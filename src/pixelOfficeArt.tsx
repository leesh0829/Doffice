import { useEffect, useRef, useState } from "react";
import type { SessionSnapshot } from "./types";
import { getAllCharacters, type CharacterDefinition, type OfficeLayoutPreset, type WorkspaceBackgroundTheme } from "./workspaceState";

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

export interface OfficeDecorItem extends TileRect {
  kind: string;
  sprite?: string[][];
}

export type CharacterSpritePose = "typing" | "roaming" | "idle";

const BACK_TYPING_TEMPLATE_0 = [
  ".....HHHHHH.....",
  "....HHHHHHHH....",
  "...HHHHHHHHHH...",
  "...HHHHHHHHHH...",
  "...HHHHHHHHHH...",
  "....HHHHHHHH....",
  "....SSSSSSSS....",
  "....SSSSSSSS....",
  "....SSSSSSSS....",
  "....TTTTTTTT....",
  "...TTTTTTTTTT...",
  "..SSTTTTTTTTSS..",
  ".SS.TTTTTTTT.SS.",
  "....TTTTTTTT....",
  "...TTTTTTTTTT...",
  "....TTTTTTTT....",
  "....PPPPPPPP....",
  "....PPP..PPP....",
  "....PPP..PPP....",
  "...PPPP..PPPP...",
  "...WWWW..WWWW...",
  "................"
] as const;

const BACK_TYPING_TEMPLATE_1 = [
  ".....HHHHHH.....",
  "....HHHHHHHH....",
  "...HHHHHHHHHH...",
  "...HHHHHHHHHH...",
  "...HHHHHHHHHH...",
  "....HHHHHHHH....",
  "....SSSSSSSS....",
  "....SSSSSSSS....",
  "....SSSSSSSS....",
  "....TTTTTTTT....",
  "...TTTTTTTTTT...",
  ".SS.TTTTTTTT.SS.",
  "..SSTTTTTTTTSS..",
  "....TTTTTTTT....",
  "...TTTTTTTTTT...",
  "....TTTTTTTT....",
  "....PPPPPPPP....",
  "....PPP..PPP....",
  "....PPP..PPP....",
  "...PPPP..PPPP...",
  "...WWWW..WWWW...",
  "................"
] as const;

const OFFICE_COLS = 42;
const OFFICE_ROWS = 20;
const CANVAS_WIDTH = 840;
const CANVAS_HEIGHT = 400;

const cozyRugs: Array<TileRect & { tone: "office" | "pantry" | "meeting" }> = [
  { col: 2, row: 4, w: 10, h: 5, tone: "office" },
  { col: 12, row: 4, w: 10, h: 5, tone: "office" },
  { col: 2, row: 11, w: 10, h: 5, tone: "office" },
  { col: 12, row: 11, w: 10, h: 5, tone: "office" },
  { col: 33, row: 3, w: 7, h: 5, tone: "pantry" },
  { col: 31, row: 13, w: 8, h: 5, tone: "meeting" }
];

function resolveSceneTheme(backgroundTheme: WorkspaceBackgroundTheme) {
  if (backgroundTheme !== "auto") return backgroundTheme;
  const hour = new Date().getHours();
  if (hour >= 6 && hour < 11) return "sunny";
  if (hour >= 11 && hour < 17) return "clearSky";
  if (hour >= 17 && hour < 19) return "goldenHour";
  if (hour >= 19 && hour < 21) return "dusk";
  return "moonlit";
}

function previewPalette(themeId: string) {
  const palettes: Record<string, { skyTop: string; skyBottom: string; wallTop: string; wallBottom: string; floorA: string; floorB: string; rugOffice: string; rugMeeting: string; rugPantry: string }> = {
    sunny: { skyTop: "#b6ddff", skyBottom: "#507dc2", wallTop: "#d7e7f6", wallBottom: "#c6d8ea", floorA: "#b98755", floorB: "#ab7a48", rugOffice: "#b8bc8b", rugMeeting: "#a3a98e", rugPantry: "#8f947f" },
    clearSky: { skyTop: "#88c7ff", skyBottom: "#356ab7", wallTop: "#d1e5f6", wallBottom: "#bdd3e8", floorA: "#b98755", floorB: "#ab7a48", rugOffice: "#b8bc8b", rugMeeting: "#a3a98e", rugPantry: "#8f947f" },
    goldenHour: { skyTop: "#ffd18d", skyBottom: "#bc784e", wallTop: "#e6dccd", wallBottom: "#d2c6b4", floorA: "#b98755", floorB: "#ab7a48", rugOffice: "#b6b785", rugMeeting: "#9d9d80", rugPantry: "#8a856d" },
    sunset: { skyTop: "#ffbb77", skyBottom: "#724376", wallTop: "#dfd1db", wallBottom: "#c5b6c2", floorA: "#b27d4a", floorB: "#9b6b3f", rugOffice: "#b6b785", rugMeeting: "#9d9d80", rugPantry: "#8a856d" },
    dusk: { skyTop: "#7486d2", skyBottom: "#392d62", wallTop: "#cfd4ea", wallBottom: "#b9bfdc", floorA: "#9b7e62", floorB: "#8b6d55", rugOffice: "#989e77", rugMeeting: "#90937d", rugPantry: "#767663" },
    moonlit: { skyTop: "#5f72ac", skyBottom: "#162141", wallTop: "#becde1", wallBottom: "#93a5bc", floorA: "#647386", floorB: "#516076", rugOffice: "#6d7e72", rugMeeting: "#627269", rugPantry: "#575f59" },
    rain: { skyTop: "#8ea1b8", skyBottom: "#36465b", wallTop: "#d6dde6", wallBottom: "#a3afbb", floorA: "#7b8791", floorB: "#687781", rugOffice: "#95a0a2", rugMeeting: "#7f8b8d", rugPantry: "#70777a" },
    storm: { skyTop: "#7d8ea1", skyBottom: "#29364a", wallTop: "#d5dce5", wallBottom: "#a4b0bc", floorA: "#6f7c88", floorB: "#61707d", rugOffice: "#93a1a3", rugMeeting: "#828e90", rugPantry: "#6f7578" },
    fog: { skyTop: "#c8d1dc", skyBottom: "#788496", wallTop: "#eef2f6", wallBottom: "#d4dde7", floorA: "#a7b0bb", floorB: "#97a1ac", rugOffice: "#c2c7c9", rugMeeting: "#b3b8bc", rugPantry: "#a4aaad" },
    snow: { skyTop: "#dce7f8", skyBottom: "#9ba9c0", wallTop: "#f5f8fb", wallBottom: "#dbe3ec", floorA: "#c2cad4", floorB: "#b2bcc6", rugOffice: "#d7dde0", rugMeeting: "#c7d0d3", rugPantry: "#b8c0c3" },
    autumn: { skyTop: "#ffd58f", skyBottom: "#a26132", wallTop: "#ede1cc", wallBottom: "#d8c7a6", floorA: "#c08b53", floorB: "#a87443", rugOffice: "#b4ab7f", rugMeeting: "#9d936f", rugPantry: "#8b7e5e" },
    forest: { skyTop: "#86c69a", skyBottom: "#3b6349", wallTop: "#d8e4d5", wallBottom: "#bfd0bb", floorA: "#8a7759", floorB: "#766447", rugOffice: "#9dad8a", rugMeeting: "#8b9d84", rugPantry: "#768569" },
    cherryBlossom: { skyTop: "#ffdbe9", skyBottom: "#d9a3bb", wallTop: "#f8eff4", wallBottom: "#ead8e1", floorA: "#d5b6ae", floorB: "#be9e95", rugOffice: "#e1d7e7", rugMeeting: "#d4ccdd", rugPantry: "#c7bfce" },
    ocean: { skyTop: "#8ddfff", skyBottom: "#287ccf", wallTop: "#d9edf8", wallBottom: "#bdd8e4", floorA: "#7ea5b5", floorB: "#688fa1", rugOffice: "#c4d6cd", rugMeeting: "#a5bdb1", rugPantry: "#94aa9d" },
    desert: { skyTop: "#ffd697", skyBottom: "#d58b4a", wallTop: "#f3e2c5", wallBottom: "#dfc38d", floorA: "#c89459", floorB: "#b17e4a", rugOffice: "#c5bf94", rugMeeting: "#b1aa84", rugPantry: "#9f9775" },
    neonCity: { skyTop: "#8a6cff", skyBottom: "#231441", wallTop: "#cfc3ef", wallBottom: "#9383c3", floorA: "#4d3a67", floorB: "#402f5a", rugOffice: "#7a6aa5", rugMeeting: "#69608f", rugPantry: "#5e547c" },
    volcano: { skyTop: "#ffb165", skyBottom: "#2b1018", wallTop: "#dbc7c5", wallBottom: "#a88c8a", floorA: "#5b4039", floorB: "#4a332d", rugOffice: "#857777", rugMeeting: "#736666", rugPantry: "#675959" }
  };
  return palettes[themeId] ?? palettes.sunny;
}

