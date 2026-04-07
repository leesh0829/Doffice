// @ts-nocheck
import { app, BrowserWindow, clipboard, dialog, ipcMain, Menu, shell } from "electron";
import { execFile, spawn } from "node:child_process";
import fs from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { t, tf } from "../src/localizationCatalog";

const execFileAsync = promisify(execFile);

let mainWindow = null;
let workerIndex = 0;
let sessions = new Map();
let persistTimer = null;
let automationServer = null;
let sshProfiles = [];
let claudeStatus = {
  isInstalled: false,
  version: "",
  path: "",
  errorInfo: "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
};
let codexStatus = {
  isInstalled: false,
  version: "",
  path: "",
  errorInfo: "Codex CLI not found. Install with: npm install -g @openai/codex"
};
let geminiStatus = {
  isInstalled: false,
  version: "",
  path: "",
  errorInfo: "Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
};
const claudeModels = ["opus", "sonnet", "haiku"];
const codexModels = ["gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex", "gpt-5.2-codex", "gpt-5.2", "gpt-5.1-codex-max", "gpt-5.1-codex-mini"];
const geminiModels = ["gemini-2.5-pro", "gemini-2.5-flash"];
const cliDescriptors = {
  claude: {
    label: "Claude Code CLI",
    executableName: "claude",
    packageName: "@anthropic-ai/claude-code",
    errorInfo: "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
  },
  codex: {
    label: "Codex CLI",
    executableName: "codex",
    packageName: "@openai/codex",
    errorInfo: "Codex CLI not found. Install with: npm install -g @openai/codex"
  },
  gemini: {
    label: "Gemini CLI",
    executableName: "gemini",
    packageName: "@google/gemini-cli",
    errorInfo: "Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
  }
};
const dangerousPatterns = [
  { regex: /rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|.*--no-preserve-root)/i, severity: "Critical", description: "Force delete command" },
  { regex: /rm\s+-[a-zA-Z]*r[a-zA-Z]*\s+(\/|~|\$HOME)/i, severity: "Critical", description: "Recursive delete on root/home" },
  { regex: /git\s+push\s+.*--force/i, severity: "High", description: "Git force push" },
  { regex: /git\s+reset\s+--hard/i, severity: "High", description: "Git hard reset" },
  { regex: /git\s+clean\s+-[a-zA-Z]*f/i, severity: "Medium", description: "Git clean" },
  { regex: /DROP\s+(TABLE|DATABASE)/i, severity: "Critical", description: "Database deletion" },
  { regex: /DELETE\s+FROM\s+\w+\s*;/i, severity: "High", description: "Table-wide delete" },
  { regex: /chmod\s+(777|a\+rwx)/i, severity: "Medium", description: "Overly broad permissions" },
  { regex: /curl\s+.*\|\s*(sudo\s+)?(ba)?sh/i, severity: "Critical", description: "Remote script execution" },
  { regex: /wget\s+.*\|\s*(sudo\s+)?(ba)?sh/i, severity: "Critical", description: "Remote script execution" },
  { regex: /mkfs\./i, severity: "Critical", description: "Filesystem formatting" },
  { regex: /dd\s+if=/i, severity: "High", description: "Direct disk write" },
  { regex: />\s*\/dev\/sd/i, severity: "Critical", description: "Device write" },
  { regex: /sudo\s+rm\s+/i, severity: "High", description: "sudo delete" },
  { regex: /docker\s+system\s+prune\s+-a/i, severity: "Medium", description: "Docker full prune" },
  { regex: /kubectl\s+delete\s+(namespace|ns|deployment|pod)/i, severity: "High", description: "Kubernetes deletion" }
];
const sensitiveFilePatterns = [
  ".env",
  ".env.*",
  ".env.local",
  ".env.production",
  "credentials.json",
  "serviceAccountKey.json",
  "id_rsa",
  "id_ed25519",
  "*.pem",
  "*.key",
  "*.p12",
  "*.pfx",
  "*.jks",
  "*.keystore",
  "secrets.*",
  "secret.yaml",
  "secret.yml",
  ".aws/credentials",
  ".aws/config",
  ".ssh/*",
  ".netrc",
  ".npmrc",
  "*.cert",
  "*.crt",
  "token.json",
  "oauth_token*",
  ".git-credentials"
];
const slashCommandDescriptors = [
  { name: "help", usage: "[query]", description: "Show slash commands or filter them by keyword." },
  { name: "clear", usage: "", description: "Clear the current session log." },
  { name: "cancel", usage: "", description: "Stop the active Claude task for this session." },
  { name: "stop", usage: "", description: "Stop the active Claude task for this session." },
  { name: "copy", usage: "", description: "Copy the latest response-like block to the clipboard." },
  { name: "export", usage: "", description: "Export the current session log into the project folder." },
  { name: "stats", usage: "", description: "Show session statistics and current configuration." },
  { name: "config", usage: "", description: "Show the current session configuration." },
  { name: "errors", usage: "", description: "Show collected errors from the session log." },
  { name: "files", usage: "", description: "Show tracked file changes for this session." },
  { name: "tokens", usage: "", description: "Show token and cost usage for this session." },
  {
    name: "model",
    usage: "<opus|sonnet|haiku|gpt-5.4|gpt-5.4-mini|gemini-2.5-pro|gemini-2.5-flash>",
    description: "Change the default model for this session."
  },
  { name: "effort", usage: "<low|medium|high|max>", description: "Change the reasoning effort level." },
  { name: "output", usage: "<full|realtime|result>", description: "Set the output mode metadata used by the UI." },
  { name: "permission", usage: "<bypass|auto|default|plan|edits>", description: "Set the permission mode for the next run." },
  { name: "budget", usage: "<amount|off>", description: "Set or remove the max budget in USD." },
  { name: "system", usage: "<prompt|show|clear>", description: "Show, clear, or replace the session system prompt." },
  { name: "name", usage: "<value>", description: "Set or show the session name used for Claude." },
  { name: "continue", usage: "", description: "Use Claude continue mode when no session id is known." },
  { name: "resume", usage: "", description: "Resume the persisted Claude session when available." },
  { name: "fork", usage: "", description: "Enable fork-session mode for the next run." },
  { name: "worktree", usage: "", description: "Toggle worktree mode for this session." },
  { name: "chrome", usage: "", description: "Toggle Chrome integration for this session." },
  { name: "brief", usage: "", description: "Toggle brief output mode for this session." },
  { name: "tmux", usage: "[toggle|status|list|open|kill]", description: "Manage external raw terminal tmux sessions." }
];
const outputModeLabels = {
  full: "전체",
  realtime: "실시간",
  result: "결과만",
  resultonly: "결과만",
  "전체": "전체",
  "실시간": "실시간",
  "결과만": "결과만"
};
const permissionModeAliases = {
  bypass: "bypassPermissions",
  bypasspermissions: "bypassPermissions",
  auto: "auto",
  default: "default",
  plan: "plan",
  edits: "acceptEdits",
  edit: "acceptEdits",
  acceptedits: "acceptEdits"
};

function sessionStorePath() {
  return path.join(app.getPath("userData"), "sessions.json");
}

function sshProfilesPath() {
  return path.join(app.getPath("userData"), "ssh-profiles.json");
}

function automationServerPath() {
  return process.platform === "win32" ? "\\\\.\\pipe\\doffice.sock" : path.join(os.tmpdir(), "doffice.sock");
}

function automationServerTransport() {
  return process.platform === "win32" ? "named-pipe" : "unix-socket";
}

function currentAutomationServerStatus() {
  return {
    running: Boolean(automationServer?.listening),
    path: automationServerPath(),
    transport: automationServerTransport()
  };
}

function normalizeSSHProfile(raw) {
  const host = String(raw?.host ?? "").trim();
  const username = String(raw?.username ?? "").trim();
  const keyPath = String(raw?.keyPath ?? "").trim();
  const remoteWorkDir = String(raw?.remoteWorkDir ?? "").trim();
  const authMethod =
    raw?.authMethod === "password" || raw?.authMethod === "key" || raw?.authMethod === "agent"
      ? raw.authMethod
      : "agent";
  const profile = {
    id: String(raw?.id ?? crypto.randomUUID()),
    name: String(raw?.name ?? "").trim(),
    host,
    port: Math.max(1, Number(raw?.port) || 22),
    username,
    authMethod,
    keyPath,
    remoteWorkDir
  };
  return {
    ...profile,
    sshCommand: buildSSHCommand(profile)
  };
}

function buildSSHCommand(profile) {
  const host = String(profile?.host ?? "").trim();
  const username = String(profile?.username ?? "").trim();
  if (!host || !username) return "";
  let command = "ssh";
  if (Number(profile?.port) > 0 && Number(profile.port) !== 22) {
    command += ` -p ${Number(profile.port)}`;
  }
  if (profile?.authMethod === "key" && String(profile?.keyPath ?? "").trim()) {
    command += ` -i "${String(profile.keyPath).trim().replace(/"/g, '\\"')}"`;
  }
  command += ` ${username}@${host}`;
  if (String(profile?.remoteWorkDir ?? "").trim()) {
    const escapedDir = String(profile.remoteWorkDir).trim().replace(/'/g, "'\\''");
    command += ` -t "cd '${escapedDir}' && exec $SHELL -l"`;
  }
  return command;
}

async function loadSSHProfiles() {
  try {
    const raw = await fs.readFile(sshProfilesPath(), "utf8");
    const parsed = JSON.parse(raw);
    sshProfiles = Array.isArray(parsed) ? parsed.map((profile) => normalizeSSHProfile(profile)).filter((profile) => profile.host && profile.username) : [];
  } catch (error) {
    if (error?.code !== "ENOENT") {
      console.error("Failed to load SSH profiles", error);
    }
    sshProfiles = [];
  }
}

async function persistSSHProfiles() {
  await fs.mkdir(path.dirname(sshProfilesPath()), { recursive: true });
  await fs.writeFile(
    sshProfilesPath(),
    JSON.stringify(
      sshProfiles.map(({ sshCommand, ...profile }) => profile),
      null,
      2
    ),
    "utf8"
  );
}

async function saveSSHProfileRecord(rawProfile) {
  const nextProfile = normalizeSSHProfile(rawProfile);
  if (!nextProfile.host || !nextProfile.username) {
    throw new Error("SSH profile requires host and username.");
  }
  const index = sshProfiles.findIndex((profile) => profile.id === nextProfile.id);
  if (index >= 0) {
    sshProfiles[index] = nextProfile;
  } else {
    sshProfiles = [...sshProfiles, nextProfile];
  }
  await persistSSHProfiles();
  return sshProfiles;
}

async function deleteSSHProfileRecord(profileId) {
  sshProfiles = sshProfiles.filter((profile) => profile.id !== String(profileId ?? ""));
  await persistSSHProfiles();
  return sshProfiles;
}

async function openSSHProfile(profileId) {
  const profile = sshProfiles.find((item) => item.id === String(profileId ?? ""));
  if (!profile) {
    throw new Error("SSH profile not found");
  }
  const command = buildSSHCommand(profile);
  if (!command) {
    throw new Error("SSH command is empty");
  }

  if (process.platform === "win32") {
    try {
      const child = spawn("cmd.exe", ["/c", "start", "", "cmd.exe", "/k", command], {
        detached: true,
        windowsHide: false,
        shell: true,
        stdio: "ignore"
      });
      child.unref();
    } catch (error) {
      throw new Error(error?.message ?? "Failed to open SSH terminal");
    }
  } else {
    const shellPath = process.env.SHELL || "/bin/bash";
    const child = spawn(shellPath, ["-lc", command], {
      detached: true,
      stdio: "ignore"
    });
    child.unref();
  }

  return {
    ok: true,
    command,
    message: `Opened SSH connection for ${profile.name || `${profile.username}@${profile.host}`}`
  };
}

function bashSingleQuote(value) {
  return `'${String(value ?? "").replace(/'/g, "'\\''")}'`;
}

function tmuxSessionNameFor(session) {
  const normalizedId = String(session?.id ?? "session").replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 18) || "session";
  return `doffice-${normalizedId}`;
}

async function runRawShell(command) {
  if (process.platform === "win32") {
    return execFileAsync("wsl.exe", ["bash", "-lc", command], {
      windowsHide: true,
      env: process.env
    });
  }
  const shellPath = process.env.SHELL || "bash";
  return execFileAsync(shellPath, ["-lc", command], {
    windowsHide: true,
    env: process.env
  });
}

async function resolveTmuxPath() {
  try {
    const { stdout } = await runRawShell("command -v tmux || true");
    return String(stdout ?? "").trim();
  } catch {
    return "";
  }
}

async function listTmuxSessions() {
  const tmuxPath = await resolveTmuxPath();
  if (!tmuxPath) {
    return {
      available: false,
      path: "",
      sessions: []
    };
  }

  try {
    const { stdout } = await runRawShell("tmux list-sessions -F '#{session_name}\t#{session_windows}\t#{?session_attached,1,0}'");
    const sessions = String(stdout ?? "")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        const [sessionName, windowCount, attached] = line.split("\t");
        return {
          id: sessionName,
          sessionName,
          windowCount: Math.max(1, Number(windowCount) || 1),
          isAttached: attached === "1"
        };
      });
    return {
      available: true,
      path: tmuxPath,
      sessions
    };
  } catch (error) {
    const message = `${error?.stderr ?? ""}${error?.stdout ?? ""}${error?.message ?? ""}`.toLowerCase();
    if (message.includes("no server running")) {
      return {
        available: true,
        path: tmuxPath,
        sessions: []
      };
    }
    throw error;
  }
}

async function rawWorkingDirectoryForSession(session) {
  const projectPath = path.resolve(expandHomePath(String(session?.projectPath ?? "")) || process.cwd());
  if (process.platform !== "win32") {
    return projectPath;
  }
  const { stdout } = await execFileAsync("wsl.exe", ["wslpath", "-a", projectPath], {
    windowsHide: true,
    env: process.env
  });
  return String(stdout ?? "").trim() || projectPath;
}

async function ensureTmuxSession(session) {
  const tmuxPath = await resolveTmuxPath();
  if (!tmuxPath) {
    throw new Error("tmux is not installed in WSL.");
  }
  const sessionName = tmuxSessionNameFor(session);
  const workDir = await rawWorkingDirectoryForSession(session);
  await runRawShell(
    `tmux has-session -t ${bashSingleQuote(sessionName)} 2>/dev/null || tmux new-session -d -s ${bashSingleQuote(sessionName)} -c ${bashSingleQuote(workDir)}`
  );
  return { sessionName, workDir, path: tmuxPath };
}

async function killTmuxSession(session) {
  const sessionName = tmuxSessionNameFor(session);
  await runRawShell(`tmux kill-session -t ${bashSingleQuote(sessionName)}`);
  return sessionName;
}

async function openRawTerminal(sessionId) {
  const session = sessions.get(String(sessionId ?? ""));
  if (!session) {
    throw new Error("Session not found");
  }

  try {
    let command = "";
    if (session.tmuxMode) {
      const tmuxInfo = await ensureTmuxSession(session);
      command = `tmux attach-session -t ${bashSingleQuote(tmuxInfo.sessionName)}`;
      if (process.platform === "win32") {
        const child = spawn("cmd.exe", ["/c", "start", "", "wsl.exe", "bash", "-lc", command], {
          detached: true,
          windowsHide: false,
          stdio: "ignore"
        });
        child.unref();
      } else {
        const shellPath = process.env.SHELL || "/bin/bash";
        const child = spawn(shellPath, ["-lc", command], {
          detached: true,
          stdio: "ignore"
        });
        child.unref();
      }
      appendBlock(session, "status", `Opened raw tmux terminal: ${tmuxInfo.sessionName}`);
      return {
        ok: true,
        command,
        message: `Opened raw tmux terminal: ${tmuxInfo.sessionName}`
      };
    }

    const projectPath = path.resolve(expandHomePath(session.projectPath));
    command = process.platform === "win32" ? `cd /d "${projectPath}"` : `cd ${bashSingleQuote(projectPath)} && exec ${process.env.SHELL || "/bin/bash"} -l`;
    if (process.platform === "win32") {
      const child = spawn("cmd.exe", ["/c", "start", "", "cmd.exe", "/k", command], {
        detached: true,
        windowsHide: false,
        stdio: "ignore"
      });
      child.unref();
    } else {
      const shellPath = process.env.SHELL || "/bin/bash";
      const child = spawn(shellPath, ["-lc", command], {
        detached: true,
        stdio: "ignore"
      });
      child.unref();
    }
    appendBlock(session, "status", "Opened raw terminal for this session.");
    return {
      ok: true,
      command,
      message: "Opened raw terminal for this session."
    };
  } catch (error) {
    const message = String(error?.message ?? error ?? "Failed to open raw terminal");
    appendBlock(session, "error", message);
    return {
      ok: false,
      command: "",
      message
    };
  }
}

