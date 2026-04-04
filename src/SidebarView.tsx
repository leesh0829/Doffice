import { useState, type ReactNode } from "react";
import type { SessionSnapshot } from "./types";
import type { ProjectGroup, SessionStatusFilter, SidebarSortOption } from "./uiModel";
import { t } from "./localizationCatalog";
import type { NewSessionProjectRecord } from "./newSessionPreferences";
import { formatTokens, inferPendingApproval, inferStatus } from "./sessionUtils";

interface SidebarViewProps {
  groupedSessions: ProjectGroup[];
  selectedSession: SessionSnapshot | null;
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
  totals: {
    active: number;
    processing: number;
    attention: number;
    completed: number;
    tokens: number;
  };
  workspaceCounts: {
    hiredCharacters: number;
    totalCharacters: number;
    enabledAccessories: number;
    totalAccessories: number;
    reports: number;
    unlockedAchievements: number;
    totalAchievements: number;
    level: number;
    levelTitle: string;
    totalXP: number;
    progressPercent: number;
  };
  tokenLeaders: SessionSnapshot[];
  favoriteProjects: NewSessionProjectRecord[];
  recentProjects: NewSessionProjectRecord[];
  selectSession: (sessionId: string) => void;
  openNewSession: () => void;
  quickLaunchProject: (project: NewSessionProjectRecord) => void;
  openSettings: () => void;
  openCharacters: () => void;
  openAccessories: () => void;
  openReports: () => void;
  openAchievements: () => void;
}

const filters: SessionStatusFilter[] = ["all", "active", "processing", "completed", "attention"];
const sortOptions: SidebarSortOption[] = ["recent", "name", "tokens", "status"];

const filterIcons: Record<Exclude<SessionStatusFilter, "all">, string> = {
  active: "⚡",
  processing: "⚙",
  completed: "✓",
  attention: "▲"
};

function renderFilterIcon(filter: SessionStatusFilter): ReactNode {
  if (filter === "all") {
    return (
      <span className="filter-chip-grid-icon" aria-hidden="true">
        <span />
        <span />
        <span />
        <span />
      </span>
    );
  }

  return <span className="filter-chip-icon">{filterIcons[filter]}</span>;
}

function filterLabel(filter: SessionStatusFilter): string {
  switch (filter) {
    case "all":
      return t("status.all");
    case "active":
      return t("status.active");
    case "processing":
      return t("status.processing");
    case "completed":
      return t("status.completed");
    case "attention":
      return t("status.attention");
  }
}

function sortLabel(option: SidebarSortOption): string {
  switch (option) {
    case "recent":
      return t("sidebar.sort.recent");
    case "name":
      return t("sidebar.sort.name");
    case "tokens":
      return t("sidebar.sort.tokens");
    case "status":
      return t("sidebar.sort.status");
  }
}

