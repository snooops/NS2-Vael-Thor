-- ============================================================================
-- Vael'Thor Empire - team palette (client)
--
-- Vanilla colours everything of the marine team *type* in marine blue: the
-- scoreboard, chat names, name tags, team messages, voice chat, end screen,
-- unit status names, world texts. The Vael'Thor are a marine-type team, so:
--   * Vael'Thor vs. Aliens: team 1 is always the empire, so on every client the
--     marine colour globals (and the vanilla GUIs' copies of them) become the
--     Vael'Thor violet. VT_ApplyPalette() runs on every matchup change.
--   * Marines vs. Vael'Thor (the empire is team 2): real marines keep their blue; only what the local
--     Vael'Thor player sees about themselves is recoloured (use prompt, damage
--     numbers, world texts - Client.lua and Hooks/GUIWorldText.lua).
--   * In every matchup the scoreboard column, the ready room sign and "N players" marker of the Vael'Thor
--     team (kVTTeamIndex) are violet and the other team's are vanilla. The map follows the same rule
--     (GUI/GUIVTMinimap.lua). All of it is re-done when kVTTeamIndex changes: a client starts with the
--     default matchup and only gets the real one (VTMatchup message) a moment after connecting.
-- ============================================================================

kVTFontColor       = Color(0.86, 0.74, 1.00, 1)   -- marine: 0.756, 0.952, 0.988
kVTTeamColorFloat  = Color(0.72, 0.45, 1.00, 1)   -- marine: 0.302, 0.859, 1
kVTTeamColor       = 0xB873FF                      -- marine: 0x4DB1FF
kVTDamageColor     = Color(0.80, 0.55, 1.00, 1)   -- damage numbers (marine default option: 0x4DDBFF)
kVTVoiceColor      = Color(0.80, 0.66, 1.00, 1)   -- voice chat names (marine: 147/255, 206/255, 1)

-- Ready room join signs: the vanilla sign props are 3D "MARINES" (team 1) / "ALIENS" (team 2) letters.
-- The ones above the Vael'Thor team's door are hidden and a 3D "VAEL'THOR" model (art/ui/signs/
-- build_join_sign.sh) is placed at the prop's coords (incl. the prop's scale). The VT model is built in the
-- frame of marine_join.model (letters x-centred on 0.014, y 0.191-0.504, front plane z = 0.105). Each
-- vanilla sign model has its own frame (bounds of its mesh, read with art/skeleton/ns2_model.py), so the VT
-- sign is fitted into it: same centre, same letter height, same front plane.
local kJoinSignModel = PrecacheAsset("models/vaelthor/signs/vt_join_sign.model")
local kVTSignFrame = { x = 0.014, y = 0.3475, z = 0.105, h = 0.313 }
local function Frame(x0, y0, x1, y1, z1)
    return { x = (x0 + x1) / 2, y = (y0 + y1) / 2, z = z1, h = y1 - y0 }
end
local kJoinSignModels =
{
    [1] =
    {
        ["models/props/generic/marine_join.model"]  = Frame(-0.917, 0.191, 0.945, 0.504, 0.105),
        ["models/props/generic/join_text_01.model"] = Frame(-0.917, 0.191, 0.945, 0.504, 0.105),
        ["models/props/generic/join_marine.model"]  = Frame(-1.834, 0.382, 1.890, 1.007, 0.209),
    },
    [2] =
    {
        ["models/props/generic/alien_join.model"]   = Frame(-0.708, 0.243, 0.689, 0.538, 0.101),
        ["models/props/generic/join_text_05.model"] = Frame(-0.708, 0.517, 0.689, 0.812, 0.417),
        ["models/props/generic/join_alien.model"]   = Frame(-1.415, 0.487, 1.333, 0.996, 0.116),
    },
}

-- prop coords * (VT sign frame -> vanilla model frame)
local function SignCoords(propCoords, frame)
    local s = frame.h / kVTSignFrame.h
    local fit = Coords.GetIdentity()
    fit.xAxis = Vector(s, 0, 0)
    fit.yAxis = Vector(0, s, 0)
    fit.zAxis = Vector(0, 0, s)
    fit.origin = Vector(frame.x - s * kVTSignFrame.x, frame.y - s * kVTSignFrame.y, frame.z - s * kVTSignFrame.z)
    return propCoords * fit
end

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
        voice       = rawget(_G, "GUIVoiceChat") and GUIVoiceChat.kMarineFontColor,
        unitStatus  = type(statusColors) == "table" and statusColors[kMarineTeamType] or nil,
        teamMessage = FindUpvalue(rawget(_G, "GUIMarineTeamMessage"), "kMessageFontColor"),
    }
end

local kVTColors =
{
    font = kVTFontColor, teamFloat = kVTTeamColorFloat,
    voice = kVTVoiceColor, unitStatus = kVTTeamColorFloat, teamMessage = kVTFontColor,
}