async function sendRawInput(payload) {
  const session = sessions.get(String(payload?.sessionId ?? ""));
  if (!session) {
    throw new Error("Session not found");
  }
  const text = String(payload?.text ?? "").replace(/\r\n/g, "\n").trim();
  if (!text) {
    return session;
  }

  session.lastPromptText = text;
  appendBlock(session, "userPrompt", text);

  try {
    if (session.tmuxMode) {
      const tmuxInfo = await ensureTmuxSession(session);
      await runRawShell(
        `tmux set-buffer -- ${bashSingleQuote(text)} && tmux paste-buffer -t ${bashSingleQuote(tmuxInfo.sessionName)} && tmux send-keys -t ${bashSingleQuote(tmuxInfo.sessionName)} Enter`
      );
      appendBlock(session, "status", `Sent prompt to tmux session ${tmuxInfo.sessionName}.`);
      return session;
    }

    clipboard.writeText(text);
    appendBlock(session, "status", "Raw terminal mode is external. Prompt copied to clipboard.");
    return session;
  } catch (error) {
    appendBlock(session, "error", String(error?.message ?? error ?? "Failed to send raw input"));
    return session;
  }
}

function pluginInstallBasePath() {
  return path.join(app.getPath("userData"), "plugins");
}

function expandHomePath(targetPath) {
  if (typeof targetPath !== "string") return "";
  if (targetPath === "~") return process.env.HOME || process.env.USERPROFILE || targetPath;
  if (targetPath.startsWith("~/") || targetPath.startsWith("~\\")) {
    const home = process.env.HOME || process.env.USERPROFILE;
    if (home) return path.join(home, targetPath.slice(2));
  }
  return targetPath;
}

