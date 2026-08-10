local ADDON_NAME = "Azerothian Beastiary"
local DB_VERSION = "1.0.0"

AzerothianBeastiaryDB = AzerothianBeastiaryDB or {}

local function LoadDatabase()
    AzerothianBeastiaryDB.npcs = AzerothianBeastiaryDB.npcs or {}
    AzerothianBeastiaryDB.version = "DB_VERSION"
end

local function GetNPCID(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end

    local unitType, _, _, _, _, npcID = strsplit("-", guid)

    if unitType ~= "Creature" then
        return nil
    end

    npcID = tonumber(npcID)

    return npcID
end

local function IsValidEnemy(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if not UnitCanAttack("player", unit) then
        return false
    end

    local playerFaction = UnitFactionGroup("player")
    local npcFaction = UnitFactionGroup(unit)

    if npcFaction == "Alliance" or npcFaction == "Horde" then
        return false
    end

    if UnitIsPlayer(unit) then
        return false
    end

    return true
end

local function GetParentZone(rawMapID)

    if not rawMapID then
        return nil, nil
    end

    local currentMapID = rawMapID

    while currentMapID do

        local mapInfo = C_Map.GetMapInfo(currentMapID)

        if not mapInfo then
            break
        end

        -- We reached an actual zone.
        if mapInfo.mapType == Enum.UIMapType.Zone then
            return mapInfo.mapID, mapInfo.name
        end

        -- No parent means we've reached the top.
        if not mapInfo.parentMapID or mapInfo.parentMapID == 0 then
            return mapInfo.mapID, mapInfo.name
        end

        currentMapID = mapInfo.parentMapID
    end

    -- Fallback: just use the original map.
    local mapInfo = C_Map.GetMapInfo(rawMapID)

    if mapInfo then
        return rawMapID, mapInfo.name
    end

    return rawMapID, nil
end


-- ============================================================
-- LOCATION DATA
-- ============================================================

local function GetLocationData()

    local rawMapID = C_Map.GetBestMapForUnit("player")

    local zoneMapID, zoneName =
        GetParentZone(rawMapID)

    local inInstance, instanceType =
        IsInInstance()

    local instanceName,
        returnedInstanceType,
        difficultyID,
        difficultyName,
        maxPlayers,
        dynamicDifficulty,
        isDynamic,
        instanceID =
        GetInstanceInfo()

    return {
        mapID = zoneMapID,
        mapName = zoneName,
        rawMapID = rawMapID,

        inInstance = inInstance,
        instanceType = instanceType,

        instanceName = instanceName,

        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        instanceID = instanceID
    }
end

local function RecordNPC(unit, source)
    if not IsValidEnemy(unit) then
        return false
    end
    
    local npcID = GetNPCID(unit)
    if not npcID then
        return false
    end

    local npcName = UnitName(unit)
    if not npcName or npcName == "" then
        npcName = "Unknown"
    end

    local currentTime = time()
    local location = GetLocationData()

    if not AzerothianBeastiaryDB.npcs[npcID] then

    AzerothianBeastiaryDB.npcs[npcID] = {
        id = npcID,
        name = npcName,

        firstSeen = currentTime,
        lastSeen = currentTime,
        seenCount = 1,

        locations = {}
    }

    print(
        "|cffaa00ff[NEW NPC]|r",
        npcName,
        "|cffaaaaaa(ID:",
        npcID .. ")|r"
    )

else

    local npcData = AzerothianBeastiaryDB.npcs[npcID]

    npcData.lastSeen = currentTime
    npcData.seenCount = (npcData.seenCount or 0) + 1
end


-- Important: define npcData again here so it exists
-- outside of the if/else block.
local npcData = AzerothianBeastiaryDB.npcs[npcID]


local locationKey

if location.inInstance then

    locationKey =
        "INSTANCE:" ..
        tostring(location.mapID or "UNKNOWN") ..
        ":" ..
        tostring(location.instanceName or "UNKNOWN")

else

    locationKey =
        "MAP:" ..
        tostring(location.mapID or "UNKNOWN")
end


if not npcData.locations[locationKey] then

    npcData.locations[locationKey] = {
        mapID = location.mapID,
        mapName = location.mapName,

        inInstance = location.inInstance,
        instanceType = location.instanceType,
        instanceName = location.instanceName,

        firstSeen = currentTime
    }
end
end

local function scanUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    return RecordNPC(unit)
end

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        LoadDatabase()
        print(
            "|ccffaa00f[Azerothian Beastiary]|r Loaded."
        )

        print(
            "|cffaa00ff /ab help for commands.|r"
        )
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        scanUnit(unit)
        return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
        scanUnit("mouseover")
        return
    end
end)

local function GetStatistics()
    local totalNPCS = 0
    local totalEncounters = 0

    for _, npcData in pairs(AzerothianBeastiaryDB.npcs) do
        totalNPCS = totalNPCS + 1
        totalEncounters =
            totalEncounters +
            (npcData.seenCount or 0)
    end

    return totalNPCS, totalEncounters
end

local function ShowStats()
    local totalNPCS, totalEncounters = 
        GetStatistics()
    
    print(
        "|cffaa00ff AZEROTHIAN BEASTIARY STATISTICS|r"
    )

    print(
        "|cffffffffUnique Enemies:|r",
        "|cff00ff00" .. totalNPCS .. "|r"
    )

    print(
        "|cffffffffTotal Encounters:|r",
        "|cffffd700" .. totalEncounters .. "|r"
    )

    print(
        "|cffaa00ff======================================|r"
    )
end

local function ShowHelp()
    print(
        "|cffaa00ff Azerothian Beastiary Commands |r"
    )

    print(
        "|cffffffff/ab stats|r - Show collection statistics."
    )

    print(
        "|cffffffff/ab help|r - Show this help menu."
    )

    print(
        "|cffaa00ff==============================|r"
    )
end

SLASH_AZEROTHIANBEASTIARY1 = "/ab"
SLASH_AZEROTHIANBEASTIARY2 = "beastiary"

SlashCmdList["AZEROTHIANBEASTIARY"] =
function(message)
    local command = 
        string.lower(
            string.match(
                message or "",
                "^(%S*)"
            ) or ""
        )

    if command == "stats" then
        ShowStats()
    
    elseif command == "help"
        or command == "" then
            ShowHelp()
    
    else
         print(
            "|ccffaa00ff[AZEROTHIAN BEASTIARY]|r Unknown command:",
            command
        )

        ShowHelp()
    end
end