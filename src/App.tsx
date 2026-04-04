import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { MainView } from "./MainView";
import type { BootstrapPayload, CLIStatus, SessionSnapshot, SlashCommandPayload } from "./types";
import type { AppViewMode, ProjectGroup, SessionStatusFilter, SidebarSortOption, TerminalViewMode } from "./uiModel";
import type { SessionNotificationItem } from "./OverlayViews";
import type { NewSessionDraftState, NewSessionProjectRecord, NewSessionPresetId } from "./newSessionPreferences";
import {
  applyDraftPreset,
  loadFavoriteProjects,
  loadNewSessionDraft,
  loadRecentProjects,
  mergeSuggestedProjects,
  rememberProjectLaunch,
  saveFavoriteProjects,
  saveNewSessionDraft,
  saveRecentProjects,
  toggleFavoriteProject
} from "./newSessionPreferences";
import { compareGroups, compareSessions, groupSessions, inferStatus, sessionActivitySummary } from "./sessionUtils";

const emptyCLIStatus: CLIStatus = {
  isInstalled: false,
  version: "",
  path: "",
  errorInfo: "Loading CLI status..."
};

const uiStateKey = "doffice.ui-state";

interface PersistedUiState {
  selectedId: string;
  sidebarCollapsed: boolean;
  appViewMode: AppViewMode;
  terminalViewMode: TerminalViewMode;
  officeExpanded: boolean;
  statusFilter: SessionStatusFilter;
  sortOption: SidebarSortOption;
  pinnedSessionIds: string[];
}

const defaultUiState: PersistedUiState = {
  selectedId: "",
  sidebarCollapsed: false,
  appViewMode: "office",
  terminalViewMode: "single",
  officeExpanded: true,
  statusFilter: "all",
  sortOption: "recent",
  pinnedSessionIds: []
};

function loadUiState(): PersistedUiState {
  try {
    const raw = window.localStorage.getItem(uiStateKey);
    if (!raw) return defaultUiState;
    const parsed = JSON.parse(raw) as Partial<PersistedUiState>;
    return {
      selectedId: typeof parsed.selectedId === "string" ? parsed.selectedId : defaultUiState.selectedId,
      sidebarCollapsed: typeof parsed.sidebarCollapsed === "boolean" ? parsed.sidebarCollapsed : defaultUiState.sidebarCollapsed,
      appViewMode:
        parsed.appViewMode === "split" ||
        parsed.appViewMode === "office" ||
        parsed.appViewMode === "terminal" ||
        parsed.appViewMode === "strip"
          ? parsed.appViewMode
          : defaultUiState.appViewMode,
      terminalViewMode:
        parsed.terminalViewMode === "grid" ||
        parsed.terminalViewMode === "single" ||
        parsed.terminalViewMode === "git" ||
        parsed.terminalViewMode === "browser"
          ? parsed.terminalViewMode
          : defaultUiState.terminalViewMode,
      officeExpanded: typeof parsed.officeExpanded === "boolean" ? parsed.officeExpanded : defaultUiState.officeExpanded,
      statusFilter:
        parsed.statusFilter === "all" ||
        parsed.statusFilter === "active" ||
        parsed.statusFilter === "processing" ||
        parsed.statusFilter === "completed" ||
        parsed.statusFilter === "attention"
          ? parsed.statusFilter
          : defaultUiState.statusFilter,
      sortOption:
        parsed.sortOption === "recent" ||
        parsed.sortOption === "name" ||
        parsed.sortOption === "tokens" ||
        parsed.sortOption === "status"
          ? parsed.sortOption
          : defaultUiState.sortOption,
      pinnedSessionIds: Array.isArray(parsed.pinnedSessionIds)
        ? parsed.pinnedSessionIds.filter((value): value is string => typeof value === "string")
        : defaultUiState.pinnedSessionIds
    };
  } catch {
    return defaultUiState;
  }
}