function sanitizePluginSlug(value) {
  return String(value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || `plugin-${Date.now()}`;
}

async function ensureUniqueChildDir(parentDir, baseName) {
  let candidate = path.join(parentDir, baseName);
  let suffix = 2;
  while (true) {
    try {
      await fs.access(candidate);
      candidate = path.join(parentDir, `${baseName}-${suffix}`);
      suffix += 1;
    } catch {
      return candidate;
    }
  }
}

async function readPluginManifest(pluginDir) {
  const manifestPath = path.join(pluginDir, "plugin.json");
  const raw = await fs.readFile(manifestPath, "utf8");
  return { raw, manifest: JSON.parse(raw) };
}

function inferPluginTags(manifest) {
  const contributes = manifest?.contributes ?? {};
  const tags = new Set();
  if (contributes.characters) tags.add("characters");
  if (Array.isArray(contributes.themes) && contributes.themes.length > 0) tags.add("theme");
  if (Array.isArray(contributes.furniture) && contributes.furniture.length > 0) tags.add("furniture");
  if (Array.isArray(contributes.effects) && contributes.effects.length > 0) tags.add("effects");
  if (Array.isArray(contributes.achievements) && contributes.achievements.length > 0) tags.add("achievements");
  if (Array.isArray(contributes.officePresets) && contributes.officePresets.length > 0) tags.add("office-preset");
  return [...tags];
}

function normalizePluginRelativePath(value) {
  if (typeof value !== "string") return "";
  const normalized = value.replace(/\\/g, "/").trim();
  if (!normalized || /^https?:\/\//i.test(normalized) || normalized.startsWith("/")) {
    return "";
  }
  const safePath = path.posix.normalize(normalized);
  if (!safePath || safePath === "." || safePath.startsWith("../") || safePath.includes("/../")) {
    return "";
  }
  return safePath;
}

function collectPluginReferencedFiles(manifest) {
  const contributes = manifest?.contributes ?? {};
  const candidates = new Set(["README.md", "package.json"]);
  const add = (value) => {
    const nextValue = normalizePluginRelativePath(value);
    if (nextValue) candidates.add(nextValue);
  };

  add(contributes.characters);
  for (const panel of Array.isArray(contributes.panels) ? contributes.panels : []) {
    add(panel?.entry);
  }
  for (const command of Array.isArray(contributes.commands) ? contributes.commands : []) {
    add(command?.script);
  }
  for (const statusItem of Array.isArray(contributes.statusBar) ? contributes.statusBar : []) {
    add(statusItem?.script);
  }
  return [...candidates];
}

function bundledPluginPathForSource(source) {
  try {
    const url = new URL(source);
    const segments = url.pathname.split("/").filter(Boolean);
    const pluginsIndex = segments.lastIndexOf("plugins");
    const pluginId = pluginsIndex >= 0 ? segments[pluginsIndex + 1] : "";
    if (!pluginId) return null;
    return path.join(app.getAppPath(), "plugins", pluginId);
  } catch {
    return null;
  }
}

async function installLocalPluginDirectory(source, originalSource = source) {
  const resolvedSource = path.resolve(expandHomePath(source));
  const { manifest } = await readPluginManifest(resolvedSource);
  if (!manifest?.name) {
    throw new Error("Invalid plugin manifest: missing name");
  }
  const slug = sanitizePluginSlug(manifest?.name || path.basename(resolvedSource));
  const installDir = path.join(pluginInstallBasePath(), slug);
  await fs.mkdir(pluginInstallBasePath(), { recursive: true });
  await fs.rm(installDir, { recursive: true, force: true });
  await fs.cp(resolvedSource, installDir, { recursive: true, force: true });
  return {
    id: slug,
    title: String(manifest?.name || path.basename(resolvedSource)),
    source: originalSource,
    localPath: installDir,
    author: String(manifest?.author || "Unknown"),
    version: String(manifest?.version || ""),
    tags: inferPluginTags(manifest)
  };
}

async function maybeDownloadRelativeFile(baseUrl, installDir, relativePath) {
  if (typeof relativePath !== "string" || !relativePath.trim()) return;
  const response = await fetch(new URL(relativePath, baseUrl));
  if (!response.ok) return;
  const targetPath = path.join(installDir, relativePath);
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  await fs.writeFile(targetPath, await response.text(), "utf8");
}

async function installRemotePluginUrl(source) {
  const bundledPath = bundledPluginPathForSource(source);
  if (bundledPath) {
    try {
      return await installLocalPluginDirectory(bundledPath, source);
    } catch {
      // Fall back to remote download if local bundled assets are unavailable.
    }
  }

  const response = await fetch(source);
  if (!response.ok) {
    throw new Error(`Plugin download failed: ${response.status} ${response.statusText}`);
  }

  const raw = await response.text();
  const manifest = JSON.parse(raw);
  if (!manifest?.name) {
    throw new Error("Invalid plugin manifest: missing name");
  }
  const slug = sanitizePluginSlug(manifest?.name || path.basename(new URL(source).pathname, ".json"));
  const installDir = path.join(pluginInstallBasePath(), slug);
  await fs.mkdir(pluginInstallBasePath(), { recursive: true });
  await fs.rm(installDir, { recursive: true, force: true });
  await fs.mkdir(installDir, { recursive: true });
  await fs.writeFile(path.join(installDir, "plugin.json"), raw, "utf8");

  for (const relativePath of collectPluginReferencedFiles(manifest)) {
    await maybeDownloadRelativeFile(source, installDir, relativePath);
  }

  return {
    id: slug,
    title: String(manifest?.name || slug),
    source,
    localPath: installDir,
    author: String(manifest?.author || "Unknown"),
    version: String(manifest?.version || ""),
    tags: inferPluginTags(manifest)
  };
}

async function installPluginFromSource(source) {
  const trimmed = String(source ?? "").trim();
  if (!trimmed) {
    throw new Error("Plugin source is required");
  }
  if (/^https?:\/\//i.test(trimmed)) {
    return installRemotePluginUrl(trimmed);
  }
  return installLocalPluginDirectory(trimmed);
}

const pluginSpeciesEmoji = {
  human: "👤",
  cat: "🐱",
  dog: "🐶",
  rabbit: "🐰",
  bear: "🐻",
  penguin: "🐧",
  fox: "🦊",
  robot: "🤖",
  claude: "✨",
  alien: "👽",
  ghost: "👻",
  dragon: "🐉",
  chicken: "🐔",
  owl: "🦉",
  frog: "🐸",
  panda: "🐼",
  unicorn: "🦄",
  skeleton: "💀"
};

const pluginJobSkillLabels = {
  developer: "개발자",
  qa: "QA",
  reporter: "보고서",
  boss: "보스",
  planner: "기획자",
  reviewer: "리뷰어",
  designer: "디자이너",
  sre: "SRE"
};

function normalizePluginSpecies(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(pluginSpeciesEmoji, normalized) ? normalized : "human";
}

function normalizePluginJobRole(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(pluginJobSkillLabels, normalized) ? normalized : "developer";
}

function normalizePluginTier(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  switch (normalized) {
    case "mythic":
    case "legendary":
    case "epic":
    case "rare":
    case "common":
      return normalized;
    default:
      return "rare";
  }
}

function normalizePluginAchievementIcon(value) {
  const raw = String(value ?? "").trim();
  if (!raw) return "🏆";
  if (/\p{Extended_Pictographic}/u.test(raw)) return raw;
  switch (raw) {
    case "sun.max.fill":
      return "☀️";
    case "sofa.fill":
      return "🛋️";
    default:
      return "🏆";
  }
}

function normalizeHexToken(value, fallback = "") {
  const normalized = String(value ?? "").trim().replace(/^#/, "");
  return /^[0-9a-f]{3}([0-9a-f]{3})?$/i.test(normalized) ? normalized : fallback;
}

function normalizeStringMatrix(value) {
  if (!Array.isArray(value)) return [];
  return value.map((row) => (Array.isArray(row) ? row.map((cell) => normalizeHexToken(cell) || "") : []));
}

async function readPluginJSONFile(pluginDir, relativePath) {
  const safeRelativePath = normalizePluginRelativePath(relativePath);
  if (!safeRelativePath) {
    return null;
  }
  const targetPath = path.join(pluginDir, safeRelativePath);
  const raw = await fs.readFile(targetPath, "utf8");
  return JSON.parse(raw);
}

async function buildPluginRuntimeSnapshot(pluginDirs) {
  const snapshot = {
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
  const seenPluginIds = new Set();

  for (const rawPluginDir of Array.isArray(pluginDirs) ? pluginDirs : []) {
    const pluginDir = path.resolve(expandHomePath(String(rawPluginDir ?? "").trim()));
    if (!pluginDir) continue;
    try {
      const { manifest } = await readPluginManifest(pluginDir);
      const pluginName = String(manifest?.name || path.basename(pluginDir) || "Plugin").trim();
      const pluginId = sanitizePluginSlug(pluginName);
      if (!seenPluginIds.has(pluginId)) {
        seenPluginIds.add(pluginId);
        snapshot.pluginIds.push(pluginId);
      }

      const contributes = manifest?.contributes ?? {};

      if (contributes.characters) {
        const characters = await readPluginJSONFile(pluginDir, contributes.characters).catch(() => null);
        for (const entry of Array.isArray(characters) ? characters : []) {
          const species = normalizePluginSpecies(entry?.species);
          const jobRole = normalizePluginJobRole(entry?.jobRole);
          const shirtColor = normalizeHexToken(entry?.shirtColor, "7d5ad6");
          snapshot.characters.push({
            id: String(entry?.id || `${pluginId}-${snapshot.characters.length + 1}`),
            name: String(entry?.name || "Plugin"),
            role: String(entry?.archetype || entry?.role || "플러그인 캐릭터"),
            skill: pluginJobSkillLabels[jobRole],
            species,
            emoji: pluginSpeciesEmoji[species],
            hairColor: normalizeHexToken(entry?.hairColor, "4a3728"),
            skinTone: normalizeHexToken(entry?.skinTone, "ffd5b8"),
            shirtColor,
            pantsColor: normalizeHexToken(entry?.pantsColor, "3a4050"),
            hatType: String(entry?.hatType || "none"),
            accessory: String(entry?.accessory || "none"),
            requiredAchievement: typeof entry?.requiredAchievement === "string" ? entry.requiredAchievement : null,
            jobRole,
            isStarter: Boolean(entry?.isStarter || entry?.isHired),
            pluginId,
            pluginName
          });
        }
      }

      for (const item of Array.isArray(contributes.furniture) ? contributes.furniture : []) {
        const id = String(item?.id || "").trim();
        const sprite = normalizeStringMatrix(item?.sprite);
        if (!id || sprite.length === 0) continue;
        snapshot.furniture.push({
          id,
          name: String(item?.name || id),
          icon: "🧩",
          officeKinds: [id],
          width: Math.max(1, Number(item?.width) || 1),
          height: Math.max(1, Number(item?.height) || 1),
          isWallItem: String(item?.zone || "").toLowerCase() === "wall",
          requiredLevel: null,
          requiredAchievement: null,
          sprite,
          zone: String(item?.zone || "mainOffice"),
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.achievements) ? contributes.achievements : []) {
        const id = String(item?.id || "").trim();
        if (!id) continue;
        snapshot.achievements.push({
          id,
          tier: normalizePluginTier(item?.rarity),
          title: String(item?.name || id),
          subtitle: String(item?.description || pluginName),
          xp: Math.max(0, Number(item?.xp) || 0),
          icon: normalizePluginAchievementIcon(item?.icon),
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.officePresets) ? contributes.officePresets : []) {
        const id = String(item?.id || "").trim();
        if (!id) continue;
        snapshot.officePresets.push({
          id,
          name: String(item?.name || id),
          description: String(item?.description || ""),
          furniture: Array.isArray(item?.furniture)
            ? item.furniture
                .map((placement) => ({
                  furnitureId: String(placement?.furnitureId || "").trim(),
                  col: Number(placement?.col) || 0,
                  row: Number(placement?.row) || 0
                }))
                .filter((placement) => placement.furnitureId)
            : [],
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.themes) ? contributes.themes : []) {
        const id = String(item?.id || "").trim();
        if (!id) continue;
        snapshot.themes.push({
          id,
          name: String(item?.name || id),
          isDark: Boolean(item?.isDark),
          accentHex: normalizeHexToken(item?.accentHex, "7d5ad6"),
          bgHex: normalizeHexToken(item?.bgHex),
          cardHex: normalizeHexToken(item?.cardHex),
          textHex: normalizeHexToken(item?.textHex),
          greenHex: normalizeHexToken(item?.greenHex),
          redHex: normalizeHexToken(item?.redHex),
          yellowHex: normalizeHexToken(item?.yellowHex),
          purpleHex: normalizeHexToken(item?.purpleHex),
          cyanHex: normalizeHexToken(item?.cyanHex),
          useGradient: Boolean(item?.useGradient),
          gradientStartHex: normalizeHexToken(item?.gradientStartHex),
          gradientEndHex: normalizeHexToken(item?.gradientEndHex),
          fontName: String(item?.fontName || ""),
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.panels) ? contributes.panels : []) {
        const entry = normalizePluginRelativePath(item?.entry);
        const id = String(item?.id || "").trim();
        if (!id || !entry) continue;
        const htmlPath = path.join(pluginDir, entry);
        snapshot.panels.push({
          id,
          title: String(item?.title || id),
          icon: String(item?.icon || "square.grid.2x2"),
          entry: pathToFileURL(htmlPath).toString(),
          position: String(item?.position || "panel"),
          width: Number.isFinite(Number(item?.width)) ? Number(item.width) : null,
          height: Number.isFinite(Number(item?.height)) ? Number(item.height) : null,
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.commands) ? contributes.commands : []) {
        const script = normalizePluginRelativePath(item?.script);
        const id = String(item?.id || "").trim();
        if (!id || !script) continue;
        snapshot.commands.push({
          id,
          title: String(item?.title || id),
          icon: String(item?.icon || "terminal"),
          script: path.join(pluginDir, script),
          keybinding: typeof item?.keybinding === "string" ? item.keybinding : null,
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.statusBar) ? contributes.statusBar : []) {
        const script = normalizePluginRelativePath(item?.script);
        const id = String(item?.id || "").trim();
        if (!id || !script) continue;
        snapshot.statusBar.push({
          id,
          script: path.join(pluginDir, script),
          interval: Math.max(1, Number(item?.interval) || 30),
          pluginId,
          pluginName
        });
      }

      for (const item of Array.isArray(contributes.effects) ? contributes.effects : []) {
        const id = String(item?.id || "").trim();
        if (!id) continue;
        snapshot.effects.push({
          id,
          trigger: String(item?.trigger || ""),
          type: String(item?.type || ""),
          config: item?.config && typeof item.config === "object" ? item.config : {},
          enabled: item?.enabled !== false,
          pluginId,
          pluginName
        });
      }

      for (const line of Array.isArray(contributes.bossLines) ? contributes.bossLines : []) {
        if (typeof line === "string" && line.trim()) {
          snapshot.bossLines.push(line.trim());
        }
      }
    } catch {
      continue;
    }
  }

  return snapshot;
}

function resolvePluginScriptCommand(scriptPath) {
  const normalizedPath = path.resolve(String(scriptPath ?? ""));
  const extension = path.extname(normalizedPath).toLowerCase();
  switch (extension) {
    case ".cmd":
    case ".bat":
      return { command: normalizedPath, args: [], shell: true };
    case ".ps1":
      return { command: "powershell.exe", args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", normalizedPath], shell: false };
    case ".js":
    case ".mjs":
    case ".cjs":
      return { command: process.execPath, args: [normalizedPath], shell: false };
    case ".sh":
      return { command: "bash", args: [normalizedPath], shell: false };
    default:
      return { command: normalizedPath, args: [], shell: true };
  }
}

async function runPluginScript(scriptPath, projectPath) {
  const cwd = projectPath ? path.resolve(expandHomePath(String(projectPath))) : app.getAppPath();
  const { command, args, shell } = resolvePluginScriptCommand(scriptPath);
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      windowsHide: true,
      shell
    });
    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (chunk) => {
      stdout += String(chunk ?? "");
    });
    child.stderr?.on("data", (chunk) => {
      stderr += String(chunk ?? "");
    });
    child.on("error", (error) => {
      resolve({
        ok: false,
        output: error?.message || String(error),
        exitCode: -1
      });
    });
    child.on("close", (code) => {
      resolve({
        ok: code === 0,
        output: `${stdout}${stderr}`.trim(),
        exitCode: typeof code === "number" ? code : -1
      });
    });
  });
}

async function readPluginStatusBar(scriptPath, projectPath) {
  const result = await runPluginScript(scriptPath, projectPath);
  if (!result.ok) {
    return {
      text: result.output || "Plugin error",
      icon: "!",
      color: "#f14c4c"
    };
  }
  try {
    const parsed = JSON.parse(result.output || "{}");
    const rawColor = typeof parsed?.color === "string" ? parsed.color.trim() : "";
    return {
      text: typeof parsed?.text === "string" ? parsed.text : "",
      icon: typeof parsed?.icon === "string" ? parsed.icon : "",
      color: rawColor ? (rawColor.startsWith("#") ? rawColor : `#${rawColor}`) : ""
    };
  } catch {
    return {
      text: result.output || "",
      icon: "",
      color: ""
    };
  }
}

async function createPluginTemplate(parentDir) {
  const resolvedParent = path.resolve(expandHomePath(String(parentDir ?? "").trim()));
  if (!resolvedParent) {
    throw new Error("Plugin parent directory is required");
  }

  await fs.mkdir(resolvedParent, { recursive: true });
  const templateDir = await ensureUniqueChildDir(resolvedParent, "doffice-plugin");
  const manifest = {
    name: "New Doffice Plugin",
    version: "0.1.1",
    description: "Starter plugin template for Doffice Windows.",
    author: "Doffice",
    contributes: {
      effects: []
    }
  };
  const packageManifest = {
    name: path.basename(templateDir),
    version: "0.1.1",
    description: "Starter plugin template for Doffice Windows."
  };
  const readme = [
    "# New Doffice Plugin",
    "",
    "1. Edit `plugin.json` and add your contributions.",
    "2. Re-enable or reinstall this plugin from Settings > Plugins after changes.",
    "3. Add assets next to `plugin.json` as needed."
  ].join("\n");

  await fs.mkdir(templateDir, { recursive: true });
  await fs.writeFile(path.join(templateDir, "plugin.json"), JSON.stringify(manifest, null, 2), "utf8");
  await fs.writeFile(path.join(templateDir, "package.json"), JSON.stringify(packageManifest, null, 2), "utf8");
  await fs.writeFile(path.join(templateDir, "README.md"), readme, "utf8");

  return {
    id: sanitizePluginSlug(path.basename(templateDir)),
    title: manifest.name,
    source: templateDir,
    localPath: templateDir,
    author: manifest.author,
    version: manifest.version,
    tags: ["starter"]
  };
}

function normalizeProjectPaths(projectPaths = []) {
  const fromSessions = [...sessions.values()].map((session) => session.projectPath);
  return Array.from(
    new Set(
      [...projectPaths, ...fromSessions]
        .filter((value) => typeof value === "string")
        .map((value) => String(value).trim())
        .filter(Boolean)
    )
  );
}

async function listReports(projectPaths = []) {
  const references = [];
  for (const projectPath of normalizeProjectPaths(projectPaths)) {
    const projectName =
      [...sessions.values()].find((session) => session.projectPath === projectPath)?.projectName ?? path.basename(projectPath) ?? "Project";
    const reportsDir = path.join(projectPath, ".workman", "reports");
    let entries = [];
    try {
      entries = await fs.readdir(reportsDir, { withFileTypes: true });
    } catch {
      continue;
    }

    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
      const reportPath = path.join(reportsDir, entry.name);
      let updatedAt = new Date(0).toISOString();
      try {
        const stats = await fs.stat(reportPath);
        updatedAt = stats.mtime.toISOString();
      } catch {
        // keep epoch fallback when stat is unavailable
      }
      references.push({
        id: reportPath,
        projectName,
        projectPath,
        path: reportPath,
        fileName: entry.name,
        updatedAt
      });
    }
  }

  return references.sort((lhs, rhs) => {
    const timeDiff = new Date(rhs.updatedAt).getTime() - new Date(lhs.updatedAt).getTime();
    if (timeDiff !== 0) return timeDiff;
    return lhs.path.localeCompare(rhs.path, "ko");
  });
}

async function readReport(reportPath) {
  const content = await fs.readFile(reportPath, "utf8");
  return { path: reportPath, content };
}

function reportDirectoryForSession(session) {
  return path.join(session.projectPath, ".workman", "reports");
}

function reportTimestampStamp(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  const seconds = String(date.getSeconds()).padStart(2, "0");
  return `${year}${month}${day}-${hours}${minutes}${seconds}`;
}

function safeProjectSlug(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function makeReportPath(session, generatedAt = new Date()) {
  const slug = safeProjectSlug(session.projectName) || "report";
  return path.join(reportDirectoryForSession(session), `${reportTimestampStamp(generatedAt)}-${slug}-report.md`);
}

async function ensureReportDirectoryExists(reportPath) {
  await fs.mkdir(path.dirname(reportPath), { recursive: true });
}

function promptRequestsReport(prompt) {
  return /(보고서|마크다운|markdown|\breport\b)/i.test(String(prompt ?? ""));
}

function latestReportBody(session) {
  const direct = sanitizeText(session.lastResultText);
  if (direct) {
    return direct;
  }

  const block = [...session.blocks]
    .reverse()
    .find((entry) => ["thought", "toolOutput", "status", "completion", "error", "toolError"].includes(entry.kind) && sanitizeText(entry.content));
  return block ? sanitizeText(block.content) : "";
}

function collectUniqueFileChanges(session) {
  const seen = new Set();
  const items = [];
  for (const change of session.fileChanges ?? []) {
    const filePath = String(change?.path ?? "").trim();
    if (!filePath || seen.has(filePath)) continue;
    seen.add(filePath);
    items.push({
      path: filePath,
      action: String(change?.action ?? "Edit")
    });
  }
  return items;
}

function collectRecentErrors(session, limit = 6) {
  return [...session.blocks]
    .filter((block) => block.kind === "error" || block.kind === "toolError")
    .map((block) => sanitizeText(block.content))
    .filter(Boolean)
    .slice(-limit);
}

function quoteMarkdown(value) {
  const normalized = sanitizeText(value);
  if (!normalized) {
    return "> 없음";
  }
  return normalized
    .split("\n")
    .map((line) => `> ${line || " "}`)
    .join("\n");
}

function buildFallbackReportBody(session) {
  const summary = latestReportBody(session) || "이번 작업에 대한 최종 요약이 기록되지 않았습니다.";
  return [`# ${session.projectName} 작업 보고서`, "", "## 결과 요약", "", summary].join("\n");
}

function buildSessionReportMarkdown(session, reportPath, generatedAtIso) {
  const generatedAt = new Date(generatedAtIso);
  const reportBody = latestReportBody(session);
  const fileChanges = collectUniqueFileChanges(session);
  const recentErrors = collectRecentErrors(session);
  const branchName = session.branch || session.gitInfo?.branch || "-";
  const body = reportBody || buildFallbackReportBody(session);
  const metadata = [
    "## 세션 메타데이터",
    "",
    `- 생성 시각: ${new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium", timeStyle: "medium" }).format(generatedAt)}`,
    `- 프로젝트: ${session.projectName}`,
    `- 프로젝트 경로: \`${session.projectPath}\``,
    `- 보고서 경로: \`${reportPath}\``,
    `- 워커: ${session.workerName}`,
    `- Provider / Model: ${titleCase(session.provider || providerForModel(session.selectedModel))} / ${session.selectedModel || "-"}`,
    `- 세션 ID: ${session.sessionId || "-"}`,
    `- 브랜치: \`${branchName}\``,
    "",
    "## 요청",
    "",
    quoteMarkdown(session.lastPromptText),
    "",
    "## 변경 파일",
    "",
    ...(fileChanges.length > 0 ? fileChanges.map((change) => `- [${change.action}] \`${change.path}\``) : ["- 없음"]),
    "",
    "## 세션 통계",
    "",
    `- 완료 프롬프트 수: ${session.completedPromptCount}`,
    `- 입력 토큰: ${session.inputTokensUsed}`,
    `- 출력 토큰: ${session.outputTokensUsed}`,
    `- 총 토큰: ${session.tokensUsed}`,
    `- 비용(USD): ${session.totalCost.toFixed(4)}`,
    `- Git 변경 파일 수: ${Number(session.gitInfo?.changedFiles ?? 0)}`,
    `- 마지막 커밋: ${session.gitInfo?.lastCommit ? `${session.gitInfo.lastCommit} (${session.gitInfo.lastCommitAge || "-"})` : "-"}`,
    ""
  ];

  if (recentErrors.length > 0) {
    metadata.push("## 최근 오류", "", ...recentErrors.map((entry) => `- ${entry}`), "");
  }

  return [body.trim(), "", "---", "", ...metadata].join("\n");
}

function shouldAutoGenerateReport(session) {
  return promptRequestsReport(session.lastPromptText) || session.fileChanges.length > Number(session.lastReportedFileChangeCount ?? 0);
}

async function saveSessionReport(session) {
  if (!session.projectPath || !shouldAutoGenerateReport(session)) {
    return;
  }

  const generatedAtIso = nowIso();
  const reportPath = makeReportPath(session, new Date(generatedAtIso));
  const markdown = buildSessionReportMarkdown(session, reportPath, generatedAtIso);
  try {
    await ensureReportDirectoryExists(reportPath);
    await fs.writeFile(reportPath, markdown, "utf8");
    session.lastReportPath = reportPath;
    session.lastReportGeneratedAt = generatedAtIso;
    session.lastReportedFileChangeCount = session.fileChanges.length;
    appendBlock(session, "status", `Markdown 보고서 저장: ${path.basename(reportPath)}`, { reportPath });
  } catch (error) {
    appendBlock(session, "error", `보고서 저장 실패: ${String(error?.message ?? error)}`);
  }
}

async function finalizeSessionCompletion(session) {
  await refreshGitInfo(session);
  await saveSessionReport(session);
  emitSessions();
}

function isCodexModel(value) {
  return codexModels.includes(String(value ?? "").trim());
}

function isGeminiModel(value) {
  return geminiModels.includes(String(value ?? "").trim());
}

function isClaudeModel(value) {
  return claudeModels.includes(String(value ?? "").trim());
}

function normalizeProvider(value) {
  const provider = String(value ?? "").trim().toLowerCase();
  if (provider === "codex" || provider === "gemini") {
    return provider;
  }
  return "claude";
}

function providerForModel(value) {
  if (isGeminiModel(value)) {
    return "gemini";
  }
  if (isCodexModel(value)) {
    return "codex";
  }
  return "claude";
}

function defaultModelForProvider(provider) {
  switch (normalizeProvider(provider)) {
    case "codex":
      return "gpt-5.4";
    case "gemini":
      return "gemini-2.5-pro";
    case "claude":
    default:
      return "sonnet";
  }
}

function cliStatusForProvider(provider) {
  switch (normalizeProvider(provider)) {
    case "codex":
      return codexStatus;
    case "gemini":
      return geminiStatus;
    case "claude":
    default:
      return claudeStatus;
  }
}

function titleCase(value) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function sessionStartContent(session) {
  const lines = [`Provider: ${titleCase(session.provider || providerForModel(session.selectedModel))}`, `Model: ${titleCase(session.selectedModel || "sonnet")}`];
  if (session.sessionId) {
    lines.push(`Session: ${session.sessionId}`);
  }
  return lines.join("\n");
}

function replaceSessionStartBlock(session) {
  const block = createBlock("sessionStart", sessionStartContent(session));
  if (session.blocks.length > 0 && session.blocks[0]?.kind === "sessionStart") {
    session.blocks[0] = block;
    return;
  }
  session.blocks = [block, ...session.blocks];
}

function normalizeOutputMode(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  return outputModeLabels[normalized] ?? null;
}

function formatOutputMode(value) {
  const raw = String(value ?? "").trim();
  return normalizeOutputMode(value) ?? (raw || "전체");
}

function formatPermissionModeLabel(value) {
  switch (String(value ?? "")) {
    case "acceptEdits":
      return lt("perm.acceptEdits");
    case "bypassPermissions":
      return lt("perm.bypass");
    case "auto":
      return lt("perm.auto");
    case "plan":
      return lt("perm.plan");
    case "default":
    default:
      return lt("perm.default");
  }
}

function toggleLabel(enabled) {
  return enabled ? lt("slash.toggle.on") : lt("slash.toggle.off");
}

function formatBudget(value) {
  return Number(value) > 0 ? `$${Number(value).toFixed(2)}` : "Unlimited";
}

function locale() {
  try {
    return app.getLocale();
  } catch {
    return undefined;
  }
}

function lt(key) {
  return t(key, locale());
}

function ltf(key, ...args) {
  return tf(key, locale(), ...args);
}

function latestCopyableContent(session) {
  const candidate = [...session.blocks].reverse().find((block) => {
    if (!String(block.content ?? "").trim()) return false;
    return (
      block.kind === "thought" ||
      block.kind === "completion" ||
      block.kind === "text" ||
      block.kind === "toolOutput" ||
      block.kind === "status"
    );
  });
  return candidate?.content?.trim() ?? "";
}

function formatLogLine(block) {
  switch (block.kind) {
    case "userPrompt":
      return `> ${block.content}`;
    case "thought":
      return `💭 ${block.content}`;
    case "toolUse":
      return `⏺ ${block.content}`;
    case "toolOutput":
      return `⎿ ${block.content}`;
    case "toolError":
      return `✗ ${block.content}`;
    case "status":
      return `ℹ ${block.content}`;
    case "completion":
      return `✅ ${block.content}`;
    case "error":
      return `🚨 ${block.content}`;
    case "fileChange":
      return `✎ ${block.content}`;
    default:
      return block.content;
  }
}

function formatSessionLog(session) {
  const header = [
    `Project: ${session.projectName}`,
    `Path: ${session.projectPath}`,
    `Worker: ${session.workerName}`,
    `Model: ${session.selectedModel}`,
    `Effort: ${session.effortLevel}`,
    `Permission: ${session.permissionMode}`,
    `Budget: ${formatBudget(session.maxBudgetUSD)}`,
    `Started: ${session.startTime}`,
    ""
  ];
  return [...header, ...session.blocks.map((block) => formatLogLine(block))].join("\n");
}

function formatSessionStats(session) {
  const elapsedMs = Math.max(0, Date.now() - new Date(session.startTime).getTime());
  const elapsedMinutes = Math.floor(elapsedMs / 60000);
  const elapsedSeconds = Math.floor((elapsedMs % 60000) / 1000);
  const none = lt("custom.none");
  const lines = [
    lt("custom.session.stats"),
    `- Project: ${session.projectName}`,
    `- Worker: ${session.workerName}`,
    `- Model: ${session.selectedModel}`,
    `- Effort: ${session.effortLevel}`,
    `- Output: ${formatOutputMode(session.outputMode)}`,
    `- Permission: ${formatPermissionModeLabel(session.permissionMode)}`,
    `- Budget: ${formatBudget(session.maxBudgetUSD)}`,
    `- ${lt("custom.system.prompt")}: ${session.systemPrompt ? session.systemPrompt.slice(0, 120) : none}`,
    `- Worktree: ${toggleLabel(session.useWorktree)}`,
    `- Chrome: ${toggleLabel(session.enableChrome)}`,
    `- Brief: ${toggleLabel(session.enableBrief)}`,
    `- Tokens: ${session.tokensUsed}`,
    `- Completed Prompts: ${session.completedPromptCount}`,
    `- ${lt("custom.file.changes")}: ${session.fileChanges.length}`,
    `- ${lt("custom.elapsed")}: ${elapsedMinutes}m ${elapsedSeconds}s`
  ];
  return lines.join("\n");
}

function formatSessionConfig(session) {
  const none = lt("custom.none");
  const lines = [
    lt("custom.session.config.title"),
    `- ${lt("custom.session.name")}: ${session.sessionName || none}`,
    `- Model: ${session.selectedModel}`,
    `- Effort: ${session.effortLevel}`,
    `- Output: ${formatOutputMode(session.outputMode)}`,
    `- Permission: ${formatPermissionModeLabel(session.permissionMode)}`,
    `- Budget: ${formatBudget(session.maxBudgetUSD)}`,
    `- ${lt("custom.system.prompt")}: ${session.systemPrompt ? session.systemPrompt.slice(0, 120) : none}`,
    `- ${lt("custom.continue.session")}: ${toggleLabel(session.continueSession)}`,
    `- ${lt("custom.resume.session.id")}: ${session.sessionId || none}`,
    `- ${lt("custom.fork.on.run")}: ${toggleLabel(session.forkSession)}`,
    `- Worktree: ${toggleLabel(session.useWorktree)}`,
    `- ${lt("custom.fallback.model")}: ${session.fallbackModel || none}`,
    `- Chrome: ${toggleLabel(session.enableChrome)}`,
    `- Brief: ${toggleLabel(session.enableBrief)}`
  ];
  return lines.join("\n");
}

function formatSessionErrors(session) {
  const errors = session.blocks.filter((block) => block.kind === "error" || block.kind === "toolError");
  if (errors.length === 0) {
    return lt("custom.no.session.errors");
  }
  return [
    `Errors (${errors.length})`,
    ...errors.slice(-12).map((block, index) => `${index + 1}. ${String(block.content ?? "").slice(0, 240)}`)
  ].join("\n");
}

function formatSessionFiles(session) {
  if (session.fileChanges.length === 0) {
    return lt("custom.no.session.files");
  }
  const unique = new Map();
  for (const change of session.fileChanges) {
    unique.set(change.path, change);
  }
  return [
    `Files (${session.fileChanges.length} changes / ${unique.size} unique files)`,
    ...[...unique.values()].slice(-20).map((change) => `- [${change.action}] ${change.path}`)
  ].join("\n");
}

function formatSessionTokens(session) {
  return [
    lt("custom.token.usage"),
    `- Total: ${session.tokensUsed}`,
    `- Input: ${session.inputTokensUsed}`,
    `- Output: ${session.outputTokensUsed}`,
    `- Cost: $${Number(session.totalCost ?? 0).toFixed(4)}`,
    `- Completed Prompts: ${session.completedPromptCount}`
  ].join("\n");
}

function formatSlashHelp(query) {
  const normalized = String(query ?? "").trim().toLowerCase();
  const commands = normalized
    ? slashCommandDescriptors.filter(
        (descriptor) =>
          descriptor.name.includes(normalized) ||
          descriptor.description.toLowerCase().includes(normalized) ||
          descriptor.usage.toLowerCase().includes(normalized)
      )
    : slashCommandDescriptors;

  if (commands.length === 0) {
    return `${lt("custom.command.no.matches")} "${query}".`;
  }

  return [
    lt("custom.slash.commands"),
    ...commands.map((descriptor) => `/${descriptor.name}${descriptor.usage ? ` ${descriptor.usage}` : ""} - ${descriptor.description}`)
  ].join("\n");
}

function parseSlashCommand(commandText) {
  const trimmed = String(commandText ?? "").trim();
  const withoutPrefix = trimmed.startsWith("/") ? trimmed.slice(1).trim() : trimmed;
  const firstSpace = withoutPrefix.search(/\s/);
  if (firstSpace === -1) {
    return { name: withoutPrefix.toLowerCase(), args: [], remainder: "" };
  }
  const name = withoutPrefix.slice(0, firstSpace).toLowerCase();
  const remainder = withoutPrefix.slice(firstSpace + 1).trim();
  return {
    name,
    args: remainder ? remainder.split(/\s+/) : [],
    remainder
  };
}

function cloneForPersistence(session) {
  const { child, ...persisted } = session;
  return persisted;
}

function cloneRendererSafe(value) {
  return JSON.parse(JSON.stringify(value));
}

function serializeSessionForRenderer(session) {
  const { child, ...safeSession } = session;
  return cloneRendererSafe({
    ...safeSession,
    pendingApproval:
      safeSession.pendingApproval && typeof safeSession.pendingApproval === "object"
        ? { ...safeSession.pendingApproval }
        : null,
    gitInfo: safeSession.gitInfo && typeof safeSession.gitInfo === "object" ? { ...safeSession.gitInfo } : null,
    lastToolUse: safeSession.lastToolUse && typeof safeSession.lastToolUse === "object" ? { ...safeSession.lastToolUse } : null,
    blocks: Array.isArray(safeSession.blocks)
      ? safeSession.blocks.map((block) => ({
          ...block,
          meta: block?.meta && typeof block.meta === "object" ? cloneRendererSafe(block.meta) : {}
        }))
      : [],
    fileChanges: Array.isArray(safeSession.fileChanges) ? safeSession.fileChanges.map((change) => ({ ...change })) : []
  });
}

function sessionsForRenderer() {
  return [...sessions.values()].sort((a, b) => a.tabOrder - b.tabOrder).map((session) => serializeSessionForRenderer(session));
}

function normalizeSession(raw) {
  const session = {
    ...raw,
    blocks: Array.isArray(raw?.blocks) ? raw.blocks : [],
    fileChanges: Array.isArray(raw?.fileChanges) ? raw.fileChanges : [],
    pendingApproval:
      raw?.pendingApproval && typeof raw.pendingApproval === "object"
        ? {
            command: String(raw.pendingApproval.command ?? ""),
            reason: String(raw.pendingApproval.reason ?? ""),
            toolName: String(raw.pendingApproval.toolName ?? ""),
            retryMode: String(raw.pendingApproval.retryMode ?? "default")
          }
        : null,
    gitInfo: {
      branch: String(raw?.gitInfo?.branch ?? raw?.branch ?? ""),
      changedFiles: Number(raw?.gitInfo?.changedFiles ?? 0),
      lastCommit: String(raw?.gitInfo?.lastCommit ?? ""),
      lastCommitAge: String(raw?.gitInfo?.lastCommitAge ?? ""),
      isGitRepo: Boolean(raw?.gitInfo?.isGitRepo)
    },
    tabOrder: Number(raw?.tabOrder ?? 0),
    isProcessing: false,
    isRunning: false,
    claudeActivity: "idle",
    lastToolUse: null,
    lastReportPath: String(raw?.lastReportPath ?? ""),
    lastReportGeneratedAt: String(raw?.lastReportGeneratedAt ?? ""),
    lastReportedFileChangeCount: Number(raw?.lastReportedFileChangeCount ?? 0),
    dangerousCommandWarning: typeof raw?.dangerousCommandWarning === "string" ? raw.dangerousCommandWarning : null,
    sensitiveFileWarning: typeof raw?.sensitiveFileWarning === "string" ? raw.sensitiveFileWarning : null,
    child: null
  };

  session.selectedModel = String(raw?.selectedModel ?? "sonnet");
  session.provider = normalizeProvider(raw?.provider ?? providerForModel(session.selectedModel));
  session.effortLevel = String(raw?.effortLevel ?? "medium");
  session.outputMode = normalizeOutputMode(raw?.outputMode) ?? "전체";
  session.permissionMode = String(raw?.permissionMode ?? "bypassPermissions");
  session.codexSandboxMode =
    raw?.codexSandboxMode === "read-only" || raw?.codexSandboxMode === "danger-full-access"
      ? raw.codexSandboxMode
      : "workspace-write";
  session.codexApprovalPolicy =
    raw?.codexApprovalPolicy === "untrusted" || raw?.codexApprovalPolicy === "never"
      ? raw.codexApprovalPolicy
      : "on-request";
  session.systemPrompt = String(raw?.systemPrompt ?? "");
  session.maxBudgetUSD = Number(raw?.maxBudgetUSD ?? 0);
  session.sessionName = String(raw?.sessionName ?? "");
  session.continueSession = Boolean(raw?.continueSession);
  session.useWorktree = Boolean(raw?.useWorktree);
  session.fallbackModel = String(raw?.fallbackModel ?? "");
  session.enableChrome = raw?.enableChrome == null ? true : Boolean(raw.enableChrome);
  session.forkSession = Boolean(raw?.forkSession);
  session.enableBrief = Boolean(raw?.enableBrief);
  session.pluginDirs = Array.isArray(raw?.pluginDirs) ? raw.pluginDirs.filter((value) => typeof value === "string" && value.trim()) : [];
  replaceSessionStartBlock(session);

  if (raw?.isProcessing) {
    session.blocks = [
      ...session.blocks,
      createBlock("status", lt("custom.restored.session"))
    ];
  }

  return session;
}

async function persistSessions() {
  const payload = {
    workerIndex,
    lastSavedAt: nowIso(),
    sessions: [...sessions.values()]
      .sort((a, b) => a.tabOrder - b.tabOrder)
      .map((session) => cloneForPersistence(session))
  };
  await fs.mkdir(path.dirname(sessionStorePath()), { recursive: true });
  await fs.writeFile(sessionStorePath(), JSON.stringify(payload, null, 2), "utf8");
}

function schedulePersistSessions() {
  if (persistTimer) {
    clearTimeout(persistTimer);
  }
  persistTimer = setTimeout(() => {
    persistTimer = null;
    void persistSessions().catch((error) => {
      console.error("Failed to persist sessions", error);
    });
  }, 250);
}

async function loadPersistedSessions() {
  try {
    const raw = await fs.readFile(sessionStorePath(), "utf8");
    const parsed = JSON.parse(raw);
    workerIndex = Number(parsed?.workerIndex ?? 0);
    sessions = new Map(
      (Array.isArray(parsed?.sessions) ? parsed.sessions : [])
        .map((session) => normalizeSession(session))
        .map((session) => [session.id, session])
    );
  } catch (error) {
    if (error?.code !== "ENOENT") {
      console.error("Failed to load persisted sessions", error);
    }
    workerIndex = 0;
    sessions = new Map();
  }
}

async function flushPersistedSessions() {
  if (persistTimer) {
    clearTimeout(persistTimer);
    persistTimer = null;
  }
  await persistSessions();
}

function randomId() {
  return crypto.randomUUID();
}

function nowIso() {
  return new Date().toISOString();
}

function emitSessions() {
  schedulePersistSessions();
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }
  mainWindow.webContents.send("sessions:updated", sessionsForRenderer());
}

function automationSessionInfo(session) {
  return {
    id: session.id,
    name: session.projectName,
    path: session.projectPath,
    worker: session.workerName,
    status: session.isCompleted ? "completed" : session.isProcessing ? "processing" : session.isRunning ? "running" : "stopped",
    activity: session.claudeActivity,
    model: session.selectedModel,
    tokensUsed: session.tokensUsed,
    cost: session.totalCost,
    isProcessing: session.isProcessing,
    isCompleted: session.isCompleted,
    errorCount: session.blocks.filter((block) => block.kind === "toolError" || block.kind === "error").length,
    commandCount: session.blocks.filter((block) => block.kind === "toolUse").length
  };
}

function automationSuccess(payload) {
  return { ok: true, ...payload };
}

function automationError(message) {
  return { ok: false, error: message };
}

async function processAutomationRequest(rawLine) {
  let json;
  try {
    json = JSON.parse(rawLine);
  } catch {
    return automationError('Invalid request. Expected JSON with "command" field.');
  }
  const command = String(json?.command ?? "").trim().toLowerCase();
  if (!command) {
    return automationError('Missing "command" field.');
  }

  switch (command) {
    case "list-tabs":
      return automationSuccess({
        tabs: [...sessions.values()].sort((a, b) => a.tabOrder - b.tabOrder).map((session) => automationSessionInfo(session))
      });
    case "select-tab": {
      const sessionId = String(json?.id ?? "").trim();
      if (!sessionId) return automationError('Missing "id" parameter.');
      if (!sessions.has(sessionId)) return automationError(`Tab not found: ${sessionId}`);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send("automation:select-session", sessionId);
      }
      return automationSuccess({ selected: sessionId });
    }
    case "new-tab": {
      const projectPath = String(json?.path ?? process.env.HOME ?? process.cwd()).trim();
      const projectName = String(json?.name ?? "").trim() || path.basename(projectPath) || "Session";
      const prompt = typeof json?.prompt === "string" ? json.prompt : "";
      const session = createSession({
        projectPath,
        projectName,
        initialPrompt: "",
        manualLaunch: true
      });
      await refreshGitInfo(session);
      emitSessions();
      if (prompt.trim()) {
        await sendPrompt({ sessionId: session.id, prompt });
      }
      return automationSuccess({ id: session.id, name: projectName, path: projectPath });
    }
    case "close-tab": {
      const sessionId = String(json?.id ?? "").trim();
      if (!sessionId) return automationError('Missing "id" parameter.');
      const session = sessions.get(sessionId);
      if (!session) return automationError(`Tab not found: ${sessionId}`);
      if (session.child && !session.child.killed) {
        session.child.kill();
      }
      sessions.delete(sessionId);
      emitSessions();
      return automationSuccess({ closed: sessionId });
    }
    case "send-input": {
      const sessionId = String(json?.id ?? "").trim();
      const text = String(json?.text ?? "");
      if (!sessionId || !text.trim()) {
        return automationError('Missing "id" or "text" parameter.');
      }
      if (!sessions.has(sessionId)) return automationError(`Tab not found: ${sessionId}`);
      await sendPrompt({ sessionId, prompt: text });
      return automationSuccess({ sent: true, id: sessionId });
    }
    case "get-status":
      return automationSuccess({
        tabCount: sessions.size,
        totalTokens: [...sessions.values()].reduce((sum, session) => sum + Number(session.tokensUsed || 0), 0),
        activeTab: [...sessions.values()].sort((a, b) => a.tabOrder - b.tabOrder)[0] ? automationSessionInfo([...sessions.values()].sort((a, b) => a.tabOrder - b.tabOrder)[0]) : null,
        tabs: [...sessions.values()].sort((a, b) => a.tabOrder - b.tabOrder).map((session) => automationSessionInfo(session))
      });
    case "open-browser": {
      const url = String(json?.url ?? "").trim();
      const sessionId = String(json?.id ?? "").trim();
      if (!url) return automationError('Missing "url" parameter.');
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send("automation:open-browser", {
          url,
          sessionId: sessionId || undefined
        });
      }
      return automationSuccess({ opened: url, id: sessionId || undefined });
    }
    case "get-notifications": {
      const notifications = [];
      for (const session of sessions.values()) {
        if (session.pendingApproval) {
          notifications.push({
            type: "pending_approval",
            tabId: session.id,
            tabName: session.projectName,
            command: session.pendingApproval.command,
            reason: session.pendingApproval.reason
          });
        }
        if (session.dangerousCommandWarning) {
          notifications.push({
            type: "dangerous_command",
            tabId: session.id,
            tabName: session.projectName,
            warning: session.dangerousCommandWarning
          });
        }
        if (session.sensitiveFileWarning) {
          notifications.push({
            type: "sensitive_file",
            tabId: session.id,
            tabName: session.projectName,
            warning: session.sensitiveFileWarning
          });
        }
        if (session.isCompleted) {
          notifications.push({
            type: "completed",
            tabId: session.id,
            tabName: session.projectName,
            tokensUsed: session.tokensUsed,
            cost: session.totalCost
          });
        }
        const latestError = [...session.blocks].reverse().find((block) => block.kind === "toolError" || block.kind === "error");
        if (latestError) {
          notifications.push({
            type: "error",
            tabId: session.id,
            tabName: session.projectName,
            error: latestError.content
          });
        }
      }
      return automationSuccess({ notifications, count: notifications.length });
    }
    case "ping":
      return automationSuccess({ message: "pong" });
    default:
      return automationError(`Unknown command: ${command}`);
  }
}

async function startAutomationServer() {
  if (automationServer?.listening) {
    return currentAutomationServerStatus();
  }
  const socketPath = automationServerPath();
  if (process.platform !== "win32") {
    await fs.unlink(socketPath).catch(() => undefined);
  }
  automationServer = net.createServer((socket) => {
    socket.setEncoding("utf8");
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += String(chunk ?? "");
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        void processAutomationRequest(trimmed)
          .then((response) => {
            socket.write(`${JSON.stringify(response)}\n`);
          })
          .catch((error) => {
            socket.write(`${JSON.stringify(automationError(error?.message ?? "Automation request failed"))}\n`);
          });
      }
    });
  });
  await new Promise((resolve, reject) => {
    automationServer.once("error", reject);
    automationServer.listen(socketPath, () => {
      automationServer.off("error", reject);
      resolve(undefined);
    });
  });
  return currentAutomationServerStatus();
}

