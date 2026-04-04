import type { PluginRuntimeSnapshot } from "./types";

export const emptyPluginRuntimeSnapshot: PluginRuntimeSnapshot = {
  pluginIds: [],
  characters: [],
  furniture: [],
  achievements: [],
  officePresets: [],
  themes: [],
  panels: [],
  commands: [],
  statusBar: [],
  effects: [],
  bossLines: []
};

let currentPluginRuntimeSnapshot: PluginRuntimeSnapshot = emptyPluginRuntimeSnapshot;

export function getPluginRuntimeSnapshot(): PluginRuntimeSnapshot {
  return currentPluginRuntimeSnapshot;
}

export function setPluginRuntimeSnapshot(snapshot: PluginRuntimeSnapshot) {
  currentPluginRuntimeSnapshot = {
    ...emptyPluginRuntimeSnapshot,
    ...snapshot,
    pluginIds: Array.isArray(snapshot?.pluginIds) ? snapshot.pluginIds : [],
    characters: Array.isArray(snapshot?.characters) ? snapshot.characters : [],
    furniture: Array.isArray(snapshot?.furniture) ? snapshot.furniture : [],
    achievements: Array.isArray(snapshot?.achievements) ? snapshot.achievements : [],
    officePresets: Array.isArray(snapshot?.officePresets) ? snapshot.officePresets : [],
    themes: Array.isArray(snapshot?.themes) ? snapshot.themes : [],
    panels: Array.isArray(snapshot?.panels) ? snapshot.panels : [],
    commands: Array.isArray(snapshot?.commands) ? snapshot.commands : [],
    statusBar: Array.isArray(snapshot?.statusBar) ? snapshot.statusBar : [],
    effects: Array.isArray(snapshot?.effects) ? snapshot.effects : [],
    bossLines: Array.isArray(snapshot?.bossLines) ? snapshot.bossLines : []
  };
}
