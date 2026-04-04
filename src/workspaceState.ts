import { setPreferredLocale } from "./localizationCatalog";
import type { SessionSnapshot } from "./types";
import {
  macAchievementCatalog,
  macBackgroundCatalog,
  macCharacterCatalog,
  macFurnitureCatalog,
  macJobMeta,
  macSpeciesMeta,
  type MacAchievementTier,
  type MacCharacterSpecies,
  type MacWorkerJob
} from "./macParityData";

export type WorkspaceThemeMode = "dark" | "light" | "custom";
export type WorkspaceBackgroundTheme = string;
export type WorkspaceFontScale = "s" | "m" | "l" | "xl" | "xxl";
export type WorkflowStyle = "planner" | "designer" | "implementation" | "rework" | "review" | "qa" | "report" | "sre";
export type OfficeLayoutPreset = "cozy" | "collab" | "focus";
export type OfficeCameraMode = "overview" | "focus";
export type WorkspaceLanguage = "system" | "ko" | "en" | "ja";

export interface BrowserWorkspaceTab {
  id: string;
  title: string;
  url: string;
}

export interface WorkspacePreferences {
  workspaceName: string;
  companyName: string;
  secretKey: string;
  language: WorkspaceLanguage;
  rawTerminalMode: boolean;
  autoRefreshOnSettingsChange: boolean;
  themeMode: WorkspaceThemeMode;
  backgroundTheme: WorkspaceBackgroundTheme;
  fontScale: WorkspaceFontScale;
  workflowStyle: WorkflowStyle;
  officeLayout: OfficeLayoutPreset;
  officeCamera: OfficeCameraMode;
  lockPin: string;
  isLocked: boolean;
  autoLockMinutes: number;
  billingDay: number;
  allowParallelAgents: boolean;
  terminalSidebarLightweight: boolean;
  reviewerMaxPasses: number;
  qaMaxPasses: number;
  automationRevisionLimit: number;
  dailyBudgetUSD: number;
  sessionBudgetUSD: number;
  tokenProtectionEnabled: boolean;
  claudeSessionTokenLimit: number;
  codexSessionTokenLimit: number;
  geminiSessionTokenLimit: number;
  claudeWeeklyLimit: number;
  codexWeeklyLimit: number;
  geminiWeeklyLimit: number;
  claudePlanName: string;
  codexPlanName: string;
  geminiPlanName: string;
  warnAtBudgetThreshold: boolean;
  protectDangerousCommands: boolean;
  protectSensitiveFiles: boolean;
  hiredCharacterIds: string[];
  vacationCharacterIds: string[];
  characterJobOverrides: Record<string, MacWorkerJob>;
  enabledAccessoryIds: string[];
  browserTabs: BrowserWorkspaceTab[];
  browserActiveTabId: string;
  browserBookmarks: string[];
}

export interface CharacterDefinition {
  id: string;
  name: string;
  role: string;
  skill: string;
  species: MacCharacterSpecies;
  emoji: string;
  hairColor: string;
  skinTone: string;
  shirtColor: string;
  pantsColor: string;
  hatType: string;
  accessory: string;
  requiredAchievement: string | null;
  jobRole: MacWorkerJob;
  isStarter: boolean;
}

export interface AccessoryDefinition {
  id: string;
  name: string;
  icon: string;
  officeKinds: string[];
  width: number;
  height: number;
  isWallItem: boolean;
  requiredLevel: number | null;
  requiredAchievement: string | null;
}

export interface BackgroundDefinition {
  id: string;
  label: string;
  icon: string;
  requiredLevel: number | null;
}

export interface WorkspaceAchievement {
  id: string;
  tier: MacAchievementTier;
  title: string;
  subtitle: string;
  xp: number;
  icon: string;
  unlocked: boolean;
}

export interface WorkspaceProgress {
  totalXP: number;
  level: number;
  levelTitle: string;
  completionRate: number;
}

const workspaceStorageKey = "doffice.workspace-preferences";

const accessoryOfficeKinds: Record<string, string[]> = {
  sofa: ["sofa"],
  sideTable: ["round-table", "meeting-table"],
  coffeeMachine: ["coffee", "water"],
  plant: ["plant"],
  picture: ["picture"],
  neonSign: [],
  rug: [],
  bookshelf: ["shelf"],
  aquarium: [],
  arcade: ["trash"],
  whiteboard: ["board"],
  lamp: ["lamp"],
  cat: [],
  tv: [],
  fan: [],
  calendar: [],
  poster: [],
  trashcan: ["trash"],
  cushion: []
};

