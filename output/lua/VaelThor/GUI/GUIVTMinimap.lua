-- ============================================================================
-- Vael'Thor icons and colours on the map (C) and the commander minimap (vanilla GUIMinimap / MapBlip).
--
-- The networked blip types stay vanilla (CommandStation, Extractor, Marine, ...): alien bots choose and rank
-- their targets by blip type, so new types would blind them. Instead, blips of the Vael'Thor team
-- (kVTTeamIndex) of the types the castes/structures reuse are drawn with the Vael'Thor icons from
-- ui/vaelthor/minimap_blip.dds (art/ui/minimap/build_minimap_atlas.sh: the vanilla atlas plus two rows of
-- Vael'Thor icons, so every other icon keeps its vanilla cell), and that team's blip colours are violet.
-- Vanilla picks a blip's minimap team from its team NUMBER (MapBlip:UpdateMapBlipTeam: 1 -> Marine*, 2 ->
-- Alien*), so the Vael'Thor's blip teams are the Marine* ones in Vael'Thor vs. Aliens and the Alien* ones in
-- Marines vs. Vael'Thor (there are no real aliens then). Everything follows kVTTeamIndex and is undone when it
-- changes: clients start with the default matchup and get the real one (VTMatchup message) a moment later.
-- Applied lazily (GUIMinimap / MapBlip client code load late): VT_InstallMinimapLook from Client.lua.
-- ============================================================================

local kVTAtlas = PrecacheAsset("ui/vaelthor/minimap_blip.dds")
local kIconSize = 32

-- vanilla blip type -> { column, row } in the Vael'Thor atlas (1-based like GUIGetSprite)
local kVTIconCells = {}
local function Cell(typeName, col, row)
    local blipType = rawget(kMinimapBlipType, typeName)
    if blipType then
        kVTIconCells[blipType] = { GUIGetSprite(col, row, kIconSize, kIconSize) }
    end
end
Cell("CommandStation", 1, 9)    -- Imperial Nexus
Cell("Extractor",      2, 9)    -- Resource Siphon
Cell("SentryBattery",  3, 9)    -- Subvention Pylon
Cell("ArmsLab",        4, 9)    -- Synthesis Chamber
Cell("Observatory",    5, 9)    -- Shield Generator
Cell("Sentry",         6, 9)    -- Sentinel Obelisk
Cell("PhaseGate",      7, 9)
Cell("PrototypeLab",   8, 9)    -- Psionic Spire
Cell("Marine",         1, 10)   -- soldier (Vanguard / Infiltrator / Subject share the Marine blip type)
Cell("JetpackMarine",  1, 10)
Cell("Exo",            4, 10)   -- Praetor

