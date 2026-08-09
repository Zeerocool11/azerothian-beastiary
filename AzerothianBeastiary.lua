local ADDON_NAME = "AzerothianBeastiary"
AzerothianBeastiaryDB = AzerothianBeastiaryDB or {}

local function InitializeDatabase()
    AzerothianBeastiaryDB.npcs = AzerothianBeastiaryDB.npcs or {}
    AzerothianBeastiaryDB.version = "0.1.0"
end

local debugMode = false

local function DebugPrint(...)
    if debugMode then
        print("|cff00bfff[ABC Debug]|r", ...)
    end
end

local function GetNPCID(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local guid = unitGUID(unit)

    if not guid then
        return nil
    end

    local unitType, _, _, _, _, npdID = strsplit("-", guid)
    
    if unitType ~= "Vehicle" then
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

    if UnitIsPlayer(unit) then 
        return false
    end

    return true

end

local function GetLocationData()
    local mapID = C.Map.GetBestMapForUnit("player")

    local mapName = nil

    if mapID then
        local mapInfo = C.Map.GetMapInfo(mapID)

        if mapInfo then 
            mapName = mapInfo.name
        end
    end

    local inInstance, instanceType = IsInInstance()

    local instanceName = GetInstanceInfo()

    return {
        mapID = mapID,
        mapName = mapName,
        inInstance = inInstance,
        instanceType = instanceType,
        instanceName = instanceName
    }
end

local function RecordNPC(unit, source)
    if not IsValidEnemy(unit) then
        DebugPrint("Ignored non-enemy:", unit)
        return false
    end

    local npcID = GetNPCID(unit)

    if not npcID then
        DebugPrint("Ignored non-creature unit:", unit)
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

            firstSource = source,
            lastSource = source,

            locations = {}
        }

        print(
            "|cff00ff00[ABC New]|r",
            npcName, 
            "|cffaaaaaa(ID:",
            npcID ..")|r"
        )

    else

        local npcData = AzerothianBeastiaryDB.npcs[npcID]

        npcData.lastSeen = currentTime
        npcData.seenCount = (npcData.seenCount or 0) + 1
        npcData.lastSource = source

        DebugPrint(
            "Already collected:",
            npcName,
            "ID:",
            npcID
        )
    end

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

    DebugPrint(
        "New location for NPC:",
        npcName,
        location.mapName or location.instanceName
    )
end

return true

end

local function scanUnit(unit, source)
    if not unit or not UnitExists(unit) then
        return false
    end

    return RecordNPC(unit, source)
end

local function ScanVisibleNameplates()
local scanned = 0
local collected = 0

for i = 1, 40 do

    local unit = "nameplate" .. i

    if UnitExists(unit) then

        scanned = scanned + 1

        local beforeCount = 0

        for _ in pairs(AzerothianBestiaryDB.npcs) do
            beforeCount = beforeCount + 1
        end

        ScanUnit(unit, "MANUAL_NAMEPLATE_SCAN")

        local afterCount = 0

        for _ in pairs(AzerothianBestiaryDB.npcs) do
            afterCount = afterCount + 1
        end

        if afterCount > beforeCount then
            collected = collected + 1
        end
    end
end

print(
    "|cff00bfff[ABC]|r Scan complete.",
    "Units scanned:",
    scanned,
    "|cff00ff00New NPCs:",
    collected
)

end

local eventFrame = CreateFrame("Frame")

eventFrame("PLAYER_LOGIN")
eventFrame("NAME_PLATE_UNIT_ADDED")
eventFrame("PLAYER_TARGET_CHANGED")
eventFrame("UPDATE_MOUSEOVER_UNIT")

eventFrame("OnEvent", function(self, event, ...)

-- ============================================
-- ADDON INITIALIZATION
-- ============================================

if event == "PLAYER_LOGIN" then

    InitializeDatabase()

    print("|cff00bfff[Azeroth Bestiary Collector]|r Loaded.")
    print(
        "|cffaaaaaaUse /ab help for commands.|r"
    )

    return
end

-- ============================================
-- AUTOMATIC NAMEPLATE COLLECTION
-- ============================================

if event == "NAME_PLATE_UNIT_ADDED" then

    local unit = ...

    ScanUnit(unit, "NAMEPLATE")

    return
end

-- ============================================
-- TARGET COLLECTION
-- ============================================

if event == "PLAYER_TARGET_CHANGED" then

    ScanUnit("target", "TARGET")

    return
end

-- ============================================
-- MOUSEOVER COLLECTION
-- ============================================

if event == "UPDATE_MOUSEOVER_UNIT" then

    ScanUnit("mouseover", "MOUSEOVER")

    return
end

end)

local function GetStatistics()

local totalNPCs = 0
local totalEncounters = 0