export const totalCharacterCount = macCharacterCatalog.length;
export const totalAccessoryCount = macFurnitureCatalog.length;
export const totalAchievementCount = macAchievementCatalog.length;

export const speciesCatalog = macSpeciesMeta;
export const jobCatalog = macJobMeta;

export const allCharacters: CharacterDefinition[] = macCharacterCatalog.map((character) => ({
  id: character.id,
  name: character.name,
  role: character.archetype || "숨겨진 캐릭터",
  skill: macJobMeta[character.jobRole].label,
  species: character.species,
  emoji: macSpeciesMeta[character.species].emoji,
  hairColor: character.hairColor,
  skinTone: character.skinTone,
  shirtColor: character.shirtColor,
  pantsColor: character.pantsColor,
  hatType: character.hatType,
  accessory: character.accessory,
  requiredAchievement: character.requiredAchievement,
  jobRole: character.jobRole,
  isStarter: character.isHired
}));

export const accessoryCatalog: AccessoryDefinition[] = macFurnitureCatalog.map((item) => ({
  id: item.id,
  name: item.name,
  icon: item.icon,
  officeKinds: accessoryOfficeKinds[item.id] ?? [],
  width: item.width,
  height: item.height,
  isWallItem: item.isWallItem,
  requiredLevel: item.requiredLevel,
  requiredAchievement: item.requiredAchievement
}));

export const backgroundCatalog: BackgroundDefinition[] = macBackgroundCatalog;

export const defaultBrowserBookmarks = [
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
  "http://localhost:4000"
];

export const defaultWorkspacePreferences: WorkspacePreferences = {
  workspaceName: "Doffice",
  companyName: "Claude Code Manager",
  secretKey: "",
  language: "system",
  rawTerminalMode: false,
  autoRefreshOnSettingsChange: true,
  themeMode: "dark",
  backgroundTheme: "sunny",
  fontScale: "l",
  workflowStyle: "planner",
  officeLayout: "cozy",
  officeCamera: "overview",
  lockPin: "",
  isLocked: false,
  autoLockMinutes: 0,
  billingDay: 0,
  allowParallelAgents: false,
  terminalSidebarLightweight: false,
  reviewerMaxPasses: 1,
  qaMaxPasses: 1,
  automationRevisionLimit: 2,
  dailyBudgetUSD: 0,
  sessionBudgetUSD: 0,
  tokenProtectionEnabled: true,
  claudeSessionTokenLimit: 0,
  codexSessionTokenLimit: 0,
  geminiSessionTokenLimit: 0,
  claudeWeeklyLimit: 0,
  codexWeeklyLimit: 0,
  geminiWeeklyLimit: 0,
  claudePlanName: "",
  codexPlanName: "",
  geminiPlanName: "",
  warnAtBudgetThreshold: true,
  protectDangerousCommands: true,
  protectSensitiveFiles: true,
  hiredCharacterIds: allCharacters.filter((character) => character.isStarter).map((character) => character.id),
  vacationCharacterIds: [],
  characterJobOverrides: {},
  enabledAccessoryIds: ["sofa", "coffeeMachine", "whiteboard"],
  browserTabs: [{ id: "tab-0", title: "New Tab", url: "https://www.google.com" }],
  browserActiveTabId: "tab-0",
  browserBookmarks: defaultBrowserBookmarks
};

function normalizeStringArray(values: unknown, fallback: string[]): string[] {
  return Array.isArray(values) ? values.filter((value): value is string => typeof value === "string") : fallback;
}

function normalizeJobOverrides(values: unknown): Record<string, MacWorkerJob> {
  if (!values || typeof values !== "object") return {};
  const result: Record<string, MacWorkerJob> = {};
  for (const [key, value] of Object.entries(values as Record<string, unknown>)) {
    if (
      value === "developer" ||
      value === "qa" ||
      value === "reporter" ||
      value === "boss" ||
      value === "planner" ||
      value === "reviewer" ||
      value === "designer" ||
      value === "sre"
    ) {
      result[key] = value;
    }
  }
  return result;
}

