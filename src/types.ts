export type ClaudeActivity =
  | "idle"
  | "thinking"
  | "reading"
  | "writing"
  | "searching"
  | "running"
  | "done"
  | "error";

export type AgentProvider = "claude" | "codex" | "gemini";

export type CodexSandboxMode = "read-only" | "workspace-write" | "danger-full-access";

export type CodexApprovalPolicy = "untrusted" | "on-request" | "never";

export type BlockKind =
  | "sessionStart"
  | "thought"
  | "toolUse"
  | "toolOutput"
  | "toolError"
  | "toolEnd"
  | "text"
  | "fileChange"
  | "status"
  | "completion"
  | "error"
  | "userPrompt";

export interface SessionBlock {
  id: string;
  kind: BlockKind;
  content: string;
  timestamp: string;
  meta?: Record<string, unknown>;
}

export interface FileChangeRecord {
  path: string;
  fileName: string;
  action: string;
  timestamp: string;
  success: boolean;
}

export interface GitInfo {
  branch: string;
  changedFiles: number;
  lastCommit: string;
  lastCommitAge: string;
  isGitRepo: boolean;
}

export interface GitBranchSnapshot {
  name: string;
  isCurrent: boolean;
  isRemote: boolean;
  upstream: string;
  shortHash: string;
  ahead: number;
  behind: number;
}

export type GitRefType = "branch" | "remoteBranch" | "tag" | "head";

export interface GitRefSnapshot {
  name: string;
  type: GitRefType;
}

export interface GitCommitSnapshot {
  id: string;
  shortHash: string;
  author: string;
  authorEmail: string;
  relativeDate: string;
  isoDate: string;
  subject: string;
  refs: GitRefSnapshot[];
  lane: number;
  activeLanes: number[];
  hasIncoming: boolean;
  topIds: string[];
  bottomIds: string[];
  topLanes: number[];
  bottomLanes: number[];
  parentLanes: number[];
  mergeLanes: number[];
  parentIds: string[];
}

export interface GitWorktreeChangeSnapshot {
  path: string;
  fileName: string;
  indexStatus: string;
  workTreeStatus: string;
  statusLabel: string;
  staged: boolean;
}

export interface GitStashSnapshot {
  id: string;
  label: string;
  relativeDate: string;
  message: string;
}

export interface GitPanelSnapshot {
  projectPath: string;
  isGitRepo: boolean;
  currentBranch: string;
  upstreamStatus: string;
  branches: GitBranchSnapshot[];
  tags: string[];
  stashes: GitStashSnapshot[];
  commits: GitCommitSnapshot[];
  changes: GitWorktreeChangeSnapshot[];
  lastError: string;
}

export interface GitActionPayload {
  projectPath: string;
  action: "stageAll" | "commit" | "commitSelected" | "amend" | "push" | "pull" | "branch" | "stash" | "merge";
  input?: string;
  selectedPaths?: string[];
}

export interface GitActionResult {
  ok: boolean;
  message: string;
}

export interface ReportReference {
  id: string;
  projectName: string;
  projectPath: string;
  path: string;
  fileName: string;
  updatedAt: string;
}

export interface ReportDocument {
  path: string;
  content: string;
}

export interface ImageAttachment {
  path: string;
  dataUrl: string;
}

export interface PendingApprovalInfo {
  command: string;
  reason: string;
  toolName: string;
  retryMode: string;
}

