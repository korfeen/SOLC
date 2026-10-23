-- The practice bot (dev characters only, SOLC.IsDev): a pretend guildmate to duel when nobody's around. It speaks
-- the duel messages (Duel.lua's list at the top) from inside the addon: Duel.lua hands it what's sent to its name
-- (Send) and it answers through Duel.Deliver, a moment later, as if over the wire. It can be challenged from the
-- duel panel (it's first in the list of who's online) or challenge you (the dev menu: Bot.ChallengeMe). At the
-- table it puts up a picture nobody owns and gets ready; in the race it "solves" at its speed (SPEEDS: seconds a
-- piece) or, in a paint duel, scores something at the end. Nothing changes hands (Duel.lua: duel.bot): losing keeps
-- your picture, winning shows its picture as the prize without adding it.

local _, ns = ...

local Duel = ns.Duel
local Bot = { name = "Practice Ogre (bot)", speed = 2 }
Bot.SPEEDS = {
    { name = "Sleepy", perPiece = 6 },
    { name = "Normal", perPiece = 3 },
    { name = "Quick", perPiece = 1.6 },
    { name = "Unbeatable", perPiece = 0.5 },
}
local COUNTDOWN = 3  -- (Duel.lua's)
local LAG = 0.4      -- seconds before each answer, like a whisper's trip
local REACTIONS = { "deal", "nice", "lousy", "haha", "hmm", "zzz" }

local state  -- the duel as the bot sees it: { id, role, mode, size, seconds, offer, theirs, theirReady, ... }

function Bot.IsBot(name) return name == Bot.name and SOLC.IsDev() end

-- Says something to you after a moment (or after delay seconds), if it's still the same duel.
local function Say(delay, ...)
    local message, id = table.concat({ ... }, "|"), state and state.id
    C_Timer.After(delay or LAG, function()
        if state and state.id == id then Duel.Deliver(Bot.name, message) end
    end)
end

-- Its picture on the table, then Ready.
local function SitDown()
    state.offer = state.offer or { number = 1, traits = SOLC.RandomPicture() }
    Say(LAG + 0.6, "O", state.id, state.offer.number, 0, SOLC.TraitsToText(state.offer.traits))
    Say(LAG + 1.4, "R", state.id, 1)
end

-- The challenger starts once both are ready with offers (Duel.lua's MaybeStart, for the bot).
local function MaybeStart()
    if state.role ~= "challenger" or not state.theirReady or not state.theirs or state.started then return end
    state.started = true
    state.seed = math.random(1, 2 ^ 30)
    Say(LAG, "S", state.id, state.seed, state.offer.number, state.theirs)
end

-- After the countdown: it races. Puzzles: done after its time (pieces x its speed, give or take 25%), unless you
-- were faster - then, once its clock passes yours, it gives up and hands its picture over. Paint: a score at the end.
local function Race()
    local id = state.id
    state.raceStart = GetTime() + COUNTDOWN
    if state.mode == "paint" then
        Say(COUNTDOWN + (state.seconds or ns.DEFAULT_PAINT_TIME), "P", id, ("%.2f"):format(35 + math.random() * 50))
        return
    end
    local pieces = state.size * state.size
    state.time = pieces * Bot.SPEEDS[Bot.speed].perPiece * (0.75 + math.random() * 0.5)
    state.moves = math.floor(pieces * (1.5 + math.random() * 1.5))
    C_Timer.After(COUNTDOWN + state.time, function()
        if not state or state.id ~= id or state.lost then return end
        state.done = true
        Duel.Deliver(Bot.name, ("F|%s|%.2f|%d"):format(id, state.time, state.moves))
    end)
end

-- You solved it (in your time): if that beats the bot, it loses when its own clock passes yours.
local function YouSolved(seconds)
    if state.done or state.mode == "paint" then return end
    seconds = tonumber(seconds) or 0
    if seconds >= state.time then return end
    state.lost = true
    local wait = math.max(0, state.raceStart + seconds - GetTime()) + 0.2
    Say(wait, "L", state.id)
    Say(wait + 0.3, "G", state.id, 0, SOLC.TraitsToText(state.offer.traits))
end

-- What you sent the bot.
function Bot.Receive(message)
    local fields = { strsplit("|", message) }
    local kind, id = fields[1], fields[2]
    if kind == "C" then  -- you challenged it: it always accepts
        state = { id = id, role = "opponent", mode = fields[3], size = tonumber(fields[4]), seconds = tonumber(fields[5]) }
        if state.seconds == 0 then state.seconds = nil end
        Say(LAG, "A", id)
        SitDown()
        return
    end
    if not state or state.id ~= id then return end
    if kind == "A" then
        SitDown()
    elseif kind == "O" then  -- your offer changed: both Ready marks are off; it gets ready again
        state.theirs, state.theirReady = fields[3] ~= "-" and tonumber(fields[3]) or nil, false
        if state.theirs then Say(LAG + 0.5, "R", id, 1) end
    elseif kind == "R" then
        state.theirReady = fields[3] == "1"
        if not state.theirReady then state.started = nil end  -- (you weren't ready for its start: it can start again)
        MaybeStart()
    elseif kind == "S" then  -- you start (you challenged it): it agrees
        Say(LAG, "GO", id)
        Race()
    elseif kind == "GO" then
        Race()
    elseif kind == "F" then
        YouSolved(fields[3])
    elseif kind == "E" and math.random() < 0.6 then
        Say(LAG + 0.5, "E", id, REACTIONS[math.random(#REACTIONS)])
    elseif kind == "D" or kind == "L" or kind == "G" then
        state = nil  -- (you left, lost or paid up: the duel's over for it)
    end
end

-- The bot challenges you (the dev menu): mode "swap", "sliding" or "paint"; size 3-5, or 16/24 for paint.
function Bot.ChallengeMe(mode, size, seconds)
    if not SOLC.IsDev() then return end
    local current = Duel.Get()
    if current and current.phase ~= "done" then return SOLC.Print("You're already in a duel.") end
    if current then Duel.Clear() end
    state = { id = tostring(math.random(100000, 999999)), role = "challenger", mode = mode, size = size, seconds = seconds }
    Say(0.2, "C", state.id, mode, size, seconds or 0)
end

Duel.bot = Bot
SOLC.PuzzleBot = Bot  -- (for the dev menu, Dev.lua)
