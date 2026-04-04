const { spawnSync } = require("node:child_process");

function getRollupNativePackage() {
  if (process.platform !== "win32") return null;
  if (process.arch === "x64") return "@rollup/rollup-win32-x64-msvc";
  if (process.arch === "arm64") return "@rollup/rollup-win32-arm64-msvc";
  if (process.arch === "ia32") return "@rollup/rollup-win32-ia32-msvc";
  return null;
}

function ensureRollupNative() {
  const nativePackage = getRollupNativePackage();
  if (!nativePackage) return;

  try {
    require.resolve(nativePackage);
    return;
  } catch {}

  const rollupVersion = require("rollup/package.json").version;
  const npmCommand = process.platform === "win32" ? "npm.cmd" : "npm";
  const result = spawnSync(npmCommand, ["install", "--no-save", `${nativePackage}@${rollupVersion}`], {
    stdio: "inherit",
    shell: false
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

ensureRollupNative();