function normalizeBackgroundTheme(value: unknown): WorkspaceBackgroundTheme {
  const raw = typeof value === "string" ? value : "";
  switch (raw) {
    case "auto":
    case "sunny":
    case "clearSky":
    case "sunset":
    case "goldenHour":
    case "dusk":
    case "moonlit":
    case "starryNight":
    case "aurora":
    case "milkyWay":
    case "storm":
    case "rain":
    case "snow":
    case "fog":
    case "cherryBlossom":
    case "autumn":
    case "forest":
    case "neonCity":
    case "ocean":
    case "desert":
    case "volcano":
      return raw;
    case "clear-day":
      return "sunny";
    case "blue-sky":
      return "clearSky";
    case "moonlight":
      return "moonlit";
    case "neon":
      return "neonCity";
    default:
      return defaultWorkspacePreferences.backgroundTheme;
  }
}

export function loadWorkspacePreferences(): WorkspacePreferences {
  try {
    const raw = window.localStorage.getItem(workspaceStorageKey);
    if (!raw) return defaultWorkspacePreferences;
    const parsed = JSON.parse(raw) as Partial<WorkspacePreferences>;
    return {
      workspaceName: typeof parsed.workspaceName === "string" ? parsed.workspaceName : defaultWorkspacePreferences.workspaceName,
      companyName: typeof parsed.companyName === "string" ? parsed.companyName : defaultWorkspacePreferences.companyName,
      secretKey: typeof parsed.secretKey === "string" ? parsed.secretKey : defaultWorkspacePreferences.secretKey,
      language: parsed.language === "ko" || parsed.language === "en" || parsed.language === "ja" || parsed.language === "system" ? parsed.language : defaultWorkspacePreferences.language,
      rawTerminalMode: typeof parsed.rawTerminalMode === "boolean" ? parsed.rawTerminalMode : defaultWorkspacePreferences.rawTerminalMode,
      autoRefreshOnSettingsChange:
        typeof parsed.autoRefreshOnSettingsChange === "boolean"
          ? parsed.autoRefreshOnSettingsChange
          : defaultWorkspacePreferences.autoRefreshOnSettingsChange,
      themeMode: parsed.themeMode === "light" || parsed.themeMode === "custom" || parsed.themeMode === "dark" ? parsed.themeMode : defaultWorkspacePreferences.themeMode,
      backgroundTheme: normalizeBackgroundTheme(parsed.backgroundTheme),
      fontScale: parsed.fontScale === "s" || parsed.fontScale === "m" || parsed.fontScale === "l" || parsed.fontScale === "xl" || parsed.fontScale === "xxl" ? parsed.fontScale : defaultWorkspacePreferences.fontScale,
      workflowStyle:
        parsed.workflowStyle === "designer" ||
        parsed.workflowStyle === "implementation" ||
        parsed.workflowStyle === "rework" ||
        parsed.workflowStyle === "review" ||
        parsed.workflowStyle === "qa" ||
        parsed.workflowStyle === "report" ||
        parsed.workflowStyle === "sre" ||
        parsed.workflowStyle === "planner"
          ? parsed.workflowStyle
          : defaultWorkspacePreferences.workflowStyle,
      officeLayout: parsed.officeLayout === "collab" || parsed.officeLayout === "focus" || parsed.officeLayout === "cozy" ? parsed.officeLayout : defaultWorkspacePreferences.officeLayout,
      officeCamera: parsed.officeCamera === "focus" || parsed.officeCamera === "overview" ? parsed.officeCamera : defaultWorkspacePreferences.officeCamera,
      lockPin: typeof parsed.lockPin === "string" ? parsed.lockPin : defaultWorkspacePreferences.lockPin,
      isLocked: typeof parsed.isLocked === "boolean" ? parsed.isLocked : defaultWorkspacePreferences.isLocked,
      autoLockMinutes: typeof parsed.autoLockMinutes === "number" ? parsed.autoLockMinutes : defaultWorkspacePreferences.autoLockMinutes,
      billingDay: typeof parsed.billingDay === "number" ? parsed.billingDay : defaultWorkspacePreferences.billingDay,
      allowParallelAgents: typeof parsed.allowParallelAgents === "boolean" ? parsed.allowParallelAgents : defaultWorkspacePreferences.allowParallelAgents,
      terminalSidebarLightweight:
        typeof parsed.terminalSidebarLightweight === "boolean"
          ? parsed.terminalSidebarLightweight
          : defaultWorkspacePreferences.terminalSidebarLightweight,
      reviewerMaxPasses: typeof parsed.reviewerMaxPasses === "number" ? parsed.reviewerMaxPasses : defaultWorkspacePreferences.reviewerMaxPasses,
      qaMaxPasses: typeof parsed.qaMaxPasses === "number" ? parsed.qaMaxPasses : defaultWorkspacePreferences.qaMaxPasses,
      automationRevisionLimit:
        typeof parsed.automationRevisionLimit === "number"
          ? parsed.automationRevisionLimit
          : defaultWorkspacePreferences.automationRevisionLimit,
      dailyBudgetUSD: typeof parsed.dailyBudgetUSD === "number" ? parsed.dailyBudgetUSD : defaultWorkspacePreferences.dailyBudgetUSD,
      sessionBudgetUSD: typeof parsed.sessionBudgetUSD === "number" ? parsed.sessionBudgetUSD : defaultWorkspacePreferences.sessionBudgetUSD,
      tokenProtectionEnabled:
        typeof parsed.tokenProtectionEnabled === "boolean"
          ? parsed.tokenProtectionEnabled
          : defaultWorkspacePreferences.tokenProtectionEnabled,
      claudeSessionTokenLimit:
        typeof parsed.claudeSessionTokenLimit === "number" ? parsed.claudeSessionTokenLimit : defaultWorkspacePreferences.claudeSessionTokenLimit,
      codexSessionTokenLimit:
        typeof parsed.codexSessionTokenLimit === "number" ? parsed.codexSessionTokenLimit : defaultWorkspacePreferences.codexSessionTokenLimit,
      geminiSessionTokenLimit:
        typeof parsed.geminiSessionTokenLimit === "number" ? parsed.geminiSessionTokenLimit : defaultWorkspacePreferences.geminiSessionTokenLimit,
      claudeWeeklyLimit:
        typeof parsed.claudeWeeklyLimit === "number" ? parsed.claudeWeeklyLimit : defaultWorkspacePreferences.claudeWeeklyLimit,
      codexWeeklyLimit:
        typeof parsed.codexWeeklyLimit === "number" ? parsed.codexWeeklyLimit : defaultWorkspacePreferences.codexWeeklyLimit,
      geminiWeeklyLimit:
        typeof parsed.geminiWeeklyLimit === "number" ? parsed.geminiWeeklyLimit : defaultWorkspacePreferences.geminiWeeklyLimit,
      claudePlanName:
        typeof parsed.claudePlanName === "string" ? parsed.claudePlanName : defaultWorkspacePreferences.claudePlanName,
      codexPlanName:
        typeof parsed.codexPlanName === "string" ? parsed.codexPlanName : defaultWorkspacePreferences.codexPlanName,
      geminiPlanName:
        typeof parsed.geminiPlanName === "string" ? parsed.geminiPlanName : defaultWorkspacePreferences.geminiPlanName,
      warnAtBudgetThreshold: typeof parsed.warnAtBudgetThreshold === "boolean" ? parsed.warnAtBudgetThreshold : defaultWorkspacePreferences.warnAtBudgetThreshold,
      protectDangerousCommands: typeof parsed.protectDangerousCommands === "boolean" ? parsed.protectDangerousCommands : defaultWorkspacePreferences.protectDangerousCommands,
      protectSensitiveFiles: typeof parsed.protectSensitiveFiles === "boolean" ? parsed.protectSensitiveFiles : defaultWorkspacePreferences.protectSensitiveFiles,
      hiredCharacterIds: normalizeStringArray(parsed.hiredCharacterIds, defaultWorkspacePreferences.hiredCharacterIds),
      vacationCharacterIds: normalizeStringArray(parsed.vacationCharacterIds, defaultWorkspacePreferences.vacationCharacterIds),
      characterJobOverrides: normalizeJobOverrides(parsed.characterJobOverrides),
      enabledAccessoryIds: normalizeStringArray(parsed.enabledAccessoryIds, defaultWorkspacePreferences.enabledAccessoryIds),
      browserTabs:
        Array.isArray(parsed.browserTabs) && parsed.browserTabs.every((tab) => tab && typeof tab.id === "string" && typeof tab.title === "string" && typeof tab.url === "string")
          ? parsed.browserTabs
          : defaultWorkspacePreferences.browserTabs,
      browserActiveTabId: typeof parsed.browserActiveTabId === "string" ? parsed.browserActiveTabId : defaultWorkspacePreferences.browserActiveTabId,
      browserBookmarks: normalizeStringArray(parsed.browserBookmarks, defaultWorkspacePreferences.browserBookmarks)
    };
  } catch {
    return defaultWorkspacePreferences;
  }
}

