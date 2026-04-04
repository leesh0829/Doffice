import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import type { AgentProvider, CLIInstallResult, CLIStatus, CLIStatusPayload, PluginInstallResult, ReportReference, SessionSnapshot } from "./types";
import { t, tf } from "./localizationCatalog";
import { relativeTime } from "./sessionUtils";
import { pluginRegistry, type PluginRegistryEntry } from "./pluginRegistry";
import { type InstalledPluginRecord, loadInstalledPlugins, saveInstalledPlugins } from "./pluginInstallState";
import {
  applyWorkspacePreferences,
  buildWorkspaceAchievements,
  defaultWorkspacePreferences,
  getAccessoryCatalog,
  getAllCharacters,
  getBackgroundCatalog,
  getTotalAchievementCount,
  getTotalCharacterCount,
  jobCatalog,
  saveWorkspacePreferences,
  speciesCatalog,
  type AccessoryDefinition,
  type BackgroundDefinition,
  type CharacterDefinition,
  type WorkspaceAchievement,
  type WorkspacePreferences,
  type WorkspaceProgress
} from "./workspaceState";

export type WorkspacePanelKind = "settings" | "characters" | "accessories" | "reports" | "achievements" | "lock";

interface WorkspaceOverlayManagerProps {
  kind: WorkspacePanelKind | null;
  onClose: () => void;
  selectedSession: SessionSnapshot | null;
  sessions: SessionSnapshot[];
  claudeStatus: CLIStatus;
  codexStatus: CLIStatus;
  geminiStatus: CLIStatus;
  refreshCLIStatuses: () => Promise<CLIStatusPayload>;
  installCLI: (provider: AgentProvider) => Promise<CLIInstallResult>;
  totals: {
    active: number;
    processing: number;
    attention: number;
    completed: number;
    tokens: number;
  };
  preferences: WorkspacePreferences;
  updatePreferences: (patch: Partial<WorkspacePreferences> | ((current: WorkspacePreferences) => WorkspacePreferences)) => void;
  reportEntries: ReportReference[];
  reportLoading: boolean;
  refreshReports: () => Promise<void>;
  achievements: WorkspaceAchievement[];
  progress: WorkspaceProgress;
}

type SettingsTab = "general" | "theme" | "office" | "tokens" | "data" | "template" | "plugins" | "support" | "security" | "shortcuts";
type PluginSection = "installed" | "marketplace";

const settingsTabs: Array<{ id: SettingsTab; labelKey: string; icon: string }> = [
  { id: "general", labelKey: "settings.tab.general", icon: "☰" },
  { id: "theme", labelKey: "settings.tab.theme", icon: "🖌" },
  { id: "office", labelKey: "settings.tab.office", icon: "🏢" },
  { id: "tokens", labelKey: "settings.tab.tokens", icon: "⚡" },
  { id: "data", labelKey: "settings.tab.data", icon: "🗃" },
  { id: "template", labelKey: "settings.tab.template", icon: "📄" },
  { id: "plugins", labelKey: "settings.tab.plugins", icon: "🧩" },
  { id: "support", labelKey: "settings.tab.support", icon: "☕" },
  { id: "security", labelKey: "settings.tab.security", icon: "🛡" },
  { id: "shortcuts", labelKey: "settings.tab.shortcuts", icon: "⌨" }
];

const workflowChoices = [
  { id: "planner", label: "기획자", icon: "🗎", tone: "green", subtitle: "사용자 요구사항을 개발 가능한 실행 계획으로 정리합니다." },
  { id: "designer", label: "디자이너", icon: "🖌", tone: "purple", subtitle: "UI/UX 흐름과 상호작용을 메모와 정리합니다." },
  { id: "implementation", label: "구현", icon: "🔨", tone: "blue", subtitle: "개발자가 처음 구현할 때 쓰는 지시문입니다." },
  { id: "rework", label: "재작업", icon: "↻", tone: "green", subtitle: "수정 반복과 후속 반영 중심으로 정리하는 재작업 양식입니다." },
  { id: "review", label: "코드 리뷰어", icon: "☑", tone: "orange", subtitle: "변경 파일과 리스크를 검토하는 리뷰 방식입니다." },
  { id: "qa", label: "QA", icon: "🗹", tone: "red", subtitle: "실행 테스트 관점에서 검증하는 QA 방식입니다." },
  { id: "report", label: "보고서", icon: "📄", tone: "blue", subtitle: "최종 Markdown 보고서 구조와 작성 지침입니다." },
  { id: "sre", label: "SRE", icon: "🖳", tone: "yellow", subtitle: "배포/운영 안정성 점검 방식입니다." }
];

const providerPlanCatalog = {
  claude: [
    { name: "Pro", weeklyLimit: 25_000_000 },
    { name: "Max 5x", weeklyLimit: 125_000_000 },
    { name: "Max 20x", weeklyLimit: 500_000_000 },
    { name: "Team", weeklyLimit: 50_000_000 },
    { name: "Enterprise", weeklyLimit: 100_000_000 }
  ],
  codex: [
    { name: "Pro", weeklyLimit: 30_000_000 },
    { name: "Team", weeklyLimit: 60_000_000 }
  ],
  gemini: [
    { name: "Advanced", weeklyLimit: 40_000_000 },
    { name: "Business", weeklyLimit: 80_000_000 }
  ]
} as const;

const backgroundChoices = getBackgroundCatalog();

const pluginMarketplace = pluginRegistry;

type PluginEntryLike = Pick<PluginRegistryEntry, "id" | "name" | "author" | "version" | "tags">;

function buildInstalledPluginRecord(
  installed: PluginInstallResult,
  registryEntry?: PluginEntryLike,
  fallbackTitle?: string
): InstalledPluginRecord {
  return {
    id: installed.id || `plugin-${Date.now()}`,
    title: fallbackTitle ?? registryEntry?.name ?? installed.title,
    source: installed.source,
    localPath: installed.localPath,
    enabled: true,
    shared: false,
    marketplaceId: registryEntry?.id ?? null,
    author: registryEntry?.author ?? installed.author ?? "Unknown",
    version: registryEntry?.version ?? installed.version ?? "",
    tags: registryEntry?.tags ?? installed.tags ?? []
  };
}

const defaultTemplateText: Record<WorkspacePreferences["workflowStyle"], string> = {
  planner: "요구사항을 개발 가능한 계획으로 정리하고 핵심 리스크를 먼저 적습니다.",
  designer: "UI/UX, 상호작용, 사용자 흐름 중심으로 정리합니다.",
  implementation: "바로 구현 가능한 단계와 검증 명령을 포함해 작성합니다.",
  rework: "이전 결과와 차이를 먼저 짚고 수정해야 할 항목과 재검증 단계를 적습니다.",
  review: "버그, 회귀, 누락 테스트를 우선 검토합니다.",
  qa: "재현 절차, 기대 결과, 실패 조건을 명확히 씁니다.",
  report: "최종 보고서는 Markdown 제목과 근거를 포함합니다.",
  sre: "배포 안정성, 롤백, 모니터링 포인트를 포함합니다."
};

const templateStorageKey = "doffice.settings.templates";
const shortcutStorageKey = "doffice.settings.shortcuts";

function loadTemplateDrafts(): Record<WorkspacePreferences["workflowStyle"], string> {
  try {
    const raw = window.localStorage.getItem(templateStorageKey);
    if (!raw) return defaultTemplateText;
    const parsed = JSON.parse(raw) as Partial<Record<WorkspacePreferences["workflowStyle"], string>>;
    return {
      planner: typeof parsed.planner === "string" ? parsed.planner : defaultTemplateText.planner,
      designer: typeof parsed.designer === "string" ? parsed.designer : defaultTemplateText.designer,
      implementation: typeof parsed.implementation === "string" ? parsed.implementation : defaultTemplateText.implementation,
      rework: typeof parsed.rework === "string" ? parsed.rework : defaultTemplateText.rework,
      review: typeof parsed.review === "string" ? parsed.review : defaultTemplateText.review,
      qa: typeof parsed.qa === "string" ? parsed.qa : defaultTemplateText.qa,
      report: typeof parsed.report === "string" ? parsed.report : defaultTemplateText.report,
      sre: typeof parsed.sre === "string" ? parsed.sre : defaultTemplateText.sre
    };
  } catch {
    return defaultTemplateText;
  }
}

function saveTemplateDrafts(nextDrafts: Record<WorkspacePreferences["workflowStyle"], string>) {
  window.localStorage.setItem(templateStorageKey, JSON.stringify(nextDrafts));
}

function loadShortcutDrafts() {
  try {
    const raw = window.localStorage.getItem(shortcutStorageKey);
    if (!raw) return defaultShortcutDrafts;
    return { ...defaultShortcutDrafts, ...(JSON.parse(raw) as Record<string, string>) };
  } catch {
    return defaultShortcutDrafts;
  }
}

function saveShortcutDrafts(nextDrafts: Record<string, string>) {
  window.localStorage.setItem(shortcutStorageKey, JSON.stringify(nextDrafts));
}

const shortcutRowsSession = [
  { key: "새로고침", labelKey: "settings.shortcuts.refresh", icon: "📄" },
  { key: "새 세션", labelKey: "settings.shortcuts.new.session", icon: "📄" },
  { key: "세션 닫기", labelKey: "settings.shortcuts.close.session", icon: "📄" },
  { key: "사이드바 토글", labelKey: "settings.shortcuts.sidebar.toggle", icon: "📄" }
];

const shortcutRowsTerminal = [
  { key: "Grid", labelKey: "custom.grid", icon: "⌗" },
  { key: "Single", labelKey: "custom.single", icon: "▥" },
  { key: "Git", labelKey: "custom.git", icon: "⑂" },
  { key: "Browser", labelKey: "custom.browser", icon: "🌐" },
  { key: "작업 승인", labelKey: "settings.shortcuts.task.approve", icon: "✓" },
  { key: "작업 거절", labelKey: "settings.shortcuts.task.deny", icon: "✕" },
  { key: "선택 세션 고정", labelKey: "settings.shortcuts.pin.selected", icon: "📌" },
  { key: "필터 토글", labelKey: "settings.shortcuts.filter.toggle", icon: "⚲" },
  { key: "파일 패널", labelKey: "settings.shortcuts.file.panel", icon: "📁" },
  { key: "Command Palette", labelKey: "settings.shortcuts.command.palette", icon: "⌘" },
  { key: "Action Center", labelKey: "settings.shortcuts.action.center", icon: "☑" }
];

const shortcutRowsView = [
  { key: "분할 뷰", labelKey: "settings.shortcuts.split.view", icon: "▥" },
  { key: "오피스 뷰", labelKey: "settings.shortcuts.office.view", icon: "🏢" },
  { key: "스트립 뷰", labelKey: "settings.shortcuts.strip.view", icon: "☰" },
  { key: "터미널 뷰", labelKey: "settings.shortcuts.terminal.view", icon: "⌘" }
];

const defaultShortcutDrafts: Record<string, string> = {
  "새로고침": "Ctrl+R",
  "새 세션": "Ctrl+T",
  "세션 닫기": "Ctrl+W",
  "Command Palette": "Ctrl+P",
  "Action Center": "Ctrl+J",
  "사이드바 토글": "Ctrl+B",
  "분할 뷰": "Ctrl+Shift+1",
  "오피스 뷰": "Ctrl+Shift+2",
  "스트립 뷰": "Ctrl+Shift+3",
  "터미널 뷰": "Ctrl+Shift+4",
  "Grid": "Ctrl+1",
  "Single": "Ctrl+2",
  "Git": "Ctrl+3",
  "Browser": "Ctrl+4",
  "작업 승인": "Ctrl+Enter",
  "작업 거절": "Ctrl+Backspace",
  "선택 세션 고정": "Ctrl+Shift+P",
  "파일 패널": "Ctrl+Shift+F",
  "필터 토글": "Ctrl+Shift+L"
};

export function WorkspaceOverlayManager(props: WorkspaceOverlayManagerProps) {
  const {
    kind,
    onClose,
    selectedSession,
    sessions,
    claudeStatus,
    codexStatus,
    geminiStatus,
    refreshCLIStatuses,
    installCLI,
    totals,
    preferences,
    updatePreferences,
    reportEntries,
    reportLoading,
    refreshReports,
    achievements,
    progress
  } = props;
  if (!kind) return null;

  return (
    <div className="overlay-backdrop workspace-modal-backdrop" onClick={onClose}>
      <div className="workspace-modal-shell" onClick={(event) => event.stopPropagation()}>
        {kind === "settings" ? (
          <SettingsPanel
            selectedSession={selectedSession}
            sessions={sessions}
            claudeStatus={claudeStatus}
            codexStatus={codexStatus}
            geminiStatus={geminiStatus}
            refreshCLIStatuses={refreshCLIStatuses}
            installCLI={installCLI}
            totals={totals}
            preferences={preferences}
            updatePreferences={updatePreferences}
            reportCount={reportEntries.length}
            progress={progress}
            onRefreshReports={refreshReports}
            onClose={onClose}
          />
        ) : null}
        {kind === "characters" ? (
          <CharacterPanel
            preferences={preferences}
            updatePreferences={updatePreferences}
            achievements={achievements}
            onClose={onClose}
          />
        ) : null}
        {kind === "accessories" ? (
          <AccessoryPanel
            preferences={preferences}
            updatePreferences={updatePreferences}
            achievements={achievements}
            progress={progress}
            onClose={onClose}
          />
        ) : null}
        {kind === "reports" ? (
          <ReportPanel reportEntries={reportEntries} reportLoading={reportLoading} onRefresh={refreshReports} onClose={onClose} />
        ) : null}
        {kind === "achievements" ? <AchievementPanel achievements={achievements} progress={progress} onClose={onClose} /> : null}
        {kind === "lock" ? <LockPanel preferences={preferences} updatePreferences={updatePreferences} onClose={onClose} /> : null}
      </div>
    </div>
  );
}

