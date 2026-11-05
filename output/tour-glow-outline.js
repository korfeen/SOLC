// One-off (2026-11-05): the tour's glow on Settings' "What SOLC tracks" is a thin gold outline with a faint wash, not
// the sidebar's button glow stretched into a blob; and it starts above the section's heading.
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
[`    glow.tex:SetVertexColor(1, 0.82, 0.3)
    glow.t = 0`,
`    glow.tex:SetVertexColor(1, 0.82, 0.3)
    -- (round a whole section instead: a thin gold outline and a faint wash)
    glow.wash = glow:CreateTexture(nil, "BACKGROUND")
    glow.wash:SetAllPoints()
    glow.wash:SetColorTexture(1, 0.82, 0.3, 0.06)
    glow.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = glow:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.82, 0.3, 0.95)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        glow.edges[i] = edge
    end
    glow.t = 0`],
[`    local button = key == "tracks" and ns.UI.settingsTracks or key and ns.UI.NavButton and ns.UI.NavButton(key)
    if not button or not button:IsShown() then glow:Hide() return end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -10, 6)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 10, -6)`,
`    local section = key == "tracks"
    local button = section and ns.UI.settingsTracks or key and ns.UI.NavButton and ns.UI.NavButton(key)
    if not button or not button:IsShown() then glow:Hide() return end
    glow:ClearAllPoints()
    local pad = section and 0 or 10
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad * 0.6)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad * 0.6)
    glow.tex:SetShown(not section)
    glow.wash:SetShown(section)
    for _, edge in ipairs(glow.edges) do edge:SetShown(section) end`],
]);

edit("Settings.lua", [[
`        UI.settingsTracks:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT - 18, -58)
        UI.settingsTracks:SetSize(96 + #ns.PRIVACY_CHOICES * 74 + 30, ry + ROW + 10 - 58)`,
`        UI.settingsTracks:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT - 20, -48)
        UI.settingsTracks:SetSize(96 + #ns.PRIVACY_CHOICES * 74 + 34, ry + ROW + 12 - 48)`]]);
console.log("done");
