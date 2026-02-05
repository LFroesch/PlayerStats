-- PlayerStats: Comprehensive statistics tracking for TBC Classic
local addonName = "PlayerStats"
local PS = {}
_G.PlayerStats = PS

-- Per-character data defaults
local charDefaults = {
    stats = {
        totalKills = 0, pvpKills = 0, deaths = 0, pvpDeaths = 0,
        totalDamage = 0, totalHealing = 0, totalDamageTaken = 0,
        highestHit = 0, highestHitSpell = "", highestHitTarget = "",
        highestHeal = 0, highestHealSpell = "",
        critCount = 0,
        honorableKills = 0, honorEarned = 0,
        duelsWon = 0, duelsLost = 0, bestKillStreak = 0,
        questsCompleted = 0, goldLooted = 0, goldFromQuests = 0, goldFromVendors = 0,
        fishCaught = 0, foodEaten = 0, drinksConsumed = 0,
        hearthstoneUses = 0, jumps = 0,
        critterKills = 0, dispels = 0,
        bgWins = 0, bgLosses = 0,
        arenaWins = 0, arenaLosses = 0,
        instancesEntered = 0,
        itemsCrafted = 0, nodesGathered = 0,
        bandagesUsed = 0, dailiesCompleted = 0,
        -- PvP
        pvpTrinketUses = 0,
        -- PvE
        bossKills = 0, dungeonsCompleted = 0, raidBossKills = 0,
        dungeonBossKills = 0, raidsCompleted = 0,
    },
    spells = {},
    bgStats = {},
    arenaStats = {},
    pveStats = {},
    gatheringStats = {},
    emoteStats = {},
    session = {},
}

-- Global (account-wide) defaults
local globalDefaults = {
    characters = {},
    settings = {
        killstreakEnabled = true,
        killstreakChat = true,
        killstreakScreen = true,
        killstreakAnnounce = "none",
        showMini = true,
        miniBarSize = "medium",
        chatFrame = 1,
        pvpKillSound = true,
    },
    miniPos = {},
    version = 3,
}

local function DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then copy[k] = DeepCopy(v) else copy[k] = v end
    end
    return copy
end

