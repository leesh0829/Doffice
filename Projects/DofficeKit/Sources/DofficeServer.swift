import Foundation

// MARK: - DofficeServer
// Unix domain socket API server for scripting/automation of Doffice.
// Protocol: newline-delimited JSON request → JSON response.
//
// Usage:
//   DofficeServer.shared.start()   // call once at app launch
//   DofficeServer.shared.stop()    // call on termination
//
// CLI example:
//   echo '{"command":"list-tabs"}' | nc -U /tmp/doffice.sock

public final class DofficeServer {

    public static let shared = DofficeServer()

    // MARK: - Configuration

    private let socketPath = "/tmp/doffice.sock"
    private let maxConnections: Int32 = 8
    private let bufferSize = 8192

    // MARK: - State

    private let queue = DispatchQueue(label: "com.doffice.doffice-server", qos: .utility)
    private var serverFD: Int32 = -1
    private var isRunning = false
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private let clientLock = NSLock()

    // MARK: - Notification Names (posted on main thread)

    public static let openBrowserNotification = Notification.Name("dofficeOpenBrowser")

    // MARK: - Lifecycle

    private init() {}

    /// Start the server. Safe to call multiple times; subsequent calls are no-ops.
    public func start() {
        queue.async { [weak self] in
            self?._start()
        }
    }

    /// Stop the server and clean up all resources.
    public func stop() {
        queue.async { [weak self] in
            self?._stop()
        }
    }

    // MARK: - Server Core (runs on `queue`)

    private func _start() {
        guard !isRunning else { return }

        // Remove stale socket file
        unlink(socketPath)

        // Create socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            log("Failed to create socket: \(errnoDescription)")
            return
        }

