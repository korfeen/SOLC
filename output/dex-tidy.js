// One-off (2026-11-05): the Collection's tiles say only their number and name (one line, cut with "..." if long); a piece
// you've painted gets the little gold coin in its corner instead of "MINTED"; the details on the right are trimmed to
// what matters (rarity; painted how often and first when; how to unlock it if locked).
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const f = "PixCollection.lua";
let s = fs.readFileSync(f, "utf8");
const nl = s.includes("\r\n") ? "\r\n" : "\n";
function rep(a, b) {
  a = a.split("\n").join(nl); b = b.split("\n").join(nl);
  if (s.split(a).length !== 2) throw Error(a.slice(0, 60));
  s = s.replace(a, () => b);
}
rep(`        local lines = {
            ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.rarity:upper()),
            entry.state,
            option.retired and "Retired from minting" or entry.unlocked and "Unlocked: this piece can roll in your pictures." or "Locked: this piece cannot roll yet.",
            own and ("Personally minted: %d picture%s using this piece."):format(own.count, own.count == 1 and "" or "s") or "Not minted with this piece yet.",
        }
        if own and own.first then lines[#lines + 1] = "First minted: " .. date("%Y-%m-%d", own.first) end
        lines[#lines + 1] = ns.PixCollectionUnlockText(option)`,
`        -- (what matters: its rarity, how often you've painted it, and - locked - how to get it)
        local lines = { ("|c%s%s|r"):format(ns.RARITY_COLORS[option.rarity] or "ffffffff", option.rarity:upper()) }
        if own then
            lines[#lines + 1] = ("Painted %dx%s"):format(own.count, own.first and ("  -  first on " .. date("%Y-%m-%d", own.first)) or "")
        elseif entry.unlocked then
            lines[#lines + 1] = "Not in a picture yet."
        end
        if option.retired then lines[#lines + 1] = "Retired: it doesn't turn up any more."
        elseif not entry.unlocked then lines[#lines + 1] = "Locked. " .. ns.PixCollectionUnlockText(option) end`);
rep(`                tile.caption:SetText(("#%03d %s\\n%s"):format(entry.number, entry.seen and entry.option.name or "Unknown",
                    entry.state))`,
`                tile.caption:SetText(("#%03d %s"):format(entry.number, entry.seen and entry.option.name or "???"))
                tile.coin:SetShown(entry.minted and true or false)  -- (painted by you: the gold coin)`);
rep(`        tile.caption:SetPoint("BOTTOM", 0, 4) tile.caption:SetWidth(116)`,
`        tile.caption:SetPoint("BOTTOM", 0, 6) tile.caption:SetWidth(112)
        tile.caption:SetWordWrap(false)  -- (one line: a long name ends in "...")
        tile.coin = tile:CreateTexture(nil, "OVERLAY")
        tile.coin:SetTexture("Interface\\\\AddOns\\\\SOLC\\\\Media\\\\Icons\\\\Fx_Coin")
        tile.coin:SetSize(22, 22)
        tile.coin:SetPoint("TOPRIGHT", 3, 3)
        tile.coin:Hide()`);
fs.writeFileSync(f, s);
console.log("done");