-- own arrow icon by caste (the local player's class is always known)
local kVTOwnIconCells =
{
    VTVanguard    = { GUIGetSprite(1, 10, kIconSize, kIconSize) },
    VTInfiltrator = { GUIGetSprite(2, 10, kIconSize, kIconSize) },
    VTSubject     = { GUIGetSprite(3, 10, kIconSize, kIconSize) },
    VTPraetor     = { GUIGetSprite(4, 10, kIconSize, kIconSize) },
}

-- the Vael'Thor team's blip colours (vanilla: cyan / orange shades)
local kVTTeamColors =
{
    Active   = Color(0.76, 0.46, 1.00, 1),
    Friend   = Color(0.90, 0.76, 1.00, 1),   -- Steam friends
    Inactive = Color(0.26, 0.14, 0.36, 1),   -- unbuilt / unpowered
}
local kBlipTeamNames =
{
    [1] = { Active = "Marine", Friend = "FriendMarine", Inactive = "InactiveMarine" },
    [2] = { Active = "Alien",  Friend = "FriendAlien",  Inactive = "InactiveAlien" },
}
local kVTPlayerColor = Color(0.84, 0.58, 1.00, 1)
local kTeamColorIndex = 1           -- kBlipColorType.Team (file-local enum in GUIMinimap.lua, 'Team' is first)

local function VTActive()
    return kVTTeamIndex ~= nil and kBlipTeamNames[kVTTeamIndex] ~= nil
end

-- the Vael'Thor's minimap blip teams for the current kVTTeamIndex: { [blipTeam] = "Active"|"Friend"|"Inactive" }
local vtBlipTeams, vtBlipTeamsFor
local function VTBlipTeams()
    if vtBlipTeamsFor ~= kVTTeamIndex or not vtBlipTeams then
        vtBlipTeamsFor, vtBlipTeams = kVTTeamIndex, {}
        for role, name in pairs(kBlipTeamNames[kVTTeamIndex] or {}) do
            vtBlipTeams[kMinimapBlipTeam[name]] = role
        end
    end
    return vtBlipTeams
end

local function IsVTBlipTeam(blipTeam)
    return VTBlipTeams()[blipTeam] ~= nil
end

-- Team colours of this minimap for the current kVTTeamIndex: vanilla colours are restored first, so a matchup
-- change (or the default matchup a client starts with) leaves nothing behind. Returns true if anything changed.
local function ApplyColors(self)
    if not self.blipColorTable or self.vtColorState == kVTTeamIndex then
        return false
    end
    self.vtColorState = kVTTeamIndex
    self.vtOriginalColors = self.vtOriginalColors or {}
    for _, names in pairs(kBlipTeamNames) do
        for _, name in pairs(names) do
            local colors = self.blipColorTable[kMinimapBlipTeam[name]]
            if colors then
                if self.vtOriginalColors[name] == nil then
                    self.vtOriginalColors[name] = colors[kTeamColorIndex]
                end
                colors[kTeamColorIndex] = self.vtOriginalColors[name]
            end
        end
    end
    for blipTeam, role in pairs(VTBlipTeams()) do
        local colors = self.blipColorTable[blipTeam]
        if colors then
            colors[kTeamColorIndex] = kVTTeamColors[role]
        end
    end
    return true
end

local function ApplyVTIcon(self, item)
    local cell = kVTIconCells[item.blipType]
    if cell and IsVTBlipTeam(item.blipTeam) then
        VT_Breadcrumb("minimap_icon", "map look: first Vael'Thor map icon")
        item:SetTexture(kVTAtlas)
        item:SetTexturePixelCoordinates(unpack(cell))
        item.vtIcon = true
    else
        item.vtIcon = nil
    end
end

-- Wrapped per class: the map (C) and the commander minimap are GUIMinimapFrame (a GUIMinimap subclass), and
-- map blips initialise their icons through the instance (MinimapMappableMixin: minimap:InitMinimapIcon), so
-- wrapping only GUIMinimap never reached them. A method a subclass merely inherits from an already wrapped
-- class is recognised (kOurWrappers) and not wrapped twice.
local kOurWrappers = {}
local kWrappedClasses = {}

local function WrapMethod(cls, name, makeWrapper)
    local base = cls[name]
    if not base or kOurWrappers[base] then
        return
    end
    local wrapper = makeWrapper(base)
    kOurWrappers[wrapper] = true
    cls[name] = wrapper
end

local function WrapMinimapClass(cls)
    if not cls or kWrappedClasses[cls] then
        return
    end
    kWrappedClasses[cls] = true

    WrapMethod(cls, "InitMinimapIcon", function(base)
        return function(self, item, blipType, blipTeam)
            ApplyColors(self)
            local result = base(self, item, blipType, blipTeam)
            if VTActive() then
                ApplyVTIcon(self, item)
            elseif item.vtIcon then
                item.vtIcon = nil
                item:SetTexture(self.iconFileName)     -- vanilla set the cell; give the vanilla atlas back
            end
            return result
        end
    end)

    -- switching atlases (zoom / big map) re-textures every icon: put the Vael'Thor atlas back on ours
    WrapMethod(cls, "SetIconFileName", function(base)
        return function(self, fileName)
            base(self, fileName)
            if VTActive() and self.iconMap then
                for _, icon in self.iconMap:Iterate() do
                    if icon.vtIcon then
                        icon:SetTexture(kVTAtlas)
                    end
                end
            end
            self.vtOwnIcon = nil
        end
    end)

    -- the local player's own icon: caste icon from the Vael'Thor atlas
    WrapMethod(cls, "UpdatePlayerIcon", function(base)
        return function(self)
            base(self)
            local player = Client.GetLocalPlayer()
            local cell = player and VTActive() and kVTOwnIconCells[player:GetClassName()]
            if cell then
                if self.vtOwnIcon ~= player:GetClassName() then
                    self.playerIcon:SetTexture(kVTAtlas)
                    self.playerIcon:SetTexturePixelCoordinates(unpack(cell))
                    self.vtOwnIcon = player:GetClassName()
                end
            elseif self.vtOwnIcon then
                self.playerIcon:SetTexture(self.iconFileName)
                self.vtOwnIcon = nil
                self.playerClass = nil      -- let vanilla re-apply its own cell
            end
        end
    end)

    -- instances (and their icons) created before the wrapping or before the matchup arrived: re-initialise
    -- every icon whenever the Vael'Thor team changes
    WrapMethod(cls, "Update", function(base)
        return function(self, deltaTime)
            if self.ResetAll and ApplyColors(self) and (VTActive() or self.vtLookReset) then
                VT_Breadcrumb("minimap_reset", "map look: resetting map icons")
                self.vtLookReset = true
                self:ResetAll()
            end
            return base(self, deltaTime)
        end
    end)
end

local function WrapMinimap()
    WrapMinimapClass(GUIMinimap)
    WrapMinimapClass(GUIMinimapFrame)
end

-- MapBlip forces a custom (cyan by default) colour onto Marine / Jetpack / Exo player blips; structures
-- already get the violet team colour (and keep vanilla's red under-attack pulse) through blipColorTable.
local kPlayerBlipTypes = {}
local function IsPlayerBlipType(blipType)
    if not next(kPlayerBlipTypes) then
        kPlayerBlipTypes[kMinimapBlipType.Marine] = true
        kPlayerBlipTypes[kMinimapBlipType.JetpackMarine] = true
        kPlayerBlipTypes[kMinimapBlipType.Exo] = true
    end
    return kPlayerBlipTypes[blipType]
end

local function WrapMapBlip()
    if not MapBlip or not MapBlip.GetMapBlipColor or VT_WrappedMapBlipColor then
        return
    end
    VT_WrappedMapBlipColor = true
    local base = MapBlip.GetMapBlipColor
    function MapBlip:GetMapBlipColor(minimap, item)
        local color = base(self, minimap, item)
        if VTActive() and self:GetTeamNumber() == kVTTeamIndex and IsPlayerBlipType(self.mapBlipType) then
            if VTBlipTeams()[self:GetMapBlipTeam(minimap)] == "Inactive" then
                return kVTTeamColors.Inactive
            end
            return self.highlighted and color or kVTPlayerColor
        end
        return color
    end
end

function VT_InstallMinimapLook()
    WrapMinimap()
    WrapMapBlip()
end