        // Set non-blocking
        let flags = fcntl(serverFD, F_GETFL)
        _ = fcntl(serverFD, F_SETFL, flags | O_NONBLOCK)

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            log("Socket path too long")
            closeSocket(serverFD)
            serverFD = -1
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                pathBytes.withUnsafeBufferPointer { src in
                    _ = memcpy(dest, src.baseAddress!, pathBytes.count)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(serverFD, sockaddrPtr, addrLen)
            }
        }
        guard bindResult == 0 else {
            log("Failed to bind: \(errnoDescription)")
            closeSocket(serverFD)
            serverFD = -1
            return
        }

        // Set permissions so any local user can connect
        chmod(socketPath, 0o666)

        // Listen
        guard listen(serverFD, maxConnections) == 0 else {
            log("Failed to listen: \(errnoDescription)")
            closeSocket(serverFD)
            serverFD = -1
            return
        }

        // Accept dispatch source
        let source = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            self.closeSocket(self.serverFD)
            self.serverFD = -1
            unlink(self.socketPath)
        }
        source.resume()
        acceptSource = source
        isRunning = true

        log("Server listening on \(socketPath)")
    }

    private func _stop() {
        guard isRunning else { return }
        isRunning = false

        acceptSource?.cancel()
        acceptSource = nil

        // Close all client connections
        clientLock.lock()
        let clients = clientSources
        clientSources.removeAll()
        clientLock.unlock()

        for (fd, source) in clients {
            source.cancel()
            closeSocket(fd)
        }

        log("Server stopped")
    }

    // MARK: - Client Handling

    private func acceptClient() {
        var clientAddr = sockaddr_un()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                accept(serverFD, sockaddrPtr, &clientAddrLen)
            }
        }

        guard clientFD >= 0 else { return }

        // Set non-blocking on client socket
        let flags = fcntl(clientFD, F_GETFL)
        _ = fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readFromClient(fd: clientFD)
        }
        source.setCancelHandler { [weak self] in
            self?.closeSocket(clientFD)
            self?.removeClient(fd: clientFD)
        }
        source.resume()

        clientLock.lock()
        clientSources[clientFD] = source
        clientLock.unlock()
    }

    private func readFromClient(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let bytesRead = read(fd, &buffer, bufferSize)

        if bytesRead <= 0 {
            // Connection closed or error
            disconnectClient(fd: fd)
            return
        }

        guard let rawString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) else {
            sendError(fd: fd, message: "Invalid UTF-8 input")
            return
        }

        // Support multiple newline-delimited requests in a single read
        let lines = rawString.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        for line in lines {
            let response = processRequest(line)
            sendResponse(fd: fd, response: response)
        }
    }

    private func disconnectClient(fd: Int32) {
        clientLock.lock()
        let source = clientSources.removeValue(forKey: fd)
        clientLock.unlock()
        source?.cancel()
    }

    private func removeClient(fd: Int32) {
        clientLock.lock()
        clientSources.removeValue(forKey: fd)
        clientLock.unlock()
    }

    // MARK: - Request Processing

    private func processRequest(_ raw: String) -> [String: Any] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = json["command"] as? String else {
            return errorResponse("Invalid request. Expected JSON with \"command\" field.")
        }

        switch command {
        case "list-tabs":
            return handleListTabs()
        case "select-tab":
            guard let tabId = json["id"] as? String else {
                return errorResponse("Missing \"id\" parameter.")
            }
            return handleSelectTab(id: tabId)
        case "new-tab":
            let projectPath = json["path"] as? String
            let projectName = json["name"] as? String
            let prompt = json["prompt"] as? String
            return handleNewTab(name: projectName, path: projectPath, prompt: prompt)
        case "close-tab":
            guard let tabId = json["id"] as? String else {
                return errorResponse("Missing \"id\" parameter.")
            }
            return handleCloseTab(id: tabId)
        case "send-input":
            guard let tabId = json["id"] as? String,
                  let text = json["text"] as? String else {
                return errorResponse("Missing \"id\" or \"text\" parameter.")
            }
            return handleSendInput(id: tabId, text: text)
        case "get-status":
            return handleGetStatus()
        case "open-browser":
            guard let urlString = json["url"] as? String else {
                return errorResponse("Missing \"url\" parameter.")
            }
            return handleOpenBrowser(url: urlString)
        case "get-notifications":
            return handleGetNotifications()
        case "ping":
            return successResponse(["message": "pong"])
        default:
            return errorResponse("Unknown command: \(command). Available: list-tabs, select-tab, new-tab, close-tab, send-input, get-status, open-browser, get-notifications, ping")
        }
    }

    // MARK: - Command Handlers

    private func handleListTabs() -> [String: Any] {
        let tabs = dispatchToMainSync { () -> [[String: Any]] in
            let manager = SessionManager.shared
            return manager.userVisibleTabs.map { tab in
                self.tabInfo(tab)
            }
        }
        return successResponse(["tabs": tabs])
    }

    private func handleSelectTab(id: String) -> [String: Any] {
        let found = dispatchToMainSync { () -> Bool in
            let manager = SessionManager.shared
            guard manager.tabs.contains(where: { $0.id == id }) else { return false }
            manager.selectTab(id)
            NotificationCenter.default.post(name: .dofficeSelectTab, object: id)
            return true
        }
        if found {
            return successResponse(["selected": id])
        } else {
            return errorResponse("Tab not found: \(id)")
        }
    }

    private func handleNewTab(name: String?, path: String?, prompt: String?) -> [String: Any] {
        let resolvedPath = path ?? NSHomeDirectory()
        let resolvedName = name ?? URL(fileURLWithPath: resolvedPath).lastPathComponent

        let tabId = dispatchToMainSync { () -> String in
            let manager = SessionManager.shared
            let tab = manager.addTab(
                projectName: resolvedName,
                projectPath: resolvedPath,
                isClaude: true,
                initialPrompt: prompt,
                manualLaunch: true
            )
            NotificationCenter.default.post(name: .dofficeNewTab, object: tab.id)
            return tab.id
        }
        return successResponse(["id": tabId, "name": resolvedName, "path": resolvedPath])
    }

    private func handleCloseTab(id: String) -> [String: Any] {
        let found = dispatchToMainSync { () -> Bool in
            let manager = SessionManager.shared
            guard manager.tabs.contains(where: { $0.id == id }) else { return false }
            manager.removeTab(id)
            NotificationCenter.default.post(name: .dofficeCloseTab, object: id)
            return true
        }
        if found {
            return successResponse(["closed": id])
        } else {
            return errorResponse("Tab not found: \(id)")
        }
    }

    private func handleSendInput(id: String, text: String) -> [String: Any] {
        let result = dispatchToMainSync { () -> (Bool, String?) in
            let manager = SessionManager.shared
            guard let tab = manager.tabs.first(where: { $0.id == id }) else {
                return (false, "Tab not found: \(id)")
            }
            tab.send(text)
            return (true, nil)
        }
        if result.0 {
            return successResponse(["sent": true, "id": id])
        } else {
            return errorResponse(result.1 ?? "Unknown error")
        }
    }

    private func handleGetStatus() -> [String: Any] {
        let status = dispatchToMainSync { () -> [String: Any] in
            let manager = SessionManager.shared
            var info: [String: Any] = [
                "tab_count": manager.userVisibleTabs.count,
                "total_tokens": manager.totalTokensUsed,
            ]
            if let active = manager.activeTab {
                info["active_tab"] = self.tabInfo(active)
            }
            info["groups"] = manager.groups.map { group in
                [
                    "id": group.id,
                    "name": group.name,
                    "tab_count": group.tabIds.count,
                ] as [String: Any]
            }
            return info
        }
        return successResponse(status)
    }

    private func handleOpenBrowser(url: String) -> [String: Any] {
        guard URL(string: url) != nil else {
            return errorResponse("Invalid URL: \(url)")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: DofficeServer.openBrowserNotification,
                object: url
            )
        }
        return successResponse(["opened": url])
    }

    private func handleGetNotifications() -> [String: Any] {
        let notifications = dispatchToMainSync { () -> [[String: Any]] in
            let manager = SessionManager.shared
            var items: [[String: Any]] = []

            for tab in manager.userVisibleTabs {
                // Pending approvals
                if let approval = tab.pendingApproval {
                    items.append([
                        "type": "pending_approval",
                        "tab_id": tab.id,
                        "tab_name": tab.projectName,
                        "command": approval.command,
                        "reason": approval.reason,
                    ])
                }
                // Dangerous command warnings
                if let warning = tab.dangerousCommandWarning {
                    items.append([
                        "type": "dangerous_command",
                        "tab_id": tab.id,
                        "tab_name": tab.projectName,
                        "warning": warning,
                    ])
                }
                // Completed tabs
                if tab.isCompleted {
                    items.append([
                        "type": "completed",
                        "tab_id": tab.id,
                        "tab_name": tab.projectName,
                        "tokens_used": tab.tokensUsed,
                        "cost": tab.totalCost,
                    ])
                }
                // Errors
                if let err = tab.startError {
                    items.append([
                        "type": "error",
                        "tab_id": tab.id,
                        "tab_name": tab.projectName,
                        "error": err,
                    ])
                }
            }
            return items
        }
        return successResponse(["notifications": notifications, "count": notifications.count])
    }

    // MARK: - Helpers

    private func tabInfo(_ tab: TerminalTab) -> [String: Any] {
        var status: String
        if tab.isCompleted {
            status = "completed"
        } else if tab.isProcessing {
            status = "processing"
        } else if tab.isRunning {
            status = "running"
        } else {
            status = "stopped"
        }

        return [
            "id": tab.id,
            "name": tab.projectName,
            "path": tab.projectPath,
            "worker": tab.workerName,
            "status": status,
            "activity": tab.claudeActivity.rawValue,
            "provider": tab.provider.rawValue,
            "model": tab.selectedModel.rawValue,
            "tokens_used": tab.tokensUsed,
            "cost": tab.totalCost,
            "is_processing": tab.isProcessing,
            "is_completed": tab.isCompleted,
            "error_count": tab.errorCount,
            "command_count": tab.commandCount,
        ]
    }

    private func successResponse(_ data: [String: Any]) -> [String: Any] {
        var response = data
        response["ok"] = true
        return response
    }

    private func errorResponse(_ message: String) -> [String: Any] {
        return ["ok": false, "error": message]
    }

    /// Synchronously dispatch a closure to the main thread and return its result.
    /// Must NOT be called from the main thread.
    private func dispatchToMainSync<T>(_ work: @escaping () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        var result: T!
        DispatchQueue.main.sync {
            result = work()
        }
        return result
    }

    // MARK: - I/O Utilities

    private func sendResponse(fd: Int32, response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]),
              var jsonString = String(data: data, encoding: .utf8) else {
            let fallback = "{\"ok\":false,\"error\":\"Failed to serialize response\"}\n"
            _ = fallback.withCString { ptr in
                Darwin.write(fd, ptr, strlen(ptr))
            }
            return
        }
        jsonString.append("\n")
        jsonString.withCString { ptr in
            let len = strlen(ptr)
            var written = 0
            while written < len {
                let n = Darwin.write(fd, ptr.advanced(by: written), len - written)
                if n <= 0 { break }
                written += n
            }
        }
    }

    private func sendError(fd: Int32, message: String) {
        sendResponse(fd: fd, response: errorResponse(message))
    }

    private func closeSocket(_ fd: Int32) {
        guard fd >= 0 else { return }
        Darwin.close(fd)
    }

    private var errnoDescription: String {
        String(cString: strerror(errno))
    }

    private func log(_ message: String) {
        print("[DofficeServer] \(message)")
    }
}
