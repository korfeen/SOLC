// One-off (2026-11-05): "mint" out of everything players read - paint for the picture, dream for the act. (Code names,
// saved data and the feed's event letters stay as they are.)
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
const EDITS = {
  "CavePage.lua": [[`"Pictures minted and won"`, `"Pictures painted and won"`], [`"Pictures minted", "pixcollection"`, `"Pictures painted", "pixcollection"`]],
  "Chests.lua": [[`"Unlocked for minting: %s."`, `"Unlocked for your dreams: %s."`]],
  "Feed.lua": [[`e.k == "M" and "minted" or "won"`, `e.k == "M" and "painted" or "won"`], [`"%s minted %spicture #%s"`, `"%s painted %spicture #%s"`],
    [`"%s unlocked |c%s%s|r for minting"`, `"%s unlocked |c%s%s|r for their dreams"`]],
  "FeedDetail.lua": [[`("Minted by %s")`, `("Painted by %s")`], [`("Unlocked for minting: |c%s%s %s|r")`, `("Unlocked for dreams: |c%s%s %s|r")`]],
  "Gallery.lua": [[`{ "Mint a picture", "Off to the Dream Bed`, `{ "Dream a picture", "Off to the Dream Bed`], [`thumb.caption:SetText("MINT")`, `thumb.caption:SetText("DREAM")`]],
  "GuildPages.lua": [[`"Mint a picture to get backgrounds"`, `"Dream a picture to get backgrounds"`]],
  "OverviewCard.lua": [[`"Mint a picture to get backgrounds"`, `"Dream a picture to get backgrounds"`],
    [`"For your pictures. Minting opens at Ogre Rank 3."`, `"For your pictures. Dreaming opens at Ogre Rank 3."`]],
  "ProfileHeader.lua": [[`"Mint a picture to get backgrounds"`, `"Dream a picture to get backgrounds"`]],
  "Minting.lua": [[`"%s minted this picture first. Reroll it for free?"`, `"%s painted this picture first. Reroll it for free?"`]],
  "MintReel.lua": [[`ns.UI.ClearScreen("Minting")`, `ns.UI.ClearScreen("Dreaming")`], [`panel.title:SetText("Minting...")`, `panel.title:SetText("Dreaming...")`],
    [`ns.UI.SetScreen("Minting", "SPIN"`, `ns.UI.SetScreen("Dreaming", "SPIN"`]],
  "PixCollection.lua": [[`'MINTED' or unlocked`, `'PAINTED' or unlocked`], [`'Retired from minting.'`, `'Retired: it no longer turns up in dreams.'`],
    [`'Available when you mint a picture.'`, `'Turns up in any dream.'`], [`'Earn its wardrobe unlock to mint this piece.'`, `'Earn its wardrobe unlock to dream of it.'`],
    [`{ "minted", "MINTED" }`, `{ "minted", "PAINTED" }`], [`"%d / %d seen  -  %d unlocked  -  %d minted"`, `"%d / %d seen  -  %d unlocked  -  %d painted"`]],
  "PixPage.lua": [[`("MINT  |T%s:12|t`, `("DREAM  |T%s:12|t`], [`{ "Mint a picture", ns.BonksLine()`, `{ "Dream a picture", ns.BonksLine()`]],
  "Ranks.lua": [[`"Lucky minting: epic`, `"Lucky dreams: epic`], [`"Luckier minting: epic`, `"Luckier dreams: epic`], [`"Luckiest minting: epic`, `"Luckiest dreams: epic`]],
  "UI.lua": [[`GameTooltip:AddLine("Mint a picture")`, `GameTooltip:AddLine("Dream a picture")`], [`"|cffffd100+ Mint a picture|r"`, `"|cffffd100+ Dream a picture|r"`]],
  "Unlocks.lua": [[`"Unlocked for minting!", name, "Worn`, `"Unlocked for your dreams!", name, "Worn`],
    [`"Unlocked for minting!", name, "It can`, `"Unlocked for your dreams!", name, "It can`]],
};
for (const [file, pairs] of Object.entries(EDITS)) {
  let s = fs.readFileSync(file, "utf8");
  for (const [a, b] of pairs) {
    if (s.split(a).length !== 2) throw Error(`${file}: ${a}`);
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(file, s);
}
console.log("done");
