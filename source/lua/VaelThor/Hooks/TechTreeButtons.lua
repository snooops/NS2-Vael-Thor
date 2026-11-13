-- ============================================================================
-- Vael'Thor Empire - commander/HUD icons
-- (post-hook of lua/TechTreeButtons.lua)
--
-- Own icons: output/ui/buildmenu.dds is the vanilla atlas plus five rows of Vael'Thor icons
-- (art/ui/commander/build_command_icons.sh; vanilla cells keep their pixel positions). kVTIconCells mirrors
-- the generator's ICONS order (column, row). kVTIconAlias stays as the fallback for tech without an icon.
-- ============================================================================

local kVTIconAlias =
{
    [kTechId.VTVanguard]             = kTechId.Marine,
    [kTechId.VTInfiltrator]          = kTechId.Marine,
    [kTechId.VTSubject]              = kTechId.Marine,
    [kTechId.VTPraetor]              = kTechId.Exo,

    [kTechId.VTNexus]                = kTechId.CommandStation,
    [kTechId.VTSiphon]               = kTechId.Extractor,
    [kTechId.VTSubventionPylon]      = kTechId.SentryBattery,
    [kTechId.VTSynthesisChamber]     = kTechId.ArmsLab,
    [kTechId.VTShieldGenerator]      = kTechId.Observatory,

    [kTechId.VTEdictRequisition]     = kTechId.PowerSurge,
    [kTechId.VTEdictRelentless]      = kTechId.CatPack,

    [kTechId.VTQuotaInfiltratorUp]   = kTechId.Axe,
    [kTechId.VTQuotaInfiltratorDown] = kTechId.Axe,
    [kTechId.VTQuotaSubjectUp]       = kTechId.Marine,
    [kTechId.VTQuotaSubjectDown]     = kTechId.Marine,
    [kTechId.VTQuotaPraetorUp]       = kTechId.Exo,
    [kTechId.VTQuotaPraetorDown]     = kTechId.Exo,

    [kTechId.VTAuthorizationTier2]   = kTechId.AdvancedArmoryUpgrade,
    [kTechId.VTAuthorizationTier3]   = kTechId.ExosuitTech,
    [kTechId.VTOverchargeTech]       = kTechId.Weapons2,
    [kTechId.VTSingularityTech]      = kTechId.GrenadeLauncher,
    [kTechId.VTPhaseDashTech]        = kTechId.PhaseTech,
    [kTechId.VTShieldOverdriveTech]  = kTechId.NanoShield,

    [kTechId.VTPlasmaCarbine]        = kTechId.Rifle,
    [kTechId.VTPsionicBlade]         = kTechId.Axe,
    [kTechId.VTSubjectClaws]         = kTechId.Axe,
    [kTechId.VTPsionicKnife]         = kTechId.Axe,
    [kTechId.VTSingularityLauncher]  = kTechId.GrenadeLauncher,
    [kTechId.VTEchoPulse]            = kTechId.Welder,
    [kTechId.VTTargetingVisorTech]   = kTechId.Scan,

    [kTechId.VTSentinelObelisk]      = kTechId.Sentry,
    [kTechId.VTPsionicSpire]         = kTechId.PrototypeLab,
    [kTechId.VTResonantPylonUpgrade] = kTechId.SentryBattery,
    [kTechId.VTAegisArrayUpgrade]    = kTechId.Armor3,
    [kTechId.VTArchonsThrone]        = kTechId.CommandStation,
    [kTechId.VTPhaseCloakTech]       = kTechId.PhaseTech,
    [kTechId.VTNeuralOverrideTech]   = kTechId.MACEMP,
    [kTechId.VTPsionicEdictsTech]    = kTechId.AdvancedWeaponry,
    [kTechId.VTEdictIronDiscipline]  = kTechId.NanoShield,
    [kTechId.VTQuotaMenu]            = kTechId.Marine,
    [kTechId.VTShieldPulse]          = kTechId.NanoShield,
    [kTechId.VTNexusRecall]          = kTechId.PhaseGate,
    [kTechId.VTNexusGate]            = kTechId.CommandStation,
    [kTechId.VTNexusGateUpgrade]     = kTechId.PhaseTech,
    [kTechId.VTObeliskPrismUpgrade]  = kTechId.Weapons2,
    [kTechId.VTObeliskTrinityUpgrade]= kTechId.Weapons3,
    [kTechId.VTObeliskFocus]         = kTechId.Attack,
    [kTechId.VTObeliskBeams1]        = kTechId.Sentry,
    [kTechId.VTObeliskBeams2]        = kTechId.Sentry,
    [kTechId.VTObeliskBeams3]        = kTechId.Sentry,
}

