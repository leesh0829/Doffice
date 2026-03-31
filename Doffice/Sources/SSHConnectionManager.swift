import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - SSH Connection Manager
// ═══════════════════════════════════════════════════════

struct SSHProfile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: SSHAuthMethod
    var keyPath: String?
    var remoteWorkDir: String?

    init(id: String = UUID().uuidString, name: String = "", host: String = "",
         port: Int = 22, username: String = "", authMethod: SSHAuthMethod = .agent,
         keyPath: String? = nil, remoteWorkDir: String? = nil) {
        self.id = id; self.name = name; self.host = host; self.port = port
        self.username = username; self.authMethod = authMethod
        self.keyPath = keyPath; self.remoteWorkDir = remoteWorkDir
    }

    var displayName: String { name.isEmpty ? "\(username)@\(host)" : name }

    /// SSH 명령어 생성
    var sshCommand: String {
        var cmd = "ssh"
        if port != 22 { cmd += " -p \(port)" }
        switch authMethod {
        case .key:
            if let path = keyPath, !path.isEmpty { cmd += " -i \(path)" }
        case .agent: break
        case .password: break
        }
        cmd += " \(username)@\(host)"
        if let dir = remoteWorkDir, !dir.isEmpty {
            let escaped = dir.replacingOccurrences(of: "'", with: "'\\''")
            cmd += " -t 'cd '\\''\\(escaped)'\\'' && exec $SHELL -l'"
        }
        return cmd
    }
}

enum SSHAuthMethod: String, Codable, CaseIterable {
    case password = "password"
    case key = "key"
    case agent = "agent"

    var displayName: String {
        switch self {
        case .password: return NSLocalizedString("ssh.auth.password", comment: "Password")
        case .key: return NSLocalizedString("ssh.auth.key", comment: "SSH Key")
        case .agent: return NSLocalizedString("ssh.auth.agent", comment: "SSH Agent")
        }
    }

    var icon: String {
        switch self {
        case .password: return "key.fill"
        case .key: return "doc.text.fill"
        case .agent: return "person.badge.key.fill"
        }
    }
}

class SSHConnectionManager: ObservableObject {
    static let shared = SSHConnectionManager()

    @Published var profiles: [SSHProfile] = []

    private let storageKey = "doffice.sshProfiles"

    private init() { loadProfiles() }

    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SSHProfile].self, from: data) {
            profiles = saved
        }
    }

    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addProfile(_ profile: SSHProfile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: SSHProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            saveProfiles()
        }
    }

    func deleteProfile(id: String) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SSH Connection Sheet
// ═══════════════════════════════════════════════════════