-- Scoreboard: vanilla colours the team-1 column GUIScoreboard.kBlueColor and the team-2 column kRedColor (by team
-- NUMBER; kRedColor is the shared global). The Vael'Thor team's column gets violet, the other one its vanilla
-- colour. The live scoreboard copies the colours into its items in Initialize, so it is rebuilt once whenever
-- kVTTeamIndex changes (vanilla does the same on a resolution change).
local kVTScoreboardHighlight = Color(0.82, 0.62, 1.00, 1)
local scoreboardVanilla, scoreboardState
local function ApplyScoreboardColors()
    local sb = rawget(_G, "GUIScoreboard")
    if not sb or scoreboardState == kVTTeamIndex then
        return
    end
    scoreboardVanilla = scoreboardVanilla or { sb.kBlueColor, sb.kBlueHighlightColor, sb.kRedColor, sb.kRedHighlightColor }
    scoreboardState = kVTTeamIndex
    local v = scoreboardVanilla
    sb.kBlueColor          = kVTTeamIndex == 1 and kVTTeamColorFloat or v[1]
    sb.kBlueHighlightColor = kVTTeamIndex == 1 and kVTScoreboardHighlight or v[2]
    sb.kRedColor           = kVTTeamIndex == 2 and kVTTeamColorFloat or v[3]
    sb.kRedHighlightColor  = kVTTeamIndex == 2 and kVTScoreboardHighlight or v[4]
    local script = ClientUI and ClientUI.GetScript and ClientUI.GetScript("GUIScoreboard")
    if script and script.teams and script.Uninitialize and script.Initialize then
        script:Uninitialize()
        script:Initialize()
    end
end

-- Ready room "N players" markers above the join doors (GUIReadyRoomOrders' file-local kTeamColors):
-- violet over the Vael'Thor team's door, vanilla over the other one, in every matchup.
local function ApplyReadyRoomColors()
    local colors = FindUpvalue(rawget(_G, "GUIReadyRoomOrders"), "kTeamColors")
    if type(colors) ~= "table" then
        return
    end
    for _, index in ipairs({ kTeam1Index, kTeam2Index }) do
        local key = "readyRoom" .. index
        if colors[index] then
            if not vanilla[key] then
                vanilla[key] = RGB(colors[index])
            end
            SetRGB(colors[index], index == kVTTeamIndex and RGB(kVTTeamColorFloat) or vanilla[key])
        end
    end
end

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

    ApplyReadyRoomColors()
    ApplyScoreboardColors()
    VT_ApplyJoinSigns(kVTTeamIndex ~= nil and kVTTeamIndex ~= kVTNoTeam and kVTTeamIndex or nil)

end

-- Swap the join sign props above the Vael'Thor team's door (vtTeam = kVTTeamIndex, or nil when the
-- Vael'Thor are not in the match) for the Vael'Thor sign. The prop list is only walked when the map's prop
-- list or vtTeam changed (both are checked every second from VT_ApplyPalette), but the hidden vanilla signs
-- are re-hidden every call: SetCommanderPropState(false) (Player_Client.lua, on every local player spawn)
-- makes every prop with commAlpha < 1 visible again.
local signList, signCount, signState
local hiddenSigns = {}
function VT_ApplyJoinSigns(vtTeam)
    local props = Client.propList
    if not props then
        return
    end
    if props ~= signList or #props ~= signCount or vtTeam ~= signState then
        signList, signCount, signState = props, #props, vtTeam
        hiddenSigns = {}
        local wanted = vtTeam and kJoinSignModels[vtTeam] or {}
        for _, propTable in ipairs(props) do
            local model = propTable[1]
            local name = model and model.model and string.lower(model.model)
            if name and (kJoinSignModels[1][name] or kJoinSignModels[2][name]) then
                local frame = wanted[name]
                if frame then
                    table.insert(hiddenSigns, model)
                    if not model.vtSign then
                        local sign = Client.CreateRenderModel(RenderScene.Zone_Default)
                        sign:SetModel(kJoinSignModel)
                        sign:SetCoords(SignCoords(model:GetCoords(), frame))
                        sign:SetIsStatic(true)
                        model.vtSign = sign
                        Shared.Message(string.format("[Vael'Thor] join sign replaced: %s at %s",
                                model.model, ToString(model:GetCoords().origin)))
                    end
                else
                    model:SetIsVisible(true)
                    if model.vtSign then
                        Client.DestroyRenderModel(model.vtSign)
                        model.vtSign = nil
                    end
                end
            end
        end
    end
    for _, model in ipairs(hiddenSigns) do
        model:SetIsVisible(false)
    end
end

-- Re-hide right after vanilla toggles prop visibility (no 1 s flash of "MARINES").
if Client and SetCommanderPropState and not VT_OrigSetCommanderPropState then
    VT_OrigSetCommanderPropState = SetCommanderPropState
    function SetCommanderPropState(isComm)
        VT_OrigSetCommanderPropState(isComm)
        VT_ApplyJoinSigns(signState)
    end
end

-- Is the local client on the Vael'Thor team (also while dead / spectating a teammate)?
function VT_GetLocalIsVT()
    return Client.GetLocalClientTeamNumber and kVTTeamIndex ~= nil and kVTTeamIndex ~= kVTNoTeam
            and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end
