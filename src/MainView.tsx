import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";
import { SidebarView } from "./SidebarView";
import { TerminalAreaView } from "./TerminalAreaView";
import { OfficeSceneView } from "./OfficeSceneView";
import { ActionCenterView, CommandPaletteView, SessionNotificationBannerStack, type SessionNotificationItem } from "./OverlayViews";
import { PixelStripView } from "./PixelStripView";
import { SessionLockOverlay, WorkspaceOverlayManager, type WorkspacePanelKind } from "./WorkspacePanels";
import { OnboardingOverlay } from "./OnboardingOverlay";
import type { AgentProvider, CLIInstallResult, CLIStatus, CLIStatusPayload, ImageAttachment, ReportReference, SessionSnapshot } from "./types";
import type { AppViewMode, ProjectGroup, SessionStatusFilter, SidebarSortOption, TerminalViewMode } from "./uiModel";
import type { NewSessionDraftState, NewSessionPresetId, NewSessionProjectRecord } from "./newSessionPreferences";
import { t, tf } from "./localizationCatalog";
import { formatTokens } from "./sessionUtils";
import { NewSessionSheet } from "./NewSessionSheet";
import {
  applyWorkspacePreferences,
  buildWorkspaceAchievements,
  deriveWorkspaceProgress,
  getTotalAchievementCount,
  getTotalAccessoryCount,
  getTotalCharacterCount,
  loadWorkspacePreferences,
  saveWorkspacePreferences,
  type WorkspacePreferences
} from "./workspaceState";

interface MainViewProps {
  sessions: SessionSnapshot[];
  selectedSession: SessionSnapshot | null;
  claudeStatus: CLIStatus;
  codexStatus: CLIStatus;
  geminiStatus: CLIStatus;
  refreshCLIStatuses: () => Promise<CLIStatusPayload>;
  installCLI: (provider: AgentProvider) => Promise<CLIInstallResult>;
  sidebarCollapsed: boolean;
  setSidebarCollapsed: (value: boolean | ((current: boolean) => boolean)) => void;
  appViewMode: AppViewMode;
  setAppViewMode: (value: AppViewMode) => void;
  terminalViewMode: TerminalViewMode;
  setTerminalViewMode: (value: TerminalViewMode) => void;
  officeExpanded: boolean;
  setOfficeExpanded: (value: boolean | ((current: boolean) => boolean)) => void;
  searchQuery: string;
  setSearchQuery: (value: string) => void;
  statusFilter: SessionStatusFilter;
  setStatusFilter: (value: SessionStatusFilter) => void;
  sortOption: SidebarSortOption;
  setSortOption: (value: SidebarSortOption) => void;
  filterCounts: {
    all: number;
    active: number;
    processing: number;
    completed: number;
    attention: number;
  };
  pinnedSessionIds: string[];
  togglePinnedSession: (sessionId: string) => void;
  groupedSessions: ProjectGroup[];
  totals: {
    active: number;
    processing: number;
    attention: number;
    completed: number;
    tokens: number;
  };
  tokenLeaders: SessionSnapshot[];
  prompt: string;
  setPrompt: (value: string) => void;
  busy: boolean;
  openNewSession: () => void;
  refreshSnapshot: () => void;
  stopSelectedSession: () => void;
  approvePendingApproval: () => void;
  denyPendingApproval: () => void;
  dismissDangerousWarning: () => void;
  dismissSensitiveWarning: () => void;
  sendPrompt: (event: FormEvent) => void;
  sendPromptToSession: (sessionId: string, prompt: string) => Promise<void>;
  selectSession: (sessionId: string) => void;
  removeSession: (sessionId: string) => void;
  notifications: SessionNotificationItem[];
  dismissNotification: (notificationId: string) => void;
  showCreateDialog: boolean;
  setShowCreateDialog: (value: boolean) => void;
  showActionCenter: boolean;
  setShowActionCenter: (value: boolean) => void;
  showCommandPalette: boolean;
  setShowCommandPalette: (value: boolean) => void;
  newSessionDraft: NewSessionDraftState;
  updateNewSessionDraft: (patch: Partial<NewSessionDraftState>) => void;
  favoriteProjects: NewSessionProjectRecord[];
  recentProjects: NewSessionProjectRecord[];
  pluginRuntimeVersion: number;
  isCurrentDraftFavorite: boolean;
  chooseSuggestedProject: (project: NewSessionProjectRecord) => void;
  toggleDraftFavorite: () => void;
  applyNewSessionPreset: (preset: NewSessionPresetId) => void;
  handlePickDirectory: () => void;
  handleAddPluginDirectory: () => void;
  handleCreateSession: () => void | Promise<void>;
}