async function stopAutomationServer() {
  if (!automationServer) return;
  const server = automationServer;
  automationServer = null;
  await new Promise((resolve) => {
    server.close(() => resolve(undefined));
  }).catch(() => undefined);
  if (process.platform !== "win32") {
    await fs.unlink(automationServerPath()).catch(() => undefined);
  }
}

function workerColor(index) {
  const colors = ["#ee7878", "#68d498", "#eebb50", "#70b0ee", "#c08ce6", "#ee9858", "#58ccbb", "#ee78bb"];
  return colors[index % colors.length];
}

function workerName(index) {
  const names = ["Pixel", "Byte", "Code", "Bug", "Chip", "Kit", "Dot", "Rex"];
  return names[index % names.length];
}

function sanitizeText(value) {
  return String(value ?? "")
    .replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .trim();
}

function createBlock(kind, content, meta = {}) {
  return {
    id: randomId(),
    kind,
    content,
    timestamp: nowIso(),
    meta
  };
}

function createSession(payload) {
  const order = workerIndex++;
  const projectPath = String(payload.projectPath ?? "").trim();
  const projectName = String(payload.projectName ?? "").trim() || path.basename(projectPath) || `Session ${order + 1}`;
  const provider = normalizeProvider(payload.provider ?? providerForModel(payload.selectedModel));
  const selectedModel = isClaudeModel(payload.selectedModel) || isCodexModel(payload.selectedModel) || isGeminiModel(payload.selectedModel)
    ? String(payload.selectedModel)
    : defaultModelForProvider(provider);
  const effortLevel = ["low", "medium", "high", "max"].includes(String(payload.effortLevel ?? ""))
    ? String(payload.effortLevel)
    : "medium";
  const permissionMode = ["acceptEdits", "bypassPermissions", "auto", "default", "plan"].includes(String(payload.permissionMode ?? ""))
    ? String(payload.permissionMode)
    : "bypassPermissions";
  const outputMode = normalizeOutputMode(payload.outputMode) ?? "전체";
  const maxBudgetUSD = Number(payload.maxBudgetUSD);
  const session = {
    id: randomId(),
    projectName,
    projectPath,
    workerName: workerName(order),
    workerColorHex: workerColor(order),
    tokensUsed: 0,
    inputTokensUsed: 0,
    outputTokensUsed: 0,
    totalCost: 0,
    branch: "",
    startTime: nowIso(),
    lastActivityTime: nowIso(),
    isCompleted: false,
    isProcessing: false,
    isRunning: true,
    claudeActivity: "idle",
    provider,
    sessionId: "",
    selectedModel,
    effortLevel,
    outputMode,
    permissionMode,
    codexSandboxMode:
      payload.codexSandboxMode === "read-only" || payload.codexSandboxMode === "danger-full-access"
        ? payload.codexSandboxMode
        : "workspace-write",
    codexApprovalPolicy:
      payload.codexApprovalPolicy === "untrusted" || payload.codexApprovalPolicy === "never"
        ? payload.codexApprovalPolicy
        : "on-request",
    systemPrompt: String(payload.systemPrompt ?? ""),
    maxBudgetUSD: Number.isFinite(maxBudgetUSD) && maxBudgetUSD > 0 ? maxBudgetUSD : 0,
    allowedTools: String(payload.allowedTools ?? ""),
    disallowedTools: String(payload.disallowedTools ?? ""),
    additionalDirs: Array.isArray(payload.additionalDirs) ? payload.additionalDirs.filter((value) => typeof value === "string" && value.trim()) : [],
    continueSession: Boolean(payload.continueSession),
    useWorktree: Boolean(payload.useWorktree),
    fallbackModel: String(payload.fallbackModel ?? ""),
    sessionName: String(payload.sessionName ?? ""),
    jsonSchema: "",
    mcpConfigPaths: [],
    customAgent: "",
    customAgentsJSON: "",
    pluginDirs: Array.isArray(payload.pluginDirs) ? payload.pluginDirs.filter((value) => typeof value === "string" && value.trim()) : [],
    customTools: "",
    enableChrome: payload.enableChrome == null ? true : Boolean(payload.enableChrome),
    forkSession: Boolean(payload.forkSession),
    fromPR: "",
    manualLaunch: false,
    enableBrief: Boolean(payload.enableBrief),
    tmuxMode: Boolean(payload.tmuxMode),
    strictMcpConfig: false,
    settingSources: "",
    settingsFileOrJSON: "",
    betaHeaders: "",
    tokenLimit: 0,
    completedPromptCount: 0,
    lastPromptText: "",
    lastResultText: "",
    lastReportPath: "",
    lastReportGeneratedAt: "",
    lastReportedFileChangeCount: 0,
    pendingApproval: null,
    dangerousCommandWarning: null,
    sensitiveFileWarning: null,
    blocks: [createBlock("sessionStart", sessionStartContent({ provider, selectedModel, sessionId: "" }))],
    fileChanges: [],
    gitInfo: {
      branch: "",
      changedFiles: 0,
      lastCommit: "",
      lastCommitAge: "",
      isGitRepo: false
    },
    tabOrder: order,
    lastToolUse: null,
    child: null
  };
  sessions.set(session.id, session);
  return session;
}