local function EnsureDefaults(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then
            if type(v) == "table" then db[k] = DeepCopy(v) else db[k] = v end
        elseif type(v) == "table" and type(db[k]) == "table"
               and k ~= "spells" and k ~= "bgStats" and k ~= "arenaStats" and k ~= "characters"
               and k ~= "session" and k ~= "pveStats" and k ~= "gatheringStats" and k ~= "emoteStats" then
            EnsureDefaults(db[k], v)
        end
    end
end

-- Utilities
function PS:FormatNumber(n)
    if n >= 1000000000 then return string.format("%.1fB", n / 1000000000)
    elseif n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fK", n / 1000)
    end
    return tostring(math.floor(n))
end

function PS:FormatGold(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c)
    elseif s > 0 then return string.format("%ds %dc", s, c)
    end
    return string.format("%dc", c)
end

function PS:Print(msg)
    local frame = _G["ChatFrame" .. (self.settings and self.settings.chatFrame or 1)]
    if not frame then frame = DEFAULT_CHAT_FRAME end
    frame:AddMessage("|cff00ccffPlayerStats:|r " .. msg)
end

-- Player info
PS.playerGUID = nil
PS.playerName = nil
PS.charKey = nil
PS.sessionStart = 0
PS.sessionKills = 0
PS.sessionDeaths = 0
PS.sessionDamage = 0
PS.sessionHealing = 0
PS.sessionGathering = 0
PS.sessionPvPKills = 0
PS.sessionPvPDeaths = 0
PS.viewMode = "character" -- "character", "total", or a specific charKey
PS.viewCharKey = nil

-- Summation keys for GetTotalStats
local SUM_KEYS = {
    "totalKills", "pvpKills", "deaths", "pvpDeaths",
    "totalDamage", "totalHealing", "totalDamageTaken", "critCount",
    "honorableKills", "honorEarned", "duelsWon", "duelsLost",
    "questsCompleted", "goldLooted", "goldFromQuests", "goldFromVendors", "fishCaught", "foodEaten",
    "drinksConsumed", "hearthstoneUses", "jumps", "critterKills",
    "dispels", "bgWins", "bgLosses", "arenaWins", "arenaLosses", "instancesEntered",
    "itemsCrafted", "nodesGathered", "bandagesUsed", "dailiesCompleted",
    "pvpTrinketUses",
    "bossKills", "dungeonsCompleted", "raidBossKills",
    "dungeonBossKills", "raidsCompleted",
}

-- Compute total stats across all characters
function PS:GetTotalStats()
    local total = DeepCopy(charDefaults.stats)
    for _, charData in pairs(PlayerStatsDB.characters) do
        local s = charData.stats
        if s then
            for _, key in ipairs(SUM_KEYS) do
                total[key] = total[key] + (s[key] or 0)
            end
            if (s.highestHit or 0) > total.highestHit then
                total.highestHit = s.highestHit
                total.highestHitSpell = s.highestHitSpell or ""
                total.highestHitTarget = s.highestHitTarget or ""
            end
            if (s.highestHeal or 0) > total.highestHeal then
                total.highestHeal = s.highestHeal
                total.highestHealSpell = s.highestHealSpell or ""
            end
            if (s.bestKillStreak or 0) > total.bestKillStreak then
                total.bestKillStreak = s.bestKillStreak
            end
        end
    end
    return total
end

function PS:GetTotalBGStats()
    local total = {}
    for _, charData in pairs(PlayerStatsDB.characters) do
        for name, data in pairs(charData.bgStats or {}) do
            if not total[name] then total[name] = { wins = 0, losses = 0 } end
            total[name].wins = total[name].wins + data.wins
            total[name].losses = total[name].losses + data.losses
            total[name].kills = (total[name].kills or 0) + (data.kills or 0)
            total[name].deaths = (total[name].deaths or 0) + (data.deaths or 0)
            total[name].flagsCaptured = (total[name].flagsCaptured or 0) + (data.flagsCaptured or 0)
            total[name].flagsReturned = (total[name].flagsReturned or 0) + (data.flagsReturned or 0)
            total[name].basesAssaulted = (total[name].basesAssaulted or 0) + (data.basesAssaulted or 0)
            total[name].basesDefended = (total[name].basesDefended or 0) + (data.basesDefended or 0)
        end
    end
    return total
end

function PS:GetTotalArenaStats()
    local total = {}
    for _, charData in pairs(PlayerStatsDB.characters) do
        for bracket, data in pairs(charData.arenaStats or {}) do
            if not total[bracket] then total[bracket] = { wins = 0, losses = 0, maps = {} } end
            total[bracket].wins = total[bracket].wins + data.wins
            total[bracket].losses = total[bracket].losses + data.losses
            for mapName, mapData in pairs(data.maps or {}) do
                if not total[bracket].maps[mapName] then total[bracket].maps[mapName] = { wins = 0, losses = 0 } end
                total[bracket].maps[mapName].wins = total[bracket].maps[mapName].wins + mapData.wins
                total[bracket].maps[mapName].losses = total[bracket].maps[mapName].losses + mapData.losses
            end
        end
    end
    return total
end

function PS:GetTotalPvEStats()
    local total = {}
    for _, charData in pairs(PlayerStatsDB.characters) do
        for instance, idata in pairs(charData.pveStats or {}) do
            if not total[instance] then
                total[instance] = { bosses = {}, completed = 0 }
            end
            total[instance].completed = total[instance].completed + (idata.completed or 0)
            for boss, count in pairs(idata.bosses or {}) do
                total[instance].bosses[boss] = (total[instance].bosses[boss] or 0) + count
            end
        end
    end
    return total
end

function PS:GetTotalGatheringStats()
    local total = {}
    for _, charData in pairs(PlayerStatsDB.characters) do
        for gatherType, nodes in pairs(charData.gatheringStats or {}) do
            if not total[gatherType] then total[gatherType] = {} end
            for node, data in pairs(nodes) do
                if not total[gatherType][node] then
                    total[gatherType][node] = { count = 0, items = {} }
                end
                -- Handle both old format (number) and new format (table)
                if type(data) == "number" then
                    total[gatherType][node].count = total[gatherType][node].count + data
                else
                    total[gatherType][node].count = total[gatherType][node].count + (data.count or 0)
                    for item, qty in pairs(data.items or {}) do
                        total[gatherType][node].items[item] = (total[gatherType][node].items[item] or 0) + qty
                    end
                end
            end
        end
    end
    return total
end

function PS:GetTotalEmoteStats()
    local total = {}
    for _, charData in pairs(PlayerStatsDB.characters) do
        for emote, count in pairs(charData.emoteStats or {}) do
            total[emote] = (total[emote] or 0) + count
        end
    end
    return total
end

-- Returns the stats/bgStats/pveStats/gatheringStats to display based on current view mode
function PS:GetViewCharData()
    if self.viewMode == "total" then return nil end
    if self.viewCharKey then
        local data = PlayerStatsDB.characters[self.viewCharKey]
        if data then return data end
    end
    return self.db
end

function PS:GetViewStats()
    if self.viewMode == "total" then
        return self:GetTotalStats()
    end
    local data = self:GetViewCharData()
    return data and data.stats or charDefaults.stats
end

function PS:GetViewBGStats()
    if self.viewMode == "total" then
        return self:GetTotalBGStats()
    end
    local data = self:GetViewCharData()
    return data and data.bgStats or {}
end

function PS:GetViewArenaStats()
    if self.viewMode == "total" then
        return self:GetTotalArenaStats()
    end
    local data = self:GetViewCharData()
    return data and data.arenaStats or {}
end

function PS:GetViewPvEStats()
    if self.viewMode == "total" then
        return self:GetTotalPvEStats()
    end
    local data = self:GetViewCharData()
    return data and data.pveStats or {}
end

function PS:GetViewGatheringStats()
    if self.viewMode == "total" then
        return self:GetTotalGatheringStats()
    end
    local data = self:GetViewCharData()
    return data and data.gatheringStats or {}
end

function PS:GetViewEmoteStats()
    if self.viewMode == "total" then
        return self:GetTotalEmoteStats()
    end
    local data = self:GetViewCharData()
    return data and data.emoteStats or {}
end

-- Session reset
function PS:ResetSession()
    self.sessionStart = time()
    self.sessionKills = 0
    self.sessionDeaths = 0
    self.sessionDamage = 0
    self.sessionHealing = 0
    self.sessionGathering = 0
    self.sessionPvPKills = 0
    self.sessionPvPDeaths = 0
    if self.db then self.db.session = {} end
    self:Print("Session reset.")
    if self.RefreshMini then self:RefreshMini() end
end

-- Init
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Just ensure the global variable exists; full init happens at PLAYER_LOGIN
        if not PlayerStatsDB then
            PlayerStatsDB = DeepCopy(globalDefaults)
        end
    elseif event == "PLAYER_LOGIN" then
        PS.playerGUID = UnitGUID("player")
        PS.playerName = UnitName("player")
        local charKey = PS.playerName .. "-" .. GetRealmName()
        PS.charKey = charKey

        -- Migration from v1 (flat structure, no characters table)
        if not PlayerStatsDB.characters then
            local old = PlayerStatsDB
            PlayerStatsDB = DeepCopy(globalDefaults)
            if old.settings then
                for k, v in pairs(old.settings) do
                    PlayerStatsDB.settings[k] = v
                end
            end
            PlayerStatsDB.miniPos = old.miniPos or {}
            if old.stats then
                PlayerStatsDB.characters[charKey] = {
                    stats = old.stats,
                    spells = old.spells or {},
                    bgStats = old.bgStats or {},
                    arenaStats = old.arenaStats or {},
                }
            end
        end

        -- Migration from v2: remove killstreakSound, add new settings
        if PlayerStatsDB.settings then
            PlayerStatsDB.settings.killstreakSound = nil
        end

        -- Ensure global defaults
        EnsureDefaults(PlayerStatsDB, globalDefaults)

        -- Ensure character entry
        if not PlayerStatsDB.characters[charKey] then
            PlayerStatsDB.characters[charKey] = DeepCopy(charDefaults)
        end
        EnsureDefaults(PlayerStatsDB.characters[charKey], charDefaults)

        -- Set references: PS.db = character data, PS.settings = shared settings
        PS.db = PlayerStatsDB.characters[charKey]
        PS.settings = PlayerStatsDB.settings

        -- Restore session if last seen < 15 min ago, otherwise start fresh
        local sess = PS.db.session
        if sess and sess.lastSeen and (time() - sess.lastSeen) < 900 then
            PS.sessionStart = sess.start or time()
            PS.sessionKills = sess.kills or 0
            PS.sessionDeaths = sess.deaths or 0
            PS.sessionDamage = sess.damage or 0
            PS.sessionHealing = sess.healing or 0
            PS.sessionGathering = sess.gathering or 0
            PS.sessionPvPKills = sess.pvpKills or 0
            PS.sessionPvPDeaths = sess.pvpDeaths or 0
            PS:Print("Session restored (" .. charKey .. "). Type /ps for commands.")
        else
            PS.sessionStart = time()
            PS:Print("Loaded (" .. charKey .. "). Type /ps for commands.")
        end
    end
end)

