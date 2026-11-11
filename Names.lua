-- Character name and nameplate controls for Azeroth Stillframe.
-- Uses only CVars present in the running client. Never changes nameplates via
-- protected frame APIs, and restores exactly the settings it was able to change.
local cvars = {
    -- Floating world names (distinct from nameplates).
    "UnitNameOwn",
    "UnitNameFriendlyPlayerName",
    "UnitNameEnemyPlayerName",
    "UnitNameNPC",
    "UnitNameFriendlySpecialNPCName",
    "UnitNameHostleNPC", -- Blizzard's historical spelling
    "UnitNameInteractiveNPC",
    "UnitNameNonCombatCreatureName",
    "UnitNameFriendlyPetName",
    "UnitNameEnemyPetName",
    "UnitNamePlayerGuild",
    "UnitNameGuildTitle",
    "UnitNamePlayerPVPTitle",
    -- Visible healthbar/name overlays; names above heads can be independent.
    "nameplateShowFriends",
    "nameplateShowFriendlyPlayers",
    "nameplateShowFriendlyNpcs",
    "nameplateShowEnemies",
    "nameplateShowAll",
    "nameplateShowSelf",
}

local previous = nil

local function readCVar(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    if ok and value ~= nil and value ~= "" then return tostring(value) end
    return nil
end

local function writeCVar(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not setter then return false end
    local ok = pcall(setter, name, value)
    return ok
end

local function hideNames()
    if previous then return end
    previous = {}
    for _, name in ipairs(cvars) do
        local value = readCVar(name)
        if value and value ~= "0" then
            if writeCVar(name, "0") and readCVar(name) == "0" then
                previous[name] = value
            end
        end
    end
end

local function restoreNames()
    if not previous then return end
    for name, value in pairs(previous) do
        -- Avoid overwriting changes performed by the user or another add-on.
        if readCVar(name) == "0" then
            writeCVar(name, value)
        end
    end
    previous = nil
end

AzerothStillframeNamesAPI = {
    Hide = hideNames,
    Restore = restoreNames,
}
