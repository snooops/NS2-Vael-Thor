-- ============================================================================
-- Vael'Thor Empire - team palette (client)
--
-- Vanilla colours everything of the marine team *type* in marine blue: the
-- scoreboard, chat names, name tags, team messages, voice chat, end screen,
-- unit status names, world texts. The Vael'Thor are a marine-type team, so:
--   * Vael'Thor vs. Aliens: team 1 is always the empire, so on every client the
--     marine colour globals (and the vanilla GUIs' copies of them) become the
--     Vael'Thor violet. VT_ApplyPalette() runs on every matchup change.
--   * Vael'Thor vs. Marines: real marines keep their blue; only what the local
--     Vael'Thor player sees about themselves is recoloured (use prompt, damage
--     numbers, world texts - Client.lua and Hooks/GUIWorldText.lua).
-- ============================================================================

kVTFontColor       = Color(0.86, 0.74, 1.00, 1)   -- marine: 0.756, 0.952, 0.988
kVTTeamColorFloat  = Color(0.72, 0.45, 1.00, 1)   -- marine: 0.302, 0.859, 1
kVTTeamColor       = 0xB873FF                      -- marine: 0x4DB1FF
kVTDamageColor     = Color(0.80, 0.55, 1.00, 1)   -- damage numbers (marine default option: 0x4DDBFF)
kVTVoiceColor      = Color(0.80, 0.66, 1.00, 1)   -- voice chat names (marine: 147/255, 206/255, 1)

local vanilla        -- first-seen vanilla values, to switch back for other matchups
local applied = false

local function RGB(c)
    return { c.r, c.g, c.b }
end

local function SetRGB(target, rgb)
    if target then
        target.r, target.g, target.b = rgb[1], rgb[2], rgb[3]   -- alpha stays as the GUI set it
    end
end

-- A file-local Color (or table of Colors) of a vanilla GUI class: found as an upvalue
-- of one of the class's functions, recoloured in place.
local function FindUpvalue(cls, name)
    if type(cls) ~= "table" then
        return nil
    end
    for _, fn in pairs(cls) do
        if VTBaseline_IsLuaFunction and VTBaseline_IsLuaFunction(fn) then
            local i = 1
            while true do
                local n, v = debug.getupvalue(fn, i)
                if not n then break end
                if n == name then
                    return v
                end
                i = i + 1
            end
        end
    end
    return nil
end

local function Targets()
    local statusColors = FindUpvalue(rawget(_G, "GUIUnitStatus"), "kStatusFontColor")
    return
    {
        font        = kMarineFontColor,                                            -- chat, name tags, end screen, ...
        teamFloat   = kMarineTeamColorFloat,                                       -- world texts, ...
        scoreboard  = rawget(_G, "GUIScoreboard") and GUIScoreboard.kBlueColor,
        voice       = rawget(_G, "GUIVoiceChat") and GUIVoiceChat.kMarineFontColor,
        unitStatus  = type(statusColors) == "table" and statusColors[kMarineTeamType] or nil,
        teamMessage = FindUpvalue(rawget(_G, "GUIMarineTeamMessage"), "kMessageFontColor"),
    }
end

local kVTColors =
{
    font = kVTFontColor, teamFloat = kVTTeamColorFloat, scoreboard = kVTTeamColorFloat,
    voice = kVTVoiceColor, unitStatus = kVTTeamColorFloat, teamMessage = kVTFontColor,
}

-- Recolours every target that exists by now (GUI classes load lazily, so Client.lua calls
-- this again every second). Vanilla colours are recorded per target when first seen.
function VT_ApplyPalette()

    if not Client then
        return
    end
    local vt = VT_GetMatchup ~= nil and VT_GetMatchup() == kVTMatchup.VTvsAliens
    vanilla = vanilla or {}

    for key, target in pairs(Targets()) do
        if target then
            if not vanilla[key] then
                vanilla[key] = RGB(target)
            end
            SetRGB(target, vt and RGB(kVTColors[key]) or vanilla[key])
        end
    end

    if vanilla.teamInt == nil then
        vanilla.teamInt = kMarineTeamColor
    end
    kMarineTeamColor = vt and kVTTeamColor or vanilla.teamInt
    applied = vt

end

-- Is the local client on the Vael'Thor team (also while dead / spectating a teammate)?
function VT_GetLocalIsVT()
    return Client.GetLocalClientTeamNumber and kVTTeamIndex ~= nil and kVTTeamIndex ~= kVTNoTeam
            and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end