function hexToRgb(hex: string) {
  const normalized = hex.replace("#", "");
  const full = normalized.length === 3 ? normalized.split("").map((token) => token + token).join("") : normalized;
  const value = Number.parseInt(full, 16);
  return {
    r: (value >> 16) & 255,
    g: (value >> 8) & 255,
    b: value & 255
  };
}

function withAlpha(hex: string, alpha: number) {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function hashValue(input: string): number {
  let hash = 0;
  for (let index = 0; index < input.length; index += 1) {
    hash = (hash * 31 + input.charCodeAt(index)) >>> 0;
  }
  return hash;
}

export function resolveCharacterForSession(session: SessionSnapshot) {
  const allCharacters = getAllCharacters();
  const lower = session.workerName.trim().toLowerCase();
  const exact = allCharacters.find((character) => character.name.toLowerCase() === lower);
  if (exact) return exact;
  const model = session.selectedModel.toLowerCase();
  if (model.includes("opus")) return allCharacters.find((character) => character.id === "claude_opus") ?? allCharacters[0]!;
  if (model.includes("sonnet")) return allCharacters.find((character) => character.id === "claude_sonnet") ?? allCharacters[0]!;
  if (model.includes("haiku")) return allCharacters.find((character) => character.id === "claude_haiku") ?? allCharacters[0]!;
  return allCharacters[hashValue(`${session.workerName}:${session.projectName}`) % allCharacters.length] ?? allCharacters[0]!;
}

function drawPixelRect(context: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string, scale: number, alpha = 1) {
  context.globalAlpha = alpha;
  context.fillStyle = color;
  context.fillRect(x * scale, y * scale, w * scale, h * scale);
  context.globalAlpha = 1;
}

function drawTemplateSprite(
  context: CanvasRenderingContext2D,
  template: readonly string[],
  palette: Record<string, string>,
  scale: number
) {
  for (let rowIndex = 0; rowIndex < template.length; rowIndex += 1) {
    const row = template[rowIndex] ?? "";
    for (let columnIndex = 0; columnIndex < row.length; columnIndex += 1) {
      const token = row[columnIndex] ?? ".";
      const color = palette[token];
      if (!color) continue;
      drawPixelRect(context, columnIndex, rowIndex, 1, 1, color, scale);
    }
  }
}

function drawStandingCharacterBase(context: CanvasRenderingContext2D, character: CharacterDefinition, scale: number, walkingFrame: 0 | 1 = 0) {
  const skin = `#${character.skinTone}`;
  const hair = `#${character.hairColor}`;
  const shirt = `#${character.shirtColor}`;
  const pants = `#${character.pantsColor}`;
  const px = (x: number, y: number, w: number, h: number, color: string, alpha = 1) => drawPixelRect(context, x, y, w, h, color, scale, alpha);

  switch (character.species) {
    case "cat":
      px(3, -2, 3, 3, skin);
      px(10, -2, 3, 3, skin);
      px(4, -1, 1, 1, "#f0a0a0");
      px(11, -1, 1, 1, "#f0a0a0");
      px(4, 1, 8, 6, skin);
      px(5, 3, 2, 2, "#60c060");
      px(6, 3, 1, 2, "#1a1a1a");
      px(9, 3, 2, 2, "#60c060");
      px(10, 3, 1, 2, "#1a1a1a");
      px(7, 5, 2, 1, "#f08080");
      px(2, 5, 2, 1, "#dddddd");
      px(12, 5, 2, 1, "#dddddd");
      px(4, 7, 8, 7, shirt);
      px(3, 12, 3, 2, skin);
      px(10, 12, 3, 2, skin);
      px(4, 14, 3, 3, skin);
      px(9, 14, 3, 3, skin);
      px(13, 10, 2, 2, skin);
      px(14, 8, 2, 3, skin);
      break;
    case "dog":
      px(2, 1, 3, 5, hair);
      px(11, 1, 3, 5, hair);
      px(4, 0, 8, 7, skin);
      px(5, 3, 2, 2, "#ffffff");
      px(6, 4, 1, 1, "#333333");
      px(9, 3, 2, 2, "#ffffff");
      px(10, 4, 1, 1, "#333333");
      px(7, 5, 2, 1, "#333333");
      px(7, 6, 2, 1, "#f06060");
      px(4, 7, 8, 7, shirt);
      px(3, 12, 3, 2, skin);
      px(10, 12, 3, 2, skin);
      px(4, 14, 3, 3, skin);
      px(9, 14, 3, 3, skin);
      px(13, 5, 2, 2, skin);
      px(14, 3, 2, 3, skin);
      break;
    case "rabbit":
      px(5, -5, 2, 6, skin);
      px(9, -5, 2, 6, skin);
      px(5, -4, 1, 4, "#f0a0a0");
      px(10, -4, 1, 4, "#f0a0a0");
      px(4, 1, 8, 6, skin);
      px(5, 3, 2, 2, "#d04060");
      px(6, 3, 1, 1, "#1a1a1a");
      px(9, 3, 2, 2, "#d04060");
      px(10, 3, 1, 1, "#1a1a1a");
      px(7, 5, 2, 1, "#f0a0a0");
      px(4, 7, 8, 7, shirt);
      px(3, 12, 3, 2, skin);
      px(10, 12, 3, 2, skin);
      px(5, 14, 3, 3, skin);
      px(8, 14, 3, 3, skin);
      px(13, 11, 3, 3, "#ffffff");
      break;
    case "bear":
      px(3, -1, 3, 3, skin);
      px(10, -1, 3, 3, skin);
      px(4, 0, 1, 1, "#c09060");
      px(11, 0, 1, 1, "#c09060");
      px(4, 1, 8, 7, skin);
      px(6, 5, 4, 3, "#d0b090");
      px(5, 3, 2, 2, "#1a1a1a");
      px(9, 3, 2, 2, "#1a1a1a");
      px(7, 5, 2, 1, "#333333");
      px(3, 8, 10, 7, shirt);
      px(2, 10, 3, 3, skin);
      px(11, 10, 3, 3, skin);
      px(4, 15, 4, 3, skin);
      px(8, 15, 4, 3, skin);
      break;
    case "penguin":
      px(4, 0, 8, 5, "#2a2a3a");
      px(5, 2, 6, 4, "#ffffff");
      px(6, 3, 1, 1, "#1a1a1a");
      px(9, 3, 1, 1, "#1a1a1a");
      px(7, 5, 2, 1, "#f0c040");
      px(3, 6, 10, 8, "#2a2a3a");
      px(5, 7, 6, 6, "#ffffff");
      px(2, 8, 2, 5, "#2a2a3a");
      px(12, 8, 2, 5, "#2a2a3a");
      px(5, 14, 3, 2, "#f0c040");
      px(8, 14, 3, 2, "#f0c040");
      break;
    case "fox":
      px(3, -2, 3, 4, "#e07030");
      px(10, -2, 3, 4, "#e07030");
      px(4, -1, 1, 2, "#ffffff");
      px(11, -1, 1, 2, "#ffffff");
      px(4, 1, 8, 6, skin);
      px(4, 4, 3, 3, "#ffffff");
      px(9, 4, 3, 3, "#ffffff");
      px(5, 3, 2, 1, "#f0c020");
      px(6, 3, 1, 1, "#1a1a1a");
      px(9, 3, 2, 1, "#f0c020");
      px(10, 3, 1, 1, "#1a1a1a");
      px(7, 5, 2, 1, "#333333");
      px(4, 7, 8, 7, shirt);
      px(3, 12, 3, 2, skin);
      px(10, 12, 3, 2, skin);
      px(4, 14, 3, 3, skin);
      px(9, 14, 3, 3, skin);
      px(12, 9, 3, 2, skin);
      px(13, 7, 3, 4, skin);
      px(14, 11, 2, 1, "#ffffff");
      break;
    case "robot":
      px(7, -3, 2, 3, "#8090a0");
      px(6, -4, 4, 1, "#60f0a0");
      px(3, 0, 10, 7, "#a0b0c0");
      px(4, 1, 8, 5, "#8090a0");
      px(5, 3, 2, 2, "#60f0a0");
      px(9, 3, 2, 2, "#60f0a0");
      px(6, 5, 4, 1, "#506070");
      px(3, 7, 10, 8, shirt);
      px(3, 7, 10, 1, "#8090a0");
      px(1, 9, 2, 5, "#8090a0");
      px(13, 9, 2, 5, "#8090a0");
      px(4, 15, 3, 3, "#708090");
      px(9, 15, 3, 3, "#708090");
      break;
    case "claude":
      px(4, 1, 8, 1, shirt);
      px(3, 2, 10, 7, shirt);
      px(1, 3, 2, 2, shirt);
      px(0, 4, 1, 1, shirt);
      px(13, 3, 2, 2, shirt);
      px(15, 4, 1, 1, shirt);
      px(5, 4, 1, 2, "#2a1810");
      px(10, 4, 1, 2, "#2a1810");
      px(4, 9, 1, 3, shirt);
      px(6, 9, 1, 3, shirt);
      px(9, 9, 1, 3, shirt);
      px(11, 9, 1, 3, shirt);
      break;
    case "alien":
      px(3, -1, 10, 2, skin);
      px(2, 1, 12, 6, skin);
      px(4, 3, 3, 3, "#101010");
      px(9, 3, 3, 3, "#101010");
      px(5, 4, 1, 1, "#40ff80");
      px(10, 4, 1, 1, "#40ff80");
      px(5, 7, 6, 5, shirt);
      px(3, 8, 2, 4, shirt);
      px(11, 8, 2, 4, shirt);
      px(5, 12, 2, 4, skin);
      px(9, 12, 2, 4, skin);
      px(7, -3, 2, 2, "#40ff80");
      px(8, -4, 1, 1, "#80ffa0");
      break;
    case "ghost":
      px(4, 0, 8, 3, skin);
      px(3, 3, 10, 6, skin);
      px(5, 4, 2, 2, "#303040");
      px(9, 4, 2, 2, "#303040");
      px(6, 7, 4, 1, "#404050");
      px(3, 9, 3, 3, skin);
      px(6, 10, 4, 2, skin);
      px(10, 9, 3, 3, skin);
      px(4, 12, 2, 1, skin);
      px(8, 12, 2, 1, skin);
      px(12, 12, 1, 1, skin);
      break;
    case "dragon":
      px(4, -2, 2, 2, "#f0c030");
      px(10, -2, 2, 2, "#f0c030");
      px(4, 0, 8, 6, skin);
      px(5, 2, 2, 2, "#ff4020");
      px(9, 2, 2, 2, "#ff4020");
      px(6, 5, 4, 1, "#f06030");
      px(3, 6, 10, 6, shirt);
      px(0, 5, 3, 5, shirt, 0.6);
      px(13, 5, 3, 5, shirt, 0.6);
      px(4, 12, 3, 4, skin);
      px(9, 12, 3, 4, skin);
      px(13, 10, 3, 2, shirt);
      px(14, 12, 2, 1, shirt);
      break;
    case "chicken":
      px(6, -2, 4, 2, "#e03020");
      px(5, 0, 6, 5, skin);
      px(6, 2, 2, 2, "#101010");
      px(11, 3, 2, 1, "#f0a020");
      px(6, 5, 1, 2, "#f03020");
      px(4, 5, 8, 7, shirt);
      px(2, 6, 2, 4, shirt, 0.7);
      px(12, 6, 2, 4, shirt, 0.7);
      px(5, 12, 2, 4, "#f0a020");
      px(9, 12, 2, 4, "#f0a020");
      break;
    case "owl":
      px(3, -1, 3, 3, hair);
      px(10, -1, 3, 3, hair);
      px(4, 1, 8, 6, skin);
      px(4, 3, 3, 3, "#f0e0a0");
      px(9, 3, 3, 3, "#f0e0a0");
      px(5, 4, 2, 2, "#202020");
      px(10, 4, 2, 2, "#202020");
      px(7, 6, 2, 1, "#d09030");
      px(3, 7, 10, 6, shirt);
      px(1, 8, 2, 4, hair);
      px(13, 8, 2, 4, hair);
      px(5, 13, 2, 3, skin);
      px(9, 13, 2, 3, skin);
      break;
    case "frog":
      px(3, 0, 4, 3, skin);
      px(9, 0, 4, 3, skin);
      px(4, 1, 2, 2, "#101010");
      px(10, 1, 2, 2, "#101010");
      px(3, 3, 10, 5, skin);
      px(4, 6, 8, 1, "#f06060");
      px(3, 8, 10, 5, shirt);
      px(1, 9, 2, 4, shirt);
      px(13, 9, 2, 4, shirt);
      px(4, 13, 3, 3, skin);
      px(9, 13, 3, 3, skin);
      break;
    case "panda":
      px(2, -1, 4, 3, "#1a1a1a");
      px(10, -1, 4, 3, "#1a1a1a");
      px(4, 1, 8, 6, skin);
      px(4, 3, 3, 3, "#1a1a1a");
      px(9, 3, 3, 3, "#1a1a1a");
      px(5, 4, 1, 1, "#ffffff");
      px(10, 4, 1, 1, "#ffffff");
      px(7, 5, 2, 1, "#1a1a1a");
      px(3, 7, 10, 6, shirt);
      px(1, 8, 2, 5, "#1a1a1a");
      px(13, 8, 2, 5, "#1a1a1a");
      px(4, 13, 3, 3, "#1a1a1a");
      px(9, 13, 3, 3, "#1a1a1a");
      break;
    case "unicorn":
      px(7, -4, 2, 1, "#f0d040");
      px(7, -3, 2, 1, "#f0c040");
      px(7, -2, 2, 2, "#f0b040");
      px(4, 0, 8, 6, skin);
      px(2, 0, 2, 5, hair);
      px(5, 2, 2, 2, "#ffffff");
      px(6, 3, 1, 1, "#c060c0");
      px(9, 2, 2, 2, "#ffffff");
      px(10, 3, 1, 1, "#c060c0");
      px(3, 6, 10, 7, shirt);
      px(1, 7, 2, 4, shirt);
      px(13, 7, 2, 4, shirt);
      px(4, 13, 3, 3, skin);
      px(9, 13, 3, 3, skin);
      break;
    case "skeleton":
      px(4, 0, 8, 6, "#f0f0e0");
      px(5, 2, 2, 2, "#1a1a1a");
      px(9, 2, 2, 2, "#1a1a1a");
      px(6, 4, 1, 1, "#1a1a1a");
      px(5, 5, 6, 1, "#1a1a1a");
      px(5, 5, 1, 1, "#f0f0e0");
      px(7, 5, 1, 1, "#f0f0e0");
      px(9, 5, 1, 1, "#f0f0e0");
      px(5, 6, 6, 6, "#404040");
      px(6, 7, 4, 1, "#f0f0e0");
      px(6, 9, 4, 1, "#f0f0e0");
      px(3, 7, 2, 5, "#404040");
      px(11, 7, 2, 5, "#404040");
      px(5, 12, 2, 4, "#f0f0e0");
      px(9, 12, 2, 4, "#f0f0e0");
      break;
    case "human":
    default:
      switch (character.hatType) {
        case "beanie":
          px(3, -2, 10, 3, "#4040a0");
          break;
        case "cap":
          px(2, -1, 12, 2, "#c04040");
          px(1, 0, 4, 1, "#a03030");
          break;
        case "hardhat":
          px(3, -2, 10, 3, "#f0c040");
          px(2, -1, 12, 1, "#f0c040");
          break;
        case "wizard":
          px(5, -5, 6, 2, "#6040a0");
          px(4, -3, 8, 2, "#6040a0");
          px(3, -1, 10, 2, "#6040a0");
          break;
        case "crown":
          px(4, -2, 8, 1, "#f0c040");
          px(4, -3, 2, 1, "#f0c040");
          px(7, -3, 2, 1, "#f0c040");
          px(10, -3, 2, 1, "#f0c040");
          break;
        case "headphones":
          px(2, 2, 2, 4, "#404040");
          px(12, 2, 2, 4, "#404040");
          px(3, 0, 10, 1, "#505050");
          break;
        case "beret":
          px(3, -1, 11, 2, "#c04040");
          px(3, -2, 8, 1, "#c04040");
          break;
        default:
          break;
      }
      px(4, 0, 8, 3, hair);
      px(3, 1, 1, 2, hair);
      px(12, 1, 1, 2, hair);
      px(4, 3, 8, 5, skin);
      px(5, 4, 2, 2, "#ffffff");
      px(6, 5, 1, 1, "#333333");
      px(9, 4, 2, 2, "#ffffff");
      px(10, 5, 1, 1, "#333333");
      switch (character.accessory) {
        case "glasses":
          px(4, 4, 3, 1, "#4060a0");
          px(7, 4, 1, 1, "#4060a0");
          px(8, 4, 3, 1, "#4060a0");
          break;
        case "sunglasses":
          px(4, 4, 3, 2, "#1a1a1a");
          px(7, 4, 1, 1, "#1a1a1a");
          px(8, 4, 3, 2, "#1a1a1a");
          break;
        case "scarf":
          px(3, 7, 10, 2, "#c04040");
          break;
        case "mask":
          px(4, 5, 8, 3, "#2a2a2a");
          break;
        case "earring":
          px(13, 4, 1, 2, "#f0c040");
          break;
        default:
          break;
      }
      px(3, 8, 10, 6, shirt);
      px(1, 9, 2, 5, shirt);
      px(13, 9, 2, 5, shirt);
      px(0, 13, 2, 2, skin);
      px(14, 13, 2, 2, skin);
      px(4, 14, 4, 4, pants);
      px(8, 14, 4, 4, pants);
      px(4 + (walkingFrame === 0 ? 0 : 1), 18, 3, 2, pants);
      px(9 - (walkingFrame === 0 ? 0 : 1), 18, 3, 2, pants);
      px(3 + (walkingFrame === 0 ? 0 : 1), 19, 4, 2, "#4a5060");
      px(9 - (walkingFrame === 0 ? 0 : 1), 19, 4, 2, "#4a5060");
      break;
  }
}

function drawSeatedCharacterBase(context: CanvasRenderingContext2D, character: CharacterDefinition, scale: number, typingFrame: 0 | 1) {
  const hair = `#${character.hairColor}`;
  const skin = `#${character.skinTone}`;
  const shirt = `#${character.shirtColor}`;
  const pants = `#${character.pantsColor}`;
  const shoes = character.species === "robot" ? "#708090" : character.species === "penguin" ? "#f0c040" : "#4a5060";
  const px = (x: number, y: number, w: number, h: number, color: string, alpha = 1) => drawPixelRect(context, x, y, w, h, color, scale, alpha);

  drawTemplateSprite(
    context,
    typingFrame === 0 ? BACK_TYPING_TEMPLATE_0 : BACK_TYPING_TEMPLATE_1,
    { H: hair, S: skin, T: shirt, P: pants, W: shoes },
    scale
  );

  switch (character.species) {
    case "cat":
    case "fox":
    case "bear":
    case "owl":
    case "panda":
      px(3, 0, 3, 3, hair);
      px(10, 0, 3, 3, hair);
      break;
    case "dog":
      px(2, 2, 2, 4, hair);
      px(12, 2, 2, 4, hair);
      break;
    case "rabbit":
      px(5, -4, 2, 6, skin);
      px(9, -4, 2, 6, skin);
      px(5, -3, 1, 4, "#f0a0a0");
      px(10, -3, 1, 4, "#f0a0a0");
      break;
    case "robot":
      px(7, -3, 2, 3, "#8090a0");
      px(6, -4, 4, 1, "#60f0a0");
      px(3, 0, 10, 6, "#a0b0c0", 0.95);
      px(4, 1, 8, 4, "#8090a0");
      px(5, 3, 2, 1, "#60f0a0");
      px(9, 3, 2, 1, "#60f0a0");
      break;
    case "penguin":
      px(4, 0, 8, 5, "#2a2a3a");
      px(5, 2, 6, 4, "#ffffff");
      px(7, 6, 2, 1, "#f0c040");
      px(4, 9, 8, 7, "#2a2a3a");
      px(5, 10, 6, 5, "#ffffff");
      break;
    default:
      break;
  }

  switch (character.hatType) {
    case "beanie":
      px(3, -1, 10, 3, "#4040a0");
      break;
    case "cap":
      px(2, -1, 12, 2, "#c04040");
      px(6, 1, 4, 1, "#a03030");
      break;
    case "hardhat":
      px(3, -2, 10, 3, "#f0c040");
      px(2, -1, 12, 1, "#f0c040");
      break;
    case "wizard":
      px(5, -5, 6, 2, "#6040a0");
      px(4, -3, 8, 2, "#6040a0");
      px(3, -1, 10, 2, "#6040a0");
      break;
    case "crown":
      px(4, -2, 8, 1, "#f0c040");
      px(4, -3, 2, 1, "#f0c040");
      px(7, -3, 2, 1, "#f0c040");
      px(10, -3, 2, 1, "#f0c040");
      break;
    case "headphones":
      px(2, 2, 2, 4, "#404040");
      px(12, 2, 2, 4, "#404040");
      px(3, 0, 10, 1, "#505050");
      break;
    case "beret":
      px(3, -1, 11, 2, "#c04040");
      px(3, -2, 8, 1, "#c04040");
      break;
    default:
      break;
  }

  if (character.accessory === "scarf") {
    px(4, 8, 8, 2, "#c04040");
  }
}

function drawCharacterBase(
  context: CanvasRenderingContext2D,
  character: CharacterDefinition,
  scale: number,
  pose: CharacterSpritePose,
  animationFrame: 0 | 1 = 0
) {
  if (pose === "typing") {
    drawSeatedCharacterBase(context, character, scale, animationFrame);
    return;
  }
  drawStandingCharacterBase(context, character, scale, pose === "roaming" ? animationFrame : 0);
}

const WINDOW_COLUMNS = [3, 4, 5, 9, 10, 11, 15, 16, 17, 21, 22, 23, 31, 32, 33, 37, 38, 39];

function drawRelativeRect(
  context: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  pxX: number,
  pxY: number,
  pxW: number,
  pxH: number,
  color: string,
  alpha = 1
) {
  context.globalAlpha = alpha;
  context.fillStyle = color;
  context.fillRect(x + (pxX / 108) * w, y + (pxY / 58) * h, (pxW / 108) * w, (pxH / 58) * h);
  context.globalAlpha = 1;
}

function drawCustomFurnitureSprite(context: CanvasRenderingContext2D, sprite: string[][], x: number, y: number, w: number, h: number) {
  const rows = Math.max(1, sprite.length);
  const cols = Math.max(1, ...sprite.map((row) => row.length || 0));
  const cellWidth = w / cols;
  const cellHeight = h / rows;
  for (let rowIndex = 0; rowIndex < sprite.length; rowIndex += 1) {
    const row = sprite[rowIndex] ?? [];
    for (let colIndex = 0; colIndex < row.length; colIndex += 1) {
      const color = (row[colIndex] ?? "").trim();
      if (!color) continue;
      context.fillStyle = color.startsWith("#") ? color : `#${color}`;
      context.fillRect(x + colIndex * cellWidth, y + rowIndex * cellHeight, cellWidth, cellHeight);
    }
  }
}

function drawFurnitureSprite(context: CanvasRenderingContext2D, kind: string, x: number, y: number, w: number, h: number, sprite?: string[][]) {
  if (Array.isArray(sprite) && sprite.length > 0) {
    drawCustomFurnitureSprite(context, sprite, x, y, w, h);
    return;
  }
  const px = (pxX: number, pxY: number, pxW: number, pxH: number, color: string, alpha = 1) => {
    drawRelativeRect(context, x, y, w, h, pxX, pxY, pxW, pxH, color, alpha);
  };

  switch (kind) {
    case "shelf":
      px(0, 0, 108, 58, "#5d4127");
      px(4, 4, 100, 12, "#6f4fc0");
      px(8, 17, 18, 35, "#d85c56");
      px(28, 17, 14, 33, "#4d86d9");
      px(44, 17, 12, 31, "#59b86d");
      px(58, 17, 10, 34, "#f2b34e");
      px(70, 17, 16, 30, "#8e67d9");
      px(88, 17, 12, 32, "#df8362");
      px(4, 28, 100, 10, "#f2b34e");
      px(6, 40, 96, 12, "#2d6dc2");
      break;
    case "picture":
      px(0, 0, 108, 58, "#6c4c2f");
      px(8, 6, 92, 46, "#7d5ad6");
      px(14, 12, 80, 34, "#d8e8f7");
      px(18, 16, 72, 14, "#8ec5f3");
      px(18, 30, 72, 12, "#7ab477");
      px(26, 20, 10, 10, "#f7e8a0");
      break;
    case "board":
      px(4, 4, 100, 34, "#eff4f8");
      px(10, 9, 88, 24, "#ffffff");
      px(0, 37, 8, 18, "#9aa5b2");
      px(100, 37, 8, 18, "#9aa5b2");
      px(16, 14, 22, 2, "#7aa4e5");
      px(16, 18, 30, 2, "#5eb978");
      px(16, 22, 26, 2, "#d77b63");
      break;
    case "plant":
      px(34, 34, 40, 14, "#9b6a3d");
      px(22, 10, 64, 26, "#56aa72");
      px(32, 2, 18, 16, "#2f8c48");
      px(58, 4, 18, 14, "#2f8c48");
      px(46, 16, 4, 18, "#3f7a3e");
      break;
    case "lamp":
      px(44, 4, 20, 18, "#f7e79d");
      px(51, 20, 6, 26, "#8d93a2");
      px(38, 46, 32, 8, "#6b7280");
      px(47, 42, 14, 4, "#a7afba");
      break;
    case "trash":
      px(36, 16, 36, 30, "#8a97a6");
      px(30, 10, 48, 8, "#c2cad2");
      px(41, 22, 3, 18, "#74808f");
      break;
    case "printer":
      px(18, 18, 72, 28, "#3f4753");
      px(22, 24, 64, 16, "#d6dde7");
      px(26, 12, 56, 10, "#778290");
      px(34, 4, 40, 12, "#ffffff");
      px(62, 28, 6, 6, "#40c040");
      break;
    case "water":
      px(30, 6, 48, 14, "#7bb8f5");
      px(30, 20, 48, 28, "#d7e8ff");
      px(36, 48, 36, 8, "#445164");
      px(42, 26, 8, 6, "#e06b6b");
      px(58, 26, 8, 6, "#4c79db");
      break;
    case "coffee":
      px(26, 8, 56, 42, "#707883");
      px(24, 2, 60, 10, "#42474f");
      px(38, 16, 32, 12, "#b4cad5");
      px(46, 30, 16, 12, "#f1ece4");
      px(62, 32, 4, 8, "#f1ece4");
      break;
    case "sofa":
      px(16, 18, 76, 26, "#6f4fc0");
      px(24, 8, 60, 16, "#8b66db");
      px(10, 22, 12, 22, "#6b49b9");
      px(86, 22, 12, 22, "#6b49b9");
      px(26, 28, 56, 10, "#7e5fd1");
      break;
    case "round-table":
      px(18, 12, 72, 34, "#5a432f");
      px(30, 18, 48, 16, "#73543b");
      px(50, 42, 8, 12, "#7a664f");
      break;
    case "meeting-table":
      px(8, 10, 92, 36, "#5a432f");
      px(20, 14, 68, 18, "#74553d");
      px(48, 44, 10, 10, "#7d684f");
      break;
    case "chair":
      px(30, 8, 48, 16, "#656c7a");
      px(26, 24, 56, 14, "#7a8290");
      px(46, 38, 16, 14, "#4f5868");
      px(24, 48, 10, 8, "#2e3440");
      px(74, 48, 10, 8, "#2e3440");
      break;
    default:
      px(20, 16, 68, 26, "#7d5ad6");
      break;
  }
}

function drawMainOfficeTile(context: CanvasRenderingContext2D, x: number, y: number, tileW: number, tileH: number, palette: ReturnType<typeof previewPalette>, row: number, col: number) {
  const topLeft = (row + col) % 2 === 0 ? withAlpha(palette.floorA, 0.96) : withAlpha(palette.floorB, 0.96);
  const topRight = (row + col + 1) % 2 === 0 ? withAlpha(palette.floorA, 0.92) : withAlpha(palette.floorB, 0.92);
  const bottomLeft = (row + col + 2) % 2 === 0 ? withAlpha(palette.floorA, 0.88) : withAlpha(palette.floorB, 0.88);
  const bottomRight = (row + col + 3) % 2 === 0 ? withAlpha(palette.floorA, 0.84) : withAlpha(palette.floorB, 0.84);
  context.fillStyle = topLeft;
  context.fillRect(x, y, tileW / 2, tileH / 2);
  context.fillStyle = topRight;
  context.fillRect(x + tileW / 2, y, tileW / 2, tileH / 2);
  context.fillStyle = bottomLeft;
  context.fillRect(x, y + tileH / 2, tileW / 2, tileH / 2);
  context.fillStyle = bottomRight;
  context.fillRect(x + tileW / 2, y + tileH / 2, tileW / 2, tileH / 2);
  context.fillStyle = withAlpha("#ffffff", 0.08);
  context.fillRect(x, y, tileW, 1);
  context.fillStyle = withAlpha("#000000", 0.12);
  context.fillRect(x + tileW / 2 - 0.5, y, 1, tileH);
  context.fillRect(x, y + tileH / 2 - 0.5, tileW, 1);
}

function drawPantryTile(context: CanvasRenderingContext2D, x: number, y: number, tileW: number, tileH: number, row: number, col: number) {
  const tileColor = (row + col) % 2 === 0 ? "#d9d0c0" : "#cfc4b0";
  context.fillStyle = tileColor;
  context.fillRect(x, y, tileW, tileH);
  context.fillStyle = withAlpha("#ffffff", 0.12);
  context.fillRect(x, y, tileW, 1);
  context.fillStyle = withAlpha("#6d6557", 0.14);
  context.fillRect(x + tileW - 1, y, 1, tileH);
  context.fillRect(x, y + tileH - 1, tileW, 1);
}

function drawMeetingTile(context: CanvasRenderingContext2D, x: number, y: number, tileW: number, tileH: number, row: number, col: number) {
  const tileColor = (row + col) % 2 === 0 ? "#35516c" : "#3e5d7a";
  context.fillStyle = tileColor;
  context.fillRect(x, y, tileW, tileH);
  context.fillStyle = withAlpha("#7eb9ff", 0.12);
  context.fillRect(x, y, tileW, 1);
  context.fillStyle = withAlpha("#0d1522", 0.18);
  context.fillRect(x + tileW - 1, y, 1, tileH);
  context.fillRect(x, y + tileH - 1, tileW, 1);
}

function drawOfficeDesk(context: CanvasRenderingContext2D, x: number, y: number, w: number, h: number) {
  context.fillStyle = "#6b4a2a";
  context.fillRect(x, y, w, h * 0.52);
  context.fillStyle = "#8d6238";
  context.fillRect(x, y + h * 0.08, w, h * 0.14);
  context.fillStyle = "#3a4b66";
  context.fillRect(x + w * 0.35, y + h * 0.08, w * 0.3, h * 0.22);
  context.fillStyle = "#0f1723";
  context.fillRect(x + w * 0.37, y + h * 0.1, w * 0.26, h * 0.16);
  context.fillStyle = "#4a5160";
  context.fillRect(x + w * 0.08, y + h * 0.62, w * 0.14, h * 0.26);
  context.fillRect(x + w * 0.78, y + h * 0.62, w * 0.14, h * 0.26);
  context.fillStyle = withAlpha("#ffffff", 0.08);
  context.fillRect(x, y, w, 1);
}

function drawDeskChair(context: CanvasRenderingContext2D, x: number, y: number, tileW: number, tileH: number) {
  drawFurnitureSprite(context, "chair", x + tileW * 0.08, y + tileH * 0.02, tileW * 0.84, tileH * 0.92);
}

function drawOfficeMapScene(
  context: CanvasRenderingContext2D,
  layout: OfficeLayoutPreset,
  themeId: WorkspaceBackgroundTheme,
  activeDeskSlots: DeskSlot[],
  visibleDecorItems: OfficeDecorItem[]
) {
  const theme = resolveSceneTheme(themeId);
  const palette = previewPalette(theme);
  const tileW = CANVAS_WIDTH / OFFICE_COLS;
  const tileH = CANVAS_HEIGHT / OFFICE_ROWS;

  context.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

  const sky = context.createLinearGradient(0, 0, 0, tileH * 2.1);
  sky.addColorStop(0, palette.skyTop);
  sky.addColorStop(1, palette.skyBottom);
  context.fillStyle = sky;
  context.fillRect(0, 0, CANVAS_WIDTH, tileH * 2);

  const wallColor = "#263c61";
  context.fillStyle = wallColor;
  context.fillRect(0, 0, CANVAS_WIDTH, tileH * 2);
  context.fillRect(0, 0, tileW, CANVAS_HEIGHT);
  context.fillRect(CANVAS_WIDTH - tileW, 0, tileW, CANVAS_HEIGHT);
  context.fillRect(0, CANVAS_HEIGHT - tileH, CANVAS_WIDTH, tileH);
  context.fillRect(tileW * 28, 0, tileW, CANVAS_HEIGHT);
  context.fillRect(tileW * (layout === "collab" ? 25 : layout === "focus" ? 26 : 29), tileH * (layout === "focus" ? 8 : 11), tileW * (layout === "collab" ? 16 : layout === "focus" ? 15 : 12), tileH);

  context.fillStyle = "#30496f";
  context.fillRect(0, tileH * 1.85, CANVAS_WIDTH, tileH * 0.15);
  context.fillStyle = "#71639f";
  context.fillRect(0, tileH * 1.7, CANVAS_WIDTH, tileH * 0.08);
  context.fillStyle = "#1e2d47";
  context.fillRect(0, tileH * 2, CANVAS_WIDTH, tileH * 0.1);

  const zones = {
    main: { x: tileW, y: tileH * 2, w: tileW * (layout === "focus" ? 24 : 27), h: tileH * 17 },
    pantry: { x: tileW * (layout === "focus" ? 26 : 29), y: tileH * 2, w: tileW * (layout === "collab" ? 8 : layout === "focus" ? 15 : 12), h: tileH * (layout === "focus" ? 6 : 9) },
    meeting: { x: tileW * (layout === "collab" ? 25 : layout === "focus" ? 26 : 29), y: tileH * (layout === "focus" ? 9 : 12), w: tileW * (layout === "collab" ? 16 : layout === "focus" ? 15 : 12), h: tileH * (layout === "focus" ? 10 : 7) }
  };

  for (let row = 2; row < OFFICE_ROWS - 1; row += 1) {
    for (let col = 1; col < OFFICE_COLS - 1; col += 1) {
      if (col === 28 && !((row >= 6 && row <= 7) || (row >= 14 && row <= 15))) continue;
      if (row === 11 && col >= 29 && !(layout === "focus" && col >= 26 && col < 41)) continue;
      const x = col * tileW;
      const y = row * tileH;
      if (col < 28) {
        drawMainOfficeTile(context, x, y, tileW, tileH, palette, row, col);
      } else if (row < 11) {
        drawPantryTile(context, x, y, tileW, tileH, row, col);
      } else {
        drawMeetingTile(context, x, y, tileW, tileH, row, col);
      }
    }
  }

  for (const rug of cozyRugs) {
    const color = rug.tone === "office" ? palette.rugOffice : rug.tone === "meeting" ? palette.rugMeeting : palette.rugPantry;
    context.fillStyle = withAlpha(color, 0.88);
    context.fillRect(rug.col * tileW, rug.row * tileH, rug.w * tileW, rug.h * tileH);
    context.strokeStyle = withAlpha("#ffffff", 0.14);
    context.strokeRect(rug.col * tileW + 0.5, rug.row * tileH + 0.5, rug.w * tileW - 1, rug.h * tileH - 1);
    context.strokeStyle = withAlpha("#dce8c8", 0.22);
    context.strokeRect(rug.col * tileW + tileW * 0.18, rug.row * tileH + tileH * 0.18, rug.w * tileW - tileW * 0.36, rug.h * tileH - tileH * 0.36);
  }

  for (const windowCol of WINDOW_COLUMNS) {
    const x = windowCol * tileW;
    context.fillStyle = "#f7f6f1";
    context.fillRect(x, tileH * 0.2, tileW, tileH * 0.95);
    context.fillStyle = "#8dc6f5";
    context.fillRect(x + 1, tileH * 0.38, tileW - 2, tileH * 0.52);
    context.fillStyle = "#ffffff";
    context.fillRect(x + 1, tileH * 0.22, tileW - 2, tileH * 0.16);
    context.fillStyle = "#7c63bf";
    context.fillRect(x, tileH * 1.55, tileW, tileH * 0.18);
    context.fillStyle = "#f2b04f";
    context.fillRect(x, tileH * 1.73, tileW, tileH * 0.12);
  }

  context.fillStyle = "#f3f0e4";
  context.fillRect(tileW * 30, tileH * 2.2, tileW * 0.75, tileH * 0.8);
  context.fillRect(tileW * 31.3, tileH * 2.1, tileW * 0.65, tileH * 1.1);
  context.fillStyle = "#7f94b9";
  context.fillRect(tileW * 32.3, tileH * 2.2, tileW * 0.65, tileH * 0.95);

  for (const slot of activeDeskSlots) {
    const x = slot.desk.col * tileW;
    const y = slot.desk.row * tileH;
    const w = slot.desk.w * tileW;
    const h = slot.desk.h * tileH;
    drawOfficeDesk(context, x, y, w, h);
    drawDeskChair(context, x + tileW * 0.85, y + tileH * 0.95, tileW * 0.9, tileH * 0.95);
  }

  const extraChairs = [
    { col: 35, row: 6 },
    { col: 38, row: 6 },
    { col: 36, row: 8 },
    { col: 37, row: 8 },
    { col: 33, row: 13 },
    { col: 36, row: 13 },
    { col: 33, row: 17 },
    { col: 36, row: 17 }
  ];

  for (const chair of extraChairs) {
    drawFurnitureSprite(context, "chair", chair.col * tileW, chair.row * tileH, tileW, tileH);
  }

  for (const item of visibleDecorItems) {
    drawFurnitureSprite(context, item.kind, item.col * tileW, item.row * tileH, item.w * tileW, item.h * tileH, item.sprite);
  }

  context.fillStyle = "#111826";
  context.fillRect(tileW * 28, tileH * 14, tileW, tileH * 2);
  const doorGradient = context.createLinearGradient(tileW * 28, 0, tileW * 29, 0);
  doorGradient.addColorStop(0, "#2b2f3f");
  doorGradient.addColorStop(1, "#9aa1af");
  context.fillStyle = doorGradient;
  context.fillRect(tileW * 29, tileH * 14, tileW, tileH * 2);

  context.fillStyle = "#9d6a3e";
  context.fillRect(tileW * 28, tileH * 6, tileW, tileH * 2);
  context.fillRect(tileW * 28, tileH * 14, tileW, tileH * 2);
  context.fillStyle = withAlpha("#000000", 0.16);
  context.fillRect(tileW * 28, tileH * 6, tileW, 1);
  context.fillRect(tileW * 28, tileH * 14, tileW, 1);
}

function drawOfficeForegroundScene(context: CanvasRenderingContext2D, activeDeskSlots: DeskSlot[]) {
  const tileW = CANVAS_WIDTH / OFFICE_COLS;
  const tileH = CANVAS_HEIGHT / OFFICE_ROWS;

  context.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

  for (const slot of activeDeskSlots) {
    const x = slot.desk.col * tileW;
    const y = slot.desk.row * tileH;
    const w = slot.desk.w * tileW;
    const h = slot.desk.h * tileH;
    drawOfficeDesk(context, x, y, w, h);
    drawDeskChair(context, x + tileW * 0.85, y + tileH * 0.95, tileW * 0.9, tileH * 0.95);
  }
}

export function PixelCharacterSprite(props: {
  character: CharacterDefinition;
  className?: string;
  scale?: number;
  pose?: CharacterSpritePose;
}) {
  const { character, className, scale = 3, pose = "idle" } = props;
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [animationFrame, setAnimationFrame] = useState<0 | 1>(0);

  useEffect(() => {
    if (pose === "idle") {
      setAnimationFrame(0);
      return;
    }
    const timer = window.setInterval(() => {
      setAnimationFrame((current) => (current === 0 ? 1 : 0));
    }, pose === "typing" ? 230 : 150);
    return () => window.clearInterval(timer);
  }, [pose]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    const width = 16 * scale;
    const height = 22 * scale;
    canvas.width = width;
    canvas.height = height;
    context.clearRect(0, 0, width, height);
    context.imageSmoothingEnabled = false;
    drawCharacterBase(context, character, scale, pose, animationFrame);
  }, [animationFrame, character, pose, scale]);

  return <canvas ref={canvasRef} className={className} width={16 * scale} height={22 * scale} />;
}

export function OfficeMapCanvas(props: {
  layout: OfficeLayoutPreset;
  themeId: WorkspaceBackgroundTheme;
  activeDeskSlots: DeskSlot[];
  visibleDecorItems: OfficeDecorItem[];
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;
    context.imageSmoothingEnabled = false;
    drawOfficeMapScene(context, props.layout, props.themeId, props.activeDeskSlots, props.visibleDecorItems);
  }, [props.activeDeskSlots, props.layout, props.themeId, props.visibleDecorItems]);

  return <canvas ref={canvasRef} className="office-map-canvas" width={CANVAS_WIDTH} height={CANVAS_HEIGHT} />;
}

export function OfficeDeskOverlayCanvas(props: {
  activeDeskSlots: DeskSlot[];
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    canvas.width = CANVAS_WIDTH;
    canvas.height = CANVAS_HEIGHT;
    context.imageSmoothingEnabled = false;
    drawOfficeForegroundScene(context, props.activeDeskSlots);
  }, [props.activeDeskSlots]);

  return <canvas ref={canvasRef} className="office-map-canvas office-map-overlay-canvas" width={CANVAS_WIDTH} height={CANVAS_HEIGHT} />;
}
