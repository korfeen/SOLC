// One-off (2026-11-05): /solc tour all, on any character: every page open for the length of it and every step played,
// welcome to the last rank's; then the locks are back and nothing's marked seen (the real rank-ups still come).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(file, pairs) {
  let s = fs.readFileSync(file, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (const [a, b] of pairs) {
    const from = a.replace(/\n/g, nl), to = b.replace(/\n/g, nl);
    const n = s.split(from).length - 1;
    if (n !== 1) throw Error(`${file}: found ${n} times: ${a.slice(0, 70)}`);
    s = s.replace(from, () => to);
  }
  fs.writeFileSync(file, s);
}

edit("Onboarding.lua", [
[`-- The rank the locks and the tour go by: yours (a dev character's pretend one while set).
function ns.TourRank()
    local db = KillTrackerDB`,
`-- The rank the locks and the tour go by: yours (a dev character's pretend one while set; the last step's during
-- /solc tour all, the preview).
local preview = false
local LAST_RANK = 1
for _, step in ipairs(STEPS) do LAST_RANK = math.max(LAST_RANK, step.rank) end
function ns.TourRank()
    if preview then return LAST_RANK end
    local db = KillTrackerDB`],
[`local function Close()
    current, line = nil, 0
    wipe(queue)
    if panel then panel:Hide() end
    if glow then glow:Hide() end
end`,
`local function Close()
    current, line = nil, 0
    wipe(queue)
    if panel then panel:Hide() end
    if glow then glow:Hide() end
    if preview then  -- (the preview's over: the locks are back)
        preview = false
        if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
        if ns.UI.window and ns.UI.window:IsShown() and ns.OpenPage then ns.OpenPage("overview") end
        if ns.Print then ns.Print("Tour preview over: back to your own rank. /solc tour reset to start the real one fresh.") end
    end
end`],
[`    if line >= #current.lines then
        if tour and current.id then tour.seen[current.id] = true end`,
`    if line >= #current.lines then
        if tour and current.id and not preview then tour.seen[current.id] = true end`],
[`    if tour then
        local rank = ns.TourRank()
        for _, step in ipairs(STEPS) do if step.rank <= rank then tour.seen[step.id] = true end end
    end
    Close()`,
`    if tour and not preview then
        local rank = ns.TourRank()
        for _, step in ipairs(STEPS) do if step.rank <= rank then tour.seen[step.id] = true end end
    end
    Close()`],
[`        elseif msg == "tour reset" then`,
`        elseif msg == "tour all" then  -- (the preview: every step, every page open till it's over)
            if not (ns.UI.window and ns.UI.window:IsShown()) and ns.ToggleUI then ns.ToggleUI() end
            C_Timer.After(0.35, function()
                Close()
                preview = true
                if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
                ns.StartTour(true)
            end)
            if ns.Print then ns.Print("Tour preview: every step, every room open till it's over. Nothing is marked seen.") end
            return
        elseif msg == "tour reset" then`],
[`-- /solc tour (every step up to your rank again), /solc tour reset (as new: next open starts from the welcome);`,
 `-- /solc tour (every step up to your rank again), /solc tour all (the preview: every step of every rank, the rooms open
-- till it's over, nothing marked seen), /solc tour reset (as new: next open starts from the welcome);`],
]);
console.log("done");