for _, npcData in pairs(AzerothianBestiaryDB.npcs) do

    totalNPCs = totalNPCs + 1
    totalEncounters =
        totalEncounters +
        (npcData.seenCount or 0)
end

return totalNPCs, totalEncounters

end

local function ShowStats()

local totalNPCs, totalEncounters =
    GetStatistics()

print("|cff00bfff========== ABC STATISTICS ==========|r")

print(
    "|cffffffffUnique Enemy NPCs:|r",
    "|cff00ff00" .. totalNPCs .. "|r"
)

print(
    "|cffffffffTotal Encounters:|r",
    "|cffffd700" .. totalEncounters .. "|r"
)

print("|cff00bfff==================================|r")

end

local function ListNPCs()

local npcList = {}

for npcID, npcData in pairs(AzerothianBestiaryDB.npcs) do

    table.insert(npcList, {
        id = npcID,
        name = npcData.name
    })
end

table.sort(npcList, function(a, b)
    return a.id < b.id
end)

print("|cff00bfff========== COLLECTED NPCS ==========|r")

for _, npc in ipairs(npcList) do

    print(
        "|cffffffff" .. npc.id .. "|r",
        "-",
        npc.name
    )
end

print("|cff00bfff====================================|r")
print("Total:", #npcList)

end

local function ScanCurrentTarget()

if not UnitExists("target") then

    print(
        "|cffff0000[ABC]|r No target selected."
    )

    return
end

local npcID = GetNPCID("target")

if not npcID then

    print(
        "|cffff0000[ABC]|r Target is not a valid creature NPC."
    )

    return
end

if not IsValidEnemy("target") then

    print(
        "|cffff0000[ABC]|r Target is not an attackable enemy."
    )

    return
end

local name = UnitName("target")

local isNew =
    not AzerothianBestiaryDB.npcs[npcID]

ScanUnit("target", "MANUAL_TARGET_SCAN")

if isNew then

    print(
        "|cff00ff00[ABC]|r Added:",
        name,
        "|cffaaaaaa(ID:",
        npcID .. ")|r"
    )

else

    print(
        "|cffffd700[ABC]|r Already collected:",
        name,
        "|cffaaaaaa(ID:",
        npcID .. ")|r"
    )
end

end

local function ExportNPCList()

local npcList = {}

for npcID, npcData in pairs(AzerothianBestiaryDB.npcs) do

    table.insert(
        npcList,
        npcID .. "\t" .. (npcData.name or "Unknown")
    )
end

table.sort(npcList)

print("|cff00bfff========== ABC EXPORT ==========|r")
print("|cffaaaaaaNPC ID\tName|r")

for _, line in ipairs(npcList) do
    print(line)
end

print("|cff00bfff================================|r")
print(
    "|cffaaaaaaCopy this output from your chat log for spreadsheet import.|r"
)

end

local function ClearDatabase()

AzerothBestiaryDB.npcs = {}

print(
    "|cffff0000[ABC]|r All collected NPC data has been cleared."
)

end

local function ShowHelp()

print("|cff00bfff========== ABC COMMANDS ==========|r")

print(
    "|cffffffff/ab scan|r - Scan your current target."
)

print(
    "|cffffffff/ab nameplates|r - Scan visible nameplates."
)

print(
    "|cffffffff/ab stats|r - Show collection statistics."
)

print(
    "|cffffffff/ab list|r - List all unique NPC IDs."
)

print(
    "|cffffffff/ab export|r - Export NPC IDs and names."
)

print(
    "|cffffffff/ab debug|r - Toggle debug messages."
)

print(
    "|cffffffff/ab clear|r - Clear all collected data."
)

print(
    "|cffffffff/ab help|r - Show this help menu."
)

print("|cff00bfff================================|r")

end

SLASH_AZEROTHIANBESTIARY1 = "/ab"
SLASH_AZEROTHIANBESTIARY2 = "/bestiary"

SlashCmdList["AZEROTHIANBESTIARY"] =
function(message)

    local command =
        string.lower(
            string.match(message or "", "^(%S*)")
            or ""
        )

    if command == "scan" then

        ScanCurrentTarget()

    elseif command == "nameplates" then

        ScanVisibleNameplates()

    elseif command == "stats" then

        ShowStats()

    elseif command == "list" then

        ListNPCs()

    elseif command == "export" then

        ExportNPCList()

    elseif command == "debug" then

        debugMode = not debugMode

        print(
            "|cff00bfff[ABC]|r Debug mode:",
            debugMode and
            "|cff00ff00ON|r" or
            "|cffff0000OFF|r"
        )

    elseif command == "clear" then

        ClearDatabase()

    elseif command == "help"
        or command == "" then

        ShowHelp()

    else

        print(
            "|cffff0000[ABC]|r Unknown command:",
            command
        )

        ShowHelp()
    end
end