async function runCommand(command, args, cwd) {
  const { stdout } = await execFileAsync(command, args, {
    cwd,
    windowsHide: true,
    env: process.env,
    shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(String(command))
  });
  return stdout.toString().trim();
}

function commandCandidates(executableName) {
  const candidates = [executableName];

  if (process.platform !== "win32") {
    return candidates;
  }

  const exeName = executableName.toLowerCase().endsWith(".exe") ? executableName : `${executableName}.exe`;
  const cmdName = executableName.toLowerCase().endsWith(".cmd") ? executableName : `${executableName}.cmd`;
  const userProfile = process.env.USERPROFILE ?? "";
  const localAppData = process.env.LOCALAPPDATA ?? "";
  const appData = process.env.APPDATA ?? "";
  const programFiles = process.env.ProgramFiles ?? "C:\\Program Files";

  const windowsCandidates = [
    path.join(appData, "npm", cmdName),
    path.join(userProfile, ".codex", ".sandbox-bin", exeName),
    path.join(localAppData, "Programs", "Codex", "bin", exeName),
    path.join(programFiles, "Codex", "bin", exeName)
  ].filter(Boolean);

  return [...new Set([...candidates, ...windowsCandidates])];
}

function currentCLIStatusPayload() {
  return {
    claudeStatus,
    codexStatus,
    geminiStatus
  };
}

async function refreshCLIStatuses() {
  [claudeStatus, codexStatus, geminiStatus] = await Promise.all([
    resolveCLIStatus(cliDescriptors.claude.executableName, cliDescriptors.claude.errorInfo),
    resolveCLIStatus(cliDescriptors.codex.executableName, cliDescriptors.codex.errorInfo),
    resolveCLIStatus(cliDescriptors.gemini.executableName, cliDescriptors.gemini.errorInfo)
  ]);
  return currentCLIStatusPayload();
}

async function installCLI(providerValue) {
  const provider = normalizeProvider(providerValue);
  const descriptor = cliDescriptors[provider];
  const npmCommand = process.platform === "win32" ? "npm.cmd" : "npm";

  try {
    await execFileAsync(npmCommand, ["install", "-g", descriptor.packageName], {
      windowsHide: true,
      env: process.env,
      shell: process.platform === "win32",
      maxBuffer: 1024 * 1024 * 16
    });
  } catch (error) {
    const stdout = sanitizeText(error?.stdout ?? "");
    const stderr = sanitizeText(error?.stderr ?? "");
    let statuses;
    try {
      statuses = await refreshCLIStatuses();
    } catch {
      statuses = currentCLIStatusPayload();
    }
    return {
      ok: false,
      provider,
      message: stderr || stdout || String(error?.message ?? `${descriptor.label} install failed.`),
      ...statuses
    };
  }

  const statuses = await refreshCLIStatuses();
  const status = cliStatusForProvider(provider);
  return {
    ok: status.isInstalled,
    provider,
    message: status.isInstalled
      ? `${descriptor.label} installed successfully.`
      : `${descriptor.label} install finished, but the executable was not detected yet.`,
    ...statuses
  };
}

async function refreshGitInfo(session) {
  try {
    const branch = await runCommand("git", ["-C", session.projectPath, "branch", "--show-current"]);
    const status = await runCommand("git", ["-C", session.projectPath, "status", "--porcelain"]);
    const log = await runCommand("git", ["-C", session.projectPath, "log", "-1", "--format=%s|||%cr"]);
    const [lastCommit = "", lastCommitAge = ""] = log.split("|||");
    session.branch = branch;
    session.gitInfo = {
      branch,
      changedFiles: status ? status.split(/\r?\n/).filter(Boolean).length : 0,
      lastCommit: lastCommit.slice(0, 40),
      lastCommitAge,
      isGitRepo: Boolean(branch)
    };
  } catch {
    session.branch = "";
    session.gitInfo = {
      branch: "",
      changedFiles: 0,
      lastCommit: "",
      lastCommitAge: "",
      isGitRepo: false
    };
  }
}

function parseGitRefs(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return [];
  return trimmed
    .replace(/^\((.*)\)$/, "$1")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      if (entry.startsWith("HEAD -> ")) {
        return {
          name: entry.replace(/^HEAD ->\s*/, ""),
          type: "head"
        };
      }
      if (entry.startsWith("tag: ")) {
        return {
          name: entry.replace(/^tag:\s*/, ""),
          type: "tag"
        };
      }
      return {
        name: entry,
        type: entry.includes("/") ? "remoteBranch" : "branch"
      };
    });
}

function parseCommitRecords(output) {
  const records = String(output ?? "")
    .split("\0")
    .map((entry) => entry.trim())
    .filter(Boolean);

  return records
    .map((record) => {
      const fields = record.split("\u001f");
      const [id = "", shortHash = "", author = "", authorEmail = "", relativeDate = "", isoDate = "", parents = "", refs = "", subject = ""] = fields;
      if (!id || !shortHash) {
        return null;
      }
      return {
        id,
        shortHash,
        author,
        authorEmail,
        relativeDate,
        isoDate,
        subject,
        refs: parseGitRefs(refs),
        parentIds: parents.trim() ? parents.trim().split(/\s+/) : []
      };
    })
    .filter(Boolean);
}

function assignCommitLanes(commits) {
  let activeLanes = [];

  return commits.map((commit) => {
    const topIds = [...activeLanes];
    let lane = topIds.indexOf(commit.id);
    const hasIncoming = lane !== -1;
    if (lane === -1) {
      lane = topIds.length;
    }

    const bottomIds = [...topIds];
    if (hasIncoming) {
      bottomIds.splice(lane, 1);
    }

    if (commit.parentIds.length > 0) {
      let insertIndex = Math.min(lane, bottomIds.length);
      commit.parentIds.forEach((parentId, parentIndex) => {
        const existingIndex = bottomIds.indexOf(parentId);
        if (existingIndex !== -1) {
          bottomIds.splice(existingIndex, 1);
          if (existingIndex < insertIndex) {
            insertIndex -= 1;
          }
        }
        const targetIndex = Math.min(insertIndex + parentIndex, bottomIds.length);
        bottomIds.splice(targetIndex, 0, parentId);
      });
    }

    activeLanes = bottomIds;
    const topLanes = topIds.map((_, index) => index);
    const bottomLanes = bottomIds.map((_, index) => index);
    const parentLanes = commit.parentIds.map((parentId) => bottomIds.indexOf(parentId)).filter((candidate) => candidate >= 0);
    const mergeLanes = parentLanes.slice(1);
    const activeLaneSet = new Set([...topLanes, ...bottomLanes, lane, ...parentLanes]);

    return {
      ...commit,
      lane,
      activeLanes: [...activeLaneSet].sort((left, right) => left - right),
      hasIncoming,
      topIds,
      bottomIds,
      topLanes,
      bottomLanes,
      parentLanes,
      mergeLanes
    };
  });
}

