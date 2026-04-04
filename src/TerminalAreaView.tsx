import { useEffect, useMemo, useState, type CSSProperties, type FormEvent, type KeyboardEvent, type ReactNode } from "react";
import { GitPanelView } from "./GitPanelView";
import { BrowserPaneView } from "./BrowserPaneView";
import { t, tf } from "./localizationCatalog";
import type { AgentProvider, ImageAttachment, SessionBlock, SessionSnapshot } from "./types";
import type { TerminalViewMode } from "./uiModel";
import { inferPendingApproval, inferStatus } from "./sessionUtils";

interface TerminalAreaViewProps {
  sessions: SessionSnapshot[];
  selectedSession: SessionSnapshot | null;
  terminalViewMode: TerminalViewMode;
  setTerminalViewMode: (value: TerminalViewMode) => void;
  pinnedSessionIds: string[];
  togglePinnedSession: (sessionId: string) => void;
  prompt: string;
  setPrompt: (value: string) => void;
  busy: boolean;
  sendPrompt: (event: FormEvent) => void;
  sendPromptToSession: (sessionId: string, prompt: string) => Promise<void>;
  approvePendingApproval: () => void;
  denyPendingApproval: () => void;
  dismissDangerousWarning: () => void;
  dismissSensitiveWarning: () => void;
  selectSession: (sessionId: string) => void;
  removeSession: (sessionId: string) => void;
  openNewSession: () => void;
}

type TerminalSplitAxis = "horizontal" | "vertical";

interface TerminalSplitState {
  enabled: boolean;
  axis: TerminalSplitAxis;
  secondarySessionId: string | null;
}

interface PastedChunkRecord {
  id: number;
  text: string;
  lineCount: number;
}

interface DraftPasteState {
  counter: number;
  chunks: PastedChunkRecord[];
}

const terminalSplitStorageKey = "doffice.terminal.single-split";

function loadTerminalSplitState(): TerminalSplitState {
  try {
    const raw = window.localStorage.getItem(terminalSplitStorageKey);
    if (!raw) {
      return { enabled: false, axis: "vertical", secondarySessionId: null };
    }
    const parsed = JSON.parse(raw) as Partial<TerminalSplitState>;
    return {
      enabled: typeof parsed.enabled === "boolean" ? parsed.enabled : false,
      axis: parsed.axis === "horizontal" ? "horizontal" : "vertical",
      secondarySessionId: typeof parsed.secondarySessionId === "string" && parsed.secondarySessionId.trim() ? parsed.secondarySessionId : null
    };
  } catch {
    return { enabled: false, axis: "vertical", secondarySessionId: null };
  }
}

