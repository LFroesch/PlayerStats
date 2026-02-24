-- PlayerStatistics: UI (mini bar + stats window)
local PS = PlayerStatistics

-- ============ MINI BAR ============
local MINI_SIZES = { small = { w = 220, h = 20, font = "GameFontNormalSmall" },
                     medium = { w = 280, h = 24, font = "GameFontNormalSmall" },
                     large = { w = 340, h = 28, font = "GameFontNormal" } }

local mini = CreateFrame("Frame", "PlayerStatisticsMini", UIParent, "BackdropTemplate")
mini:SetSize(280, 24)
mini:SetPoint("TOP", 0, -35)
mini:SetMovable(true)
mini:EnableMouse(true)
mini:RegisterForDrag("LeftButton")
mini:SetScript("OnDragStart", mini.StartMoving)
mini:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if PlayerStatsDB then PlayerStatsDB.miniPos = { point = p, relPoint = rp, x = x, y = y } end
end)
mini:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
mini:SetBackdropColor(0, 0, 0, 0.85)
mini:SetBackdropBorderColor(0, 0.5, 0.8, 0.8)

mini.text = mini:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mini.text:SetPoint("CENTER")

local function ApplyMiniSize()
    local sz = PS.settings and PS.settings.miniBarSize or "medium"
    local data = MINI_SIZES[sz] or MINI_SIZES.medium
    mini:SetSize(data.w, data.h)
    mini.text:SetFontObject(data.font)
end

function PS:RefreshMini()
    if not self.db then return end
    local pvpK = self.sessionPvPKills or 0
    local pvpD = self.sessionPvPDeaths or 0
    local kd = pvpD > 0 and string.format("%.1f", pvpK / pvpD) or "-"
    local cur = self.currentStreak or 0
    mini.text:SetText(string.format("|cff88ff88KB:%d|r  |cffff6666D:%d|r  |cffffffaaK/D:%s|r  |cffcc88ffCurr:%d|r  |cffcc88ffBest:%d|r",
        pvpK, pvpD, kd, cur, self.db.stats.bestKillStreak))
end

mini:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        if PlayerStatisticsFrame and PlayerStatisticsFrame:IsShown() then PlayerStatisticsFrame:Hide()
        else PlayerStatisticsFrame:Show() end
    end
end)

local miniTimer = 0
mini:SetScript("OnUpdate", function(self, dt)
    miniTimer = miniTimer + dt
    if miniTimer >= 5 then miniTimer = 0; PS:RefreshMini() end
end)

-- ============ MAIN FRAME ============
local f = CreateFrame("Frame", "PlayerStatisticsFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(460, 520)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

-- ESC to close
tinsert(UISpecialFrames, "PlayerStatisticsFrame")

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", 0, -5)
f.title:SetText("PlayerStatistics")

-- ============ CHARACTER DROPDOWN ============
local dropdown = CreateFrame("Frame", "PlayerStatisticsDropdown", f, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPRIGHT", -2, -1)
UIDropDownMenu_SetWidth(dropdown, 120)

local function DropdownInit(self, level)
    local info = UIDropDownMenu_CreateInfo()

    -- "All Characters" option
    info.text = "All Characters"
    info.value = "total"
    info.checked = (PS.viewMode == "total")
    info.func = function()
        PS.viewMode = "total"
        PS.viewCharKey = nil
        UIDropDownMenu_SetText(dropdown, "All Characters")
        if PS.RefreshUI then PS:RefreshUI() end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Current character
    if PS.charKey then
        info = UIDropDownMenu_CreateInfo()
        info.text = PS.charKey
        info.value = PS.charKey
        info.checked = (PS.viewMode == "character" and (PS.viewCharKey == nil or PS.viewCharKey == PS.charKey))
        info.func = function()
            PS.viewMode = "character"
            PS.viewCharKey = nil
            UIDropDownMenu_SetText(dropdown, PS.charKey)
            if PS.RefreshUI then PS:RefreshUI() end
        end
        UIDropDownMenu_AddButton(info, level)
    end

    -- Other characters
    if PlayerStatsDB and PlayerStatsDB.characters then
        local sorted = {}
        for key in pairs(PlayerStatsDB.characters) do
            if key ~= PS.charKey then table.insert(sorted, key) end
        end
        table.sort(sorted)
        for _, key in ipairs(sorted) do
            info = UIDropDownMenu_CreateInfo()
            info.text = key
            info.value = key
            info.checked = (PS.viewMode == "character" and PS.viewCharKey == key)
            info.func = function()
                PS.viewMode = "character"
                PS.viewCharKey = key
                UIDropDownMenu_SetText(dropdown, key)
                if PS.RefreshUI then PS:RefreshUI() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

UIDropDownMenu_Initialize(dropdown, DropdownInit)

-- ============ TAB SYSTEM ============
local currentTab = "combat"
local tabButtons = {}
local tabDefs = {
    { key = "combat",   label = "Combat" },
    { key = "pvp",      label = "PvP" },
    { key = "pve",      label = "PvE" },
    { key = "general",  label = "General" },
    { key = "spells",   label = "Spells" },
    { key = "settings", label = "Settings" },
}

local tabBar = CreateFrame("Frame", nil, f)
tabBar:SetPoint("TOPLEFT", 10, -28)
tabBar:SetSize(400, 24)

for i, td in ipairs(tabDefs) do
    local tab = CreateFrame("Button", nil, tabBar)
    tab:SetSize(60, 24)
    tab:SetPoint("LEFT", (i - 1) * 63, 0)
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER")
    tab.label:SetText(td.label)
    tab.key = td.key
    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetHeight(2)
    tab.underline:SetPoint("BOTTOMLEFT", 2, -1)
    tab.underline:SetPoint("BOTTOMRIGHT", -2, -1)
    tab.underline:SetColorTexture(0, 0.7, 1, 1)
    tab.underline:Hide()
    tab:SetScript("OnEnter", function(self)
        if currentTab ~= self.key then self.label:SetTextColor(1, 1, 1) end
    end)
    tab:SetScript("OnLeave", function(self)
        if currentTab ~= self.key then self.label:SetTextColor(0.6, 0.6, 0.6) end
    end)
    tabButtons[td.key] = tab
end

local tabSep = f:CreateTexture(nil, "ARTWORK")
tabSep:SetHeight(1)
tabSep:SetPoint("TOPLEFT", 10, -52)
tabSep:SetPoint("TOPRIGHT", -10, -52)
tabSep:SetColorTexture(0.3, 0.3, 0.35, 0.8)

-- ============ CONTENT AREA ============
local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 10, -56)
scroll:SetPoint("BOTTOMRIGHT", -28, 10)

local content = CreateFrame("Frame", nil, scroll)
content:SetWidth(scroll:GetWidth() or 360)
content:SetHeight(1)
scroll:SetScrollChild(content)
scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

-- Row pool
local rows = {}
local function GetRow(idx)
    if rows[idx] then return rows[idx] end
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetWidth(220)
    row.label:SetJustifyH("LEFT")
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("RIGHT", -8, 0)
    row.value:SetJustifyH("RIGHT")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.04)
    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetHeight(1)
    row.sep:SetPoint("TOPLEFT", 4, 0)
    row.sep:SetPoint("TOPRIGHT", -4, 0)
    row.sep:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    row.sep:Hide()
    rows[idx] = row
    return row