function statusLabelFromCodes(indexStatus, workTreeStatus) {
  const code = `${indexStatus}${workTreeStatus}`.trim();
  if (code === "??") return "untracked";
  if (code.includes("U")) return "conflict";
  if (indexStatus === "A" || workTreeStatus === "A") return "added";
  if (indexStatus === "D" || workTreeStatus === "D") return "deleted";
  if (indexStatus === "R" || workTreeStatus === "R") return "renamed";
  if (indexStatus === "M" || workTreeStatus === "M") return "modified";
  if (indexStatus === "C" || workTreeStatus === "C") return "copied";
  return "changed";
}

function parseStatusOutput(output) {
  return String(output ?? "")
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const indexStatus = line.slice(0, 1);
      const workTreeStatus = line.slice(1, 2);
      const remainder = line.slice(3).trim();
      const normalizedPath = remainder.includes(" -> ") ? remainder.split(" -> ").pop() : remainder;
      return {
        path: normalizedPath,
        fileName: path.basename(normalizedPath),
        indexStatus,
        workTreeStatus,
        statusLabel: statusLabelFromCodes(indexStatus, workTreeStatus),
        staged: indexStatus !== " " && indexStatus !== "?"
      };
    });
}

function parseBranchOutput(output, currentBranch) {
  return String(output ?? "")
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const isCurrent = line.startsWith("*");
      const body = line.slice(2).trim();
      const [name = "", hash = "", ...rest] = body.split(/\s+/);
      const upstreamMatch = body.match(/\[([^\]]+)\]/);
      const upstreamText = upstreamMatch ? upstreamMatch[1] : "";
      const aheadMatch = upstreamText.match(/ahead\s+(\d+)/i);
      const behindMatch = upstreamText.match(/behind\s+(\d+)/i);
      return {
        name,
        isCurrent: isCurrent || name === currentBranch,
        isRemote: name.startsWith("remotes/"),
        upstream: upstreamText,
        shortHash: hash,
        ahead: aheadMatch ? Number(aheadMatch[1]) : 0,
        behind: behindMatch ? Number(behindMatch[1]) : 0
      };
    })
    .filter((branch) => branch.name && branch.name !== "(HEAD");
}

function parseStashOutput(output) {
  return String(output ?? "")
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      const [label = "", relativeDate = "", message = ""] = line.split("\t");
      return {
        id: label.replace(/^stash@\{|\}$/g, ""),
        label,
        relativeDate,
        message
      };
    });
}

function parseCommitGraphOutput(output) {
  return assignCommitLanes(parseCommitRecords(output));
}

async function getGitPanelSnapshot(projectPath, refName) {
  const targetPath = String(projectPath ?? "").trim();
  const targetRef = String(refName ?? "").trim();
  if (!targetPath) {
    return {
      projectPath: "",
      isGitRepo: false,
      currentBranch: "",
      upstreamStatus: "",
      branches: [],
      tags: [],
      stashes: [],
      commits: [],
      changes: [],
      lastError: lt("custom.no.session.selected")
    };
  }

  try {
    const isGitRepo = await runCommand("git", ["-C", targetPath, "rev-parse", "--is-inside-work-tree"]);
    if (String(isGitRepo).trim() !== "true") {
      throw new Error("Not a git repository");
    }

    const commitArgs = [
      "-C",
      targetPath,
      "log",
      ...(targetRef ? [targetRef] : ["--all"]),
      "--topo-order",
      "--decorate=short",
      "--date=relative",
      "--pretty=format:%x00%H%x1f%h%x1f%an%x1f%ae%x1f%ar%x1f%aI%x1f%P%x1f%D%x1f%s"
    ];

    const [currentBranch, branchOutput, tagOutput, stashOutput, commitOutput, statusOutput, upstreamStatus] = await Promise.all([
      runCommand("git", ["-C", targetPath, "branch", "--show-current"]),
      runCommand("git", ["-C", targetPath, "branch", "--all", "--no-color", "--verbose", "--verbose"]),
      runCommand("git", ["-C", targetPath, "tag", "--sort=-creatordate"]),
      runCommand("git", ["-C", targetPath, "stash", "list", "--date=relative", "--pretty=format:%gd\t%cr\t%gs"]),
      runCommand("git", commitArgs),
      runCommand("git", ["-C", targetPath, "status", "--porcelain=v1", "--untracked-files=all"]),
      runCommand("git", ["-C", targetPath, "status", "--short", "--branch"])
    ]);

    return {
      projectPath: targetPath,
      isGitRepo: true,
      currentBranch: String(currentBranch ?? "").trim(),
      upstreamStatus: String(upstreamStatus ?? "").split(/\r?\n/)[0] ?? "",
      branches: parseBranchOutput(branchOutput, String(currentBranch ?? "").trim()),
      tags: String(tagOutput ?? "")
        .split(/\r?\n/)
        .map((entry) => entry.trim())
        .filter(Boolean)
        .slice(0, 24),
      stashes: parseStashOutput(stashOutput),
      commits: parseCommitGraphOutput(commitOutput),
      changes: parseStatusOutput(statusOutput),
      lastError: ""
    };
  } catch (error) {
    return {
      projectPath: targetPath,
      isGitRepo: false,
      currentBranch: "",
      upstreamStatus: "",
      branches: [],
      tags: [],
      stashes: [],
      commits: [],
      changes: [],
      lastError: String(error?.message ?? lt("custom.na"))
    };
  }
}

async function executeGitAction(payload) {
  const projectPath = String(payload?.projectPath ?? "").trim();
  const action = String(payload?.action ?? "").trim();
  const input = String(payload?.input ?? "").trim();
  const selectedPaths = Array.isArray(payload?.selectedPaths)
    ? payload.selectedPaths
        .map((value) => String(value ?? "").trim())
        .filter(Boolean)
    : [];
  if (!projectPath) {
    return { ok: false, message: "Project path missing" };
  }

  try {
    switch (action) {
      case "stageAll":
        await runCommand("git", ["-C", projectPath, "add", "-A"]);
        return { ok: true, message: "Staged all changes" };
      case "commit":
        if (!input) return { ok: false, message: "Commit message required" };
        await runCommand("git", ["-C", projectPath, "commit", "-m", input]);
        return { ok: true, message: "Commit created" };
      case "commitSelected": {
        if (!input) return { ok: false, message: "Commit message required" };
        if (selectedPaths.length === 0) {
          return { ok: false, message: "Select at least one file to commit" };
        }

        const stagedBefore = await runCommand("git", ["-C", projectPath, "diff", "--name-only", "--cached"]);
        if (String(stagedBefore).trim()) {
          return { ok: false, message: "선택 커밋은 스테이징된 변경이 없을 때만 사용할 수 있습니다." };
        }

        try {
          await runCommand("git", ["-C", projectPath, "add", "--", ...selectedPaths]);
          const stagedAfter = await runCommand("git", ["-C", projectPath, "diff", "--name-only", "--cached"]);
          if (!String(stagedAfter).trim()) {
            await runCommand("git", ["-C", projectPath, "reset", "--", ...selectedPaths]);
            return { ok: false, message: "선택한 파일에서 커밋할 변경을 찾지 못했습니다." };
          }
          await runCommand("git", ["-C", projectPath, "commit", "-m", input]);
          return { ok: true, message: `Committed ${selectedPaths.length} selected file${selectedPaths.length === 1 ? "" : "s"}` };
        } catch (error) {
          try {
            await runCommand("git", ["-C", projectPath, "reset", "--", ...selectedPaths]);
          } catch {}
          throw error;
        }
      }
      case "amend":
        if (!input) return { ok: false, message: "Amend message required" };
        await runCommand("git", ["-C", projectPath, "commit", "--amend", "-m", input]);
        return { ok: true, message: "Commit amended" };
      case "push":
        await runCommand("git", ["-C", projectPath, "push"]);
        return { ok: true, message: "Pushed to remote" };
      case "pull":
        await runCommand("git", ["-C", projectPath, "pull", "--ff-only"]);
        return { ok: true, message: "Pulled latest changes" };
      case "branch":
        if (!input) return { ok: false, message: "Branch name required" };
        await runCommand("git", ["-C", projectPath, "checkout", "-b", input]);
        return { ok: true, message: `Created branch ${input}` };
      case "stash":
        await runCommand("git", ["-C", projectPath, "stash", "push", "-m", input || "Doffice stash"]);
        return { ok: true, message: "Created stash" };
      case "merge":
        if (!input) return { ok: false, message: "Merge target required" };
        await runCommand("git", ["-C", projectPath, "merge", input]);
        return { ok: true, message: `Merged ${input}` };
      default:
        return { ok: false, message: `Unsupported action: ${action}` };
    }
  } catch (error) {
    return { ok: false, message: String(error?.message ?? "Git action failed") };
  }
}

async function resolveCLIStatus(executableName, errorInfo) {
  const lookupCommand = process.platform === "win32" ? "where.exe" : "which";
  const directCandidates = commandCandidates(executableName);

  try {
    const location = await runCommand(lookupCommand, [executableName]);
    const resolved = location
      .split(/\r?\n/)
      .map((entry) => entry.trim())
      .filter(Boolean);
    directCandidates.unshift(...resolved);
  } catch {}

  for (const executable of [...new Set(directCandidates)]) {
    try {
      const version = await runCommand(executable, ["--version"]);
      return {
        isInstalled: true,
        version,
        path: executable,
        errorInfo: ""
      };
    } catch {}
  }

  return {
    isInstalled: false,
    version: "",
    path: "",
    errorInfo
  };
}

function appendBlock(session, kind, content, meta = {}) {
  const block = createBlock(kind, content, meta);
  session.blocks.push(block);
  if (session.blocks.length > 420) {
    session.blocks = session.blocks.slice(-420);
  }
  session.lastActivityTime = block.timestamp;
  emitSessions();
}

function markSessionRuntimeError(session, message, options = {}) {
  session.child = null;
  session.isProcessing = false;
  session.isCompleted = false;
  if (options.stopRunning) {
    session.isRunning = false;
  }
  session.claudeActivity = "error";
  appendBlock(session, "error", String(message ?? "Session failed"));
}

function summarizeToolUse(toolName, toolInput) {
  if (toolName === "Bash") {
    return String(toolInput.command ?? "").trim();
  }
  if (toolName === "Read" || toolName === "Write" || toolName === "Edit") {
    return String(toolInput.file_path ?? "").trim();
  }
  if (toolName === "Grep" || toolName === "Glob") {
    return String(toolInput.pattern ?? "").trim();
  }
  return toolName;
}

function globToRegex(pattern) {
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".");
  return new RegExp(`^${escaped}$`, "i");
}

function detectDangerousCommand(command) {
  for (const pattern of dangerousPatterns) {
    const match = String(command ?? "").match(pattern.regex);
    if (match) {
      return `⚠ ${pattern.severity}: ${pattern.description}\n→ ${match[0]}`;
    }
  }
  return null;
}

function detectSensitiveFile(filePath, action) {
  const fullPath = String(filePath ?? "");
  const filename = path.basename(fullPath);
  const normalizedPath = fullPath.replace(process.env.HOME || "", "~");
  for (const pattern of sensitiveFilePatterns) {
    const regex = globToRegex(pattern);
    if (regex.test(filename) || regex.test(normalizedPath)) {
      return `Sensitive file ${action}: ${pattern}\n→ ${filePath}`;
    }
  }
  return null;
}

function retryPermissionMode(toolName) {
  switch (toolName) {
    case "Write":
    case "Edit":
    case "NotebookEdit":
      return "acceptEdits";
    default:
      return "bypassPermissions";
  }
}

function approvalReasonPrefix(toolName) {
  switch (toolName) {
    case "Write":
    case "Edit":
    case "NotebookEdit":
      return "File edit";
    case "Bash":
      return "Command run";
    case "WebFetch":
      return "Web fetch";
    case "WebSearch":
      return "Web search";
    default:
      return toolName || "Tool use";
  }
}

function approvalCommandText(lastToolUse) {
  if (!lastToolUse) {
    return "Tool approval required.";
  }
  if (lastToolUse.summary) {
    return lastToolUse.summary;
  }
  return lastToolUse.toolName || "Tool approval required.";
}

function detectPermissionDenied(text) {
  const lowered = String(text ?? "").toLowerCase();
  if (!lowered) return false;
  return (
    (lowered.includes("permission") && lowered.includes("denied")) ||
    (lowered.includes("permission") && lowered.includes("required")) ||
    lowered.includes("approval required") ||
    lowered.includes("approval needed") ||
    lowered.includes("pending approval") ||
    lowered.includes("requires approval") ||
    lowered.includes("not allowed by sandbox")
  );
}

function presentPermissionApprovalIfNeeded(session, rawMessage) {
  if (session.pendingApproval) {
    return;
  }
  const lastToolUse = session.lastToolUse ?? { toolName: "", summary: "" };
  const retryMode = retryPermissionMode(lastToolUse.toolName);
  const retrySummary =
    retryMode === "acceptEdits"
      ? "Approving will retry with edit permissions."
      : "Approving will retry with broader permissions.";

  session.pendingApproval = {
    command: approvalCommandText(lastToolUse),
    reason: `${approvalReasonPrefix(lastToolUse.toolName)} needs approval. ${retrySummary}`.trim(),
    toolName: lastToolUse.toolName,
    retryMode
  };
  session.isProcessing = false;
  session.claudeActivity = "idle";
  appendBlock(session, "status", sanitizeText(rawMessage) || session.pendingApproval.reason);
}

function clearPendingApproval(session) {
  if (!session.pendingApproval) return;
  session.pendingApproval = null;
  emitSessions();
}

function handleAssistantBlock(session, block) {
  if (block.type === "text" && block.text) {
    session.claudeActivity = "writing";
    appendBlock(session, "thought", String(block.text));
    return;
  }

  if (block.type !== "tool_use") {
    return;
  }

  const toolName = String(block.name ?? "");
  const toolInput = block.input ?? {};
  session.lastToolUse = {
    toolName,
    summary: summarizeToolUse(toolName, toolInput)
  };
  if (toolName === "Bash") {
    session.claudeActivity = "running";
    session.dangerousCommandWarning = detectDangerousCommand(String(toolInput.command ?? ""));
    appendBlock(session, "toolUse", String(toolInput.command ?? ""), { toolName });
    return;
  }
  if (toolName === "Read") {
    session.claudeActivity = "reading";
    session.sensitiveFileWarning = detectSensitiveFile(String(toolInput.file_path ?? ""), "Read");
    appendBlock(session, "toolUse", path.basename(String(toolInput.file_path ?? "")), { toolName });
    return;
  }
  if (toolName === "Write" || toolName === "Edit") {
    session.claudeActivity = "writing";
    const filePath = String(toolInput.file_path ?? "");
    session.sensitiveFileWarning = detectSensitiveFile(filePath, toolName);
    session.fileChanges.push({
      path: filePath,
      fileName: path.basename(filePath),
      action: toolName,
      timestamp: nowIso(),
      success: true
    });
    appendBlock(session, "fileChange", path.basename(filePath), { toolName, filePath });
    return;
  }
  if (toolName === "Grep" || toolName === "Glob") {
    session.claudeActivity = "searching";
    appendBlock(session, "toolUse", String(toolInput.pattern ?? ""), { toolName });
    return;
  }
  appendBlock(session, "toolUse", toolName, { toolName });
}

