import SwiftUI
import AppKit
import SwiftTerm

// ═══════════════════════════════════════════════════════
// MARK: - CLITerminalView (SwiftTerm 기반 100% 터미널)
// ═══════════════════════════════════════════════════════

struct CLITerminalView: NSViewRepresentable {
    let tab: TerminalTab
    var fontSize: CGFloat

    func makeNSView(context: Context) -> SwiftTermContainer {
        SwiftTermContainer(tab: tab, fontSize: fontSize)
    }

    func updateNSView(_ nsView: SwiftTermContainer, context: Context) {}
}

/// SwiftTerm의 LocalProcessTerminalView를 감싸는 컨테이너
/// 이미지 드래그앤드롭 + 클립보드 붙여넣기 지원
class SwiftTermContainer: NSView, LocalProcessTerminalViewDelegate {
    weak var tab: TerminalTab?
    let terminalView: LocalProcessTerminalView

    private var sendKeysObserver: NSObjectProtocol?

    init(tab: TerminalTab, fontSize: CGFloat) {
        self.tab = tab
        self.terminalView = LocalProcessTerminalView(frame: .zero)
        super.init(frame: .zero)

        terminalView.processDelegate = self
        terminalView.autoresizingMask = [.width, .height]

        // 테마 연동 터미널 스타일
        let bgColor = Theme.resolvedBgTerminalNSColor
        let fgColor = Theme.resolvedFgTerminalNSColor
        terminalView.nativeBackgroundColor = bgColor
        terminalView.nativeForegroundColor = fgColor

        // 커스텀 폰트 지원
        let customFontName = AppSettings.shared.customTheme.fontName
        let monoFont: NSFont
        if let fontName = customFontName, !fontName.isEmpty,
           let customFont = NSFont(name: fontName, size: fontSize) {
            monoFont = customFont
        } else {
            monoFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        terminalView.font = monoFont
        terminalView.optionAsMetaKey = false

        addSubview(terminalView)

        // 드래그앤드롭 등록
        registerForDraggedTypes([.fileURL, .png, .tiff])

        // send-keys 자동화 지원
        sendKeysObserver = NotificationCenter.default.addObserver(
            forName: .dofficeSendKeysToTerminal,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let targetTabId = userInfo["tabId"] as? String,
                  targetTabId == tab.id,
                  let text = userInfo["text"] as? String else { return }
            self.terminalView.send(txt: text)
        }

        // 셸 프로세스 시작 (SSH 또는 일반 셸)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = TerminalTab.buildFullPATH()
        env["TERM"] = "xterm"
        env["TERM_PROGRAM"] = "Apple_Terminal"
        env["COLORTERM"] = "truecolor"
        env.removeValue(forKey: "TERM_PROGRAM_VERSION")
        if env["LANG"] == nil { env["LANG"] = "ko_KR.UTF-8" }
        env["HOME"] = NSHomeDirectory()
        let envArray = env.map { "\($0.key)=\($0.value)" }

        if let sshProfile = tab.sshProfile {
            // SSH 모드: ssh 명령어를 셸을 통해 실행
            let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            terminalView.startProcess(executable: userShell, args: ["-l"], environment: envArray, execName: "-zsh")
            // SSH 연결 명령 자동 전송
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.terminalView.send(txt: sshProfile.sshCommand + "\r")
            }
        } else {
            let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            terminalView.startProcess(executable: userShell, args: ["-l"], environment: envArray, execName: "-zsh")
        }

        // 포커스
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.makeFirstResponder(self?.terminalView)
        }
    }

    required init?(coder: NSCoder) { return nil }

    deinit {
        terminalView.processDelegate = nil
        if let observer = sendKeysObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 외부에서 터미널에 텍스트를 보낼 때 사용
    func sendText(_ text: String) {
        terminalView.send(txt: text)
    }

    override func layout() {
        super.layout()
        terminalView.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.window?.makeFirstResponder(self?.terminalView)
            }
        }
    }

    // MARK: - 드래그앤드롭 (이미지 파일 → 터미널에 경로 입력)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasImageFiles(sender) { return .copy }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let paths = extractImagePaths(from: sender), !paths.isEmpty else { return false }
        // 이미지 경로를 터미널에 입력 (공백 이스케이프)
        let escaped = paths.map { "'\($0)'" }.joined(separator: " ")
        terminalView.send(txt: escaped)
        return true
    }

    private func hasImageFiles(_ info: NSDraggingInfo) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems else { return false }
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"])
        return items.contains { item in
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr) {
                return imageExts.contains(url.pathExtension.lowercased())
            }
            // 클립보드 이미지 (스크린샷 등)
            return item.types.contains(.png) || item.types.contains(.tiff)
        }
    }

    private func extractImagePaths(from info: NSDraggingInfo) -> [String]? {
        guard let items = info.draggingPasteboard.pasteboardItems else { return nil }
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"])
        var paths: [String] = []

        for item in items {
            // 파일 URL
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr),
               imageExts.contains(url.pathExtension.lowercased()) {
                paths.append(url.path)
                continue
            }
            // 클립보드 이미지 데이터 → 임시 파일로 저장
            if let imgData = item.data(forType: .png) ?? item.data(forType: .tiff) {
                if let path = saveClipboardImage(imgData) {
                    paths.append(path)
                }
            }
        }
        return paths
    }

    /// 클립보드/스크린샷 이미지를 임시 파일로 저장하고 경로 반환
    private func saveClipboardImage(_ data: Data) -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "doffice_image_\(timestamp).png"
        let tmpDir = NSTemporaryDirectory()
        let filePath = (tmpDir as NSString).appendingPathComponent(filename)

        // PNG 변환
        guard let bitmapRep = NSBitmapImageRep(data: data),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            // raw 데이터 그대로 저장
            do { try data.write(to: URL(fileURLWithPath: filePath)); return filePath }
            catch { return nil }
        }
        do { try pngData.write(to: URL(fileURLWithPath: filePath)); return filePath }
        catch { return nil }
    }

    // MARK: - Cmd+Shift+V로 클립보드 이미지 붙여넣기

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == [.command, .shift] && event.charactersIgnoringModifiers == "v" {
            if pasteClipboardImage() { return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    @discardableResult
    private func pasteClipboardImage() -> Bool {
        let pb = NSPasteboard.general
        // 이미지 데이터 확인
        if let imgData = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            if let path = saveClipboardImage(imgData) {
                terminalView.send(txt: "'\(path)'")
                return true
            }
        }
        // 파일 URL 확인
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"])
            let imagePaths = urls.filter { imageExts.contains($0.pathExtension.lowercased()) }.map { "'\($0.path)'" }
            if !imagePaths.isEmpty {
                terminalView.send(txt: imagePaths.joined(separator: " "))
                return true
            }
        }
        return false
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.tab?.isProcessing = false
            self?.tab?.claudeActivity = .idle
            self?.tab?.isRawMode = false
        }
    }
}