end

local function HideRows()
    for _, r in pairs(rows) do r:Hide() end
end

-- ============ SECTION HEADER HELPER ============
local function AddSectionHeader(idx, y, text)
    local row = GetRow(idx)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", 0, 0)
    row:SetHeight(16)
    row.label:SetText("|cffffd100" .. text .. "|r")
    row.label:SetTextColor(1, 1, 1)
    row.value:SetText("")
    row.bg:Hide()
    row.sep:Hide()
    row:EnableMouse(false)
    row:SetScript("OnMouseUp", nil)
    row:Show()
    return 16
end

-- ============ STAT DEFINITIONS ============
local COMBAT_STATS = {
    { header = "Damage & Kills" },
    { label = "Total Kills", key = "totalKills" },
    { label = "PvP Kills", key = "pvpKills" },
    { label = "Deaths", key = "deaths" },
    { label = "K/D Ratio", func = function(s)
        return s.deaths > 0 and string.format("%.2f", s.totalKills / s.deaths) or "-"
    end },
    "sep",
    { label = "Total Damage", key = "totalDamage", fmt = "number" },
    { label = "Total Healing", key = "totalHealing", fmt = "number" },
    { label = "Damage Taken", key = "totalDamageTaken", fmt = "number" },
    
    "sep",
    { header = "Records" },
    { label = "Highest Hit", resetKeys = {"highestHit", "highestHitSpell", "highestHitTarget"}, func = function(s)
        if s.highestHit > 0 then
            return PS:FormatNumber(s.highestHit) .. " (" .. s.highestHitSpell .. ")"
        end
        return "-"
    end },
    { label = "  on target", func = function(s)
        return s.highestHitTarget ~= "" and s.highestHitTarget or "-"
    end },
    { label = "Highest Heal", resetKeys = {"highestHeal", "highestHealSpell"}, func = function(s)
        if s.highestHeal > 0 then
            return PS:FormatNumber(s.highestHeal) .. " (" .. s.highestHealSpell .. ")"
        end
        return "-"
    end },
    { label = "Critical Hits", key = "critCount" },
    "sep",
    { header = "Misc" },
    { label = "Critter Kills", key = "critterKills" },
    { label = "Dispels", key = "dispels" }
}

local PVP_STATS = {
    { header = "Honor" },
    { label = "Honorable Kills", key = "honorableKills" },
    { label = "Honor Earned", key = "honorEarned" },
    "sep",
    { header = "Killing Blows" },
    { label = "PvP Killing Blows", key = "pvpKills" },
    { label = "PvP Deaths", key = "pvpDeaths" },
    { label = "PvP K/D", func = function(s)
        local d = (s.pvpDeaths or 0)
        return d > 0 and string.format("%.2f", s.pvpKills / d) or "-"
    end },
    { label = "PvP Trinket Uses", key = "pvpTrinketUses" },
    "sep",
    { header = "Killstreak" },
    { label = "Current Kill Streak", func = function(s) return tostring(PS.currentStreak or 0) end },
    { label = "Best Kill Streak", key = "bestKillStreak" },
    "sep",
    { header = "Arenas" },
    { label = "Arena Wins", key = "arenaWins" },
    { label = "Arena Losses", key = "arenaLosses" },
    { label = "Arena Win %", collapsibleKey = "arenas", func = function(s)
        local total = (s.arenaWins or 0) + (s.arenaLosses or 0)
        return total > 0 and string.format("%.0f%%", ((s.arenaWins or 0) / total) * 100) or "-"
    end },
    { generator = function()
        if not PS._expanded or not PS._expanded["arenas"] then return {} end
        local out = {}
        local arenaData = PS:GetViewArenaStats()
        local order = { ["2v2"] = 1, ["3v3"] = 2, ["5v5"] = 3 }
        local sorted = {}
        for bracket, data in pairs(arenaData) do
            table.insert(sorted, { bracket = bracket, data = data, sortKey = order[bracket] or 4 })
        end
        table.sort(sorted, function(a, b) return a.sortKey < b.sortKey end)
        for _, entry in ipairs(sorted) do
            local data = entry.data
            local total = data.wins + data.losses
            local pct = total > 0 and string.format(" (%.0f%%)", (data.wins / total) * 100) or ""
            table.insert(out, { label = "  " .. entry.bracket, value = data.wins .. "W / " .. data.losses .. "L" .. pct, arenaName = entry.bracket })
            -- Per-map breakdown under this bracket
            local maps = {}
            for mapName, mapData in pairs(data.maps or {}) do
                table.insert(maps, { name = mapName, data = mapData })
            end
            table.sort(maps, function(a, b) return a.name < b.name end)
            for _, m in ipairs(maps) do
                local mTotal = m.data.wins + m.data.losses
                local mPct = mTotal > 0 and string.format(" (%.0f%%)", (m.data.wins / mTotal) * 100) or ""
                table.insert(out, { label = "    " .. m.name, value = m.data.wins .. "W / " .. m.data.losses .. "L" .. mPct })
            end
        end
        return out
    end },
    "sep",
    { header = "Battlegrounds" },
    { label = "BG Wins", key = "bgWins" },
    { label = "BG Losses", key = "bgLosses" },
    { label = "BG Win %", collapsibleKey = "battlegrounds", func = function(s)
        local total = (s.bgWins or 0) + (s.bgLosses or 0)
        return total > 0 and string.format("%.0f%%", ((s.bgWins or 0) / total) * 100) or "-"
    end },
    { generator = function()
        if not PS._expanded or not PS._expanded["battlegrounds"] then return {} end
        local out = {}
        local bgData = PS:GetViewBGStats()
        local sorted = {}
        for name, data in pairs(bgData) do
            table.insert(sorted, { name = name, data = data })
        end
        table.sort(sorted, function(a, b) return a.name < b.name end)
        for _, bg in ipairs(sorted) do
            local data = bg.data
            local total = data.wins + data.losses
            local pct = total > 0 and string.format(" (%.0f%%)", (data.wins / total) * 100) or ""
            table.insert(out, { label = "  " .. bg.name, value = data.wins .. "W / " .. data.losses .. "L" .. pct, bgName = bg.name })
            local k, d = data.kills or 0, data.deaths or 0
            if k > 0 or d > 0 then
                table.insert(out, { label = "    Kills / Deaths", value = k .. " / " .. d })
            end
            local fc, fr = data.flagsCaptured or 0, data.flagsReturned or 0
            if fc > 0 or fr > 0 then
                table.insert(out, { label = "    Flags Cap / Ret", value = fc .. " / " .. fr })
            end
            local ba, bd = data.basesAssaulted or 0, data.basesDefended or 0
            if ba > 0 or bd > 0 then
                table.insert(out, { label = "    Bases Asl / Def", value = ba .. " / " .. bd })
            end
        end
        return out
    end },
    "sep",
    { header = "Duels" },
    { label = "Duels Won", key = "duelsWon" },
    { label = "Duels Lost", key = "duelsLost" },
    { label = "Duel Win %", func = function(s)
        local total = s.duelsWon + s.duelsLost
        return total > 0 and string.format("%.0f%%", (s.duelsWon / total) * 100) or "-"
    end },
    "sep",
    { header = "Session" },
    { label = "Session Time", func = function(s)
        local e = time() - PS.sessionStart
        return string.format("%dh %dm", math.floor(e / 3600), math.floor((e % 3600) / 60))
    end },
    { label = "Session Kills / Deaths", func = function(s)
        local kd = PS.sessionDeaths > 0 and string.format("%.1f", PS.sessionKills / PS.sessionDeaths) or "-"
        return PS.sessionKills .. " / " .. PS.sessionDeaths .. "  (K/D: " .. kd .. ")"
    end },
    { label = "Session Damage", func = function(s) return PS:FormatNumber(PS.sessionDamage) end },
    { label = "Session Healing", func = function(s) return PS:FormatNumber(PS.sessionHealing) end },
}