-- tech id name -> { column, row } in the extended atlas (generated: art/ui/commander/vaelthor_buildmenu_cells.txt)
local kVTIconCellList =
{
    { "VTNexus", 0, 16 },
    { "VTSiphon", 1, 16 },
    { "VTSubventionPylon", 2, 16 },
    { "VTSynthesisChamber", 3, 16 },
    { "VTShieldGenerator", 4, 16 },
    { "VTSentinelObelisk", 5, 16 },
    { "VTPsionicSpire", 7, 16 },
    { "VTNexusGate", 8, 16 },
    { "VTNexusGateUpgrade", 9, 16 },
    { "VTResonantPylonUpgrade", 10, 16 },
    { "VTAegisArrayUpgrade", 11, 16 },
    { "VTVanguard", 0, 17 },
    { "VTInfiltrator", 1, 17 },
    { "VTSubject", 2, 17 },
    { "VTPraetor", 3, 17 },
    { "VTQuotaMenu", 4, 17 },
    { "VTQuotaInfiltratorUp", 5, 17 },
    { "VTQuotaInfiltratorDown", 6, 17 },
    { "VTQuotaSubjectUp", 7, 17 },
    { "VTQuotaSubjectDown", 8, 17 },
    { "VTQuotaPraetorUp", 9, 17 },
    { "VTQuotaPraetorDown", 10, 17 },
    { "VTArchonsThrone", 11, 17 },
    { "VTEdictRequisition", 0, 18 },
    { "VTEdictRelentless", 1, 18 },
    { "VTEdictIronDiscipline", 2, 18 },
    { "VTShieldPulse", 3, 18 },
    { "VTNexusRecall", 8, 16 },   -- Nexus Gate icon (cell 4,18 is the old rift-themed recall icon)
    { "VTAuthorizationTier2", 5, 18 },
    { "VTAuthorizationTier3", 6, 18 },
    { "VTOverchargeTech", 7, 18 },
    { "VTSingularityTech", 8, 18 },
    { "VTPhaseDashTech", 9, 18 },
    { "VTShieldOverdriveTech", 10, 18 },
    { "VTTargetingVisorTech", 11, 18 },
    { "VTPhaseCloakTech", 0, 19 },
    { "VTNeuralOverrideTech", 1, 19 },
    { "VTPsionicEdictsTech", 2, 19 },
    { "VTPlasmaCarbine", 9, 19 },
    { "VTPsionicBlade", 10, 19 },
    { "VTSubjectClaws", 11, 19 },
    { "VTPsionicKnife", 0, 20 },
    { "VTSingularityLauncher", 1, 20 },
    { "VTEchoPulse", 2, 20 },
    { "VTObeliskPrismUpgrade", 3, 20 },
    { "VTObeliskTrinityUpgrade", 4, 20 },
    { "VTObeliskFocus", 5, 20 },
    { "VTObeliskBeams1", 6, 20 },
    { "VTObeliskBeams2", 7, 20 },
    { "VTObeliskBeams3", 8, 20 },
}

-- vanilla upgrades relabelled for Vael'Thor viewers (Plasma Calibration / Shield Matrix): own icons for them only
local kVTViewerIconCellList =
{
    { "Weapons1", 3, 19 },
    { "Weapons2", 4, 19 },
    { "Weapons3", 5, 19 },
    { "Armor1", 6, 19 },
    { "Armor2", 7, 19 },
    { "Armor3", 8, 19 },
}

local function BuildCells(list)
    local cells = {}
    for _, entry in ipairs(list) do
        local techId = rawget(kTechId, entry[1])
        if techId then
            cells[techId] = { entry[2], entry[3] }
        end
    end
    return cells
end

local kVTIconCells = BuildCells(kVTIconCellList)
local kVTViewerIconCells = BuildCells(kVTViewerIconCellList)

local function GetLocalIsVT()
    return Client and Client.GetLocalClientTeamNumber and kVTTeamIndex ~= kVTNoTeam
            and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end

if not VT_HookedTechTreeButtons then
VT_HookedTechTreeButtons = true

local oldGetMaterialXYOffset = GetMaterialXYOffset
function GetMaterialXYOffset(techId, ...)
    local cell = kVTIconCells[techId] or (kVTViewerIconCells[techId] and GetLocalIsVT() and kVTViewerIconCells[techId])
    if cell then
        return cell[1], cell[2]
    end
    return oldGetMaterialXYOffset(kVTIconAlias[techId] or techId, ...)
end

end -- VT_HookedTechTreeButtons
