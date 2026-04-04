import { useEffect, useMemo, useState } from "react";
import { t } from "./localizationCatalog";
import { Theme } from "./Theme";
import { formatTokens, inferPendingApproval, inferStatus, relativeTime, sessionActivitySummary } from "./sessionUtils";
import type { AppViewMode } from "./uiModel";
import type { SessionSnapshot } from "./types";

interface ActionCenterViewProps {
  sessions: SessionSnapshot[];
  onClose: () => void;
  onSelectSession: (sessionId: string) => void;
}

interface ActionSectionDescriptor {
  key: string;
  title: string;
  symbol: string;
  tint: string;
  sessions: SessionSnapshot[];
  detail: (session: SessionSnapshot) => string;
}

export interface SessionNotificationItem {
  id: string;
  sessionId: string;
  title: string;
  detail: string;
  tint: string;
  glyph: string;
}

export function ActionCenterView(props: ActionCenterViewProps) {
  const { sessions, onClose, onSelectSession } = props;

  const sections = useMemo<ActionSectionDescriptor[]>(() => {
    const approvals = sessions.filter((session) => Boolean(inferPendingApproval(session)));
    const attention = sessions.filter((session) => inferStatus(session).category === "attention");
    const processing = sessions.filter((session) => inferStatus(session).category === "processing");
    const completed = sessions.filter((session) => inferStatus(session).category === "completed");

    return [
      {
        key: "approval",
        title: t("overlay.pending.approval"),
        symbol: "◌",
        tint: Theme.orange,
        sessions: approvals,
        detail: (session: SessionSnapshot) => inferPendingApproval(session) ?? t("custom.pending.approval.waiting")
      },
      {
        key: "attention",
        title: t("overlay.needs.attention"),
        symbol: "▲",
        tint: Theme.red,
        sessions: attention,
        detail: (session: SessionSnapshot) => sessionActivitySummary(session)
      },
      {
        key: "processing",
        title: t("overlay.in.progress"),
        symbol: "◎",
        tint: Theme.accent,
        sessions: processing,
        detail: (session: SessionSnapshot) => sessionActivitySummary(session)
      },
      {
        key: "completed",
        title: t("overlay.completed"),
        symbol: "●",
        tint: Theme.green,
        sessions: completed,
        detail: (session: SessionSnapshot) => sessionActivitySummary(session)
      }
    ].filter((section) => section.sessions.length > 0);
  }, [sessions]);

  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="overlay-panel action-center-panel" onClick={(event) => event.stopPropagation()}>
        <div className="overlay-header">
          <div className="overlay-title-block">
            <span className="overlay-glyph" style={{ color: Theme.orange }}>
              ●
            </span>
            <div>
              <strong>{t("overlay.action.center")}</strong>
              <span>{t("overlay.action.center.subtitle")}</span>
            </div>
          </div>
          <button className="chrome-icon-button" onClick={onClose}>
            ✕
          </button>
        </div>

        <div className="overlay-scroll">
          {sections.length === 0 ? (
            <div className="overlay-empty">
              <div className="overlay-empty-icon">✓</div>
              <strong>{t("overlay.all.normal")}</strong>
              <span>{t("custom.action.center.empty.detail")}</span>
            </div>
          ) : (
            sections.map((section) => (
              <section key={section.key} className="action-section">
                <div className="action-section-header">
                  <div className="action-section-title">
                    <span style={{ color: section.tint }}>{section.symbol}</span>
                    <strong>{section.title}</strong>
                  </div>
                  <span className="action-section-count" style={{ color: section.tint, borderColor: `${section.tint}33` }}>
                    {section.sessions.length}
                  </span>
                </div>
                <div className="action-section-list">
                  {section.sessions.map((session) => {
                    const status = inferStatus(session);
                    return (
                      <div
                        key={session.id}
                        className="action-card"
                        style={{ borderColor: `${section.tint}26` }}
                      >
                        <div className="action-card-head">
                          <div className="action-card-title">
                            <span className="worker-dot" style={{ backgroundColor: status.tint }} />
                            <strong>{session.workerName || session.projectName}</strong>
                            <span>{session.projectName}</span>
                          </div>
                          <button
                            className="action-go-button"
                            onClick={() => {
                              onSelectSession(session.id);
                              onClose();
                            }}
                          >
                            {t("custom.go")}
                          </button>
                        </div>
                        <div className="action-card-detail">{section.detail(session)}</div>
                        <div className="action-card-meta">
                          <span>{session.branch || t("custom.no.branch")}</span>
                          <span>{formatTokens(session.tokensUsed)} {t("custom.tokens.suffix")}</span>
                          <span>{relativeTime(session.lastActivityTime)}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </section>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

interface CommandPaletteViewProps {
  isOpen: boolean;
  sessions: SessionSnapshot[];
  onClose: () => void;
  onOpenNewSession: () => void;
  onRefresh: () => void;
  onSetViewMode: (mode: AppViewMode) => void;
  onSelectSession: (sessionId: string) => void;
}

interface CommandPaletteAction {
  id: string;
  title: string;
  subtitle: string;
  glyph: string;
  tint: string;
  run: () => void;
}

export function CommandPaletteView(props: CommandPaletteViewProps) {
  const { isOpen, sessions, onClose, onOpenNewSession, onRefresh, onSetViewMode, onSelectSession } = props;
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);

  const allActions = useMemo<CommandPaletteAction[]>(
    () => [
      {
        id: "new-session",
        title: t("overlay.new.session"),
        subtitle: "Ctrl+T",
        glyph: "+",
        tint: Theme.green,
        run: () => {
          onClose();
          onOpenNewSession();
        }
      },
      {
        id: "refresh",
        title: t("overlay.refresh.session"),
        subtitle: "Ctrl+R",
        glyph: "↻",
        tint: Theme.accent,
        run: () => {
          onClose();
          onRefresh();
        }
      },
      {
        id: "view-split",
        title: t("overlay.split.view"),
        subtitle: "Layout",
        glyph: "▥",
        tint: Theme.accent,
        run: () => {
          onClose();
          onSetViewMode("split");
        }
      },
      {
        id: "view-office",
        title: t("overlay.office.view"),
        subtitle: "Layout",
        glyph: "▦",
        tint: Theme.purple,
        run: () => {
          onClose();
          onSetViewMode("office");
        }
      },
      {
        id: "view-strip",
        title: t("overlay.strip.view"),
        subtitle: "Layout",
        glyph: "▤",
        tint: Theme.orange,
        run: () => {
          onClose();
          onSetViewMode("strip");
        }
      },
      {
        id: "view-terminal",
        title: t("overlay.terminal.view"),
        subtitle: "Layout",
        glyph: ">_",
        tint: Theme.green,
        run: () => {
          onClose();
          onSetViewMode("terminal");
        }
      },
      ...sessions.map((session) => ({
        id: `session-${session.id}`,
        title: session.workerName ? `${session.workerName} · ${session.projectName}` : session.projectName,
        subtitle: t("overlay.go.to.session"),
        glyph: "→",
        tint: inferStatus(session).tint,
        run: () => {
          onClose();
          onSelectSession(session.id);
        }
      }))
    ],
    [onClose, onOpenNewSession, onRefresh, onSelectSession, onSetViewMode, sessions]
  );

  const filteredActions = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return allActions;
    return allActions.filter(
      (action) => action.title.toLowerCase().includes(normalized) || action.subtitle.toLowerCase().includes(normalized)
    );
  }, [allActions, query]);

  useEffect(() => {
    if (!isOpen) {
      setQuery("");
      setSelectedIndex(0);
      return;
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (!isOpen) return;
      if (event.key === "ArrowDown") {
        event.preventDefault();
        setSelectedIndex((current) => (filteredActions.length ? (current + 1) % filteredActions.length : 0));
      }
      if (event.key === "ArrowUp") {
        event.preventDefault();
        setSelectedIndex((current) =>
          filteredActions.length ? (current - 1 + filteredActions.length) % filteredActions.length : 0
        );
      }
      if (event.key === "Enter") {
        const action = filteredActions[selectedIndex];
        if (!action) return;
        event.preventDefault();
        action.run();
      }
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [filteredActions, isOpen, onClose, selectedIndex]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  if (!isOpen) return null;

  return (
    <div className="overlay-backdrop command-palette-backdrop" onClick={onClose}>
      <div className="overlay-panel command-palette-panel" onClick={(event) => event.stopPropagation()}>
        <div className="command-search-row">
          <span className="command-search-icon">⌕</span>
          <input
            autoFocus
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={t("overlay.search.commands")}
          />
        </div>
        <div className="command-results">
          {filteredActions.map((action, index) => (
            <button
              key={action.id}
              className={`command-row ${selectedIndex === index ? "is-selected" : ""}`}
              onMouseEnter={() => setSelectedIndex(index)}
              onClick={action.run}
            >
              <span className="command-glyph" style={{ color: action.tint }}>
                {action.glyph}
              </span>
              <span className="command-title">{action.title}</span>
              <span className="command-subtitle">{action.subtitle}</span>
            </button>
          ))}
          {filteredActions.length === 0 ? (
            <div className="command-empty">
              <strong>{t("custom.command.no.matches")}</strong>
              <span>{t("custom.command.try.keyword")}</span>
            </div>
          ) : null}
        </div>
        <div className="command-footer">{t("custom.command.footer")}</div>
      </div>
    </div>
  );
}

interface SessionNotificationBannerStackProps {
  notifications: SessionNotificationItem[];
  onDismiss: (notificationId: string) => void;
  onSelectSession: (sessionId: string) => void;
}

export function SessionNotificationBannerStack(props: SessionNotificationBannerStackProps) {
  const { notifications, onDismiss, onSelectSession } = props;

  if (notifications.length === 0) return null;

  return (
    <div className="notification-stack">
      {notifications.slice(-3).map((notification) => (
        <div
          key={notification.id}
          className="notification-card"
          style={{ borderColor: `${notification.tint}4d` }}
          onClick={() => onSelectSession(notification.sessionId)}
        >
          <div className="notification-card-head">
            <span className="notification-glyph" style={{ color: notification.tint }}>
              {notification.glyph}
            </span>
            <div className="notification-copy">
              <strong>{notification.title}</strong>
              <span>{notification.detail}</span>
            </div>
            <button
              className="notification-dismiss"
              onClick={(event) => {
                event.stopPropagation();
                onDismiss(notification.id);
              }}
            >
              ✕
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
