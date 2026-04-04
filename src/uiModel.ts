import type { SessionSnapshot } from "./types";

export type AppViewMode = "split" | "office" | "terminal" | "strip";
export type TerminalViewMode = "grid" | "single" | "git" | "browser";
export type SessionStatusFilter = "all" | "active" | "processing" | "completed" | "attention";
export type SidebarSortOption = "recent" | "name" | "tokens" | "status";

export interface ProjectGroup {
  id: string;
  projectName: string;
  projectPath: string;
  tabs: SessionSnapshot[];
  hasActiveTab: boolean;
}

export interface StatusPresentation {
  category: "idle" | "active" | "processing" | "completed" | "attention";
  label: string;
  symbol: string;
  tint: string;
  sortPriority: number;
}