export function SessionLockOverlay(props: { lockPin: string; onUnlock: () => void }) {
  const { lockPin, onUnlock } = props;
  const [pinInput, setPinInput] = useState("");
  const [wrongPin, setWrongPin] = useState(false);

  function tryUnlock() {
    if (!lockPin) {
      onUnlock();
      return;
    }
    if (pinInput === lockPin) {
      setPinInput("");
      setWrongPin(false);
      onUnlock();
      return;
    }
    setWrongPin(true);
    setPinInput("");
  }

  return (
    <div className="overlay-backdrop workspace-modal-backdrop session-lock-backdrop">
      <div className="workspace-modal lock-modal session-lock-modal">
        <div className="workspace-modal-header">
          <div>
            <strong>세션 잠금 중</strong>
            <span>세션은 계속 실행 중입니다</span>
          </div>
        </div>
        <div className="workspace-modal-body centered">
          <div className="lock-hero">🔒</div>
          {lockPin ? (
            <>
              <input
                className={`lock-input ${wrongPin ? "is-error" : ""}`}
                value={pinInput}
                onChange={(event) => setPinInput(event.target.value)}
                placeholder="PIN 입력"
                type="password"
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    tryUnlock();
                  }
                }}
                autoFocus
              />
              {wrongPin ? <span className="lock-error-text">PIN이 올바르지 않습니다.</span> : null}
              <button type="button" className="hero-action-button" onClick={tryUnlock}>
                잠금 해제
              </button>
            </>
          ) : (
            <button type="button" className="hero-action-button" onClick={onUnlock}>
              잠금 해제
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function SettingsPanel(props: {
  selectedSession: SessionSnapshot | null;
  sessions: SessionSnapshot[];
  claudeStatus: CLIStatus;
  codexStatus: CLIStatus;
  geminiStatus: CLIStatus;
  refreshCLIStatuses: WorkspaceOverlayManagerProps["refreshCLIStatuses"];
  installCLI: WorkspaceOverlayManagerProps["installCLI"];
  totals: WorkspaceOverlayManagerProps["totals"];
  preferences: WorkspacePreferences;
  updatePreferences: WorkspaceOverlayManagerProps["updatePreferences"];
  reportCount: number;
  progress: WorkspaceProgress;
  onRefreshReports: () => Promise<void>;
  onClose: () => void;
}) {
  const {
    selectedSession,
    sessions,
    claudeStatus,
    codexStatus,
    geminiStatus,
    refreshCLIStatuses,
    installCLI,
    totals,
    preferences,
    updatePreferences,
    reportCount,
    progress,
    onRefreshReports,
    onClose
  } = props;
  const [tab, setTab] = useState<SettingsTab>("general");
  const [pluginSection, setPluginSection] = useState<PluginSection>("installed");
  const [selectedTemplateKind, setSelectedTemplateKind] = useState<WorkspacePreferences["workflowStyle"]>(preferences.workflowStyle);
  const [templateDrafts, setTemplateDrafts] = useState(loadTemplateDrafts);
  const [shortcutDrafts, setShortcutDrafts] = useState(loadShortcutDrafts);
  const [workspaceNameDraft, setWorkspaceNameDraft] = useState(preferences.workspaceName);
  const [secretKeyDraft, setSecretKeyDraft] = useState(preferences.secretKey);
  const [pluginSourceInput, setPluginSourceInput] = useState("");
  const [pluginSearchText, setPluginSearchText] = useState("");
  const [pluginTagFilter, setPluginTagFilter] = useState<string>("");
  const [installedPlugins, setInstalledPlugins] = useState<InstalledPluginRecord[]>(loadInstalledPlugins);
  const [pluginActionMessage, setPluginActionMessage] = useState("");
  const [cliActionState, setCliActionState] = useState<AgentProvider | "refresh" | null>(null);
  const [cliActionMessage, setCliActionMessage] = useState("");

  useEffect(() => {
    saveTemplateDrafts(templateDrafts);
  }, [templateDrafts]);

  useEffect(() => {
    saveShortcutDrafts(shortcutDrafts);
  }, [shortcutDrafts]);

  useEffect(() => {
    saveInstalledPlugins(installedPlugins);
  }, [installedPlugins]);

  useEffect(() => {
    setSelectedTemplateKind(preferences.workflowStyle);
  }, [preferences.workflowStyle]);

  useEffect(() => {
    setWorkspaceNameDraft(preferences.workspaceName);
  }, [preferences.workspaceName]);

  useEffect(() => {
    setSecretKeyDraft(preferences.secretKey);
  }, [preferences.secretKey]);

  const marketplaceTags = useMemo(
    () => Array.from(new Set(pluginMarketplace.flatMap((item) => item.tags))),
    []
  );
  const filteredMarketplace = pluginMarketplace.filter((item) => {
    const query = pluginSearchText.trim().toLowerCase();
    const matchesQuery =
      !query ||
      `${item.name} ${item.description} ${item.author} ${item.tags.join(" ")}`.toLowerCase().includes(query);
    const matchesTag = !pluginTagFilter || item.tags.includes(pluginTagFilter);
    return matchesQuery && matchesTag;
  });
  const activePluginCount = installedPlugins.filter((item) => item.enabled).length;
  const installedMarketplaceIds = new Set(installedPlugins.map((item) => item.marketplaceId).filter((value): value is string => Boolean(value)));
  const currentTemplate = templateDrafts[selectedTemplateKind];
  const selectedTemplateMeta = workflowChoices.find((choice) => choice.id === selectedTemplateKind) ?? workflowChoices[0];
  const cliEntries = [
    {
      id: "claude" as const,
      label: "Claude Code CLI",
      status: claudeStatus,
      installCommand: "npm install -g @anthropic-ai/claude-code"
    },
    {
      id: "codex" as const,
      label: "Codex CLI",
      status: codexStatus,
      installCommand: "npm install -g @openai/codex"
    },
    {
      id: "gemini" as const,
      label: "Gemini CLI",
      status: geminiStatus,
      installCommand: "npm install -g @google/gemini-cli"
    }
  ];

  function updateTemplateDraft(value: string) {
    setTemplateDrafts((current) => ({
      ...current,
      [selectedTemplateKind]: value
    }));
  }

  function commitWorkspaceNameDraft() {
    updatePreferences({ workspaceName: workspaceNameDraft.trim() || "Doffice" });
  }

  function applySecretKeyDraft() {
    updatePreferences({ secretKey: secretKeyDraft.trim() });
  }

  function persistPreferences(nextPreferences: WorkspacePreferences) {
    saveWorkspacePreferences(nextPreferences);
    applyWorkspacePreferences(nextPreferences);
    updatePreferences(nextPreferences);
  }

  async function requestRestartForPreferences(
    patch: Partial<WorkspacePreferences>,
    confirmationMessage: string
  ) {
    const nextPreferences = { ...preferences, ...patch };
    if (JSON.stringify(nextPreferences) === JSON.stringify(preferences)) return;
    if (!window.confirm(confirmationMessage)) return;
    persistPreferences(nextPreferences);
    await window.doffice.restartApp();
  }

  const combinedProviderWeeklyLimit =
    preferences.claudeWeeklyLimit + preferences.codexWeeklyLimit + preferences.geminiWeeklyLimit;
  const combinedProviderDailyLimit = combinedProviderWeeklyLimit > 0 ? Math.floor(combinedProviderWeeklyLimit / 7) : 0;

  function applyProviderPlan(provider: AgentProvider, planName: string, weeklyLimit: number) {
    const suggestedSessionLimit = Math.floor(weeklyLimit / 7);
    switch (provider) {
      case "claude":
        updatePreferences({
          claudePlanName: planName,
          claudeWeeklyLimit: weeklyLimit,
          claudeSessionTokenLimit: suggestedSessionLimit
        });
        return;
      case "codex":
        updatePreferences({
          codexPlanName: planName,
          codexWeeklyLimit: weeklyLimit,
          codexSessionTokenLimit: suggestedSessionLimit
        });
        return;
      case "gemini":
        updatePreferences({
          geminiPlanName: planName,
          geminiWeeklyLimit: weeklyLimit,
          geminiSessionTokenLimit: suggestedSessionLimit
        });
        return;
    }
  }

  function clearProviderPlan(provider: AgentProvider) {
    switch (provider) {
      case "claude":
        updatePreferences({
          claudePlanName: "",
          claudeWeeklyLimit: 0,
          claudeSessionTokenLimit: 0
        });
        return;
      case "codex":
        updatePreferences({
          codexPlanName: "",
          codexWeeklyLimit: 0,
          codexSessionTokenLimit: 0
        });
        return;
      case "gemini":
        updatePreferences({
          geminiPlanName: "",
          geminiWeeklyLimit: 0,
          geminiSessionTokenLimit: 0
        });
        return;
    }
  }

  function handleTabChange(nextTab: SettingsTab) {
    commitWorkspaceNameDraft();
    setTab(nextTab);
  }

  async function handleRefreshCLIStatuses() {
    setCliActionState("refresh");
    try {
      await refreshCLIStatuses();
      setCliActionMessage(t("settings.cli.refresh.done"));
    } catch (error) {
      setCliActionMessage(String(error instanceof Error ? error.message : error));
    } finally {
      setCliActionState(null);
    }
  }

  async function handleInstallCLI(provider: AgentProvider) {
    setCliActionState(provider);
    try {
      const result = await installCLI(provider);
      setCliActionMessage(result.message);
    } catch (error) {
      setCliActionMessage(String(error instanceof Error ? error.message : error));
    } finally {
      setCliActionState(null);
    }
  }

  async function installPlugin(source: string, options?: { title?: string; registryEntry?: PluginEntryLike }) {
    const trimmed = source.trim();
    if (!trimmed) return;
    const registryEntry = options?.registryEntry;
    try {
      const installed = await window.doffice.installPluginSource(trimmed);
      const nextPlugin = buildInstalledPluginRecord(installed, registryEntry, options?.title);
      setInstalledPlugins((current) => {
        const alreadyInstalled = current.some(
          (item) =>
            item.marketplaceId === nextPlugin.marketplaceId ||
            item.source === nextPlugin.source ||
            item.localPath === nextPlugin.localPath
        );
        if (alreadyInstalled) {
          return current.map((item) =>
            item.marketplaceId === nextPlugin.marketplaceId ||
            item.source === nextPlugin.source ||
            item.localPath === nextPlugin.localPath
              ? { ...item, ...nextPlugin, enabled: item.enabled }
              : item
          );
        }
        return [nextPlugin, ...current];
      });
      setPluginActionMessage(tf("settings.plugins.install.done", undefined, nextPlugin.title));
    } catch (error) {
      setPluginActionMessage(String(error instanceof Error ? error.message : error));
    }
    setPluginSourceInput("");
  }

  async function handleInstallLocalFolder() {
    const picked = await window.doffice.pickDirectory();
    if (!picked) return;
    await installPlugin(picked, { title: t("settings.plugins.local.plugin") });
  }

  async function handleCreatePluginTemplate() {
    const parentDir = await window.doffice.pickDirectory();
    if (!parentDir) return;
    try {
      const installed = await window.doffice.createPluginTemplate(parentDir);
      const nextPlugin = buildInstalledPluginRecord(installed, undefined, t("settings.plugins.new.plugin"));
      setInstalledPlugins((current) => [nextPlugin, ...current.filter((item) => item.localPath !== nextPlugin.localPath)]);
      setPluginActionMessage(tf("settings.plugins.template.done", undefined, nextPlugin.localPath));
      await window.doffice.revealPath(nextPlugin.localPath);
    } catch (error) {
      setPluginActionMessage(String(error instanceof Error ? error.message : error));
    }
  }

  return (
    <div className="workspace-modal settings-modal">
      <div className="workspace-modal-header">
        <div>
          <strong><span className="panel-title-emoji tone-default">⚙</span>{t("settings.title")}</strong>
        </div>
        <button type="button" className="workspace-close-button" onClick={() => {
          commitWorkspaceNameDraft();
          onClose();
        }}>
          ×
        </button>
      </div>
      <div className="settings-layout">
        <nav className="workspace-tab-strip settings-sidebar-nav" aria-label={t("settings.title")}>
          {settingsTabs.map((item) => (
            <button key={item.id} type="button" className={`workspace-tab-button ${tab === item.id ? "is-active" : ""}`} onClick={() => handleTabChange(item.id)}>
              <span className="settings-tab-icon">{item.icon}</span>
              <span className="settings-tab-label">{t(item.labelKey)}</span>
            </button>
          ))}
        </nav>
        <div className="workspace-modal-body settings-modal-body">
        {tab === "general" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">☰</span>{t("settings.section.profile")}</span>}>
              <div className="settings-form-grid">
                <label>
                  <span>{t("settings.field.app.name")}</span>
                  <input
                    value={workspaceNameDraft}
                    placeholder="Doffice"
                    onChange={(event) => setWorkspaceNameDraft(event.target.value)}
                    onBlur={commitWorkspaceNameDraft}
                  />
                </label>
                <label>
                  <span>{t("settings.field.company.name")}</span>
                  <input value={preferences.companyName} onChange={(event) => updatePreferences({ companyName: event.target.value })} />
                </label>
                <label className="settings-form-grid-span">
                  <span>{t("settings.field.secret.key")}</span>
                  <div className="settings-inline-input-row">
                    <input
                      type="password"
                      value={secretKeyDraft}
                      placeholder={t("settings.field.secret.placeholder")}
                      onChange={(event) => setSecretKeyDraft(event.target.value)}
                    />
                    <button type="button" className="mini-action-button accent-button" onClick={applySecretKeyDraft}>
                      {t("settings.action.apply")}
                    </button>
                  </div>
                </label>
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🌐</span>{t("settings.section.language")}</span>}>
              <div className="segmented-choice-row">
                {[
                  ["system", t("settings.language.system")],
                  ["ko", t("settings.language.ko")],
                  ["en", t("settings.language.en")],
                  ["ja", t("settings.language.ja")]
                ].map(([id, label]) => (
                  <button
                    key={id}
                    type="button"
                    className={`segmented-choice ${preferences.language === id ? "is-active" : ""}`}
                    onClick={() =>
                      void requestRestartForPreferences(
                        { language: id as WorkspacePreferences["language"] },
                        t("settings.restart.language.confirm")
                      )
                    }
                  >
                    {label}
                  </button>
                ))}
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">⌘</span>{t("settings.section.terminal")}</span>}>
              <div className="settings-list-rows">
                <ToggleRow
                  label={preferences.language === "en" || preferences.language === "ja" ? t("settings.option.raw.terminal.iterm") : t("settings.option.raw.terminal")}
                  enabled={preferences.rawTerminalMode}
                  onToggle={() => updatePreferences({ rawTerminalMode: !preferences.rawTerminalMode })}
                />
                <ToggleRow
                  label={t("settings.option.auto.refresh")}
                  enabled={preferences.autoRefreshOnSettingsChange}
                  onToggle={() => updatePreferences({ autoRefreshOnSettingsChange: !preferences.autoRefreshOnSettingsChange })}
                />
                <div className="settings-list-row">
                  <span>{t("settings.option.replay.tutorial")}</span>
                  <button
                    type="button"
                    className="mini-action-button"
                    onClick={() => {
                      window.localStorage.removeItem("doffice.onboarding.completed");
                      onClose();
                      window.requestAnimationFrame(() => {
                        window.dispatchEvent(new CustomEvent("doffice:show-tutorial"));
                      });
                    }}
                  >
                    {t("settings.action.open")}
                  </button>
                </div>
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-green">⚡</span>{t("settings.section.cli")}</span>}>
              <div className="settings-action-row">
                <span className="settings-card-note">{t("settings.cli.note")}</span>
                <button
                  type="button"
                  className="mini-action-button"
                  disabled={cliActionState !== null}
                  onClick={() => void handleRefreshCLIStatuses()}
                >
                  {cliActionState === "refresh" ? t("settings.cli.refreshing") : t("settings.cli.refresh")}
                </button>
              </div>
              <div className="marketplace-list">
                {cliEntries.map((entry) => (
                  <div key={entry.id} className="marketplace-row cli-status-row">
                    <div className="marketplace-copy">
                      <strong>{entry.label}</strong>
                      <span>
                        {entry.status.isInstalled
                          ? tf("settings.cli.version.installed", undefined, entry.status.version || t("custom.none"))
                          : entry.status.errorInfo || t("settings.cli.not.installed")}
                      </span>
                      <small className="path-ellipsis">{entry.status.path || entry.installCommand}</small>
                    </div>
                    <div className="settings-inline-actions cli-status-actions">
                      <span className={`chrome-pill tone-${entry.status.isInstalled ? "green" : "red"}`}>
                        {entry.status.isInstalled ? t("settings.cli.installed") : t("settings.cli.not.installed")}
                      </span>
                      {!entry.status.isInstalled ? (
                        <button
                          type="button"
                          className="mini-action-button install-button"
                          disabled={cliActionState !== null}
                          onClick={() => void handleInstallCLI(entry.id)}
                        >
                          {cliActionState === entry.id ? t("settings.cli.installing") : t("settings.cli.install")}
                        </button>
                      ) : null}
                    </div>
                  </div>
                ))}
              </div>
              {cliActionMessage ? <div className="settings-card-note cli-status-note">{cliActionMessage}</div> : null}
            </SettingsCard>
          </div>
        ) : null}

        {tab === "theme" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🖌</span>{t("settings.theme.section.theme")}</span>}>
              <div className="segmented-choice-row">
                {[
                  ["light", "☀", "Light"],
                  ["dark", "☾", "Dark"],
                  ["custom", "🎨", "Custom"]
                ].map(([id, icon, label]) => (
                  <button
                    key={id}
                    type="button"
                    className={`theme-choice theme-choice-tone ${preferences.themeMode === id ? "is-active" : ""}`}
                    onClick={() =>
                      void requestRestartForPreferences(
                        { themeMode: id as WorkspacePreferences["themeMode"] },
                        t("settings.restart.theme.confirm")
                      )
                    }
                  >
                    <span className="choice-icon">{icon}</span>
                    <span>{label}</span>
                    {preferences.themeMode === id ? <span className="choice-check theme-choice-check" aria-hidden="true">●</span> : null}
                  </button>
                ))}
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🖼</span>{t("settings.theme.section.background")}</span>}>
              <div className="chip-grid">
                {backgroundChoices.map((choice) => (
                  <button
                    key={choice.id}
                    type="button"
                    className={`chip-button background-choice ${preferences.backgroundTheme === choice.id ? "is-active" : ""}`}
                    disabled={choice.requiredLevel != null && progress.level < choice.requiredLevel}
                    onClick={() => updatePreferences({ backgroundTheme: choice.id as WorkspacePreferences["backgroundTheme"] })}
                  >
                    <span className="choice-icon background-choice-icon" aria-hidden="true">{backgroundIconGlyph(choice.id)}</span>
                    <span>{choice.label}</span>
                    {choice.requiredLevel != null ? ` · Lv.${choice.requiredLevel}` : ""}
                  </button>
                ))}
              </div>
            </SettingsCard>
            <SettingsCard title={t("settings.theme.section.font.size")}>
              <div className="settings-card-note">{tf("settings.theme.font.size.current", undefined, preferences.fontScale.toUpperCase())}</div>
              <div className="segmented-choice-row">
                {["s", "m", "l", "xl", "xxl"].map((size) => (
                  <button
                    key={size}
                    type="button"
                    className={`theme-choice ${preferences.fontScale === size ? "is-active" : ""}`}
                    onClick={() =>
                      void requestRestartForPreferences(
                        { fontScale: size as WorkspacePreferences["fontScale"] },
                        t("settings.restart.font.confirm")
                      )
                    }
                  >
                    {size.toUpperCase()}
                  </button>
                ))}
              </div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "office" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-sky">🏢</span>{t("settings.office.section.layout")}</span>}>
              <div className="layout-choice-list">
                {[
                  ["cozy", "🏠", "Cozy", t("settings.office.layout.cozy")],
                  ["collab", "👥", "Collab", t("settings.office.layout.collab")],
                  ["focus", "◎", "Focus", t("settings.office.layout.focus")]
                ].map(([id, icon, label, subtitle]) => (
                  <button
                    key={id}
                    type="button"
                    className={`layout-choice office-layout-choice ${preferences.officeLayout === id ? "is-active" : ""}`}
                    onClick={() => updatePreferences({ officeLayout: id as WorkspacePreferences["officeLayout"] })}
                  >
                    <strong><span className="choice-icon">{icon}</span>{label}</strong>
                    <span>{subtitle}</span>
                  </button>
                ))}
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-purple">⌖</span>{t("settings.office.section.camera")}</span>}>
              <div className="segmented-choice-row">
                {[
                  ["overview", "⛶", t("settings.office.camera.overview")],
                  ["focus", "◎", t("settings.office.camera.focus")]
                ].map(([id, icon, label]) => (
                  <button
                    key={id}
                    type="button"
                    className={`theme-choice camera-choice ${preferences.officeCamera === id ? "is-active" : ""}`}
                    onClick={() => updatePreferences({ officeCamera: id as WorkspacePreferences["officeCamera"] })}
                  >
                    <span className="choice-icon">{icon}</span>
                    {label}
                    {preferences.officeCamera === id ? <span className="choice-check">◉</span> : null}
                  </button>
                ))}
              </div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "tokens" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-gold">⚡</span>{t("settings.tokens.section.usage")}</span>}>
              <div className="settings-card-note">{t("settings.tokens.note")}</div>
              <div className="usage-grid">
                <div className="usage-card">
                  <span>{t("settings.tokens.today")}</span>
                  <strong>{formatCompactNumber(Math.max(0, Math.round(totals.tokens / 5)))}</strong>
                  <small>$0.00</small>
                  <span className="settings-inline-progress"><span style={{ width: `${Math.max(0, Math.min(100, preferences.dailyBudgetUSD > 0 ? (totals.tokens / Math.max(1, preferences.dailyBudgetUSD * 49000)) * 100 : 18))}%` }} /></span>
                </div>
                <div className="usage-card">
                  <span>{t("settings.tokens.this.week")}</span>
                  <strong>{formatCompactNumber(totals.tokens)}</strong>
                  <small>{`$${(totals.tokens / 49000).toFixed(2)}`}</small>
                  <span className="settings-inline-progress"><span style={{ width: `${Math.max(0, Math.min(100, preferences.sessionBudgetUSD > 0 ? (totals.tokens / Math.max(1, preferences.sessionBudgetUSD * 49000)) * 100 : 36))}%` }} /></span>
                </div>
              </div>
              {preferences.tokenProtectionEnabled ? (
                <>
                  <div className="settings-form-grid">
                    <label>
                      <span>{t("settings.tokens.daily.limit")}</span>
                      <input
                        type="number"
                        value={preferences.dailyBudgetUSD}
                        onChange={(event) => updatePreferences({ dailyBudgetUSD: Number(event.target.value) || 0 })}
                      />
                    </label>
                    <label>
                      <span>{t("settings.tokens.session.limit")}</span>
                      <input
                        type="number"
                        value={preferences.sessionBudgetUSD}
                        onChange={(event) => updatePreferences({ sessionBudgetUSD: Number(event.target.value) || 0 })}
                      />
                    </label>
                  </div>
                  <div className="settings-notice-banner settings-token-note-inline">
                    <span className="panel-title-emoji tone-green">🛡</span>
                    <span>{t("settings.tokens.recommendation")}</span>
                  </div>
                  <div className="settings-action-row">
                    <button
                      type="button"
                      className="mini-action-button apply-button"
                      onClick={() =>
                        updatePreferences({
                          dailyBudgetUSD: Math.max(preferences.dailyBudgetUSD, 5),
                          sessionBudgetUSD: Math.max(preferences.sessionBudgetUSD, 2)
                        })
                      }
                    >
                      {t("settings.tokens.apply.recommended")}
                    </button>
                    <button
                      type="button"
                      className="mini-action-button reset-button"
                      onClick={() =>
                        updatePreferences((current) => ({
                          ...current,
                          dailyBudgetUSD: 0,
                          sessionBudgetUSD: 0
                        }))
                      }
                    >
                      {t("settings.tokens.clear.history")}
                    </button>
                  </div>
                </>
              ) : (
                <div className="settings-notice-banner settings-token-note-inline muted">
                  <span className="panel-title-emoji tone-default">⊝</span>
                  <span>{t("settings.tokens.protection.disabled.desc")}</span>
                </div>
              )}
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-green">🛡</span>{t("settings.tokens.protection.title")}</span>}>
              <ToggleRow
                label={t("settings.tokens.protection.enabled")}
                enabled={preferences.tokenProtectionEnabled}
                onToggle={() => updatePreferences({ tokenProtectionEnabled: !preferences.tokenProtectionEnabled })}
              />
              <div className="settings-card-note">
                {preferences.tokenProtectionEnabled ? t("settings.tokens.protection.enabled.desc") : t("settings.tokens.protection.disabled.desc")}
              </div>
              <div className="settings-form-grid">
                <label>
                  <span>{t("settings.tokens.provider.claude")}</span>
                  <input
                    type="number"
                    min={0}
                    value={preferences.claudeSessionTokenLimit}
                    onChange={(event) => updatePreferences({ claudeSessionTokenLimit: Math.max(0, Number(event.target.value) || 0) })}
                  />
                </label>
                <label>
                  <span>{t("settings.tokens.provider.codex")}</span>
                  <input
                    type="number"
                    min={0}
                    value={preferences.codexSessionTokenLimit}
                    onChange={(event) => updatePreferences({ codexSessionTokenLimit: Math.max(0, Number(event.target.value) || 0) })}
                  />
                </label>
                <label className="settings-form-grid-span">
                  <span>{t("settings.tokens.provider.gemini")}</span>
                  <input
                    type="number"
                    min={0}
                    value={preferences.geminiSessionTokenLimit}
                    onChange={(event) => updatePreferences({ geminiSessionTokenLimit: Math.max(0, Number(event.target.value) || 0) })}
                  />
                </label>
              </div>
              <div className="settings-card-note">{t("settings.tokens.provider.limits")}</div>
            </SettingsCard>
            {preferences.tokenProtectionEnabled ? (
              <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-purple">∑</span>{t("settings.tokens.plan.title")}</span>}>
                <div className="settings-card-note">{t("settings.tokens.plan.subtitle")}</div>
                {combinedProviderWeeklyLimit > 0 ? (
                  <div className="settings-notice-banner settings-token-plan-summary">
                    <span className="panel-title-emoji tone-accent">◈</span>
                    <span>{tf("settings.tokens.plan.summary", undefined, formatCompactNumber(combinedProviderWeeklyLimit), formatCompactNumber(combinedProviderDailyLimit))}</span>
                  </div>
                ) : null}
                <div className="provider-plan-grid">
                  {([
                    {
                      id: "claude" as const,
                      label: t("settings.tokens.provider.claude"),
                      selectedPlan: preferences.claudePlanName,
                      weeklyLimit: preferences.claudeWeeklyLimit,
                      sessionLimit: preferences.claudeSessionTokenLimit,
                      plans: providerPlanCatalog.claude
                    },
                    {
                      id: "codex" as const,
                      label: t("settings.tokens.provider.codex"),
                      selectedPlan: preferences.codexPlanName,
                      weeklyLimit: preferences.codexWeeklyLimit,
                      sessionLimit: preferences.codexSessionTokenLimit,
                      plans: providerPlanCatalog.codex
                    },
                    {
                      id: "gemini" as const,
                      label: t("settings.tokens.provider.gemini"),
                      selectedPlan: preferences.geminiPlanName,
                      weeklyLimit: preferences.geminiWeeklyLimit,
                      sessionLimit: preferences.geminiSessionTokenLimit,
                      plans: providerPlanCatalog.gemini
                    }
                  ]).map((entry) => (
                    <div key={entry.id} className="provider-plan-card">
                      <div className="provider-plan-header">
                        <strong>{entry.label}</strong>
                        <span>
                          {entry.selectedPlan
                            ? tf("settings.tokens.plan.active", undefined, entry.selectedPlan, formatCompactNumber(entry.weeklyLimit))
                            : t("settings.tokens.plan.none")}
                        </span>
                      </div>
                      <div className="provider-plan-chip-row">
                        {entry.plans.map((plan) => (
                          <button
                            key={plan.name}
                            type="button"
                            className={`plan-chip ${entry.selectedPlan === plan.name ? "is-active" : ""}`}
                            onClick={() => applyProviderPlan(entry.id, plan.name, plan.weeklyLimit)}
                          >
                            <strong>{plan.name}</strong>
                            <span>{tf("settings.tokens.plan.weekly", undefined, formatCompactNumber(plan.weeklyLimit))}</span>
                          </button>
                        ))}
                      </div>
                      <div className="provider-plan-footer">
                        <span>{tf("settings.tokens.plan.session.suggestion", undefined, formatCompactNumber(entry.sessionLimit))}</span>
                        {entry.selectedPlan ? (
                          <button type="button" className="ghost-link-button" onClick={() => clearProviderPlan(entry.id)}>
                            {t("settings.tokens.plan.clear")}
                          </button>
                        ) : null}
                      </div>
                    </div>
                  ))}
                </div>
              </SettingsCard>
            ) : null}
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-green">🛡</span>{t("settings.tokens.section.automation")}</span>}>
              <ToggleRow
                label={t("settings.tokens.parallel.agents")}
                enabled={preferences.allowParallelAgents}
                onToggle={() => updatePreferences({ allowParallelAgents: !preferences.allowParallelAgents })}
              />
              <ToggleRow
                label={t("settings.tokens.lightweight.sidebar")}
                enabled={preferences.terminalSidebarLightweight}
                onToggle={() => updatePreferences({ terminalSidebarLightweight: !preferences.terminalSidebarLightweight })}
              />
              <div className="settings-stepper-grid">
                <StepperCard
                  title={t("settings.tokens.review.max")}
                  value={preferences.reviewerMaxPasses}
                  min={0}
                  max={3}
                  onChange={(value) => updatePreferences({ reviewerMaxPasses: value })}
                />
                <StepperCard
                  title={t("settings.tokens.qa.max")}
                  value={preferences.qaMaxPasses}
                  min={0}
                  max={3}
                  onChange={(value) => updatePreferences({ qaMaxPasses: value })}
                />
                <StepperCard
                  title={t("settings.tokens.revision.limit")}
                  value={preferences.automationRevisionLimit}
                  min={1}
                  max={5}
                  onChange={(value) => updatePreferences({ automationRevisionLimit: value })}
                />
              </div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "data" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🗃</span>{t("settings.data.section.storage")}</span>}>
              <div className="settings-card-note">{tf("settings.data.storage.note", undefined, (sessions.length * 0.42 + reportCount * 0.08 + preferences.hiredCharacterIds.length * 0.01).toFixed(1))}</div>
              <div className="settings-list-rows">
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-blue">📄</span>{t("settings.data.sessions")}</span><strong>{tf("settings.count.items", undefined, sessions.length)}</strong></div>
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-gold">⚡</span>{t("settings.data.tokens")}</span><strong>{formatCompactNumber(totals.tokens)}</strong></div>
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-sky">🏢</span>{t("settings.data.office.layout")}</span><strong>{preferences.officeLayout}</strong></div>
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-purple">🏆</span>{t("settings.data.achievements")}</span><strong>{`${countUnlockedAchievements(props.sessions, props.preferences, reportCount)}/${getTotalAchievementCount()}`}</strong></div>
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-green">👥</span>{t("settings.data.characters")}</span><strong>{`${preferences.hiredCharacterIds.length}/${getTotalCharacterCount()}`}</strong></div>
                <div className="settings-list-row"><span><span className="panel-title-emoji tone-orange">📑</span>{t("settings.data.reports")}</span><strong>{tf("settings.count.items", undefined, reportCount)}</strong></div>
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🧹</span>{t("settings.data.section.cache")}</span>}>
              <div className="settings-card-note">{t("settings.data.cache.note")}</div>
              <div className="danger-stack">
                <button type="button" className="danger-button warn" onClick={() => void onRefreshReports()}>
                  {`🌬 ${t("settings.data.cache.old")}`}
                </button>
                <button
                  type="button"
                  className="danger-button"
                  onClick={() =>
                    updatePreferences((current) => ({
                      ...current,
                      browserTabs: [{ id: "tab-0", title: "New Tab", url: "https://www.google.com" }],
                      browserActiveTabId: "tab-0",
                      browserBookmarks: current.browserBookmarks.slice(0, 4)
                    }))
                  }
                >
                  {`🗑 ${t("settings.data.delete.all")}`}
                </button>
              </div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "template" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">📄</span>{t("settings.template.section.workflow")}</span>}>
              <div className="workflow-choice-grid">
                {workflowChoices.map((choice) => (
                  <button
                    key={choice.id}
                    type="button"
                    className={`workflow-choice workflow-tone-${choice.tone} ${selectedTemplateKind === choice.id ? "is-active" : ""}`}
                    onClick={() => {
                      setSelectedTemplateKind(choice.id as WorkspacePreferences["workflowStyle"]);
                      updatePreferences({ workflowStyle: choice.id as WorkspacePreferences["workflowStyle"] });
                    }}
                  >
                    <strong><span className="choice-icon">{choice.icon}</span>{choice.label}</strong>
                    {selectedTemplateKind === choice.id ? <span className="choice-check">◉</span> : null}
                  </button>
                ))}
              </div>
              <div className="settings-template-summary">
                <strong><span className={`panel-title-emoji tone-${selectedTemplateMeta.tone}`}>{selectedTemplateMeta.icon}</span>{selectedTemplateMeta.label}</strong>
                <span>{selectedTemplateMeta.subtitle}</span>
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">✎</span>{t("settings.template.section.editor")}</span>}>
              <div className="settings-editor-header">
                <span className="settings-card-note">{tf("settings.template.using.current", undefined, selectedTemplateMeta.label)}</span>
                <div className="settings-action-row">
                  <button type="button" className="mini-action-button reset-button" onClick={() => updateTemplateDraft(defaultTemplateText[selectedTemplateKind])}>
                    {t("settings.template.reset.current")}
                  </button>
                  <button type="button" className="mini-action-button danger-text" onClick={() => setTemplateDrafts(defaultTemplateText)}>
                    {t("settings.template.reset.all")}
                  </button>
                </div>
              </div>
              <textarea
                className="settings-template-editor"
                value={currentTemplate}
                onChange={(event) => updateTemplateDraft(event.target.value)}
                rows={12}
              />
            </SettingsCard>
          </div>
        ) : null}

        {tab === "security" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🛡</span>{t("settings.security.section.session")}</span>}>
              <div className="settings-list-rows">
                <div className="settings-inline-field">
                  <span>{t("settings.security.lock.pin")}</span>
                  <input
                    type="password"
                    value={preferences.lockPin}
                    placeholder={t("settings.security.pin.placeholder")}
                    onChange={(event) => updatePreferences({ lockPin: event.target.value })}
                  />
                </div>
                <div className="settings-inline-field">
                  <span>{t("settings.security.auto.lock")}</span>
                  <select value={preferences.autoLockMinutes} onChange={(event) => updatePreferences({ autoLockMinutes: Number(event.target.value) })}>
                    <option value={0}>{t("settings.security.disabled")}</option>
                    <option value={1}>{tf("settings.security.minutes", undefined, 1)}</option>
                    <option value={3}>{tf("settings.security.minutes", undefined, 3)}</option>
                    <option value={5}>{tf("settings.security.minutes", undefined, 5)}</option>
                    <option value={10}>{tf("settings.security.minutes", undefined, 10)}</option>
                  </select>
                </div>
                <div className="settings-inline-field">
                  <span>{t("settings.security.billing.alert")}</span>
                  <select value={preferences.billingDay} onChange={(event) => updatePreferences({ billingDay: Number(event.target.value) })}>
                    <option value={0}>{t("settings.security.unset")}</option>
                    {Array.from({ length: 31 }, (_, index) => index + 1).map((day) => (
                      <option key={day} value={day}>{tf("settings.security.day", undefined, day)}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="settings-action-row">
                <button type="button" className="mini-action-button success" onClick={() => updatePreferences({ isLocked: true })}>
                  {t("settings.security.lock.now")}
                </button>
                <button type="button" className="mini-action-button" onClick={() => updatePreferences({ isLocked: false })}>
                  {t("settings.security.unlock.now")}
                </button>
                <button type="button" className="mini-action-button danger-text" onClick={() => updatePreferences({ lockPin: "" })}>
                  {t("settings.security.remove.pin")}
                </button>
              </div>
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-orange">💳</span>{t("settings.security.section.budget")}</span>}>
              <div className="settings-list-rows">
                <div className="settings-inline-field">
                  <span>{t("settings.security.daily.limit")}</span>
                  <input type="number" value={preferences.dailyBudgetUSD} onChange={(event) => updatePreferences({ dailyBudgetUSD: Number(event.target.value) || 0 })} />
                </div>
                <div className="settings-inline-field">
                  <span>{t("settings.security.session.limit")}</span>
                  <input type="number" value={preferences.sessionBudgetUSD} onChange={(event) => updatePreferences({ sessionBudgetUSD: Number(event.target.value) || 0 })} />
                </div>
              </div>
              <ToggleRow
                label={t("settings.security.warn.threshold")}
                enabled={preferences.warnAtBudgetThreshold}
                onToggle={() => updatePreferences({ warnAtBudgetThreshold: !preferences.warnAtBudgetThreshold })}
              />
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-green">🧷</span>{t("settings.security.section.protection")}</span>}>
              <div className="settings-check-list">
                <label>
                  <input type="checkbox" checked={preferences.protectDangerousCommands} onChange={() => updatePreferences({ protectDangerousCommands: !preferences.protectDangerousCommands })} />
                  {t("settings.security.detect.dangerous")}
                </label>
                <label>
                  <input type="checkbox" checked={preferences.protectSensitiveFiles} onChange={() => updatePreferences({ protectSensitiveFiles: !preferences.protectSensitiveFiles })} />
                  {t("settings.security.protect.sensitive")}
                </label>
                <label>
                  <input type="checkbox" checked={preferences.warnAtBudgetThreshold} onChange={() => updatePreferences({ warnAtBudgetThreshold: !preferences.warnAtBudgetThreshold })} />
                  {t("settings.security.warn.threshold")}
                </label>
              </div>
              <div className="settings-action-row">
                <button type="button" className="mini-action-button" onClick={() => void window.doffice.copyText(JSON.stringify({ lockPin: preferences.lockPin, billingDay: preferences.billingDay }))}>
                  {t("settings.security.export.log")}
                </button>
                <button type="button" className="mini-action-button danger-text" onClick={() => updatePreferences({ protectDangerousCommands: false, protectSensitiveFiles: false })}>
                  {t("settings.security.clear.records")}
                </button>
              </div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "plugins" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-default">🧩</span>{t("settings.plugins.section.add")}</span>}>
              <div className="settings-form-grid">
                <label className="settings-form-grid-span">
                  <span>{t("settings.plugins.source.label")}</span>
                  <div className="settings-inline-input-row">
                    <input value={pluginSourceInput} onChange={(event) => setPluginSourceInput(event.target.value)} placeholder={t("settings.plugins.source.placeholder")} />
                    <button type="button" className="mini-action-button install-button" onClick={() => void installPlugin(pluginSourceInput)}>
                      {t("settings.plugins.install")}
                    </button>
                  </div>
                </label>
              </div>
              <div className="settings-action-row">
                <button type="button" className="mini-action-button sky-button" onClick={() => void handleInstallLocalFolder()}>
                  {`📁 ${t("settings.plugins.local.folder")}`}
                </button>
                <button type="button" className="mini-action-button green-button" onClick={() => void handleCreatePluginTemplate()}>
                  {`🔨 ${t("settings.plugins.new.plugin")}`}
                </button>
              </div>
              {pluginActionMessage ? <div className="settings-notice-banner muted">{pluginActionMessage}</div> : null}
              <div className="settings-format-hints">
                <div className="settings-format-hint-row"><strong>brew formula</strong><span>formula-name</span></div>
                <div className="settings-format-hint-row"><strong>brew tap</strong><span>user/tap/formula</span></div>
                <div className="settings-format-hint-row"><strong>{t("settings.plugins.direct.download")}</strong><span>https://.../plugin.json</span></div>
                <div className="settings-format-hint-row"><strong>{t("settings.plugins.local.path")}</strong><span>~/plugin</span></div>
              </div>
            </SettingsCard>
            <div className="segmented-choice-row plugin-section-switch">
              <button type="button" className={`segmented-choice ${pluginSection === "installed" ? "is-active" : ""}`} onClick={() => setPluginSection("installed")}>
                {tf("settings.plugins.installed.tab", undefined, installedPlugins.length)}
              </button>
              <button type="button" className={`segmented-choice ${pluginSection === "marketplace" ? "is-active" : ""}`} onClick={() => setPluginSection("marketplace")}>
                {tf("settings.plugins.marketplace.tab", undefined, filteredMarketplace.length)}
              </button>
            </div>
            {pluginSection === "installed" ? (
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-green">🧱</span>{tf("settings.plugins.installed.summary", undefined, installedPlugins.length, activePluginCount)}</span>}>
              <div className="marketplace-list">
                {installedPlugins.length === 0 ? <div className="leaderboard-empty">{t("settings.plugins.installed.empty")}</div> : null}
                {installedPlugins.map((item) => (
                  <div key={item.id} className="marketplace-row">
                    <div className="marketplace-copy">
                      <strong>{item.title}</strong>
                      <span className="path-ellipsis">{item.localPath || item.source}</span>
                      {item.localPath && item.source && item.localPath !== item.source ? <small className="path-ellipsis">{item.source}</small> : null}
                      <small>{[item.author, item.version ? `v${item.version}` : null, item.tags.slice(0, 3).join(" · ")].filter(Boolean).join(" · ")}</small>
                    </div>
                    <div className="settings-inline-actions">
                      <button
                        type="button"
                        className={`mini-action-button plugin-toggle-button ${item.enabled ? "is-enabled" : ""}`}
                        aria-pressed={item.enabled}
                        aria-label={`${item.title} ${item.enabled ? "enabled" : "disabled"}`}
                        onClick={() => setInstalledPlugins((current) => current.map((plugin) => plugin.id === item.id ? { ...plugin, enabled: !plugin.enabled } : plugin))}
                      >
                        <span className={`toggle-fake plugin-toggle-switch ${item.enabled ? "is-on" : ""}`} />
                      </button>
                      <button type="button" className="mini-action-button icon-action-button" onClick={() => setInstalledPlugins((current) => current.map((plugin) => plugin.id === item.id ? { ...plugin, shared: !plugin.shared } : plugin))}>⤴</button>
                      <button type="button" className="mini-action-button icon-action-button" onClick={() => void window.doffice.revealPath(item.localPath || item.source)}>📁</button>
                      <button type="button" className="mini-action-button icon-action-button" onClick={() => void window.doffice.copyText(item.localPath || item.source)}>📄</button>
                      <button type="button" className="mini-action-button icon-action-button danger-text" onClick={() => setInstalledPlugins((current) => current.filter((plugin) => plugin.id !== item.id))}>🗑</button>
                    </div>
                  </div>
                ))}
              </div>
            </SettingsCard>
            ) : null}
            {pluginSection === "marketplace" ? (
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-blue">🌐</span>{t("settings.plugins.section.marketplace")}</span>}>
              <div className="settings-action-row plugin-market-actions">
                <button type="button" className="mini-action-button blue-button" onClick={() => setPluginSearchText("")}>
                  {`↻ ${t("main.refresh")}`}
                </button>
                <button type="button" className="ghost-link-button" onClick={() => void window.doffice.openExternal("https://github.com/jjunhaa0211/Doffice/tree/main/plugins")}>
                  {t("settings.plugins.open.github")}
                </button>
              </div>
              <div className="settings-inline-input-row">
                <input value={pluginSearchText} onChange={(event) => setPluginSearchText(event.target.value)} placeholder={t("settings.plugins.search.placeholder")} />
              </div>
              <div className="plugin-tag-strip">
                {marketplaceTags.map((tag) => (
                  <button key={tag} type="button" className={`chip-button plugin-tag-chip ${pluginTagFilter === tag ? "is-active" : ""}`} onClick={() => setPluginTagFilter((current) => current === tag ? "" : tag)}>
                    {tag}
                  </button>
                ))}
              </div>
              <div className="marketplace-list">
                {filteredMarketplace.map((item) => (
                  <div key={item.id} className="marketplace-row">
                    <div className="marketplace-copy">
                      <strong>{item.name}</strong>
                      <span>{item.description}</span>
                      <small>{`${item.author} · v${item.version} · ★${item.stars} · ${item.tags.join(" ")}`}</small>
                    </div>
                    <button
                      type="button"
                      className={`mini-action-button ${installedMarketplaceIds.has(item.id) ? "" : "install-button"}`}
                      onClick={() => void installPlugin(item.downloadURL, { title: item.name, registryEntry: item })}
                      disabled={installedMarketplaceIds.has(item.id)}
                    >
                      {installedMarketplaceIds.has(item.id) ? t("settings.plugins.installed.badge") : t("settings.plugins.install")}
                    </button>
                  </div>
                ))}
              </div>
            </SettingsCard>
            ) : null}
          </div>
        ) : null}

        {tab === "support" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-orange">☕</span>{t("settings.support.section.title")}</span>}>
              <div className="settings-card-note">{t("settings.support.note")}</div>
              <div className="support-card">
                <span>7777015832634</span>
                <button type="button" className="mini-action-button reset-button" onClick={() => void window.doffice.copyText("7777015832634")}>
                  {`📄 ${t("settings.support.copy")}`}
                </button>
              </div>
              <div className="marketplace-list">
                <div className="marketplace-row support-row">
                  <div><strong><span className="panel-title-emoji tone-gold">🏦</span>{t("settings.support.kakao")}</strong><span>{t("settings.support.kakao.desc")}</span></div>
                  <button type="button" className="ghost-link-button support-link yellow-link" onClick={() => void window.doffice.openExternal("https://www.kakaobank.com")}>{t("settings.action.open")}</button>
                </div>
                <div className="marketplace-row support-row">
                  <div><strong><span className="panel-title-emoji tone-sky">🛫</span>{t("settings.support.toss")}</strong><span>{t("settings.support.toss.desc")}</span></div>
                  <button type="button" className="ghost-link-button support-link sky-link" onClick={() => void window.doffice.openExternal("https://toss.im")}>{t("settings.action.open")}</button>
                </div>
              </div>
              <div className="settings-card-note">{t("settings.support.fallback.note")}</div>
            </SettingsCard>
          </div>
        ) : null}

        {tab === "shortcuts" ? (
          <div className="settings-stack">
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-blue">▤</span>{t("settings.shortcuts.section.session")}</span>}>
              <EditableShortcutRows
                rows={shortcutRowsSession}
                values={shortcutDrafts}
                onChange={(key, value) => setShortcutDrafts((current) => ({ ...current, [key]: value }))}
              />
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-blue">⌘</span>{t("settings.shortcuts.section.terminal")}</span>}>
              <EditableShortcutRows
                rows={shortcutRowsTerminal}
                values={shortcutDrafts}
                onChange={(key, value) => setShortcutDrafts((current) => ({ ...current, [key]: value }))}
              />
            </SettingsCard>
            <SettingsCard title={<span className="settings-section-title"><span className="panel-title-emoji tone-blue">▥</span>{t("settings.shortcuts.section.view")}</span>}>
              <EditableShortcutRows
                rows={shortcutRowsView}
                values={shortcutDrafts}
                onChange={(key, value) => setShortcutDrafts((current) => ({ ...current, [key]: value }))}
              />
            </SettingsCard>
          </div>
        ) : null}
        </div>
      </div>
    </div>
  );
}

