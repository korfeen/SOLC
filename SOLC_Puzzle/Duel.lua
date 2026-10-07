-- Duels: two guildmates sit down at a duel table like a trade window, each puts up one of their pictures (and
-- can react to the other's offer), both press Ready, then they race on the same scramble of one of the two.
-- The winner takes the loser's picture. Messages are whispers on our own prefix:
--   C|id|mode|size|seconds                  challenge (seconds: the paint time, for paint duels)
--   A|id                                     accept: both go to the table
--   D|id|reason                              decline, or leave the table ("busy" if already in a duel)
--   O|id|number|minted|traits  or  O|id|-   my offer (or none); any change clears both Ready marks
--   R|id|1 or 0                              ready, or not
--   E|id|reaction                            a reaction to the other's offer (see ns.REACTIONS)
--   S|id|seed|challenger's number|opponent's number   start (challenger, once both are ready)
--   GO|id                                    the opponent agrees the offers match: both count down 3 seconds
--   F|id|seconds|moves                       solved in that time (each player's own clock, from their start)
--   P|id|score                               paint duels: my painting's score (0-100) when my time ran out
--   L|id                                     ran out of time, or gave up: lost
--   G|id|minted|traits                       the loser gave their picture away; the winner adds it
--   M|id|part|parts|chunk                    puzzle duels, after the race: my moves (ns.EncodeMoves), for replays
--   V|id|moves                               puzzle duels, during the race: my moves of the last second, so the
--                                            other side can watch my board live (one message a second at most)
-- Fair timing without synced clocks: each player is timed from the end of their own countdown. Whoever
-- solves faster wins (fewer moves, then the challenger, on a tie). After the other's time arrives you can
-- still win if you finish within it; once your clock passes it, you've lost.

local _, ns = ...

local PREFIX = "SOLCPZ"
local COUNTDOWN = 3        -- seconds
local INVITE_TIMEOUT = 90  -- seconds to answer a challenge
local START_TIMEOUT = 15   -- seconds for the opponent to confirm a start
local MAX_TIME = 600       -- a race ends after 10 minutes; anyone not done by then loses

ns.REACTIONS = {
    { key = "deal", text = "Deal!" },
    { key = "nice", text = "Nice card!" },
    { key = "lousy", text = "Lousy..." },
    { key = "haha", text = "Haha" },
    { key = "hmm", text = "Hmm..." },
    { key = "zzz", text = "Zzz" },
}
local REACTION_TEXT = {}
for _, r in ipairs(ns.REACTIONS) do REACTION_TEXT[r.key] = r.text end
ns.REACTION_TEXT = REACTION_TEXT

local issecret = issecretvalue or function() return false end
local function Short(name) return Ambiguate and Ambiguate(name, "short") or name end

local Duel = {}
ns.Duel = Duel
local duel  -- the current duel, or nil (see Duel.Get)

-- After you decline someone (or let their challenge run out), their next challenges are declined quietly for
-- a while; challenging them yourself lifts it.
local DECLINE_COOLDOWN = 60  -- seconds; for anyone more persistent, turn duels off
local declinedAt = {}  -- [name] = when we last declined them

-- Sending: queued, so a message the game throttles is retried instead of silently lost (a lost prize message
-- would leave the winner without the picture the loser already gave away). Throttled sends wait SEND_RETRY.
local SEND_RETRY = 0.5
local outbox, sending = {}, false
local function Pump()
    local item = outbox[1]
    if not item then
        sending = false
        return
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.message, "WHISPER", item.target)
    local results = Enum and Enum.SendAddonMessageResult
    if ok and results and result == results.AddonMessageThrottle then
        C_Timer.After(SEND_RETRY, Pump)  -- try the same message again
        return
    end
    table.remove(outbox, 1)
    if #outbox > 0 then C_Timer.After(0.1, Pump) else sending = false end
end

local function Send(target, ...)
    outbox[#outbox + 1] = { target = target, message = table.concat({ ... }, "|") }
    if not sending then
        sending = true
        Pump()
    end
end

-- Duel.Tick runs a few times a second while a race is on (racing or waiting for their result), whether or not
-- the window is open.
local ticker = CreateFrame("Frame")
ticker:Hide()
local sinceTick = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    if not duel or (duel.phase ~= "racing" and duel.phase ~= "waiting") then return self:Hide() end
    sinceTick = sinceTick + elapsed
    if sinceTick < 0.2 then return end
    sinceTick = 0
    Duel.Tick()
end)

-- Something about the duel changed: the page (Duel.OnChange) and any listeners (Duel.Listen) hear of it.
local listeners = {}
function Duel.Listen(callback) listeners[#listeners + 1] = callback end
local function Changed()
    if duel and (duel.phase == "racing" or duel.phase == "waiting") then ticker:Show() end
    if Duel.OnChange then Duel.OnChange(duel) end
    for _, callback in ipairs(listeners) do callback(duel) end
end

local function NewID() return tostring(math.random(100000, 999999)) end

-- The current duel: { id, role = "challenger" | "opponent", opponent, mode, size, phase, mine, theirs,
-- myReady, theirReady, reactions = { mine, theirs } }. mine/theirs = offers { number, minted, traits } or nil;
-- reactions = { key, at }. phase: "inviting" (we challenged), "invited" (we were challenged), "table",
-- "starting" (challenger sent the start), "countdown", "racing", "waiting" (we solved, their result pending),
-- "done". Done duels carry result = { won, reason, myTime, theirTime, prize } until Duel.Clear.
function Duel.Get() return duel end
function Duel.Clear()
    if duel and duel.phase ~= "done" then return end
    duel = nil
    Changed()
end

-- Seconds since this player's race started (nil before).
function Duel.Elapsed()
    return duel and duel.startedAt and GetTime() - duel.startedAt or nil
end

local function ChallengerOffer() return duel.role == "challenger" and duel.mine or duel.theirs end
local function OpponentOffer() return duel.role == "challenger" and duel.theirs or duel.mine end

-- Which picture the puzzle is made of: one of the two offers, picked by the seed so both sides agree.
local function PuzzleTraits()
    return (duel.seed % 2 == 0 and ChallengerOffer() or OpponentOffer()).traits
end

local function Finish(won, reason)
    if duel.phase == "done" then return end
    duel.phase = "done"
    duel.result = { won = won, reason = reason, myTime = duel.myTime, theirTime = duel.theirTime,
        myScore = duel.myScore, theirScore = duel.theirScore }
    if not won then
        -- Hand our picture over: give it away first, then tell the winner, so it can't end up with both.
        local traits = SOLC.GivePicture(duel.mine.number)
        if traits then
            Send(duel.opponent, "G", duel.id, duel.mine.minted or 0, SOLC.TraitsToText(traits))
            duel.result.prize = duel.mine
        end
    end
    Changed()
end

-- Both results known: decide. Paint duels: the higher score; puzzles: the faster time, then fewer moves.
local function Decide()
    if duel.mode == "paint" then
        local mine, theirs = duel.myScore, duel.theirScore
        if mine and theirs then
            if math.abs(mine - theirs) >= 0.05 then return Finish(mine > theirs, "score") end
            return Finish(duel.role == "challenger", "tie")
        end
        return
    end
    local mine, theirs = duel.myTime, duel.theirTime
    if mine and theirs then
        if mine ~= theirs then return Finish(mine < theirs, "time") end
        if duel.myMoves ~= duel.theirMoves then return Finish(duel.myMoves < duel.theirMoves, "moves") end
        return Finish(duel.role == "challenger", "tie")
    end
end

-- The countdown and then the race (each side when it knows the start is agreed).
local function Begin(seed)
    duel.seed, duel.phase = seed, "countdown"
    duel.countdownEnds = GetTime() + COUNTDOWN
    duel.puzzle = PuzzleTraits()
    Changed()
    local id = duel.id
    C_Timer.After(COUNTDOWN, function()
        if not duel or duel.id ~= id or duel.phase ~= "countdown" then return end
        duel.phase, duel.startedAt = "racing", GetTime()
        if Duel.OnRaceStart then Duel.OnRaceStart(duel) end
        Changed()
    end)
end

local function OfferFields(offer)
    if not offer then return "-" end
    return table.concat({ offer.number, offer.minted or 0, SOLC.TraitsToText(offer.traits) }, "|")
end

-- The challenger starts once both are ready with an offer on the table.
local function MaybeStart()
    if duel.role ~= "challenger" or duel.phase ~= "table" then return end
    if not (duel.myReady and duel.theirReady and duel.mine and duel.theirs) then return end
    duel.phase, duel.seed = "starting", math.random(1, 2 ^ 30)
    Send(duel.opponent, "S", duel.id, duel.seed, duel.mine.number, duel.theirs.number)
    Changed()
    local id = duel.id
    C_Timer.After(START_TIMEOUT, function()
        if duel and duel.id == id and duel.phase == "starting" then
            duel.phase, duel.myReady, duel.theirReady = "table", false, false
            SOLC.Print(("%s didn't confirm the start; press Ready again."):format(duel.opponent))
            Changed()
        end
    end)
end

-- Your actions ----------------------------------------------------------------------------------------------

-- Challenges a player to a duel with these settings. Returns false and why if not.
function Duel.Challenge(target, mode, size, seconds)
    if duel and duel.phase ~= "done" then return false, "You're already in a duel." end
    declinedAt[target] = nil  -- challenging them yourself lifts the cooldown from declining them
    duel = { id = NewID(), role = "challenger", opponent = target, mode = mode, size = size, seconds = seconds, phase = "inviting",
        invitedAt = GetTime(), reactions = {} }
    Send(target, "C", duel.id, mode, size, seconds or 0)
    Changed()
    local id = duel.id
    C_Timer.After(INVITE_TIMEOUT, function()
        if duel and duel.id == id and duel.phase == "inviting" then
            duel = nil
            SOLC.Print(("%s didn't answer the challenge (or doesn't have SOLC Puzzle)."):format(target))
            Changed()
        end
    end)
    return true
end

-- Accepts the challenge you received: both go to the duel table.
function Duel.Accept()
    if not duel or duel.phase ~= "invited" then return end
    duel.phase = "table"
    Send(duel.opponent, "A", duel.id)
    Changed()
end

-- Declines a challenge, withdraws yours, or leaves the table (before the race).
function Duel.Cancel()
    if not duel then return end
    local p = duel.phase
    if p == "invited" or p == "inviting" or p == "table" or p == "starting" then
        if p == "invited" then declinedAt[duel.opponent] = GetTime() end
        Send(duel.opponent, "D", duel.id, p == "table" and "left" or "declined")
        duel = nil
        Changed()
    end
end

-- Puts one of your pictures (from SOLC.GetPictures) on the table, or nil to take it off. Clears both Ready marks.
-- Clicking through pictures sends only the last one: the offer goes out OFFER_DELAY after the last change
-- (or straight away when you press Ready, see FlushOffer).
local OFFER_DELAY = 0.4
local offerPending, offerChangedAt = false, 0

local function FlushOffer()
    if not offerPending or not duel then return end
    offerPending = false
    Send(duel.opponent, "O", duel.id, OfferFields(duel.mine))
end

function Duel.Offer(picture)
    if not duel or duel.phase ~= "table" then return end
    duel.mine = picture and { number = picture.number, minted = picture.time, traits = picture.traits } or nil
    duel.myReady, duel.theirReady = false, false
    offerChangedAt = GetTime()
    if not offerPending then
        offerPending = true
        local function Later()
            if not offerPending then return end
            local wait = offerChangedAt + OFFER_DELAY - GetTime()
            if wait > 0 then return C_Timer.After(wait, Later) end
            FlushOffer()
        end
        C_Timer.After(OFFER_DELAY, Later)
    end
    Changed()
end

-- Ready (or not) to race with the offers as they are.
function Duel.SetReady(ready)
    if not duel or duel.phase ~= "table" or (ready and not duel.mine) then return end
    FlushOffer()  -- the other side must have our current offer before our Ready
    duel.myReady = ready
    Send(duel.opponent, "R", duel.id, ready and 1 or 0)
    Changed()
    MaybeStart()
end

-- Reacts to the other's offer: shown above your card on their screen for a moment.
function Duel.React(key)
    if not duel or not REACTION_TEXT[key] or duel.phase == "done" then return end
    duel.reactions.mine = { key = key, at = GetTime() }
    Send(duel.opponent, "E", duel.id, key)
    Changed()
end

-- During a puzzle race: your latest moves (ns.EncodeMoves text) for the other's live view of your board. The
-- page calls this once a second with whatever is new, so it stays within the game's message budget.
function Duel.SendLive(text)
    if not duel or (duel.phase ~= "racing" and duel.phase ~= "waiting") or text == "" then return end
    Send(duel.opponent, "V", duel.id, text)
end

-- After a puzzle race: sends your moves (ns.EncodeMoves text) so both can watch the duel back side by side.
local MOVES_CHUNK = 200
function Duel.ShareMoves(text)
    if not duel or duel.myMoves then return end
    duel.myMoves = text
    local parts = math.max(1, math.ceil(#text / MOVES_CHUNK))
    for part = 1, parts do
        Send(duel.opponent, "M", duel.id, part, parts, text:sub((part - 1) * MOVES_CHUNK + 1, part * MOVES_CHUNK))
    end
end

-- Gives up during the countdown or race: counts as a loss.
function Duel.GiveUp()
    if not duel or (duel.phase ~= "countdown" and duel.phase ~= "racing") then return end
    Send(duel.opponent, "L", duel.id)
    Finish(false, "gave up")
end

-- Called by the board when you solve the puzzle.
function Duel.Solved(moves)
    if not duel or duel.phase ~= "racing" then return end
    duel.myTime, duel.myMoves = Duel.Elapsed(), moves
    duel.phase = "waiting"
    Send(duel.opponent, "F", duel.id, ("%.2f"):format(duel.myTime), moves)
    Changed()
    Decide()
end

-- Called by the paint tools when your time is up (or you press Done): your painting's score, 0-100.
function Duel.Painted(score)
    if not duel or duel.phase ~= "racing" then return end
    duel.myScore = score
    duel.phase = "waiting"
    Send(duel.opponent, "P", duel.id, ("%.2f"):format(score))
    Changed()
    Decide()
end

-- Checked by the ticker while racing: out of time, or past the opponent's finished time. (Paint duels end when
-- the paint time is up; the tools submit then.)
function Duel.Tick()
    if not duel then return end
    local elapsed = Duel.Elapsed()
    if duel.mode == "paint" then
        local limit = (duel.seconds or 90) + 30
        if duel.phase == "waiting" and elapsed and elapsed >= limit then Finish(true, "no answer") end
        return
    end
    if duel.phase == "racing" and elapsed then
        if elapsed >= MAX_TIME or (duel.theirTime and elapsed > duel.theirTime) then
            Send(duel.opponent, "L", duel.id)
            Finish(false, duel.theirTime and "slower" or "time limit")
        end
    elseif duel.phase == "waiting" and elapsed and elapsed >= MAX_TIME + 30 then
        Finish(true, "no answer")  -- they went quiet after we solved
    end
end

-- Messages --------------------------------------------------------------------------------------------------

local handlers = {}

local function Mine(sender, id)
    return duel and duel.id == id and sender == duel.opponent
end

-- Turning duels off (SOLCPuzzleDB.acceptDuels = false): challenges are declined without asking. And after you
-- decline someone (or let their challenge run out), their next challenges are declined quietly for a while.

function Duel.AcceptsDuels() return not SOLCPuzzleDB or SOLCPuzzleDB.acceptDuels ~= false end
function Duel.SetAcceptDuels(accept)
    SOLCPuzzleDB.acceptDuels = accept and true or false
    Changed()
end

function handlers.C(sender, id, mode, size, seconds)
    if not Duel.AcceptsDuels() then
        Send(sender, "D", id, "off")
        return
    end
    if declinedAt[sender] and GetTime() - declinedAt[sender] < DECLINE_COOLDOWN then
        Send(sender, "D", id, "declined")
        return
    end
    if duel and duel.phase ~= "done" then
        Send(sender, "D", id, "busy")
        return
    end
    size = tonumber(size)
    local valid = (mode == "swap" or mode == "sliding") and size and size >= 3 and size <= 5
        or mode == "paint" and (size == 16 or size == 24)
    if not valid then return end
    seconds = math.max(10, math.min(600, tonumber(seconds) or ns.DEFAULT_PAINT_TIME))
    duel = { id = id, role = "opponent", opponent = sender, mode = mode, size = size, seconds = seconds, phase = "invited",
        invitedAt = GetTime(), reactions = {} }
    if Duel.OnInvited then Duel.OnInvited(duel) end
    Changed()
    -- Unanswered: let it go (the challenger gives up after as long), so it doesn't block later challenges.
    C_Timer.After(INVITE_TIMEOUT, function()
        if duel and duel.id == id and duel.phase == "invited" then
            declinedAt[sender] = GetTime()
            duel = nil
            Changed()
        end
    end)
end

function handlers.A(sender, id)
    if not Mine(sender, id) or duel.phase ~= "inviting" then return end
    duel.phase = "table"
    Changed()
end

function handlers.D(sender, id, reason)
    if not Mine(sender, id) then return end
    local p = duel.phase
    if p ~= "inviting" and p ~= "invited" and p ~= "table" and p ~= "starting" then return end  -- not mid-race
    SOLC.Print(reason == "busy" and ("%s is already in a duel."):format(sender)
        or reason == "off" and ("%s isn't taking duels right now."):format(sender)
        or reason == "left" and ("%s left the duel table."):format(sender)
        or ("%s declined the duel."):format(sender))
    duel = nil
    Changed()
end

function handlers.O(sender, id, number, minted, traits)
    if not Mine(sender, id) or (duel.phase ~= "table" and duel.phase ~= "starting") then return end
    duel.theirs = number ~= "-" and { number = tonumber(number), minted = tonumber(minted),
        traits = SOLC.TextToTraits(traits or "") } or nil
    duel.myReady, duel.theirReady = false, false
    if duel.phase == "starting" then duel.phase = "table" end  -- the offer changed under the start
    Changed()
end

function handlers.R(sender, id, ready)
    if not Mine(sender, id) then return end
    if duel.phase == "starting" and ready ~= "1" then duel.phase = "table" end  -- they didn't agree the start
    if duel.phase ~= "table" then return end
    duel.theirReady = ready == "1"
    Changed()
    MaybeStart()
end

function handlers.E(sender, id, key)
    if not Mine(sender, id) or not REACTION_TEXT[key] then return end
    duel.reactions.theirs = { key = key, at = GetTime() }
    if Duel.OnReaction then Duel.OnReaction(duel, key) end
    Changed()
end

function handlers.S(sender, id, seed, challengerNumber, opponentNumber)
    if not Mine(sender, id) or duel.phase ~= "table" then return end
    -- Only if the offers are the ones we both see, and we're ready; otherwise we're not.
    local ok = duel.myReady and duel.mine and duel.theirs and tonumber(challengerNumber) == duel.theirs.number
        and tonumber(opponentNumber) == duel.mine.number
    if not ok then
        duel.myReady = false
        Send(sender, "R", id, 0)
        Changed()
        return
    end
    Send(sender, "GO", id)
    Begin(tonumber(seed) or 1)
end

handlers.GO = function(sender, id)
    if not Mine(sender, id) or duel.phase ~= "starting" then return end
    Begin(duel.seed)
end

function handlers.F(sender, id, seconds, moves)
    if not Mine(sender, id) or duel.phase == "done" then return end
    duel.theirTime, duel.theirMoves = tonumber(seconds), tonumber(moves) or 0
    Changed()
    Decide()
    Duel.Tick()  -- already past their time?
end

function handlers.P(sender, id, score)
    if not Mine(sender, id) or duel.phase == "done" or duel.mode ~= "paint" then return end
    duel.theirScore = tonumber(score) or 0
    Changed()
    Decide()
end

function handlers.L(sender, id)
    if not Mine(sender, id) or duel.phase == "done" then return end
    if duel.phase ~= "countdown" and duel.phase ~= "racing" and duel.phase ~= "waiting" then return end
    Finish(true, "they lost")
end

function handlers.V(sender, id, text)
    if not Mine(sender, id) or duel.mode == "paint" or not text then return end
    duel.theirLiveMoves = (duel.theirLiveMoves or 0) + math.floor(#text / 5)
    if Duel.OnLiveMoves then Duel.OnLiveMoves(duel, ns.DecodeMoves(text)) end
end

function handlers.M(sender, id, part, parts, chunk)
    part, parts = tonumber(part), tonumber(parts)
    if not Mine(sender, id) or not part or not parts or parts > 100 or duel.theirMoves then return end
    duel.movesIn = duel.movesIn or {}
    duel.movesIn[part] = chunk or ""
    for i = 1, parts do
        if not duel.movesIn[i] then return end
    end
    duel.theirMoves = table.concat(duel.movesIn, "", 1, parts)
    duel.movesIn = nil
    Changed()
end

function handlers.G(sender, id, minted, traits)
    -- The prize: only from the opponent of the duel we just won, once.
    if not Mine(sender, id) or not duel.result or not duel.result.won or duel.result.received then return end
    duel.result.received = true
    local mint = SOLC.ReceivePicture(SOLC.TextToTraits(traits or ""), sender, tonumber(minted))
    duel.result.prize = mint and { number = mint.number, traits = mint.traits }
    Changed()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
    if prefix ~= PREFIX or issecret(message) or issecret(sender) then return end
    sender = Short(sender)
    if sender == SOLC.MyName() then return end
    local fields = { strsplit("|", message) }
    local handler = handlers[fields[1]]
    if handler then handler(sender, select(2, unpack(fields))) end
end)
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Asks the server for a fresh guild roster (who's online); GUILD_ROSTER_UPDATE follows.
function Duel.RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
end

-- Online guildmates to challenge: { name }, sorted, without you.
function Duel.OnlineGuildmates()
    local list, me = {}, SOLC.MyName()
    for i = 1, GetNumGuildMembers and GetNumGuildMembers() or 0 do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online and not issecret(name) then
            local short = Short(name)
            if short ~= me then list[#list + 1] = short end
        end
    end
    table.sort(list)
    return list
end
