// The night run: paints what's still waiting in tools/gen-art-night.json once Codex has images again (its limit resets
// at night). A job is waiting when its picture is missing, or (with "since": a time in ms) when it's older than that -
// a repaint. Runs the waiting ones; if any are left (the limit again), tries again every hour, up to 6 times.
// Started by Windows Task Scheduler ("SOLC night art"), or by hand: node tools/night-art.js
// Log: %USERPROFILE%\killtracker-art-extra\Unlocks\generated\night-art.log
const fs = require("fs"), os = require("os"), path = require("path");
const { spawnSync } = require("child_process");
const LIST = path.join(__dirname, "gen-art-night.json");
const OUT = path.join(os.homedir(), "killtracker-art-extra", "Unlocks", "generated");
const LOG = path.join(OUT, "night-art.log");
const say = (s) => { const line = `${new Date().toLocaleString("sv-SE")} ${s}`; console.log(line); fs.appendFileSync(LOG, line + "\n"); };
const waiting = () => JSON.parse(fs.readFileSync(LIST, "utf8")).filter((j) => {
  const ed = (j.flags || []).includes("--edition") ? j.flags[j.flags.indexOf("--edition") + 1] : "painted";
  const file = path.join(OUT, ed, j.id + ".png");
  return !fs.existsSync(file) || (j.since && fs.statSync(file).mtimeMs < j.since);
});
(async () => {
  for (let tryN = 1; tryN <= 6; tryN++) {
    const jobs = waiting();
    say(`try ${tryN}: ${jobs.length} waiting${jobs.length ? " (" + jobs.map((j) => j.id).join(", ") + ")" : ""}`);
    if (!jobs.length) { say("all painted"); return; }
    const tmp = path.join(os.tmpdir(), "solc-night-queue.json");
    fs.writeFileSync(tmp, JSON.stringify(jobs.map(({ since, ...j }) => j), null, 1));
    spawnSync(process.execPath, [path.join(__dirname, "gen-art.js"), "--queue", tmp, "--redo"], { stdio: "inherit", cwd: path.join(__dirname, "..") });
    if (!waiting().length) { say("all painted"); return; }
    if (tryN < 6) await new Promise((r) => setTimeout(r, 3600 * 1000));
  }
  say(`stopped: ${waiting().length} still waiting`);
})();