export function saveWorkspacePreferences(preferences: WorkspacePreferences) {
  window.localStorage.setItem(workspaceStorageKey, JSON.stringify(preferences));
}

export function applyWorkspacePreferences(preferences: WorkspacePreferences) {
  const root = document.documentElement;
  setPreferredLocale(preferences.language === "system" ? null : preferences.language);
  root.lang = preferences.language === "system"
    ? (typeof navigator !== "undefined" && navigator.language ? navigator.language : "ko")
    : preferences.language;
  root.dataset.themeMode = preferences.themeMode;
  root.dataset.backgroundTheme = preferences.backgroundTheme;
  root.dataset.fontScale = preferences.fontScale;
  root.dataset.appName = (preferences.workspaceName || "Doffice").trim() || "Doffice";
}

function compactLevelTitle(level: number): string {
  if (level >= 50) return "차원";
  if (level >= 25) return "우주";
  if (level >= 16) return "전설";
  if (level >= 10) return "영웅";
  if (level >= 5) return "희귀";
  return "일반";
}

function parseMagnitudeToken(id: string): number | null {
  const match = id.match(/^token_(?:first_)?(\d+)(k)?_(?:total|session)$/);
  if (!match) return null;
  const value = Number(match[1]);
  return match[2] ? value * 1000 : value;
}