function App() {
  const [persistedUiState] = useState(loadUiState);
  const [sessions, setSessions] = useState<SessionSnapshot[]>([]);
  const [selectedId, setSelectedId] = useState(persistedUiState.selectedId);
  const [claudeStatus, setClaudeStatus] = useState<CLIStatus>(emptyCLIStatus);
  const [codexStatus, setCodexStatus] = useState<CLIStatus>(emptyCLIStatus);
  const [busy, setBusy] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(persistedUiState.sidebarCollapsed);
  const [appViewMode, setAppViewMode] = useState<AppViewMode>(persistedUiState.appViewMode);
  const [terminalViewMode, setTerminalViewMode] = useState<TerminalViewMode>(persistedUiState.terminalViewMode);
  const [officeExpanded, setOfficeExpanded] = useState(persistedUiState.officeExpanded);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<SessionStatusFilter>(persistedUiState.statusFilter);
  const [sortOption, setSortOption] = useState<SidebarSortOption>(persistedUiState.sortOption);
  const [pinnedSessionIds, setPinnedSessionIds] = useState<string[]>(persistedUiState.pinnedSessionIds);
  const [prompt, setPrompt] = useState("");
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showActionCenter, setShowActionCenter] = useState(false);
  const [showCommandPalette, setShowCommandPalette] = useState(false);
  const [newSessionDraft, setNewSessionDraft] = useState<NewSessionDraftState>(loadNewSessionDraft);
  const [favoriteProjects, setFavoriteProjects] = useState<NewSessionProjectRecord[]>(loadFavoriteProjects);
  const [recentProjects, setRecentProjects] = useState<NewSessionProjectRecord[]>(loadRecentProjects);
  const [notifications, setNotifications] = useState<SessionNotificationItem[]>([]);
  const hasSeededSessionStateRef = useRef(false);
  const sessionStateRef = useRef<Map<string, { status: string; completedPromptCount: number }>>(new Map());
  const notificationTimersRef = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    let unsubscribe = () => {};

    void window.doffice.bootstrap().then((payload: BootstrapPayload) => {
      setSessions(payload.sessions);
      setClaudeStatus(payload.claudeStatus);
      setCodexStatus(payload.codexStatus);
      setSelectedId((current) => current || payload.sessions[0]?.id || "");
    });

    unsubscribe = window.doffice.onSessionsUpdated((payload) => {
      setSessions(payload);
      setSelectedId((current) => {
        if (current && payload.some((session) => session.id === current)) {
          return current;
        }
        return payload[0]?.id || "";
      });
    });

    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const validSessionIds = new Set(sessions.map((session) => session.id));
    setPinnedSessionIds((current) => {
      const next = current.filter((sessionId) => validSessionIds.has(sessionId));
      return next.length === current.length ? current : next;
    });
    setSelectedId((current) => (current && validSessionIds.has(current) ? current : sessions[0]?.id || ""));
  }, [sessions]);

  useEffect(() => {
    return () => {
      notificationTimersRef.current.forEach((timer) => window.clearTimeout(timer));
      notificationTimersRef.current.clear();
    };
  }, []);

  useEffect(() => {
    saveNewSessionDraft(newSessionDraft);
  }, [newSessionDraft]);

  useEffect(() => {
    saveFavoriteProjects(favoriteProjects);
  }, [favoriteProjects]);

  useEffect(() => {
    saveRecentProjects(recentProjects);
  }, [recentProjects]);

  useEffect(() => {
    const nextState = new Map<string, { status: string; completedPromptCount: number }>();
    for (const session of sessions) {
      nextState.set(session.id, {
        status: inferStatus(session).category,
        completedPromptCount: session.completedPromptCount
      });
    }

    if (!hasSeededSessionStateRef.current) {
      sessionStateRef.current = nextState;
      hasSeededSessionStateRef.current = true;
      return;
    }

    const previousState = sessionStateRef.current;
    const generated: SessionNotificationItem[] = [];

    for (const session of sessions) {
      const previous = previousState.get(session.id);
      const currentStatus = inferStatus(session).category;
      if (!previous) continue;

      if (currentStatus === "completed" && previous.completedPromptCount < session.completedPromptCount) {
        generated.push({
          id: `${session.id}-completed-${session.completedPromptCount}`,
          sessionId: session.id,
          title: `${session.workerName || session.projectName} completed`,
          detail: sessionActivitySummary(session),
          tint: "#3ecf8e",
          glyph: "●"
        });
        continue;
      }

      if (currentStatus === "attention" && previous.status !== "attention") {
        generated.push({
          id: `${session.id}-attention-${session.lastActivityTime}`,
          sessionId: session.id,
          title: `${session.workerName || session.projectName} needs attention`,
          detail: sessionActivitySummary(session),
          tint: "#f14c4c",
          glyph: "▲"
        });
      }
    }

    for (const notification of generated) {
      setNotifications((current) => {
        if (current.some((item) => item.id === notification.id)) return current;
        return [...current.slice(-2), notification];
      });
      const timer = window.setTimeout(() => {
        setNotifications((current) => current.filter((item) => item.id !== notification.id));
        notificationTimersRef.current.delete(notification.id);
      }, 6500);
      notificationTimersRef.current.set(notification.id, timer);
    }

    sessionStateRef.current = nextState;
  }, [sessions]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const mod = event.ctrlKey || event.metaKey;
      if (event.key === "Escape") {
        setShowCommandPalette(false);
        setShowActionCenter(false);
        return;
      }
      if (!mod) return;

      const lower = event.key.toLowerCase();
      if (lower === "p") {
        event.preventDefault();
        setShowCommandPalette(true);
        return;
      }
      if (lower === "j") {
        event.preventDefault();
        setShowActionCenter(true);
        return;
      }
      if (lower === "t") {
        event.preventDefault();
        setShowCreateDialog(true);
        return;
      }
      if (lower === "r") {
        event.preventDefault();
        void refreshSnapshot();
        return;
      }
      if (/^[1-9]$/.test(lower)) {
        const index = Number(lower) - 1;
        const session = sessions[index];
        if (!session) return;
        event.preventDefault();
        setSelectedId(session.id);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [sessions]);

  useEffect(() => {
    const persisted: PersistedUiState = {
      selectedId,
      sidebarCollapsed,
      appViewMode,
      terminalViewMode,
      officeExpanded,
      statusFilter,
      sortOption,
      pinnedSessionIds
    };
    window.localStorage.setItem(uiStateKey, JSON.stringify(persisted));
  }, [selectedId, sidebarCollapsed, appViewMode, terminalViewMode, officeExpanded, statusFilter, sortOption, pinnedSessionIds]);

  const selectedSession = useMemo(
    () => sessions.find((session) => session.id === selectedId) ?? null,
    [selectedId, sessions]
  );

  const filteredSessions = useMemo(() => {
    const loweredQuery = searchQuery.trim().toLowerCase();
    return [...sessions]
      .filter((session) => {
        const haystack = [session.projectName, session.projectPath, session.workerName, session.branch, session.lastResultText]
          .join(" ")
          .toLowerCase();
        return !loweredQuery || haystack.includes(loweredQuery);
      })
      .filter((session) => {
        const category = inferStatus(session).category;
        if (statusFilter === "all") return true;
        if (statusFilter === "active") return category === "active" || category === "processing";
        return category === statusFilter;
      })
      .sort((lhs, rhs) => compareSessions(lhs, rhs, sortOption));
  }, [searchQuery, sessions, sortOption, statusFilter]);

  const groupedSessions = useMemo<ProjectGroup[]>(
    () => groupSessions(filteredSessions, selectedId).sort((lhs, rhs) => compareGroups(lhs, rhs, sortOption)),
    [filteredSessions, selectedId, sortOption]
  );

  const totals = useMemo(() => {
    const active = sessions.filter((session) => inferStatus(session).category === "active").length;
    const processing = sessions.filter((session) => inferStatus(session).category === "processing").length;
    const attention = sessions.filter((session) => inferStatus(session).category === "attention").length;
    const completed = sessions.filter((session) => inferStatus(session).category === "completed").length;
    const tokens = sessions.reduce((sum, session) => sum + session.tokensUsed, 0);
    return { active, processing, attention, completed, tokens };
  }, [sessions]);

  const sidebarFilterCounts = useMemo(
    () => ({
      all: sessions.length,
      active: sessions.filter((session) => {
        const category = inferStatus(session).category;
        return category === "active" || category === "processing";
      }).length,
      processing: sessions.filter((session) => inferStatus(session).category === "processing").length,
      completed: sessions.filter((session) => inferStatus(session).category === "completed").length,
      attention: sessions.filter((session) => inferStatus(session).category === "attention").length
    }),
    [sessions]
  );

  const tokenLeaders = useMemo(
    () => [...sessions].filter((session) => session.tokensUsed > 0).sort((lhs, rhs) => rhs.tokensUsed - lhs.tokensUsed).slice(0, 6),
    [sessions]
  );

  const suggestedProjects = useMemo(
    () => mergeSuggestedProjects(sessions, favoriteProjects, recentProjects),
    [favoriteProjects, recentProjects, sessions]
  );

  const sidebarHistoryProjects = useMemo(
    () =>
      suggestedProjects
        .filter((project) => !sessions.some((session) => session.projectPath === project.path))
        .slice(0, 5),
    [sessions, suggestedProjects]
  );

  const sidebarFavoriteProjects = useMemo(() => suggestedProjects.filter((project) => project.isFavorite).slice(0, 4), [suggestedProjects]);

  const isCurrentDraftFavorite = useMemo(
    () => favoriteProjects.some((project) => project.path === newSessionDraft.projectPath),
    [favoriteProjects, newSessionDraft.projectPath]
  );

  async function refreshSnapshot() {
    const payload = await window.doffice.bootstrap();
    setSessions(payload.sessions);
    setClaudeStatus(payload.claudeStatus);
    setCodexStatus(payload.codexStatus);
  }

  async function openNewSession() {
    setShowCreateDialog(true);
  }

  function updateNewSessionDraft(patch: Partial<NewSessionDraftState>) {
    setNewSessionDraft((current) => ({ ...current, ...patch }));
  }

  function chooseSuggestedProject(project: NewSessionProjectRecord) {
    setNewSessionDraft((current) => ({
      ...current,
      projectPath: project.path,
      projectName: project.name || current.projectName
    }));
    setShowCreateDialog(true);
  }

  function toggleDraftFavorite() {
    if (!newSessionDraft.projectPath.trim()) return;
    setFavoriteProjects((current) =>
      toggleFavoriteProject(current, newSessionDraft.projectPath.trim(), newSessionDraft.projectName.trim())
    );
  }

  function applyNewSessionPreset(preset: NewSessionPresetId) {
    setNewSessionDraft((current) => applyDraftPreset(current, preset));
  }

  async function handlePickDirectory() {
    const picked = await window.doffice.pickDirectory();
    if (!picked) return;
    setNewSessionDraft((current) => {
      const normalized = picked.replace(/[\\/]+$/, "");
      const pieces = normalized.split(/[\\/]/);
      return {
        ...current,
        projectPath: picked,
        projectName: current.projectName.trim() ? current.projectName : pieces[pieces.length - 1] || current.projectName
      };
    });
  }

  async function handleAddPluginDirectory() {
    const picked = await window.doffice.pickDirectory();
    if (!picked) return;
    setNewSessionDraft((current) => ({
      ...current,
      pluginDirs: current.pluginDirs.includes(picked) ? current.pluginDirs : [...current.pluginDirs, picked]
    }));
  }

  async function handleCreateSession(event: FormEvent) {
    event.preventDefault();
    if (!newSessionDraft.projectPath.trim()) return;
    setBusy(true);
    try {
      const parsedBudget = Number(newSessionDraft.maxBudget);
      const created = await window.doffice.createSession({
        projectPath: newSessionDraft.projectPath.trim(),
        projectName: newSessionDraft.projectName.trim() || undefined,
        initialPrompt: newSessionDraft.initialPrompt.trim() || undefined,
        provider: newSessionDraft.provider,
        selectedModel: newSessionDraft.selectedModel,
        effortLevel: newSessionDraft.effortLevel,
        outputMode: newSessionDraft.outputMode,
        permissionMode: newSessionDraft.permissionMode,
        codexSandboxMode: newSessionDraft.codexSandboxMode,
        codexApprovalPolicy: newSessionDraft.codexApprovalPolicy,
        pluginDirs: newSessionDraft.pluginDirs,
        systemPrompt: newSessionDraft.systemPrompt.trim() || undefined,
        maxBudgetUSD: Number.isFinite(parsedBudget) && parsedBudget > 0 ? parsedBudget : undefined,
        allowedTools: newSessionDraft.allowedTools.trim() || undefined,
        disallowedTools: newSessionDraft.disallowedTools.trim() || undefined,
        additionalDirs: newSessionDraft.additionalDirs,
        continueSession: newSessionDraft.continueSession,
        useWorktree: newSessionDraft.useWorktree,
        fallbackModel: newSessionDraft.fallbackModel.trim() || undefined,
        sessionName: newSessionDraft.sessionName.trim() || undefined,
        enableChrome: newSessionDraft.enableChrome,
        forkSession: newSessionDraft.forkSession,
        enableBrief: newSessionDraft.enableBrief
      });
      const isFavorite = favoriteProjects.some((project) => project.path === newSessionDraft.projectPath.trim());
      setRecentProjects((current) =>
        rememberProjectLaunch(
          current,
          newSessionDraft.projectPath.trim(),
          newSessionDraft.projectName.trim() || created.projectName,
          isFavorite
        )
      );
      setSelectedId(created.id);
      setShowCreateDialog(false);
    } finally {
      setBusy(false);
    }
  }

  async function sendPrompt(event: FormEvent) {
    event.preventDefault();
    if (!selectedSession || !prompt.trim()) return;
    await sendPromptToSession(selectedSession.id, prompt.trim());
    setPrompt("");
  }

  async function sendPromptToSession(sessionId: string, nextPrompt: string) {
    if (!nextPrompt.trim()) return;
    setBusy(true);
    try {
      const trimmedPrompt = nextPrompt.trim();
      if (trimmedPrompt.startsWith("/")) {
        const payload: SlashCommandPayload = { sessionId, command: trimmedPrompt };
        await window.doffice.runSlashCommand(payload);
      } else {
        await window.doffice.sendPrompt({ sessionId, prompt: trimmedPrompt });
      }
    } finally {
      setBusy(false);
    }
  }

  async function stopSelectedSession() {
    if (!selectedSession) return;
    setBusy(true);
    try {
      await window.doffice.stopSession(selectedSession.id);
    } finally {
      setBusy(false);
    }
  }

  async function approvePendingApproval() {
    if (!selectedSession?.pendingApproval) return;
    setBusy(true);
    try {
      await window.doffice.approvePendingApproval(selectedSession.id);
    } finally {
      setBusy(false);
    }
  }

  async function denyPendingApproval() {
    if (!selectedSession?.pendingApproval) return;
    setBusy(true);
    try {
      await window.doffice.denyPendingApproval(selectedSession.id);
    } finally {
      setBusy(false);
    }
  }

  async function dismissDangerousWarning() {
    if (!selectedSession?.dangerousCommandWarning) return;
    await window.doffice.dismissDangerousWarning(selectedSession.id);
  }

  async function dismissSensitiveWarning() {
    if (!selectedSession?.sensitiveFileWarning) return;
    await window.doffice.dismissSensitiveWarning(selectedSession.id);
  }

  async function removeSession(sessionId: string) {
    setBusy(true);
    try {
      await window.doffice.removeSession(sessionId);
      setPinnedSessionIds((current) => current.filter((value) => value !== sessionId));
    } finally {
      setBusy(false);
    }
  }

  function togglePinnedSession(sessionId: string) {
    setPinnedSessionIds((current) =>
      current.includes(sessionId) ? current.filter((value) => value !== sessionId) : [...current, sessionId]
    );
  }

  function dismissNotification(notificationId: string) {
    const timer = notificationTimersRef.current.get(notificationId);
    if (timer) {
      window.clearTimeout(timer);
      notificationTimersRef.current.delete(notificationId);
    }
    setNotifications((current) => current.filter((item) => item.id !== notificationId));
  }

  return (
    <MainView
      sessions={sessions}
      selectedSession={selectedSession}
      claudeStatus={claudeStatus}
      codexStatus={codexStatus}
      sidebarCollapsed={sidebarCollapsed}
      setSidebarCollapsed={setSidebarCollapsed}
      appViewMode={appViewMode}
      setAppViewMode={setAppViewMode}
      terminalViewMode={terminalViewMode}
      setTerminalViewMode={setTerminalViewMode}
      officeExpanded={officeExpanded}
      setOfficeExpanded={setOfficeExpanded}
      searchQuery={searchQuery}
      setSearchQuery={setSearchQuery}
      statusFilter={statusFilter}
      setStatusFilter={setStatusFilter}
      sortOption={sortOption}
      setSortOption={setSortOption}
      filterCounts={sidebarFilterCounts}
      pinnedSessionIds={pinnedSessionIds}
      togglePinnedSession={togglePinnedSession}
      groupedSessions={groupedSessions}
      totals={totals}
      tokenLeaders={tokenLeaders}
      prompt={prompt}
      setPrompt={setPrompt}
      busy={busy}
      openNewSession={openNewSession}
      refreshSnapshot={refreshSnapshot}
      stopSelectedSession={stopSelectedSession}
      approvePendingApproval={approvePendingApproval}
      denyPendingApproval={denyPendingApproval}
      dismissDangerousWarning={dismissDangerousWarning}
      dismissSensitiveWarning={dismissSensitiveWarning}
      sendPrompt={sendPrompt}
      sendPromptToSession={sendPromptToSession}
      selectSession={setSelectedId}
      removeSession={removeSession}
      notifications={notifications}
      dismissNotification={dismissNotification}
      showCreateDialog={showCreateDialog}
      setShowCreateDialog={setShowCreateDialog}
      showActionCenter={showActionCenter}
      setShowActionCenter={setShowActionCenter}
      showCommandPalette={showCommandPalette}
      setShowCommandPalette={setShowCommandPalette}
      newSessionDraft={newSessionDraft}
      updateNewSessionDraft={updateNewSessionDraft}
      favoriteProjects={sidebarFavoriteProjects}
      recentProjects={sidebarHistoryProjects}
      isCurrentDraftFavorite={isCurrentDraftFavorite}
      chooseSuggestedProject={chooseSuggestedProject}
      toggleDraftFavorite={toggleDraftFavorite}
      applyNewSessionPreset={applyNewSessionPreset}
      handlePickDirectory={handlePickDirectory}
      handleAddPluginDirectory={handleAddPluginDirectory}
      handleCreateSession={handleCreateSession}
    />
  );
}

export default App;