function handleStreamEvent(session, json) {
  const type = String(json.type ?? "");

  if (type === "system") {
    if (json.session_id) {
      session.sessionId = String(json.session_id);
      replaceSessionStartBlock(session);
      emitSessions();
    }
    if (json.model) {
      session.selectedModel = String(json.model);
      replaceSessionStartBlock(session);
    }
    return;
  }

  if (type === "assistant") {
    const message = json.message ?? {};
    const usage = message.usage ?? json.usage ?? {};
    session.inputTokensUsed += Number(usage.input_tokens ?? 0);
    session.outputTokensUsed += Number(usage.output_tokens ?? 0);
    session.tokensUsed = session.inputTokensUsed + session.outputTokensUsed;

    for (const block of message.content ?? []) {
      handleAssistantBlock(session, block);
    }
    return;
  }

  if (type === "user") {
    const message = json.message ?? {};
    const content = message.content ?? [];
    const toolResult = content.find((item) => item.type === "tool_result");
    if (toolResult?.is_error) {
      const text = sanitizeText(toolResult.content ?? "");
      appendBlock(session, "toolError", text);
      if (detectPermissionDenied(text)) {
        presentPermissionApprovalIfNeeded(session, text);
      }
      return;
    }
    if (toolResult?.content) {
      appendBlock(session, "toolOutput", sanitizeText(toolResult.content));
    }
    return;
  }

  if (type === "result") {
    session.totalCost += Number(json.total_cost_usd ?? 0);
    if (json.total_input_tokens != null) {
      session.inputTokensUsed = Number(json.total_input_tokens);
    }
    if (json.total_output_tokens != null) {
      session.outputTokensUsed = Number(json.total_output_tokens);
    }
    session.tokensUsed = session.inputTokensUsed + session.outputTokensUsed;
    session.lastResultText = String(json.result ?? "");
    session.completedPromptCount += 1;
    session.isCompleted = true;
    session.isProcessing = false;
    session.claudeActivity = "done";
    session.pendingApproval = null;
    appendBlock(session, "completion", lt("custom.completed"), {
      totalCostUsd: Number(json.total_cost_usd ?? 0),
      durationMs: Number(json.duration_ms ?? 0)
    });
    void finalizeSessionCompletion(session);
  }
}

function handleCodexItem(session, item, started) {
  const itemType = String(item?.type ?? "");
  switch (itemType) {
    case "agent_message": {
      if (started) return;
      const text = sanitizeText(item.text ?? "");
      if (!text) return;
      session.claudeActivity = "writing";
      session.lastResultText = text;
      appendBlock(session, "thought", text);
      return;
    }
    case "command_execution": {
      const command = String(item.command ?? "");
      if (started) {
        session.claudeActivity = "running";
        session.lastToolUse = { toolName: "Bash", summary: command };
        session.dangerousCommandWarning = detectDangerousCommand(command);
        appendBlock(session, "toolUse", command, { toolName: "Bash" });
      } else {
        const output = sanitizeText(item.aggregated_output ?? "");
        const exitCode = Number(item.exit_code ?? 0);
        if (output) {
          appendBlock(session, "toolOutput", output, { toolName: "Bash" });
        }
        if (exitCode !== 0) {
          appendBlock(session, "toolError", `exit ${exitCode}`, { toolName: "Bash" });
          session.claudeActivity = "error";
        }
      }
      return;
    }
    case "file_change": {
      if (started) return;
      const changes = Array.isArray(item.changes) ? item.changes : [];
      session.claudeActivity = "writing";
      for (const change of changes) {
        const filePath = String(change?.path ?? "");
        if (!filePath) continue;
        const kind = String(change?.kind ?? "update").toLowerCase();
        const action = kind === "add" ? "Write" : kind === "delete" ? "Delete" : "Edit";
        session.fileChanges.push({
          path: filePath,
          fileName: path.basename(filePath),
          action,
          timestamp: nowIso(),
          success: true
        });
        appendBlock(session, "fileChange", path.basename(filePath), { toolName: action, filePath });
      }
      return;
    }
    default:
      return;
  }
}

function handleCodexStreamEvent(session, json) {
  const type = String(json?.type ?? "");
  switch (type) {
    case "thread.started":
      if (json.thread_id) {
        session.sessionId = String(json.thread_id);
        replaceSessionStartBlock(session);
        emitSessions();
      }
      return;
    case "item.started":
      handleCodexItem(session, json.item ?? {}, true);
      return;
    case "item.completed":
      handleCodexItem(session, json.item ?? {}, false);
      return;
    case "turn.completed": {
      const usage = json.usage ?? {};
      session.inputTokensUsed += Number(usage.input_tokens ?? 0);
      session.outputTokensUsed += Number(usage.output_tokens ?? 0);
      session.tokensUsed = session.inputTokensUsed + session.outputTokensUsed;
      session.completedPromptCount += 1;
      session.isCompleted = true;
      session.isProcessing = false;
      session.claudeActivity = "done";
      appendBlock(session, "completion", lt("custom.completed"));
      void finalizeSessionCompletion(session);
      return;
    }
    case "exec_approval_request":
      session.claudeActivity = "error";
      appendBlock(session, "error", "Codex approval required");
      appendBlock(session, "status", "Codex exec JSON mode does not support live approval responses.");
      return;
    case "error": {
      const message = String(json.message ?? "Codex execution failed");
      session.claudeActivity = "error";
      appendBlock(session, "error", message);
      return;
    }
    default:
      return;
  }
}

async function runSlashCommand(payload) {
  const session = sessions.get(payload.sessionId);
  if (!session) {
    throw new Error("Session not found");
  }

  const commandText = String(payload.command ?? "").trim();
  if (!commandText.startsWith("/")) {
    return session;
  }

  const { name, args, remainder } = parseSlashCommand(commandText);
  if (!name) {
    appendBlock(session, "status", lt("custom.slash.empty"));
    return session;
  }

  appendBlock(session, "userPrompt", commandText);

  switch (name) {
    case "help": {
      appendBlock(session, "status", formatSlashHelp(remainder));
      return session;
    }
    case "clear": {
      session.blocks = [createBlock("sessionStart", sessionStartContent(session))];
      session.pendingApproval = null;
      session.dangerousCommandWarning = null;
      session.sensitiveFileWarning = null;
      appendBlock(session, "status", lt("terminal.log.cleared"));
      return session;
    }
    case "cancel": {
      if (session.child && !session.child.killed) {
        session.child.kill();
      }
      session.child = null;
      session.isProcessing = false;
      session.claudeActivity = "idle";
      session.pendingApproval = null;
      appendBlock(session, "status", lt("custom.cancelled.active.session"));
      return session;
    }
    case "stop": {
      if (session.child && !session.child.killed) {
        session.child.kill();
      }
      session.child = null;
      session.isProcessing = false;
      session.isRunning = false;
      session.claudeActivity = "idle";
      session.pendingApproval = null;
      appendBlock(session, "status", lt("custom.stopped.active.session"));
      return session;
    }
    case "copy": {
      const content = latestCopyableContent(session);
      if (!content) {
        appendBlock(session, "status", lt("terminal.no.response.to.copy"));
        return session;
      }
      clipboard.writeText(content);
      appendBlock(session, "status", ltf("terminal.copied.to.clipboard", content.length));
      return session;
    }
    case "export": {
      const stamp = nowIso().replace(/[:]/g, "-").replace(/\..+$/, "");
      const exportPath = path.join(session.projectPath, `doffice_log_${stamp}.txt`);
      try {
        await fs.writeFile(exportPath, formatSessionLog(session), "utf8");
        appendBlock(session, "status", ltf("terminal.log.saved", exportPath));
      } catch (error) {
        appendBlock(session, "status", ltf("terminal.log.save.failed", error.message));
      }
      return session;
    }
    case "stats": {
      appendBlock(session, "status", formatSessionStats(session));
      return session;
    }
    case "config": {
      appendBlock(session, "status", formatSessionConfig(session));
      return session;
    }
    case "errors": {
      appendBlock(session, "status", formatSessionErrors(session));
      return session;
    }
    case "files": {
      appendBlock(session, "status", formatSessionFiles(session));
      return session;
    }
    case "tokens": {
      appendBlock(session, "status", formatSessionTokens(session));
      return session;
    }
    case "model": {
      const nextModel = [...claudeModels, ...codexModels, ...geminiModels].find((value) => value === String(args[0] ?? "").toLowerCase());
      if (!nextModel) {
        appendBlock(session, "status", ltf("terminal.model.current", session.selectedModel, ""));
        return session;
      }
      session.selectedModel = nextModel;
      session.provider = providerForModel(nextModel);
      replaceSessionStartBlock(session);
      appendBlock(session, "status", ltf("terminal.model.changed", nextModel, ""));
      return session;
    }
    case "effort": {
      const nextEffort = ["low", "medium", "high", "max"].find((value) => value === String(args[0] ?? "").toLowerCase());
      if (!nextEffort) {
        appendBlock(session, "status", ltf("terminal.effort.current", session.effortLevel, ""));
        return session;
      }
      session.effortLevel = nextEffort;
      appendBlock(session, "status", ltf("slash.status.effort.changed", nextEffort, ""));
      return session;
    }
    case "output": {
      const normalized = normalizeOutputMode(args[0]);
      if (!normalized) {
        appendBlock(session, "status", ltf("slash.status.output.current", formatOutputMode(session.outputMode), ""));
        return session;
      }
      session.outputMode = normalized;
      appendBlock(session, "status", ltf("slash.status.output.changed", normalized, ""));
      return session;
    }
    case "permission": {
      const nextPermission = permissionModeAliases[String(args[0] ?? "").toLowerCase()];
      if (!nextPermission) {
        appendBlock(
          session,
          "status",
          ltf("slash.status.permission.current", formatPermissionModeLabel(session.permissionMode), "", "")
        );
        return session;
      }
      session.permissionMode = nextPermission;
      appendBlock(session, "status", ltf("slash.status.permission.changed", formatPermissionModeLabel(nextPermission), "", ""));
      return session;
    }
    case "budget": {
      const value = String(args[0] ?? "").trim().toLowerCase();
      if (!value) {
        appendBlock(session, "status", ltf("slash.status.budget.current", formatBudget(session.maxBudgetUSD)));
        return session;
      }
      if (value === "off" || value === "0") {
        session.maxBudgetUSD = 0;
        appendBlock(session, "status", lt("slash.status.budget.removed"));
        return session;
      }
      const numeric = Number(value);
      if (!Number.isFinite(numeric) || numeric <= 0) {
        appendBlock(session, "status", lt("slash.status.budget.invalid"));
        return session;
      }
      session.maxBudgetUSD = numeric;
      appendBlock(session, "status", ltf("slash.status.budget.set", numeric.toFixed(2)));
      return session;
    }
    case "system": {
      if (!remainder || remainder === "show") {
        appendBlock(session, "status", ltf("slash.status.system.current", session.systemPrompt || lt("slash.status.system.none")));
        return session;
      }
      if (remainder === "clear") {
        session.systemPrompt = "";
        appendBlock(session, "status", lt("slash.status.system.cleared"));
        return session;
      }
      session.systemPrompt = remainder;
      appendBlock(session, "status", ltf("slash.status.system.set", session.systemPrompt.slice(0, 160)));
      return session;
    }
    case "name": {
      if (!remainder) {
        appendBlock(session, "status", ltf("custom.session.name.current", session.sessionName || lt("slash.status.system.none")));
        return session;
      }
      session.sessionName = remainder;
      appendBlock(session, "status", ltf("custom.session.name.updated", session.sessionName));
      return session;
    }
    case "continue":
    case "resume": {
      session.continueSession = true;
      appendBlock(
        session,
        "status",
        session.sessionId
          ? ltf("custom.resume.enabled", session.sessionId)
          : lt("custom.continue.enabled")
      );
      return session;
    }
    case "fork": {
      session.forkSession = true;
      appendBlock(session, "status", lt("custom.fork.enabled"));
      return session;
    }
    case "worktree": {
      session.useWorktree = !session.useWorktree;
      appendBlock(session, "status", ltf("slash.status.worktree.toggle", toggleLabel(session.useWorktree)));
      return session;
    }
    case "chrome": {
      session.enableChrome = !session.enableChrome;
      appendBlock(session, "status", ltf("slash.status.chrome.toggle", toggleLabel(session.enableChrome)));
      return session;
    }
    case "brief": {
      session.enableBrief = !session.enableBrief;
      appendBlock(session, "status", ltf("slash.status.brief.toggle", toggleLabel(session.enableBrief)));
      return session;
    }
    case "tmux": {
      const action = String(args[0] ?? "toggle").trim().toLowerCase();
      if (action === "status" || action === "list") {
        try {
          const status = await listTmuxSessions();
          if (!status.available) {
            appendBlock(session, "status", "tmux is not available in WSL.");
            return session;
          }
          const summary = status.sessions.length
            ? status.sessions.map((item) => `${item.sessionName} · ${item.windowCount}w${item.isAttached ? " · attached" : ""}`).join("\n")
            : "No tmux sessions running.";
          appendBlock(session, "status", `tmux · ${status.path}\n${summary}`);
        } catch (error) {
          appendBlock(session, "error", String(error?.message ?? error ?? "Failed to read tmux status"));
        }
        return session;
      }
      if (action === "open" || action === "attach" || action === "restore") {
        session.tmuxMode = true;
        await openRawTerminal(session.id);
        return session;
      }
      if (action === "kill") {
        try {
          const sessionName = await killTmuxSession(session);
          appendBlock(session, "status", `Killed tmux session ${sessionName}.`);
        } catch (error) {
          appendBlock(session, "error", String(error?.message ?? error ?? "Failed to kill tmux session"));
        }
        return session;
      }
      session.tmuxMode = !session.tmuxMode;
      appendBlock(session, "status", `tmux mode ${session.tmuxMode ? "enabled" : "disabled"}.`);
      return session;
    }
    default: {
      appendBlock(session, "status", ltf("custom.unknown.command", name));
      return session;
    }
  }
}

