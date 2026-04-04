import { useEffect, useMemo, useState, type CSSProperties, type ReactNode } from "react";
import { t } from "./localizationCatalog";
import type {
  GitActionPayload,
  GitBranchSnapshot,
  GitCommitSnapshot,
  GitPanelSnapshot,
  GitRefSnapshot,
  GitWorktreeChangeSnapshot,
  SessionSnapshot
} from "./types";
import { formatTokens } from "./sessionUtils";

type GitTone = "blue" | "yellow" | "cyan" | "purple" | "green" | "muted" | "orange";

const emptySnapshot: GitPanelSnapshot = {
  projectPath: "",
  isGitRepo: false,
  currentBranch: "",
  upstreamStatus: "",
  branches: [],
  tags: [],
  stashes: [],
  commits: [],
  changes: [],
  lastError: ""
};

export function GitPanelView(props: { selectedSession: SessionSnapshot | null }) {
  const { selectedSession } = props;
  const [snapshot, setSnapshot] = useState<GitPanelSnapshot>(emptySnapshot);
  const [loading, setLoading] = useState(false);
  const [selectedCommitId, setSelectedCommitId] = useState("");
  const [selectedRef, setSelectedRef] = useState("");
  const [sidebarBranchesExpanded, setSidebarBranchesExpanded] = useState(true);
  const [sidebarTagsExpanded, setSidebarTagsExpanded] = useState(false);
  const [sidebarStashesExpanded, setSidebarStashesExpanded] = useState(false);
  const [sidebarRemotesExpanded, setSidebarRemotesExpanded] = useState(false);
  const [searchText, setSearchText] = useState("");
  const [commitMessage, setCommitMessage] = useState("");
  const [actionInput, setActionInput] = useState("");
  const [actionFeedback, setActionFeedback] = useState("");

  async function refreshSnapshot() {
    if (!selectedSession?.projectPath) {
      setSnapshot(emptySnapshot);
      return;
    }
    setLoading(true);
    try {
      const nextSnapshot = await window.doffice.getGitSnapshot(selectedSession.projectPath, selectedRef || undefined);
      setSnapshot(nextSnapshot);
      setSelectedCommitId((current) => (nextSnapshot.commits.some((commit) => commit.id === current) ? current : nextSnapshot.commits[0]?.id || ""));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    let cancelled = false;

    async function load() {
      if (!selectedSession?.projectPath) {
        setSnapshot(emptySnapshot);
        return;
      }
      setLoading(true);
      try {
        const nextSnapshot = await window.doffice.getGitSnapshot(selectedSession.projectPath, selectedRef || undefined);
        if (cancelled) return;
        setSnapshot(nextSnapshot);
        setSelectedCommitId((current) => (nextSnapshot.commits.some((commit) => commit.id === current) ? current : nextSnapshot.commits[0]?.id || ""));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    const interval = window.setInterval(() => {
      void load();
    }, 5000);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, [selectedSession?.projectPath, selectedRef]);

  useEffect(() => {
    setSelectedRef("");
  }, [selectedSession?.projectPath]);

  const displayedCommits = useMemo(() => {
    const query = searchText.trim().toLowerCase();
    if (!query) return snapshot.commits;
    return snapshot.commits.filter((commit) => {
      const haystack = `${commit.shortHash} ${commit.author} ${commit.relativeDate} ${commit.subject} ${commit.refs.map((ref) => ref.name).join(" ")}`.toLowerCase();
      return haystack.includes(query);
    });
  }, [searchText, snapshot.commits]);

  const selectedCommit = displayedCommits.find((commit) => commit.id === selectedCommitId) ?? displayedCommits[0] ?? null;
  const localBranches = snapshot.branches.filter((branch) => !branch.isRemote);
  const remoteBranches = snapshot.branches.filter((branch) => branch.isRemote);
  const remoteNames = useMemo(
    () =>
      Array.from(
        new Set(
          remoteBranches
            .map((branch) => branch.name.replace(/^remotes\//, "").split("/")[0] ?? "")
            .filter(Boolean)
        )
      ),
    [remoteBranches]
  );
  const currentBranchInfo = localBranches.find((branch) => branch.isCurrent) ?? null;
  const graphLaneCount = useMemo(
    () =>
      Math.max(
        1,
        ...displayedCommits.map((commit) =>
          Math.max(commit.lane + 1, commit.topIds.length, commit.bottomIds.length, ...commit.parentLanes.map((lane) => lane + 1))
        )
      ),
    [displayedCommits]
  );
  const graphLaneWidth = 24 + graphLaneCount * 18;
  const effectiveChanges = snapshot.changes.length
    ? snapshot.changes
    : selectedSession?.fileChanges.map((change) => ({
        path: change.path,
        fileName: change.fileName,
        indexStatus: " ",
        workTreeStatus: "M",
        statusLabel: change.action.toLowerCase(),
        staged: false
      })) ?? [];
  const stagedChanges = effectiveChanges.filter((change) => change.staged);
  const unstagedChanges = effectiveChanges.filter((change) => !change.staged);
  const branchSummaryItems = [
    currentBranchInfo?.ahead ? { id: "push", icon: "↑", value: currentBranchInfo.ahead, tone: "green" as const } : null,
    currentBranchInfo?.behind ? { id: "pull", icon: "↓", value: currentBranchInfo.behind, tone: "green" as const } : null
  ].filter(Boolean) as Array<{ id: string; icon: string; value: number; tone: "green" }>;
  const statItems = [
    { id: "commits", icon: "◷", value: snapshot.commits.length, tone: "muted" as const },
    { id: "tags", icon: "🏷", value: snapshot.tags.length, tone: "yellow" as const },
    { id: "stashes", icon: "✉", value: snapshot.stashes.length, tone: "cyan" as const },
    { id: "remotes", icon: "☁", value: remoteNames.length, tone: "purple" as const }
  ];

  async function runGitAction(action: GitActionPayload["action"], input?: string) {
    if (!selectedSession?.projectPath) return;
    const result = await window.doffice.executeGitAction({ projectPath: selectedSession.projectPath, action, input });
    setActionFeedback(result.message);
    if (result.ok) {
      if (action === "commit" || action === "amend") {
        setCommitMessage("");
      }
      if (action === "branch" || action === "stash" || action === "merge") {
        setActionInput("");
      }
      await refreshSnapshot();
    }
  }

  if (!selectedSession) {
    return <div className="git-panel empty-stream">{t("custom.no.session.selected")}</div>;
  }

  return (
    <section className="git-client">
      <header className="git-client-toolbar">
        <div className="git-toolbar-left">
          <div className="git-branch-pill">
            <span className="git-section-icon tone-green">⑂</span>
            <span className="git-branch-pill-label">{selectedRef || snapshot.currentBranch || selectedSession.gitInfo.branch || t("custom.no.branch")}</span>
          </div>
          <div className="git-toolbar-stats">
            {branchSummaryItems.map((item) => (
              <StatPill key={item.id} icon={item.icon} value={item.value} tone={item.tone} />
            ))}
            {statItems.map((item) => (
              <StatPill key={item.id} icon={item.icon} value={item.value} tone={item.tone} />
            ))}
          </div>
        </div>
        <div className="git-toolbar-right">
          <div className="git-toolbar-actions">
            <button type="button" className="mini-action-button success git-action-button tone-green" onClick={() => void runGitAction("commit", commitMessage)} disabled={!commitMessage.trim()}>
              <span className="git-action-icon">✓</span>
              커밋
            </button>
            <button type="button" className="mini-action-button git-action-button tone-blue" onClick={() => void runGitAction("push")}>
              <span className="git-action-icon">↑</span>
              푸시
            </button>
            <button type="button" className="mini-action-button git-action-button tone-cyan" onClick={() => void runGitAction("pull")}>
              <span className="git-action-icon">↓</span>
              풀
            </button>
          </div>
          <span className="git-toolbar-meta">{formatTokens(selectedSession.tokensUsed)} {t("custom.tokens.suffix")}</span>
          <button type="button" className="chrome-icon-button" onClick={() => void refreshSnapshot()}>
            ↻
          </button>
        </div>
      </header>

      {!snapshot.isGitRepo ? (
        <div className="git-panel empty-stream">{snapshot.lastError || t("custom.na")}</div>
      ) : (
        <div className="git-client-layout">
          <aside className="git-client-sidebar">
            <div className="git-sidebar-scroll">
              <SidebarSection
                title={t("git.section.branches")}
                icon="⑂"
                tone="blue"
                count={localBranches.length}
                expanded={sidebarBranchesExpanded}
                onToggle={() => setSidebarBranchesExpanded((current) => !current)}
              >
                <button type="button" className={`git-sidebar-row ${selectedRef === "" ? "is-selected" : ""}`} onClick={() => setSelectedRef("")}>
                  <span className="git-sidebar-item-main">
                    <span className="git-sidebar-row-icon tone-muted">◷</span>
                    <span>전체 히스토리</span>
                  </span>
                  <span className="git-sidebar-hash">ALL</span>
                </button>
                {localBranches.map((branch) => (
                  <BranchRow key={branch.name} branch={branch} isSelected={selectedRef === branch.name} onSelect={setSelectedRef} />
                ))}
              </SidebarSection>

              <SidebarSection
                title={t("git.section.tags")}
                icon="🏷"
                tone="yellow"
                count={snapshot.tags.length}
                expanded={sidebarTagsExpanded}
                onToggle={() => setSidebarTagsExpanded((current) => !current)}
              >
                {snapshot.tags.slice(0, 20).map((tag) => (
                  <button key={tag} type="button" className={`git-sidebar-row ${selectedRef === tag ? "is-selected" : ""}`} onClick={() => setSelectedRef(tag)}>
                    <span className="git-sidebar-item-main">
                      <span className="git-sidebar-row-icon tone-yellow">🏷</span>
                      <span>{tag}</span>
                    </span>
                    <span className="git-sidebar-hash tone-yellow">tag</span>
                  </button>
                ))}
              </SidebarSection>

              <SidebarSection
                title={t("git.section.stashes")}
                icon="✉"
                tone="cyan"
                count={snapshot.stashes.length}
                expanded={sidebarStashesExpanded}
                onToggle={() => setSidebarStashesExpanded((current) => !current)}
              >
                {snapshot.stashes.map((stash) => (
                  <div key={stash.label} className="git-stash-row">
                    <div className="git-sidebar-item-main">
                      <span className="git-sidebar-row-icon tone-cyan">✉</span>
                      <strong>{stash.label}</strong>
                    </div>
                    <span>{stash.message}</span>
                    <span>{stash.relativeDate}</span>
                  </div>
                ))}
              </SidebarSection>

              <SidebarSection
                title={t("git.section.remotes")}
                icon="☁"
                tone="purple"
                count={remoteNames.length}
                expanded={sidebarRemotesExpanded}
                onToggle={() => setSidebarRemotesExpanded((current) => !current)}
              >
                {remoteNames.map((remote) => (
                  <div key={remote} className="git-sidebar-row git-sidebar-remote-row">
                    <span className="git-sidebar-item-main">
                      <span className="git-sidebar-row-icon tone-purple">☁</span>
                      <span>{remote}</span>
                    </span>
                    <span className="git-sidebar-hash tone-purple">{remoteBranches.filter((branch) => normalizedRemoteName(branch.name) === remote).length}</span>
                  </div>
                ))}
              </SidebarSection>
            </div>
            <div className="git-sidebar-footer">
              <button type="button" className="mini-action-button success git-stage-all-button" onClick={() => void runGitAction("stageAll")}>
                <span className="git-action-icon">＋</span>
                전체 스테이지
              </button>
            </div>
          </aside>

          <main className="git-client-graph">
            <div className="git-graph-search">
              <input value={searchText} onChange={(event) => setSearchText(event.target.value)} placeholder={t("git.search.placeholder")} />
              {loading ? <span className="git-graph-loading">{t("main.refresh")}</span> : null}
            </div>
            <div className="git-graph-list">
              {displayedCommits.map((commit) => (
                <button
                  key={commit.id}
                  type="button"
                  className={`git-commit-row ${selectedCommit?.id === commit.id ? "is-selected" : ""}`}
                  style={{ ["--git-graph-width" as string]: `${graphLaneWidth}px` } as CSSProperties}
                  onClick={() => setSelectedCommitId(commit.id)}
                >
                  <GraphLaneView commit={commit} width={graphLaneWidth} />
                  <div className="git-commit-main">
                    <div className="git-commit-title-row">
                      <strong>{commit.subject}</strong>
                      <span>{commit.relativeDate}</span>
                    </div>
                    <div className="git-commit-meta-row">
                      <span>{commit.shortHash}</span>
                      <span>{commit.author}</span>
                      {commit.refs.map((ref) => (
                        <RefPill key={`${commit.id}-${ref.type}-${ref.name}`} refItem={ref} />
                      ))}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </main>

          <aside className="git-client-detail">
            <div className="git-detail-card">
              <div className="panel-header">
                <span>{t("git.section.commit.detail")}</span>
              </div>
              {selectedCommit ? (
                <div className="git-detail-copy">
                  <strong>{selectedCommit.subject}</strong>
                  <span>{selectedCommit.shortHash} · {selectedCommit.author}</span>
                  <span>{selectedCommit.relativeDate}</span>
                  <div className="git-detail-ref-row">
                    {selectedCommit.refs.length === 0 ? <span className="git-ref-pill muted">HEAD</span> : null}
                    {selectedCommit.refs.map((ref) => (
                      <RefPill key={`${selectedCommit.id}-detail-${ref.type}-${ref.name}`} refItem={ref} />
                    ))}
                  </div>
                </div>
              ) : (
                <div className="leaderboard-empty">{t("custom.na")}</div>
              )}
            </div>

            <div className="git-detail-card grow">
              <div className="panel-header">
                <span>작업 디렉토리</span>
                <strong>{effectiveChanges.length}</strong>
              </div>
              <div className="git-working-dir">
                <div className="git-working-column">
                  <div className="git-working-column-header">
                    <span>Staged</span>
                    <strong>{stagedChanges.length}</strong>
                  </div>
                  <div className="git-change-list git-change-list-rich">
                    {stagedChanges.length === 0 ? <div className="leaderboard-empty">No staged files</div> : null}
                    {stagedChanges.map((change) => (
                      <ChangeRow key={`staged-${change.path}-${change.statusLabel}`} change={change} />
                    ))}
                  </div>
                </div>
                <div className="git-working-column">
                  <div className="git-working-column-header">
                    <span>Unstaged</span>
                    <strong>{unstagedChanges.length}</strong>
                  </div>
                  <div className="git-change-list git-change-list-rich">
                    {unstagedChanges.length === 0 ? <div className="leaderboard-empty">No unstaged files</div> : null}
                    {unstagedChanges.map((change) => (
                      <ChangeRow key={`unstaged-${change.path}-${change.statusLabel}`} change={change} />
                    ))}
                  </div>
                </div>
              </div>
            </div>

            <div className="git-detail-card">
              <div className="panel-header">
                <span>커밋</span>
              </div>
              <div className="git-commit-form">
                <textarea value={commitMessage} onChange={(event) => setCommitMessage(event.target.value)} rows={3} placeholder="커밋 메시지 입력" />
                <div className="settings-action-row">
                  <button type="button" className="mini-action-button success git-action-button tone-green" onClick={() => void runGitAction("commit", commitMessage)} disabled={!commitMessage.trim()}>
                    <span className="git-action-icon">✓</span>
                    Commit
                  </button>
                  <button type="button" className="mini-action-button" onClick={() => void runGitAction("amend", commitMessage)} disabled={!commitMessage.trim()}>
                    Amend
                  </button>
                </div>
              </div>
            </div>

            <div className="git-detail-card">
              <div className="panel-header">
                <span><span className="git-section-icon tone-muted">⚡</span>빠른 명령</span>
              </div>
              <div className="git-quick-actions">
                <button type="button" className="mini-action-button git-action-button tone-green" onClick={() => void runGitAction("commit", commitMessage)} disabled={!commitMessage.trim()}>
                  <span className="git-action-icon">✓</span>
                  커밋
                </button>
                <button type="button" className="mini-action-button git-action-button tone-blue" onClick={() => void runGitAction("push")}>
                  <span className="git-action-icon">↑</span>
                  푸시
                </button>
                <button type="button" className="mini-action-button git-action-button tone-cyan" onClick={() => void runGitAction("pull")}>
                  <span className="git-action-icon">↓</span>
                  풀
                </button>
                <button type="button" className="mini-action-button git-action-button tone-blue" onClick={() => void runGitAction("branch", actionInput)}>
                  <span className="git-action-icon">⑂</span>
                  브런치
                </button>
                <button type="button" className="mini-action-button git-action-button tone-yellow" onClick={() => void runGitAction("stash", actionInput)}>
                  <span className="git-action-icon">✉</span>
                  스태시
                </button>
                <button type="button" className="mini-action-button git-action-button tone-orange" onClick={() => void runGitAction("merge", actionInput)}>
                  <span className="git-action-icon">⋈</span>
                  병합
                </button>
              </div>
              <div className="git-inline-action">
                <input value={actionInput} onChange={(event) => setActionInput(event.target.value)} placeholder="브런치 / 스태시 / 병합 대상" />
              </div>
              <div className="git-quick-status-bar">
                <div className="git-upstream-summary">
                  <StatPill icon="↑" value={currentBranchInfo?.ahead ?? 0} tone="blue" />
                  <StatPill icon="↓" value={currentBranchInfo?.behind ?? 0} tone="cyan" />
                </div>
                <span className="git-toolbar-meta">{actionFeedback || snapshot.upstreamStatus || " "}</span>
              </div>
            </div>
          </aside>
        </div>
      )}
    </section>
  );
}

function StatPill(props: { icon: string; value: number; tone: GitTone }) {
  const { icon, value, tone } = props;
  return (
    <span className={`git-toolbar-stat-pill tone-${tone}`}>
      <span className="git-toolbar-stat-icon">{icon}</span>
      <strong>{value}</strong>
    </span>
  );
}

function SidebarSection(props: {
  title: string;
  icon: string;
  tone: GitTone;
  count: number;
  expanded: boolean;
  onToggle: () => void;
  children: ReactNode;
}) {
  const { title, icon, tone, count, expanded, onToggle, children } = props;
  return (
    <section className="git-sidebar-section">
      <button type="button" className="git-sidebar-section-header" onClick={onToggle}>
        <span>{expanded ? "▾" : "▸"}</span>
        <span className={`git-section-icon tone-${tone}`}>{icon}</span>
        <strong>{title}</strong>
        <span className={`git-sidebar-count tone-${tone}`}>{count}</span>
      </button>
      {expanded ? <div className="git-sidebar-section-body">{children}</div> : null}
    </section>
  );
}

function BranchRow(props: { branch: GitBranchSnapshot; isSelected: boolean; onSelect: (ref: string) => void }) {
  const { branch, isSelected, onSelect } = props;
  return (
    <button type="button" className={`git-sidebar-row ${branch.isCurrent ? "is-current" : ""} ${isSelected ? "is-selected" : ""}`} onClick={() => onSelect(branch.name)}>
      <span className="git-sidebar-item-main">
        <span className="git-sidebar-row-icon tone-blue">⑂</span>
        <span>{branch.name.replace(/^remotes\//, "")}</span>
      </span>
      <span className="git-sidebar-meta-group">
        {branch.ahead > 0 ? <span className="git-sidebar-hash tone-green">↑{branch.ahead}</span> : null}
        {branch.behind > 0 ? <span className="git-sidebar-hash tone-green">↓{branch.behind}</span> : null}
        {branch.shortHash ? <span className="git-sidebar-hash">{branch.shortHash}</span> : null}
      </span>
    </button>
  );
}

function GraphLaneView(props: { commit: GitCommitSnapshot; width: number }) {
  const { commit, width } = props;
  const palette = ["#1fd6c3", "#38a6ff", "#d657ff", "#ffcb57", "#52db95", "#ff8a5b", "#8f76ff", "#70f0ff"];
  const colWidth = 18;
  const midY = 20;
  const height = 40;
  const nodeX = 12 + commit.lane * colWidth;
  const hasTag = commit.refs.some((ref) => ref.type === "tag");
  const isMerge = commit.parentIds.length > 1;

  return (
    <svg className="git-commit-graphline" width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
      {commit.topIds.map((laneId, topIndex) => {
        if (laneId === commit.id) {
          if (!commit.hasIncoming) return null;
          const x = 12 + topIndex * colWidth;
          return <line key={`incoming-${commit.id}-${topIndex}`} x1={x} y1={0} x2={nodeX} y2={midY} stroke={palette[topIndex % palette.length]} strokeOpacity="0.78" strokeWidth="1.8" strokeLinecap="round" />;
        }

        const bottomIndex = commit.bottomIds.indexOf(laneId);
        const startX = 12 + topIndex * colWidth;
        const colorIndex = bottomIndex === -1 ? topIndex : bottomIndex;
        const color = palette[colorIndex % palette.length];
        if (bottomIndex === -1) {
          return <line key={`end-${commit.id}-${laneId}-${topIndex}`} x1={startX} y1={0} x2={startX} y2={midY} stroke={color} strokeOpacity="0.34" strokeWidth="1.6" strokeLinecap="round" />;
        }

        const endX = 12 + bottomIndex * colWidth;
        if (topIndex === bottomIndex) {
          return <line key={`carry-${commit.id}-${laneId}-${topIndex}`} x1={startX} y1={0} x2={endX} y2={height} stroke={color} strokeOpacity="0.34" strokeWidth="1.6" strokeLinecap="round" />;
        }

        return <path key={`carry-${commit.id}-${laneId}-${topIndex}-${bottomIndex}`} d={`M ${startX} 0 C ${startX} 12, ${endX} 28, ${endX} ${height}`} fill="none" stroke={color} strokeOpacity="0.34" strokeWidth="1.6" strokeLinecap="round" />;
      })}
      {commit.parentLanes.map((parentLane, index) => {
        const targetX = 12 + parentLane * colWidth;
        const color = palette[parentLane % palette.length];
        if (index === 0) {
          if (parentLane === commit.lane) {
            return <line key={`parent-${commit.id}-primary`} x1={nodeX} y1={midY} x2={targetX} y2={height} stroke={color} strokeOpacity="0.78" strokeWidth="1.8" strokeLinecap="round" />;
          }
          return <path key={`parent-${commit.id}-primary`} d={`M ${nodeX} ${midY} C ${nodeX} ${midY + 10}, ${targetX} ${height - 10}, ${targetX} ${height}`} fill="none" stroke={color} strokeOpacity="0.78" strokeWidth="1.8" strokeLinecap="round" />;
        }
        return <path key={`merge-${commit.id}-${index}-${parentLane}`} d={`M ${nodeX} ${midY} C ${nodeX} ${midY + 10}, ${targetX} ${height - 10}, ${targetX} ${height}`} fill="none" stroke={color} strokeOpacity="0.52" strokeWidth="1.7" strokeLinecap="round" />;
      })}
      {hasTag ? (
        <rect x={nodeX - 4.5} y={midY - 4.5} width={9} height={9} fill="#ffcb57" stroke="#ffdf93" strokeWidth="1.1" transform={`rotate(45 ${nodeX} ${midY})`} rx="1.2" />
      ) : (
        <>
          <circle cx={nodeX} cy={midY} r={4.5} fill={palette[commit.lane % palette.length]} />
          {isMerge ? <circle cx={nodeX} cy={midY} r={7.4} fill="none" stroke={palette[commit.lane % palette.length]} strokeWidth="1.4" /> : null}
        </>
      )}
    </svg>
  );
}

function RefPill(props: { refItem: GitRefSnapshot }) {
  const { refItem } = props;
  return <span className={`git-ref-pill tone-${refItem.type}`}>{refItem.name}</span>;
}

function ChangeRow(props: { change: GitWorktreeChangeSnapshot }) {
  const { change } = props;
  return (
    <div className="git-change-row git-change-row-rich">
      <div className="git-change-status-pill">{change.statusLabel}</div>
      <div className="git-change-copy">
        <strong>{change.fileName}</strong>
        <span>{change.path}</span>
      </div>
      {change.staged ? <div className="git-staged-pill">staged</div> : null}
    </div>
  );
}

function normalizedRemoteName(branchName: string): string {
  return branchName.replace(/^remotes\//, "").split("/")[0] ?? "";
}