function minutesBetween(startISO: string, endISO: string): number {
  const start = new Date(startISO).getTime();
  const end = new Date(endISO).getTime();
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return 0;
  return Math.round((end - start) / 60000);
}

function deriveAchievementUnlocks(preferences: WorkspacePreferences, sessions: SessionSnapshot[], progress: WorkspaceProgress) {
  const totalTokens = sessions.reduce((sum, session) => sum + session.tokensUsed, 0);
  const totalCost = sessions.reduce((sum, session) => sum + session.totalCost, 0);
  const startedSessions = sessions.length;
  const completedSessions = sessions.filter((session) => session.isCompleted).length;
  const totalCommands = sessions.reduce((sum, session) => sum + session.completedPromptCount, 0);
  const totalFileEdits = sessions.reduce((sum, session) => sum + session.fileChanges.length, 0);
  const totalReads = sessions.reduce(
    (sum, session) =>
      sum +
      session.blocks.filter(
        (block) =>
          block.kind === "toolUse" &&
          /(read|cat|sed|find|search|open|glob|rg)/i.test(block.content)
      ).length,
    0
  );
  const activeDays = new Set(sessions.map((session) => session.startTime.slice(0, 10)).filter(Boolean)).size;
  const uniqueBranches = new Set(sessions.map((session) => session.branch).filter(Boolean)).size;
  const longestSessionMinutes = sessions.reduce(
    (max, session) => Math.max(max, minutesBetween(session.startTime, session.lastActivityTime)),
    0
  );
  const longestSessionTokens = sessions.reduce((max, session) => Math.max(max, session.tokensUsed), 0);
  const hires = preferences.hiredCharacterIds.length;
  const enabledAccessories = preferences.enabledAccessoryIds.length;

  const explicitUnlocks = new Set<string>();
  if (startedSessions >= 1) explicitUnlocks.add("first_session");
  if (completedSessions >= 1) explicitUnlocks.add("first_complete");
  if (totalCommands >= 1) explicitUnlocks.add("first_bash");
  if (totalFileEdits >= 1) explicitUnlocks.add("first_edit");
  if (enabledAccessories >= 1) explicitUnlocks.add("office");
  if (hires >= 5) explicitUnlocks.add("team");
  if (sessions.some((session) => Boolean(session.pendingApproval))) explicitUnlocks.add("pair_programmer");
  if (sessions.some((session) => session.provider === "claude" && /opus/i.test(session.selectedModel))) explicitUnlocks.add("opus_user");
  if (sessions.some((session) => session.provider === "claude" && /haiku/i.test(session.selectedModel))) explicitUnlocks.add("haiku_user");
  if (sessions.some((session) => session.provider === "codex")) explicitUnlocks.add("three_models");
  if (sessions.some((session) => Boolean(session.dangerousCommandWarning) || Boolean(session.sensitiveFileWarning))) explicitUnlocks.add("bug_squasher");

  return {
    explicitUnlocks,
    totalTokens,
    totalCost,
    startedSessions,
    completedSessions,
    totalCommands,
    totalFileEdits,
    totalReads,
    activeDays,
    uniqueBranches,
    longestSessionMinutes,
    longestSessionTokens,
    progress
  };
}

