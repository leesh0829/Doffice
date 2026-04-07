import { t } from "./localizationCatalog";
import type { ProjectGroup } from "./uiModel";
import { inferStatus } from "./sessionUtils";
import type { WorkspaceBackgroundTheme } from "./workspaceState";
import { estimateDisplayUnits } from "./unicodeWidth";
import { PixelCharacterSprite, resolveCharacterForSession } from "./pixelOfficeArt";

interface StripGroup {
  id: string;
  projectName: string;
  workerName: string;
  workerColor: string;
  character: ReturnType<typeof resolveCharacterForSession> | null;
  statusLabel: string;
  statusClass: "approval" | "attention" | "processing" | "completed" | "idle";
  modelIcon: string;
}

function resolveStripGroups(groupedSessions: ProjectGroup[]): StripGroup[] {
  return groupedSessions.slice(0, 8).map((group) => {
    const tabs = group.tabs;
    const statuses = tabs.map((tab) => inferStatus(tab));
    const hasApproval = tabs.some((tab) => tab.pendingApproval);
    const hasAttention = statuses.some((status) => status.category === "attention");
    const hasProcessing = statuses.some((status) => status.category === "processing");
    const hasCompleted = tabs.length > 0 && tabs.every((tab) => tab.isCompleted);
    const leadTab = tabs[0];

    return {
      id: group.id,
      projectName: group.projectName,
      workerName: leadTab?.workerName ?? "workMan",
      workerColor: leadTab?.workerColorHex ?? "#4aa3ff",
      character: leadTab ? resolveCharacterForSession(leadTab) : null,
      modelIcon: leadTab?.selectedModel?.slice(0, 1).toUpperCase() ?? "C",
      statusLabel: hasApproval
        ? t("custom.approval")
        : hasAttention
          ? t("custom.attention")
          : hasProcessing
            ? t("custom.busy")
            : hasCompleted
              ? t("custom.completed")
              : t("status.idle"),
      statusClass: hasApproval ? "approval" : hasAttention ? "attention" : hasProcessing ? "processing" : hasCompleted ? "completed" : "idle"
    };
  });
}

export function PixelStripView(props: { groupedSessions: ProjectGroup[]; backgroundTheme?: WorkspaceBackgroundTheme }) {
  const { groupedSessions, backgroundTheme = "sunny" } = props;
  const groups = resolveStripGroups(groupedSessions);
  const cloudOffsets = [6, 17, 31, 48, 66];
  const starOffsets = [6, 10, 14, 19, 26, 33, 39, 47, 58, 66, 74, 81];

  return (
    <section className={`pixel-strip weather-${backgroundTheme}`}>
      <div className="pixel-strip-sky" />
      <div className="pixel-strip-stars">
        {starOffsets.map((offset, index) => (
          <span key={offset} className={`pixel-strip-star size-${index % 3}`} style={{ left: `${offset}%`, top: `${8 + (index % 5) * 8}%` }} />
        ))}
      </div>
      <div className="pixel-strip-cloud-layer">
        {cloudOffsets.map((offset, index) => (
          <div
            key={offset}
            className={`pixel-strip-cloud cloud-${index % 3}`}
            style={{ left: `${offset}%`, top: `${10 + (index % 3) * 9}px` }}
          />
        ))}
      </div>
      <div className="pixel-strip-sun" />
      <div className="pixel-strip-horizon" />

      <div className="pixel-strip-stage">
        <div className="pixel-strip-group-row">
          {groups.map((group) => (
            <div key={group.id} className={`pixel-strip-group status-${group.statusClass}`}>
              <div className="pixel-strip-group-actor">
                {group.character ? (
                  <PixelCharacterSprite
                    character={group.character}
                    className="pixel-strip-group-character"
                    scale={2}
                    pose={group.statusClass === "processing" ? "roaming" : "idle"}
                  />
                ) : null}
                <span className="pixel-strip-group-worker" style={{ color: group.workerColor, minWidth: `${estimateDisplayUnits(group.workerName) * 0.52 + 1}em` }}>
                  {group.workerName}
                </span>
              </div>

              <div className="pixel-strip-group-desk">
                <span className="pixel-strip-group-monitor" />
                <span className="pixel-strip-group-stand" />
                <span className="pixel-strip-group-keyboard" />
                <span className="pixel-strip-group-model">{group.modelIcon}</span>
              </div>

              <div className="pixel-strip-group-label">
                <strong style={{ minWidth: `${estimateDisplayUnits(group.projectName) * 0.52 + 1.8}em` }}>{group.projectName}</strong>
              </div>
            </div>
          ))}
        </div>
      </div>

      {groups.length > 0 ? (
        <div className="pixel-strip-status-panel">
          {groups.map((group) => (
            <div key={group.id} className={`pixel-strip-status-item status-${group.statusClass}`}>
              <span className="pixel-strip-status-dot" />
              <span className="pixel-strip-status-name" style={{ minWidth: `${estimateDisplayUnits(group.projectName) * 0.52 + 1.8}em` }}>{group.projectName}</span>
            </div>
          ))}
        </div>
      ) : null}

      <div className="pixel-strip-floor" />
    </section>
  );
}
