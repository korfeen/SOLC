// One-off (2026-11-05): /solc pretend <rank> on any character: the rooms of that rank open for this session only (not
// saved: a /reload ends it), without the steward's rank-up talks playing or being marked seen, and without bounties
// counting - the real rank and its rank-ups stay as they were. /solc pretend alone stops.
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
[`function ns.TourRank()
    if preview then return LAST_RANK end`,
 `local pretend  -- (/solc pretend <rank>: this session only, any character)
function ns.TourRank()
    if preview then return LAST_RANK end
    if pretend then return pretend end`],
[`    if current and not current.timed then return end  -- (already talking: the rest come next time; a remark gives way)`,
 `    if current and not current.timed then return end  -- (already talking: the rest come next time; a remark gives way)
    if pretend and not replay then return end  -- (pretending: the real rank-up talks wait for the real ranks)`],
[`        if tour and current.id and not preview then tour.seen[current.id] = true end`,
 `        if tour and current.id and not preview and not pretend then tour.seen[current.id] = true end`],
[`    if tour and not preview then
        local rank = ns.TourRank()`,
 `    if tour and not preview and not pretend then
        local rank = ns.TourRank()`],
[`        local rank = msg:match("^tourrank%s*(%d*)$")`,
 `        local pretendRank = msg:match("^pretend%s*(%d*)$")
        if pretendRank then  -- (any character, this session only: the rooms of a rank to look round, nothing saved)
            pretend = tonumber(pretendRank)
            Close()
            if ns.UI.RelayoutSidebar then ns.UI.RelayoutSidebar() end
            if ns.UI.window and ns.UI.window:IsShown() and ns.OpenPage then ns.OpenPage("overview") end
            if ns.Print then
                ns.Print(pretend and ("Pretending Ogre Rank %d this session: its rooms are open. No rank-up talks, no bounties. /solc pretend to stop."):format(pretend)
                    or "Back to your own rank.")
            end
            return
        end
        local rank = msg:match("^tourrank%s*(%d*)$")`],
[`-- dev: /solc tourrank <n> | /solc tourrank. The rest goes to Core.lua's handler.`,
 `-- /solc pretend <n> | /solc pretend (any character, this session: a rank's rooms open, nothing saved, no rank-up talks,
-- no bounties); dev: /solc tourrank <n> | /solc tourrank. The rest goes to Core.lua's handler.
function ns.Pretending() return pretend ~= nil end`],
]);

edit("Posters.lua", [[
`    if ns.RankLocked and ns.RankLocked("bounties") then return end  -- (no posters before the board opens: Onboarding.lua)`,
`    if ns.RankLocked and ns.RankLocked("bounties") then return end  -- (no posters before the board opens: Onboarding.lua)
    if ns.Pretending and ns.Pretending() then return end  -- (nor while only pretending a rank)`]]);
console.log("done");
