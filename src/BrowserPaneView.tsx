import { useEffect, useMemo, useRef, useState } from "react";
import type { SessionSnapshot } from "./types";
import { t } from "./localizationCatalog";

interface BrowserPaneViewProps {
  selectedSession: SessionSnapshot | null;
}

interface BrowserTab {
  id: string;
  title: string;
  url: string;
  history: string[];
  historyIndex: number;
  reloadToken: number;
}

interface BrowserWorkspaceState {
  tabs: BrowserTab[];
  activeTabId: string;
  showBookmarks: boolean;
}

const defaultBookmarks = [
  { url: "http://localhost:3000", icon: "🌎" },
  { url: "http://localhost:5173", icon: "🕊" },
  { url: "http://localhost:8080", icon: "🖳" },
  { url: "http://localhost:4000", icon: "🍃" }
];

const legacyBrowserStorageKey = "doffice.browser-pane";
const browserBookmarksStorageKey = "doffice.browser-bookmarks";
const browserWorkspaceKeyPrefix = "doffice.browser-pane";
const browserWorkspaceCache = new Map<string, BrowserWorkspaceState>();
const defaultBrowserURL = "https://www.google.com";

function tabTitleForUrl(url: string): string {
  if (!url || url === defaultBrowserURL) {
    return t("custom.browser.new.tab");
  }
  return url.replace(/^https?:\/\//, "");
}

function createBrowserTab(url = defaultBrowserURL, id = `tab-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`): BrowserTab {
  return {
    id,
    title: tabTitleForUrl(url),
    url,
    history: [url],
    historyIndex: 0,
    reloadToken: 0
  };
}

function normalizeNavigationTarget(input: string): string {
  const trimmed = input.trim();
  if (!trimmed || trimmed === "about:blank") {
    return defaultBrowserURL;
  }

  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed;
  }

  if (/^(localhost|\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(?:\/.*)?$/i.test(trimmed)) {
    return `http://${trimmed}`;
  }

  if (/^[\w-]+(\.[\w-]+)+(?::\d+)?(?:\/.*)?$/i.test(trimmed)) {
    return `https://${trimmed}`;
  }

  return `https://www.google.com/search?q=${encodeURIComponent(trimmed)}`;
}

function displayAddress(url: string): string {
  if (!url || url === "about:blank") {
    return "";
  }
  return url.replace(/^https?:\/\//, "");
}

function normalizeTab(raw: Partial<BrowserTab> | undefined, index: number): BrowserTab {
  const normalizedUrl = normalizeNavigationTarget(typeof raw?.url === "string" ? raw.url : defaultBrowserURL);
  const history = Array.isArray(raw?.history)
    ? raw.history
        .filter((value): value is string => typeof value === "string" && value.trim().length > 0)
        .map((value) => normalizeNavigationTarget(value))
    : [normalizedUrl];
  const safeHistory = history.length > 0 ? history : [normalizedUrl];
  const historyIndex =
    typeof raw?.historyIndex === "number" && raw.historyIndex >= 0 && raw.historyIndex < safeHistory.length
      ? raw.historyIndex
      : safeHistory.length - 1;
  const url = safeHistory[historyIndex] ?? normalizedUrl;

  return {
    id: typeof raw?.id === "string" && raw.id.trim() ? raw.id : `tab-${index}`,
    title: typeof raw?.title === "string" && raw.title.trim() ? raw.title : tabTitleForUrl(url),
    url,
    history: safeHistory,
    historyIndex,
    reloadToken: typeof raw?.reloadToken === "number" && raw.reloadToken >= 0 ? raw.reloadToken : 0
  };
}

function createBrowserWorkspaceState(): BrowserWorkspaceState {
  const tab = createBrowserTab();
  return {
    tabs: [tab],
    activeTabId: tab.id,
    showBookmarks: false
  };
}

function browserWorkspaceKey(scope: string) {
  return `${browserWorkspaceKeyPrefix}:${scope}`;
}

function loadLegacyBrowserState(): BrowserWorkspaceState | null {
  try {
    const raw = window.localStorage.getItem(legacyBrowserStorageKey);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as {
      tabs?: Partial<BrowserTab>[];
      activeTabId?: string;
      showBookmarks?: boolean;
    };
    const tabs =
      Array.isArray(parsed.tabs) && parsed.tabs.length > 0
        ? parsed.tabs.map((tab, index) => normalizeTab(tab, index))
        : [createBrowserTab()];
    const activeTabId = typeof parsed.activeTabId === "string" && tabs.some((tab) => tab.id === parsed.activeTabId)
      ? parsed.activeTabId
      : tabs[0]?.id ?? "tab-0";
    return {
      tabs,
      activeTabId,
      showBookmarks: typeof parsed.showBookmarks === "boolean" ? parsed.showBookmarks : false
    };
  } catch {
    return null;
  }
}

function loadBrowserWorkspace(scope: string): BrowserWorkspaceState {
  const cached = browserWorkspaceCache.get(scope);
  if (cached) {
    return cached;
  }

  try {
    const raw = window.localStorage.getItem(browserWorkspaceKey(scope));
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<BrowserWorkspaceState>;
      const tabs =
        Array.isArray(parsed.tabs) && parsed.tabs.length > 0
          ? parsed.tabs.map((tab, index) => normalizeTab(tab, index))
          : [createBrowserTab()];
      const activeTabId =
        typeof parsed.activeTabId === "string" && tabs.some((tab) => tab.id === parsed.activeTabId)
          ? parsed.activeTabId
          : tabs[0]?.id ?? "tab-0";
      const state = {
        tabs,
        activeTabId,
        showBookmarks: typeof parsed.showBookmarks === "boolean" ? parsed.showBookmarks : false
      };
      browserWorkspaceCache.set(scope, state);
      return state;
    }
  } catch {}

  const migrated = scope === "global" ? loadLegacyBrowserState() : null;
  const fallback = migrated ?? createBrowserWorkspaceState();
  browserWorkspaceCache.set(scope, fallback);
  return fallback;
}

function saveBrowserWorkspace(scope: string, state: BrowserWorkspaceState) {
  browserWorkspaceCache.set(scope, state);
  window.localStorage.setItem(browserWorkspaceKey(scope), JSON.stringify(state));
}

function loadBrowserBookmarks() {
  try {
    const raw = window.localStorage.getItem(browserBookmarksStorageKey);
    if (raw) {
      const parsed = JSON.parse(raw) as string[];
      return Array.isArray(parsed)
        ? parsed
            .filter((value): value is string => typeof value === "string" && value.trim().length > 0)
            .map((value) => normalizeNavigationTarget(value))
            .filter((value) => !defaultBookmarks.some((item) => item.url === value))
        : [];
    }

    const legacy = window.localStorage.getItem(legacyBrowserStorageKey);
    if (!legacy) return [];
    const parsed = JSON.parse(legacy) as { bookmarks?: string[] };
    return Array.isArray(parsed.bookmarks)
      ? parsed.bookmarks
          .filter((value): value is string => typeof value === "string" && value.trim().length > 0)
          .map((value) => normalizeNavigationTarget(value))
          .filter((value) => !defaultBookmarks.some((item) => item.url === value))
      : [];
  } catch {
    return [];
  }
}

function saveBrowserBookmarks(bookmarks: string[]) {
  window.localStorage.setItem(browserBookmarksStorageKey, JSON.stringify(bookmarks));
}

function pushHistory(tab: BrowserTab, nextUrl: string): BrowserTab {
  if (tab.history[tab.historyIndex] === nextUrl) {
    return {
      ...tab,
      url: nextUrl,
      title: tabTitleForUrl(nextUrl)
    };
  }

  const nextHistory = [...tab.history.slice(0, tab.historyIndex + 1), nextUrl];
  return {
    ...tab,
    url: nextUrl,
    title: tabTitleForUrl(nextUrl),
    history: nextHistory,
    historyIndex: nextHistory.length - 1
  };
}

export function BrowserPaneView(props: BrowserPaneViewProps) {
  const browserScope = props.selectedSession?.id ?? "global";
  const [workspaceState, setWorkspaceState] = useState<BrowserWorkspaceState>(() => loadBrowserWorkspace(browserScope));
  const [savedBookmarks, setSavedBookmarks] = useState<string[]>(loadBrowserBookmarks);
  const [address, setAddress] = useState("");
  const addressInputRef = useRef<HTMLInputElement | null>(null);

  const tabs = workspaceState.tabs;
  const activeTabId = workspaceState.activeTabId;
  const showBookmarks = workspaceState.showBookmarks;

  const activeTab = tabs.find((tab) => tab.id === activeTabId) ?? tabs[0];
  const bookmarks = useMemo(() => savedBookmarks.slice(0, 12), [savedBookmarks]);
  const canGoBack = activeTab ? activeTab.historyIndex > 0 : false;
  const canGoForward = activeTab ? activeTab.historyIndex < activeTab.history.length - 1 : false;

  useEffect(() => {
    setWorkspaceState(loadBrowserWorkspace(browserScope));
  }, [browserScope]);

  useEffect(() => {
    setAddress(displayAddress(activeTab?.url ?? ""));
  }, [activeTab]);

  useEffect(() => {
    if (activeTabId && tabs.some((tab) => tab.id === activeTabId)) {
      return;
    }
    setWorkspaceState((current) => ({
      ...current,
      activeTabId: current.tabs[0]?.id ?? "tab-0"
    }));
  }, [activeTabId, tabs]);

  useEffect(() => {
    saveBrowserWorkspace(browserScope, workspaceState);
  }, [browserScope, workspaceState]);

  useEffect(() => {
    saveBrowserBookmarks(savedBookmarks);
  }, [savedBookmarks]);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      addressInputRef.current?.focus();
      if (activeTab?.url === defaultBrowserURL) {
        addressInputRef.current?.select();
      }
    });
    return () => window.cancelAnimationFrame(frame);
  }, [browserScope, activeTab?.id, activeTab?.url]);

  function updateWorkspaceState(update: (current: BrowserWorkspaceState) => BrowserWorkspaceState) {
    setWorkspaceState((current) => update(current));
  }

  function createTab(url = defaultBrowserURL) {
    const nextTab = createBrowserTab(url);
    updateWorkspaceState((current) => ({
      ...current,
      tabs: [...current.tabs, nextTab],
      activeTabId: nextTab.id
    }));
  }

  function navigate(nextInput: string) {
    const normalized = normalizeNavigationTarget(nextInput);
    updateWorkspaceState((current) => ({
      ...current,
      tabs: current.tabs.map((tab) => (tab.id === current.activeTabId ? pushHistory(tab, normalized) : tab))
    }));
  }

  function stepHistory(direction: -1 | 1) {
    updateWorkspaceState((current) => ({
      ...current,
      tabs: current.tabs.map((tab) => {
        if (tab.id !== current.activeTabId) return tab;
        const nextIndex = tab.historyIndex + direction;
        if (nextIndex < 0 || nextIndex >= tab.history.length) return tab;
        const nextUrl = tab.history[nextIndex] ?? tab.url;
        return {
          ...tab,
          url: nextUrl,
          title: tabTitleForUrl(nextUrl),
          historyIndex: nextIndex
        };
      })
    }));
  }

  function reloadActiveTab() {
    if (!activeTab) return;
    updateWorkspaceState((current) => ({
      ...current,
      tabs: current.tabs.map((tab) =>
        tab.id === activeTab.id
          ? {
              ...tab,
              reloadToken: tab.reloadToken + 1
            }
          : tab
      )
    }));
  }

  function closeTab(tabId: string) {
    updateWorkspaceState((current) => {
      const nextTabs = current.tabs.filter((tab) => tab.id !== tabId);
      const safeTabs = nextTabs.length > 0 ? nextTabs : [createBrowserTab(defaultBrowserURL, "tab-0")];
      const nextActiveTabId =
        current.activeTabId === tabId
          ? safeTabs[Math.max(0, Math.min(current.tabs.findIndex((tab) => tab.id === tabId), safeTabs.length - 1))]?.id ?? "tab-0"
          : current.activeTabId;
      return {
        ...current,
        tabs: safeTabs,
        activeTabId: nextActiveTabId
      };
    });
  }

  function toggleBookmark(url: string) {
    const normalized = normalizeNavigationTarget(url);
    if (!normalized || defaultBookmarks.some((item) => item.url === normalized)) return;
    setSavedBookmarks((current) => (current.includes(normalized) ? current.filter((value) => value !== normalized) : [normalized, ...current].slice(0, 12)));
  }

  return (
    <section className="browser-pane">
      <aside className={`browser-sidebar ${showBookmarks ? "" : "is-collapsed"}`}>
        <div className="browser-sidebar-header">
          <strong>{t("custom.browser.bookmarks")}</strong>
          <button
            type="button"
            className="browser-close-button"
            onClick={() => updateWorkspaceState((current) => ({ ...current, showBookmarks: !current.showBookmarks }))}
          >
            {showBookmarks ? "×" : "☰"}
          </button>
        </div>
        {showBookmarks ? (
          <>
            {bookmarks.length === 0 ? (
              <div className="browser-sidebar-empty">
                <div className="browser-sidebar-empty-icon">⌘</div>
                <span>{t("custom.browser.empty")}</span>
              </div>
            ) : (
              <div className="browser-bookmark-section">
                <span className="browser-bookmark-title">{t("custom.browser.bookmarks")}</span>
                {bookmarks.map((bookmark) => (
                  <button key={bookmark} type="button" className="browser-bookmark-row" onClick={() => navigate(bookmark)}>
                    <span className="browser-bookmark-icon">🔖</span>
                    <span className="path-ellipsis">{displayAddress(bookmark)}</span>
                  </button>
                ))}
              </div>
            )}
              <div className="browser-bookmark-section">
                <span className="browser-bookmark-title">{t("custom.browser.dev")}</span>
                {defaultBookmarks.map((bookmark) => (
                  <button key={bookmark.url} type="button" className="browser-bookmark-row" onClick={() => navigate(bookmark.url)}>
                  <span className="browser-bookmark-icon">{bookmark.icon}</span>
                  <span>{displayAddress(bookmark.url)}</span>
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
              onClick={() => updateWorkspaceState((current) => ({ ...current, activeTabId: tab.id }))}
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
          <button type="button" className="browser-nav-button" onClick={() => stepHistory(-1)} disabled={!canGoBack}>
            ←
          </button>
          <button type="button" className="browser-nav-button" onClick={() => stepHistory(1)} disabled={!canGoForward}>
            →
          </button>
          <button type="button" className="browser-nav-button" onClick={reloadActiveTab}>
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
            <input
              ref={addressInputRef}
              value={address}
              onChange={(event) => setAddress(event.target.value)}
              placeholder={t("custom.browser.search.placeholder")}
            />
          </form>
          <button type="button" className="browser-nav-button" onClick={() => void window.doffice.openExternal(activeTab?.url ?? defaultBrowserURL)}>
            ↗
          </button>
          <button type="button" className="browser-nav-button" onClick={() => toggleBookmark(activeTab?.url ?? "")}>
            {bookmarks.includes(activeTab?.url ?? "") ? "★" : "🔖"}
          </button>
        </div>
        <div className="browser-surface">
          <iframe
            key={`${activeTab?.id ?? "browser"}:${activeTab?.reloadToken ?? 0}`}
            className="browser-iframe"
            src={activeTab?.url ?? defaultBrowserURL}
            title={activeTab?.title || t("custom.browser")}
          />
        </div>
      </div>
    </section>
  );
}