function isAchievementUnlocked(
  achievementId: string,
  derived: ReturnType<typeof deriveAchievementUnlocks>
): boolean {
  if (derived.explicitUnlocks.has(achievementId)) return true;

  const tokenMagnitude = parseMagnitudeToken(achievementId);
  if (tokenMagnitude != null) {
    if (achievementId.endsWith("_total")) return derived.totalTokens >= tokenMagnitude;
    if (achievementId.endsWith("_session")) return derived.longestSessionTokens >= tokenMagnitude;
  }

  let match = achievementId.match(/^session_(\d+)$/);
  if (match) return derived.startedSessions >= Number(match[1]);

  match = achievementId.match(/^complete_(\d+)$/);
  if (match) return derived.completedSessions >= Number(match[1]);

  match = achievementId.match(/^command_(\d+)$/);
  if (match) return derived.totalCommands >= Number(match[1]);

  match = achievementId.match(/^file_edit_(\d+)$/);
  if (match) return derived.totalFileEdits >= Number(match[1]);

  match = achievementId.match(/^read_(\d+)$/);
  if (match) return derived.totalReads >= Number(match[1]);

  match = achievementId.match(/^git_branch_(\d+)$/);
  if (match) return derived.uniqueBranches >= Number(match[1]);

  match = achievementId.match(/^focus_(\d+)$/);
  if (match) return derived.longestSessionMinutes >= Number(match[1]);

  match = achievementId.match(/^cost_(\d+)$/);
  if (match) return derived.totalCost >= Number(match[1]);

  match = achievementId.match(/^level_(\d+)$/);
  if (match) return derived.progress.level >= Number(match[1]);

  match = achievementId.match(/^session_streak_(\d+)$/);
  if (match) return derived.activeDays >= Number(match[1]);

  switch (achievementId) {
    case "marathon":
      return derived.longestSessionMinutes >= 60;
    case "ultra_marathon":
      return derived.longestSessionMinutes >= 180;
    case "night_marathon":
      return derived.longestSessionMinutes >= 60 && derived.activeDays >= 1;
    case "git_first_branch":
      return derived.uniqueBranches >= 1;
    case "git_master":
      return derived.totalFileEdits >= 10;
    case "git_master_25":
      return derived.totalFileEdits >= 25;
    case "token_whale":
      return derived.longestSessionTokens >= 10000;
    case "speed_demon":
      return derived.completedSessions >= 1 && derived.longestSessionMinutes <= 5 && derived.longestSessionMinutes > 0;
    case "speed_2min":
      return derived.completedSessions >= 1 && derived.longestSessionMinutes <= 2 && derived.longestSessionMinutes > 0;
    case "night_owl":
    case "night_complete":
      return derived.activeDays >= 1 && derived.startedSessions >= 1;
    case "weekend_warrior":
    case "lunch_coder":
    case "morning_complete":
      return derived.startedSessions >= 1;
    case "five_sessions":
      return derived.startedSessions >= 5;
    case "mythic_perfectionist":
      return false;
    case "true_god":
      return false;
    default:
      return false;
  }
}

export function deriveWorkspaceProgress(
  preferences: WorkspacePreferences,
  sessions: SessionSnapshot[],
  reportCount: number
): WorkspaceProgress {
  const totalTokens = sessions.reduce((sum, session) => sum + session.tokensUsed, 0);
  const completedSessions = sessions.filter((session) => session.isCompleted).length;
  const activeSessions = sessions.filter((session) => session.isRunning || session.isProcessing).length;
  const totalXP =
    Math.round(totalTokens / 60) +
    completedSessions * 180 +
    activeSessions * 50 +
    preferences.hiredCharacterIds.length * 160 +
    preferences.enabledAccessoryIds.length * 80 +
    reportCount * 120;
  const level = Math.max(1, Math.floor(totalXP / 420) + 1);
  return {
    totalXP,
    level,
    levelTitle: compactLevelTitle(level),
    completionRate: Math.max(1, Math.min(100, Math.round((level / 50) * 100)))
  };
}

export function buildWorkspaceAchievements(
  preferences: WorkspacePreferences,
  sessions: SessionSnapshot[],
  reportCount: number
): WorkspaceAchievement[] {
  const progress = deriveWorkspaceProgress(preferences, sessions, reportCount);
  const derived = deriveAchievementUnlocks(preferences, sessions, progress);
  return macAchievementCatalog.map((achievement) => ({
    id: achievement.id,
    tier: achievement.tier,
    title: achievement.title,
    subtitle: achievement.subtitle,
    xp: achievement.xp,
    icon: achievement.icon,
    unlocked: isAchievementUnlocked(achievement.id, derived)
  }));
}