export interface SessionSnapshot {
  id: string;
  projectName: string;
  projectPath: string;
  workerName: string;
  workerColorHex: string;
  tokensUsed: number;
  inputTokensUsed: number;
  outputTokensUsed: number;
  totalCost: number;
  branch: string;
  startTime: string;
  lastActivityTime: string;
  isCompleted: boolean;
  isProcessing: boolean;
  isRunning: boolean;
  claudeActivity: ClaudeActivity;
  provider: AgentProvider;
  sessionId: string;
  selectedModel: string;
  effortLevel: string;
  outputMode: string;
  permissionMode: string;
  codexSandboxMode: CodexSandboxMode;
  codexApprovalPolicy: CodexApprovalPolicy;
  systemPrompt: string;
  maxBudgetUSD: number;
  allowedTools: string;
  disallowedTools: string;
  additionalDirs: string[];
  continueSession: boolean;
  useWorktree: boolean;
  fallbackModel: string;
  sessionName: string;
  jsonSchema: string;
  mcpConfigPaths: string[];
  customAgent: string;
  customAgentsJSON: string;
  pluginDirs: string[];
  customTools: string;
  enableChrome: boolean;
  forkSession: boolean;
  fromPR: string;
  manualLaunch: boolean;
  enableBrief: boolean;
  tmuxMode: boolean;
  strictMcpConfig: boolean;
  settingSources: string;
  settingsFileOrJSON: string;
  betaHeaders: string;
  tokenLimit: number;
  completedPromptCount: number;
  lastPromptText: string;
  lastResultText: string;
  lastReportPath: string;
  lastReportGeneratedAt: string;
  lastReportedFileChangeCount: number;
  pendingApproval: PendingApprovalInfo | null;
  dangerousCommandWarning: string | null;
  sensitiveFileWarning: string | null;
  blocks: SessionBlock[];
  fileChanges: FileChangeRecord[];
  gitInfo: GitInfo;
  tabOrder: number;
}

export interface ClaudeStatus {
  isInstalled: boolean;
  version: string;
  path: string;
  errorInfo: string;
}

export interface CLIStatus {
  isInstalled: boolean;
  version: string;
  path: string;
  errorInfo: string;
}

export interface CLIStatusPayload {
  claudeStatus: CLIStatus;
  codexStatus: CLIStatus;
  geminiStatus: CLIStatus;
}

