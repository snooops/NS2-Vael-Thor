-- ============================================================================
-- Vael'Thor Empire - commander/HUD icons
-- (post-hook of lua/TechTreeButtons.lua)
--
-- Own icons: output/ui/buildmenu.dds is the vanilla atlas plus five rows of Vael'Thor icons from
-- row kVTFirstRow on (art/ui/commander/build_command_icons.sh; vanilla cells keep their pixel positions). kVTIconCells mirrors
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

    [kTechId.VTBuyInfiltrator]       = kTechId.Axe,
    [kTechId.VTBuySubject]           = kTechId.Marine,
    [kTechId.VTBuyPraetor]           = kTechId.Exo,

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

-- First Vael'Thor row = vanilla atlas row count (16 before the 2026-11-17 game update, 18 since). Must match
-- the atlas built by art/ui/commander/build_command_icons.sh (it prints the vanilla row count).
local kVTFirstRow = 18

-- tech id name -> { column, row } in the extended atlas (generated: art/ui/commander/vaelthor_buildmenu_cells.txt)
local kVTIconCellList =
{
    { "VTNexus", 0, kVTFirstRow + 0 },
    { "VTSiphon", 1, kVTFirstRow + 0 },
    { "VTSubventionPylon", 2, kVTFirstRow + 0 },
    { "VTSynthesisChamber", 3, kVTFirstRow + 0 },
    { "VTShieldGenerator", 4, kVTFirstRow + 0 },
    { "VTSentinelObelisk", 5, kVTFirstRow + 0 },
    { "VTPsionicSpire", 7, kVTFirstRow + 0 },
    { "VTNexusGate", 8, kVTFirstRow + 0 },
    { "VTNexusGateUpgrade", 9, kVTFirstRow + 0 },
    { "VTResonantPylonUpgrade", 10, kVTFirstRow + 0 },
    { "VTAegisArrayUpgrade", 11, kVTFirstRow + 0 },
    { "VTVanguard", 0, kVTFirstRow + 1 },
    { "VTInfiltrator", 1, kVTFirstRow + 1 },
    { "VTSubject", 2, kVTFirstRow + 1 },
    { "VTPraetor", 3, kVTFirstRow + 1 },
    { "VTQuotaMenu", 4, kVTFirstRow + 1 },
    { "VTBuyInfiltrator", 5, kVTFirstRow + 1 },   -- the old "quota +1" icons
    { "VTBuySubject", 7, kVTFirstRow + 1 },
    { "VTBuyPraetor", 9, kVTFirstRow + 1 },
    { "VTArchonsThrone", 11, kVTFirstRow + 1 },
    { "VTEdictRequisition", 0, kVTFirstRow + 2 },
    { "VTEdictRelentless", 1, kVTFirstRow + 2 },
    { "VTEdictIronDiscipline", 2, kVTFirstRow + 2 },
    { "VTShieldPulse", 3, kVTFirstRow + 2 },
    { "VTNexusRecall", 8, kVTFirstRow + 0 },   -- Nexus Gate icon (cell 4,18 is the old rift-themed recall icon)
    { "VTAuthorizationTier2", 5, kVTFirstRow + 2 },
    { "VTAuthorizationTier3", 6, kVTFirstRow + 2 },
    { "VTOverchargeTech", 7, kVTFirstRow + 2 },
    { "VTSingularityTech", 8, kVTFirstRow + 2 },
    { "VTPhaseDashTech", 9, kVTFirstRow + 2 },
    { "VTShieldOverdriveTech", 10, kVTFirstRow + 2 },
    { "VTTargetingVisorTech", 11, kVTFirstRow + 2 },
    { "VTPhaseCloakTech", 0, kVTFirstRow + 3 },
    { "VTNeuralOverrideTech", 1, kVTFirstRow + 3 },
    { "VTPsionicEdictsTech", 2, kVTFirstRow + 3 },
    { "VTPlasmaCarbine", 9, kVTFirstRow + 3 },
    { "VTPsionicBlade", 10, kVTFirstRow + 3 },
    { "VTSubjectClaws", 11, kVTFirstRow + 3 },
    { "VTPsionicKnife", 0, kVTFirstRow + 4 },
    { "VTSingularityLauncher", 1, kVTFirstRow + 4 },
    { "VTEchoPulse", 2, kVTFirstRow + 4 },
    { "VTObeliskPrismUpgrade", 3, kVTFirstRow + 4 },
    { "VTObeliskTrinityUpgrade", 4, kVTFirstRow + 4 },
    { "VTObeliskFocus", 5, kVTFirstRow + 4 },
    { "VTObeliskBeams1", 6, kVTFirstRow + 4 },
    { "VTObeliskBeams2", 7, kVTFirstRow + 4 },
    { "VTObeliskBeams3", 8, kVTFirstRow + 4 },
}

-- Plasma Calibration / Shield Matrix (own tech ids) use the cells drawn for them
for i, name in ipairs({ "VTPlasmaCalibration1", "VTPlasmaCalibration2", "VTPlasmaCalibration3",
                        "VTShieldMatrix1", "VTShieldMatrix2", "VTShieldMatrix3" }) do
    kVTIconCellList[#kVTIconCellList + 1] = { name, i + 2, kVTFirstRow + 3 }
end

-- vanilla tech shown with a different icon to Vael'Thor viewers only (none at the moment)
local kVTViewerIconCellList =
{
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
