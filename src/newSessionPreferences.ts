import type { SessionSnapshot } from "./types";

export interface NewSessionProjectRecord {
  path: string;
  name: string;
  lastUsedAt: string;
  isFavorite: boolean;
}

export interface NewSessionDraftState {
  projectPath: string;
  projectName: string;
  initialPrompt: string;
  provider: "claude" | "codex";
  selectedModel: string;
  effortLevel: string;
  outputMode: string;
  permissionMode: string;
  codexSandboxMode: "read-only" | "workspace-write" | "danger-full-access";
  codexApprovalPolicy: "untrusted" | "on-request" | "never";
  pluginDirs: string[];
  systemPrompt: string;
  maxBudget: string;
  terminalCount: number;
  advancedExpanded: boolean;
  allowedTools: string;
  disallowedTools: string;
  additionalDirs: string[];
  additionalDirInput: string;
  continueSession: boolean;
  useWorktree: boolean;
  sessionName: string;
  fallbackModel: string;
  enableChrome: boolean;
  enableBrief: boolean;
  forkSession: boolean;
}

export type NewSessionPresetId = "balanced" | "planFirst" | "safeReview" | "parallelBuild";

const favoritesKey = "doffice.new-session.favorite-projects";
const recentKey = "doffice.new-session.recent-projects";
const draftKey = "doffice.new-session.last-draft";

export const defaultNewSessionDraft: NewSessionDraftState = {
  projectPath: "",
  projectName: "",
  initialPrompt: "",
  provider: "claude",
  selectedModel: "sonnet",
  effortLevel: "medium",
  outputMode: "전체",
  permissionMode: "bypassPermissions",
  codexSandboxMode: "workspace-write",
  codexApprovalPolicy: "on-request",
  pluginDirs: [],
  systemPrompt: "",
  maxBudget: "",
  terminalCount: 1,
  advancedExpanded: false,
  allowedTools: "",
  disallowedTools: "",
  additionalDirs: [],
  additionalDirInput: "",
  continueSession: false,
  useWorktree: false,
  sessionName: "",
  fallbackModel: "",
  enableChrome: true,
  enableBrief: false,
  forkSession: false
};

export function loadFavoriteProjects(): NewSessionProjectRecord[] {
  return loadProjects(favoritesKey);
}

export function loadRecentProjects(): NewSessionProjectRecord[] {
  return loadProjects(recentKey);
}