export function SidebarView(props: SidebarViewProps) {
  const {
    groupedSessions,
    selectedSession,
    searchQuery,
    setSearchQuery,
    statusFilter,
    setStatusFilter,
    sortOption,
    setSortOption,
    filterCounts,
    totals,
    workspaceCounts,
    tokenLeaders,
    favoriteProjects,
    selectSession,
    openNewSession,
    quickLaunchProject,
    openSettings,
    openCharacters,
    openAccessories,
    openReports,
    openAchievements
  } = props;
  const [levelExpanded, setLevelExpanded] = useState(true);
  const [usageExpanded, setUsageExpanded] = useState(true);
  const [tokensExpanded, setTokensExpanded] = useState(true);
  const visibleSessions = groupedSessions.flatMap((group) => group.tabs);
  const usageLeaders = [...visibleSessions]
    .sort((lhs, rhs) => rhs.completedPromptCount - lhs.completedPromptCount || rhs.tokensUsed - lhs.tokensUsed)
    .slice(0, 6);
  const maxUsage = Math.max(1, ...usageLeaders.map((session) => session.completedPromptCount));
  const maxLeaderTokens = Math.max(1, ...tokenLeaders.map((session) => session.tokensUsed));

  return (
    <aside className="sidebar">
      <div className="sidebar-section sidebar-header-row">
        <div className="sidebar-title">
          <span className="sidebar-title-icon">▦</span>
          <span>{t("sessions")}</span>
        </div>
        <span className="sidebar-count">{groupedSessions.reduce((sum, group) => sum + group.tabs.length, 0)}</span>
      </div>

      <button className="new-session-card" onClick={openNewSession}>
        <div className="new-session-title"><span className="new-session-plus-icon">＋</span>{t("session.new")}</div>
        <div className="new-session-body">{t("session.project")}</div>
      </button>
      <div className="sidebar-scroll">
        {favoriteProjects.length > 0 ? (
          <section className="sidebar-panel compact">
            <div className="panel-header">
              <span>{t("custom.favorites")}</span>
            </div>
            <div className="leaderboard">
              {favoriteProjects.map((project) => (
                <button key={project.path} className="history-row" onClick={() => quickLaunchProject(project)}>
                  <div className="history-row-main">
                    <strong>{project.name}</strong>
                    <span className="path-ellipsis">{project.path}</span>
                  </div>
                  <span className="history-row-time">★</span>
                </button>
              ))}
            </div>
          </section>
        ) : null}

        <section className="sidebar-panel">
          <div className="panel-header sidebar-explorer-header">
            <span>{t("custom.session.explorer")}</span>
          </div>
          <div className="sidebar-explorer-toolbar">
            <div className="sidebar-search-shell sidebar-search-shell-compact">
              <span className="sidebar-inline-icon">⌕</span>
              <input
                className="sidebar-search"
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                placeholder={t("custom.search.project.placeholder")}
              />
              {searchQuery ? (
                <button type="button" className="sidebar-clear-button" onClick={() => setSearchQuery("")} aria-label={t("cancel")}>
                  ✕
                </button>
              ) : null}
            </div>
            <label className="sidebar-sort-inline sidebar-sort-inline-compact">
              <span className="sidebar-inline-icon">⇅</span>
              <select value={sortOption} onChange={(event) => setSortOption(event.target.value as SidebarSortOption)}>
                {sortOptions.map((option) => (
                  <option key={option} value={option}>
                    {sortLabel(option)}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <div className="filter-chip-row">
            {filters.map((filter) => (
              <button
                key={filter}
                type="button"
                className={`filter-chip ${statusFilter === filter ? "is-active" : ""} ${filterCounts[filter] === 0 && statusFilter !== filter ? "is-empty" : ""}`}
                onClick={() => setStatusFilter(filter)}
                title={filterLabel(filter)}
              >
                {renderFilterIcon(filter)}
                <span className="filter-chip-count">{filterCounts[filter]}</span>
              </button>
            ))}
          </div>
        </section>

        {groupedSessions.length === 0 ? (
          <div className="empty-state-card">
            <strong>{t("custom.no.sessions")}</strong>
            <span>{t("custom.clear.filter")}</span>
          </div>
        ) : (
          groupedSessions.map((group) =>
            group.tabs.length === 1 ? (
              <SessionCard
                key={group.tabs[0].id}
                session={group.tabs[0]}
                isSelected={selectedSession?.id === group.tabs[0].id}
                onSelect={selectSession}
              />
            ) : (
              <SessionGroupCard
                key={group.id}
                group={group}
                selectedId={selectedSession?.id ?? ""}
                onSelect={selectSession}
              />
            )
          )
        )}
        <section className="sidebar-panel compact collapsible-panel">
          <button type="button" className="panel-header panel-toggle" onClick={() => setLevelExpanded((current) => !current)}>
            <span className="sidebar-panel-title"><span className="sidebar-panel-icon tone-gold">★</span>{t("custom.level")}</span>
            {!levelExpanded ? <span className="sidebar-panel-meta">{`${workspaceCounts.totalXP.toLocaleString("ko-KR")} XP`}</span> : null}
          </button>
          {levelExpanded ? (
            <div className="level-card">
              <div className="level-badge">
                <span>{`Lv.${workspaceCounts.level} ${workspaceCounts.levelTitle}`}</span>
                <strong>{`${workspaceCounts.totalXP.toLocaleString("ko-KR")} XP`}</strong>
              </div>
              <div className="level-progress-line">
                <span style={{ width: `${workspaceCounts.progressPercent}%` }} />
              </div>
            </div>
          ) : null}
        </section>

        <section className="sidebar-panel compact collapsible-panel">
          <button type="button" className="panel-header panel-toggle" onClick={() => setUsageExpanded((current) => !current)}>
            <span className="sidebar-panel-title"><span className="sidebar-panel-icon tone-sky">▥</span>{t("custom.usage")}</span>
            <span>{usageExpanded ? "⌄" : "›"}</span>
          </button>
          {usageExpanded ? (
            <div className="leaderboard sidebar-usage-list">
              {usageLeaders.length === 0 ? <span className="leaderboard-empty">{t("custom.no.active.sessions")}</span> : null}
              {usageLeaders.map((session) => (
                <button key={session.id} className="leader-row stat-leader-row" onClick={() => selectSession(session.id)}>
                  <span className="stat-leader-accent" style={{ backgroundColor: session.workerColorHex }} />
                  <span className="leader-name">{session.workerName}</span>
                  <span className="leader-score">{session.completedPromptCount}</span>
                  <span className="token-leader-bar">
                    <span style={{ width: `${(session.completedPromptCount / maxUsage) * 100}%` }} />
                  </span>
                </button>
              ))}
            </div>
          ) : null}
        </section>

        <section className="sidebar-panel compact collapsible-panel">
          <button type="button" className="panel-header panel-toggle" onClick={() => setTokensExpanded((current) => !current)}>
            <span className="sidebar-panel-title"><span className="sidebar-panel-icon tone-gold">⚡</span>TOKENS</span>
            <span>{tokensExpanded ? "⌄" : "›"}</span>
          </button>
          {tokensExpanded ? (
            <>
              <div className="leaderboard">
                {tokenLeaders.length === 0 ? <span className="leaderboard-empty">{t("custom.no.token.usage")}</span> : null}
                {tokenLeaders.map((session) => (
                  <button key={session.id} className="leader-row stat-leader-row" onClick={() => selectSession(session.id)}>
                    <span className="stat-leader-accent" style={{ backgroundColor: session.workerColorHex }} />
                    <span className="leader-name">{session.workerName}</span>
                    <span className="leader-score">{formatTokens(session.tokensUsed)}</span>
                    <span className="token-leader-bar">
                      <span style={{ width: `${(session.tokensUsed / maxLeaderTokens) * 100}%` }} />
                    </span>
                  </button>
                ))}
              </div>
            </>
          ) : null}
        </section>

        <section className="sidebar-action-stack">
          <button type="button" className="sidebar-action-button" onClick={openCharacters}>
            <span className="sidebar-action-label"><span className="sidebar-action-icon tone-blue">👥</span><span>{t("custom.characters")}</span></span>
            <strong className="sidebar-action-badge tone-blue">{`${workspaceCounts.hiredCharacters}/${workspaceCounts.totalCharacters}`}</strong>
          </button>
          <button type="button" className="sidebar-action-button" onClick={openAccessories}>
            <span className="sidebar-action-label"><span className="sidebar-action-icon tone-purple">🛋</span><span>{t("custom.accessories")}</span></span>
            <strong>{`${workspaceCounts.enabledAccessories}/${workspaceCounts.totalAccessories}`}</strong>
          </button>
          <button type="button" className="sidebar-action-button" onClick={openReports}>
            <span className="sidebar-action-label"><span className="sidebar-action-icon tone-sky">📄</span><span>{t("custom.reports")}</span></span>
            <strong>{workspaceCounts.reports}</strong>
          </button>
          <button type="button" className="sidebar-action-button" onClick={openAchievements}>
            <span className="sidebar-action-label"><span className="sidebar-action-icon tone-gold">🏆</span><span>{t("custom.achievements")}</span></span>
            <strong>{`${workspaceCounts.unlockedAchievements}/${workspaceCounts.totalAchievements}`}</strong>
          </button>
          <button type="button" className="sidebar-action-button tone-accent" onClick={openSettings}>
            <span className="sidebar-action-label"><span className="sidebar-action-icon">⚙</span><span>{t("custom.settings")}</span></span>
            <strong>열기</strong>
          </button>
        </section>
      </div>
    </aside>
  );
}

function SessionCard(props: { session: SessionSnapshot; isSelected: boolean; onSelect: (sessionId: string) => void }) {
  const { session, isSelected, onSelect } = props;
  const status = inferStatus(session);
  const approval = inferPendingApproval(session);
  const changedFiles = session.gitInfo.changedFiles || session.fileChanges.length;
  const online = session.isRunning || session.isProcessing || !session.isCompleted;

  return (
    <button
      className={`session-card ${isSelected ? "is-selected" : ""}`}
      onClick={() => onSelect(session.id)}
      onContextMenu={(event) => {
        event.preventDefault();
        void window.doffice.showSessionContextMenu(session.id);
      }}
    >
      <div className="session-card-head">
        <div className="session-project-row">
          <span className={`session-online-dot ${online ? "is-online" : "is-offline"}`} />
          <strong className="path-ellipsis">{session.projectName}</strong>
        </div>
      </div>
      <div className="session-card-meta">
        <span className="session-worker-strip" style={{ backgroundColor: session.workerColorHex }} />
        <span className="path-ellipsis">{session.workerName}</span>
        <span>{approval ? t("custom.approval.needed") : status.label}</span>
      </div>
      <div className="session-card-foot">
        <span className="path-ellipsis">{session.branch || t("custom.no.branch")}</span>
        <span>{`+ ${changedFiles}`}</span>
      </div>
    </button>
  );
}

function SessionGroupCard(props: { group: ProjectGroup; selectedId: string; onSelect: (sessionId: string) => void }) {
  const { group, selectedId, onSelect } = props;
  const hasApproval = group.tabs.some((session) => Boolean(inferPendingApproval(session)));
  return (
    <div className={`session-group-card ${group.hasActiveTab ? "is-selected" : ""}`}>
      <div className="session-group-head">
        <strong>{group.projectName}</strong>
        <div className="session-group-head-meta">
          {hasApproval ? <span className="session-group-pill tone-warning">{t("custom.approval")}</span> : null}
          <span>{group.tabs.length}</span>
        </div>
      </div>
      <div className="session-group-list">
        {group.tabs.map((session) => {
          const status = inferStatus(session);
          const approval = inferPendingApproval(session);
          return (
            <button
              key={session.id}
              className={`session-group-row ${selectedId === session.id ? "is-selected" : ""}`}
              onClick={() => onSelect(session.id)}
              onContextMenu={(event) => {
                event.preventDefault();
                void window.doffice.showSessionContextMenu(session.id);
              }}
            >
              <span className="worker-dot" style={{ backgroundColor: session.workerColorHex }} />
              <span className="session-group-name">{session.workerName}</span>
              <span className="session-group-status" style={{ color: approval ? "#f5a623" : status.tint }}>
                {approval ? t("custom.approval") : status.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
