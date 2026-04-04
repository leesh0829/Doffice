import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("doffice", {
  bootstrap: () => ipcRenderer.invoke("app:bootstrap"),
  restartApp: () => ipcRenderer.invoke("app:restart"),
  installPluginSource: (source: string) => ipcRenderer.invoke("plugin:install", source),
  createPluginTemplate: (parentDir: string) => ipcRenderer.invoke("plugin:create-template", parentDir),
  getPluginRuntimeSnapshot: (pluginDirs: string[]) => ipcRenderer.invoke("plugin:runtime-snapshot", pluginDirs),
  refreshCLIStatuses: () => ipcRenderer.invoke("app:refresh-cli-status"),
  installCLI: (provider: string) => ipcRenderer.invoke("app:install-cli", provider),
  getGitSnapshot: (projectPath: string, refName?: string) => ipcRenderer.invoke("git:snapshot", { projectPath, refName }),
  executeGitAction: (payload: unknown) => ipcRenderer.invoke("git:execute", payload),
  listReports: (projectPaths: string[]) => ipcRenderer.invoke("reports:list", projectPaths),
  readReport: (reportPath: string) => ipcRenderer.invoke("reports:read", reportPath),
  deleteReport: (reportPath: string) => ipcRenderer.invoke("reports:delete", reportPath),
  createSession: (payload: unknown) => ipcRenderer.invoke("session:create", payload),
  sendPrompt: (payload: unknown) => ipcRenderer.invoke("session:prompt", payload),
  runSlashCommand: (payload: unknown) => ipcRenderer.invoke("session:slash-command", payload),
  updateSessionConfig: (payload: unknown) => ipcRenderer.invoke("session:update-config", payload),
  approvePendingApproval: (sessionId: string) => ipcRenderer.invoke("session:approval-approve", sessionId),
  denyPendingApproval: (sessionId: string) => ipcRenderer.invoke("session:approval-deny", sessionId),
  dismissDangerousWarning: (sessionId: string) => ipcRenderer.invoke("session:dismiss-dangerous-warning", sessionId),
  dismissSensitiveWarning: (sessionId: string) => ipcRenderer.invoke("session:dismiss-sensitive-warning", sessionId),
  stopSession: (sessionId: string) => ipcRenderer.invoke("session:stop", sessionId),
  removeSession: (sessionId: string) => ipcRenderer.invoke("session:remove", sessionId),
  pickDirectory: () => ipcRenderer.invoke("dialog:pick-directory"),
  openPath: (targetPath: string) => ipcRenderer.invoke("path:open", targetPath),
  revealPath: (targetPath: string) => ipcRenderer.invoke("path:reveal", targetPath),
  openExternal: (targetUrl: string) => ipcRenderer.invoke("app:open-external", targetUrl),
  copyText: (text: string) => ipcRenderer.invoke("clipboard:copy", text),
  captureCurrentView: () => ipcRenderer.invoke("bug:capture-current-view"),
  pickImageFile: () => ipcRenderer.invoke("bug:pick-image-file"),
  showSessionContextMenu: (sessionId: string) => ipcRenderer.invoke("session:context-menu", sessionId),
  onSessionsUpdated: (callback: (payload: unknown) => void) => {
    const listener = (_event: Electron.IpcRendererEvent, payload: unknown) => callback(payload);
    ipcRenderer.on("sessions:updated", listener);
    return () => ipcRenderer.removeListener("sessions:updated", listener);
  }
});