struct SSHConnectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var sshManager = SSHConnectionManager.shared
    @State private var editingProfile = SSHProfile()
    @State private var isEditing = false
    @State private var showForm = false

    let onConnect: (SSHProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: Theme.iconSize(16)))
                    .foregroundStyle(Theme.accentBackground)
                Text(NSLocalizedString("ssh.title", comment: "SSH Connections"))
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(16)))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Theme.bgCard)

            Divider()

            if showForm {
                sshFormView
            } else {
                profileListView
            }
        }
        .frame(width: 480, height: 420)
        .background(Theme.bg)
    }

    private var profileListView: some View {
        VStack(spacing: 0) {
            if sshManager.profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.textDim.opacity(0.3))
                    Text(NSLocalizedString("ssh.no.profiles", comment: "No SSH profiles"))
                        .font(Theme.mono(12))
                        .foregroundColor(Theme.textDim)
                    Text(NSLocalizedString("ssh.add.first", comment: "Add your first server"))
                        .font(Theme.chrome(10))
                        .foregroundColor(Theme.textDim.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sshManager.profiles) { profile in
                            sshProfileRow(profile)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            HStack {
                Button(action: {
                    editingProfile = SSHProfile()
                    isEditing = false
                    showForm = true
                }) {
                    Label(NSLocalizedString("ssh.add.new", comment: "New Connection"), systemImage: "plus.circle.fill")
                        .font(Theme.mono(11, weight: .medium))
                        .foregroundStyle(Theme.accentBackground)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(12)
        }
    }

    private func sshProfileRow(_ profile: SSHProfile) -> some View {
        HStack(spacing: 10) {
            // Server icon with status glow
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accentBackground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(profile.username)@\(profile.host):\(profile.port)")
                    .font(Theme.chrome(9))
                    .foregroundColor(Theme.textDim)
            }

            Spacer()

            HStack(spacing: 6) {
                // Auth method badge
                HStack(spacing: 3) {
                    Image(systemName: profile.authMethod.icon)
                        .font(.system(size: 8))
                    Text(profile.authMethod.displayName)
                        .font(Theme.chrome(8))
                }
                .foregroundColor(Theme.textDim)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.bgSurface)
                .cornerRadius(4)

                // Edit button
                Button(action: {
                    editingProfile = profile
                    isEditing = true
                    showForm = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)

                // Connect button
                Button(action: {
                    onConnect(profile)
                    dismiss()
                }) {
                    Text(NSLocalizedString("ssh.connect", comment: "Connect"))
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.bgCard)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1))
    }

    private var sshFormView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formField(NSLocalizedString("ssh.field.name", comment: "Name"), placeholder: "My Server", binding: $editingProfile.name)
                    formField(NSLocalizedString("ssh.field.host", comment: "Host"), placeholder: "192.168.1.100", binding: $editingProfile.host)

                    HStack(spacing: 12) {
                        formField(NSLocalizedString("ssh.field.username", comment: "Username"), placeholder: "root", binding: $editingProfile.username)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("ssh.field.port", comment: "Port"))
                                .font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.textDim)
                            TextField("22", value: $editingProfile.port, format: .number)
                                .textFieldStyle(.plain)
                                .font(Theme.mono(11))
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                                .frame(width: 80)
                        }
                    }

                    // Auth method
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("ssh.field.auth", comment: "Authentication"))
                            .font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.textDim)
                        HStack(spacing: 6) {
                            ForEach(SSHAuthMethod.allCases, id: \.rawValue) { method in
                                let isSelected = editingProfile.authMethod == method
                                Button(action: { editingProfile.authMethod = method }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: method.icon).font(.system(size: 9))
                                        Text(method.displayName).font(Theme.chrome(9, weight: isSelected ? .bold : .regular))
                                    }
                                    .foregroundColor(isSelected ? Theme.accent : Theme.textDim)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if editingProfile.authMethod == .key {
                        let keyBinding = Binding<String>(
                            get: { editingProfile.keyPath ?? "" },
                            set: { editingProfile.keyPath = $0.isEmpty ? nil : $0 }
                        )
                        formField(NSLocalizedString("ssh.field.keypath", comment: "Key Path"), placeholder: "~/.ssh/id_rsa", binding: keyBinding)
                    }

                    let workDirBinding = Binding<String>(
                        get: { editingProfile.remoteWorkDir ?? "" },
                        set: { editingProfile.remoteWorkDir = $0.isEmpty ? nil : $0 }
                    )
                    formField(NSLocalizedString("ssh.field.workdir", comment: "Remote Work Directory"), placeholder: "/home/user/project", binding: workDirBinding)
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button(action: { showForm = false }) {
                    Text(NSLocalizedString("ssh.cancel", comment: "Cancel"))
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)

                if isEditing {
                    Button(action: {
                        sshManager.deleteProfile(id: editingProfile.id)
                        showForm = false
                    }) {
                        Text(NSLocalizedString("ssh.delete", comment: "Delete"))
                            .font(Theme.mono(11, weight: .medium))
                            .foregroundColor(Theme.red)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
                    if isEditing {
                        sshManager.updateProfile(editingProfile)
                    } else {
                        sshManager.addProfile(editingProfile)
                    }
                    showForm = false
                }) {
                    Text(isEditing ? NSLocalizedString("ssh.save", comment: "Save") : NSLocalizedString("ssh.add", comment: "Add"))
                        .font(Theme.mono(11, weight: .semibold))
                        .foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(Theme.accent).cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(editingProfile.host.isEmpty || editingProfile.username.isEmpty)

                if !isEditing {
                    Button(action: {
                        if editingProfile.host.isEmpty || editingProfile.username.isEmpty { return }
                        sshManager.addProfile(editingProfile)
                        onConnect(editingProfile)
                        dismiss()
                    }) {
                        Text(NSLocalizedString("ssh.add.and.connect", comment: "Add & Connect"))
                            .font(Theme.mono(11, weight: .semibold))
                            .foregroundColor(Theme.textOnAccent)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Theme.green).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(editingProfile.host.isEmpty || editingProfile.username.isEmpty)
                }
            }
            .padding(12)
        }
    }

    private func formField(_ label: String, placeholder: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.chrome(9, weight: .semibold))
                .foregroundColor(Theme.textDim)
            TextField(placeholder, text: binding)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.3), lineWidth: 1))
        }
    }
}
