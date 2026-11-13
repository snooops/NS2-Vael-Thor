-- ============================================================================
-- Vael'Thor icons and colours on the map (C) and the commander minimap (vanilla GUIMinimap / MapBlip).
--
-- The networked blip types stay vanilla (CommandStation, Extractor, Marine, ...): alien bots choose and rank
-- their targets by blip type, so new types would blind them. Instead, while the Vael'Thor are active, team 1
-- *is* the Vael'Thor, and team-1 blips of the types the castes/structures reuse are drawn with the Vael'Thor
-- icons from ui/vaelthor/minimap_blip.dds (art/ui/minimap/build_minimap_atlas.sh: the vanilla atlas plus two
-- rows of Vael'Thor icons, so every other icon keeps its vanilla cell). Team-1 blip colours are violet.
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

-- team-1 blip colours while the Vael'Thor are active (vanilla: cyan shades)
local kVTTeamColors =
{
    Marine         = Color(0.76, 0.46, 1.00, 1),
    FriendMarine   = Color(0.90, 0.76, 1.00, 1),   -- Steam friends
    InactiveMarine = Color(0.26, 0.14, 0.36, 1),   -- unbuilt / unpowered
}
local kVTPlayerColor = Color(0.84, 0.58, 1.00, 1)
local kTeamColorIndex = 1           -- kBlipColorType.Team (file-local enum in GUIMinimap.lua, 'Team' is first)

local function VTActive()
    return kVTTeamIndex ~= nil and kVTTeamIndex ~= kVTNoTeam and kVTTeamIndex == kTeam1Index
end

local kVTBlipTeams = {}
local function IsVTBlipTeam(blipTeam)
    if not next(kVTBlipTeams) then
        kVTBlipTeams[kMinimapBlipTeam.Marine] = true
        kVTBlipTeams[kMinimapBlipTeam.FriendMarine] = true
        kVTBlipTeams[kMinimapBlipTeam.InactiveMarine] = true
    end
    return kVTBlipTeams[blipTeam]
end

local function ApplyColors(self)
    if self.vtColorsApplied or not self.blipColorTable then
        return
    end
    self.vtColorsApplied = true
    for teamName, color in pairs(kVTTeamColors) do
        local colors = self.blipColorTable[kMinimapBlipTeam[teamName]]
        if colors then
            colors[kTeamColorIndex] = color
        end
    end
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
            if VTActive() then
                ApplyColors(self)
            end
            local result = base(self, item, blipType, blipTeam)
            if VTActive() then
                ApplyVTIcon(self, item)
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

    -- instances (and their icons) created before the wrapping: re-initialise every icon once
    WrapMethod(cls, "Update", function(base)
        return function(self, deltaTime)
            if VTActive() and not self.vtLookReset and self.ResetAll then
                VT_Breadcrumb("minimap_reset", "map look: resetting map icons")
                self.vtLookReset = true
                ApplyColors(self)
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
            local blipTeam = self:GetMapBlipTeam(minimap)
            if blipTeam == kMinimapBlipTeam.InactiveMarine then
                return kVTTeamColors.InactiveMarine
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