type PixelIconName =
  | "menuOpen"
  | "menuClosed"
  | "split"
  | "office"
  | "strip"
  | "terminal"
  | "settings"
  | "characters"
  | "accessories"
  | "lockClosed"
  | "lockOpen"
  | "layout"
  | "bug"
  | "command"
  | "notify"
  | "add"
  | "refresh"
  | "stop"
  | "focus"
  | "expand"
  | "collapse";

const pixelIconPatterns: Record<PixelIconName, string[]> = {
  menuOpen: ["10000", "11000", "11100", "11000", "10000"],
  menuClosed: ["00100", "00110", "00111", "00110", "00100"],
  split: ["11011", "11011", "00000", "11011", "11011"],
  office: ["11111", "10001", "10101", "10001", "11111"],
  strip: ["11111", "00000", "11111", "00000", "11111"],
  terminal: ["10000", "01000", "00100", "01000", "11111"],
  settings: ["01010", "11111", "01110", "11111", "01010"],
  characters: ["01010", "11111", "01110", "11111", "01010"],
  accessories: ["10001", "01010", "00100", "01010", "10001"],
  lockClosed: ["01110", "10001", "11111", "11011", "11111"],
  lockOpen: ["00110", "01001", "11111", "11011", "11111"],
  layout: ["11111", "10001", "10111", "10001", "11111"],
  bug: ["10001", "01110", "11111", "01010", "10101"],
  command: ["10001", "01010", "00100", "01010", "10001"],
  notify: ["00100", "01110", "01110", "11111", "00100"],
  add: ["00100", "00100", "11111", "00100", "00100"],
  refresh: ["01110", "10011", "10101", "11001", "01110"],
  stop: ["11111", "11111", "11111", "11111", "11111"],
  focus: ["10001", "01010", "00100", "01010", "10001"],
  expand: ["00100", "01110", "10101", "00100", "00100"],
  collapse: ["00100", "00100", "10101", "01110", "00100"]
};

function PixelIcon(props: { name: PixelIconName; compact?: boolean; tone?: "default" | "accent" | "danger"; decorative?: boolean }) {
  const rows = pixelIconPatterns[props.name];
  return (
    <span
      className={`pixel-icon ${props.compact ? "is-compact" : ""} tone-${props.tone ?? "default"}`}
      aria-hidden={props.decorative ?? true}
    >
      {rows.flatMap((row, rowIndex) =>
        row.split("").map((cell, columnIndex) => (
          <span key={`${props.name}-${rowIndex}-${columnIndex}`} className={`pixel-dot ${cell === "1" ? "is-on" : ""}`} />
        ))
      )}
    </span>
  );
}

function GlyphIcon(props: { symbol: string; tone?: "default" | "accent" | "danger" }) {
  return <span className={`emoji-icon tone-${props.tone ?? "default"}`}>{props.symbol}</span>;
}

function viewModeIcon(mode: AppViewMode): ReactNode {
  switch (mode) {
    case "split":
      return <GlyphIcon symbol="▥" />;
    case "office":
      return <GlyphIcon symbol="🏢" />;
    case "strip":
      return <GlyphIcon symbol="☰" />;
    case "terminal":
      return <GlyphIcon symbol="⌘" />;
  }
}

function statusPill(label: string, tone: "neutral" | "green" | "red" | "accent") {
  return <span className={`chrome-pill tone-${tone}`}>{label}</span>;
}

function viewModeLabel(mode: AppViewMode): string {
  switch (mode) {
    case "split":
      return t("view.split");
    case "office":
      return t("view.office");
    case "strip":
      return t("view.strip");
    case "terminal":
      return t("view.terminal");
  }
}