local GENERAL_STATS = {
    { header = "Quests & Gold" },
    { label = "Quests Completed", key = "questsCompleted" },
    { label = "Dailies Completed", key = "dailiesCompleted" },
    { label = "Gold Looted", key = "goldLooted", fmt = "gold" },
    { label = "Gold from Quests", key = "goldFromQuests", fmt = "gold" },
    { label = "Gold from Vendors", key = "goldFromVendors", fmt = "gold" },
    { label = "Total Gold Earned", func = function(s)
        return PS:FormatGold((s.goldLooted or 0) + (s.goldFromQuests or 0) + (s.goldFromVendors or 0))
    end },
    "sep",
    { header = "Food & Drink" },
    { label = "Food Eaten", key = "foodEaten" },
    { label = "Drinks Consumed", key = "drinksConsumed" },
    { label = "Bandages Used", key = "bandagesUsed" },
    "sep",
    { header = "Professions" },
    { label = "Fish Caught", key = "fishCaught" },
    { label = "Nodes Gathered", key = "nodesGathered", collapsibleKey = "gathering" },
    { generator = function()
        if not PS._expanded or not PS._expanded["gathering"] then return {} end
        local out = {}
        local gatherData = PS:GetViewGatheringStats()
        local sortedTypes = {}
        for gatherType in pairs(gatherData) do
            table.insert(sortedTypes, gatherType)
        end
        table.sort(sortedTypes)
        for _, gatherType in ipairs(sortedTypes) do
            local nodes = gatherData[gatherType]
            local total = 0
            for _, data in pairs(nodes) do
                if type(data) == "number" then
                    total = total + data
                else
                    total = total + (data.count or 0)
                end
            end
            table.insert(out, { label = "  " .. gatherType, value = tostring(total) })
            local sorted = {}
            for node, data in pairs(nodes) do
                local count = type(data) == "number" and data or (data.count or 0)
                local items = type(data) == "table" and data.items or {}
                table.insert(sorted, { name = node, count = count, items = items })
            end
            table.sort(sorted, function(a, b) return a.count > b.count end)
            for _, nodeData in ipairs(sorted) do
                table.insert(out, { label = "    " .. nodeData.name, value = tostring(nodeData.count) })
                local sortedItems = {}
                for item, qty in pairs(nodeData.items) do
                    table.insert(sortedItems, { name = item, qty = qty })
                end
                table.sort(sortedItems, function(a, b) return a.qty > b.qty end)
                for _, itemData in ipairs(sortedItems) do
                    table.insert(out, { label = "      " .. itemData.name, value = tostring(itemData.qty) })
                end
            end
        end
        return out
    end },
    "sep",
    { header = "Miscellaneous" },
    { label = "Hearthstone Uses", key = "hearthstoneUses" },
    { label = "Jumps", key = "jumps" },
    "sep",
    { header = "Emotes" },
    { label = "Total Emotes", collapsibleKey = "emotes", func = function(s)
        local total = 0
        for _, count in pairs(PS:GetViewEmoteStats()) do
            total = total + count
        end
        return tostring(total)
    end },
    { generator = function()
        if not PS._expanded or not PS._expanded["emotes"] then return {} end
        local out = {}
        local emoteData = PS:GetViewEmoteStats()
        local sorted = {}
        for emote, count in pairs(emoteData) do
            table.insert(sorted, { name = emote, count = count })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        for _, e in ipairs(sorted) do
            local displayName = e.name:sub(1,1):upper() .. e.name:sub(2)
            table.insert(out, { label = "    " .. displayName, value = tostring(e.count) })
        end
        return out
    end },
    "sep",
    { header = "Session" },
    { label = "Session Gathering", func = function(s) return tostring(PS.sessionGathering) end },
}

-- ============ INDIVIDUAL STAT RESET ============
local pendingReset = nil

local function ResetStatKeys(keys)
    if not PS.db or not PS.db.stats then return end
    for _, key in ipairs(keys) do
        local v = PS.db.stats[key]
        if type(v) == "string" then
            PS.db.stats[key] = ""
        else
            PS.db.stats[key] = 0
        end
    end
end