function CharacterPanel(props: {
  preferences: WorkspacePreferences;
  updatePreferences: WorkspaceOverlayManagerProps["updatePreferences"];
  achievements: WorkspaceAchievement[];
  onClose: () => void;
}) {
  const { preferences, updatePreferences, achievements, onClose } = props;
  const [selectedSpecies, setSelectedSpecies] = useState<keyof typeof speciesCatalog | "all">("all");
  const [sortMode, setSortMode] = useState<"default" | "name" | "role" | "species">("default");
  const allCharacters = getAllCharacters();
  const unlockedAchievementIds = useMemo(
    () => new Set(achievements.filter((item) => item.unlocked).map((item) => item.id)),
    [achievements]
  );
  const resolveJob = (characterId: string, fallback: keyof typeof jobCatalog) =>
    preferences.characterJobOverrides[characterId] ?? fallback;
  const hired = allCharacters.filter((character) => preferences.hiredCharacterIds.includes(character.id));
  const filtered = allCharacters.filter((character) => selectedSpecies === "all" || character.species === selectedSpecies);
  const available = filtered.filter(
    (character) =>
      !preferences.hiredCharacterIds.includes(character.id) &&
      (!character.requiredAchievement || unlockedAchievementIds.has(character.requiredAchievement))
  );
  const locked = filtered.filter(
    (character) =>
      !preferences.hiredCharacterIds.includes(character.id) &&
      character.requiredAchievement != null &&
      !unlockedAchievementIds.has(character.requiredAchievement)
  );
  const hiredFiltered = hired.filter((character) => selectedSpecies === "all" || character.species === selectedSpecies);
  const sortedHired = sortCharacters(hiredFiltered, sortMode);
  const sortedAvailable = sortCharacters(available, sortMode);
  const sortedLocked = sortCharacters(locked, sortMode);
  const roleCounts = {
    developer: hired.filter((character) => resolveJob(character.id, character.jobRole) === "developer").length,
    qa: hired.filter((character) => resolveJob(character.id, character.jobRole) === "qa").length,
    reporter: hired.filter((character) => resolveJob(character.id, character.jobRole) === "reporter").length
  };
  const roleStatKeys: Array<"developer" | "qa" | "reporter"> = ["developer", "qa", "reporter"];

  return (
    <div className="workspace-modal character-modal mac-character-modal">
      <div className="workspace-modal-header">
        <div>
          <strong><span className="panel-title-emoji tone-blue">👥</span>캐릭터</strong>
          <span>{`${preferences.hiredCharacterIds.length}명 고용 / ${getTotalCharacterCount()}명 전체`}</span>
        </div>
        <button type="button" className="workspace-close-button" onClick={onClose}>×</button>
      </div>

      <div className="character-filter-row">
        <div className="character-species-row">
          <button
            type="button"
            className={`species-chip ${selectedSpecies === "all" ? "is-active" : ""}`}
            onClick={() => setSelectedSpecies("all")}
          >
            <strong>All</strong>
            <span>{getTotalCharacterCount()}</span>
          </button>
          {Object.entries(speciesCatalog).map(([species, meta]) => {
            const count = allCharacters.filter((character) => character.species === species).length;
            return (
              <button
                key={species}
                type="button"
                className={`species-chip ${selectedSpecies === species ? "is-active" : ""}`}
                onClick={() => setSelectedSpecies(species as keyof typeof speciesCatalog)}
              >
                <strong>{meta.emoji}</strong>
                <span>{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="character-toolbar">
        <div className="character-stat-badges">
          <span className="character-stat-badge" title="고용 현황">
            <span className="character-stat-icon" aria-hidden="true">👥</span>
            <span>{`${preferences.hiredCharacterIds.length}/${Math.max(12, getTotalCharacterCount())}`}</span>
          </span>
          {roleStatKeys.map((role) => (
            <span
              key={role}
              className="character-stat-badge"
              title={jobCatalog[role].label}
              style={{ "--badge-tint": jobCatalog[role].tint } as CSSProperties}
            >
              <span className="character-stat-icon" aria-hidden="true">{jobCatalog[role].icon}</span>
              <span>{roleCounts[role]}</span>
            </span>
          ))}
        </div>
        <select className="character-sort-select" value={sortMode} onChange={(event) => setSortMode(event.target.value as typeof sortMode)}>
          <option value="default">⇅ 픽셀프라인</option>
          <option value="name">⇅ 이름순</option>
          <option value="role">⇅ 직군순</option>
          <option value="species">⇅ 종족순</option>
        </select>
      </div>

      <div className="workspace-modal-body character-collection-body">
        <CharacterSection title={`고용 중 ${sortedHired.length}`} tone="active">
          <div className="character-grid">
            {sortedHired.map((character) => {
              const onVacation = preferences.vacationCharacterIds.includes(character.id);
              return (
                <CharacterRosterCard
                  key={character.id}
                  character={{ ...character, jobRole: resolveJob(character.id, character.jobRole) }}
                  locked={false}
                  onVacation={onVacation}
                  footer={
                    <>
                      <button
                        type="button"
                        className="mini-action-button"
                        onClick={() =>
                          updatePreferences({
                            vacationCharacterIds: onVacation
                              ? preferences.vacationCharacterIds.filter((id) => id !== character.id)
                              : [...preferences.vacationCharacterIds, character.id]
                          })
                        }
                      >
                        {onVacation ? "복귀" : "휴가"}
                      </button>
                      <button
                        type="button"
                        className="mini-action-button danger-text"
                        onClick={() =>
                          updatePreferences({
                            hiredCharacterIds: preferences.hiredCharacterIds.filter((id) => id !== character.id),
                            vacationCharacterIds: preferences.vacationCharacterIds.filter((id) => id !== character.id)
                          })
                        }
                      >
                        해고
                      </button>
                    </>
                  }
                  extra={
                    <select
                      className="character-role-select"
                      value={resolveJob(character.id, character.jobRole)}
                      onChange={(event) =>
                        updatePreferences((current) => ({
                          ...current,
                          characterJobOverrides: {
                            ...current.characterJobOverrides,
                            [character.id]: event.target.value as keyof typeof jobCatalog
                          }
                        }))
                      }
                    >
                      {Object.entries(jobCatalog).map(([job, meta]) => (
                        <option key={job} value={job}>
                          {`${meta.icon} ${meta.label}`}
                        </option>
                      ))}
                    </select>
                  }
                />
              );
            })}
          </div>
        </CharacterSection>

        <CharacterSection title={`대기 중 ${sortedAvailable.length}`} tone="available">
          <div className="character-grid">
            {sortedAvailable.map((character) => (
              <CharacterRosterCard
                key={character.id}
                character={{ ...character, jobRole: resolveJob(character.id, character.jobRole) }}
                locked={false}
                footer={
                  <button
                    type="button"
                    className="mini-action-button success"
                    disabled={preferences.hiredCharacterIds.length >= 12}
                    onClick={() =>
                      updatePreferences({
                        hiredCharacterIds: [...preferences.hiredCharacterIds, character.id].slice(0, 12)
                      })
                    }
                  >
                    고용
                  </button>
                }
              />
            ))}
          </div>
        </CharacterSection>

        <CharacterSection title={`잠금 ${sortedLocked.length}`} tone="locked">
          <div className="character-grid">
            {sortedLocked.map((character) => (
              <CharacterRosterCard
                key={character.id}
                character={{ ...character, jobRole: resolveJob(character.id, character.jobRole) }}
                locked
                lockReason={character.requiredAchievement ?? undefined}
              />
            ))}
          </div>
        </CharacterSection>
      </div>
    </div>
  );
}

function AccessoryPanel(props: {
  preferences: WorkspacePreferences;
  updatePreferences: WorkspaceOverlayManagerProps["updatePreferences"];
  achievements: WorkspaceAchievement[];
  progress: WorkspaceProgress;
  onClose: () => void;
}) {
  const { preferences, updatePreferences, achievements, progress, onClose } = props;
  const [mode, setMode] = useState<"accessories" | "background">("accessories");
  const accessoryCatalog = getAccessoryCatalog();
  const unlockedAchievementIds = useMemo(
    () => new Set(achievements.filter((item) => item.unlocked).map((item) => item.id)),
    [achievements]
  );
  const currentBackgroundChoice = backgroundChoices.find((choice) => choice.id === preferences.backgroundTheme) ?? backgroundChoices[0];

  return (
    <div className="workspace-modal accessory-modal mac-accessory-modal">
      <div className="workspace-modal-header">
        <div>
          <strong><span className="panel-title-emoji tone-purple">🎨</span>꾸미기</strong>
          <span>오피스 악세서리 및 배경 관리</span>
        </div>
        <button type="button" className="workspace-close-button" onClick={onClose}>×</button>
      </div>
      <div className="workspace-tab-strip narrow accessory-tab-strip">
        <button type="button" className={`workspace-tab-button ${mode === "accessories" ? "is-active" : ""}`} onClick={() => setMode("accessories")}>
          <span className="accessory-tab-button-copy">
            <span className="accessory-tab-icon" aria-hidden="true">🛋️</span>
            <span>악세서리</span>
          </span>
        </button>
        <button type="button" className={`workspace-tab-button ${mode === "background" ? "is-active" : ""}`} onClick={() => setMode("background")}>
          <span className="accessory-tab-button-copy">
            <span className="accessory-tab-icon" aria-hidden="true">🖼️</span>
            <span>배경</span>
          </span>
        </button>
      </div>
      <div className="workspace-modal-body accessory-collection-body">
        {mode === "accessories" ? (
          <>
            <div className="accessory-grid mac-accessory-grid">
              {accessoryCatalog.map((item) => {
                const enabled = preferences.enabledAccessoryIds.includes(item.id);
                const lockedByLevel = item.requiredLevel != null && progress.level < item.requiredLevel;
                const lockedByAchievement =
                  item.requiredAchievement != null && !unlockedAchievementIds.has(item.requiredAchievement);
                const locked = lockedByLevel || lockedByAchievement;

                return (
                  <button
                    key={item.id}
                    type="button"
                    className={`accessory-tile mac-accessory-tile ${enabled ? "is-active" : ""} ${locked ? "is-locked" : ""}`}
                    onClick={() => {
                      if (locked) return;
                      updatePreferences({
                        enabledAccessoryIds: enabled
                          ? preferences.enabledAccessoryIds.filter((id) => id !== item.id)
                          : [...preferences.enabledAccessoryIds, item.id]
                      });
                    }}
                  >
                    <AccessoryPreviewCard
                      item={item}
                      themeId={preferences.backgroundTheme}
                      enabled={enabled}
                      locked={locked}
                    />
                    <div className="accessory-tile-footer">
                      <span className={`accessory-tile-label ${enabled ? "is-active" : ""} ${locked ? "is-locked" : ""}`}>
                        <span className={`accessory-tile-icon ${enabled ? "is-active" : ""} ${locked ? "is-locked" : ""}`} aria-hidden="true">
                          {accessoryIconGlyph(item.id)}
                        </span>
                        <span>{item.name}</span>
                      </span>
                      {enabled ? <span className="accessory-check-mark">✓</span> : <span className="accessory-radio-mark" />}
                    </div>
                    {locked ? (
                      <div className="accessory-lock-overlay">
                        <strong>🔒</strong>
                        <span>
                          {lockedByLevel ? `레벨 ${item.requiredLevel}` : item.requiredAchievement ?? "잠금"}
                        </span>
                      </div>
                    ) : null}
                  </button>
                );
              })}
            </div>
            <div className="accessory-bottom-stack">
              <button type="button" className="hero-action-button accessory-place-button" onClick={onClose}>
                손 드래그로 가구 배치하기
              </button>
              <button type="button" className="ghost-link-button" onClick={() => updatePreferences({ enabledAccessoryIds: defaultWorkspacePreferences.enabledAccessoryIds })}>
                기본 배치로 초기화
              </button>
            </div>
          </>
        ) : (
          <>
            <div className="background-theme-header">
              <span>배경 테마</span>
              <strong>{currentBackgroundChoice?.label ?? ""}</strong>
            </div>
            <div className="accessory-grid mac-background-grid">
              {backgroundChoices.map((choice) => {
                const selected = preferences.backgroundTheme === choice.id;
                const locked = choice.requiredLevel != null && progress.level < choice.requiredLevel;
                return (
                  <button
                    key={choice.id}
                    type="button"
                    className={`background-tile ${selected ? "is-active" : ""} ${locked ? "is-locked" : ""}`}
                    onClick={() => {
                      if (!locked) updatePreferences({ backgroundTheme: choice.id as WorkspacePreferences["backgroundTheme"] });
                    }}
                  >
                    <BackgroundPreviewCard choice={choice} locked={locked} />
                    <div className="background-tile-footer">
                      <span className={`background-tile-label ${selected ? "is-active" : ""} ${locked ? "is-locked" : ""}`}>
                        {choice.label}
                      </span>
                    </div>
                    {locked ? <div className="accessory-lock-overlay"><strong>🔒</strong><span>{`레벨 ${choice.requiredLevel}`}</span></div> : null}
                  </button>
                );
              })}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function ReportPanel(props: {
  reportEntries: ReportReference[];
  reportLoading: boolean;
  onRefresh: () => Promise<void>;
  onClose: () => void;
}) {
  const { reportEntries, reportLoading, onRefresh, onClose } = props;
  const [selectedPath, setSelectedPath] = useState<string>("");
  const [content, setContent] = useState("");
  const [readError, setReadError] = useState("");

  useEffect(() => {
    if (!reportEntries.some((entry) => entry.path === selectedPath)) {
      setSelectedPath(reportEntries[0]?.path ?? "");
    }
  }, [reportEntries, selectedPath]);

  useEffect(() => {
    if (!selectedPath) {
      setContent("");
      return;
    }
    let cancelled = false;
    setReadError("");
    void window.doffice
      .readReport(selectedPath)
      .then((document) => {
        if (!cancelled) setContent(document.content);
      })
      .catch((error) => {
        if (!cancelled) {
          setReadError(error instanceof Error ? error.message : String(error));
          setContent("");
        }
      });
    return () => {
      cancelled = true;
    };
  }, [selectedPath]);

  const selectedEntry = reportEntries.find((entry) => entry.path === selectedPath) ?? reportEntries[0] ?? null;

  return (
    <div className="workspace-modal report-modal mac-report-modal">
      <div className="workspace-modal-header">
        <div>
          <strong><span className="panel-title-emoji tone-sky">📄</span>보고서</strong>
          <span>AI가 정리한 Markdown 결과물을 프로젝트별로 보여줍니다.</span>
        </div>
        <button type="button" className="workspace-close-button" onClick={onClose}>×</button>
      </div>
      <div className="report-layout">
        <aside className="report-sidebar">
          <div className="settings-action-row">
            <button type="button" className="mini-action-button" onClick={() => void onRefresh()}>
              새로고침
            </button>
          </div>
          {reportLoading ? <div className="leaderboard-empty">보고서 목록을 불러오는 중입니다.</div> : null}
          {!reportLoading && reportEntries.length === 0 ? <div className="leaderboard-empty">보고서가 없습니다.</div> : null}
          {reportEntries.map((entry) => (
            <button
              key={entry.path}
              type="button"
              className={`report-list-item ${entry.path === selectedPath ? "is-active" : ""}`}
              onClick={() => setSelectedPath(entry.path)}
            >
              <strong>{entry.projectName}</strong>
              <span>{entry.fileName}</span>
              <span>{relativeTime(entry.updatedAt)}</span>
            </button>
          ))}
        </aside>
        <article className="report-body">
          <div className="settings-action-row">
            <button type="button" className="mini-action-button" disabled={!selectedEntry} onClick={() => selectedEntry && void window.doffice.revealPath(selectedEntry.path)}>
              경로 보기
            </button>
            <button type="button" className="mini-action-button" disabled={!selectedEntry} onClick={() => selectedEntry && void window.doffice.copyText(selectedEntry.path)}>
              복사
            </button>
            <button
              type="button"
              className="mini-action-button danger-text"
              disabled={!selectedEntry}
              onClick={async () => {
                if (!selectedEntry) return;
                await window.doffice.deleteReport(selectedEntry.path);
                await onRefresh();
              }}
            >
              삭제
            </button>
          </div>
          {selectedEntry ? <strong>{selectedEntry.fileName}</strong> : null}
          {readError ? <div className="leaderboard-empty">{readError}</div> : null}
          {!selectedEntry && !readError ? <div className="leaderboard-empty">보고서를 선택하세요.</div> : null}
          {selectedEntry && !readError ? (
            <div className="report-section markdown-report-surface">
              <MarkdownDocumentView content={content} />
            </div>
          ) : null}
        </article>
      </div>
    </div>
  );
}

function AchievementPanel(props: { achievements: WorkspaceAchievement[]; progress: WorkspaceProgress; onClose: () => void }) {
  const { achievements, progress, onClose } = props;
  const [selectedTier, setSelectedTier] = useState<WorkspaceAchievement["tier"] | "all">("all");
  const [showUnlockedOnly, setShowUnlockedOnly] = useState(false);
  const unlocked = achievements.filter((item) => item.unlocked);
  const completion = unlocked.length / Math.max(1, achievements.length);
  const tierOrder: Array<WorkspaceAchievement["tier"]> = ["mythic", "legendary", "epic", "rare", "common"];
  const tierTone: Record<WorkspaceAchievement["tier"] | "all", { accent: string; border: string; background: string; text: string }> = {
    all: { accent: "#ffcb57", border: "rgba(255, 203, 87, 0.36)", background: "rgba(255, 203, 87, 0.14)", text: "#ffe0a3" },
    mythic: { accent: "#f14c4c", border: "rgba(241, 76, 76, 0.34)", background: "rgba(241, 76, 76, 0.14)", text: "#ff9898" },
    legendary: { accent: "#ffcb57", border: "rgba(255, 203, 87, 0.34)", background: "rgba(255, 203, 87, 0.14)", text: "#ffe08d" },
    epic: { accent: "#b46cff", border: "rgba(180, 108, 255, 0.34)", background: "rgba(180, 108, 255, 0.14)", text: "#d4afff" },
    rare: { accent: "#4aa3ff", border: "rgba(74, 163, 255, 0.34)", background: "rgba(74, 163, 255, 0.14)", text: "#9ecbff" },
    common: { accent: "#8e98a8", border: "rgba(142, 152, 168, 0.34)", background: "rgba(142, 152, 168, 0.14)", text: "#d0d5dc" }
  };
  const tierLabel: Record<WorkspaceAchievement["tier"], string> = {
    mythic: "신화",
    legendary: "전설",
    epic: "영웅",
    rare: "희귀",
    common: "일반"
  };
  const filtered = achievements.filter(
    (item) =>
      (selectedTier === "all" || item.tier === selectedTier) &&
      (!showUnlockedOnly || item.unlocked)
  );

  return (
    <div className="workspace-modal achievements-modal mac-achievements-modal">
      <div className="workspace-modal-header">
        <div>
          <strong><span className="panel-title-emoji tone-gold">🏆</span>도전과제</strong>
          <span>{`${unlocked.length}/${achievements.length} · ${Math.round(completion * 100)}%`}</span>
        </div>
        <div className="achievement-header-right">
          <div className="achievement-overall-bar">
            <span style={{ width: `${completion * 100}%` }} />
          </div>
          <button type="button" className="workspace-close-button" onClick={onClose}>×</button>
        </div>
      </div>
      <div className="workspace-modal-body">
        <div className="achievement-summary-row">
          <div className="achievement-summary-filters">
            <button
              type="button"
              className={`workspace-tab-button achievement-tier-button tier-all ${selectedTier === "all" ? "is-active" : ""}`}
              style={
                {
                  "--tier-accent": tierTone.all.accent,
                  "--tier-border": tierTone.all.border,
                  "--tier-background": tierTone.all.background,
                  "--tier-text": tierTone.all.text
                } as CSSProperties
              }
              onClick={() => setSelectedTier("all")}
            >
              <span className="achievement-tier-dot" aria-hidden="true">•</span>
              <span>{`전체 ${unlocked.length}`}</span>
            </button>
            {tierOrder.map((tier) => (
              <button
                key={tier}
                type="button"
                className={`workspace-tab-button achievement-tier-button tier-${tier} ${selectedTier === tier ? "is-active" : ""}`}
                style={
                  {
                    "--tier-accent": tierTone[tier].accent,
                    "--tier-border": tierTone[tier].border,
                    "--tier-background": tierTone[tier].background,
                    "--tier-text": tierTone[tier].text
                  } as CSSProperties
                }
                onClick={() => setSelectedTier(tier)}
              >
                <span className="achievement-tier-dot" aria-hidden="true">•</span>
                <span>{`${tierLabel[tier]} ${achievements.filter((item) => item.tier === tier && item.unlocked).length}`}</span>
              </button>
            ))}
          </div>
          <button
            type="button"
            className={`workspace-tab-button achievement-view-toggle ${showUnlockedOnly ? "is-active" : ""}`}
            onClick={() => setShowUnlockedOnly((current) => !current)}
            title={showUnlockedOnly ? "달성한 도전과제만 보기" : "전체 도전과제 보기"}
          >
            <span className="achievement-view-toggle-icon" aria-hidden="true">👁</span>
            <span>{showUnlockedOnly ? "달성만" : "전부보기"}</span>
          </button>
        </div>

        {selectedTier === "all" ? (
          <div className="achievement-tier-stack">
            {tierOrder.map((tier) => {
              const tierItems = achievements.filter((item) => item.tier === tier && (!showUnlockedOnly || item.unlocked));
              const tierUnlocked = achievements.filter((item) => item.tier === tier && item.unlocked).length;
              const tierTotal = achievements.filter((item) => item.tier === tier).length;
              if (tierItems.length === 0) return null;
              return (
                <section key={tier} className={`achievement-tier-section tier-${tier}`}>
                  <div className="achievement-tier-header">
                    <div className="achievement-tier-title">
                      <strong>{tierLabel[tier]}</strong>
                      <span>{`${tierUnlocked}/${tierTotal}`}</span>
                    </div>
                    <div className="achievement-tier-bar">
                      <span style={{ width: `${(tierUnlocked / Math.max(1, tierTotal)) * 100}%` }} />
                    </div>
                  </div>
                  <div className="achievement-grid">
                    {tierItems.map((item) => (
                      <AchievementCardView key={item.id} achievement={item} />
                    ))}
                  </div>
                </section>
              );
            })}
          </div>
        ) : (
          <div className="achievement-grid">
            {filtered.map((item) => (
              <AchievementCardView key={item.id} achievement={item} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function CharacterSection(props: { title: string; tone: "active" | "available" | "locked"; children: ReactNode }) {
  return (
    <section className={`character-section-card tone-${props.tone}`}>
      <div className="character-section-title">{props.title}</div>
      {props.children}
    </section>
  );
}

function CharacterRosterCard(props: {
  character: CharacterDefinition;
  locked: boolean;
  onVacation?: boolean;
  lockReason?: string;
  extra?: ReactNode;
  footer?: ReactNode;
}) {
  const { character, locked, onVacation = false, lockReason, extra, footer } = props;
  const isHiddenCharacter = character.id.startsWith("secret_");
  const roleMeta = jobCatalog[character.jobRole];
  return (
    <div className={`character-card mac-character-card ${locked ? "is-locked" : ""}`}>
      <div className="character-card-head">
        <div className="character-avatar-wrap">
          <PixelCharacterAvatar character={character} locked={locked} />
        </div>
        <div className="character-card-copy">
          <strong style={locked ? undefined : { color: `#${character.shirtColor}` }}>
            {locked ? "???" : character.name}
            {!locked && isHiddenCharacter ? <span className="character-hidden-badge">히든</span> : null}
          </strong>
          <span>{locked ? "잠금 캐릭터" : character.role}</span>
          <span
            className="character-role-pill"
            title={roleMeta.label}
            style={{ "--role-tint": roleMeta.tint } as CSSProperties}
          >
            <span className="character-role-icon" aria-hidden="true">{roleMeta.icon}</span>
          </span>
        </div>
        <div className="character-card-status">
          {onVacation ? <span className="character-status-pill">휴가</span> : null}
          <span className="character-species-mark">{speciesCatalog[character.species].emoji}</span>
        </div>
      </div>
      {extra}
      <div className="character-card-actions">{footer}</div>
      {locked ? <div className="character-lock-mask"><strong>🔒</strong><span>{lockReason ?? "잠김"}</span></div> : null}
    </div>
  );
}

function PixelCharacterAvatar(props: { character: CharacterDefinition; locked?: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    const safeContext = context;
    const scale = 4;
    canvas.width = 16 * scale;
    canvas.height = 22 * scale;
    safeContext.clearRect(0, 0, canvas.width, canvas.height);

    const skin = `#${props.character.skinTone}`;
    const hair = `#${props.character.hairColor}`;
    const shirt = `#${props.character.shirtColor}`;
    const pants = `#${props.character.pantsColor}`;

    function withAlpha(color: string, alpha: number) {
      if (alpha >= 1) return color;
      if (!color.startsWith("#")) return color;
      const normalized = color.slice(1);
      const full = normalized.length === 3 ? normalized.split("").map((token) => token + token).join("") : normalized;
      const value = Number.parseInt(full, 16);
      const red = (value >> 16) & 255;
      const green = (value >> 8) & 255;
      const blue = value & 255;
      return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
    }

    function px(x: number, y: number, w: number, h: number, color: string, alpha = 1) {
      safeContext.fillStyle = withAlpha(color, alpha);
      safeContext.fillRect(x * scale, y * scale, w * scale, h * scale);
    }

    switch (props.character.species) {
      case "cat":
        px(3, -2, 3, 3, skin);
        px(10, -2, 3, 3, skin);
        px(4, -1, 1, 1, "#f0a0a0");
        px(11, -1, 1, 1, "#f0a0a0");
        px(4, 1, 8, 6, skin);
        px(5, 3, 2, 2, "#60c060");
        px(6, 3, 1, 2, "#1a1a1a");
        px(9, 3, 2, 2, "#60c060");
        px(10, 3, 1, 2, "#1a1a1a");
        px(7, 5, 2, 1, "#f08080");
        px(2, 5, 2, 1, "#dddddd");
        px(12, 5, 2, 1, "#dddddd");
        px(4, 7, 8, 7, shirt);
        px(3, 12, 3, 2, skin);
        px(10, 12, 3, 2, skin);
        px(4, 14, 3, 3, skin);
        px(9, 14, 3, 3, skin);
        px(13, 10, 2, 2, skin);
        px(14, 8, 2, 3, skin);
        break;
      case "dog":
        px(2, 1, 3, 5, hair);
        px(11, 1, 3, 5, hair);
        px(4, 0, 8, 7, skin);
        px(5, 3, 2, 2, "#ffffff");
        px(6, 4, 1, 1, "#333333");
        px(9, 3, 2, 2, "#ffffff");
        px(10, 4, 1, 1, "#333333");
        px(7, 5, 2, 1, "#333333");
        px(7, 6, 2, 1, "#f06060");
        px(4, 7, 8, 7, shirt);
        px(3, 12, 3, 2, skin);
        px(10, 12, 3, 2, skin);
        px(4, 14, 3, 3, skin);
        px(9, 14, 3, 3, skin);
        px(13, 5, 2, 2, skin);
        px(14, 3, 2, 3, skin);
        break;
      case "rabbit":
        px(5, -5, 2, 6, skin);
        px(9, -5, 2, 6, skin);
        px(5, -4, 1, 4, "#f0a0a0");
        px(10, -4, 1, 4, "#f0a0a0");
        px(4, 1, 8, 6, skin);
        px(5, 3, 2, 2, "#d04060");
        px(6, 3, 1, 1, "#1a1a1a");
        px(9, 3, 2, 2, "#d04060");
        px(10, 3, 1, 1, "#1a1a1a");
        px(7, 5, 2, 1, "#f0a0a0");
        px(4, 7, 8, 7, shirt);
        px(3, 12, 3, 2, skin);
        px(10, 12, 3, 2, skin);
        px(5, 14, 3, 3, skin);
        px(8, 14, 3, 3, skin);
        px(13, 11, 3, 3, "#ffffff");
        break;
      case "bear":
        px(3, -1, 3, 3, skin);
        px(10, -1, 3, 3, skin);
        px(4, 0, 1, 1, "#c09060");
        px(11, 0, 1, 1, "#c09060");
        px(4, 1, 8, 7, skin);
        px(6, 5, 4, 3, "#d0b090");
        px(5, 3, 2, 2, "#1a1a1a");
        px(9, 3, 2, 2, "#1a1a1a");
        px(7, 5, 2, 1, "#333333");
        px(3, 8, 10, 7, shirt);
        px(2, 10, 3, 3, skin);
        px(11, 10, 3, 3, skin);
        px(4, 15, 4, 3, skin);
        px(8, 15, 4, 3, skin);
        break;
      case "penguin":
        px(4, 0, 8, 5, "#2a2a3a");
        px(5, 2, 6, 4, "#ffffff");
        px(6, 3, 1, 1, "#1a1a1a");
        px(9, 3, 1, 1, "#1a1a1a");
        px(7, 5, 2, 1, "#f0c040");
        px(3, 6, 10, 8, "#2a2a3a");
        px(5, 7, 6, 6, "#ffffff");
        px(2, 8, 2, 5, "#2a2a3a");
        px(12, 8, 2, 5, "#2a2a3a");
        px(5, 14, 3, 2, "#f0c040");
        px(8, 14, 3, 2, "#f0c040");
        break;
      case "fox":
        px(3, -2, 3, 4, "#e07030");
        px(10, -2, 3, 4, "#e07030");
        px(4, -1, 1, 2, "#ffffff");
        px(11, -1, 1, 2, "#ffffff");
        px(4, 1, 8, 6, skin);
        px(4, 4, 3, 3, "#ffffff");
        px(9, 4, 3, 3, "#ffffff");
        px(5, 3, 2, 1, "#f0c020");
        px(6, 3, 1, 1, "#1a1a1a");
        px(9, 3, 2, 1, "#f0c020");
        px(10, 3, 1, 1, "#1a1a1a");
        px(7, 5, 2, 1, "#333333");
        px(4, 7, 8, 7, shirt);
        px(3, 12, 3, 2, skin);
        px(10, 12, 3, 2, skin);
        px(4, 14, 3, 3, skin);
        px(9, 14, 3, 3, skin);
        px(12, 9, 3, 2, skin);
        px(13, 7, 3, 4, skin);
        px(14, 11, 2, 1, "#ffffff");
        break;
      case "robot":
        px(7, -3, 2, 3, "#8090a0");
        px(6, -4, 4, 1, "#60f0a0");
        px(3, 0, 10, 7, "#a0b0c0");
        px(4, 1, 8, 5, "#8090a0");
        px(5, 3, 2, 2, "#60f0a0");
        px(9, 3, 2, 2, "#60f0a0");
        px(6, 5, 4, 1, "#506070");
        px(3, 7, 10, 8, shirt);
        px(3, 7, 10, 1, "#8090a0");
        px(1, 9, 2, 5, "#8090a0");
        px(13, 9, 2, 5, "#8090a0");
        px(4, 15, 3, 3, "#708090");
        px(9, 15, 3, 3, "#708090");
        break;
      case "claude":
        px(4, 1, 8, 1, shirt);
        px(3, 2, 10, 7, shirt);
        px(1, 3, 2, 2, shirt);
        px(0, 4, 1, 1, shirt);
        px(13, 3, 2, 2, shirt);
        px(15, 4, 1, 1, shirt);
        px(5, 4, 1, 2, "#2a1810");
        px(10, 4, 1, 2, "#2a1810");
        px(4, 9, 1, 3, shirt);
        px(6, 9, 1, 3, shirt);
        px(9, 9, 1, 3, shirt);
        px(11, 9, 1, 3, shirt);
        break;
      case "alien":
        px(3, -1, 10, 2, skin);
        px(2, 1, 12, 6, skin);
        px(4, 3, 3, 3, "#101010");
        px(9, 3, 3, 3, "#101010");
        px(5, 4, 1, 1, "#40ff80");
        px(10, 4, 1, 1, "#40ff80");
        px(5, 7, 6, 5, shirt);
        px(3, 8, 2, 4, shirt);
        px(11, 8, 2, 4, shirt);
        px(5, 12, 2, 4, skin);
        px(9, 12, 2, 4, skin);
        px(7, -3, 2, 2, "#40ff80");
        px(8, -4, 1, 1, "#80ffa0");
        break;
      case "ghost":
        px(4, 0, 8, 3, skin);
        px(3, 3, 10, 6, skin);
        px(5, 4, 2, 2, "#303040");
        px(9, 4, 2, 2, "#303040");
        px(6, 7, 4, 1, "#404050");
        px(3, 9, 3, 3, skin);
        px(6, 10, 4, 2, skin);
        px(10, 9, 3, 3, skin);
        px(4, 12, 2, 1, skin);
        px(8, 12, 2, 1, skin);
        px(12, 12, 1, 1, skin);
        break;
      case "dragon":
        px(4, -2, 2, 2, "#f0c030");
        px(10, -2, 2, 2, "#f0c030");
        px(4, 0, 8, 6, skin);
        px(5, 2, 2, 2, "#ff4020");
        px(9, 2, 2, 2, "#ff4020");
        px(6, 5, 4, 1, "#f06030");
        px(3, 6, 10, 6, shirt);
        px(0, 5, 3, 5, shirt, 0.6);
        px(13, 5, 3, 5, shirt, 0.6);
        px(4, 12, 3, 4, skin);
        px(9, 12, 3, 4, skin);
        px(13, 10, 3, 2, shirt);
        px(14, 12, 2, 1, shirt);
        break;
      case "chicken":
        px(6, -2, 4, 2, "#e03020");
        px(5, 0, 6, 5, skin);
        px(6, 2, 2, 2, "#101010");
        px(11, 3, 2, 1, "#f0a020");
        px(6, 5, 1, 2, "#f03020");
        px(4, 5, 8, 7, shirt);
        px(2, 6, 2, 4, shirt, 0.7);
        px(12, 6, 2, 4, shirt, 0.7);
        px(5, 12, 2, 4, "#f0a020");
        px(9, 12, 2, 4, "#f0a020");
        break;
      case "owl":
        px(3, -1, 3, 3, hair);
        px(10, -1, 3, 3, hair);
        px(4, 1, 8, 6, skin);
        px(4, 3, 3, 3, "#f0e0a0");
        px(9, 3, 3, 3, "#f0e0a0");
        px(5, 4, 2, 2, "#202020");
        px(10, 4, 2, 2, "#202020");
        px(7, 6, 2, 1, "#d09030");
        px(3, 7, 10, 6, shirt);
        px(1, 8, 2, 4, hair);
        px(13, 8, 2, 4, hair);
        px(5, 13, 2, 3, skin);
        px(9, 13, 2, 3, skin);
        break;
      case "frog":
        px(3, 0, 4, 3, skin);
        px(9, 0, 4, 3, skin);
        px(4, 1, 2, 2, "#101010");
        px(10, 1, 2, 2, "#101010");
        px(3, 3, 10, 5, skin);
        px(4, 6, 8, 1, "#f06060");
        px(3, 8, 10, 5, shirt);
        px(1, 9, 2, 4, shirt);
        px(13, 9, 2, 4, shirt);
        px(4, 13, 3, 3, skin);
        px(9, 13, 3, 3, skin);
        break;
      case "panda":
        px(2, -1, 4, 3, "#1a1a1a");
        px(10, -1, 4, 3, "#1a1a1a");
        px(4, 1, 8, 6, skin);
        px(4, 3, 3, 3, "#1a1a1a");
        px(9, 3, 3, 3, "#1a1a1a");
        px(5, 4, 1, 1, "#ffffff");
        px(10, 4, 1, 1, "#ffffff");
        px(7, 5, 2, 1, "#1a1a1a");
        px(3, 7, 10, 6, shirt);
        px(1, 8, 2, 5, "#1a1a1a");
        px(13, 8, 2, 5, "#1a1a1a");
        px(4, 13, 3, 3, "#1a1a1a");
        px(9, 13, 3, 3, "#1a1a1a");
        break;
      case "unicorn":
        px(7, -4, 2, 1, "#f0d040");
        px(7, -3, 2, 1, "#f0c040");
        px(7, -2, 2, 2, "#f0b040");
        px(4, 0, 8, 6, skin);
        px(2, 0, 2, 5, hair);
        px(5, 2, 2, 2, "#ffffff");
        px(6, 3, 1, 1, "#c060c0");
        px(9, 2, 2, 2, "#ffffff");
        px(10, 3, 1, 1, "#c060c0");
        px(3, 6, 10, 7, shirt);
        px(1, 7, 2, 4, shirt);
        px(13, 7, 2, 4, shirt);
        px(4, 13, 3, 3, skin);
        px(9, 13, 3, 3, skin);
        break;
      case "skeleton":
        px(4, 0, 8, 6, "#f0f0e0");
        px(5, 2, 2, 2, "#1a1a1a");
        px(9, 2, 2, 2, "#1a1a1a");
        px(6, 4, 1, 1, "#1a1a1a");
        px(5, 5, 6, 1, "#1a1a1a");
        px(5, 5, 1, 1, "#f0f0e0");
        px(7, 5, 1, 1, "#f0f0e0");
        px(9, 5, 1, 1, "#f0f0e0");
        px(5, 6, 6, 6, "#404040");
        px(6, 7, 4, 1, "#f0f0e0");
        px(6, 9, 4, 1, "#f0f0e0");
        px(3, 7, 2, 5, "#404040");
        px(11, 7, 2, 5, "#404040");
        px(5, 12, 2, 4, "#f0f0e0");
        px(9, 12, 2, 4, "#f0f0e0");
        break;
      case "human":
      default:
        switch (props.character.hatType) {
          case "beanie":
            px(3, -2, 10, 3, "#4040a0");
            break;
          case "cap":
            px(2, -1, 12, 2, "#c04040");
            px(1, 0, 4, 1, "#a03030");
            break;
          case "hardhat":
            px(3, -2, 10, 3, "#f0c040");
            px(2, -1, 12, 1, "#f0c040");
            break;
          case "wizard":
            px(5, -5, 6, 2, "#6040a0");
            px(4, -3, 8, 2, "#6040a0");
            px(3, -1, 10, 2, "#6040a0");
            break;
          case "crown":
            px(4, -2, 8, 1, "#f0c040");
            px(4, -3, 2, 1, "#f0c040");
            px(7, -3, 2, 1, "#f0c040");
            px(10, -3, 2, 1, "#f0c040");
            break;
          case "headphones":
            px(2, 2, 2, 4, "#404040");
            px(12, 2, 2, 4, "#404040");
            px(3, 0, 10, 1, "#505050");
            break;
          case "beret":
            px(3, -1, 11, 2, "#c04040");
            px(3, -2, 8, 1, "#c04040");
            break;
          default:
            break;
        }
        px(4, 0, 8, 3, hair);
        px(3, 1, 1, 2, hair);
        px(12, 1, 1, 2, hair);
        px(4, 3, 8, 5, skin);
        px(5, 4, 2, 2, "#ffffff");
        px(6, 5, 1, 1, "#333333");
        px(9, 4, 2, 2, "#ffffff");
        px(10, 5, 1, 1, "#333333");
        switch (props.character.accessory) {
          case "glasses":
            px(4, 4, 3, 1, "#4060a0");
            px(7, 4, 1, 1, "#4060a0");
            px(8, 4, 3, 1, "#4060a0");
            break;
          case "sunglasses":
            px(4, 4, 3, 2, "#1a1a1a");
            px(7, 4, 1, 1, "#1a1a1a");
            px(8, 4, 3, 2, "#1a1a1a");
            break;
          case "scarf":
            px(3, 7, 10, 2, "#c04040");
            break;
          case "mask":
            px(4, 5, 8, 3, "#2a2a2a");
            break;
          case "earring":
            px(13, 4, 1, 2, "#f0c040");
            break;
          default:
            break;
        }
        px(3, 8, 10, 6, shirt);
        px(1, 9, 2, 5, shirt);
        px(13, 9, 2, 5, shirt);
        px(0, 13, 2, 2, skin);
        px(14, 13, 2, 2, skin);
        px(4, 14, 4, 4, pants);
        px(8, 14, 4, 4, pants);
        px(4, 18, 3, 2, pants);
        px(9, 18, 3, 2, pants);
        px(3, 19, 4, 2, "#4a5060");
        px(9, 19, 4, 2, "#4a5060");
        break;
    }

    if (props.locked) {
      context.fillStyle = "rgba(0,0,0,0.65)";
      context.fillRect(0, 0, canvas.width, canvas.height);
    }
  }, [props.character, props.locked]);

  return <canvas ref={canvasRef} className="pixel-character-canvas" />;
}

function AccessoryPreviewCard(props: {
  item: AccessoryDefinition;
  themeId: string;
  enabled: boolean;
  locked: boolean;
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;

    const width = 108;
    const height = 58;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    context.clearRect(0, 0, width, height);

    drawAccessoryPreviewScene(context, props.item, props.themeId, props.locked);
  }, [props.item, props.themeId, props.locked]);

  return (
    <div className="accessory-preview-card">
      <canvas ref={canvasRef} className="accessory-preview-canvas" />
    </div>
  );
}

function BackgroundPreviewCard(props: { choice: BackgroundDefinition; locked: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;

    const width = 108;
    const height = 58;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    context.setTransform(dpr, 0, 0, dpr, 0, 0);
    context.clearRect(0, 0, width, height);

    drawBackgroundPreviewScene(context, props.choice.id, props.locked);
  }, [props.choice.id, props.locked]);

  return (
    <div className="background-preview">
      <canvas ref={canvasRef} className="accessory-preview-canvas" />
    </div>
  );
}

function accessoryIconGlyph(itemId: string) {
  const glyphs: Record<string, string> = {
    sofa: "🛋️",
    sideTable: "🪑",
    coffeeMachine: "☕",
    plant: "🌿",
    picture: "🖼️",
    neonSign: "💡",
    rug: "▬",
    bookshelf: "📚",
    aquarium: "🐟",
    arcade: "🎮",
    whiteboard: "🗒️",
    lamp: "💡",
    cat: "🐈",
    tv: "📺",
    fan: "🌀",
    calendar: "🗓️",
    poster: "📄",
    trashcan: "🗑️",
    cushion: "●"
  };
  return glyphs[itemId] ?? "◻";
}

function backgroundIconGlyph(themeId: string) {
  const glyphs: Record<string, string> = {
    auto: "✦",
    sunny: "☀",
    clearSky: "⛅",
    sunset: "🌇",
    goldenHour: "🌤",
    dusk: "🌆",
    moonlit: "☾",
    starryNight: "★",
    aurora: "✧",
    milkyWay: "✦",
    storm: "⚡",
    rain: "☔",
    snow: "❄",
    fog: "〰",
    cherryBlossom: "🌸",
    autumn: "🍂",
    forest: "🌳",
    neonCity: "▥",
    ocean: "≋",
    desert: "☀",
    volcano: "▲"
  };
  return glyphs[themeId] ?? "✦";
}

function previewPalette(themeId: string) {
  const palettes: Record<string, { skyTop: string; skyBottom: string; floorTop: string; floorBottom: string; wallTop: string; wallBottom: string }> = {
    auto: { skyTop: "#9ed3ff", skyBottom: "#4d78b9", floorTop: "#b98654", floorBottom: "#8b5a34", wallTop: "#e6edf4", wallBottom: "#cad9e3" },
    sunny: { skyTop: "#b9d9ff", skyBottom: "#6faef3", floorTop: "#be8a53", floorBottom: "#8e5a31", wallTop: "#edf4fb", wallBottom: "#d4e1ea" },
    clearSky: { skyTop: "#88c7ff", skyBottom: "#437dcb", floorTop: "#be8a53", floorBottom: "#8e5a31", wallTop: "#e8f0f8", wallBottom: "#c4d7e8" },
    sunset: { skyTop: "#ffbb76", skyBottom: "#6b3e7b", floorTop: "#b57b48", floorBottom: "#7c4d28", wallTop: "#f4dec8", wallBottom: "#d7b593" },
    goldenHour: { skyTop: "#ffd08d", skyBottom: "#b3664b", floorTop: "#be8a53", floorBottom: "#8e5a31", wallTop: "#f3dfc0", wallBottom: "#dcbc94" },
    dusk: { skyTop: "#7f8fd8", skyBottom: "#342b5f", floorTop: "#8f6d58", floorBottom: "#65473b", wallTop: "#d9d4e5", wallBottom: "#b8b2d0" },
    moonlit: { skyTop: "#6d86c7", skyBottom: "#18203e", floorTop: "#586a84", floorBottom: "#354356", wallTop: "#cad4e6", wallBottom: "#97a4bd" },
    starryNight: { skyTop: "#445893", skyBottom: "#0a1020", floorTop: "#4b5c78", floorBottom: "#2c384d", wallTop: "#c8d1e3", wallBottom: "#8d9ab2" },
    aurora: { skyTop: "#4ac0d4", skyBottom: "#141f3a", floorTop: "#4b5c78", floorBottom: "#2c384d", wallTop: "#d6e5ee", wallBottom: "#97a9c2" },
    milkyWay: { skyTop: "#5e5fab", skyBottom: "#0c1020", floorTop: "#4b5c78", floorBottom: "#2c384d", wallTop: "#d2d9ea", wallBottom: "#98a2bc" },
    storm: { skyTop: "#76869a", skyBottom: "#273347", floorTop: "#7d8790", floorBottom: "#4d5560", wallTop: "#d3d8de", wallBottom: "#a4aeb9" },
    rain: { skyTop: "#91a0b5", skyBottom: "#3c495b", floorTop: "#7d8790", floorBottom: "#4d5560", wallTop: "#dae0e7", wallBottom: "#aeb7c2" },
    snow: { skyTop: "#dbe6f7", skyBottom: "#95a7bd", floorTop: "#c3cbd4", floorBottom: "#9ba5b0", wallTop: "#f5f8fc", wallBottom: "#dbe3ed" },
    fog: { skyTop: "#c7cfda", skyBottom: "#697586", floorTop: "#aab3be", floorBottom: "#7e8996", wallTop: "#edf1f6", wallBottom: "#d0d8e1" },
    cherryBlossom: { skyTop: "#ffdbe8", skyBottom: "#d59cb3", floorTop: "#d2b6ac", floorBottom: "#a7867c", wallTop: "#fff1f6", wallBottom: "#ebd3dd" },
    autumn: { skyTop: "#ffdd98", skyBottom: "#9b5c2f", floorTop: "#b07a45", floorBottom: "#7b4d28", wallTop: "#f7e4cb", wallBottom: "#d6b78e" },
    forest: { skyTop: "#85c89a", skyBottom: "#365b46", floorTop: "#8f7855", floorBottom: "#625038", wallTop: "#e0ebdf", wallBottom: "#bed0bc" },
    neonCity: { skyTop: "#8a6cff", skyBottom: "#1f133f", floorTop: "#342655", floorBottom: "#201538", wallTop: "#cdc3ef", wallBottom: "#8d7dbd" },
    ocean: { skyTop: "#8ddfff", skyBottom: "#287ccf", floorTop: "#78a6b3", floorBottom: "#4b7481", wallTop: "#e6f7fb", wallBottom: "#b9d9e0" },
    desert: { skyTop: "#ffd697", skyBottom: "#d58b4a", floorTop: "#c69257", floorBottom: "#926437", wallTop: "#f6e3c3", wallBottom: "#dfc18b" },
    volcano: { skyTop: "#ffb165", skyBottom: "#290d15", floorTop: "#402124", floorBottom: "#211012", wallTop: "#d9c4c2", wallBottom: "#a68887" }
  };
  return palettes[themeId] ?? palettes.auto;
}

function drawAccessoryPreviewScene(
  context: CanvasRenderingContext2D,
  item: AccessoryDefinition,
  themeId: string,
  locked: boolean
) {
  const width = 108;
  const height = 58;
  const palette = previewPalette(themeId);

  const skyGradient = context.createLinearGradient(0, 0, 0, 24);
  skyGradient.addColorStop(0, palette.skyTop);
  skyGradient.addColorStop(1, palette.skyBottom);
  context.fillStyle = palette.wallBottom;
  context.fillRect(0, 0, width, 42);
  context.fillStyle = palette.wallTop;
  context.fillRect(0, 0, width, 19);
  context.fillStyle = "#d9e9f8";
  context.globalAlpha = 0.28;
  context.fillRect(0, 0, width, 1);
  context.globalAlpha = 1;

  context.fillStyle = "#f4fbff";
  context.fillRect(65, 6, 28, 19);
  context.fillStyle = skyGradient;
  context.fillRect(67, 8, 24, 15);
  context.fillStyle = "#ffffff";
  context.globalAlpha = 0.2;
  context.fillRect(69, 9, 1, 13);
  context.fillRect(79, 9, 1, 13);
  context.globalAlpha = 1;

  context.fillStyle = "#c08f58";
  context.fillRect(0, 42, width, 16);
  context.fillStyle = palette.floorTop;
  context.fillRect(0, 42, width, 8);
  context.fillStyle = palette.floorBottom;
  for (let x = 0; x < width; x += 8) {
    context.fillRect(x, 42, 1, 16);
  }
  context.globalAlpha = 0.16;
  context.fillStyle = "#000000";
  for (let y = 44; y < height; y += 4) {
    context.fillRect(0, y, width, 1);
  }
  context.globalAlpha = 1;

  if (item.sprite?.length) {
    drawCustomAccessoryPreview(context, item.sprite);
  } else {
    drawFurniturePreview(context, item.id);
  }

  if (locked) {
    context.fillStyle = "rgba(0,0,0,0.56)";
    context.fillRect(0, 0, width, height);
  }
}

function drawCustomAccessoryPreview(context: CanvasRenderingContext2D, sprite: string[][]) {
  const rows = Math.max(1, sprite.length);
  const cols = Math.max(1, ...sprite.map((row) => row.length || 0));
  const cellSize = Math.min(8, Math.floor(Math.min(48 / rows, 56 / cols)));
  const originX = Math.round((108 - cols * cellSize) / 2);
  const originY = Math.round((58 - rows * cellSize) / 2) + 4;
  for (let rowIndex = 0; rowIndex < sprite.length; rowIndex += 1) {
    const row = sprite[rowIndex] ?? [];
    for (let colIndex = 0; colIndex < row.length; colIndex += 1) {
      const color = (row[colIndex] ?? "").trim();
      if (!color) continue;
      context.fillStyle = color.startsWith("#") ? color : `#${color}`;
      context.fillRect(originX + colIndex * cellSize, originY + rowIndex * cellSize, cellSize, cellSize);
    }
  }
}

function drawFurniturePreview(context: CanvasRenderingContext2D, itemId: string) {
  const px = (x: number, y: number, w: number, h: number, color: string, alpha = 1) => {
    context.globalAlpha = alpha;
    context.fillStyle = color;
    context.fillRect(x, y, w, h);
    context.globalAlpha = 1;
  };

  switch (itemId) {
    case "sofa":
      px(18, 34, 44, 4, "#000000", 0.12);
      px(26, 18, 28, 12, "#8b66db");
      px(20, 24, 40, 12, "#6f4fc0");
      px(18, 22, 6, 16, "#6b49b9");
      px(56, 22, 6, 16, "#6b49b9");
      break;
    case "sideTable":
      px(45, 33, 18, 3, "#000000", 0.12);
      px(47, 20, 14, 4, "#d8ae75");
      px(50, 24, 8, 12, "#8b6135");
      break;
    case "coffeeMachine":
      px(47, 33, 14, 3, "#000000", 0.12);
      px(47, 17, 14, 18, "#7e8895");
      px(46, 15, 16, 4, "#a8b1bb");
      px(50, 21, 8, 6, "#cfd5dd");
      px(53, 27, 2, 6, "#2f3844");
      break;
    case "plant":
      px(47, 34, 14, 3, "#000000", 0.12);
      px(49, 28, 10, 7, "#9b6a3d");
      px(45, 16, 18, 10, "#55a86f");
      px(48, 12, 5, 7, "#2e8a46");
      px(55, 12, 5, 7, "#2e8a46");
      break;
    case "picture":
      px(36, 13, 32, 22, "#5d3d90");
      px(39, 16, 26, 16, "#d5e8fa");
      px(41, 18, 22, 8, "#8ac285");
      px(49, 17, 7, 7, "#f2c15b");
      break;
    case "neonSign":
      px(29, 12, 50, 10, "#3c275f");
      px(32, 15, 44, 4, "#bc6cff");
      break;
    case "rug":
      px(21, 35, 60, 8, "#9b6cff");
      px(25, 37, 52, 4, "#c991ff");
      break;
    case "bookshelf":
      px(44, 14, 18, 28, "#7a5433");
      px(46, 16, 14, 24, "#936640");
      px(48, 19, 10, 3, "#59a6ff");
      px(48, 25, 10, 3, "#ffd46a");
      px(48, 31, 10, 3, "#8fe38a");
      break;
    case "aquarium":
      px(36, 28, 34, 4, "#4d6a7b");
      px(38, 17, 30, 15, "#59b8ff");
      px(43, 24, 7, 3, "#ffd46a");
      px(55, 22, 8, 4, "#ffffff", 0.45);
      break;
    case "arcade":
      px(46, 13, 18, 30, "#40345a");
      px(48, 16, 14, 10, "#73b5ff");
      px(53, 29, 4, 4, "#f05454");
      px(51, 35, 8, 4, "#6cd96d");
      break;
    case "whiteboard":
      px(34, 13, 40, 22, "#d8dee8");
      px(36, 15, 36, 18, "#ffffff");
      px(40, 20, 14, 2, "#6aa5ff");
      px(56, 24, 10, 2, "#f4974f");
      px(34, 35, 4, 8, "#8993a3");
      px(70, 35, 4, 8, "#8993a3");
      break;
    case "lamp":
      px(51, 14, 6, 7, "#ffe79a");
      px(53, 21, 2, 15, "#8d93a2");
      px(47, 36, 14, 3, "#6b7280");
      break;
    case "cat":
      px(43, 32, 22, 5, "#000000", 0.12);
      px(48, 24, 12, 8, "#d9bf8d");
      px(46, 20, 4, 6, "#d9bf8d");
      px(58, 20, 4, 6, "#d9bf8d");
      px(60, 24, 5, 3, "#d9bf8d");
      break;
    case "tv":
      px(35, 16, 38, 20, "#454c56");
      px(39, 20, 30, 12, "#91cbff");
      px(51, 36, 6, 5, "#7b838f");
      break;
    case "fan":
      px(53, 17, 2, 18, "#8f98a5");
      px(47, 22, 14, 6, "#c7d1de");
      px(49, 20, 10, 10, "#dee7f2");
      px(47, 35, 14, 3, "#6f7785");
      break;
    case "calendar":
      px(42, 14, 24, 20, "#ffffff");
      px(42, 14, 24, 5, "#e96969");
      px(47, 22, 14, 8, "#d6dde8");
      break;
    case "poster":
      px(42, 12, 24, 26, "#f4f1ff");
      px(46, 17, 16, 6, "#9f85ff");
      px(46, 27, 16, 5, "#7ed6a0");
      break;
    case "trashcan":
      px(49, 24, 10, 13, "#8a97a6");
      px(47, 22, 14, 3, "#b7c0cb");
      break;
    case "cushion":
      px(45, 28, 18, 8, "#8e69dc");
      px(48, 30, 12, 4, "#c79aff");
      break;
    default:
      px(44, 18, 20, 16, "#7d5ad6");
      break;
  }
}

function drawBackgroundPreviewScene(
  context: CanvasRenderingContext2D,
  themeId: string,
  locked: boolean
) {
  const width = 108;
  const height = 58;
  const palette = previewPalette(themeId);
  const gradient = context.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, palette.skyTop);
  gradient.addColorStop(0.7, palette.skyBottom);
  gradient.addColorStop(1, "#11161f");
  context.fillStyle = gradient;
  context.fillRect(0, 0, width, height);

  context.fillStyle = "rgba(255,255,255,0.18)";
  context.fillRect(0, 0, width, 1);
  context.fillStyle = "rgba(255,255,255,0.06)";
  context.fillRect(8, 39, 92, 1);

  context.fillStyle = "rgba(255,255,255,0.88)";
  context.font = "bold 16px monospace";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(backgroundIconGlyph(themeId), width / 2, height / 2 + 2);

  if (locked) {
    context.fillStyle = "rgba(0,0,0,0.55)";
    context.fillRect(0, 0, width, height);
  }
}

function MarkdownDocumentView(props: { content: string }) {
  const lines = props.content.split(/\r?\n/);
  return (
    <div className="markdown-report-content">
      {lines.map((line, index) => {
        if (!line.trim()) return <div key={index} className="markdown-gap" />;
        if (line.startsWith("### ")) return <h3 key={index}>{line.slice(4)}</h3>;
        if (line.startsWith("## ")) return <h2 key={index}>{line.slice(3)}</h2>;
        if (line.startsWith("# ")) return <h1 key={index}>{line.slice(2)}</h1>;
        if (line.startsWith("- ") || line.startsWith("* ")) return <li key={index}>{line.slice(2)}</li>;
        if (line.startsWith("> ")) return <blockquote key={index}>{line.slice(2)}</blockquote>;
        if (line.startsWith("```")) return <pre key={index}>{line}</pre>;
        return <p key={index}>{line}</p>;
      })}
    </div>
  );
}

function AchievementCardView(props: { achievement: WorkspaceAchievement }) {
  const { achievement } = props;
  const tierLabel: Record<WorkspaceAchievement["tier"], string> = {
    mythic: "신화",
    legendary: "전설",
    epic: "영웅",
    rare: "희귀",
    common: "일반"
  };
  return (
    <div className={`achievement-card mac-achievement-card tier-${achievement.tier} ${achievement.unlocked ? "is-unlocked" : "is-locked"}`}>
      <div className="achievement-card-icon">{achievement.unlocked ? achievement.icon : achievement.icon}</div>
      <strong>{achievement.unlocked ? achievement.title : "???"}</strong>
      <span>{achievement.unlocked ? achievement.subtitle : `${tierLabel[achievement.tier]} 도전과제`}</span>
      {!achievement.unlocked ? (
        <div className="achievement-card-lock-mask">
          <strong>🔒</strong>
          <span>{`${tierLabel[achievement.tier]} 잠금`}</span>
        </div>
      ) : null}
      <div className="achievement-card-bottom-left">{achievement.unlocked ? <span className="achievement-clear-badge">✓</span> : null}</div>
      <div className="achievement-card-bottom-right">{`+${achievement.xp}`}</div>
    </div>
  );
}

function sortCharacters(characters: CharacterDefinition[], sortMode: "default" | "name" | "role" | "species") {
  return [...characters].sort((lhs, rhs) => {
    switch (sortMode) {
      case "name":
        return lhs.name.localeCompare(rhs.name, "ko");
      case "role":
        return jobCatalog[lhs.jobRole].label.localeCompare(jobCatalog[rhs.jobRole].label, "ko");
      case "species":
        return speciesCatalog[lhs.species].label.localeCompare(speciesCatalog[rhs.species].label, "ko");
      default:
        return 0;
    }
  });
}

function LockPanel(props: {
  preferences: WorkspacePreferences;
  updatePreferences: WorkspaceOverlayManagerProps["updatePreferences"];
  onClose: () => void;
}) {
  const { preferences, updatePreferences, onClose } = props;
  return (
    <div className="workspace-modal lock-modal">
      <div className="workspace-modal-header">
        <div>
          <strong>세션 잠금</strong>
          <span>바로 잠그거나 PIN을 수정합니다.</span>
        </div>
        <button type="button" className="workspace-close-button" onClick={onClose}>×</button>
      </div>
      <div className="workspace-modal-body centered">
        <div className="lock-hero">🔒</div>
        <input
          className="lock-input"
          type="password"
          value={preferences.lockPin}
          placeholder="PIN 입력"
          onChange={(event) => updatePreferences({ lockPin: event.target.value })}
        />
        <div className="settings-action-row">
          <button type="button" className="hero-action-button" onClick={() => updatePreferences({ isLocked: true })}>
            잠그기
          </button>
          <button type="button" className="ghost-link-button" onClick={() => updatePreferences({ isLocked: false })}>
            잠금 해제
          </button>
        </div>
      </div>
    </div>
  );
}

function SettingsCard(props: { title: ReactNode; children: ReactNode }) {
  return (
    <section className="settings-card">
      <strong>{props.title}</strong>
      {props.children}
    </section>
  );
}

function EditableShortcutRows(props: { rows: Array<{ key: string; labelKey: string; icon: string }>; values: Record<string, string>; onChange: (key: string, value: string) => void }) {
  return (
    <div className="shortcut-rows">
      {props.rows.map((row) => (
        <div key={row.key} className="shortcut-row">
          <span className="shortcut-label"><span className="panel-title-emoji tone-blue">{row.icon}</span>{t(row.labelKey)}</span>
          <input value={props.values[row.key] ?? ""} onChange={(event) => props.onChange(row.key, event.target.value)} />
        </div>
      ))}
    </div>
  );
}

function StepperCard(props: { title: string; value: number; min: number; max: number; onChange: (value: number) => void }) {
  const { title, value, min, max, onChange } = props;
  return (
    <div className="settings-stepper-card">
      <span>{title}</span>
      <div className="settings-stepper-row">
        <button type="button" className="mini-action-button" onClick={() => onChange(Math.max(min, value - 1))}>−</button>
        <strong>{value}</strong>
        <button type="button" className="mini-action-button" onClick={() => onChange(Math.min(max, value + 1))}>＋</button>
      </div>
    </div>
  );
}

function ToggleRow(props: { label: string; enabled: boolean; onToggle: () => void }) {
  const { label, enabled, onToggle } = props;
  return (
    <button type="button" className="settings-toggle-row toggle-button-row" onClick={onToggle}>
      <span>{label}</span>
      <span className={`toggle-fake ${enabled ? "is-on" : ""}`} />
    </button>
  );
}

function countUnlockedAchievements(sessions: SessionSnapshot[], preferences: WorkspacePreferences, reportCount: number) {
  return buildWorkspaceAchievements(preferences, sessions, reportCount).filter((item) => item.unlocked).length;
}

function formatCompactNumber(value: number) {
  if (!value) return "0";
  if (value >= 1000) return `${(value / 1000).toFixed(1)}k`;
  return String(Math.round(value));
}
