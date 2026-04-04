import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { MainView } from "./MainView";
import type { AgentProvider, BootstrapPayload, CLIInstallResult, CLIStatus, CLIStatusPayload, SessionSnapshot, SlashCommandPayload } from "./types";
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
import { enabledInstalledPluginDirs, loadInstalledPlugins } from "./pluginInstallState";
import { emptyPluginRuntimeSnapshot, getPluginRuntimeSnapshot, setPluginRuntimeSnapshot } from "./pluginRuntime";
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

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  if (target.isContentEditable) return true;
  const tagName = target.tagName.toLowerCase();
  return tagName === "input" || tagName === "textarea" || tagName === "select";
}

function App() {
  const [persistedUiState] = useState(loadUiState);
  const [sessions, setSessions] = useState<SessionSnapshot[]>([]);
  const [selectedId, setSelectedId] = useState(persistedUiState.selectedId);
  const [claudeStatus, setClaudeStatus] = useState<CLIStatus>(emptyCLIStatus);
  const [codexStatus, setCodexStatus] = useState<CLIStatus>(emptyCLIStatus);
  const [geminiStatus, setGeminiStatus] = useState<CLIStatus>(emptyCLIStatus);
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
  const [pluginRuntimeVersion, setPluginRuntimeVersion] = useState(0);
  const [pluginFlash, setPluginFlash] = useState<{ id: number; color: string; durationMs: number } | null>(null);
  const [pluginShake, setPluginShake] = useState<{ id: number; intensity: number; durationMs: number } | null>(null);
  const [pluginConfettiBursts, setPluginConfettiBursts] = useState<Array<{ id: number; colors: string[]; count: number; durationMs: number }>>([]);
  const [pluginCombo, setPluginCombo] = useState<{ id: number; count: number; label: string; color: string } | null>(null);
  const [pluginParticleBursts, setPluginParticleBursts] = useState<Array<{ id: number; emojis: string[]; count: number; durationMs: number }>>([]);
  const hasSeededSessionStateRef = useRef(false);
  const sessionStateRef = useRef<Map<string, { status: string; completedPromptCount: number }>>(new Map());
  const notificationTimersRef = useRef<Map<string, number>>(new Map());
  const comboDecayTimerRef = useRef<number | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);

  function applyCLIStatuses(payload: CLIStatusPayload) {
    setClaudeStatus(payload.claudeStatus);
    setCodexStatus(payload.codexStatus);
    setGeminiStatus(payload.geminiStatus);
  }

  function appendNotification(notification: SessionNotificationItem, durationMs = 6500) {
    setNotifications((current) => {
      if (current.some((item) => item.id === notification.id)) return current;
      return [...current.slice(-2), notification];
    });
    const existingTimer = notificationTimersRef.current.get(notification.id);
    if (existingTimer) {
      window.clearTimeout(existingTimer);
    }
    const timer = window.setTimeout(() => {
      setNotifications((current) => current.filter((item) => item.id !== notification.id));
      notificationTimersRef.current.delete(notification.id);
    }, durationMs);
    notificationTimersRef.current.set(notification.id, timer);
  }

  function normalizeEffectColor(value: unknown, fallback: string) {
    if (typeof value !== "string" || !value.trim()) return fallback;
    return `#${String(value).replace(/^#/, "")}`;
  }

  function playPluginSound(config: Record<string, unknown>) {
    const AudioCtor = window.AudioContext || (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AudioCtor) return;
    if (!audioContextRef.current) {
      audioContextRef.current = new AudioCtor();
    }
    const context = audioContextRef.current;
    void context.resume().catch(() => undefined);

    const name = String(config.name || "pop").trim().toLowerCase();
    const volume = Math.min(0.18, Math.max(0.03, Number(config.volume) || 0.07));
    const duration = Math.min(1.2, Math.max(0.05, Number(config.duration) || (name.includes("level") ? 0.32 : 0.14)));
    const primaryFrequency =
      name.includes("error") ? 180 :
      name.includes("level") ? 720 :
      name.includes("click") ? 320 :
      540;
    const secondaryFrequency =
      name.includes("error") ? 130 :
      name.includes("level") ? 980 :
      name.includes("click") ? 260 :
      760;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = name.includes("error") ? "sawtooth" : name.includes("level") ? "triangle" : "sine";
    oscillator.frequency.setValueAtTime(primaryFrequency, context.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(secondaryFrequency, context.currentTime + duration);
    gain.gain.setValueAtTime(0.0001, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(volume, context.currentTime + Math.min(0.03, duration / 3));
    gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + duration);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start();
    oscillator.stop(context.currentTime + duration);
  }

  function triggerPluginEffects(trigger: string, session: SessionSnapshot | null) {
    const runtime = getPluginRuntimeSnapshot();
    const effects = runtime.effects.filter((effect) => effect.enabled && effect.trigger === trigger);
    if (effects.length === 0) return;
    for (const effect of effects) {
      const config = effect.config ?? {};
      if (effect.type === "toast") {
        appendNotification(
          {
            id: `plugin-effect-${effect.id}-${Date.now()}`,
            sessionId: session?.id || "",
            title: typeof config.text === "string" && config.text.trim() ? config.text : `${effect.pluginName} effect`,
            detail: session ? `${session.workerName || session.projectName} · ${session.projectName}` : effect.pluginName,
            tint: typeof config.tint === "string" && config.tint ? `#${String(config.tint).replace(/^#/, "")}` : "#3291ff",
            glyph: typeof config.icon === "string" && config.icon.trim() ? config.icon : "✦"
          },
          Math.max(1800, Number(config.duration) > 0 ? Number(config.duration) * 1000 : 4000)
        );
      }
      if (effect.type === "flash") {
        setPluginFlash({
          id: Date.now(),
          color: normalizeEffectColor(config.colorHex, "#3291ff"),
          durationMs: Math.max(120, Number(config.duration) > 0 ? Number(config.duration) * 1000 : 220)
        });
      }
      if (effect.type === "screen-shake") {
        setPluginShake({
          id: Date.now(),
          intensity: Math.max(2, Number(config.intensity) || 6),
          durationMs: Math.max(180, Number(config.duration) > 0 ? Number(config.duration) * 1000 : 420)
        });
      }
      if (effect.type === "confetti") {
        const id = Date.now() + Math.floor(Math.random() * 1000);
        const burst = {
          id,
          colors: Array.isArray(config.colors) ? config.colors.map((value) => String(value).replace(/^#/, "")).filter(Boolean) : ["3291ff", "3ecf8e", "f5a623", "f14c4c", "8e4ec6"],
          count: Math.max(12, Number(config.count) || 30),
          durationMs: Math.max(1000, Number(config.duration) > 0 ? Number(config.duration) * 1000 : 2500)
        };
        setPluginConfettiBursts((current) => [...current.slice(-1), burst]);
        window.setTimeout(() => {
          setPluginConfettiBursts((current) => current.filter((item) => item.id !== id));
        }, burst.durationMs + 400);
      }
      if (effect.type === "combo-counter") {
        const decayMs = Math.max(400, Number(config.decaySeconds) > 0 ? Number(config.decaySeconds) * 1000 : 2400);
        let nextCount = 1;
        setPluginCombo((current) => {
          nextCount = (current?.count ?? 0) + 1;
          return {
            id: Date.now() + Math.floor(Math.random() * 1000),
            count: nextCount,
            label: typeof config.label === "string" && config.label.trim() ? config.label.trim() : "Combo",
            color: normalizeEffectColor(config.colorHex ?? config.tint, "#f5a623")
          };
        });
        if (comboDecayTimerRef.current) {
          window.clearTimeout(comboDecayTimerRef.current);
        }
        comboDecayTimerRef.current = window.setTimeout(() => {
          setPluginCombo(null);
          comboDecayTimerRef.current = null;
        }, decayMs);
        if (config.shakeOnMilestone && nextCount % 10 === 0) {
          setPluginShake({
            id: Date.now() + 1,
            intensity: Math.max(3, Number(config.milestoneIntensity) || 7),
            durationMs: Math.max(180, Number(config.milestoneDuration) > 0 ? Number(config.milestoneDuration) * 1000 : 360)
          });
        }
      }
      if (effect.type === "particle-burst") {
        const id = Date.now() + Math.floor(Math.random() * 1000);
        const burst = {
          id,
          emojis:
            Array.isArray(config.emojis) && config.emojis.length > 0
              ? config.emojis.map((value) => String(value)).filter(Boolean)
              : ["⌨", "✨", "⚡", "💥"],
          count: Math.max(3, Math.min(18, Number(config.count) || 6)),
          durationMs: Math.max(420, Number(config.duration) > 0 ? Number(config.duration) * 1000 : 900)
        };
        setPluginParticleBursts((current) => [...current.slice(-4), burst]);
        window.setTimeout(() => {
          setPluginParticleBursts((current) => current.filter((item) => item.id !== id));
        }, burst.durationMs + 240);
      }
      if (effect.type === "sound") {
        playPluginSound(config);
      }
    }
  }

  async function refreshPluginRuntime(nextSessions: SessionSnapshot[] = sessions) {
    const installedPluginDirs = enabledInstalledPluginDirs(loadInstalledPlugins());
    const sessionPluginDirs = nextSessions.flatMap((session) =>
      Array.isArray(session.pluginDirs) ? session.pluginDirs.map((value) => value.trim()).filter(Boolean) : []
    );
    const pluginDirs = [...new Set([...installedPluginDirs, ...sessionPluginDirs])];
    const snapshot =
      pluginDirs.length > 0
        ? await window.doffice.getPluginRuntimeSnapshot(pluginDirs).catch(() => emptyPluginRuntimeSnapshot)
        : emptyPluginRuntimeSnapshot;
    setPluginRuntimeSnapshot(snapshot);
    setPluginRuntimeVersion((current) => current + 1);
  }

  useEffect(() => {
    let unsubscribe = () => {};

    void window.doffice.bootstrap().then((payload: BootstrapPayload) => {
      setSessions(payload.sessions);
      applyCLIStatuses(payload);
      setSelectedId((current) => current || payload.sessions[0]?.id || "");
      void refreshPluginRuntime(payload.sessions);
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
    void refreshPluginRuntime(sessions);
  }, [sessions.map((session) => session.pluginDirs.join("||")).join("###")]);

  useEffect(() => {
    function handleInstalledPluginsChanged() {
      void refreshPluginRuntime();
    }

    window.addEventListener("doffice:installed-plugins-changed", handleInstalledPluginsChanged);
    return () => window.removeEventListener("doffice:installed-plugins-changed", handleInstalledPluginsChanged);
  }, [sessions]);

  useEffect(() => {
    const unsubscribeSelect = window.doffice.onAutomationSelectSession((sessionId) => {
      setSelectedId(sessionId);
    });
    const unsubscribeOpenBrowser = window.doffice.onAutomationOpenBrowser((payload) => {
      if (payload.sessionId) {
        setSelectedId(payload.sessionId);
      }
      setAppViewMode("terminal");
      setTerminalViewMode("browser");
      window.setTimeout(() => {
        window.dispatchEvent(new CustomEvent("doffice:open-browser-url", { detail: payload }));
      }, 40);
    });
    return () => {
      unsubscribeSelect();
      unsubscribeOpenBrowser();
    };
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
      if (comboDecayTimerRef.current) {
        window.clearTimeout(comboDecayTimerRef.current);
      }
      if (audioContextRef.current) {
        void audioContextRef.current.close().catch(() => undefined);
      }
    };
  }, []);

  useEffect(() => {
    if (!pluginFlash) return;
    const timer = window.setTimeout(() => setPluginFlash((current) => (current?.id === pluginFlash.id ? null : current)), pluginFlash.durationMs + 40);
    return () => window.clearTimeout(timer);
  }, [pluginFlash]);

  useEffect(() => {
    if (!pluginShake) return;
    const timer = window.setTimeout(() => setPluginShake((current) => (current?.id === pluginShake.id ? null : current)), pluginShake.durationMs + 40);
    return () => window.clearTimeout(timer);
  }, [pluginShake]);

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
        const notification = {
          id: `${session.id}-completed-${session.completedPromptCount}`,
          sessionId: session.id,
          title: `${session.workerName || session.projectName} completed`,
          detail: sessionActivitySummary(session),
          tint: "#3ecf8e",
          glyph: "●"
        };
        generated.push(notification);
        triggerPluginEffects("onSessionComplete", session);
        continue;
      }

      if (currentStatus === "attention" && previous.status !== "attention") {
        const notification = {
          id: `${session.id}-attention-${session.lastActivityTime}`,
          sessionId: session.id,
          title: `${session.workerName || session.projectName} needs attention`,
          detail: sessionActivitySummary(session),
          tint: "#f14c4c",
          glyph: "▲"
        };
        generated.push(notification);
        triggerPluginEffects("onSessionError", session);
      }
    }

    for (const notification of generated) {
      appendNotification(notification);
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
      if ((event.key === "Delete" || event.key === "Backspace") && !isEditableTarget(event.target)) {
        if (!selectedId) return;
        event.preventDefault();
        void removeSession(selectedId);
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
  }, [selectedId, sessions]);

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
    applyCLIStatuses(payload);
    await refreshPluginRuntime(payload.sessions);
  }

  async function refreshCLIStatuses() {
    const payload = await window.doffice.refreshCLIStatuses();
    applyCLIStatuses(payload);
    return payload;
  }

  async function installCLI(provider: AgentProvider): Promise<CLIInstallResult> {
    const result = await window.doffice.installCLI(provider);
    applyCLIStatuses(result);
    return result;
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

  async function handleCreateSession() {
    if (!newSessionDraft.projectPath.trim()) return;
    setBusy(true);
    try {
      const parsedBudget = Number(newSessionDraft.maxBudget);
      const autoInstalledPluginDirs = enabledInstalledPluginDirs(loadInstalledPlugins());
      const pluginDirs = [...new Set([...autoInstalledPluginDirs, ...newSessionDraft.pluginDirs.map((value) => value.trim()).filter(Boolean)])];
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
        pluginDirs,
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
      const targetSession = sessions.find((session) => session.id === sessionId) ?? null;
      triggerPluginEffects("onPromptSubmit", targetSession);
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

  function handlePromptKeyPress(sessionId: string, previousValue: string, nextValue: string) {
    if (nextValue.length <= previousValue.length) return;
    if (!nextValue.trim()) return;
    const targetSession = sessions.find((session) => session.id === sessionId) ?? null;
    triggerPluginEffects("onPromptKeyPress", targetSession);
  }

  function handleWorkspaceLevelUp() {
    triggerPluginEffects("onLevelUp", selectedSession);
  }

  function handlePluginPanelNotify(pluginName: string, text: string) {
    if (!text.trim()) return;
    appendNotification(
      {
        id: `plugin-panel-notify-${pluginName}-${Date.now()}`,
        sessionId: selectedSession?.id || "",
        title: pluginName,
        detail: text.trim(),
        tint: "#5ccfff",
        glyph: "▣"
      },
      5200
    );
  }

  async function executePluginCommand(scriptPath: string, title: string) {
    const result = await window.doffice.executePluginCommand(scriptPath, selectedSession?.projectPath);
    appendNotification({
      id: `plugin-command-${title}-${Date.now()}`,
      sessionId: selectedSession?.id || "",
      title,
      detail: result.output || (result.ok ? "Plugin command finished." : "Plugin command failed."),
      tint: result.ok ? "#3ecf8e" : "#f14c4c",
      glyph: result.ok ? "⌘" : "!"
    }, result.ok ? 4200 : 7000);
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
      geminiStatus={geminiStatus}
      refreshCLIStatuses={refreshCLIStatuses}
      installCLI={installCLI}
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
      pluginRuntimeVersion={pluginRuntimeVersion}
      pluginFlash={pluginFlash}
      pluginShake={pluginShake}
      pluginConfettiBursts={pluginConfettiBursts}
      pluginCombo={pluginCombo}
      pluginParticleBursts={pluginParticleBursts}
      isCurrentDraftFavorite={isCurrentDraftFavorite}
      chooseSuggestedProject={chooseSuggestedProject}
      toggleDraftFavorite={toggleDraftFavorite}
      applyNewSessionPreset={applyNewSessionPreset}
      handlePickDirectory={handlePickDirectory}
      handleAddPluginDirectory={handleAddPluginDirectory}
      handleCreateSession={handleCreateSession}
      executePluginCommand={executePluginCommand}
      notifyPluginMessage={handlePluginPanelNotify}
      onWorkspaceLevelUp={handleWorkspaceLevelUp}
      onPromptKeyPress={handlePromptKeyPress}
    />
  );
}

export default App;
