-- PlayerStats: PvP Killstreak system
local PS = PlayerStats

local streakCount = 0
local lastKillTime = 0

local STREAK_DATA = {
    [2]  = { text = "Double Kill",    color = {1, 1, 0.2},     size = 38 },
    [3]  = { text = "Triple Kill",    color = {1, 0.7, 0},     size = 40 },
    [4]  = { text = "Ultra Kill",     color = {1, 0.4, 0},     size = 42 },
    [5]  = { text = "Mega Kill",      color = {1, 0.2, 0},     size = 44 },
    [6]  = { text = "Monster Kill",   color = {1, 0, 0},       size = 46 },
    [7]  = { text = "Godlike",        color = {0.9, 0, 0.9},   size = 48 },
    [8]  = { text = "Wicked Sick",    color = {0.6, 0, 1},     size = 50 },
    [9]  = { text = "Unstoppable",    color = {0.8, 0, 0},     size = 52 },
    [10] = { text = "Rampage",        color = {1, 0.3, 0},     size = 52 },
    [11] = { text = "Dominating",     color = {0.7, 0, 0.7},   size = 54 },
    [12] = { text = "Legendary",      color = {1, 0.84, 0},    size = 54 },
    [13] = { text = "Ownage",         color = {1, 0, 0},       size = 56 },
}
local BEYOND = { text = "Beyond Godlike", color = {1, 0.84, 0}, size = 56 }

local function GetStreakData(count)
    return STREAK_DATA[count] or (count > 13 and BEYOND or nil)
end

-- ============ ANIMATED DISPLAY ============
local display = CreateFrame("Frame", "PlayerStatsKillstreak", UIParent)
display:SetSize(600, 100)
display:SetPoint("CENTER", 0, 150)
display:SetFrameStrata("HIGH")
display:Hide()

local streakText = display:CreateFontString(nil, "OVERLAY")
streakText:SetFont("Fonts\\FRIZQT__.TTF", 42, "THICKOUTLINE")
streakText:SetPoint("CENTER", 0, 10)
streakText:SetShadowOffset(2, -2)
streakText:SetShadowColor(0, 0, 0, 0.8)

local victimText = display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
victimText:SetPoint("CENTER", 0, -20)
victimText:SetTextColor(0.8, 0.8, 0.8)

local anim = { active = false, elapsed = 0 }
local FADE_IN = 0.15
local HOLD = 2.0
local FADE_OUT = 0.6
local TOTAL = FADE_IN + HOLD + FADE_OUT

display:SetScript("OnUpdate", function(self, dt)
    if not anim.active then return end
    anim.elapsed = anim.elapsed + dt
    local t = anim.elapsed

    if t < FADE_IN then
        local a = t / FADE_IN
        streakText:SetAlpha(a)
        victimText:SetAlpha(a * 0.8)
    elseif t < FADE_IN + HOLD then
        streakText:SetAlpha(1)
        victimText:SetAlpha(0.8)
    elseif t < TOTAL then
        local a = 1 - (t - FADE_IN - HOLD) / FADE_OUT
        streakText:SetAlpha(a)
        victimText:SetAlpha(a * 0.8)
    else
        anim.active = false
        self:Hide()
    end
end)

local function ShowStreakDisplay(data, victim, count)
    streakText:SetText(data.text)
    streakText:SetTextColor(data.color[1], data.color[2], data.color[3])
    streakText:SetFont("Fonts\\FRIZQT__.TTF", data.size, "THICKOUTLINE")

    if victim then
        if count > 3 then
            victimText:SetText(victim .. " (" .. count .. " streak)")
        else
            victimText:SetText(victim)
        end
        victimText:Show()
    else
        victimText:Hide()
    end

    streakText:SetAlpha(0)
    victimText:SetAlpha(0)
    anim.active = true
    anim.elapsed = 0
    display:Show()
end

-- ============ STREAK LOGIC ============
-- Streak only resets on death, never on a timer.
function PS:OnPvPKill(victimName)
    if not self.settings or not self.settings.killstreakEnabled then return end

    streakCount = streakCount + 1
    lastKillTime = GetTime()
    PS.currentStreak = streakCount

    if streakCount > self.db.stats.bestKillStreak then
        self.db.stats.bestKillStreak = streakCount
    end

    local data = GetStreakData(streakCount)
    if not data then return end

    -- Screen popup
    if self.settings.killstreakScreen then
        ShowStreakDisplay(data, victimName, streakCount)
    end

    -- Chat message (self)
    if self.settings.killstreakChat then
        local hex = string.format("|cff%02x%02x%02x",
            data.color[1] * 255, data.color[2] * 255, data.color[3] * 255)
        local msg = hex .. data.text .. "|r"
        if victimName then msg = msg .. " " .. victimName end
        self:Print(msg)
    end

    -- Announce to chat channels
    local announce = self.settings.killstreakAnnounce
    if announce and announce ~= "none" then
        local announceMsg = data.text
        if streakCount > 3 then
            announceMsg = announceMsg .. " " .. "<" .. streakCount .. ">"
        end
        if announce == "say" or announce == "all" then
            SendChatMessage(announceMsg, "SAY")
        end
        if announce == "emote" or announce == "all" then
            SendChatMessage("scores a " .. announceMsg .. "!", "EMOTE")
        end
        if announce == "group" or announce == "all" then
            local _, instanceType = IsInInstance()
            if instanceType == "pvp" or instanceType == "arena" then
                SendChatMessage(announceMsg, "INSTANCE_CHAT")
            elseif IsInRaid() then
                SendChatMessage(announceMsg, "RAID")
            elseif IsInGroup() then
                SendChatMessage(announceMsg, "PARTY")
            end
        end
    end
end

function PS:OnPlayerDeath()
    if streakCount >= 2 then
        self:Print("Kill streak ended at " .. streakCount .. " kills.")
    end
    streakCount = 0
    lastKillTime = 0
    PS.currentStreak = 0
end