async function sendPrompt(payload) {
  const session = sessions.get(payload.sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  const prompt = String(payload.prompt ?? "").trim();
  if (!prompt) {
    return session;
  }
  const provider = normalizeProvider(session.provider ?? providerForModel(session.selectedModel));
  const activeStatus = cliStatusForProvider(provider);
  if (!activeStatus.isInstalled) {
    markSessionRuntimeError(session, activeStatus.errorInfo, { stopRunning: true });
    return session;
  }

  session.lastPromptText = prompt;
  session.isProcessing = true;
  session.isCompleted = false;
  session.pendingApproval = null;
  session.dangerousCommandWarning = null;
  session.sensitiveFileWarning = null;
  session.claudeActivity = "thinking";
  session.lastToolUse = null;
  appendBlock(session, "userPrompt", prompt);

  const permissionMode = String(payload.permissionOverride ?? session.permissionMode);
  if (provider === "gemini") {
    try {
      const args = [];
      if (session.selectedModel && session.selectedModel !== "gemini-2.5-pro") {
        args.push("--model", session.selectedModel);
      }
      if (permissionMode === "bypassPermissions") {
        args.push("--yolo");
      }

      const child = spawn(activeStatus.path, args, {
        cwd: session.projectPath,
        env: process.env,
        windowsHide: true,
        shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(activeStatus.path)
      });
      session.child = child;

      let thoughtBlockId = "";
      let stderrBuffer = "";

      const appendGeminiOutput = (rawText) => {
        const text = sanitizeText(String(rawText ?? "").replace(/^✦\s*/, ""));
        if (!text || text === ">") {
          return;
        }
        session.claudeActivity = "writing";
        session.lastResultText = session.lastResultText ? `${session.lastResultText}\n${text}` : text;
        const lastBlock = session.blocks.at(-1);
        if (lastBlock?.id === thoughtBlockId && lastBlock.kind === "thought") {
          lastBlock.content = `${lastBlock.content}\n${text}`.trim();
          lastBlock.timestamp = nowIso();
        } else {
          const block = createBlock("thought", text);
          thoughtBlockId = block.id;
          session.blocks.push(block);
        }
        emitSessions();
      };

      const stdoutReader = readline.createInterface({ input: child.stdout });
      stdoutReader.on("line", (line) => {
        appendGeminiOutput(line);
      });

      child.stderr.on("data", (chunk) => {
        const text = sanitizeText(chunk.toString("utf8"));
        if (!text) {
          return;
        }
        stderrBuffer = stderrBuffer ? `${stderrBuffer}\n${text}` : text;
        appendBlock(session, "toolError", text);
      });

      child.on("error", (error) => {
        markSessionRuntimeError(session, error.message);
      });

      child.stdin.write(prompt);
      child.stdin.end();

      child.on("close", (code) => {
        session.child = null;
        if (!session.isProcessing) {
          emitSessions();
          return;
        }
        session.isProcessing = false;
        if (code && code !== 0) {
          session.claudeActivity = "error";
          appendBlock(session, "error", stderrBuffer || `Gemini exited with code ${code}`);
          emitSessions();
          return;
        }
        session.completedPromptCount += 1;
        session.isCompleted = true;
        session.claudeActivity = "done";
        appendBlock(session, "completion", lt("custom.completed"));
        void finalizeSessionCompletion(session);
      });

      return session;
    } catch (error) {
      markSessionRuntimeError(session, error?.message ?? error);
      return session;
    }
  }

  if (provider === "codex") {
    try {
      const args = session.sessionId
        ? [
            "exec",
            "resume",
            "--json",
            "-c",
            `sandbox_mode="${session.codexSandboxMode || "workspace-write"}"`,
            "-c",
            `approval_policy="${session.codexApprovalPolicy || "on-request"}"`,
            "--skip-git-repo-check",
            "-m",
            session.selectedModel,
            session.sessionId,
            prompt
          ]
        : [
            "exec",
            "--json",
            "-c",
            `sandbox_mode="${session.codexSandboxMode || "workspace-write"}"`,
            "-c",
            `approval_policy="${session.codexApprovalPolicy || "on-request"}"`,
            "--skip-git-repo-check",
            "-m",
            session.selectedModel,
            prompt
          ];

      for (const dir of session.additionalDirs ?? []) {
        if (dir) {
          args.splice(args.length - 1, 0, "--add-dir", dir);
        }
      }

      const child = spawn(activeStatus.path, args, {
        cwd: session.projectPath,
        env: process.env,
        windowsHide: true,
        shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(activeStatus.path)
      });
      session.child = child;

      const stdoutReader = readline.createInterface({ input: child.stdout });
      stdoutReader.on("line", (line) => {
        const trimmedLine = String(line).trim();
        if (!trimmedLine) return;
        try {
          handleCodexStreamEvent(session, JSON.parse(trimmedLine));
        } catch {
          const text = sanitizeText(trimmedLine);
          if (text) {
            appendBlock(session, "status", text);
          }
        }
      });

      child.stderr.on("data", (chunk) => {
        const text = sanitizeText(chunk.toString("utf8"));
        if (text && !text.startsWith("{")) {
          appendBlock(session, "toolError", text);
        }
      });

      child.on("error", (error) => {
        markSessionRuntimeError(session, error.message);
      });

      child.on("close", (code) => {
        session.child = null;
        if (session.isProcessing) {
          session.isProcessing = false;
          if (code && code !== 0 && session.claudeActivity !== "error") {
            session.claudeActivity = "error";
            appendBlock(session, "error", `Codex exited with code ${code}`);
          } else {
            session.claudeActivity = "idle";
          }
        }
        emitSessions();
      });

      return session;
    } catch (error) {
      markSessionRuntimeError(session, error?.message ?? error);
      return session;
    }
  }

  try {
    const args = [
      "-p",
      "--output-format",
      "stream-json",
      "--verbose",
      "--permission-mode",
      permissionMode,
      "--model",
      session.selectedModel,
      "--effort",
      session.effortLevel
    ];

    if (session.continueSession && !session.sessionId) {
      args.push("--continue");
    } else if (session.sessionId) {
      args.push("--resume", session.sessionId);
    }
    if (session.sessionName.trim()) {
      args.push("--name", session.sessionName.trim());
    }

    if (session.systemPrompt.trim()) {
      args.push("--append-system-prompt", session.systemPrompt.trim());
    }
    if (session.maxBudgetUSD > 0) {
      args.push("--max-budget-usd", session.maxBudgetUSD.toFixed(2));
    }
    if (session.fallbackModel.trim()) {
      args.push("--fallback-model", session.fallbackModel.trim());
    }
    if (session.enableChrome) {
      args.push("--chrome");
    }
    if (session.useWorktree) {
      args.push("--worktree");
    }
    if (session.forkSession) {
      args.push("--fork-session");
    }
    if (session.enableBrief) {
      args.push("--brief");
    }
    for (const pluginDir of session.pluginDirs ?? []) {
      if (pluginDir) {
        args.push("--plugin-dir", pluginDir);
      }
    }

    args.push("--", prompt);

    const child = spawn(activeStatus.path, args, {
      cwd: session.projectPath,
      env: process.env,
      windowsHide: true,
      shell: process.platform === "win32" && /\.(cmd|bat)$/i.test(activeStatus.path)
    });
    session.child = child;

    const stdoutReader = readline.createInterface({ input: child.stdout });
    stdoutReader.on("line", (line) => {
      const trimmedLine = String(line).trim();
      if (!trimmedLine) {
        return;
      }
      try {
        handleStreamEvent(session, JSON.parse(trimmedLine));
      } catch {
        const text = sanitizeText(trimmedLine);
        if (text) {
          appendBlock(session, "status", text);
        }
      }
    });

    child.stderr.on("data", (chunk) => {
      const text = sanitizeText(chunk.toString("utf8"));
      if (text && !text.startsWith("{")) {
        appendBlock(session, "toolError", text);
        if (detectPermissionDenied(text)) {
          presentPermissionApprovalIfNeeded(session, text);
        }
      }
    });

    child.on("error", (error) => {
      markSessionRuntimeError(session, error.message);
    });

    child.on("close", (code) => {
      session.child = null;
      if (session.isProcessing) {
        session.isProcessing = false;
        if (code && code !== 0 && session.claudeActivity !== "error") {
          session.claudeActivity = "error";
          appendBlock(session, "error", `Claude exited with code ${code}`);
        } else {
          session.claudeActivity = "idle";
        }
      }
      emitSessions();
    });

    return session;
  } catch (error) {
    markSessionRuntimeError(session, error?.message ?? error);
    return session;
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 920,
    minWidth: 1180,
    minHeight: 720,
    backgroundColor: "#090d12",
    title: "Doffice for Windows",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  void mainWindow.loadFile(path.join(app.getAppPath(), "dist", "index.html"));
}

app.whenReady().then(async () => {
  await loadPersistedSessions();
  await loadSSHProfiles();
  await refreshCLIStatuses();
  await Promise.allSettled([...sessions.values()].map((session) => refreshGitInfo(session)));
  await startAutomationServer().catch((error) => {
    console.error("Failed to start automation server", error);
  });
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("before-quit", (event) => {
  event.preventDefault();
  void flushPersistedSessions()
    .catch((error) => {
      console.error("Failed to flush sessions before quit", error);
    })
    .finally(async () => {
      await stopAutomationServer().catch((error) => {
        console.error("Failed to stop automation server", error);
      });
      app.exit(0);
    });
});

ipcMain.handle("app:bootstrap", async () => ({
  sessions: sessionsForRenderer(),
  ...currentCLIStatusPayload()
}));
ipcMain.handle("app:restart", async () => {
  setTimeout(() => {
    app.relaunch();
    app.exit(0);
  }, 120);
});
ipcMain.handle("automation:status", async () => currentAutomationServerStatus());
ipcMain.handle("tmux:status", async () => listTmuxSessions());
ipcMain.handle("plugin:install", async (_event, source) => installPluginFromSource(source));
ipcMain.handle("plugin:create-template", async (_event, parentDir) => createPluginTemplate(parentDir));
ipcMain.handle("plugin:runtime-snapshot", async (_event, pluginDirs) => buildPluginRuntimeSnapshot(pluginDirs));
ipcMain.handle("plugin:execute-command", async (_event, payload) => runPluginScript(payload?.scriptPath, payload?.projectPath));
ipcMain.handle("plugin:read-status-bar", async (_event, payload) => readPluginStatusBar(payload?.scriptPath, payload?.projectPath));
ipcMain.handle("app:refresh-cli-status", async () => refreshCLIStatuses());
ipcMain.handle("app:install-cli", async (_event, provider) => installCLI(provider));
ipcMain.handle("ssh:list", async () => sshProfiles);
ipcMain.handle("ssh:save", async (_event, profile) => saveSSHProfileRecord(profile));
ipcMain.handle("ssh:delete", async (_event, profileId) => deleteSSHProfileRecord(profileId));
ipcMain.handle("ssh:open", async (_event, profileId) => openSSHProfile(profileId));

ipcMain.handle("git:snapshot", async (_event, payload) => getGitPanelSnapshot(payload?.projectPath, payload?.refName));
ipcMain.handle("git:execute", async (_event, payload) => executeGitAction(payload));
ipcMain.handle("reports:list", async (_event, projectPaths) => listReports(projectPaths));
ipcMain.handle("reports:read", async (_event, reportPath) => readReport(reportPath));
ipcMain.handle("reports:delete", async (_event, reportPath) => {
  await fs.unlink(reportPath);
});

ipcMain.handle("dialog:pick-directory", async () => {
  const options = { properties: ["openDirectory"] };
  const result = mainWindow ? await dialog.showOpenDialog(mainWindow, options) : await dialog.showOpenDialog(options);
  if (result.canceled) {
    return "";
  }
  return result.filePaths[0] ?? "";
});

ipcMain.handle("session:create", async (_event, payload) => {
  const session = createSession(payload);
  await refreshGitInfo(session);
  emitSessions();
  if (payload.initialPrompt) {
    await sendPrompt({ sessionId: session.id, prompt: payload.initialPrompt });
  }
  return serializeSessionForRenderer(session);
});

ipcMain.handle("session:prompt", async (_event, payload) => sendPrompt(payload));
ipcMain.handle("session:slash-command", async (_event, payload) => runSlashCommand(payload));
ipcMain.handle("session:open-raw-terminal", async (_event, sessionId) => openRawTerminal(sessionId));
ipcMain.handle("session:send-raw-input", async (_event, payload) => sendRawInput(payload));
ipcMain.handle("session:update-config", async (_event, payload) => {
  const session = sessions.get(String(payload?.sessionId ?? ""));
  if (!session) {
    throw new Error("Session not found");
  }

  let nextProvider = normalizeProvider(session.provider ?? providerForModel(session.selectedModel));
  let nextModel = String(session.selectedModel ?? "").trim();

  if (payload?.provider === "codex" || payload?.provider === "claude" || payload?.provider === "gemini") {
    nextProvider = normalizeProvider(payload.provider);
  }

  if (typeof payload?.selectedModel === "string") {
    const requestedModel = String(payload.selectedModel).trim();
    if (isCodexModel(requestedModel)) {
      nextProvider = "codex";
      nextModel = requestedModel;
    } else if (isGeminiModel(requestedModel)) {
      nextProvider = "gemini";
      nextModel = requestedModel;
    } else if (isClaudeModel(requestedModel)) {
      nextProvider = "claude";
      nextModel = requestedModel;
    }
  }

  if (
    !nextModel ||
    (nextProvider === "codex" && !isCodexModel(nextModel)) ||
    (nextProvider === "gemini" && !isGeminiModel(nextModel)) ||
    (nextProvider === "claude" && !isClaudeModel(nextModel))
  ) {
    nextModel = defaultModelForProvider(nextProvider);
  }

  const providerChanged = nextProvider !== session.provider;
  session.provider = nextProvider;
  session.selectedModel = nextModel;

  if (providerChanged) {
    session.sessionId = "";
  }

  if (["low", "medium", "high", "max"].includes(String(payload?.effortLevel ?? ""))) {
    session.effortLevel = String(payload.effortLevel);
  }

  const nextOutputMode = normalizeOutputMode(payload?.outputMode);
  if (nextOutputMode) {
    session.outputMode = nextOutputMode;
  }

  if (["acceptEdits", "bypassPermissions", "auto", "default", "plan"].includes(String(payload?.permissionMode ?? ""))) {
    session.permissionMode = String(payload.permissionMode);
  }

  if (typeof payload?.enableBrief === "boolean") {
    session.enableBrief = payload.enableBrief;
  }

  replaceSessionStartBlock(session);
  emitSessions();
  return session;
});
ipcMain.handle("session:approval-approve", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  const approval = session.pendingApproval;
  if (!approval) {
    return session;
  }
  clearPendingApproval(session);
  appendBlock(session, "status", "Permission approved. Retrying previous task.");
  return sendPrompt({
    sessionId,
    prompt: `Permission granted. Please continue the previous task.`,
    permissionOverride: approval.retryMode
  });
});
ipcMain.handle("session:approval-deny", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  if (!session.pendingApproval) {
    return session;
  }
  clearPendingApproval(session);
  appendBlock(session, "status", lt("custom.permission.denied"));
  return session;
});
ipcMain.handle("session:dismiss-dangerous-warning", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  session.dangerousCommandWarning = null;
  emitSessions();
  return session;
});
ipcMain.handle("session:dismiss-sensitive-warning", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  session.sensitiveFileWarning = null;
  emitSessions();
  return session;
});
ipcMain.handle("session:stop", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session) {
    throw new Error("Session not found");
  }
  if (session.child && !session.child.killed) {
    session.child.kill();
  }
  session.child = null;
  session.isProcessing = false;
  session.isRunning = false;
  session.claudeActivity = "idle";
  appendBlock(session, "status", lt("custom.stopped"));
  return session;
});

ipcMain.handle("session:remove", async (_event, sessionId) => {
  sessions.delete(sessionId);
  emitSessions();
});
ipcMain.handle("session:context-menu", async (_event, sessionId) => {
  const session = sessions.get(sessionId);
  if (!session || !mainWindow) {
    return;
  }

  const template = [
    {
      label: lt("custom.open.project"),
      click: () => {
        void shell.openPath(session.projectPath);
      }
    },
    {
      label: lt("custom.reveal.explorer"),
      click: () => {
        shell.showItemInFolder(session.projectPath);
      }
    },
    {
      label: lt("custom.path.copy"),
      click: () => {
        clipboard.writeText(session.projectPath);
      }
    },
    { type: "separator" },
    {
      label: lt("custom.remove.session"),
      click: () => {
        sessions.delete(sessionId);
        emitSessions();
      }
    }
  ];

  Menu.buildFromTemplate(template).popup({ window: mainWindow });
});

ipcMain.handle("path:open", async (_event, targetPath) => shell.openPath(targetPath));
ipcMain.handle("path:reveal", async (_event, targetPath) => shell.showItemInFolder(targetPath));
ipcMain.handle("app:open-external", async (_event, targetUrl) => shell.openExternal(targetUrl));
ipcMain.handle("clipboard:copy", async (_event, text) => clipboard.writeText(String(text ?? "")));
ipcMain.handle("bug:capture-current-view", async () => {
  if (!mainWindow) return null;
  const image = await mainWindow.webContents.capturePage();
  return {
    path: "",
    dataUrl: image.toDataURL()
  };
});
ipcMain.handle("bug:pick-image-file", async () => {
  const result = await dialog.showOpenDialog({
    properties: ["openFile"],
    filters: [{ name: "Images", extensions: ["png", "jpg", "jpeg", "webp"] }]
  });
  if (result.canceled || result.filePaths.length === 0) return null;
  const filePath = result.filePaths[0];
  const buffer = await fs.readFile(filePath);
  const extension = path.extname(filePath).toLowerCase().slice(1) || "png";
  return {
    path: filePath,
    dataUrl: `data:image/${extension === "jpg" ? "jpeg" : extension};base64,${buffer.toString("base64")}`
  };
});
