-- ============================================================================
-- Voice menu (Z / X) for the voiced Vael'Thor castes (post-hook of lua/VoiceOver.lua, every VM).
-- Vanilla looks the menu up by class name and has none for "VTVanguard" (empty menu, voice keys did nothing).
-- The entries reuse the vanilla voice ids, so key binds, the send limit and the commander alerts keep working;
-- the server swaps the sound for the caste's own line (Server.lua CreateVoiceMessage, Classes/VTVoice.lua).
-- ============================================================================

local kVTRequestMenus =
{
    VTVanguard =
    {
        [LEFT_MENU]  = { kVoiceId.MarineRequestMedpack, kVoiceId.MarineRequestAmmo, kVoiceId.MarineRequestOrder,
                         kVoiceId.MarineRequestStructure, kVoiceId.Ping },
        [RIGHT_MENU] = { kVoiceId.MarineTaunt, kVoiceId.MarineCovering, kVoiceId.MarineFollowMe,
                         kVoiceId.MarineLetsMove, kVoiceId.MarineHostiles, kVoiceId.MarineAcknowledged },
    },
}

-- Menu labels that read differently for the empire (vanilla text for everything else).
local kVTVoiceLabels =
{
    [kVoiceId.MarineRequestMedpack]   = "VT_VOICE_REQ_SHIELD",
    [kVoiceId.MarineRequestAmmo]      = "VT_VOICE_REQ_ARMS",
    [kVoiceId.MarineRequestStructure] = "VT_VOICE_BUILD",
    [kVoiceId.MarineLetsMove]         = "VT_VOICE_ADVANCE",
}

-- The menu passes a class name, which can be a robotic-skin alias ("BigMac"), so the local player decides.
local function GetVTMenuClass(className)
    if kVTRequestMenus[className] then
        return className
    end
    local player = Client and Client.GetLocalPlayer()
    local localClass = player and player.GetClassName and player:GetClassName()
    return localClass and kVTRequestMenus[localClass] and localClass or nil
end

local oldGetRequestMenu = GetRequestMenu
function GetRequestMenu(side, className)
    local vtClass = GetVTMenuClass(className)
    if vtClass then
        return kVTRequestMenus[vtClass][side] or {}
    end
    return oldGetRequestMenu(side, className)
end

if Client then
    local oldGetVoiceDescriptionText = GetVoiceDescriptionText
    function GetVoiceDescriptionText(voiceId)
        local label = kVTVoiceLabels[voiceId]
        if label and GetVTMenuClass(nil) then
            return VT_GetString(label)
        end
        return oldGetVoiceDescriptionText(voiceId)
    end
end
