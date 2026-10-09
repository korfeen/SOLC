// Matches every WoW Forever dungeon encounter (de-forever.csv) to its boss creature(s): by name in Questie's WoW
// Forever NPC data (elite and boss ranks preferred), plus hand-made entries for encounters with several bosses or
// another name. Writes references/encounters.csv.
// Inputs: Questie's WoW Forever data (QuestieDB_Forever.toc from a Questie release) and wago.tools' DungeonEncounter
// table for the product wow_classic_beta (de-forever.csv), both in this script's folder when run.
// Usage: node tools/match-encounters.js   then node tools/build-encounters.js
const fs = require("fs"), path = require("path");
const toc = fs.readFileSync(path.join(__dirname, "questie/QuestieDB/QuestieDB_Forever.toc"), "utf8");
const store = {};
for (const line of toc.split(/\r?\n/)) { const m = line.match(/^## (X-[^:]+): (.*)$/); if (m) store[m[1]] = m[2]; }
const getStored = (key) => {
  const v = store[key]; if (!v || v[0] !== "~") return v;
  const parts = +v.slice(1).match(/\d+/)[0]; let out = ""; for (let i = 1; i <= parts; i++) out += store[key + "-" + i]; return out;
};
function cbor(buf) {
  let i = 0;
  const len = (info) => { if (info < 24) return info; if (info === 24) return buf[i++]; if (info === 25) { const v = buf.readUInt16BE(i); i += 2; return v; }
    if (info === 26) { const v = buf.readUInt32BE(i); i += 4; return v; } const v = Number(buf.readBigUInt64BE(i)); i += 8; return v; };
  const item = () => {
    const b = buf[i++], major = b >> 5, info = b & 31;
    switch (major) {
      case 0: return len(info); case 1: return -1 - len(info);
      case 2: { const n = len(info); const v = buf.subarray(i, i + n); i += n; return v; }
      case 3: { const n = len(info); const v = buf.toString("utf8", i, i + n); i += n; return v; }
      case 4: { const n = len(info), a = []; for (let k = 0; k < n; k++) a.push(item()); return a; }
      case 5: { const n = len(info), o = {}; for (let k = 0; k < n; k++) { const key = item(); o[key] = item(); } return o; }
      case 6: len(info); return item();
      case 7: if (info === 20) return false; if (info === 21) return true; if (info === 22 || info === 23) return null;
        if (info === 25) { i += 2; return 0; } if (info === 26) { const v = buf.readFloatBE(i); i += 4; return v; }
        if (info === 27) { const v = buf.readDoubleBE(i); i += 8; return v; } return info;
    }
  };
  return item();
}
const byName = {};
for (const key of Object.keys(store)) {
  const m = key.match(/^X-Npc-(\d+)-S$/); if (!m) continue;
  const row = cbor(Buffer.from(getStored(key), "base64"));
  if (!row || !row[1]) continue;
  const name = (Buffer.isBuffer(row[1]) ? row[1].toString("utf8") : String(row[1])).toLowerCase();
  (byName[name] ??= []).push({ id: +m[1], rank: row[6] || 0 });
}
// Encounters with several bosses or another name: their creatures by name.
const MANUAL = {
  "The Seven": ["Anger'rel", "Seeth'rel", "Dope'rel", "Gloom'rel", "Vile'rel", "Hate'rel", "Doom'rel"],
  "The Lost Dwarves": ["Baelog", "Eric \"The Swift\"", "Olaf"],
  "Silithid Royalty": ["Lord Kri", "Princess Yauj", "Vem"],
  "Twin Emperors": ["Emperor Vek'lor", "Emperor Vek'nilash"],
  "The Four Horsemen": ["Thane Korth'azz", "Lady Blaumeux", "Highlord Mograine", "Sir Zeliek"],
  "Dreamscythe and Weaver": ["Dreamscythe", "Weaver"],
  "Jammal'an and Ogom": ["Jammal'an the Prophet", "Ogom the Wretched"],
  "Morphaz and Hazzas": ["Morphaz", "Hazzas"],
  "Ras Frostwhisperer": ["Ras Frostwhisper"],
  "Festering Rotslime": ["Festering Rotslime"],
  "Ring of Law": [],
};
const proper = {};  // id -> the creature's name as written
const pick = (name) => {
  let c = byName[name.toLowerCase()] || [];
  if (c.length > 1) { const e = c.filter((x) => x.rank > 0); if (e.length) c = e; }
  if (c.length > 3) c = c.slice(0, 3);
  for (const x of c) proper[x.id] = name;
  return c.map((x) => x.id);
};
const rows = [], missing = [], seen = new Set();
for (const l of fs.readFileSync(path.join(__dirname, "de-forever.csv"), "utf8").trim().split(/\r?\n/).slice(1)) {
  const m = l.match(/^("(?:[^"]|"")*"|[^,]*),(\d+),(\d+),/);
  if (!m) continue;
  const name = m[1].replace(/^"|"$/g, "").replace(/""/g, '"'), id = +m[2], map = +m[3];
  if (seen.has(id)) continue; seen.add(id);
  const names = MANUAL[name] || [name];
  const npcs = [...new Set(names.flatMap(pick))];
  if (npcs.length) rows.push([id, name, map, npcs.join(" "), npcs.map((n) => proper[n]).join("|")]); else missing.push(`${id} ${name} (map ${map})`);
}
const q = (s) => '"' + s.replace(/"/g, '""') + '"';
const csv = ["encounterID,name,map,npcIDs,npcNames", ...rows.map(([id, n, map, npcs, names]) => `${id},${q(n)},${map},${npcs},${q(names)}`)];
fs.writeFileSync("C:/Users/faluk/Projects/SOLC/references/encounters.csv", csv.join("\n") + "\n");
console.log("matched", rows.length, "missing", missing.length);
console.log(missing.join("\n"));
for (const n of ["Dextren Ward", "Bazil Thredd", "Durgen Dirgehammer", "Rath'mael", "Relic Guardian", "The Seven", "Twin Emperors"]) {
  const r = rows.find((x) => x[1] === n); console.log(n, r ? r[3] : "-");
}
