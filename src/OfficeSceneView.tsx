import { useEffect, useMemo, useRef, useState, type CSSProperties, type MouseEvent } from "react";
import { t } from "./localizationCatalog";
import { formatTokens, inferStatus } from "./sessionUtils";
import type { SessionSnapshot } from "./types";
import type { ProjectGroup } from "./uiModel";
import { accessoryCatalog, jobCatalog, type OfficeCameraMode, type OfficeLayoutPreset, type WorkspaceBackgroundTheme } from "./workspaceState";
import { OfficeMapCanvas, PixelCharacterSprite, resolveCharacterForSession, type OfficeDecorItem } from "./pixelOfficeArt";

type OfficeVariant = "compact" | "full";

interface OfficeSceneViewProps {
  selectedSession: SessionSnapshot | null;
  groupedSessions: ProjectGroup[];
  selectSession: (sessionId: string) => void;
  variant?: OfficeVariant;
  enabledAccessoryIds?: string[];
  backgroundTheme?: WorkspaceBackgroundTheme;
  officeLayout?: OfficeLayoutPreset;
  officeCamera?: OfficeCameraMode;
}

interface TileRect {
  col: number;
  row: number;
  w: number;
  h: number;
}

interface DeskSlot {
  id: string;
  desk: TileRect;
  seat: { col: number; row: number };
}

interface WorkerPlacement {
  session: SessionSnapshot;
  pose: "typing" | "roaming" | "idle";
  col: number;
  row: number;
  status: ReturnType<typeof inferStatus>;
  projectName: string;
  character: ReturnType<typeof resolveCharacterForSession>;
}

const OFFICE_COLS = 42;
const OFFICE_ROWS = 20;

const deskSlots: DeskSlot[] = [
  { id: "desk_0", desk: { col: 3, row: 4, w: 3, h: 2 }, seat: { col: 4, row: 5 } },
  { id: "desk_1", desk: { col: 8, row: 4, w: 3, h: 2 }, seat: { col: 9, row: 5 } },
  { id: "desk_2", desk: { col: 13, row: 4, w: 3, h: 2 }, seat: { col: 14, row: 5 } },
  { id: "desk_3", desk: { col: 18, row: 4, w: 3, h: 2 }, seat: { col: 19, row: 5 } },
  { id: "desk_4", desk: { col: 3, row: 8, w: 3, h: 2 }, seat: { col: 4, row: 9 } },
  { id: "desk_5", desk: { col: 8, row: 8, w: 3, h: 2 }, seat: { col: 9, row: 9 } },
  { id: "desk_6", desk: { col: 13, row: 8, w: 3, h: 2 }, seat: { col: 14, row: 9 } },
  { id: "desk_7", desk: { col: 18, row: 8, w: 3, h: 2 }, seat: { col: 19, row: 9 } },
  { id: "desk_8", desk: { col: 3, row: 12, w: 3, h: 2 }, seat: { col: 4, row: 13 } },
  { id: "desk_9", desk: { col: 8, row: 12, w: 3, h: 2 }, seat: { col: 9, row: 13 } },
  { id: "desk_10", desk: { col: 13, row: 12, w: 3, h: 2 }, seat: { col: 14, row: 13 } },
  { id: "desk_11", desk: { col: 18, row: 12, w: 3, h: 2 }, seat: { col: 19, row: 13 } }
];

const rugs: Array<TileRect & { tone: "office" | "pantry" | "meeting" }> = [
  { col: 2, row: 4, w: 10, h: 5, tone: "office" },
  { col: 12, row: 4, w: 10, h: 5, tone: "office" },
  { col: 2, row: 11, w: 10, h: 5, tone: "office" },
  { col: 12, row: 11, w: 10, h: 5, tone: "office" },
  { col: 33, row: 3, w: 7, h: 5, tone: "pantry" },
  { col: 31, row: 13, w: 8, h: 5, tone: "meeting" }
];