export function loadNewSessionDraft(): NewSessionDraftState {
  try {
    const raw = window.localStorage.getItem(draftKey);
    if (!raw) return defaultNewSessionDraft;
    const parsed = JSON.parse(raw) as Partial<NewSessionDraftState>;
    const parsedModel = String(parsed.selectedModel);
    const inferredProvider =
      parsed.provider === "codex" ||
      ["gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex", "gpt-5.2-codex", "gpt-5.2", "gpt-5.1-codex-max", "gpt-5.1-codex-mini"].includes(parsedModel)
        ? "codex"
        : "claude";
    return {
      projectPath: typeof parsed.projectPath === "string" ? parsed.projectPath : defaultNewSessionDraft.projectPath,
      projectName: typeof parsed.projectName === "string" ? parsed.projectName : defaultNewSessionDraft.projectName,
      initialPrompt: typeof parsed.initialPrompt === "string" ? parsed.initialPrompt : defaultNewSessionDraft.initialPrompt,
      provider: inferredProvider,
      selectedModel: [
        "opus",
        "sonnet",
        "haiku",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.3-codex",
        "gpt-5.2-codex",
        "gpt-5.2",
        "gpt-5.1-codex-max",
        "gpt-5.1-codex-mini"
      ].includes(String(parsed.selectedModel))
        ? String(parsed.selectedModel)
        : defaultNewSessionDraft.selectedModel,
      effortLevel: ["low", "medium", "high", "max"].includes(String(parsed.effortLevel)) ? String(parsed.effortLevel) : defaultNewSessionDraft.effortLevel,
      outputMode:
        parsed.outputMode === "전체" || parsed.outputMode === "실시간" || parsed.outputMode === "결과만"
          ? parsed.outputMode
          : defaultNewSessionDraft.outputMode,
      permissionMode:
        parsed.permissionMode === "acceptEdits" ||
        parsed.permissionMode === "bypassPermissions" ||
        parsed.permissionMode === "auto" ||
        parsed.permissionMode === "default" ||
        parsed.permissionMode === "plan"
          ? parsed.permissionMode
          : defaultNewSessionDraft.permissionMode,
      codexSandboxMode:
        parsed.codexSandboxMode === "read-only" ||
        parsed.codexSandboxMode === "workspace-write" ||
        parsed.codexSandboxMode === "danger-full-access"
          ? parsed.codexSandboxMode
          : defaultNewSessionDraft.codexSandboxMode,
      codexApprovalPolicy:
        parsed.codexApprovalPolicy === "untrusted" ||
        parsed.codexApprovalPolicy === "on-request" ||
        parsed.codexApprovalPolicy === "never"
          ? parsed.codexApprovalPolicy
          : defaultNewSessionDraft.codexApprovalPolicy,
      pluginDirs: Array.isArray(parsed.pluginDirs)
        ? parsed.pluginDirs.filter((value): value is string => typeof value === "string" && value.trim().length > 0)
        : defaultNewSessionDraft.pluginDirs,
      systemPrompt: typeof parsed.systemPrompt === "string" ? parsed.systemPrompt : defaultNewSessionDraft.systemPrompt,
      maxBudget: typeof parsed.maxBudget === "string" ? parsed.maxBudget : defaultNewSessionDraft.maxBudget,
      terminalCount: [1, 2, 3, 4, 5].includes(Number(parsed.terminalCount)) ? Number(parsed.terminalCount) : defaultNewSessionDraft.terminalCount,
      advancedExpanded: typeof parsed.advancedExpanded === "boolean" ? parsed.advancedExpanded : defaultNewSessionDraft.advancedExpanded,
      allowedTools: typeof parsed.allowedTools === "string" ? parsed.allowedTools : defaultNewSessionDraft.allowedTools,
      disallowedTools: typeof parsed.disallowedTools === "string" ? parsed.disallowedTools : defaultNewSessionDraft.disallowedTools,
      additionalDirs: Array.isArray(parsed.additionalDirs)
        ? parsed.additionalDirs.filter((value): value is string => typeof value === "string" && value.trim().length > 0)
        : defaultNewSessionDraft.additionalDirs,
      additionalDirInput: typeof parsed.additionalDirInput === "string" ? parsed.additionalDirInput : defaultNewSessionDraft.additionalDirInput,
      continueSession: typeof parsed.continueSession === "boolean" ? parsed.continueSession : defaultNewSessionDraft.continueSession,
      useWorktree: typeof parsed.useWorktree === "boolean" ? parsed.useWorktree : defaultNewSessionDraft.useWorktree,
      sessionName: typeof parsed.sessionName === "string" ? parsed.sessionName : defaultNewSessionDraft.sessionName,
      fallbackModel: typeof parsed.fallbackModel === "string" ? parsed.fallbackModel : defaultNewSessionDraft.fallbackModel,
      enableChrome: typeof parsed.enableChrome === "boolean" ? parsed.enableChrome : defaultNewSessionDraft.enableChrome,
      enableBrief: typeof parsed.enableBrief === "boolean" ? parsed.enableBrief : defaultNewSessionDraft.enableBrief,
      forkSession: typeof parsed.forkSession === "boolean" ? parsed.forkSession : defaultNewSessionDraft.forkSession
    };
  } catch {
    return defaultNewSessionDraft;
  }
}

export function saveFavoriteProjects(projects: NewSessionProjectRecord[]) {
  window.localStorage.setItem(favoritesKey, JSON.stringify(projects.slice(0, 8)));
}

export function saveRecentProjects(projects: NewSessionProjectRecord[]) {
  window.localStorage.setItem(recentKey, JSON.stringify(projects.slice(0, 10)));
}

export function saveNewSessionDraft(draft: NewSessionDraftState) {
  window.localStorage.setItem(draftKey, JSON.stringify(draft));
}