export function MainView(props: MainViewProps) {
  const {
    sessions,
    selectedSession,
    claudeStatus,
    codexStatus,
    geminiStatus,
    refreshCLIStatuses,
    installCLI,
    sidebarCollapsed,
    setSidebarCollapsed,
    appViewMode,
    setAppViewMode,
    terminalViewMode,
    setTerminalViewMode,
    officeExpanded,
    setOfficeExpanded,
    searchQuery,
    setSearchQuery,
    statusFilter,
    setStatusFilter,
    sortOption,
    setSortOption,
    filterCounts,
    pinnedSessionIds,
    togglePinnedSession,
    groupedSessions,
    totals,
    tokenLeaders,
    prompt,
    setPrompt,
    busy,
    openNewSession,
    refreshSnapshot,
    stopSelectedSession,
    approvePendingApproval,
    denyPendingApproval,
    dismissDangerousWarning,
    dismissSensitiveWarning,
    sendPrompt,
    sendPromptToSession,
    selectSession,
    removeSession,
    notifications,
    dismissNotification,
    showCreateDialog,
    setShowCreateDialog,
    showActionCenter,
    setShowActionCenter,
    showCommandPalette,
    setShowCommandPalette,
    newSessionDraft,
    updateNewSessionDraft,
    favoriteProjects,
    recentProjects,
    pluginRuntimeVersion,
    isCurrentDraftFavorite,
    chooseSuggestedProject,
    toggleDraftFavorite,
    applyNewSessionPreset,
    handlePickDirectory,
    handleAddPluginDirectory,
    handleCreateSession
  } = props;

  const officeHeight = officeExpanded ? 380 : 240;
  const [workspacePanel, setWorkspacePanel] = useState<WorkspacePanelKind | null>(null);
  const [showBugReport, setShowBugReport] = useState(false);
  const [showOnboarding, setShowOnboarding] = useState<boolean>(() => !window.localStorage.getItem("doffice.onboarding.completed"));
  const [workspacePreferences, setWorkspacePreferences] = useState<WorkspacePreferences>(loadWorkspacePreferences);
  const [reportEntries, setReportEntries] = useState<ReportReference[]>([]);
  const [reportLoading, setReportLoading] = useState(false);
  const showOfficeSplitPane = appViewMode === "split";

  const knownProjectPaths = useMemo(
    () =>
      Array.from(
        new Set(
          [...sessions.map((session) => session.projectPath), ...favoriteProjects.map((project) => project.path), ...recentProjects.map((project) => project.path)].filter(Boolean)
        )
      ),
    [favoriteProjects, recentProjects, sessions]
  );
  const reportRefreshKey = useMemo(
    () => sessions.map((session) => `${session.id}:${session.lastReportGeneratedAt || session.lastReportPath || ""}`).join("||"),
    [sessions]
  );

  useEffect(() => {
    saveWorkspacePreferences(workspacePreferences);
    applyWorkspacePreferences(workspacePreferences);
  }, [workspacePreferences]);

  useEffect(() => {
    function handleShowTutorial() {
      setAppViewMode("split");
      setTerminalViewMode("grid");
      setShowOnboarding(true);
    }

    window.addEventListener("doffice:show-tutorial", handleShowTutorial);
    return () => window.removeEventListener("doffice:show-tutorial", handleShowTutorial);
  }, [setAppViewMode, setTerminalViewMode]);

  function dismissOnboarding() {
    window.localStorage.setItem("doffice.onboarding.completed", "1");
    setShowOnboarding(false);
  }

  function completeOnboarding() {
    dismissOnboarding();
    setShowCreateDialog(true);
  }

  async function refreshReports() {
    setReportLoading(true);
    try {
      const nextEntries = await window.doffice.listReports(knownProjectPaths);
      setReportEntries(nextEntries);
    } finally {
      setReportLoading(false);
    }
  }

  useEffect(() => {
    void refreshReports();
  }, [knownProjectPaths.join("||"), reportRefreshKey]);

  function updateWorkspacePreferences(
    patch: Partial<WorkspacePreferences> | ((current: WorkspacePreferences) => WorkspacePreferences)
  ) {
    setWorkspacePreferences((current) =>
      typeof patch === "function" ? patch(current) : { ...current, ...patch }
    );
  }

  const progress = useMemo(
    () => deriveWorkspaceProgress(workspacePreferences, sessions, reportEntries.length),
    [reportEntries.length, sessions, workspacePreferences]
  );
  const achievements = useMemo(
    () => buildWorkspaceAchievements(workspacePreferences, sessions, reportEntries.length),
    [pluginRuntimeVersion, reportEntries.length, sessions, workspacePreferences]
  );
  const unlockedAchievements = achievements.filter((item) => item.unlocked).length;
  const workspaceCounts = useMemo(
    () => ({
      hiredCharacters: workspacePreferences.hiredCharacterIds.length,
      totalCharacters: getTotalCharacterCount(),
      enabledAccessories: workspacePreferences.enabledAccessoryIds.length,
      totalAccessories: getTotalAccessoryCount(),
      reports: reportEntries.length,
      unlockedAchievements,
      totalAchievements: getTotalAchievementCount(),
      level: progress.level,
      levelTitle: progress.levelTitle,
      totalXP: progress.totalXP,
      progressPercent: progress.completionRate
    }),
    [pluginRuntimeVersion, progress, reportEntries.length, unlockedAchievements, workspacePreferences.enabledAccessoryIds.length, workspacePreferences.hiredCharacterIds.length]
  );

  return (
    <div className="window-frame">
      <header className="title-bar">
        <div className="title-bar-left">
          <div className="traffic-gap" />
          <button className="chrome-icon-button" onClick={() => setSidebarCollapsed((current) => !current)}>
            <GlyphIcon symbol={sidebarCollapsed ? "▾" : "☰"} />
          </button>
          <div className="app-brand">
            <strong>{workspacePreferences.workspaceName.trim() || "Doffice"}</strong>
            <span>{t("custom.title.subtitle")}</span>
          </div>
          <div className="view-mode-strip">
            {(["split", "office", "strip", "terminal"] as AppViewMode[]).map((mode) => (
              <button
                key={mode}
                className={`view-mode-button ${appViewMode === mode ? "is-active" : ""}`}
                onClick={() => setAppViewMode(mode)}
              >
                <span className="view-mode-icon">{viewModeIcon(mode)}</span>
                <span>{viewModeLabel(mode)}</span>
              </button>
            ))}
          </div>
          <div className="title-icon-strip">
            <button className="chrome-icon-button" title={t("custom.settings")} onClick={() => setWorkspacePanel("settings")}>
              <GlyphIcon symbol="⚙" />
            </button>
            <button className="chrome-icon-button" title={t("custom.characters")} onClick={() => setWorkspacePanel("characters")}>
              <GlyphIcon symbol="👥" />
            </button>
            <button className="chrome-icon-button" title={t("custom.accessories")} onClick={() => setWorkspacePanel("accessories")}>
              <GlyphIcon symbol="🛋" />
            </button>
            <button
              className="chrome-icon-button"
              title={t("custom.lock")}
              onClick={() =>
                updateWorkspacePreferences({
                  isLocked: workspacePreferences.lockPin ? true : !workspacePreferences.isLocked
                })
              }
            >
              <GlyphIcon symbol={workspacePreferences.isLocked ? "🔒" : "🔓"} tone={workspacePreferences.isLocked ? "danger" : "default"} />
            </button>
            <button className="chrome-icon-button" title={t("view.split")} onClick={() => setAppViewMode("split")}>
              <GlyphIcon symbol="▤" />
            </button>
          </div>
        </div>
        <div className="title-bar-right">
          {claudeStatus.isInstalled || codexStatus.isInstalled || geminiStatus.isInstalled ? (
            <span className="title-meta">
              {[claudeStatus.isInstalled ? `Claude ${claudeStatus.version}` : null, codexStatus.isInstalled ? `Codex ${codexStatus.version}` : null, geminiStatus.isInstalled ? `Gemini ${geminiStatus.version}` : null]
                .filter(Boolean)
                .join(" · ")}
            </span>
          ) : null}
          {totals.tokens > 0 ? (
            <span className="token-pill">
              <span className="token-pip">●</span>
              {formatTokens(totals.tokens)}
            </span>
          ) : null}
          {statusPill(`Lv.${progress.level}`, "neutral")}
          <div className="title-actions">
            <button className="chrome-icon-button" onClick={() => setShowBugReport(true)}>
              <GlyphIcon symbol="🐞" tone="danger" />
            </button>
            <button className="chrome-icon-button" onClick={() => setShowCommandPalette(true)}>
              <GlyphIcon symbol="⌘" />
            </button>
            <button className="chrome-icon-button" onClick={() => setShowActionCenter(true)}>
              <GlyphIcon symbol="☑" />
            </button>
            <button className="chrome-icon-button" onClick={openNewSession}>
              <GlyphIcon symbol="＋" tone="accent" />
            </button>
            <button className="chrome-icon-button" onClick={refreshSnapshot}>
              <GlyphIcon symbol="↻" />
            </button>
            <button className="chrome-icon-button" onClick={stopSelectedSession} disabled={!selectedSession || busy}>
              <GlyphIcon symbol="✕" tone="danger" />
            </button>
          </div>
          <span className="session-pill">{sessions.length}</span>
        </div>
      </header>

      <div className="main-area">
        {!sidebarCollapsed ? (
          <>
            <SidebarView
              groupedSessions={groupedSessions}
              selectedSession={selectedSession}
              searchQuery={searchQuery}
              setSearchQuery={setSearchQuery}
              statusFilter={statusFilter}
              setStatusFilter={setStatusFilter}
              sortOption={sortOption}
              setSortOption={setSortOption}
              filterCounts={filterCounts}
              totals={totals}
              workspaceCounts={workspaceCounts}
              tokenLeaders={tokenLeaders}
              favoriteProjects={favoriteProjects}
              recentProjects={recentProjects}
              selectSession={selectSession}
              openNewSession={openNewSession}
              quickLaunchProject={chooseSuggestedProject}
              openSettings={() => setWorkspacePanel("settings")}
              openCharacters={() => setWorkspacePanel("characters")}
              openAccessories={() => setWorkspacePanel("accessories")}
              openReports={() => setWorkspacePanel("reports")}
              openAchievements={() => setWorkspacePanel("achievements")}
            />
            <div className="sidebar-divider" />
          </>
        ) : null}

        <main className="content-area">
          {appViewMode === "split" ? (
            <div className="split-view">
              {showOfficeSplitPane ? (
                <>
                  <div className={`office-panel-shell ${officeExpanded ? "" : "is-collapsed"}`.trim()} style={{ height: officeHeight }}>
                    <OfficeSceneView
                      selectedSession={selectedSession}
                      groupedSessions={groupedSessions}
                      selectSession={selectSession}
                      variant="compact"
                      enabledAccessoryIds={workspacePreferences.enabledAccessoryIds}
                      backgroundTheme={workspacePreferences.backgroundTheme}
                      officeLayout={workspacePreferences.officeLayout}
                      officeCamera={workspacePreferences.officeCamera}
                    />
                    <div className="office-control-row">
                      <button
                        className="chrome-icon-button compact"
                        title={workspacePreferences.officeCamera === "focus" ? t("main.office.grid.toggle") : t("main.office.focus.toggle")}
                        onClick={() =>
                          updateWorkspacePreferences({
                            officeCamera: workspacePreferences.officeCamera === "focus" ? "overview" : "focus"
                          })
                        }
                      >
                        <PixelIcon name="focus" compact />
                      </button>
                      <button className="chrome-icon-button compact" onClick={() => setOfficeExpanded((current) => !current)}>
                        <PixelIcon name={officeExpanded ? "collapse" : "expand"} compact />
                      </button>
                    </div>
                  </div>
                  <div className="content-divider" />
                </>
              ) : null}
              <TerminalAreaView
                sessions={sessions}
                selectedSession={selectedSession}
                workspacePreferences={workspacePreferences}
                terminalViewMode={terminalViewMode}
                setTerminalViewMode={setTerminalViewMode}
                pinnedSessionIds={pinnedSessionIds}
                togglePinnedSession={togglePinnedSession}
                prompt={prompt}
                setPrompt={setPrompt}
                busy={busy}
                sendPrompt={sendPrompt}
                sendPromptToSession={sendPromptToSession}
                approvePendingApproval={approvePendingApproval}
                denyPendingApproval={denyPendingApproval}
                dismissDangerousWarning={dismissDangerousWarning}
                dismissSensitiveWarning={dismissSensitiveWarning}
                selectSession={selectSession}
                removeSession={removeSession}
                openNewSession={openNewSession}
              />
            </div>
          ) : null}

          {appViewMode === "office" ? (
            <OfficeSceneView
              selectedSession={selectedSession}
              groupedSessions={groupedSessions}
              selectSession={selectSession}
              variant="full"
              enabledAccessoryIds={workspacePreferences.enabledAccessoryIds}
              backgroundTheme={workspacePreferences.backgroundTheme}
              officeLayout={workspacePreferences.officeLayout}
              officeCamera={workspacePreferences.officeCamera}
            />
          ) : null}

          {appViewMode === "strip" ? (
            <div className="split-view">
              <PixelStripView groupedSessions={groupedSessions} backgroundTheme={workspacePreferences.backgroundTheme} />
              <div className="content-divider" />
              <TerminalAreaView
                sessions={sessions}
                selectedSession={selectedSession}
                workspacePreferences={workspacePreferences}
                terminalViewMode={terminalViewMode}
                setTerminalViewMode={setTerminalViewMode}
                pinnedSessionIds={pinnedSessionIds}
                togglePinnedSession={togglePinnedSession}
                prompt={prompt}
                setPrompt={setPrompt}
                busy={busy}
                sendPrompt={sendPrompt}
                sendPromptToSession={sendPromptToSession}
                approvePendingApproval={approvePendingApproval}
                denyPendingApproval={denyPendingApproval}
                dismissDangerousWarning={dismissDangerousWarning}
                dismissSensitiveWarning={dismissSensitiveWarning}
                selectSession={selectSession}
                removeSession={removeSession}
                openNewSession={openNewSession}
              />
            </div>
          ) : null}

          {appViewMode === "terminal" ? (
            <TerminalAreaView
              sessions={sessions}
              selectedSession={selectedSession}
              workspacePreferences={workspacePreferences}
              terminalViewMode={terminalViewMode}
              setTerminalViewMode={setTerminalViewMode}
              pinnedSessionIds={pinnedSessionIds}
              togglePinnedSession={togglePinnedSession}
              prompt={prompt}
              setPrompt={setPrompt}
              busy={busy}
              sendPrompt={sendPrompt}
              sendPromptToSession={sendPromptToSession}
              approvePendingApproval={approvePendingApproval}
              denyPendingApproval={denyPendingApproval}
              dismissDangerousWarning={dismissDangerousWarning}
              dismissSensitiveWarning={dismissSensitiveWarning}
              selectSession={selectSession}
              removeSession={removeSession}
              openNewSession={openNewSession}
            />
          ) : null}
        </main>
      </div>

      <footer className="status-bar">
        <div className="status-bar-left">
          {sessions.length === 0 ? <span className="status-empty">{t("custom.no.active.sessions")}</span> : null}
          {totals.active > 0 ? statusPill(`${t("custom.active")} ${totals.active}`, "green") : null}
          {totals.processing > 0 ? (
            <button className="status-pill-button" onClick={() => setShowActionCenter(true)}>
              {statusPill(tf("custom.processing.count", undefined, totals.processing), "accent")}
            </button>
          ) : null}
          {totals.attention > 0 ? (
            <button className="status-pill-button" onClick={() => setShowActionCenter(true)}>
              {statusPill(tf("custom.attention.count", undefined, totals.attention), "red")}
            </button>
          ) : null}
          {totals.completed > 0 ? (
            <button className="status-pill-button" onClick={() => setShowActionCenter(true)}>
              {statusPill(tf("custom.completed.count", undefined, totals.completed), "green")}
            </button>
          ) : null}
        </div>
        <div className="status-bar-right">{t("custom.shortcuts")}</div>
      </footer>

      <CommandPaletteView
        isOpen={showCommandPalette}
        sessions={sessions}
        onClose={() => setShowCommandPalette(false)}
        onOpenNewSession={openNewSession}
        onRefresh={refreshSnapshot}
        onSetViewMode={setAppViewMode}
        onSelectSession={selectSession}
      />

      <SessionNotificationBannerStack
        notifications={notifications}
        onDismiss={dismissNotification}
        onSelectSession={selectSession}
      />

      {showActionCenter ? (
        <ActionCenterView
          sessions={sessions}
          onClose={() => setShowActionCenter(false)}
          onSelectSession={selectSession}
        />
      ) : null}

      <WorkspaceOverlayManager
        kind={workspacePanel}
        onClose={() => setWorkspacePanel(null)}
        selectedSession={selectedSession}
        sessions={sessions}
        claudeStatus={claudeStatus}
        codexStatus={codexStatus}
        geminiStatus={geminiStatus}
        refreshCLIStatuses={refreshCLIStatuses}
        installCLI={installCLI}
        totals={totals}
        preferences={workspacePreferences}
        updatePreferences={updateWorkspacePreferences}
        reportEntries={reportEntries}
        reportLoading={reportLoading}
        refreshReports={refreshReports}
        achievements={achievements}
        progress={progress}
      />

      {workspacePreferences.isLocked ? (
        <SessionLockOverlay
          lockPin={workspacePreferences.lockPin}
          onUnlock={() => updateWorkspacePreferences({ isLocked: false })}
        />
      ) : null}

      {showBugReport ? <BugReportModal onClose={() => setShowBugReport(false)} /> : null}

      <OnboardingOverlay
        isOpen={showOnboarding}
        onSkip={dismissOnboarding}
        onFinish={completeOnboarding}
      />

      <NewSessionSheet
        isOpen={showCreateDialog}
        busy={busy}
        draft={newSessionDraft}
        favoriteProjects={favoriteProjects}
        recentProjects={recentProjects}
        isFavorite={isCurrentDraftFavorite}
        onClose={() => setShowCreateDialog(false)}
        onPickDirectory={handlePickDirectory}
        onAddPluginDirectory={handleAddPluginDirectory}
        onSubmit={handleCreateSession}
        onUpdateDraft={updateNewSessionDraft}
        onChooseProject={chooseSuggestedProject}
        onToggleFavorite={toggleDraftFavorite}
        onApplyPreset={applyNewSessionPreset}
      />
    </div>
  );
}

