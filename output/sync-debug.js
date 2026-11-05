// One-off (2026-11-06): /solc sync <first name> finds the guildmate's full name in the guild roster (on Forever a
// whisper needs "First Last"; "First" gets "No player named ..."), and /solc syncdebug prints the sync messages sent
// (with WoW's answer) and received - Inga Bekymmer couldn't get Bonnie's data and nothing said why.
const fs = require("fs");
const path = require("path");
process.chdir(path.join(__dirname, ".."));
function edit(f, pairs) {
  let s = fs.readFileSync(f, "utf8");
  const nl = s.includes("\r\n") ? "\r\n" : "\n";
  for (let [a, b] of pairs) {
    a = a.split("\n").join(nl); b = b.split("\n").join(nl);
    if (s.split(a).length !== 2) throw Error(f + ": " + a.slice(0, 60));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(f, s);
}
edit("Config.lua", [[
`-- True if sender ("Name" or "Name-Realm") is a guild master or officer, by your own guild roster.`,
`-- A guildmate's full name ("Inga Bekymmer", "Name-Realm") from your guild roster, for a name typed short ("inga": the
-- first name, if only one member has it) or whole, any capitals; nil if no one (or more than one) fits.
function ns.GuildFullName(name)
    name = (name or ""):lower()
    if name == "" then return end
    local found, foundPlain
    for fullName in pairs(Ranks()) do  -- (each member is in it twice: "Name-Realm" and "Name")
        local plain = fullName:match("^[^-]+")
        if fullName:lower() == name or plain:lower() == name then return plain end
        if plain:match("^%S+"):lower() == name then
            if foundPlain and foundPlain ~= plain then return end  -- (two members with that first name: say which)
            found, foundPlain = plain, plain
        end
    end
    return found
end

-- True if sender ("Name" or "Name-Realm") is a guild master or officer, by your own guild roster.`]]);
edit("Sync.lua", [
[`    local result = SendResult(item)
    if result == "throttled" then return end`,
`    local result = SendResult(item)
    if ns.syncDebug then  -- (/solc syncdebug: what went out, and WoW's answer)
        ns.Print(("|cff88ccffsync out|r %s %s %s: %s"):format(item.channel, item.target or "", item.message:sub(1, 1), result))
    end
    if result == "throttled" then return end`],
[`    if prefix ~= PREFIX or issecret(message) or issecret(sender) or IsMe(sender) then return end
    local fields = Split(message, "|")`,
`    if prefix ~= PREFIX or issecret(message) or issecret(sender) or IsMe(sender) then return end
    if ns.syncDebug then  -- (/solc syncdebug: what came in; a big update's chunks only their first and last)
        local part, parts = message:match("^%a|%d+|(%d+)|(%d+)|")
        if not part or part == "1" or part == parts then
            ns.Print(("|cff88ff88sync in|r %s from %s%s"):format(message:sub(1, 1), sender, part and (" (%s/%s)"):format(part, parts) or ""))
        end
    end
    local fields = Split(message, "|")`],
[`    target = FindFriend(target) or target`,
`    target = FindFriend(target) or (ns.GuildFullName and ns.GuildFullName(target)) or target  -- (a whisper needs "First Last")`],
]);
edit("Core.lua", [[
`    elseif msg == "sync" and arg ~= "" then
        ns.SyncWith(arg)`,
`    elseif msg == "sync" and arg ~= "" then
        ns.SyncWith(arg)
    elseif msg == "syncdebug" then  -- (the sync messages in chat, sent and received: Sync.lua)
        ns.syncDebug = not ns.syncDebug or nil
        Print("Sync debugging " .. (ns.syncDebug and "on: sync messages show in chat." or "off."))`]]);
console.log("done");
