// Generates ../Data.lua: NPC ID -> faction, creature type, rank, subtype and size.
// Subtype rules live in subtypes.js, faction corrections (tribes, clans, leaders) in factions.js.
// Sources:
//   CMaNGOS classic-db (creature_template)                        https://github.com/cmangos/classic-db
//   wago.tools Classic Era DB2 exports (factions, creature models)  https://wago.tools
//   wowdev community listfile (model file paths, ~150 MB)          https://github.com/wowdev/wow-listfile
// Usage: node tools/build-data.js   (Node 18+, no dependencies)

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const DB_URL = "https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz";
const DB2_URL = (table) => `https://wago.tools/db2/${table}/csv?product=wow_classic_era`;
const LISTFILE_URL = "https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv";
const { TYPE_NAMES, subtypeFor } = require("./subtypes");
const { fixFactions, assignBySpawns, groupBeasts, resolveLeaders, resolveRaceLeaders, resolveOverlords } = require("./factions");
const OUT = path.join(__dirname, "..", "Data.lua");

async function download(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${url}`);
    return Buffer.from(await res.arrayBuffer());
}

function parseCsv(text) {
    const rows = [];
    let row = [], field = "", quoted = false;
    for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (quoted) {
            if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
            else if (c === '"') quoted = false;
            else field += c;
        } else if (c === '"') quoted = true;
        else if (c === ",") { row.push(field); field = ""; }
        else if (c === "\n") { row.push(field.replace(/\r$/, "")); rows.push(row); row = []; field = ""; }
        else field += c;
    }
    if (field || row.length) { row.push(field); rows.push(row); }
    const header = rows.shift();
    return rows.filter((r) => r.length === header.length)
        .map((r) => Object.fromEntries(header.map((h, i) => [h, r[i]])));
}

// Column names from the CREATE TABLE statement, in order.
function sqlColumns(sql, table) {
    const start = sql.indexOf("CREATE TABLE `" + table + "`");
    const body = sql.slice(start, sql.indexOf(";", start));
    return [...body.matchAll(/^\s+`(\w+)`/gm)].map((m) => m[1]);
}

// All value tuples from INSERT INTO `table` VALUES (...),(...);
function sqlRows(sql, table) {
    const rows = [];
    const marker = "INSERT INTO `" + table + "` VALUES ";
    let pos = 0;
    while ((pos = sql.indexOf(marker, pos)) !== -1) {
        let i = pos + marker.length;
        let row = null, field = "", inStr = false, isStr = false;
        for (; i < sql.length; i++) {
            const c = sql[i];
            if (inStr) {
                if (c === "\\") { field += sql[++i]; }
                else if (c === "'") inStr = false;
                else field += c;
            } else if (c === "'") { inStr = true; isStr = true; }
            else if (c === "(" && row === null) { row = []; field = ""; isStr = false; }
            else if (c === "," && row !== null) { row.push(isStr ? field : field.trim()); field = ""; isStr = false; }
            else if (c === ")" && row !== null) { row.push(isStr ? field : field.trim()); rows.push(row); row = null; }
            else if (c === ";" && row === null) break;
            else if (row !== null) field += c;
        }
        pos = i;
    }
    return rows;
}

const luaStr = (s) => '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';

// Name matching. Core.lua looks names up lowercased and splits them into words on [^a-z'].
const STOP_WORDS = new Set(["the", "of", "and", "a", "an"]);
const normalizeName = (name) => name.toLowerCase().trim();
const nameWords = (name) => normalizeName(name).split(/[^a-z']+/)
    .filter((w) => w.length >= 3 && !STOP_WORDS.has(w));

// Picks the dominant value from Map(value -> count), or null if it isn't dominant enough.
function dominant(counts, minTotal, minShare) {
    let total = 0, best = null, bestCount = 0;
    for (const [id, n] of counts) {
        total += n;
        if (n > bestCount) { best = id; bestCount = n; }
    }
    return total >= minTotal && bestCount / total >= minShare ? { id: best, count: bestCount } : null;
}

function tally(map, key, value) {
    if (!map.has(key)) map.set(key, new Map());
    const counts = map.get(key);
    counts.set(value, (counts.get(value) || 0) + 1);
}

// Learns name -> value and name word -> value from known NPCs, to guess values for unknown ones.
function createNameIndex() {
    const byName = new Map(), byWord = new Map();
    return {
        add(name, value) {
            if (/[\[\(]|trigger|\bdnd\b/i.test(name)) return;
            tally(byName, normalizeName(name), value);
            for (const w of new Set(nameWords(name))) tally(byWord, w, value);
        },
        // names: [[name, value]], words: [[word, value, supportingNPCs]]
        finish() {
            const names = [], words = [];
            for (const [name, counts] of byName) {
                const d = dominant(counts, 1, 0.6);
                if (d) names.push([name, d.id]);
            }
            for (const [word, counts] of byWord) {
                const d = dominant(counts, 3, 0.8);
                if (d) words.push([word, d.id, d.count]);
            }
            names.sort((a, b) => a[0].localeCompare(b[0]));
            words.sort((a, b) => a[0].localeCompare(b[0]));
            return { names, words };
        },
    };
}

function writeNameIndex(out, label, index) {
    out.push(`-- [lowercase name] = ${label}, for mobs whose NPC ID is not in ns.NPCs`);
    out.push(`ns.Name${label}s = {`);
    for (const [name, id] of index.names) out.push(`[${luaStr(name)}]=${id},`);
    out.push("}");
    out.push(`-- [lowercase name word] = { ${label}, number of known NPCs supporting it }`);
    out.push(`ns.Word${label}s = {`);
    for (const [word, id, n] of index.words) out.push(`[${luaStr(word)}]={${id},${n}},`);
    out.push("}");
}

async function main() {
    console.log("Downloading CMaNGOS classic-db...");
    const sql = zlib.gunzipSync(await download(DB_URL)).toString("utf8");
    console.log("Downloading faction and creature model tables from wago.tools...");
    const templates = parseCsv((await download(DB2_URL("FactionTemplate"))).toString("utf8"));
    const factions = parseCsv((await download(DB2_URL("Faction"))).toString("utf8"));
    const displays = parseCsv((await download(DB2_URL("CreatureDisplayInfo"))).toString("utf8"));
    const models = parseCsv((await download(DB2_URL("CreatureModelData"))).toString("utf8"));
    const families = parseCsv((await download(DB2_URL("CreatureFamily"))).toString("utf8"));

    const templateToFaction = new Map(templates.map((t) => [Number(t.ID), Number(t.Faction)]));
    const factionName = new Map(factions.map((f) => [Number(f.ID), f.Name_lang]));
    const displayToModel = new Map(displays.map((d) => [Number(d.ID), Number(d.ModelID)]));
    // Model bounding box height (GeoBox max Z - min Z), in yards at scale 1.
    const modelHeight = new Map(models.map((m) => [Number(m.ID), Number(m.GeoBox_5) - Number(m.GeoBox_2)]));
    const displayScale = new Map(displays.map((d) => [Number(d.ID), Number(d.CreatureModelScale) || 1]));
    const modelToFile = new Map(models.map((m) => [Number(m.ID), Number(m.FileDataID)]));
    const familyName = new Map(families.map((f) => [Number(f.ID), f.Name_lang]));

    console.log("Downloading community listfile (~150 MB)...");
    const modelFiles = new Set(modelToFile.values());
    const filePath = new Map();
    for (const line of (await download(LISTFILE_URL)).toString("utf8").split("\n")) {
        const sep = line.indexOf(";");
        const fileID = Number(line.slice(0, sep));
        if (modelFiles.has(fileID)) filePath.set(fileID, line.slice(sep + 1).trim().toLowerCase());
    }

    const cols = sqlColumns(sql, "creature_template");
    const col = (name) => {
        const i = cols.indexOf(name);
        if (i === -1) throw new Error("creature_template has no column " + name);
        return i;
    };
    const iEntry = col("Entry"), iName = col("Name"), iFaction = col("Faction"), iType = col("CreatureType"),
        iFamily = col("Family"), iRank = col("Rank"), iScale = col("Scale"), iLevel = col("MaxLevel");
    const iModels = ["ModelId1", "ModelId2", "ModelId3", "ModelId4"].map(col);

    // Subtype and real in-game height per NPC.
    const rows = [];
    const fallbacks = new Map();
    for (const r of sqlRows(sql, "creature_template")) {
        if (r.length !== cols.length) continue;
        let factionID = templateToFaction.get(Number(r[iFaction])) || 0;
        if (!factionName.has(factionID)) factionID = 0;

        const type = Number(r[iType]);
        const display = iModels.map((i) => Number(r[i])).find((d) => d > 0);
        const fileID = modelToFile.get(displayToModel.get(display));
        const subtype = subtypeFor(type, familyName.get(Number(r[iFamily])), filePath.get(fileID));
        const isFallback = subtype === (TYPE_NAMES[type] || "Other");
        if (isFallback && filePath.has(fileID)) {
            const key = `${TYPE_NAMES[type]}: ${filePath.get(fileID).split("/")[1]}`;
            fallbacks.set(key, (fallbacks.get(key) || 0) + 1);
        }
        rows.push({
            id: Number(r[iEntry]), name: r[iName], factionID, type, rank: Number(r[iRank]), level: Number(r[iLevel]), subtype, isFallback, fileID,
            height: (modelHeight.get(displayToModel.get(display)) || 1) * (displayScale.get(display) || 1) * (Number(r[iScale]) || 1),
        });
    }
    rows.sort((a, b) => a.id - b.id);

    fixFactions(rows, factionName);
    // Spawn positions place rare/named mobs into the tribe they live among.
    const sc = sqlColumns(sql, "creature");
    const spawns = sqlRows(sql, "creature").map((r) => ({ id: Number(r[sc.indexOf("id")]), map: Number(r[sc.indexOf("map")]),
        x: Number(r[sc.indexOf("position_x")]), y: Number(r[sc.indexOf("position_y")]) }));
    const placed = assignBySpawns(rows, factionName, spawns);
    const beastsGrouped = groupBeasts(rows, factionName);
    const leaders = resolveLeaders(rows, factionName);
    const raceLeaders = resolveRaceLeaders(rows);
    const usedFactions = new Set(rows.map((n) => n.factionID).filter((id) => id));

    const subtypes = [...new Set(rows.map((n) => n.subtype))].sort();
    const subtypeID = new Map(subtypes.map((s, i) => [s, i + 1]));

    // Size = height / median height of the NPC's subtype, so 1.0 is a typical member. Heights come from
    // the model's bounding box times its scale, so they're comparable across different models.
    // Invisible triggers, placeholders and mounts would skew what "typical" means, so they're left out.
    const isRealCreature = (n) => n.height > 0.1 && n.type !== 10 && !/[\[(]|trigger|riding|\bmount\b|\bdnd\b/i.test(n.name);
    const groupHeights = new Map();
    for (const n of rows.filter(isRealCreature)) tally(groupHeights, n.subtype, n.height);
    const medians = new Map();
    for (const [key, counts] of groupHeights) {
        const heights = [...counts].flatMap(([height, count]) => Array(count).fill(height)).sort((a, b) => a - b);
        medians.set(key, heights[Math.floor(heights.length / 2)]);
    }

    // Name and model indexes, used by the addon to place mobs that are missing from this data.
    const factionIndex = createNameIndex(), subtypeIndex = createNameIndex();
    const byModel = new Map();
    for (const n of rows) {
        if (n.factionID) factionIndex.add(n.name, n.factionID);
        if (n.isFallback) continue;
        subtypeIndex.add(n.name, subtypeID.get(n.subtype));
        if (n.fileID) tally(byModel, n.fileID, subtypeID.get(n.subtype));
    }
    const modelSubtypes = [];
    for (const [fileID, counts] of byModel) {
        const d = dominant(counts, 1, 0.6);
        if (d) modelSubtypes.push([fileID, d.id]);
    }
    modelSubtypes.sort((a, b) => a[0] - b[0]);

    // Subtype -> its most common creature type, for mobs whose type the addon doesn't know.
    const subtypeTypes = new Map();
    for (const n of rows) tally(subtypeTypes, subtypeID.get(n.subtype), n.type);
    const subtypeType = new Map([...subtypeTypes].map(([id, counts]) => [subtypes[id - 1], dominant(counts, 1, 0).id]));
    const spawnCount = new Map();
    for (const sp of spawns) spawnCount.set(sp.id, (spawnCount.get(sp.id) || 0) + 1);
    const overlords = resolveOverlords(rows, subtypeType, spawnCount, factionName);

    const out = [];
    out.push("-- Generated by tools/build-data.js - do not edit by hand.");
    out.push("-- Data: CMaNGOS classic-db (creature_template), wago.tools Classic Era DB2, wowdev community listfile.");
    out.push("local _, ns = ...");
    out.push("ns.Factions = {");
    for (const id of [...usedFactions].sort((a, b) => a - b)) out.push(`[${id}]=${luaStr(factionName.get(id))},`);
    out.push("}");
    out.push("ns.Subtypes = {");
    for (const s of subtypes) out.push(luaStr(s) + ",");
    out.push("}");
    out.push("-- [subtypeID] = most common creatureType");
    out.push("ns.SubtypeTypes = {");
    for (const [id, counts] of [...subtypeTypes].sort((a, b) => a[0] - b[0])) {
        out.push(`[${id}]=${dominant(counts, 1, 0).id},`);
    }
    out.push("}");
    out.push("-- [npcID] = { factionID, creatureType, rank, subtypeID, size (1 = typical for its subtype) }");
    out.push("ns.NPCs = {");
    for (const n of rows) {
        const median = medians.get(n.subtype) || n.height;
        const size = Math.round(Math.min(2.5, Math.max(0.3, n.height / median)) * 100) / 100;
        out.push(`[${n.id}]={${n.factionID},${n.type},${n.rank},${subtypeID.get(n.subtype)},${size}},`);
    }
    out.push("}");
    out.push("-- [faction name] = { { npcID, leader name }, ... }");
    out.push("ns.Leaders = {");
    for (const [faction, list] of Object.entries(leaders).sort()) {
        out.push(`[${luaStr(faction)}]={${list.map(([id, name]) => `{${id},${luaStr(name)}}`).join(",")}},`);
    }
    out.push("}");
    out.push("-- [subtype] = { kind = \"overlord\" (lore) or \"champion\" (mightiest of its race), { npcID, name }, ... }");
    out.push("ns.SubtypeLeaders = {");
    for (const [subtype, o] of Object.entries(overlords).sort()) {
        out.push(`[${luaStr(subtype)}]={kind=${luaStr(o.kind)},${o.leaders.map(([id, name]) => `{${id},${luaStr(name)}}`).join(",")}},`);
    }
    out.push("}");
    out.push("-- [player race] = { { npcID, leader name } } (PvP tab)");
    out.push("ns.RaceLeaders = {");
    for (const [race, list] of Object.entries(raceLeaders).sort()) {
        out.push(`[${luaStr(race)}]={${list.map(([id, name]) => `{${id},${luaStr(name)}}`).join(",")}},`);
    }
    out.push("}");
    out.push("-- [model fileID] = subtypeID");
    out.push("ns.ModelSubtypes = {");
    for (const [fileID, id] of modelSubtypes) out.push(`[${fileID}]=${id},`);
    out.push("}");
    writeNameIndex(out, "Faction", factionIndex.finish());
    writeNameIndex(out, "Subtype", subtypeIndex.finish());
    fs.writeFileSync(OUT, out.join("\n") + "\n");

    const specific = rows.filter((n) => !n.isFallback).length;
    console.log(`Wrote ${rows.length} NPCs (${specific} with a specific subtype), ${usedFactions.size} factions ` +
        `(${placed} mobs placed in a tribe by their spawns, ${beastsGrouped} beasts grouped by kind), ` +
        `${subtypes.length} subtypes to ${OUT}`);
    const top = [...fallbacks].sort((a, b) => b[1] - a[1]).slice(0, 30);
    if (top.length) console.log("Model folders falling back to the type name: " + top.map(([f, n]) => `${f} ${n}`).join(", "));
}

main().catch((e) => { console.error(e); process.exit(1); });
