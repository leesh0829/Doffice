const { spawnSync } = require("node:child_process");

function getRollupNativePackage() {
  if (process.platform === "win32") {
    if (process.arch === "x64") return "@rollup/rollup-win32-x64-msvc";
    if (process.arch === "arm64") return "@rollup/rollup-win32-arm64-msvc";
    if (process.arch === "ia32") return "@rollup/rollup-win32-ia32-msvc";
    return null;
  }

  if (process.platform === "linux") {
    const report = typeof process.report?.getReport === "function" ? process.report.getReport() : null;
    const isMusl = !report?.header?.glibcVersionRuntime;
    if (process.arch === "x64") return isMusl ? "@rollup/rollup-linux-x64-musl" : "@rollup/rollup-linux-x64-gnu";
    if (process.arch === "arm64") return isMusl ? "@rollup/rollup-linux-arm64-musl" : "@rollup/rollup-linux-arm64-gnu";
    if (process.arch === "arm") return "@rollup/rollup-linux-arm-gnueabihf";
    return null;
  }

  if (process.platform === "darwin") {
    if (process.arch === "x64") return "@rollup/rollup-darwin-x64";
    if (process.arch === "arm64") return "@rollup/rollup-darwin-arm64";
    return null;
  }

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