-- Slash commands
SLASH_PLAYERSTATS1 = "/ps"
SLASH_PLAYERSTATS2 = "/playerstats"
SlashCmdList["PLAYERSTATS"] = function(msg)
    local cmd = msg:lower():trim()
    if cmd == "" or cmd == "show" then
        if PlayerStatsFrame then
            if PlayerStatsFrame:IsShown() then PlayerStatsFrame:Hide()
            else PlayerStatsFrame:Show() end
        end
    elseif cmd == "mini" then
        if PlayerStatsMini then
            PS.settings.showMini = not PS.settings.showMini
            if PS.settings.showMini then PlayerStatsMini:Show()
            else PlayerStatsMini:Hide() end
        end
    elseif cmd == "session reset" then
        PS:ResetSession()
    elseif cmd == "session" then
        local e = time() - PS.sessionStart
        PS:Print(string.format("Session: %dh %dm | K:%d D:%d | Dmg:%s Heal:%s",
            math.floor(e / 3600), math.floor((e % 3600) / 60),
            PS.sessionKills, PS.sessionDeaths,
            PS:FormatNumber(PS.sessionDamage), PS:FormatNumber(PS.sessionHealing)))
    elseif cmd == "streak" then
        PS:Print("Best kill streak: " .. (PS.db and PS.db.stats.bestKillStreak or 0))
    elseif cmd == "reset" then
        StaticPopup_Show("PLAYERSTATS_CONFIRM_RESET")
    elseif cmd:match("^announce") then
        local mode = cmd:match("announce%s+(%S+)")
        if mode and (mode == "none" or mode == "say" or mode == "emote" or mode == "group" or mode == "all") then
            PS.settings.killstreakAnnounce = mode
            PS:Print("Killstreak announce: " .. mode)
        else
            PS:Print("Usage: /ps announce <none | say | emote | group | all>")
        end
    else
        PS:Print("Commands:")
        print("  /ps - Toggle stats window")
        print("  /ps mini - Toggle mini bar")
        print("  /ps session - Show session stats")
        print("  /ps session reset - Reset current session")
        print("  /ps streak - Show best kill streak")
        print("  /ps reset - Reset current character stats")
        print("  /ps announce <none|say|emote|group|all> - Killstreak chat announce")
    end
end

StaticPopupDialogs["PLAYERSTATS_CONFIRM_RESET"] = {
    text = "Reset stats for this character? This cannot be undone.",
    button1 = "Reset", button2 = "Cancel",
    OnAccept = function()
        if PS.charKey then
            PlayerStatsDB.characters[PS.charKey] = DeepCopy(charDefaults)
            PS.db = PlayerStatsDB.characters[PS.charKey]
            PS:Print("Stats reset for " .. PS.charKey .. ".")
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["PLAYERSTATS_CONFIRM_RESET_ALL"] = {
    text = "Reset stats for ALL characters? This cannot be undone.",
    button1 = "Reset All", button2 = "Cancel",
    OnAccept = function()
        for key in pairs(PlayerStatsDB.characters) do
            PlayerStatsDB.characters[key] = DeepCopy(charDefaults)
        end
        PS.db = PlayerStatsDB.characters[PS.charKey]
        PS:Print("Stats reset for all characters.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
