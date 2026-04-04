import { Theme } from "./Theme";
import { t, tf } from "./localizationCatalog";
import type { SessionBlock, SessionSnapshot } from "./types";
import type { ProjectGroup, SidebarSortOption, StatusPresentation } from "./uiModel";

export function inferStatus(session: SessionSnapshot): StatusPresentation {
  if (session.claudeActivity === "error") {
    return { category: "attention", label: t("custom.attention"), symbol: "▲", tint: Theme.red, sortPriority: 0 };
  }
  if (session.isCompleted || session.claudeActivity === "done") {
    return { category: "completed", label: t("custom.completed"), symbol: "●", tint: Theme.green, sortPriority: 3 };
  }
  if (session.isProcessing) {
    return { category: "processing", label: t("custom.processing"), symbol: "◎", tint: Theme.accent, sortPriority: 1 };
  }
  if (session.isRunning) {
    return { category: "active", label: t("custom.active"), symbol: "●", tint: Theme.green, sortPriority: 2 };
  }
  return { category: "idle", label: t("status.idle"), symbol: "○", tint: Theme.textDim, sortPriority: 4 };
}

export function formatTokens(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}k`;
  return `${value}`;
}

export function compareSessions(lhs: SessionSnapshot, rhs: SessionSnapshot, option: SidebarSortOption): number {
  if (option === "recent") {
    const lhsTime = new Date(lhs.lastActivityTime).getTime();
    const rhsTime = new Date(rhs.lastActivityTime).getTime();
    if (lhsTime !== rhsTime) return rhsTime - lhsTime;
  }

  if (option === "name") {
    const diff = lhs.projectName.localeCompare(rhs.projectName, "ko", { sensitivity: "base" });
    if (diff !== 0) return diff;
  }

  if (option === "tokens" && lhs.tokensUsed !== rhs.tokensUsed) {
    return rhs.tokensUsed - lhs.tokensUsed;
  }

  if (option === "status") {
    const lhsPriority = inferStatus(lhs).sortPriority;
    const rhsPriority = inferStatus(rhs).sortPriority;
    if (lhsPriority !== rhsPriority) return lhsPriority - rhsPriority;
  }

  const projectDiff = lhs.projectName.localeCompare(rhs.projectName, "ko", { sensitivity: "base" });
  if (projectDiff !== 0) return projectDiff;
  return lhs.workerName.localeCompare(rhs.workerName, "ko", { sensitivity: "base" });
}

export function compareGroups(lhs: ProjectGroup, rhs: ProjectGroup, option: SidebarSortOption): number {
  if (option === "recent") {
    const lhsTime = Math.max(...lhs.tabs.map((tab) => new Date(tab.lastActivityTime).getTime()));
    const rhsTime = Math.max(...rhs.tabs.map((tab) => new Date(tab.lastActivityTime).getTime()));
    if (lhsTime !== rhsTime) return rhsTime - lhsTime;
  }

  if (option === "name") {
    const diff = lhs.projectName.localeCompare(rhs.projectName, "ko", { sensitivity: "base" });
    if (diff !== 0) return diff;
  }

  if (option === "tokens") {
    const lhsTokens = lhs.tabs.reduce((sum, tab) => sum + tab.tokensUsed, 0);
    const rhsTokens = rhs.tabs.reduce((sum, tab) => sum + tab.tokensUsed, 0);
    if (lhsTokens !== rhsTokens) return rhsTokens - lhsTokens;
  }

  if (option === "status") {
    const lhsPriority = Math.min(...lhs.tabs.map((tab) => inferStatus(tab).sortPriority));
    const rhsPriority = Math.min(...rhs.tabs.map((tab) => inferStatus(tab).sortPriority));
    if (lhsPriority !== rhsPriority) return lhsPriority - rhsPriority;
  }

  return lhs.projectName.localeCompare(rhs.projectName, "ko", { sensitivity: "base" });
}

export function groupSessions(sessions: SessionSnapshot[], selectedId: string): ProjectGroup[] {
  const grouped = new Map<string, ProjectGroup>();
  sessions.forEach((session) => {
    const key = session.projectPath || session.projectName || session.id;
    const existing = grouped.get(key);
    if (existing) {
      existing.tabs.push(session);
      existing.hasActiveTab = existing.hasActiveTab || session.id === selectedId;
      return;
    }
    grouped.set(key, {
      id: key,
      projectName: session.projectName,
      projectPath: session.projectPath,
      tabs: [session],
      hasActiveTab: session.id === selectedId
    });
  });
  return [...grouped.values()];
}

export function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return t("sidebar.time.just.now");
  if (minutes < 60) return tf("sidebar.time.minutes.ago", undefined, minutes);
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return tf("sidebar.time.hours.ago", undefined, hours);
  const days = Math.floor(hours / 24);
  return tf("sidebar.time.days.ago", undefined, days);
}

function truncateLine(value: string, maxLength = 120): string {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, Math.max(0, maxLength - 1)).trimEnd()}…`;
}

function normalizeSingleLine(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

export function latestMeaningfulBlock(session: SessionSnapshot, kinds?: SessionBlock["kind"][]): SessionBlock | null {
  const allowed = kinds ? new Set(kinds) : null;
  const block = [...session.blocks]
    .reverse()
    .find((entry) => (!allowed || allowed.has(entry.kind)) && normalizeSingleLine(entry.content).length > 0);
  return block ?? null;
}

export function inferPendingApproval(session: SessionSnapshot): string | null {
  if (session.pendingApproval) {
    return truncateLine(normalizeSingleLine(session.pendingApproval.command), 140);
  }

  const approvalBlock = [...session.blocks].reverse().find((block) => {
    const content = normalizeSingleLine(block.content).toLowerCase();
    if (!content) return false;
    return (
      content.includes("pending approval") ||
      content.includes("approval required") ||
      content.includes("approval needed") ||
      content.includes("permission approval") ||
      (content.includes("permission") && (content.includes("required") || content.includes("needed"))) ||
      (content.includes("approve") && content.includes("deny"))
    );
  });

  if (!approvalBlock) return null;
  return truncateLine(normalizeSingleLine(approvalBlock.content), 140);
}

export function sessionActivitySummary(session: SessionSnapshot): string {
  const pendingApproval = inferPendingApproval(session);
  if (pendingApproval) return pendingApproval;

  const block = latestMeaningfulBlock(session, [
    "toolError",
    "error",
    "status",
    "fileChange",
    "toolUse",
    "completion",
    "thought",
    "userPrompt",
    "toolOutput"
  ]);

  if (!block) {
    return session.lastResultText ? truncateLine(normalizeSingleLine(session.lastResultText)) : t("custom.no.recent.activity");
  }

  const content = truncateLine(normalizeSingleLine(block.content));
  if (!content) return t("custom.no.recent.activity");

  switch (block.kind) {
    case "fileChange":
      return `Edit ${content}`;
    case "toolUse":
      return `Use ${content}`;
    case "userPrompt":
      return `Prompt: ${content}`;
    case "completion":
      return session.lastResultText ? truncateLine(normalizeSingleLine(session.lastResultText)) : t("custom.completed");
    default:
      return content;
  }
}