const decorItems: OfficeDecorItem[] = [
  { col: 2, row: 2, w: 2, h: 1, kind: "shelf" },
  { col: 7, row: 2, w: 2, h: 1, kind: "shelf" },
  { col: 12, row: 2, w: 2, h: 1, kind: "shelf" },
  { col: 17, row: 2, w: 2, h: 1, kind: "shelf" },
  { col: 22, row: 2, w: 2, h: 1, kind: "shelf" },
  { col: 24, row: 6, w: 2, h: 1, kind: "shelf" },
  { col: 24, row: 10, w: 2, h: 1, kind: "shelf" },
  { col: 33, row: 9, w: 2, h: 1, kind: "shelf" },
  { col: 30, row: 17, w: 2, h: 1, kind: "shelf" },
  { col: 38, row: 17, w: 2, h: 1, kind: "shelf" },
  { col: 4, row: 1, w: 3, h: 1, kind: "picture" },
  { col: 11, row: 1, w: 3, h: 1, kind: "picture" },
  { col: 18, row: 1, w: 3, h: 1, kind: "picture" },
  { col: 34, row: 1, w: 3, h: 1, kind: "picture" },
  { col: 31, row: 11, w: 4, h: 1, kind: "board" },
  { col: 37, row: 11, w: 3, h: 1, kind: "picture" },
  { col: 35, row: 3, w: 3, h: 2, kind: "sofa" },
  { col: 36, row: 6, w: 2, h: 2, kind: "round-table" },
  { col: 33, row: 14, w: 4, h: 3, kind: "meeting-table" },
  { col: 30, row: 2, w: 1, h: 1, kind: "coffee" },
  { col: 32, row: 2, w: 1, h: 1, kind: "water" },
  { col: 23, row: 16, w: 2, h: 1, kind: "printer" },
  { col: 25, row: 16, w: 1, h: 1, kind: "trash" },
  { col: 1, row: 2, w: 1, h: 1, kind: "plant" },
  { col: 26, row: 2, w: 1, h: 1, kind: "plant" },
  { col: 1, row: 17, w: 1, h: 1, kind: "plant" },
  { col: 26, row: 17, w: 1, h: 1, kind: "plant" },
  { col: 39, row: 2, w: 1, h: 1, kind: "plant" },
  { col: 30, row: 9, w: 1, h: 1, kind: "plant" },
  { col: 39, row: 9, w: 1, h: 1, kind: "plant" },
  { col: 39, row: 12, w: 1, h: 1, kind: "plant" },
  { col: 29, row: 17, w: 1, h: 1, kind: "plant" },
  { col: 39, row: 17, w: 1, h: 1, kind: "lamp" }
];

const roamTiles = [
  { col: 24, row: 4 },
  { col: 24, row: 8 },
  { col: 24, row: 12 },
  { col: 24, row: 15 },
  { col: 31, row: 5 },
  { col: 35, row: 7 },
  { col: 38, row: 4 },
  { col: 34, row: 15 },
  { col: 38, row: 16 },
  { col: 31, row: 16 },
  { col: 21, row: 16 },
  { col: 7, row: 16 },
  { col: 15, row: 16 }
];

const collabDeskSlots: DeskSlot[] = [
  { id: "desk_0", desk: { col: 4, row: 4, w: 4, h: 2 }, seat: { col: 5, row: 5 } },
  { id: "desk_1", desk: { col: 10, row: 4, w: 4, h: 2 }, seat: { col: 11, row: 5 } },
  { id: "desk_2", desk: { col: 16, row: 4, w: 4, h: 2 }, seat: { col: 17, row: 5 } },
  { id: "desk_3", desk: { col: 4, row: 10, w: 4, h: 2 }, seat: { col: 5, row: 11 } },
  { id: "desk_4", desk: { col: 10, row: 10, w: 4, h: 2 }, seat: { col: 11, row: 11 } },
  { id: "desk_5", desk: { col: 16, row: 10, w: 4, h: 2 }, seat: { col: 17, row: 11 } },
  { id: "desk_6", desk: { col: 6, row: 15, w: 4, h: 2 }, seat: { col: 7, row: 16 } },
  { id: "desk_7", desk: { col: 14, row: 15, w: 4, h: 2 }, seat: { col: 15, row: 16 } }
];