function BugReportModal(props: { onClose: () => void }) {
  const { onClose } = props;
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [attachment, setAttachment] = useState<ImageAttachment | null>(null);
  const [sending, setSending] = useState(false);

  async function handleCapture() {
    const nextAttachment = await window.doffice.captureCurrentView();
    if (nextAttachment) setAttachment(nextAttachment);
  }

  async function handlePick() {
    const nextAttachment = await window.doffice.pickImageFile();
    if (nextAttachment) setAttachment(nextAttachment);
  }

  async function handleSend() {
    if (!title.trim()) return;
    setSending(true);
    const body = [
      `[문제 요약] ${title.trim()}`,
      "",
      "[상세 설명]",
      description.trim() || "(내용 없음)",
      "",
      `[첨부] ${attachment?.path || "현재 화면 캡처"}`
    ].join("\n");
    const target = `mailto:goodjunha@gmail.com?subject=${encodeURIComponent(`[Doffice Windows] ${title.trim()}`)}&body=${encodeURIComponent(body)}`;
    await window.doffice.openExternal(target);
    setSending(false);
    onClose();
  }

  return (
    <div className="overlay-backdrop workspace-modal-backdrop" onClick={onClose}>
      <div className="workspace-modal bug-report-modal" onClick={(event) => event.stopPropagation()}>
        <div className="workspace-modal-header">
          <div>
            <strong><span className="panel-title-emoji tone-red">🐞</span>버그 신고</strong>
            <span>문제를 빠르게 파악할 수 있도록 핵심 정보만 정리해 보내세요.</span>
          </div>
          <button type="button" className="workspace-close-button" onClick={onClose}>
            ×
          </button>
        </div>
        <div className="workspace-modal-body">
          <section className="settings-card">
            <strong>문제 요약</strong>
            <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="어떤 문제가 발생했나요?" />
          </section>
          <section className="settings-card">
            <strong>상세 설명</strong>
            <textarea rows={8} value={description} onChange={(event) => setDescription(event.target.value)} placeholder="재현 순서나 기대 동작을 적어주세요." />
          </section>
          <section className="settings-card">
            <strong>스크린샷</strong>
            <div className="settings-action-row">
              <button type="button" className="mini-action-button success" onClick={() => void handleCapture()}>
                현재 화면 캡쳐
              </button>
              <button type="button" className="mini-action-button" onClick={() => void handlePick()}>
                파일 선택
              </button>
            </div>
            {attachment ? (
              <div className="bug-attachment-preview">
                <img src={attachment.dataUrl} alt="bug attachment preview" />
              </div>
            ) : null}
          </section>
        </div>
        <div className="sheet-actions">
          <button type="button" className="secondary-button" onClick={onClose}>
            취소
          </button>
          <button type="button" className="primary-button" disabled={!title.trim() || sending} onClick={() => void handleSend()}>
            보내기
          </button>
        </div>
      </div>
    </div>
  );
}
