// One-off (2026-11-05): Reginald's remarks (a locked room, the empty showcase, the inventory's first look) are timed:
// no buttons, gone after a few seconds (longer lines stay longer), a click on the bubble sends them off sooner. They
// never cut into a tour he's giving.
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
[`function ns.SayLocked(key)
    local rank = PAGE_RANKS[key] or (key == "dreambed" and PAGE_RANKS.pixcollection)
    if not rank then return end
    local text = ("%s opens at Ogre Rank %d. You are not Ogre Rank %d. Off you go."):format(NAMES[key] or "That room", rank, rank)
    if not CanShow() or current then
        if ns.Print then ns.Print(text) end
        return
    end
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end`,
`-- A remark: one line, no buttons, gone by itself after a while (a click on the bubble sends it off sooner). Never over
-- a tour he's giving (then it goes to the chat); a remark in its place is replaced.
local remarkToken = 0
local function Remark(text)
    if not CanShow() or (current and not current.timed) then
        if ns.Print then ns.Print(text) end
        return false
    end
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true, timed = true }, 1
    wipe(queue)
    ShowLine()
    remarkToken = remarkToken + 1
    local token, mine = remarkToken, current
    C_Timer.After(math.min(9, 3 + #text / 22), function()
        if token == remarkToken and current == mine then Close() end
    end)
    return true
end

function ns.SayLocked(key)
    local rank = PAGE_RANKS[key] or (key == "dreambed" and PAGE_RANKS.pixcollection)
    if not rank then return end
    Remark(("%s opens at Ogre Rank %d. You are not Ogre Rank %d. Off you go."):format(NAMES[key] or "That room", rank, rank))
end`],
[`function ns.StewardSay(lines)
    local text = type(lines) == "table" and lines[math.random(#lines)] or lines
    if not CanShow() then if ns.Print then ns.Print(text) end return end
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end`,
`function ns.StewardSay(lines)
    Remark(type(lines) == "table" and lines[math.random(#lines)] or lines)
end`],
[`    if not tour or tour.seen[id] or not CanShow() or current then return end
    tour.seen[id] = true
    if not panel then Build() end
    current, line = { lines = { { text = text } }, single = true }, 1
    wipe(queue)
    ShowLine()
end`,
`    if not tour or tour.seen[id] or not CanShow() or (current and not current.timed) then return end
    if Remark(text) then tour.seen[id] = true end
end`],
[`local function Say(text, glowKey, last, single)
    panel.text:SetText(text)
    panel.bubble:ClearAllPoints()
    panel.bubble:SetPoint("BOTTOMRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
    panel.bubble:SetSize(308, panel.text:GetStringHeight() + 58)`,
`local function Say(text, glowKey, last, single, timed)
    panel.text:SetText(text)
    panel.bubble:ClearAllPoints()
    panel.bubble:SetPoint("BOTTOMRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
    panel.bubble:SetSize(308, panel.text:GetStringHeight() + (timed and 26 or 58))  -- (a remark: no buttons under it)
    panel.next:SetShown(not timed)`],
[`    panel.skip:SetShown(not last and not single)`, `    panel.skip:SetShown(not last and not single and not timed)`],
[`    Say(step_line.reaction and Reaction() or step_line.text, step_line.glow, line == #current.lines and #queue == 0, current.single)`,
 `    Say(step_line.reaction and Reaction() or step_line.text, step_line.glow, line == #current.lines and #queue == 0, current.single,
        current.timed)`],
[`    panel.bubble:EnableMouse(true)  -- (clicks on it don't fall through to the page)`,
 `    panel.bubble:EnableMouse(true)  -- (clicks on it don't fall through to the page)
    panel.bubble:SetScript("OnMouseUp", function() if current and current.timed then Close() end end)  -- (a remark: off it goes)`],
]);
console.log("done");
