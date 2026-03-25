import SwiftUI
import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - Auto Update Checker (GitHub Release 직접 다운로드)
// ═══════════════════════════════════════════════════════

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    // 상태
    enum UpdateState: Equatable {
        case idle
        case checking
        case noUpdate
        case available
        case downloading(progress: Double)
        case extracting
        case readyToInstall
        case installing
        case failed(message: String)
    }

    @Published var state: UpdateState = .idle
    @Published var latestVersion: String = ""
    @Published var currentVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var downloadURL: String = ""

    var hasUpdate: Bool {
        switch state {
        case .available, .downloading, .extracting, .readyToInstall, .failed:
            return !latestVersion.isEmpty && isNewer(latestVersion, than: currentVersion)
        default:
            return false
        }
    }

    var isChecking: Bool { state == .checking }

    // GitHub repo 정보
    private let owner = "jjunhaa0211"
    private let repo = "MyWorkStudio"

    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: DownloadDelegate?
    private var downloadedAppURL: URL?

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - 버전 확인

    func checkForUpdates() {
        // idle, noUpdate, available, failed 상태에서만 체크 허용
        switch state {
        case .idle, .noUpdate, .available, .failed: break
        default: return
        }
        state = .checking

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            state = .idle
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    print("[도피스] 업데이트 확인 실패: \(error.localizedDescription)")
                    self.state = .failed(message: "네트워크 오류: \(error.localizedDescription)")
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.state = .failed(message: "GitHub 응답을 파싱할 수 없습니다.")
                    return
                }

                // draft/prerelease 체크
                let isDraft = json["draft"] as? Bool ?? false
                let isPrerelease = json["prerelease"] as? Bool ?? false
                if isDraft || isPrerelease {
                    self.state = .noUpdate
                    return
                }

                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                self.latestVersion = version
                self.releaseNotes = json["body"] as? String ?? ""

                // .zip 다운로드 URL 추출 (macOS용)
                self.downloadURL = ""
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           name.hasSuffix(".zip"),
                           let url = asset["browser_download_url"] as? String {
                            self.downloadURL = url
                            break
                        }
                    }
                    // .zip 없으면 .dmg
                    if self.downloadURL.isEmpty {
                        for asset in assets {
                            if let name = asset["name"] as? String,
                               name.hasSuffix(".dmg"),
                               let url = asset["browser_download_url"] as? String {
                                self.downloadURL = url
                                break
                            }
                        }
                    }
                }

                if self.isNewer(version, than: self.currentVersion) {
                    self.state = .available
                    print("[도피스] 업데이트 발견: v\(self.currentVersion) → v\(version)")
                    // 백그라운드 자동 다운로드 시작
                    self.performUpdate()
                } else {
                    self.state = .noUpdate
                    print("[도피스] 최신 버전 사용 중: v\(self.currentVersion)")
                }
            }
        }.resume()
    }

    // MARK: - 다운로드 & 설치

    func performUpdate() {
        guard !downloadURL.isEmpty, let url = URL(string: downloadURL) else {
            state = .failed(message: "다운로드 URL을 찾을 수 없습니다. GitHub에서 직접 다운로드해주세요.")
            return
        }

        state = .downloading(progress: 0)
        downloadedAppURL = nil

        let delegate = DownloadDelegate { [weak self] progress in
            DispatchQueue.main.async {
                self?.state = .downloading(progress: progress)
            }
        } onComplete: { [weak self] tempURL, error in
            DispatchQueue.main.async {
                self?.handleDownloadComplete(tempURL: tempURL, error: error)
            }
        }
        self.downloadDelegate = delegate

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
        print("[도피스] 다운로드 시작: \(downloadURL)")
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadDelegate = nil
        state = .available
    }

    private func handleDownloadComplete(tempURL: URL?, error: Error?) {
        if let error {
            state = .failed(message: "다운로드 실패: \(error.localizedDescription)")
            return
        }
        guard let tempURL else {
            state = .failed(message: "다운로드된 파일을 찾을 수 없습니다.")
            return
        }

        state = .extracting
        print("[도피스] 다운로드 완료, 압축 해제 중...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.extractAndPrepare(zipURL: tempURL)
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let appURL):
                    self.downloadedAppURL = appURL
                    self.state = .readyToInstall
                    print("[도피스] 설치 준비 완료: \(appURL.path)")
                case .failure(let error):
                    self.state = .failed(message: "압축 해제 실패: \(error.localizedDescription)")
                case .none:
                    self.state = .failed(message: "알 수 없는 오류")
                }
            }
        }
    }

    private func extractAndPrepare(zipURL: URL) -> Result<URL, Error> {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("doffice-update-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // unzip 실행
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            proc.arguments = ["-o", "-q", zipURL.path, "-d", tempDir.path]
            try proc.run()
            proc.waitUntilExit()

            guard proc.terminationStatus == 0 else {
                return .failure(NSError(domain: "UpdateChecker", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "unzip 종료 코드: \(proc.terminationStatus)"
                ]))
            }

            // .app 번들 찾기
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            if let app = contents.first(where: { $0.pathExtension == "app" }) {
                return .success(app)
            }

            // 하위 디렉토리에서 찾기
            for dir in contents where dir.hasDirectoryPath {
                let subContents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                if let app = subContents.first(where: { $0.pathExtension == "app" }) {
                    return .success(app)
                }
            }

            return .failure(NSError(domain: "UpdateChecker", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "압축 해제된 파일에서 .app을 찾을 수 없습니다."
            ]))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - 설치 (현재 앱 교체 후 재시작)

    func installAndRestart() {
        guard let newAppURL = downloadedAppURL else {
            state = .failed(message: "설치할 앱을 찾을 수 없습니다.")
            return
        }

        state = .installing

        // 현재 앱 경로
        let currentAppURL = Bundle.main.bundleURL

        // 설치 스크립트: 현재 앱 종료 → 교체 → 재시작
        // 앱이 종료된 후 실행되어야 하므로 별도 프로세스로 작성
        let script = """
        #!/bin/zsh
        # 앱 종료 대기
        sleep 1
        # 기존 앱 백업 후 교체
        BACKUP="\(currentAppURL.path).backup"
        rm -rf "$BACKUP"
        mv "\(currentAppURL.path)" "$BACKUP" 2>/dev/null
        cp -R "\(newAppURL.path)" "\(currentAppURL.path)"
        # xattr 초기화 (quarantine 제거)
        xattr -cr "\(currentAppURL.path)" 2>/dev/null
        # 새 앱 실행
        open "\(currentAppURL.path)"
        # 백업 정리
        sleep 3
        rm -rf "$BACKUP"
        rm -rf "\(newAppURL.path.components(separatedBy: "/").dropLast().joined(separator: "/"))"
        """

        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("doffice-updater.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = [scriptURL.path]
            proc.standardOutput = nil
            proc.standardError = nil
            try proc.run()

            // 앱 종료
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        } catch {
            state = .failed(message: "설치 스크립트 실행 실패: \(error.localizedDescription)")
        }
    }

    func openReleasePage() {
        if let url = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    func resetState() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadDelegate = nil
        downloadedAppURL = nil
        state = .idle
    }

    // MARK: - Version Comparison

    private func isNewer(_ latest: String, than current: String) -> Bool {
        let lParts = latest.split(separator: ".").compactMap { Int($0) }
        let cParts = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lParts.count, cParts.count) {
            let l = i < lParts.count ? lParts[i] : 0
            let c = i < cParts.count ? cParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onComplete: (URL?, Error?) -> Void

    init(onProgress: @escaping (Double) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 임시 위치에서 안전한 곳으로 복사 (콜백 리턴 후 삭제되므로)
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("doffice-download-\(UUID().uuidString).zip")
        do {
            try FileManager.default.copyItem(at: location, to: dest)
            onComplete(dest, nil)
        } catch {
            onComplete(nil, error)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            onComplete(nil, error)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Update Sheet UI
// ═══════════════════════════════════════════════════════

struct UpdateSheet: View {
    @ObservedObject var updater = UpdateChecker.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            headerView
            versionCompareView
            releaseNotesView
            stateView
            actionButtons
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.bgCard)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(stateColor.opacity(0.1)).frame(width: 56, height: 56)
                Image(systemName: stateIcon)
                    .font(.system(size: Theme.iconSize(26)))
                    .foregroundColor(stateColor)
            }
            Text(stateTitle)
                .font(Theme.mono(14, weight: .bold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private var stateColor: Color {
        switch updater.state {
        case .available, .noUpdate, .idle, .checking: return Theme.green
        case .downloading, .extracting: return Theme.accent
        case .readyToInstall: return Theme.green
        case .installing: return Theme.purple
        case .failed: return Theme.red
        }
    }

    private var stateIcon: String {
        switch updater.state {
        case .idle, .checking: return "arrow.down.app.fill"
        case .noUpdate: return "checkmark.circle.fill"
        case .available: return "arrow.down.app.fill"
        case .downloading: return "arrow.down.circle"
        case .extracting: return "doc.zipper"
        case .readyToInstall: return "checkmark.seal.fill"
        case .installing: return "gear.badge.checkmark"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var stateTitle: String {
        switch updater.state {
        case .idle, .checking: return "업데이트 확인 중"
        case .noUpdate: return "최신 버전입니다"
        case .available: return "새 버전이 있습니다"
        case .downloading: return "다운로드 중"
        case .extracting: return "압축 해제 중"
        case .readyToInstall: return "설치 준비 완료"
        case .installing: return "설치 중..."
        case .failed: return "업데이트 실패"
        }
    }

    // MARK: - Version Compare

    private var versionCompareView: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("현재").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                Text("v\(updater.currentVersion)")
                    .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.textSecondary)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: Theme.iconSize(14)))
                .foregroundColor(Theme.green)
            VStack(spacing: 4) {
                Text("최신").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                Text("v\(updater.latestVersion.isEmpty ? "..." : updater.latestVersion)")
                    .font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.green)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Release Notes

    @ViewBuilder
    private var releaseNotesView: some View {
        if !updater.releaseNotes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("변경 사항").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                ScrollView {
                    Text(updater.releaseNotes)
                        .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 120)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))
        }
    }

    // MARK: - State View

    @ViewBuilder
    private var stateView: some View {
        switch updater.state {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("최신 버전을 확인하고 있습니다...")
                    .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
            }

        case .downloading(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(Theme.accent)
                HStack {
                    Text("다운로드 중...")
                        .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.accent)
                }
            }

        case .extracting:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("압축을 해제하고 있습니다...")
                    .font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
            }

        case .readyToInstall:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                Text("다운로드가 완료되었습니다. 재시작하면 새 버전이 적용됩니다.")
                    .font(Theme.mono(9)).foregroundColor(Theme.green)
            }

        case .installing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("앱을 교체하고 재시작합니다...")
                    .font(Theme.mono(10)).foregroundColor(Theme.purple)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.red)
                    Text(message).font(Theme.mono(9)).foregroundColor(Theme.red)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch updater.state {
        case .available:
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("나중에").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain).keyboardShortcut(.escape)

                Button(action: { updater.openReleasePage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari").font(.system(size: Theme.iconSize(9)))
                        Text("수동 다운로드").font(Theme.mono(10))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.performUpdate() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: Theme.iconSize(10)))
                        Text("지금 업데이트").font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .downloading:
            Button(action: { updater.cancelDownload() }) {
                Text("취소").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            }.buttonStyle(.plain)

        case .readyToInstall:
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("종료 시 적용").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.installAndRestart() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise").font(.system(size: Theme.iconSize(10)))
                        Text("지금 재시작하고 업데이트").font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .failed:
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("닫기").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                }.buttonStyle(.plain).keyboardShortcut(.escape)

                Button(action: { updater.openReleasePage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari").font(.system(size: Theme.iconSize(9)))
                        Text("수동 다운로드").font(Theme.mono(10))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)

                Button(action: { updater.checkForUpdates() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: Theme.iconSize(10)))
                        Text("재시도").font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }

        case .noUpdate:
            Button(action: { dismiss() }) {
                Text("확인").font(Theme.mono(10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
            }.buttonStyle(.plain).keyboardShortcut(.return)

        default:
            EmptyView()
        }
    }
}