export interface PluginRuntimeCharacter {
  id: string;
  name: string;
  role: string;
  skill: string;
  species: string;
  emoji: string;
  hairColor: string;
  skinTone: string;
  shirtColor: string;
  pantsColor: string;
  hatType: string;
  accessory: string;
  requiredAchievement: string | null;
  jobRole: string;
  isStarter: boolean;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeFurniture {
  id: string;
  name: string;
  icon: string;
  officeKinds: string[];
  width: number;
  height: number;
  isWallItem: boolean;
  requiredLevel: number | null;
  requiredAchievement: string | null;
  sprite: string[][];
  zone: string;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeAchievement {
  id: string;
  tier: string;
  title: string;
  subtitle: string;
  xp: number;
  icon: string;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeOfficePresetPlacement {
  furnitureId: string;
  col: number;
  row: number;
}

export interface PluginRuntimeOfficePreset {
  id: string;
  name: string;
  description: string;
  furniture: PluginRuntimeOfficePresetPlacement[];
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeTheme {
  id: string;
  name: string;
  isDark: boolean;
  accentHex: string;
  bgHex: string;
  cardHex: string;
  textHex: string;
  greenHex: string;
  redHex: string;
  yellowHex: string;
  purpleHex: string;
  cyanHex: string;
  useGradient: boolean;
  gradientStartHex: string;
  gradientEndHex: string;
  fontName: string;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimePanel {
  id: string;
  title: string;
  icon: string;
  entry: string;
  position: string;
  width: number | null;
  height: number | null;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeCommand {
  id: string;
  title: string;
  icon: string;
  script: string;
  keybinding: string | null;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeStatusBarItem {
  id: string;
  script: string;
  interval: number;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeEffect {
  id: string;
  trigger: string;
  type: string;
  config: Record<string, unknown>;
  enabled: boolean;
  pluginId: string;
  pluginName: string;
}

export interface PluginRuntimeSnapshot {
  pluginIds: string[];
  characters: PluginRuntimeCharacter[];
  furniture: PluginRuntimeFurniture[];
  achievements: PluginRuntimeAchievement[];
  officePresets: PluginRuntimeOfficePreset[];
  themes: PluginRuntimeTheme[];
  panels: PluginRuntimePanel[];
  commands: PluginRuntimeCommand[];
  statusBar: PluginRuntimeStatusBarItem[];
  effects: PluginRuntimeEffect[];
  bossLines: string[];
}

export interface BootstrapPayload extends CLIStatusPayload {
  sessions: SessionSnapshot[];
}

export interface CLIInstallResult extends CLIStatusPayload {
  ok: boolean;
  provider: AgentProvider;
  message: string;
}

export interface PluginInstallResult {
  id: string;
  title: string;
  source: string;
  localPath: string;
  author: string;
  version: string;
  tags: string[];
}

export interface CreateSessionPayload {
  projectPath: string;
  projectName?: string;
  initialPrompt?: string;
  provider?: AgentProvider;
  selectedModel?: string;
  effortLevel?: string;
  outputMode?: string;
  permissionMode?: string;
  codexSandboxMode?: CodexSandboxMode;
  codexApprovalPolicy?: CodexApprovalPolicy;
  pluginDirs?: string[];
  systemPrompt?: string;
  maxBudgetUSD?: number;
  allowedTools?: string;
  disallowedTools?: string;
  additionalDirs?: string[];
  continueSession?: boolean;
  useWorktree?: boolean;
  fallbackModel?: string;
  sessionName?: string;
  enableChrome?: boolean;
  forkSession?: boolean;
  enableBrief?: boolean;
}

export interface PromptPayload {
  sessionId: string;
  prompt: string;
}

export interface SlashCommandPayload {
  sessionId: string;
  command: string;
}

export interface UpdateSessionConfigPayload {
  sessionId: string;
  provider?: AgentProvider;
  selectedModel?: string;
  effortLevel?: string;
  outputMode?: string;
  permissionMode?: string;
  enableBrief?: boolean;
}

export interface DofficeBridge {
  bootstrap: () => Promise<BootstrapPayload>;
  restartApp: () => Promise<void>;
  installPluginSource: (source: string) => Promise<PluginInstallResult>;
  createPluginTemplate: (parentDir: string) => Promise<PluginInstallResult>;
  getPluginRuntimeSnapshot: (pluginDirs: string[]) => Promise<PluginRuntimeSnapshot>;
  refreshCLIStatuses: () => Promise<CLIStatusPayload>;
  installCLI: (provider: AgentProvider) => Promise<CLIInstallResult>;
  getGitSnapshot: (projectPath: string, refName?: string) => Promise<GitPanelSnapshot>;
  executeGitAction: (payload: GitActionPayload) => Promise<GitActionResult>;
  listReports: (projectPaths: string[]) => Promise<ReportReference[]>;
  readReport: (reportPath: string) => Promise<ReportDocument>;
  deleteReport: (reportPath: string) => Promise<void>;
  createSession: (payload: CreateSessionPayload) => Promise<SessionSnapshot>;
  sendPrompt: (payload: PromptPayload) => Promise<SessionSnapshot>;
  runSlashCommand: (payload: SlashCommandPayload) => Promise<SessionSnapshot>;
  updateSessionConfig: (payload: UpdateSessionConfigPayload) => Promise<SessionSnapshot>;
  approvePendingApproval: (sessionId: string) => Promise<SessionSnapshot>;
  denyPendingApproval: (sessionId: string) => Promise<SessionSnapshot>;
  dismissDangerousWarning: (sessionId: string) => Promise<SessionSnapshot>;
  dismissSensitiveWarning: (sessionId: string) => Promise<SessionSnapshot>;
  stopSession: (sessionId: string) => Promise<SessionSnapshot>;
  removeSession: (sessionId: string) => Promise<void>;
  pickDirectory: () => Promise<string>;
  openPath: (targetPath: string) => Promise<void>;
  revealPath: (targetPath: string) => Promise<void>;
  openExternal: (targetUrl: string) => Promise<void>;
  copyText: (text: string) => Promise<void>;
  captureCurrentView: () => Promise<ImageAttachment | null>;
  pickImageFile: () => Promise<ImageAttachment | null>;
  showSessionContextMenu: (sessionId: string) => Promise<void>;
  onSessionsUpdated: (callback: (payload: SessionSnapshot[]) => void) => () => void;
}
