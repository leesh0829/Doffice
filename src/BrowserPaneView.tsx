import { useEffect, useMemo, useState } from "react";
import type { SessionSnapshot } from "./types";
import { t } from "./localizationCatalog";

interface BrowserPaneViewProps {
  selectedSession: SessionSnapshot | null;
}

interface BrowserTab {
  id: string;
  title: string;
  url: string;
}

const defaultBookmarks = [
  { url: "http://localhost:3000", icon: "🌎" },
  { url: "http://localhost:5173", icon: "🕊" },
  { url: "http://localhost:8080", icon: "🖳" },
  { url: "http://localhost:4000", icon: "🍃" }
];

const browserStorageKey = "doffice.browser-pane";

function loadBrowserState() {
  try {
    const raw = window.localStorage.getItem(browserStorageKey);
    if (!raw) {
      return {
        tabs: [{ id: "tab-0", title: "New Tab", url: "about:blank" }],
        activeTabId: "tab-0",
        bookmarks: []
      };
    }
    const parsed = JSON.parse(raw) as {
      tabs?: BrowserTab[];
      activeTabId?: string;
      bookmarks?: string[];
    };
    const tabs =
      Array.isArray(parsed.tabs) && parsed.tabs.every((tab) => tab && typeof tab.id === "string" && typeof tab.title === "string" && typeof tab.url === "string")
        ? parsed.tabs
        : [{ id: "tab-0", title: "New Tab", url: "about:blank" }];
    const activeTabId = typeof parsed.activeTabId === "string" ? parsed.activeTabId : tabs[0]?.id ?? "tab-0";
    const bookmarks = Array.isArray(parsed.bookmarks)
      ? parsed.bookmarks.filter((value): value is string => typeof value === "string" && !defaultBookmarks.some((item) => item.url === value))
      : [];
    return { tabs, activeTabId, bookmarks };
  } catch {
    return {
      tabs: [{ id: "tab-0", title: "New Tab", url: "about:blank" }],
      activeTabId: "tab-0",
      bookmarks: []
    };
  }
}