export function mergeSuggestedProjects(
  sessions: SessionSnapshot[],
  favorites: NewSessionProjectRecord[],
  recents: NewSessionProjectRecord[]
): NewSessionProjectRecord[] {
  const merged = new Map<string, NewSessionProjectRecord>();

  for (const project of favorites) merged.set(project.path, project);
  for (const project of recents) mergeProject(merged, project);
  for (const session of sessions) {
    mergeProject(merged, {
      path: session.projectPath,
      name: session.projectName,
      lastUsedAt: session.lastActivityTime || session.startTime,
      isFavorite: favorites.some((project) => project.path === session.projectPath)
    });
  }

  return [...merged.values()].sort((lhs, rhs) => {
    if (lhs.isFavorite !== rhs.isFavorite) return lhs.isFavorite ? -1 : 1;
    if (lhs.lastUsedAt !== rhs.lastUsedAt) return rhs.lastUsedAt.localeCompare(lhs.lastUsedAt);
    return lhs.name.localeCompare(rhs.name, "ko", { sensitivity: "base" });
  });
}

export function toggleFavoriteProject(
  current: NewSessionProjectRecord[],
  projectPath: string,
  projectName: string
): NewSessionProjectRecord[] {
  const existingIndex = current.findIndex((project) => project.path === projectPath);
  if (existingIndex >= 0) {
    return current.filter((project) => project.path !== projectPath);
  }
  const record: NewSessionProjectRecord = {
    path: projectPath,
    name: projectName || inferProjectName(projectPath),
    lastUsedAt: new Date().toISOString(),
    isFavorite: true
  };
  return dedupeProjects([record, ...current]).slice(0, 8);
}

export function rememberProjectLaunch(
  current: NewSessionProjectRecord[],
  projectPath: string,
  projectName: string,
  isFavorite: boolean
): NewSessionProjectRecord[] {
  const record: NewSessionProjectRecord = {
    path: projectPath,
    name: projectName || inferProjectName(projectPath),
    lastUsedAt: new Date().toISOString(),
    isFavorite
  };
  return dedupeProjects([record, ...current]).slice(0, 10);
}

export function applyDraftPreset(draft: NewSessionDraftState, preset: NewSessionPresetId): NewSessionDraftState {
  switch (preset) {
    case "balanced":
      return {
        ...draft,
        provider: "claude",
        selectedModel: "sonnet",
        effortLevel: "medium",
        permissionMode: "bypassPermissions",
        terminalCount: 1,
        continueSession: false,
        useWorktree: false
      };
    case "planFirst":
      return {
        ...draft,
        provider: "claude",
        selectedModel: "sonnet",
        effortLevel: "medium",
        permissionMode: "plan",
        terminalCount: 1,
        continueSession: false,
        useWorktree: false
      };
    case "safeReview":
      return {
        ...draft,
        provider: "claude",
        selectedModel: "sonnet",
        effortLevel: "high",
        permissionMode: "default",
        terminalCount: 1,
        continueSession: true,
        useWorktree: false
      };
    case "parallelBuild":
      return {
        ...draft,
        provider: "claude",
        selectedModel: "sonnet",
        effortLevel: "high",
        permissionMode: "bypassPermissions",
        terminalCount: 3,
        continueSession: false,
        useWorktree: true
      };
  }
}

export function relativeProjectTime(value: string): string {
  const diff = Date.now() - new Date(value).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function loadProjects(key: string): NewSessionProjectRecord[] {
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as NewSessionProjectRecord[];
    return Array.isArray(parsed)
      ? parsed.filter(
          (project) =>
            project &&
            typeof project.path === "string" &&
            typeof project.name === "string" &&
            typeof project.lastUsedAt === "string" &&
            typeof project.isFavorite === "boolean"
        )
      : [];
  } catch {
    return [];
  }
}

function mergeProject(store: Map<string, NewSessionProjectRecord>, project: NewSessionProjectRecord) {
  const existing = store.get(project.path);
  if (!existing) {
    store.set(project.path, project);
    return;
  }
  store.set(project.path, {
    path: project.path,
    name: existing.name.length >= project.name.length ? existing.name : project.name,
    lastUsedAt: existing.lastUsedAt > project.lastUsedAt ? existing.lastUsedAt : project.lastUsedAt,
    isFavorite: existing.isFavorite || project.isFavorite
  });
}

function dedupeProjects(projects: NewSessionProjectRecord[]): NewSessionProjectRecord[] {
  const seen = new Set<string>();
  return projects.filter((project) => {
    if (seen.has(project.path)) return false;
    seen.add(project.path);
    return true;
  });
}

function inferProjectName(projectPath: string): string {
  const normalized = projectPath.replace(/[\\/]+$/, "");
  const pieces = normalized.split(/[\\/]/);
  return pieces[pieces.length - 1] || projectPath;
}
