export interface InstalledPluginRecord {
  id: string;
  title: string;
  source: string;
  localPath: string;
  enabled: boolean;
  shared: boolean;
  marketplaceId: string | null;
  author: string;
  version: string;
  tags: string[];
}

export const pluginInstallStorageKey = "doffice.settings.plugins.installed";

export function loadInstalledPlugins(): InstalledPluginRecord[] {
  try {
    const raw = window.localStorage.getItem(pluginInstallStorageKey);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as Partial<InstalledPluginRecord>[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((item, index) => {
        const source = typeof item.source === "string" ? item.source.trim() : "";
        const localPath = typeof item.localPath === "string" ? item.localPath.trim() : "";
        const title =
          typeof item.title === "string" && item.title.trim()
            ? item.title.trim()
            : source.split("/").pop() || localPath.split(/[\\/]/).pop() || `plugin-${index + 1}`;
        if (!source && !localPath) return null;
        return {
          id: typeof item.id === "string" && item.id.trim() ? item.id : `plugin-${index}-${title}`,
          title,
          source,
          localPath,
          enabled: typeof item.enabled === "boolean" ? item.enabled : true,
          shared: typeof item.shared === "boolean" ? item.shared : false,
          marketplaceId: typeof item.marketplaceId === "string" && item.marketplaceId.trim() ? item.marketplaceId : null,
          author: typeof item.author === "string" ? item.author : "Unknown",
          version: typeof item.version === "string" ? item.version : "",
          tags: Array.isArray(item.tags) ? item.tags.filter((tag): tag is string => typeof tag === "string") : []
        };
      })
      .filter((item): item is InstalledPluginRecord => item !== null);
  } catch {
    return [];
  }
}

export function saveInstalledPlugins(installedPlugins: InstalledPluginRecord[]) {
  window.localStorage.setItem(pluginInstallStorageKey, JSON.stringify(installedPlugins));
  window.dispatchEvent(new CustomEvent("doffice:installed-plugins-changed"));
}

export function enabledInstalledPluginDirs(installedPlugins: InstalledPluginRecord[]): string[] {
  return [...new Set(
    installedPlugins
      .filter((item) => item.enabled && item.localPath.trim().length > 0)
      .map((item) => item.localPath.trim())
  )];
}
