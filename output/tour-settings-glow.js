// One-off (2026-11-05): the steward's privacy talk opens Settings and lights up its "What SOLC tracks" section instead
// of putting the choices in his speech bubble (the bubble's form is gone).
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

// Onboarding.lua: cut the form (FormRows .. BuildForm) out whole.
let o = fs.readFileSync("Onboarding.lua", "utf8");
const nl = o.includes("\r\n") ? "\r\n" : "\n";
const a = o.indexOf("-- The privacy form, under his words:");
const b = o.indexOf("-- What he thinks of your choices in the form.");
if (a < 0 || b < 0 || b < a) throw Error("form block");
o = o.slice(0, a) + o.slice(b);
fs.writeFileSync("Onboarding.lua", o);

edit("Onboarding.lua", [
[`{ text = "Before you go. The club keeps records. Some members prefer... discretion. Tell me what I may write down about you. You may change your mind later: Settings, the cog, top right.", form = true },`,
 `{ text = "Before you go. The club keeps records. Some members prefer... discretion. Mark what I may write down about you, there, in the Settings. You may change your mind whenever you like.", open = "settings", glow = "tracks" },`],
[`-- What he thinks of your choices in the form.`, `-- What he thinks of your choices (Settings' "What SOLC tracks").`],
[`local function Glow(key)
    local button = key and ns.UI.NavButton and ns.UI.NavButton(key)`,
`local function Glow(key)
    -- (a sidebar button by its page, or "tracks": Settings' "What SOLC tracks" section)
    local button = key == "tracks" and ns.UI.settingsTracks or key and ns.UI.NavButton and ns.UI.NavButton(key)`],
[`local function Say(text, glowKey, last, single, form)
    panel.text:SetText(text)
    -- (the form: in the bubble under his words, the bubble hanging down over the page so it fits on the screen)
    if form and not panel.form then BuildForm() end
    if panel.form then panel.form:SetShown(form and true or false) end
    panel.bubble:ClearAllPoints()
    if form then
        panel.form:ClearAllPoints()
        panel.form:SetPoint("TOPLEFT", panel.text, "BOTTOMLEFT", 0, -10)
        RefreshForm()
        panel.bubble:SetPoint("TOPRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -BEAM_MIDDLE - 18)
        panel.bubble:SetSize(308, panel.text:GetStringHeight() + panel.form:GetHeight() + 68)
    else
        panel.bubble:SetPoint("BOTTOMRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
        panel.bubble:SetSize(308, panel.text:GetStringHeight() + 58)
    end
    panel.tail:SetShown(not form)`,
`local function Say(text, glowKey, last, single)
    panel.text:SetText(text)
    panel.bubble:ClearAllPoints()
    panel.bubble:SetPoint("BOTTOMRIGHT", ns.UI.window, "TOPLEFT", STAND_X - OGRE * 0.3, -TOP_BEAM_TOP + 46)
    panel.bubble:SetSize(308, panel.text:GetStringHeight() + 58)`],
[`    Say(step_line.reaction and Reaction() or step_line.text, step_line.glow, line == #current.lines and #queue == 0, current.single,
        step_line.form)`,
 `    Say(step_line.reaction and Reaction() or step_line.text, step_line.glow, line == #current.lines and #queue == 0, current.single)`],
]);

edit("Settings.lua", [[
`            choiceRows[#choiceRows + 1] = row
        end
`,
`            choiceRows[#choiceRows + 1] = row
        end
        -- (the section's whole area, for the steward's tour to light up: Onboarding.lua)
        UI.settingsTracks = UI.settingsTracks or CreateFrame("Frame", nil, page)
        UI.settingsTracks:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT - 18, -58)
        UI.settingsTracks:SetSize(96 + #ns.PRIVACY_CHOICES * 74 + 30, ry + ROW + 10 - 58)
`]]);
console.log("done");