const focusDeskSlots: DeskSlot[] = [
  { id: "desk_0", desk: { col: 4, row: 4, w: 3, h: 2 }, seat: { col: 5, row: 5 } },
  { id: "desk_1", desk: { col: 4, row: 8, w: 3, h: 2 }, seat: { col: 5, row: 9 } },
  { id: "desk_2", desk: { col: 4, row: 12, w: 3, h: 2 }, seat: { col: 5, row: 13 } },
  { id: "desk_3", desk: { col: 12, row: 4, w: 3, h: 2 }, seat: { col: 13, row: 5 } },
  { id: "desk_4", desk: { col: 12, row: 8, w: 3, h: 2 }, seat: { col: 13, row: 9 } },
  { id: "desk_5", desk: { col: 12, row: 12, w: 3, h: 2 }, seat: { col: 13, row: 13 } },
  { id: "desk_6", desk: { col: 20, row: 4, w: 3, h: 2 }, seat: { col: 21, row: 5 } },
  { id: "desk_7", desk: { col: 20, row: 8, w: 3, h: 2 }, seat: { col: 21, row: 9 } },
  { id: "desk_8", desk: { col: 20, row: 12, w: 3, h: 2 }, seat: { col: 21, row: 13 } }
];

function resolveSceneTheme(backgroundTheme: WorkspaceBackgroundTheme) {
  const chosenTheme =
    backgroundTheme === "auto"
      ? (() => {
          const hour = new Date().getHours();
          if (hour >= 6 && hour < 11) return "sunny";
          if (hour >= 11 && hour < 17) return "clearSky";
          if (hour >= 17 && hour < 19) return "goldenHour";
          if (hour >= 19 && hour < 21) return "dusk";
          return "moonlit";
        })()
      : backgroundTheme;
  return chosenTheme;
}

function rectStyle(rect: TileRect): CSSProperties {
  return {
    left: `${(rect.col / OFFICE_COLS) * 100}%`,
    top: `${(rect.row / OFFICE_ROWS) * 100}%`,
    width: `${(rect.w / OFFICE_COLS) * 100}%`,
    height: `${(rect.h / OFFICE_ROWS) * 100}%`
  };
}

function tileStyle(col: number, row: number, extra?: CSSProperties): CSSProperties {
  return {
    left: `${((col + 0.5) / OFFICE_COLS) * 100}%`,
    top: `${((row + 0.5) / OFFICE_ROWS) * 100}%`,
    ...extra
  };
}

function hashValue(input: string): number {
  let hash = 0;
  for (let index = 0; index < input.length; index += 1) {
    hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
  }
  return hash;
}

function isWorkingSession(session: SessionSnapshot): boolean {
  return (
    session.isProcessing ||
    session.claudeActivity !== "idle" ||
    Boolean(session.pendingApproval) ||
    Boolean(session.dangerousCommandWarning) ||
    Boolean(session.sensitiveFileWarning)
  );
}

interface MotionEntry {
  x: number;
  y: number;
  targetX: number;
  targetY: number;
  speed: number;
  pauseUntil: number;
  anchorIndex: number;
  lastTargetKey?: string;
}

const MOTION_TICK_MS = 48;
const ROAM_OFFSETS = [
  { dx: 0, dy: 0 },
  { dx: -0.72, dy: 0 },
  { dx: 0.72, dy: 0 },
  { dx: 0, dy: -0.62 },
  { dx: 0, dy: 0.62 },
  { dx: -0.58, dy: -0.38 },
  { dx: 0.58, dy: -0.38 },
  { dx: -0.58, dy: 0.38 },
  { dx: 0.58, dy: 0.38 },
  { dx: -1.1, dy: 0.24 },
  { dx: 1.1, dy: 0.24 },
  { dx: -0.9, dy: -0.74 },
  { dx: 0.9, dy: -0.74 },
  { dx: -0.94, dy: 0.72 },
  { dx: 0.94, dy: 0.72 }
] as const;

function workerBadge(session: SessionSnapshot): string {
  if (session.pendingApproval) return "!";
  switch (session.claudeActivity) {
    case "thinking":
      return "?";
    case "reading":
      return "R";
    case "writing":
      return "W";
    case "searching":
      return "S";
    case "running":
      return ">";
    case "done":
      return "✓";
    case "error":
      return "!";
    default:
      return "•";
  }
}