StaticPopupDialogs["PLAYERSTATISTICS_RESET_STAT"] = {
    text = "Reset \"%s\" for this character?",
    button1 = "Reset", button2 = "Cancel",
    OnAccept = function()
        if not pendingReset then return end
        if pendingReset.keys then
            ResetStatKeys(pendingReset.keys)
        elseif pendingReset.spellId then
            if PS.db and PS.db.spells then
                PS.db.spells[pendingReset.spellId] = nil
            end
        elseif pendingReset.arenaName then
            if PS.db and PS.db.arenaStats then
                PS.db.arenaStats[pendingReset.arenaName] = nil
            end
        elseif pendingReset.bgName then
            if PS.db and PS.db.bgStats then
                PS.db.bgStats[pendingReset.bgName] = nil
            end
        end
        pendingReset = nil
        if PS.RefreshUI then PS:RefreshUI() end
    end,
    OnCancel = function() pendingReset = nil end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- ============ RIGHT-CLICK CONTEXT MENU ============
local contextMenu = CreateFrame("Frame", "PlayerStatisticsContextMenu", UIParent, "UIDropDownMenuTemplate")

local function ShowStatContextMenu(label, value, resetInfo)
    local cleanLabel = label:gsub("^%s+", "")
    local reportMsg = "[PS] " .. cleanLabel .. ": " .. value
    local function InitMenu(self, level)
        -- Title (non-interactive)
        local title = UIDropDownMenu_CreateInfo()
        title.text = cleanLabel
        title.isTitle = true
        title.notCheckable = true
        UIDropDownMenu_AddButton(title, level)

        -- Report to Say
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Report to Say"
        info.notCheckable = true
        info.func = function() SendChatMessage(reportMsg, "SAY") end
        UIDropDownMenu_AddButton(info, level)

        -- Report to Party
        info = UIDropDownMenu_CreateInfo()
        info.text = "Report to Party"
        info.notCheckable = true
        info.func = function() SendChatMessage(reportMsg, "PARTY") end
        UIDropDownMenu_AddButton(info, level)

        -- Report to Raid
        info = UIDropDownMenu_CreateInfo()
        info.text = "Report to Raid"
        info.notCheckable = true
        info.func = function() SendChatMessage(reportMsg, "RAID") end
        UIDropDownMenu_AddButton(info, level)

        -- Report to Guild
        info = UIDropDownMenu_CreateInfo()
        info.text = "Report to Guild"
        info.notCheckable = true
        info.func = function() SendChatMessage(reportMsg, "GUILD") end
        UIDropDownMenu_AddButton(info, level)

        -- Separator before Reset
        if resetInfo then
            local sep = UIDropDownMenu_CreateInfo()
            sep.text = ""
            sep.isTitle = true
            sep.notCheckable = true
            UIDropDownMenu_AddButton(sep, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff4444Reset|r"
            info.notCheckable = true
            info.func = function()
                pendingReset = resetInfo
                StaticPopup_Show("PLAYERSTATISTICS_RESET_STAT", cleanLabel)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(contextMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, contextMenu, "cursor", 0, 0)
end

-- ============ RENDER STATS ============
PS._expanded = {} -- collapsible section state (default collapsed)

local function RenderStats(defs)
    HideRows()
    local s = PS:GetViewStats()
    local y = 0
    local idx = 0
    local visIdx = 0  -- for alternating backgrounds

    for _, def in ipairs(defs) do
        if def == "sep" then
            idx = idx + 1
            local row = GetRow(idx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            row:SetHeight(14)
            row.label:SetText("")
            row.value:SetText("")
            row.bg:Hide()
            row.sep:Show()
            row:EnableMouse(false)
            row:SetScript("OnMouseUp", nil)
            row:Show()
            y = y + 14
        elseif def.header then
            idx = idx + 1
            y = y + AddSectionHeader(idx, y, def.header)
        elseif def.generator then
            local genRows = def.generator()
            for _, gr in ipairs(genRows) do
                idx = idx + 1
                visIdx = visIdx + 1
                local row = GetRow(idx)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", 0, 0)
                row:SetHeight(22)
                row.sep:Hide()
                row.label:SetText(gr.label)
                row.label:SetTextColor(0.7, 0.7, 0.8)
                row.value:SetText(gr.value)
                if visIdx % 2 == 0 then row.bg:Show() else row.bg:Hide() end
                row:Show()

                row:EnableMouse(true)
                row:SetScript("OnMouseUp", function(self, button)
                    if button == "RightButton" then
                        local canReset = (gr.bgName or gr.arenaName) and PS.viewMode ~= "total" and not PS.viewCharKey
                        local resetInfo = nil
                        if canReset then
                            if gr.arenaName then resetInfo = { arenaName = gr.arenaName }
                            elseif gr.bgName then resetInfo = { bgName = gr.bgName } end
                        end
                        ShowStatContextMenu(gr.label, gr.value, resetInfo)
                    end
                end)

                y = y + 22
            end
        else
            idx = idx + 1
            visIdx = visIdx + 1
            local row = GetRow(idx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            row:SetHeight(22)
            row.sep:Hide()

            -- Collapsible indicator
            local labelText = def.label
            if def.collapsibleKey then
                local expanded = PS._expanded[def.collapsibleKey]
                labelText = (expanded and "- " or "+ ") .. def.label
            end
            row.label:SetText(labelText)
            row.label:SetTextColor(1, 0.82, 0)

            local val
            if def.func then
                val = def.func(s)
            elseif def.fmt == "number" then
                val = PS:FormatNumber(s[def.key] or 0)
            elseif def.fmt == "gold" then
                val = PS:FormatGold(s[def.key] or 0)
            else
                val = tostring(s[def.key] or 0)
            end
            row.value:SetText(val)

            if visIdx % 2 == 0 then row.bg:Show() else row.bg:Hide() end
            row:Show()

            -- Right-click context menu (report to chat + reset)
            local rk = def.resetKeys or (def.key and {def.key} or nil)
            row:EnableMouse(true)
            local cKey = def.collapsibleKey
            row:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" and cKey then
                    PS._expanded[cKey] = not PS._expanded[cKey]
                    if PS.RefreshUI then PS:RefreshUI() end
                elseif button == "RightButton" then
                    local canReset = rk and PS.viewMode ~= "total" and not PS.viewCharKey
                    local resetInfo = canReset and { keys = rk } or nil
                    ShowStatContextMenu(def.label, val, resetInfo)
                end
            end)

            y = y + 22
        end
    end
    content:SetHeight(math.max(1, y))
end

-- ============ PVE TAB ============
local pveExpanded = {} -- tracks which instances are expanded (default collapsed)

local function RenderPvE()
    HideRows()
    local s = PS:GetViewStats()
    local pveData = PS:GetViewPvEStats()
    local y = 0
    local idx = 0
    local visIdx = 0

    -- Overview header
    idx = idx + 1
    y = y + AddSectionHeader(idx, y, "Overview")

    local dBossN = s.dungeonBossKills or 0
    local dBossH = s.dungeonBossKillsHeroic or 0
    local dClearN = s.dungeonsCompleted or 0
    local dClearH = s.dungeonsCompletedHeroic or 0
    local overviewStats = {
        { label = "Raid Boss Kills", value = tostring(s.raidBossKills or 0) },
        { label = "Raids Cleared", value = tostring(s.raidsCompleted or 0) },
        { label = "Dungeon Boss Kills", value = "|cffbbbbbb" .. dBossN .. "N|r  |cffff9900" .. dBossH .. "H|r" },
        { label = "Dungeons Cleared", value = "|cffbbbbbb" .. dClearN .. "N|r  |cffff9900" .. dClearH .. "H|r" },
    }

    for _, stat in ipairs(overviewStats) do
        idx = idx + 1
        visIdx = visIdx + 1
        local row = GetRow(idx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", 0, 0)
        row:SetHeight(22)
        row.sep:Hide()
        row.label:SetText(stat.label)
        row.label:SetTextColor(1, 0.82, 0)
        row.value:SetText(stat.value)
        if visIdx % 2 == 0 then row.bg:Show() else row.bg:Hide() end
        row:EnableMouse(false)
        row:SetScript("OnMouseUp", nil)
        row:Show()
        y = y + 22
    end

    -- Split instances into raids and dungeons
    local raids, dungeons = {}, {}
    for name, data in pairs(pveData) do
        if PS.RAID_INSTANCES and PS.RAID_INSTANCES[name] then
            table.insert(raids, { name = name, data = data })
        else
            table.insert(dungeons, { name = name, data = data })
        end
    end
    table.sort(raids, function(a, b) return a.name < b.name end)
    table.sort(dungeons, function(a, b) return a.name < b.name end)

    -- Helper: add a separator line
    local function AddSep()
        idx = idx + 1
        local sep = GetRow(idx)
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", 0, -y)
        sep:SetPoint("RIGHT", 0, 0)
        sep:SetHeight(14)
        sep.label:SetText(""); sep.value:SetText("")
        sep.bg:Hide(); sep.sep:Show()
        sep:EnableMouse(false); sep:SetScript("OnMouseUp", nil)
        sep:Show()
        y = y + 14
    end

    -- Helper: "None recorded yet" placeholder
    local function AddEmpty()
        idx = idx + 1
        local row = GetRow(idx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", 0, 0)
        row:SetHeight(22)
        row.sep:Hide()
        row.label:SetText("  None recorded yet")
        row.label:SetTextColor(0.5, 0.5, 0.5)
        row.value:SetText("")
        row.bg:Hide()
        row:EnableMouse(false); row:SetScript("OnMouseUp", nil)
        row:Show()
        y = y + 22
    end

    -- ---- RAIDS (no heroic distinction, collapsible) ----
    AddSep()
    idx = idx + 1
    y = y + AddSectionHeader(idx, y, "Raids")

    if #raids == 0 then
        AddEmpty()
    else
        for ri, inst in ipairs(raids) do
            -- Padding between instances
            if ri > 1 then y = y + 6 end

            local expanded = pveExpanded[inst.name]
            local arrow = expanded and "- " or "+ "
            idx = idx + 1
            visIdx = visIdx + 1
            local row = GetRow(idx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            row:SetHeight(22)
            row.sep:Hide()
            row.label:SetText(arrow .. inst.name)
            row.label:SetTextColor(0.4, 0.8, 1)
            local clears = (inst.data.completed or 0)
            row.value:SetText(clears > 0 and (clears .. " cleared") or "")
            if visIdx % 2 == 0 then row.bg:Show() else row.bg:Hide() end
            row:EnableMouse(true)
            local instName = inst.name
            row:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    pveExpanded[instName] = not pveExpanded[instName]
                    RenderPvE()
                end
            end)
            row:Show()
            y = y + 22

            if expanded then
                -- Boss kills (combine normal + heroic into one total)
                local bosses = inst.data.bosses or {}
                local bossesH = inst.data.bossesHeroic or {}
                local allBossNames = {}
                for boss in pairs(bosses) do allBossNames[boss] = true end
                for boss in pairs(bossesH) do allBossNames[boss] = true end
                local sortedBosses = {}
                for boss in pairs(allBossNames) do
                    table.insert(sortedBosses, { name = boss, kills = (bosses[boss] or 0) + (bossesH[boss] or 0) })
                end
                table.sort(sortedBosses, function(a, b) return a.name < b.name end)

                for _, boss in ipairs(sortedBosses) do
                    idx = idx + 1
                    visIdx = visIdx + 1
                    local brow = GetRow(idx)
                    brow:ClearAllPoints()
                    brow:SetPoint("TOPLEFT", 0, -y)
                    brow:SetPoint("RIGHT", 0, 0)
                    brow:SetHeight(22)
                    brow.sep:Hide()
                    brow.label:SetText("    " .. boss.name)
                    brow.label:SetTextColor(0.7, 0.7, 0.8)
                    brow.value:SetText(tostring(boss.kills))
                    if visIdx % 2 == 0 then brow.bg:Show() else brow.bg:Hide() end
                    brow:EnableMouse(false); brow:SetScript("OnMouseUp", nil)
                    brow:Show()
                    y = y + 22
                end
            end
        end
    end

    -- ---- DUNGEONS (Normal / Heroic columns, collapsible) ----
    AddSep()
    idx = idx + 1
    y = y + AddSectionHeader(idx, y, "Dungeons")

    if #dungeons == 0 then
        AddEmpty()
    else
        -- Column header row
        idx = idx + 1
        local hdr = GetRow(idx)
        hdr:ClearAllPoints()
        hdr:SetPoint("TOPLEFT", 0, -y)
        hdr:SetPoint("RIGHT", 0, 0)
        hdr:SetHeight(18)
        hdr.sep:Hide()
        hdr.label:SetText("")
        hdr.value:SetText("|cffbbbbbbN|r  |cffff9900H|r")
        hdr.bg:Hide()
        hdr:EnableMouse(false); hdr:SetScript("OnMouseUp", nil)
        hdr:Show()
        y = y + 18

        for di, inst in ipairs(dungeons) do
            -- Padding between instances
            if di > 1 then y = y + 6 end

            local expanded = pveExpanded[inst.name]
            local arrow = expanded and "- " or "+ "
            idx = idx + 1
            visIdx = visIdx + 1
            local row = GetRow(idx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            row:SetHeight(22)
            row.sep:Hide()
            row.label:SetText(arrow .. inst.name)
            row.label:SetTextColor(0.4, 0.8, 1)
            local nClears = inst.data.completed or 0
            local hClears = inst.data.completedHeroic or 0
            local clearStr = ""
            if nClears > 0 or hClears > 0 then
                clearStr = string.format("|cffbbbbbb%d|r  |cffff9900%d|r", nClears, hClears)
            end
            row.value:SetText(clearStr)
            if visIdx % 2 == 0 then row.bg:Show() else row.bg:Hide() end
            row:EnableMouse(true)
            local instName = inst.name
            row:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    pveExpanded[instName] = not pveExpanded[instName]
                    RenderPvE()
                end
            end)
            row:Show()
            y = y + 22

            if expanded then
                -- Boss kills with N / H columns
                local normalBosses = inst.data.bosses or {}
                local heroicBosses = inst.data.bossesHeroic or {}
                local allBossNames = {}
                for boss in pairs(normalBosses) do allBossNames[boss] = true end
                for boss in pairs(heroicBosses) do allBossNames[boss] = true end
                local sortedBosses = {}
                for boss in pairs(allBossNames) do
                    table.insert(sortedBosses, { name = boss, normal = normalBosses[boss] or 0, heroic = heroicBosses[boss] or 0 })
                end
                table.sort(sortedBosses, function(a, b) return a.name < b.name end)

                for _, boss in ipairs(sortedBosses) do
                    idx = idx + 1
                    visIdx = visIdx + 1
                    local brow = GetRow(idx)
                    brow:ClearAllPoints()
                    brow:SetPoint("TOPLEFT", 0, -y)
                    brow:SetPoint("RIGHT", 0, 0)
                    brow:SetHeight(22)
                    brow.sep:Hide()
                    brow.label:SetText("    " .. boss.name)
                    brow.label:SetTextColor(0.7, 0.7, 0.8)
                    brow.value:SetText(string.format("|cffbbbbbb%d|r  |cffff9900%d|r", boss.normal, boss.heroic))
                    if visIdx % 2 == 0 then brow.bg:Show() else brow.bg:Hide() end
                    brow:EnableMouse(false); brow:SetScript("OnMouseUp", nil)
                    brow:Show()
                    y = y + 22
                end
            end
        end
    end

    content:SetHeight(math.max(1, y))
end

-- ============ SPELLS TAB ============
local spellHeaders = CreateFrame("Frame", nil, f)
spellHeaders:SetPoint("TOPLEFT", 10, -56)
spellHeaders:SetPoint("TOPRIGHT", -28, -56)
spellHeaders:SetHeight(18)
spellHeaders:Hide()

-- Spell sort state
local spellSortKey = "total"  -- default sort column
local spellSortAsc = false    -- default descending

local spellHeaderButtons = {}
local spellHeaderDefs = {
    { key = "name",    label = "Spell",   xOff = 6,   width = 155, align = "LEFT" },
    { key = "casts",   label = "Casts",   xOff = 164, width = 45,  align = "RIGHT" },
    { key = "highest", label = "Highest", xOff = 214, width = 58,  align = "RIGHT" },
    { key = "total",   label = "Total",   xOff = 276, width = 58,  align = "RIGHT" },
    { key = "avg",     label = "Avg",     xOff = 338, width = 58,  align = "RIGHT" },
}

local function UpdateSpellHeaderText()
    for _, hd in ipairs(spellHeaderDefs) do
        local btn = spellHeaderButtons[hd.key]
        if btn then
            local arrow = ""
            if spellSortKey == hd.key then
                arrow = spellSortAsc and " ^" or " v"
            end
            if spellSortKey == hd.key then
                btn.fs:SetTextColor(1, 0.82, 0)
            else
                btn.fs:SetTextColor(0.6, 0.6, 0.6)
            end
            btn.fs:SetText(hd.label .. arrow)
        end
    end
end

for _, hd in ipairs(spellHeaderDefs) do
    local btn = CreateFrame("Button", nil, spellHeaders)
    btn:SetPoint("LEFT", spellHeaders, "LEFT", hd.xOff, 0)
    btn:SetSize(hd.width, 20)
    btn.fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.fs:SetPoint(hd.align)
    btn.fs:SetWidth(hd.width)
    btn.fs:SetJustifyH(hd.align)
    btn.fs:SetText(hd.label)
    btn.fs:SetTextColor(0.6, 0.6, 0.6)
    btn:SetScript("OnEnter", function(self) self.fs:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function(self)
        if spellSortKey == hd.key then self.fs:SetTextColor(1, 0.82, 0)
        else self.fs:SetTextColor(0.6, 0.6, 0.6) end
    end)
    btn:SetScript("OnClick", function()
        if spellSortKey == hd.key then
            spellSortAsc = not spellSortAsc
        else
            spellSortKey = hd.key
            spellSortAsc = (hd.key == "name") -- name defaults asc, numbers desc
        end
        UpdateSpellHeaderText()
        if PS.RefreshUI then PS:RefreshUI() end
    end)
    spellHeaderButtons[hd.key] = btn
end
UpdateSpellHeaderText()

-- Separator line under spell headers
local spellHeaderSep = spellHeaders:CreateTexture(nil, "ARTWORK")
spellHeaderSep:SetHeight(1)
spellHeaderSep:SetPoint("BOTTOMLEFT", 0, -1)
spellHeaderSep:SetPoint("BOTTOMRIGHT", 0, -1)
spellHeaderSep:SetColorTexture(0.4, 0.4, 0.45, 0.8)

local spellScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
spellScroll:SetPoint("TOPLEFT", 10, -74)
spellScroll:SetPoint("BOTTOMRIGHT", -28, 10)
spellScroll:Hide()

local spellContent = CreateFrame("Frame", nil, spellScroll)
spellContent:SetWidth(spellScroll:GetWidth() or 360)
spellContent:SetHeight(1)
spellScroll:SetScrollChild(spellContent)
spellScroll:SetScript("OnSizeChanged", function(self, w) spellContent:SetWidth(w) end)

local spellRows = {}
local function GetSpellRow(idx)
    if spellRows[idx] then return spellRows[idx] end
    local row = CreateFrame("Frame", nil, spellContent)
    row:SetHeight(20)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(155)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(1, 1, 1)

    row.casts = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.casts:SetPoint("LEFT", 164, 0)
    row.casts:SetWidth(45)
    row.casts:SetJustifyH("RIGHT")
    row.casts:SetTextColor(0.8, 0.8, 0.8)

    row.highest = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.highest:SetPoint("LEFT", 214, 0)
    row.highest:SetWidth(58)
    row.highest:SetJustifyH("RIGHT")

    row.total = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.total:SetPoint("LEFT", 276, 0)
    row.total:SetWidth(58)
    row.total:SetJustifyH("RIGHT")

    row.avg = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.avg:SetPoint("LEFT", 338, 0)
    row.avg:SetWidth(58)
    row.avg:SetJustifyH("RIGHT")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.04)

    spellRows[idx] = row
    return row
end

local function RenderSpells()
    for _, r in pairs(spellRows) do r:Hide() end
    if not PS.db then return end

    local spells = PS:GetViewSpells()
    local sorted = {}
    for id, data in pairs(spells) do
        if data.casts > 0 or data.damage > 0 or data.healing > 0 then
            data._id = id
            -- Pre-compute sort values
            data._total = math.max(data.damage, data.healing)
            data._avg = data.casts > 0 and (data._total / data.casts) or 0
            table.insert(sorted, data)
        end
    end

    local function getSortVal(sp)
        if spellSortKey == "name" then return (sp.name or ""):lower()
        elseif spellSortKey == "casts" then return sp.casts
        elseif spellSortKey == "highest" then return sp.highestHit or 0
        elseif spellSortKey == "total" then return sp._total
        elseif spellSortKey == "avg" then return sp._avg
        end
        return sp._total
    end

    table.sort(sorted, function(a, b)
        local va, vb = getSortVal(a), getSortVal(b)
        if va == vb then
            -- Tiebreak: name ascending
            return (a.name or ""):lower() < (b.name or ""):lower()
        end
        if spellSortAsc then return va < vb else return va > vb end
    end)

    local y = 0
    for i, sp in ipairs(sorted) do
        local row = GetSpellRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", 0, 0)
        -- Determine if damage or healing spell (dominant value)
        local isDamage = sp.damage >= sp.healing
        local cr, cg, cb
        if sp.damage == 0 and sp.healing == 0 then
            cr, cg, cb = 0.8, 0.8, 0.8
        elseif isDamage then
            cr, cg, cb = 1, 0.4, 0.4
        else
            cr, cg, cb = 0.4, 1, 0.4
        end

        row.name:SetText(sp.name or "?")
        row.name:SetTextColor(1, 1, 1)
        row.casts:SetText(tostring(sp.casts))

        local highest = sp.highestHit or 0
        row.highest:SetText(highest > 0 and PS:FormatNumber(highest) or "-")
        row.highest:SetTextColor(cr, cg, cb)

        local total = isDamage and sp.damage or sp.healing
        row.total:SetText(total > 0 and PS:FormatNumber(total) or "-")
        row.total:SetTextColor(cr, cg, cb)

        local avgVal = "-"
        if sp.casts > 0 and total > 0 then
            avgVal = PS:FormatNumber(total / sp.casts)
        end
        row.avg:SetText(avgVal)
        row.avg:SetTextColor(cr, cg, cb)
        if i % 2 == 0 then row.bg:Show() else row.bg:Hide() end
        row:Show()

        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                local canReset = sp._id and PS.viewMode ~= "total" and not PS.viewCharKey
                local resetInfo = canReset and { spellId = sp._id } or nil
                local spellVal = "Casts: " .. sp.casts
                if sp.damage > 0 then spellVal = spellVal .. ", Dmg: " .. PS:FormatNumber(sp.damage) end
                if sp.healing > 0 then spellVal = spellVal .. ", Heal: " .. PS:FormatNumber(sp.healing) end
                ShowStatContextMenu(sp.name or "?", spellVal, resetInfo)
            end
        end)

        y = y + 20
    end

    if #sorted == 0 then
        local row = GetSpellRow(1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)
        row.name:SetText("No spells recorded yet")
        row.name:SetTextColor(0.5, 0.5, 0.5)
        row.casts:SetText("")
        row.highest:SetText("")
        row.total:SetText("")
        row.avg:SetText("")
        row.bg:Hide()
        row:Show()
        y = 20
    end

    spellContent:SetHeight(math.max(1, y))
end

-- ============ SETTINGS TAB ============
local settingsFrame = CreateFrame("Frame", nil, f)
settingsFrame:SetPoint("TOPLEFT", 10, -56)
settingsFrame:SetPoint("BOTTOMRIGHT", -10, 10)
settingsFrame:Hide()

local settingsWidgets = {}

local function MakeSettingsLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    return fs
end

local function MakeSettingsCheckbox(parent, x, y, label, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb.text:SetTextColor(0.9, 0.9, 0.9)
    cb.getVal = getVal
    cb.setVal = setVal
    cb:SetScript("OnClick", function(self)
        self.setVal(self:GetChecked())
    end)
    table.insert(settingsWidgets, cb)
    return cb
end

local function MakeSettingsCycleButton(parent, x, y, label, options, getVal, setVal)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(180, 22)
    btn:SetPoint("TOPLEFT", x, y)
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("LEFT", 0, 0)
    btn.label:SetTextColor(0.9, 0.9, 0.9)
    btn.options = options
    btn.getVal = getVal
    btn.setVal = setVal
    btn.labelPrefix = label
    btn:SetScript("OnClick", function(self)
        local cur = self.getVal()
        for i, opt in ipairs(self.options) do
            if opt == cur then
                local next = self.options[(i % #self.options) + 1]
                self.setVal(next)
                self.label:SetText(self.labelPrefix .. ": " .. next)
                return
            end
        end
        -- fallback
        self.setVal(self.options[1])
        self.label:SetText(self.labelPrefix .. ": " .. self.options[1])
    end)
    btn:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function(self) self.label:SetTextColor(0.9, 0.9, 0.9) end)
    table.insert(settingsWidgets, btn)
    return btn
end

-- Build settings UI elements
local sy = -4

-- Section: Mini Bar
MakeSettingsLabel(settingsFrame, "|cffffd100Mini Bar|r", 8, sy)
sy = sy - 18

local miniSizeBtn = MakeSettingsCycleButton(settingsFrame, 16, sy, "Size",
    {"small", "medium", "large"},
    function() return PS.settings and PS.settings.miniBarSize or "medium" end,
    function(v)
        if PS.settings then PS.settings.miniBarSize = v end
        ApplyMiniSize()
    end)
sy = sy - 24

local miniShowCb = MakeSettingsCheckbox(settingsFrame, 16, sy, "Show Mini Bar",
    function() return PS.settings and PS.settings.showMini end,
    function(v)
        if PS.settings then PS.settings.showMini = v end
        if v then mini:Show() else mini:Hide() end
    end)
sy = sy - 28

-- Section: Killstreak
MakeSettingsLabel(settingsFrame, "|cffffd100Killstreak|r", 8, sy)
sy = sy - 18

local streakEnabledCb = MakeSettingsCheckbox(settingsFrame, 16, sy, "Enabled",
    function() return PS.settings and PS.settings.killstreakEnabled end,
    function(v) if PS.settings then PS.settings.killstreakEnabled = v end end)
sy = sy - 24

local streakScreenCb = MakeSettingsCheckbox(settingsFrame, 16, sy, "Screen Popup",
    function() return PS.settings and PS.settings.killstreakScreen end,
    function(v) if PS.settings then PS.settings.killstreakScreen = v end end)
sy = sy - 24

local streakChatCb = MakeSettingsCheckbox(settingsFrame, 16, sy, "Chat Messages",
    function() return PS.settings and PS.settings.killstreakChat end,
    function(v) if PS.settings then PS.settings.killstreakChat = v end end)
sy = sy - 28

-- Section: PvP Kill Sound
MakeSettingsLabel(settingsFrame, "|cffffd100PvP Kill Sound|r", 8, sy)
sy = sy - 18

local pvpSoundCb = MakeSettingsCheckbox(settingsFrame, 16, sy, "Play sound on killing blows",
    function() return PS.settings and PS.settings.pvpKillSound end,
    function(v) if PS.settings then PS.settings.pvpKillSound = v end end)
sy = sy - 28

-- Section: Announce
MakeSettingsLabel(settingsFrame, "|cffffd100Announce|r", 8, sy)
sy = sy - 18

local announceBtn = MakeSettingsCycleButton(settingsFrame, 16, sy, "Mode",
    {"none", "say", "emote", "group", "all"},
    function() return PS.settings and PS.settings.killstreakAnnounce or "none" end,
    function(v) if PS.settings then PS.settings.killstreakAnnounce = v end end)
sy = sy - 28

-- Section: Chat
MakeSettingsLabel(settingsFrame, "|cffffd100Chat|r", 8, sy)
sy = sy - 18

local chatFrameBtn = MakeSettingsCycleButton(settingsFrame, 16, sy, "Chat Frame",
    {"1", "2", "3", "4", "5", "6", "7"},
    function() return PS.settings and tostring(PS.settings.chatFrame or 1) end,
    function(v) if PS.settings then PS.settings.chatFrame = tonumber(v) or 1 end end)
sy = sy - 28

-- Section: Data
MakeSettingsLabel(settingsFrame, "|cffffd100Data|r", 8, sy)
sy = sy - 22

local resetBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(140, 22)
resetBtn:SetPoint("TOPLEFT", 16, sy)
resetBtn:SetText("Reset Char Stats")
resetBtn:SetScript("OnClick", function()
    StaticPopup_Show("PLAYERSTATISTICS_CONFIRM_RESET")
end)
sy = sy - 26

local resetAllBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetAllBtn:SetSize(180, 22)
resetAllBtn:SetPoint("TOPLEFT", 16, sy)
resetAllBtn:SetText("Reset All Characters")
resetAllBtn:SetScript("OnClick", function()
    StaticPopup_Show("PLAYERSTATISTICS_CONFIRM_RESET_ALL")
end)
sy = sy - 26

local resetSessionBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetSessionBtn:SetSize(140, 22)
resetSessionBtn:SetPoint("TOPLEFT", 16, sy)
resetSessionBtn:SetText("Reset Session")
resetSessionBtn:SetScript("OnClick", function()
    PS:ResetSession()
end)

local function RefreshSettings()
    for _, w in ipairs(settingsWidgets) do
        if w.getVal and w.SetChecked then
            w:SetChecked(w.getVal())
        elseif w.getVal and w.labelPrefix then
            w.label:SetText(w.labelPrefix .. ": " .. (w.getVal() or "?"))
        end
    end
end

-- ============ TAB SWITCHING ============
local function UpdateTabs()
    for key, tab in pairs(tabButtons) do
        if key == currentTab then
            tab.label:SetTextColor(1, 1, 1)
            tab.underline:Show()
        else
            tab.label:SetTextColor(0.6, 0.6, 0.6)
            tab.underline:Hide()
        end
    end
end

local function RefreshContent()
    if currentTab == "combat" then RenderStats(COMBAT_STATS)
    elseif currentTab == "pvp" then RenderStats(PVP_STATS)
    elseif currentTab == "pve" then RenderPvE()
    elseif currentTab == "general" then RenderStats(GENERAL_STATS)
    elseif currentTab == "spells" then RenderSpells()
    elseif currentTab == "settings" then RefreshSettings()
    end
end

local function SwitchTab(key)
    currentTab = key
    UpdateTabs()
    scroll:Hide()
    spellScroll:Hide()
    spellHeaders:Hide()
    settingsFrame:Hide()
    if key == "spells" then
        spellHeaders:Show()
        spellScroll:Show()
    elseif key == "settings" then
        settingsFrame:Show()
    else
        scroll:Show()
    end
    RefreshContent()
end

for _, tab in pairs(tabButtons) do
    tab:SetScript("OnClick", function(self) SwitchTab(self.key) end)
end

-- ============ ON SHOW ============
f:SetScript("OnShow", function()
    -- Update dropdown text
    if PS.viewMode == "total" then
        UIDropDownMenu_SetText(dropdown, "All Characters")
    elseif PS.viewCharKey then
        UIDropDownMenu_SetText(dropdown, PS.viewCharKey)
    else
        UIDropDownMenu_SetText(dropdown, PS.charKey or "Character")
    end
    SwitchTab(currentTab)
end)

-- Auto-refresh every 2 seconds when visible
local refreshTimer = 0
f:SetScript("OnUpdate", function(self, dt)
    refreshTimer = refreshTimer + dt
    if refreshTimer >= 2 then
        refreshTimer = 0
        if currentTab ~= "settings" then
            RefreshContent()
        end
    end
end)

-- Public refresh
function PS:RefreshUI()
    if f:IsShown() then RefreshContent() end
end

-- ============ INIT MINI POSITION ============
local uiInit = CreateFrame("Frame")
uiInit:RegisterEvent("ADDON_LOADED")
uiInit:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "PlayerStatistics" then
        C_Timer.After(0.1, function()
            local pos = PlayerStatsDB and PlayerStatsDB.miniPos
            if pos and pos.point then
                mini:ClearAllPoints()
                mini:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
            end
            if PS.settings and PS.settings.showMini then mini:Show() else mini:Hide() end
            ApplyMiniSize()
            PS:RefreshMini()
        end)
        self:UnregisterAllEvents()
    end
end)