export function BrowserPaneView(props: BrowserPaneViewProps) {
  void props;
  const [persistedState] = useState(loadBrowserState);
  const [tabs, setTabs] = useState<BrowserTab[]>(persistedState.tabs);
  const [activeTabId, setActiveTabId] = useState(persistedState.activeTabId);
  const [savedBookmarks, setSavedBookmarks] = useState<string[]>(persistedState.bookmarks);
  const [address, setAddress] = useState("about:blank");
  const [showBookmarks, setShowBookmarks] = useState(true);

  const activeTab = tabs.find((tab) => tab.id === activeTabId) ?? tabs[0];
  const bookmarks = useMemo(() => savedBookmarks.slice(0, 12), [savedBookmarks]);

  useEffect(() => {
    if (activeTab) {
      setAddress(activeTab.url);
    }
  }, [activeTab]);

  useEffect(() => {
    if (!tabs.some((tab) => tab.id === activeTabId)) {
      setActiveTabId(tabs[0]?.id ?? "tab-0");
    }
  }, [activeTabId, tabs]);

  useEffect(() => {
    window.localStorage.setItem(browserStorageKey, JSON.stringify({ tabs, activeTabId, bookmarks: savedBookmarks }));
  }, [tabs, activeTabId, savedBookmarks]);

  function createTab(url = "about:blank") {
    const nextId = `tab-${Date.now()}`;
    const nextTab = {
      id: nextId,
      title: url === "about:blank" ? "New Tab" : url.replace(/^https?:\/\//, ""),
      url
    };
    setTabs((current) => [...current, nextTab]);
    setActiveTabId(nextId);
  }

  function navigate(nextUrl: string) {
    const normalized = /^https?:\/\//i.test(nextUrl) || nextUrl === "about:blank" ? nextUrl : `http://${nextUrl}`;
    setTabs((current) =>
      current.map((tab) =>
        tab.id === activeTabId
          ? {
              ...tab,
              url: normalized,
              title: normalized === "about:blank" ? "New Tab" : normalized.replace(/^https?:\/\//, "")
            }
          : tab
      )
    );
  }

  function closeTab(tabId: string) {
    setTabs((current) => {
      const next = current.filter((tab) => tab.id !== tabId);
      return next.length > 0 ? next : [{ id: "tab-0", title: "New Tab", url: "about:blank" }];
    });
    if (activeTabId === tabId) {
      setActiveTabId((current) => (current === tabId ? tabs.find((tab) => tab.id !== tabId)?.id ?? "tab-0" : current));
    }
  }

  function toggleBookmark(url: string) {
    if (!url || url === "about:blank" || defaultBookmarks.some((item) => item.url === url)) return;
    setSavedBookmarks((current) => (current.includes(url) ? current.filter((value) => value !== url) : [url, ...current].slice(0, 12)));
  }

  return (
    <section className="browser-pane">
      <aside className={`browser-sidebar ${showBookmarks ? "" : "is-collapsed"}`}>
        <div className="browser-sidebar-header">
          <strong>Bookmarks</strong>
          <button
            type="button"
            className="browser-close-button"
            onClick={() => setShowBookmarks((current) => !current)}
          >
            ×
          </button>
        </div>
        {showBookmarks ? (
          <>
            {bookmarks.length === 0 ? (
              <div className="browser-sidebar-empty">
                <div className="browser-sidebar-empty-icon">⌘</div>
                <span>No bookmarks yet</span>
              </div>
            ) : (
              <div className="browser-bookmark-section">
                <span className="browser-bookmark-title">BOOKMARKS</span>
                {bookmarks.map((bookmark) => (
                  <button key={bookmark} type="button" className="browser-bookmark-row" onClick={() => navigate(bookmark)}>
                    <span className="browser-bookmark-icon">🔖</span>
                    <span className="path-ellipsis">{bookmark.replace(/^https?:\/\//, "")}</span>
                  </button>
                ))}
              </div>
            )}
            <div className="browser-bookmark-section">
              <span className="browser-bookmark-title">DEV</span>
              {defaultBookmarks.map((bookmark) => (
                <button key={bookmark.url} type="button" className="browser-bookmark-row" onClick={() => navigate(bookmark.url)}>
                  <span className="browser-bookmark-icon">{bookmark.icon}</span>
                  <span>{bookmark.url.replace(/^https?:\/\//, "")}</span>
                </button>
              ))}
            </div>
          </>
        ) : null}
      </aside>

      <div className="browser-main">
        <div className="browser-tab-bar">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={`browser-tab ${tab.id === activeTabId ? "is-active" : ""}`}
              onClick={() => setActiveTabId(tab.id)}
            >
              <span>{tab.title}</span>
              {tabs.length > 1 ? (
                <span
                  className="browser-tab-close"
                  onClick={(event) => {
                    event.stopPropagation();
                    closeTab(tab.id);
                  }}
                >
                  ×
                </span>
              ) : null}
            </button>
          ))}
          <button type="button" className="browser-add-tab" onClick={() => createTab()}>
            +
          </button>
        </div>
        <div className="browser-address-bar">
          <button type="button" className="browser-nav-button" onClick={() => navigate(activeTab?.url ?? "about:blank")}>
            ↻
          </button>
          <form
            className="browser-address-form"
            onSubmit={(event) => {
              event.preventDefault();
              navigate(address);
            }}
          >
            <span className="browser-lock-icon">⌂</span>
            <input value={address} onChange={(event) => setAddress(event.target.value)} placeholder="http://localhost:5173" />
          </form>
          <button type="button" className="browser-nav-button" onClick={() => void window.doffice.openExternal(activeTab?.url ?? "about:blank")}>
            ↗
          </button>
          <button type="button" className="browser-nav-button" onClick={() => toggleBookmark(activeTab?.url ?? "")}>
            {bookmarks.includes(activeTab?.url ?? "") ? "★" : "🔖"}
          </button>
        </div>
        <div className="browser-surface">
          {activeTab?.url === "about:blank" ? <div className="browser-empty-page">about:blank</div> : null}
          {activeTab?.url !== "about:blank" ? <iframe className="browser-iframe" src={activeTab.url} title={activeTab.title || t("custom.browser")} /> : null}
        </div>
      </div>
    </section>
  );
}