function statusLabel(session: SessionSnapshot): string {
  if (session.pendingApproval) return t("custom.approval.needed");
  switch (session.claudeActivity) {
    case "thinking":
      return "Thinking";
    case "reading":
      return "Reading";
    case "writing":
      return "Writing";
    case "searching":
      return "Searching";
    case "running":
      return "Running";
    case "done":
      return "Done";
    case "error":
      return "Error";
    default:
      return t("status.idle");
  }
}

function clampWorkerPosition(x: number, y: number) {
  return {
    x: Math.max(1.85, Math.min(OFFICE_COLS - 1.85, x)),
    y: Math.max(2.65, Math.min(OFFICE_ROWS - 1.55, y))
  };
}

function motionTargetKey(x: number, y: number) {
  return `${x.toFixed(2)},${y.toFixed(2)}`;
}

export function OfficeSceneView(props: OfficeSceneViewProps) {
  const {
    selectedSession,
    groupedSessions,
    selectSession,
    variant = "full",
    enabledAccessoryIds = [],
    backgroundTheme = "clear-day",
    officeLayout = "cozy",
    officeCamera = "overview"
  } = props;
  const activeDeskSlots = officeLayout === "collab" ? collabDeskSlots : officeLayout === "focus" ? focusDeskSlots : deskSlots;
  const effectiveTheme = resolveSceneTheme(backgroundTheme);
  const sceneBackgroundTheme =
    effectiveTheme === "clearSky"
      ? "blue-sky"
      : effectiveTheme === "moonlit" || effectiveTheme === "starryNight" || effectiveTheme === "aurora" || effectiveTheme === "milkyWay"
        ? "moonlight"
        : effectiveTheme === "rain" || effectiveTheme === "storm" || effectiveTheme === "fog" || effectiveTheme === "snow"
          ? "rain"
          : effectiveTheme === "neonCity" || effectiveTheme === "volcano"
            ? "neon"
            : effectiveTheme === "sunny" || effectiveTheme === "sunset" || effectiveTheme === "goldenHour" || effectiveTheme === "dusk" || effectiveTheme === "autumn" || effectiveTheme === "forest" || effectiveTheme === "cherryBlossom" || effectiveTheme === "ocean" || effectiveTheme === "desert"
              ? "clear-day"
              : effectiveTheme;
  const [followingSessionId, setFollowingSessionId] = useState<string | null>(null);
  const [followZoom, setFollowZoom] = useState(1.85);
  const [motionEntries, setMotionEntries] = useState<Record<string, MotionEntry>>({});
  const roamSeedRef = useRef(0);

  const orderedGroups = [...groupedSessions].sort((lhs, rhs) => {
    const lhsSelected = lhs.tabs.some((session) => session.id === selectedSession?.id);
    const rhsSelected = rhs.tabs.some((session) => session.id === selectedSession?.id);
    if (lhsSelected !== rhsSelected) return lhsSelected ? -1 : 1;
    const lhsWorking = lhs.tabs.some(isWorkingSession);
    const rhsWorking = rhs.tabs.some(isWorkingSession);
    if (lhsWorking !== rhsWorking) return lhsWorking ? -1 : 1;
    return rhs.tabs.length - lhs.tabs.length;
  });

  const sessions = orderedGroups.flatMap((group) => group.tabs);
  const orderedSessions = [...sessions].sort((lhs, rhs) => {
    if (lhs.id === selectedSession?.id) return -1;
    if (rhs.id === selectedSession?.id) return 1;
    if (isWorkingSession(lhs) !== isWorkingSession(rhs)) return isWorkingSession(lhs) ? -1 : 1;
    return new Date(rhs.lastActivityTime).getTime() - new Date(lhs.lastActivityTime).getTime();
  });

  const activeSessions = orderedSessions.filter(isWorkingSession);
  const roamingSessions = orderedSessions.filter((session) => !isWorkingSession(session));

  const activeSeatMap = useMemo(
    () =>
      Object.fromEntries(
        activeSessions.map((session, index) => {
          const slot = activeDeskSlots[index % activeDeskSlots.length];
          return [session.id, { x: slot.seat.col, y: slot.seat.row }];
        })
      ),
    [activeDeskSlots, activeSessions]
  );

  useEffect(() => {
    const now = Date.now();
    setMotionEntries((current) => {
      const next: Record<string, MotionEntry> = {};
      for (const session of orderedSessions) {
        const existing = current[session.id];
        if (activeSeatMap[session.id]) {
          const seat = activeSeatMap[session.id];
          const clamped = clampWorkerPosition(seat.x, seat.y);
          next[session.id] = {
            x: existing?.x ?? clamped.x,
            y: existing?.y ?? clamped.y,
            targetX: clamped.x,
            targetY: clamped.y,
            speed: existing?.speed ?? (0.12 + (hashValue(session.id) % 4) * 0.012),
            pauseUntil: now,
            anchorIndex: existing?.anchorIndex ?? hashValue(session.id) % roamTiles.length
          };
          continue;
        }
        const anchorIndex = existing?.anchorIndex ?? hashValue(session.id) % roamTiles.length;
        const anchor = roamTiles[anchorIndex];
        const clamped = clampWorkerPosition(anchor.col, anchor.row);
        next[session.id] = existing ?? {
          x: clamped.x,
          y: clamped.y,
          targetX: clamped.x,
          targetY: clamped.y,
          speed: 0.058 + ((hashValue(session.id) % 5) * 0.009),
          pauseUntil: now + 120 + (hashValue(session.id) % 320),
          anchorIndex
        };
      }
      return next;
    });
  }, [activeSeatMap, orderedSessions]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const now = Date.now();
      roamSeedRef.current += 1;
      setMotionEntries((current) => {
        const next = { ...current };

        for (const session of activeSessions) {
          const entry = next[session.id];
          const seat = activeSeatMap[session.id];
          if (!entry || !seat) continue;
          const clamped = clampWorkerPosition(seat.x, seat.y);
          const dx = clamped.x - entry.x;
          const dy = clamped.y - entry.y;
          const distance = Math.hypot(dx, dy);
          const step = Math.min(entry.speed, distance);
          next[session.id] = {
            ...entry,
            x: distance > 0.015 ? Number((entry.x + (dx / distance) * step).toFixed(3)) : clamped.x,
            y: distance > 0.015 ? Number((entry.y + (dy / distance) * step).toFixed(3)) : clamped.y,
            targetX: clamped.x,
            targetY: clamped.y,
            speed: 0.11 + ((hashValue(`${session.id}:${session.lastActivityTime}`) % 5) * 0.012),
            pauseUntil: now
          };
        }

        for (const session of roamingSessions) {
          const entry = next[session.id];
          if (!entry) continue;
          const dx = entry.targetX - entry.x;
          const dy = entry.targetY - entry.y;
          const distance = Math.hypot(dx, dy);
          if (distance > 0.02) {
            const step = Math.min(entry.speed, distance);
            next[session.id] = {
              ...entry,
              x: Number((entry.x + (dx / distance) * step).toFixed(3)),
              y: Number((entry.y + (dy / distance) * step).toFixed(3))
            };
            continue;
          }
          if (now < entry.pauseUntil) continue;

          const hopSeed = hashValue(`${session.id}:${roamSeedRef.current}:${entry.anchorIndex}:${entry.x.toFixed(2)}:${entry.y.toFixed(2)}`);
          const changeAnchor = hopSeed % 6 === 0;
          const nextAnchorIndex = changeAnchor ? (entry.anchorIndex + (hopSeed % 5) - 2 + roamTiles.length) % roamTiles.length : entry.anchorIndex;
          const anchor = roamTiles[nextAnchorIndex];
          const roamCandidates = ROAM_OFFSETS
            .map((offset) => {
              const clamped = clampWorkerPosition(anchor.col + offset.dx, anchor.row + offset.dy);
              return { x: clamped.x, y: clamped.y, key: motionTargetKey(clamped.x, clamped.y) };
            })
            .filter((candidate, index, all) => all.findIndex((item) => item.key === candidate.key) === index);
          const filteredCandidates =
            roamCandidates.length > 1 && entry.lastTargetKey
              ? roamCandidates.filter((candidate) => candidate.key !== entry.lastTargetKey)
              : roamCandidates;
          const nextTarget = filteredCandidates[hopSeed % filteredCandidates.length] ?? roamCandidates[0]!;
          next[session.id] = {
            ...entry,
            anchorIndex: nextAnchorIndex,
            targetX: nextTarget.x,
            targetY: nextTarget.y,
            lastTargetKey: nextTarget.key,
            pauseUntil: now + 140 + ((hopSeed >> 9) % 460),
            speed: 0.052 + ((hopSeed >> 14) % 6) * 0.01
          };
        }

        return next;
      });
    }, MOTION_TICK_MS);

    return () => window.clearInterval(timer);
  }, [activeSeatMap, activeSessions, roamingSessions]);

  const placements: WorkerPlacement[] = orderedSessions.map((session) => {
    const motion = motionEntries[session.id];
    const seat = activeSeatMap[session.id];
    const initialAnchor = roamTiles[hashValue(session.id) % roamTiles.length];
    const unclampedX = seat ? seat.x : motion?.x ?? initialAnchor.col;
    const unclampedY = seat ? seat.y : motion?.y ?? initialAnchor.row;
    const clamped = clampWorkerPosition(unclampedX, unclampedY);
    const seatDistance = seat && motion ? Math.hypot(seat.x - clamped.x, seat.y - clamped.y) : 0;
    const moving = motion ? Math.hypot((motion.targetX ?? clamped.x) - clamped.x, (motion.targetY ?? clamped.y) - clamped.y) > 0.06 : false;
    return {
      session,
      pose: seat ? (seatDistance > 0.12 ? "roaming" : "typing") : moving ? "roaming" : "idle",
      col: clamped.x,
      row: clamped.y,
      status: inferStatus(session),
      projectName: session.projectName,
      character: resolveCharacterForSession(session)
    };
  });

  const selectedCharacter = selectedSession ? resolveCharacterForSession(selectedSession) : null;
  const selectedStatus = selectedSession ? inferStatus(selectedSession) : null;
  const selectedRoleLabel = selectedCharacter ? jobCatalog[selectedCharacter.jobRole].label : "";
  const enabledKinds = new Set(
    accessoryCatalog.flatMap((entry) => (enabledAccessoryIds.includes(entry.id) ? entry.officeKinds : []))
  );
  const visibleDecorItems = decorItems.filter((item) => {
    if (["sofa", "round-table", "meeting-table", "coffee", "water", "board", "lamp", "picture", "plant", "shelf", "printer", "trash"].includes(item.kind)) {
      const requiredByAccessory = accessoryCatalog.some((entry) => entry.officeKinds.includes(item.kind));
      if (requiredByAccessory) {
        return enabledKinds.has(item.kind);
      }
    }
    return true;
  });
  const followedPlacement = followingSessionId ? placements.find((placement) => placement.session.id === followingSessionId) ?? null : null;
  const isFollowing = followedPlacement != null;
  const focusPlacement = officeCamera === "focus" ? followedPlacement ?? placements.find((placement) => placement.session.id === selectedSession?.id) ?? placements[0] ?? null : null;
  const baseZoom = officeCamera === "focus" ? Math.max(followZoom, 1.65) : 1;
  const cameraStyle: CSSProperties | undefined = followedPlacement
    ? {
        width: `${baseZoom * 100}%`,
        height: `${baseZoom * 100}%`,
        left: `${50 - (((followedPlacement.col + 0.5) / OFFICE_COLS) * 100 * baseZoom)}%`,
        top: `${50 - (((followedPlacement.row + 0.5) / OFFICE_ROWS) * 100 * baseZoom)}%`
      }
    : focusPlacement
      ? {
          width: `${baseZoom * 100}%`,
          height: `${baseZoom * 100}%`,
          left: `${50 - (((focusPlacement.col + 0.5) / OFFICE_COLS) * 100 * baseZoom)}%`,
          top: `${50 - (((focusPlacement.row + 0.5) / OFFICE_ROWS) * 100 * baseZoom)}%`
        }
    : undefined;

  useEffect(() => {
    if (!selectedSession) {
      setFollowingSessionId(null);
      return;
    }
    if (followingSessionId && !sessions.some((session) => session.id === followingSessionId)) {
      setFollowingSessionId(null);
    }
  }, [followingSessionId, selectedSession, sessions]);

  function handleWorkerSelect(session: SessionSnapshot) {
    selectSession(session.id);
    setFollowingSessionId((current) => {
      if (!current) return session.id;
      if (current === session.id) return null;
      return session.id;
    });
  }

  function clearFollowingIfNeeded(event: MouseEvent<HTMLDivElement>) {
    if (event.target === event.currentTarget && followingSessionId) {
      setFollowingSessionId(null);
    }
  }

  return (
    <section className={`office-scene office-scene-${variant} layout-${officeLayout} camera-${officeCamera} background-${sceneBackgroundTheme}`}>
      <div className="office-backdrop">
        <div className="office-aura office-aura-top" />
        <div className="office-aura office-aura-bottom" />
        <div className={`office-camera ${isFollowing ? "is-following" : ""}`} style={cameraStyle} onClick={clearFollowingIfNeeded}>
        <div className="office-map">
          <OfficeMapCanvas layout={officeLayout} themeId={backgroundTheme} activeDeskSlots={activeDeskSlots} visibleDecorItems={visibleDecorItems} />

          {placements.map((worker) => {
            const selected = selectedSession?.id === worker.session.id;
            const workerStyle: CSSProperties = tileStyle(worker.col, worker.row, {
              ["--worker-color" as string]: worker.session.workerColorHex,
              ["--worker-status" as string]: worker.status.tint,
              ["--worker-transition" as string]: worker.pose === "typing" ? "160ms" : "72ms"
            });
            return (
              <button
                key={worker.session.id}
                className={`office-worker-sprite pose-${worker.pose} ${selected ? "is-selected" : ""} status-${worker.status.category}`}
                style={workerStyle}
                onClick={(event) => {
                  event.stopPropagation();
                  handleWorkerSelect(worker.session);
                }}
                >
                <span className="office-worker-project">{worker.projectName}</span>
                <span className="office-worker-shadow" />
                <span className="office-worker-body-wrap">
                  <PixelCharacterSprite character={worker.character} className="office-worker-canvas" scale={2} walking={worker.pose === "roaming"} />
                </span>
                <span className="office-worker-badge">{workerBadge(worker.session)}</span>
                <span className="office-worker-tag" style={{ color: worker.session.workerColorHex }}>{worker.session.workerName}</span>
              </button>
            );
          })}
        </div>
        </div>
      </div>

      {selectedSession ? (
        <div className={`office-selection-panel ${isFollowing ? "is-following" : ""} variant-${variant}`}>
          <div className="office-selection-top">
            <span className="worker-dot" style={{ backgroundColor: selectedSession.workerColorHex }} />
            <div className="office-selection-identity">
              <strong>{selectedSession.workerName}</strong>
              <span>{selectedSession.projectName}</span>
            </div>
            <div className="office-selection-meta">
              <span className="office-selection-chip role">{selectedRoleLabel}</span>
              <span className="office-selection-chip status" style={{ color: selectedStatus?.tint }}>
                {selectedStatus?.label}
              </span>
            </div>
          </div>
          <div className="office-selection-stats">
            <div className="office-stat-card">
              <span>{t("custom.activity")}</span>
              <strong>{statusLabel(selectedSession)}</strong>
            </div>
            <div className="office-stat-card">
              <span>{t("custom.token.usage")}</span>
              <strong>{formatTokens(selectedSession.tokensUsed)}</strong>
            </div>
            <div className="office-stat-card">
              <span>{t("custom.files")}</span>
              <strong>{selectedSession.fileChanges.length}</strong>
            </div>
          </div>
        </div>
      ) : null}

      {isFollowing ? (
        <div className="office-follow-indicator">
          <div className="office-follow-zoom">
            <button type="button" className="chrome-icon-button compact" onClick={() => setFollowZoom((current) => Math.max(1.2, Number((current - 0.3).toFixed(2))))} disabled={followZoom <= 1.2}>
              −
            </button>
            <span>{Math.round(followZoom * 100)}%</span>
            <button type="button" className="chrome-icon-button compact" onClick={() => setFollowZoom((current) => Math.min(3, Number((current + 0.3).toFixed(2))))} disabled={followZoom >= 3}>
              ＋
            </button>
          </div>
          <button type="button" className="office-follow-pill" onClick={() => setFollowingSessionId(null)}>
            <span>◉</span>
            <strong>{selectedSession?.workerName ?? followedPlacement?.session.workerName} 추적 중</strong>
            <span>✕</span>
          </button>
        </div>
      ) : null}
    </section>
  );
}