export function TerminalAreaView(props: TerminalAreaViewProps) {
  const {
    sessions,
    selectedSession,
    terminalViewMode,
    setTerminalViewMode,
    pinnedSessionIds,
    togglePinnedSession,
    prompt,
    setPrompt,
    busy,
    sendPrompt,
    sendPromptToSession,
    approvePendingApproval,
    denyPendingApproval,
    dismissDangerousWarning,
    dismissSensitiveWarning,
    selectSession,
    removeSession,
    openNewSession
  } = props;
  const [showFilterBar, setShowFilterBar] = useState(false);
  const [showFilePanel, setShowFilePanel] = useState(false);
  const [onlyErrors, setOnlyErrors] = useState(false);
  const [searchText, setSearchText] = useState("");
  const [toolFilters, setToolFilters] = useState<string[]>([]);
  const [gridDrafts, setGridDrafts] = useState<Record<string, string>>({});
  const [splitDrafts, setSplitDrafts] = useState<Record<string, string>>({});
  const [draftPasteState, setDraftPasteState] = useState<Record<string, DraftPasteState>>({});
  const [attachedImage, setAttachedImage] = useState<ImageAttachment | null>(null);
  const [splitState, setSplitState] = useState<TerminalSplitState>(loadTerminalSplitState);

  const selectedSessionStatus = selectedSession ? inferStatus(selectedSession) : null;
  const activeSingleModel = singleModelValue(selectedSession);
  const terminalGridStyle = useMemo<CSSProperties>(() => ({ gridTemplateColumns: terminalGridTemplate(sessions.length) }), [sessions.length]);
  const secondarySession = useMemo(
    () => resolveSecondarySession(sessions, selectedSession?.id ?? null, splitState.secondarySessionId),
    [sessions, selectedSession?.id, splitState.secondarySessionId]
  );
  const filteredBlocks = useMemo(() => {
    if (!selectedSession) return [];
    return selectedSession.blocks.filter((block) => {
      if (onlyErrors && block.kind !== "toolError" && block.kind !== "error") {
        return false;
      }
      if (toolFilters.length > 0) {
        const toolName = String(block.meta?.toolName ?? "");
        const matchesTool =
          (block.kind === "toolUse" || block.kind === "toolOutput" || block.kind === "toolError" || block.kind === "fileChange") &&
          toolFilters.includes(toolName || (block.kind === "fileChange" ? "Edit" : ""));
        if (!matchesTool && block.kind !== "userPrompt" && block.kind !== "thought" && block.kind !== "completion" && block.kind !== "status") {
          return false;
        }
      }
      if (searchText.trim()) {
        const haystack = `${block.kind} ${block.content} ${String(block.meta?.toolName ?? "")}`.toLowerCase();
        if (!haystack.includes(searchText.trim().toLowerCase())) {
          return false;
        }
      }
      return true;
    });
  }, [onlyErrors, searchText, selectedSession, toolFilters]);

  const selectedFileCount = selectedSession ? new Set(selectedSession.fileChanges.map((change) => change.fileName)).size : 0;
  const selectedErrorCount = selectedSession
    ? selectedSession.blocks.filter((block) => block.kind === "toolError" || block.kind === "error").length
    : 0;
  const selectedCommandCount = selectedSession ? selectedSession.blocks.filter((block) => block.kind === "toolUse").length : 0;

  useEffect(() => {
    setAttachedImage(null);
  }, [selectedSession?.id]);

  useEffect(() => {
    setDraftPasteState({});
  }, [selectedSession?.id]);

  useEffect(() => {
    window.localStorage.setItem(terminalSplitStorageKey, JSON.stringify(splitState));
  }, [splitState]);

  useEffect(() => {
    if (!splitState.enabled) return;
    if (!selectedSession) {
      setSplitState((current) => ({ ...current, enabled: false, secondarySessionId: null }));
      return;
    }
    if (secondarySession) return;
    const fallbackId = defaultSecondarySessionId(sessions, selectedSession.id);
    setSplitState((current) =>
      fallbackId
        ? { ...current, secondarySessionId: fallbackId }
        : { ...current, enabled: false, secondarySessionId: null }
    );
  }, [secondarySession, selectedSession, sessions, splitState.enabled]);

  function toggleToolFilter(toolName: string) {
    setToolFilters((current) => (current.includes(toolName) ? current.filter((value) => value !== toolName) : [...current, toolName]));
  }

  function submitTextareaOnEnter(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      event.currentTarget.form?.requestSubmit();
    }
  }

  async function updateSelectedSessionConfig(patch: {
    provider?: AgentProvider;
    selectedModel?: string;
    effortLevel?: string;
    outputMode?: string;
    permissionMode?: string;
    enableBrief?: boolean;
  }) {
    if (!selectedSession) return;
    await window.doffice.updateSessionConfig({
      sessionId: selectedSession.id,
      ...patch
    });
  }

  async function handleSingleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedSession) return;
    const expandedPrompt = expandPastedChunks(prompt, draftPasteState.__single__?.chunks ?? []);
    const nextPrompt = expandedPrompt.trim();
    if (!nextPrompt) return;
    const promptWithAttachment = attachedImage
      ? [nextPrompt, "", `[첨부 이미지] ${attachedImage.path || "선택된 이미지"}`].join("\n")
      : nextPrompt;
    await sendPromptToSession(selectedSession.id, promptWithAttachment);
    setPrompt("");
    clearDraftPasteState("__single__");
    setAttachedImage(null);
  }

  async function handlePickAttachment() {
    const nextAttachment = await window.doffice.pickImageFile();
    if (nextAttachment) {
      setAttachedImage(nextAttachment);
    }
  }

  function openSplit(axis: TerminalSplitAxis) {
    if (!selectedSession) return;
    const fallbackId = secondarySession?.id ?? defaultSecondarySessionId(sessions, selectedSession.id);
    if (!fallbackId) return;
    setSplitState({
      enabled: true,
      axis,
      secondarySessionId: fallbackId
    });
  }

  function closeSplit() {
    setSplitState((current) => ({ ...current, enabled: false, secondarySessionId: null }));
  }

  function updateDraftWithPaste(key: string, previousValue: string, nextValue: string, applyValue: (value: string) => void) {
    const addedLength = nextValue.length - previousValue.length;
    if (addedLength <= 0) {
      applyValue(nextValue);
      return;
    }

    const added = nextValue.slice(nextValue.length - addedLength);
    const lineCount = added.split(/\r?\n/).length;
    if (lineCount < 5) {
      applyValue(nextValue);
      return;
    }

    setDraftPasteState((current) => {
      const nextState = current[key] ?? { counter: 0, chunks: [] };
      const nextId = nextState.counter + 1;
      const placeholder = `[Pasted text #${nextId} +${lineCount} lines]`;
      applyValue(`${nextValue.slice(0, nextValue.length - addedLength)}${placeholder}`);
      return {
        ...current,
        [key]: {
          counter: nextId,
          chunks: [...nextState.chunks, { id: nextId, text: added, lineCount }]
        }
      };
    });
  }

  function clearDraftPasteState(key: string) {
    setDraftPasteState((current) => {
      if (!(key in current)) return current;
      const next = { ...current };
      delete next[key];
      return next;
    });
  }

  return (
    <section className="terminal-shell">
      <div className="terminal-topbar">
        <div className="terminal-mode-strip">
          {(["grid", "single", "git", "browser"] as TerminalViewMode[]).map((mode) => (
            <button
              key={mode}
              className={`terminal-mode-button ${terminalViewMode === mode ? "is-active" : ""}`}
              onClick={() => setTerminalViewMode(mode)}
            >
              <span className="view-mode-icon">{terminalModeIcon(mode)}</span>
              {terminalViewModeLabel(mode)}
            </button>
          ))}
        </div>
        <div className="terminal-tab-strip">
          {sessions.map((session) => {
            const status = inferStatus(session);
            const pinned = pinnedSessionIds.includes(session.id);
            const approval = inferPendingApproval(session);
            return (
              <button
                key={session.id}
                className={`terminal-tab ${selectedSession?.id === session.id ? "is-active" : ""} ${pinned ? "is-pinned" : ""}`}
                onClick={() => selectSession(session.id)}
                onContextMenu={(event) => {
                  event.preventDefault();
                  void window.doffice.showSessionContextMenu(session.id);
                }}
              >
                <span className="worker-dot" style={{ backgroundColor: status.category === "attention" ? "#f14c4c" : session.workerColorHex }} />
                <span className="terminal-tab-label">{session.projectName}</span>
                {approval ? <span className="terminal-tab-badge tone-warning">{t("custom.approval")}</span> : null}
                {!approval && status.category === "processing" ? <span className="terminal-tab-badge">{t("custom.busy")}</span> : null}
              </button>
            );
          })}
        </div>
        <div className="terminal-topbar-actions">
          {terminalViewMode === "single" && selectedSession ? (
            <>
              <button
                type="button"
                className={`chrome-icon-button ${splitState.enabled && splitState.axis === "horizontal" ? "is-active" : ""}`}
                onClick={() => openSplit("horizontal")}
                disabled={sessions.length < 2}
                title={t("custom.split.horizontal")}
              >
                ⇳
              </button>
              <button
                type="button"
                className={`chrome-icon-button ${splitState.enabled && splitState.axis === "vertical" ? "is-active" : ""}`}
                onClick={() => openSplit("vertical")}
                disabled={sessions.length < 2}
                title={t("custom.split.vertical")}
              >
                ⇔
              </button>
              {splitState.enabled ? (
                <button type="button" className="chrome-icon-button" onClick={closeSplit} title={t("custom.split.close")}>
                  ✕
                </button>
              ) : null}
            </>
          ) : null}
          <button className="chrome-icon-button" onClick={openNewSession}>
            ＋
          </button>
        </div>
      </div>

      {terminalViewMode === "grid" ? (
        <div className="terminal-grid" style={terminalGridStyle}>
          {sessions.map((session) => {
            const status = inferStatus(session);
            const pinned = pinnedSessionIds.includes(session.id);
            const compactBlocks = condensedBlocks(session.blocks);
            return (
              <article
                key={session.id}
                className={`terminal-grid-card ${selectedSession?.id === session.id ? "is-selected" : ""}`}
                onContextMenu={(event) => {
                  event.preventDefault();
                  void window.doffice.showSessionContextMenu(session.id);
                }}
              >
                <div className="terminal-grid-head">
                  <button className="terminal-grid-title" onClick={() => selectSession(session.id)}>
                    <span className="worker-dot" style={{ backgroundColor: session.workerColorHex }} />
                    <strong>{session.projectName}</strong>
                  </button>
                  <button className={`pin-button ${pinned ? "is-active" : ""}`} onClick={() => togglePinnedSession(session.id)}>
                    {pinned ? t("custom.unpin") : t("custom.pin")}
                  </button>
                </div>
                <div className="terminal-grid-meta">
                  <span>{session.workerName}</span>
                  <span style={{ color: session.pendingApproval ? "#f5a623" : status.tint }}>
                    {session.pendingApproval ? t("custom.approval") : status.label}
                  </span>
                </div>
                <div className="terminal-grid-stream is-compact">
                  {compactBlocks.length === 0 ? <div className="terminal-grid-empty">{latestText(session.blocks)}</div> : null}
                  {compactBlocks.map((block) => (
                    <EventBlock key={block.id} block={block} compact />
                  ))}
                </div>
                <form
                  className="grid-composer"
                  onSubmit={async (event) => {
                    event.preventDefault();
                    const nextPrompt = gridDrafts[session.id]?.trim();
                    const expandedPrompt = expandPastedChunks(gridDrafts[session.id] ?? "", draftPasteState[session.id]?.chunks ?? []).trim();
                    if (!expandedPrompt) return;
                    await sendPromptToSession(session.id, expandedPrompt);
                    setGridDrafts((current) => ({ ...current, [session.id]: "" }));
                    clearDraftPasteState(session.id);
                  }}
                >
                  <textarea
                    value={gridDrafts[session.id] ?? ""}
                    onChange={(event) =>
                      updateDraftWithPaste(
                        session.id,
                        gridDrafts[session.id] ?? "",
                        event.target.value,
                        (value) => setGridDrafts((current) => ({ ...current, [session.id]: value }))
                      )
                    }
                    onKeyDown={submitTextareaOnEnter}
                    placeholder={t("custom.direct.chat")}
                    rows={3}
                  />
                  <button type="submit" className="primary-button" disabled={busy || !(gridDrafts[session.id] ?? "").trim()}>
                    Send
                  </button>
                </form>
              </article>
            );
          })}
        </div>
      ) : null}

      {terminalViewMode === "single" ? (
        selectedSession ? (
          splitState.enabled && secondarySession ? (
            <div className="terminal-single terminal-single-split">
              <div className={`terminal-split-view axis-${splitState.axis}`}>
                <SplitSessionPane
                  session={selectedSession}
                  sessions={sessions}
                  draft={splitDrafts[selectedSession.id] ?? ""}
                  busy={busy}
                  onDraftChange={(value) => setSplitDrafts((current) => ({ ...current, [selectedSession.id]: value }))}
                  onSubmit={async () => {
                    const nextPrompt = (splitDrafts[selectedSession.id] ?? "").trim();
                    const expandedPrompt = expandPastedChunks(splitDrafts[selectedSession.id] ?? "", draftPasteState[selectedSession.id]?.chunks ?? []).trim();
                    if (!expandedPrompt) return;
                    await sendPromptToSession(selectedSession.id, expandedPrompt);
                    setSplitDrafts((current) => ({ ...current, [selectedSession.id]: "" }));
                    clearDraftPasteState(selectedSession.id);
                  }}
                  onSelectSession={null}
                />
                <SplitSessionPane
                  session={secondarySession}
                  sessions={sessions.filter((session) => session.id !== selectedSession.id)}
                  draft={splitDrafts[secondarySession.id] ?? ""}
                  busy={busy}
                  onDraftChange={(value) => setSplitDrafts((current) => ({ ...current, [secondarySession.id]: value }))}
                  onSubmit={async () => {
                    const nextPrompt = (splitDrafts[secondarySession.id] ?? "").trim();
                    const expandedPrompt = expandPastedChunks(splitDrafts[secondarySession.id] ?? "", draftPasteState[secondarySession.id]?.chunks ?? []).trim();
                    if (!expandedPrompt) return;
                    await sendPromptToSession(secondarySession.id, expandedPrompt);
                    setSplitDrafts((current) => ({ ...current, [secondarySession.id]: "" }));
                    clearDraftPasteState(secondarySession.id);
                  }}
                  onSelectSession={(sessionId) => setSplitState((current) => ({ ...current, secondarySessionId: sessionId }))}
                />
              </div>
            </div>
          ) : (
          <div className="terminal-single">
            <div className="terminal-single-header">
              <div className="terminal-single-title">
                <span className="worker-dot" style={{ backgroundColor: selectedSession.workerColorHex }} />
                <div className="terminal-single-title-copy">
                  <strong>{selectedSession.workerName}</strong>
                  <span>
                    {selectedSession.projectName}
                    {" · "}
                    <em style={{ color: selectedSession.pendingApproval ? "#f5a623" : selectedSessionStatus?.tint }}>
                      {selectedSession.pendingApproval ? t("custom.approval.needed") : selectedSessionStatus?.label}
                    </em>
                    {" · "}
                    {relativeDuration(selectedSession.startTime)}
                    {selectedFileCount > 0 ? ` · ${selectedFileCount} ${t("custom.files")}` : ""}
                    {selectedErrorCount > 0 ? ` · ${selectedErrorCount} ${t("custom.errors")}` : ""}
                    {selectedCommandCount > 0 ? ` · ${selectedCommandCount} cmds` : ""}
                  </span>
                </div>
              </div>
              <div className="terminal-single-header-actions">
                <button
                  type="button"
                  className={`status-toggle ${showFilterBar || onlyErrors || toolFilters.length > 0 || searchText.trim() ? "is-active" : ""}`}
                  onClick={() => setShowFilterBar((current) => !current)}
                >
                  {t("custom.filter")}
                </button>
                <button
                  type="button"
                  className={`status-toggle ${showFilePanel ? "is-active" : ""}`}
                  onClick={() => setShowFilePanel((current) => !current)}
                >
                  {t("custom.files")}
                </button>
                <button type="button" className="status-toggle" onClick={() => togglePinnedSession(selectedSession.id)}>
                  {pinnedSessionIds.includes(selectedSession.id) ? t("custom.unpin") : t("custom.pin")}
                </button>
              </div>
            </div>

            {selectedSession.dangerousCommandWarning ? (
              <div className="security-banner tone-danger">
                <div className="security-banner-copy">
                  <strong>{t("custom.dangerous.command")}</strong>
                  <span>{selectedSession.dangerousCommandWarning}</span>
                </div>
                <button type="button" className="security-banner-dismiss" onClick={dismissDangerousWarning}>
                  ✕
                </button>
              </div>
            ) : null}

            {selectedSession.sensitiveFileWarning ? (
              <div className="security-banner tone-warning">
                <div className="security-banner-copy">
                  <strong>{t("custom.sensitive.file")}</strong>
                  <span>{selectedSession.sensitiveFileWarning}</span>
                </div>
                <button type="button" className="security-banner-dismiss" onClick={dismissSensitiveWarning}>
                  ✕
                </button>
              </div>
            ) : null}

            {showFilterBar ? (
              <div className="terminal-filter-bar">
                <div className="terminal-filter-tools">
                  {(["Bash", "Read", "Write", "Edit", "Grep", "Glob"] as const).map((tool) => (
                    <button
                      key={tool}
                      type="button"
                      className={`filter-toggle ${toolFilters.includes(tool) ? "is-active" : ""}`}
                      onClick={() => toggleToolFilter(tool)}
                    >
                      {tool}
                    </button>
                  ))}
                  <button
                    type="button"
                    className={`filter-toggle tone-red ${onlyErrors ? "is-active" : ""}`}
                    onClick={() => setOnlyErrors((current) => !current)}
                  >
                    {t("custom.errors")}
                  </button>
                </div>
                <div className="terminal-filter-search">
                  <input value={searchText} onChange={(event) => setSearchText(event.target.value)} placeholder={t("custom.search.log")} />
                  {onlyErrors || toolFilters.length > 0 || searchText.trim() ? (
                    <button
                      type="button"
                      className="filter-clear"
                      onClick={() => {
                        setOnlyErrors(false);
                        setToolFilters([]);
                        setSearchText("");
                      }}
                    >
                      {t("custom.clear")}
                    </button>
                  ) : null}
                </div>
              </div>
            ) : null}

            <div className="terminal-single-body">
              <div className="event-stream">
                {filteredBlocks.length === 0 ? <div className="empty-stream">{t("custom.no.output")}</div> : null}
                {filteredBlocks.map((block) => (
                  <EventBlock key={block.id} block={block} />
                ))}
              </div>

              {showFilePanel ? (
                <aside className="file-change-panel">
                  <div className="file-change-panel-header">
                    <span>{t("custom.files")}</span>
                    <strong>{selectedFileCount}</strong>
                  </div>
                  <div className="file-change-panel-body">
                    {selectedSession.fileChanges.length === 0 ? <div className="leaderboard-empty">{t("custom.no.tracked.file.changes")}</div> : null}
                    {Object.entries(
                      selectedSession.fileChanges.reduce<Record<string, typeof selectedSession.fileChanges>>((acc, change) => {
                        acc[change.path] = [...(acc[change.path] ?? []), change];
                        return acc;
                      }, {})
                    ).map(([filePath, changes]) => {
                      const latest = changes.at(-1);
                      if (!latest) return null;
                      return (
                        <div key={filePath} className="file-change-item">
                          <div className="file-change-title-row">
                            <strong>{latest.fileName}</strong>
                            <span>{latest.action}</span>
                          </div>
                          <div className="file-change-subtitle">{tf("custom.changes", undefined, changes.length)}</div>
                        </div>
                      );
                    })}
                  </div>
                </aside>
              ) : null}
            </div>

            <form className="composer" onSubmit={handleSingleSubmit}>
              <div className="single-composer-topbar">
                <div className="single-composer-name">{selectedSession.workerName}</div>
                <div className="terminal-config-badges">
                  <span className="terminal-config-pill tone-accent">{t("custom.agent")} {sessionProviderLabel(selectedSession.provider)}</span>
                  <span className="terminal-config-pill">{t("terminal.config.model")} {singleModelLabel(activeSingleModel)}</span>
                  <span className="terminal-config-pill">{t("custom.effort")} {effortLabel(selectedSession.effortLevel)}</span>
                  <span className="terminal-config-pill tone-warning">{t("custom.enable.brief")} {selectedSession.enableBrief ? "ON" : "OFF"}</span>
                </div>
              </div>
              <div className="single-config-groups">
                <ConfigChoiceGroup label="Agent">
                  {(["claude", "codex"] as const).map((provider) => (
                    <button
                      key={provider}
                      type="button"
                      className={`terminal-choice-chip tone-blue ${selectedSession.provider === provider ? "is-active" : ""}`}
                      onClick={() =>
                        void updateSelectedSessionConfig({
                          provider,
                          selectedModel: provider === "codex" ? "gpt-5.4" : "sonnet"
                        })
                      }
                    >
                      {provider === "codex" ? "Codex" : "Claude"}
                    </button>
                  ))}
                </ConfigChoiceGroup>
                <ConfigChoiceGroup label="Model">
                  {singleModelOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className={`terminal-choice-chip tone-blue ${activeSingleModel === option.value ? "is-active" : ""}`}
                      onClick={() =>
                        void updateSelectedSessionConfig({
                          provider: option.provider,
                          selectedModel: option.model
                        })
                      }
                    >
                      {option.label}
                    </button>
                  ))}
                </ConfigChoiceGroup>
                <ConfigChoiceGroup label="Effort">
                  {effortOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className={`terminal-choice-chip tone-blue ${selectedSession.effortLevel === option.value ? "is-active" : ""}`}
                      onClick={() => void updateSelectedSessionConfig({ effortLevel: option.value })}
                    >
                      {option.label}
                    </button>
                  ))}
                </ConfigChoiceGroup>
                <ConfigChoiceGroup label="Output">
                  {outputOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className={`terminal-choice-chip tone-cyan ${selectedSession.outputMode === option.value ? "is-active" : ""}`}
                      onClick={() => void updateSelectedSessionConfig({ outputMode: option.value })}
                    >
                      {option.label}
                    </button>
                  ))}
                </ConfigChoiceGroup>
                <ConfigChoiceGroup label="권한">
                  {permissionOptions.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className={`terminal-choice-chip tone-yellow ${selectedSession.permissionMode === option.value ? "is-active" : ""}`}
                      onClick={() => void updateSelectedSessionConfig({ permissionMode: option.value })}
                    >
                      {option.label}
                    </button>
                  ))}
                </ConfigChoiceGroup>
              </div>
              {attachedImage ? (
                <div className="composer-attachment-row">
                  <span className="composer-attachment-chip">🖼 {imageLabel(attachedImage)}</span>
                  <button type="button" className="composer-attachment-clear" onClick={() => setAttachedImage(null)}>
                    ✕
                  </button>
                </div>
              ) : null}
              <textarea
                value={prompt}
                onChange={(event) => updateDraftWithPaste("__single__", prompt, event.target.value, setPrompt)}
                onKeyDown={submitTextareaOnEnter}
                placeholder={t("custom.send.prompt.placeholder")}
                rows={4}
              />
              <div className="composer-actions">
                <div className="composer-utility-actions">
                  <button type="button" className="mini-action-button icon-action-button" onClick={() => void handlePickAttachment()}>
                    🖼
                  </button>
                  <button
                    type="button"
                    className={`mini-action-button icon-action-button ${selectedSession.enableBrief ? "is-active" : ""}`}
                    onClick={() => void updateSelectedSessionConfig({ enableBrief: !selectedSession.enableBrief })}
                  >
                    ☾
                  </button>
                </div>
                <button type="submit" className="primary-button" disabled={busy || !prompt.trim()}>
                  Send
                </button>
              </div>
            </form>
          </div>
          )
        ) : (
          <div className="empty-stream">{t("custom.no.session.selected")}</div>
        )
      ) : null}

      {terminalViewMode === "git" ? <GitPanelView selectedSession={selectedSession} /> : null}
      {terminalViewMode === "browser" ? <BrowserPaneView selectedSession={selectedSession} /> : null}

      {selectedSession?.pendingApproval ? (
        <div className="terminal-overlay-backdrop">
          <div className="approval-sheet">
            <div className="approval-sheet-title">{t("terminal.approval.needed")}</div>
            <div className="approval-sheet-reason">{selectedSession.pendingApproval.reason}</div>
            <pre className="approval-sheet-command">{selectedSession.pendingApproval.command}</pre>
            <div className="approval-sheet-actions">
              <button type="button" className="secondary-button danger" onClick={denyPendingApproval} disabled={busy}>
                {t("terminal.deny")}
              </button>
              <button type="button" className="primary-button" onClick={approvePendingApproval} disabled={busy}>
                {t("terminal.approve")}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}

function EventBlock(props: { block: SessionBlock; compact?: boolean }) {
  const { block, compact = false } = props;
  if (compact) {
    return (
      <div className={`event-block is-compact kind-${block.kind}`}>
        <div className="event-kind">{compactLabelForBlock(block.kind)}</div>
        <pre>{compactBlockText(block)}</pre>
      </div>
    );
  }
  return (
    <div className={`event-block kind-${block.kind}`}>
      <div className="event-kind">{labelForBlock(block.kind)}</div>
      <pre>{block.content || " "}</pre>
    </div>
  );
}

function labelForBlock(kind: SessionBlock["kind"]): string {
  switch (kind) {
    case "userPrompt":
      return t("custom.initial.prompt");
    case "thought":
      return "THOUGHT";
    case "toolUse":
      return "TOOL";
    case "toolOutput":
      return "OUTPUT";
    case "toolError":
      return t("custom.errors").toUpperCase();
    case "completion":
      return t("custom.completed").toUpperCase();
    case "status":
      return "STATUS";
    default:
      return kind.toUpperCase();
  }
}

function latestText(blocks: SessionBlock[]): string {
  const textBlock = [...blocks].reverse().find((block) => block.content.trim());
  return textBlock?.content ?? t("custom.no.output");
}

function expandPastedChunks(value: string, chunks: PastedChunkRecord[]): string {
  return chunks.reduce((current, chunk) => current.replaceAll(`[Pasted text #${chunk.id} +${chunk.lineCount} lines]`, chunk.text), value);
}

function condensedBlocks(blocks: SessionBlock[]): SessionBlock[] {
  const meaningful = blocks.filter((block) => {
    const text = block.content.trim();
    return Boolean(text) && (block.kind !== "status" || text !== "중지됨");
  });
  const deduped = meaningful.filter((block, index, entries) => {
    const previous = entries[index - 1];
    if (!previous) return true;
    return !(previous.kind === block.kind && previous.content.trim() === block.content.trim());
  });
  return deduped.slice(-10);
}

function compactLabelForBlock(kind: SessionBlock["kind"]): string {
  switch (kind) {
    case "userPrompt":
      return ">";
    case "completion":
      return "✓";
    case "toolError":
    case "error":
      return "!";
    case "toolUse":
      return "·";
    case "toolOutput":
      return "↳";
    default:
      return "○";
  }
}

function compactBlockText(block: SessionBlock): string {
  return block.content.replace(/\s+/g, " ").trim();
}

function relativeDuration(startTime: string): string {
  const diff = Math.max(0, Date.now() - new Date(startTime).getTime());
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
}

function outputModeLabel(value: string): string {
  switch (value) {
    case "전체":
    case "full":
      return t("output.mode.full");
    case "실시간":
    case "realtime":
      return t("output.mode.realtime");
    case "결과만":
    case "result":
    case "resultOnly":
      return t("output.mode.resultOnly");
    default:
      return value || t("output.mode.full");
  }
}

function permissionModeLabel(value: string): string {
  switch (value) {
    case "acceptEdits":
      return t("perm.acceptEdits");
    case "bypassPermissions":
      return t("perm.bypass");
    case "default":
      return t("perm.default");
    case "auto":
      return t("perm.auto");
    case "plan":
      return t("perm.plan");
    default:
      return value || t("perm.default");
  }
}

function budgetLabel(value: number): string {
  return `$${value.toFixed(2)}`;
}

function terminalViewModeLabel(mode: TerminalViewMode): string {
  switch (mode) {
    case "grid":
      return t("custom.grid");
    case "single":
      return t("custom.single");
    case "git":
      return t("custom.git");
    case "browser":
      return t("custom.browser");
  }
}

function terminalModeIcon(mode: TerminalViewMode): string {
  switch (mode) {
    case "grid":
      return "▦";
    case "single":
      return "▥";
    case "git":
      return "⑂";
    case "browser":
      return "🌐";
  }
}

function sessionProviderLabel(provider: string): string {
  return provider === "codex" ? t("custom.agent.codex") : t("custom.agent.claude");
}

function ConfigChoiceGroup(props: { label: string; children: ReactNode }) {
  return (
    <div className="terminal-choice-group">
      <span className="terminal-choice-label">{props.label}</span>
      <div className="terminal-choice-row">{props.children}</div>
    </div>
  );
}

const effortOptions = [
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium" },
  { value: "high", label: "High" },
  { value: "max", label: "Max" }
] as const;

const outputOptions = [
  { value: "전체", label: "전체" },
  { value: "실시간", label: "실시간" },
  { value: "결과만", label: "결과만" }
] as const;

const permissionOptions = [
  { value: "acceptEdits", label: "수정만 허용" },
  { value: "bypassPermissions", label: "전체 허용" },
  { value: "auto", label: "자동" },
  { value: "default", label: "기본" },
  { value: "plan", label: "계획만" }
] as const;

const singleModelOptions = [
  { value: "opus", label: "Opus", model: "opus", provider: "claude" },
  { value: "sonnet", label: "Sonnet", model: "sonnet", provider: "claude" },
  { value: "haiku", label: "Haiku", model: "haiku", provider: "claude" },
  { value: "codex", label: "Codex", model: "gpt-5.4", provider: "codex" }
] as const;

function singleModelValue(session: SessionSnapshot | null): (typeof singleModelOptions)[number]["value"] {
  if (!session) return "sonnet";
  if (session.provider === "codex") {
    return "codex";
  }
  if (session.selectedModel === "opus" || session.selectedModel === "haiku") {
    return session.selectedModel;
  }
  return "sonnet";
}

function singleModelLabel(value: (typeof singleModelOptions)[number]["value"]): string {
  return singleModelOptions.find((option) => option.value === value)?.label ?? "Sonnet";
}

function effortLabel(value: string): string {
  return effortOptions.find((option) => option.value === value)?.label ?? "Medium";
}

function imageLabel(image: ImageAttachment): string {
  const normalized = image.path.split(/[/\\]/).at(-1)?.trim();
  return normalized || "selected-image";
}

function defaultSecondarySessionId(sessions: SessionSnapshot[], selectedSessionId: string): string | null {
  return sessions.find((session) => session.id !== selectedSessionId)?.id ?? null;
}

function resolveSecondarySession(
  sessions: SessionSnapshot[],
  selectedSessionId: string | null,
  secondarySessionId: string | null
): SessionSnapshot | null {
  if (!selectedSessionId || sessions.length < 2) return null;
  if (secondarySessionId) {
    const matched = sessions.find((session) => session.id === secondarySessionId && session.id !== selectedSessionId);
    if (matched) return matched;
  }
  return sessions.find((session) => session.id !== selectedSessionId) ?? null;
}

function terminalGridTemplate(count: number): string {
  if (count <= 1) return "minmax(0, 1fr)";
  if (count === 2) return "repeat(2, minmax(0, 1fr))";
  if (count <= 4) return "repeat(2, minmax(0, 1fr))";
  return "repeat(3, minmax(0, 1fr))";
}

function SplitSessionPane(props: {
  session: SessionSnapshot;
  sessions: SessionSnapshot[];
  draft: string;
  busy: boolean;
  onDraftChange: (value: string) => void;
  onSubmit: () => Promise<void>;
  onSelectSession: ((sessionId: string) => void) | null;
}) {
  const { session, sessions, draft, busy, onDraftChange, onSubmit, onSelectSession } = props;
  const status = inferStatus(session);
  const recentBlocks = session.blocks.slice(-18);

  return (
    <article className="terminal-split-pane">
      <div className="terminal-split-pane-header">
        <div className="terminal-split-pane-title">
          <span className="worker-dot" style={{ backgroundColor: session.workerColorHex }} />
          <div className="terminal-split-pane-copy">
            <strong>{session.workerName}</strong>
            <span>{session.projectName}</span>
          </div>
        </div>
        {onSelectSession ? (
          <select className="terminal-split-pane-select" value={session.id} onChange={(event) => onSelectSession(event.target.value)}>
            {sessions.map((candidate) => (
              <option key={candidate.id} value={candidate.id}>
                {candidate.workerName} · {candidate.projectName}
              </option>
            ))}
          </select>
        ) : null}
      </div>
      <div className="terminal-split-pane-meta">
        <span>{status.label}</span>
        <span>{relativeDuration(session.startTime)}</span>
        <span>{session.completedPromptCount} prompts</span>
        <span>{session.fileChanges.length} files</span>
      </div>
      <div className="terminal-split-pane-stream">
        {recentBlocks.length === 0 ? <div className="empty-stream">{t("custom.no.output")}</div> : null}
        {recentBlocks.map((block) => (
          <EventBlock key={block.id} block={block} compact />
        ))}
      </div>
      <form
        className="split-pane-composer"
        onSubmit={async (event) => {
          event.preventDefault();
          await onSubmit();
        }}
      >
        <textarea
          value={draft}
          onChange={(event) => onDraftChange(event.target.value)}
          placeholder={t("custom.send.prompt.placeholder")}
          rows={3}
        />
        <button type="submit" className="primary-button" disabled={busy || !draft.trim()}>
          Send
        </button>
      </form>
    </article>
  );
}
