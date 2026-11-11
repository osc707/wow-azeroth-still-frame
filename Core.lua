local ADDON_NAME = ...
_G.BINDING_HEADER_AZEROTHSTILLFRAME = "Azeroth Stillframe"
_G.BINDING_NAME_AZEROTHSTILLFRAME_TOGGLE = "Toggle Photo Mode"
_G.BINDING_NAME_AZEROTHSTILLFRAME_CAPTURE = "Capture Screenshot"
_G.BINDING_NAME_AZEROTHSTILLFRAME_CYCLE = "Cycle Composition Guide"
_G.BINDING_NAME_AZEROTHSTILLFRAME_ORIENT = "Rotate / Mirror Composition Guide"

local SF = CreateFrame("Frame")
local active, uiWasVisible, capturePending = false, true, false
local captureSerial = 0
local hideNamesEnabled = true
local overlay = AzerothStillframeOverlayAPI
local names = AzerothStillframeNamesAPI
local modes = { "thirds", "triangle", "phi", "spiral", "off" }
local guide = "thirds"
local orientation = 0

local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffbaa5ffAzeroth Stillframe:|r " .. message)
end

local function save()
    AzerothStillframeDB = AzerothStillframeDB or {}
    AzerothStillframeDB.guide = guide
    AzerothStillframeDB.orientation = orientation
    AzerothStillframeDB.hideNamesEnabled = hideNamesEnabled
end

local function syncGuide()
    overlay.Configure(guide, orientation)
    if active and not capturePending then overlay.Show() else overlay.Hide() end
end

local function restoreUI()
    if active then
        active = false
        names.Restore()
        if uiWasVisible then UIParent:Show() end
    end
    captureSerial = captureSerial + 1
    capturePending = false
    syncGuide()
end

local function enterPhotoMode()
    if active then return end
    if InCombatLockdown() then
        say("Photo mode isn't available during combat. Try again afterward.")
        return
    end
    uiWasVisible = UIParent:IsShown()
    active = true
    if hideNamesEnabled then names.Hide() end
    UIParent:Hide()
    syncGuide()
end

-- Escape (ToggleGameMenu), Alt+Z, or other UI code can show UIParent again
-- while photo mode is active. Treat that as leaving photo mode so the guides
-- and hidden names are restored along with the UI. restoreUI() clears `active`
-- before it calls UIParent:Show(), so this cannot recurse.
UIParent:HookScript("OnShow", function()
    if active then restoreUI() end
end)

function AzerothStillframe_Toggle()
    if active then restoreUI() else enterPhotoMode() end
end

function AzerothStillframe_Capture()
    if capturePending then return end
    if InCombatLockdown() then
        say("Wait until combat ends to take a Stillframe screenshot.")
        return
    end
    local temporaryMode = not active
    if temporaryMode then enterPhotoMode() end
    if not active then return end
    capturePending = true
    captureSerial = captureSerial + 1
    local serial = captureSerial
    syncGuide()
    C_Timer.After(0.15, function()
        if not active or serial ~= captureSerial then return end
        Screenshot()
        C_Timer.After(0.5, function()
            if serial ~= captureSerial then return end
            capturePending = false
            if temporaryMode then restoreUI() else syncGuide() end
        end)
    end)
end

local function setGuide(newGuide)
    guide = newGuide
    save()
    syncGuide()
    say("Guide: " .. guide .. ".")
end

function AzerothStillframe_Cycle()
    local index = 1
    for i, value in ipairs(modes) do
        if value == guide then index = i; break end
    end
    setGuide(modes[(index % #modes) + 1])
end

function AzerothStillframe_Orient()
    orientation = (orientation + 1) % 4
    save()
    syncGuide()
    say("Orientation: " .. (orientation + 1) .. "/4.")
end

local function command(input)
    local cmd = (input or ""):lower():match("^%s*(.-)%s*$")
    if cmd == "" or cmd == "toggle" then
        AzerothStillframe_Toggle()
    elseif cmd == "shot" or cmd == "capture" then
        AzerothStillframe_Capture()
    elseif cmd == "grid" then -- legacy grid toggle
        if guide == "off" then setGuide("thirds") else setGuide("off") end
    elseif cmd == "names" then
        hideNamesEnabled = not hideNamesEnabled
        save()
        if active then
            if hideNamesEnabled then names.Hide() else names.Restore() end
        end
        say("Hide character names " .. (hideNamesEnabled and "on" or "off") .. ".")
    elseif cmd == "off" or cmd == "exit" then
        restoreUI()
    elseif cmd == "orient" or cmd == "rotate" or cmd == "mirror" or cmd == "overlay orient" then
        AzerothStillframe_Orient()
    elseif cmd == "overlay" or cmd == "overlay next" then
        AzerothStillframe_Cycle()
    else
        local requested = cmd:match("^overlay%s+(%S+)$")
        if requested == "thirds" or requested == "triangle" or requested == "phi" or requested == "spiral" or requested == "off" then
            setGuide(requested)
        elseif cmd == "help" then
            say("/as [toggle|shot|names|off], /as overlay [next|thirds|triangle|phi|spiral|off], /as orient")
            say("Keyboard shortcuts are configurable under Keybindings > Azeroth Stillframe.")
        else
            say("Unknown command. Type /as help.")
        end
    end
end

SLASH_AZEROTHSTILLFRAME1 = "/stillframe"
SLASH_AZEROTHSTILLFRAME2 = "/as"
SLASH_AZEROTHSTILLFRAME3 = "/ad"
SLASH_AZEROTHSTILLFRAME4 = "/darkroom"
SlashCmdList.AZEROTHSTILLFRAME = command

SF:RegisterEvent("PLAYER_LOGIN")
SF:RegisterEvent("PLAYER_LOGOUT")
SF:RegisterEvent("PLAYER_REGEN_DISABLED")
SF:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        AzerothStillframeDB = AzerothStillframeDB or {}
        local db = AzerothStillframeDB
        -- If an old DB is present in memory (e.g. manually migrated), import it.
        if not db.migratedFromDarkroom and AzerothDarkroomDB then
            if db.hideNamesEnabled == nil then db.hideNamesEnabled = AzerothDarkroomDB.hideNamesEnabled end
            if db.guide == nil then db.guide = AzerothDarkroomDB.gridEnabled == false and "off" or "thirds" end
            db.migratedFromDarkroom = true
        end
        if db.hideNamesEnabled ~= nil then hideNamesEnabled = db.hideNamesEnabled end
        for _, known in ipairs(modes) do if db.guide == known then guide = known; break end end
        if type(db.orientation) == "number" then orientation = math.floor(db.orientation) % 4 end
        syncGuide()
        say("Ready. Type /as help or configure keys in Keybindings.")
    elseif event == "PLAYER_LOGOUT" then
        restoreUI()
    elseif event == "PLAYER_REGEN_DISABLED" and active then
        restoreUI()
    end
end)
