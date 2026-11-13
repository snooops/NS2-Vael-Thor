-- ============================================================================
-- Vael'Thor Empire - tech data
-- (post-hook of lua/TechData.lua)
--
-- New entries are cloned from the marine entry they are prototyped on, so
-- every engine-required field (extents, ghost model class, damage type...)
-- is present, then overridden. Isolation: the clone source is the *vanilla*
-- marine entry (the frozen vanilla BuildTechData, run with the vanilla balance
-- values - Baseline/Freeze.lua), so mods changing marine tech data or balance
-- values don't leak into the Vael'Thor entries. Map names are literal strings because
-- BuildTechData() may run before the Vael'Thor classes are loaded.
-- ============================================================================

local REMOVE = {}

local function FindEntry(techData, techId)
    for i = 1, #techData do
        if techData[i][kTechDataId] == techId then
            return techData[i]
        end
    end
end

-- Vanilla tech data to clone from (nil without the baseline: then the live entries are used).
local cloneSource

local function BuildVanillaTechData()
    local build = VTBaseline and VTBaseline.functions and VTBaseline.functions.BuildTechData
    if not (build and VTFreeze) then
        return nil
    end
    local ok, data = pcall(VTFreeze.Clone(build))
    if not ok then
        Print("[Vael'Thor] Warning: vanilla tech data failed (%s); cloning from live entries", tostring(data))
        return nil
    end
    return data
end

local function Clone(techData, baseTechId, overrides)
    local base = FindEntry(cloneSource or techData, baseTechId) or FindEntry(techData, baseTechId)
    local entry = {}
    if base then
        for k, v in pairs(base) do entry[k] = v end
    else
        Print("[Vael'Thor] Warning: tech data base entry %s missing", EnumToString(kTechId, baseTechId))
    end
    for k, v in pairs(overrides) do
        if v == REMOVE then entry[k] = nil else entry[k] = v end
    end
    techData[#techData + 1] = entry
end

local function Add(techData, entry)
    techData[#techData + 1] = entry
end

if not VT_HookedTechData then
VT_HookedTechData = true

local oldBuildTechData = BuildTechData
function BuildTechData()

    local techData = oldBuildTechData()
    cloneSource = BuildVanillaTechData()

    -- Imperial Nexus: own tech id + class (VTNexus, a CommandStation subclass) so
    -- vanilla marines in the same match keep the normal Command Station.
    Clone(techData, kTechId.CommandStation, {
        [kTechDataId] = kTechId.VTNexus,
        [kTechDataMapName] = kVTMapNames.Nexus,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/nexus/nexus.model"),   -- commander ghost
        [kTechDataDisplayName] = "VT_NEXUS",
        [kTechDataTooltipInfo] = "VT_NEXUS_TOOLTIP",
        [kTechDataHint] = "VT_NEXUS_TOOLTIP",
        [kVisualRange] = kVTFieldRadiusNexus,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
        -- Free placement: may snap onto a free tech point, but doesn't have to.
        [kTechDataAttachOptional] = true,
        [kTechDataCostKey] = kVTNexusCost,
    })

    -- Upgraded Nexus. Same class and map name; only the tech id changes.
    Clone(techData, kTechId.CommandStation, {
        [kTechDataId] = kTechId.VTNexusGate,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/nexus/nexus.model"),
        [kTechDataMapName] = kVTMapNames.Nexus,
        [kTechDataUpgradeTech] = kTechId.VTNexus,   -- still counts as a Nexus
        [kTechDataDisplayName] = "VT_NEXUS_GATE",
        [kTechDataTooltipInfo] = "VT_NEXUS_GATE_TOOLTIP",
        [kTechDataHint] = "VT_NEXUS_GATE_TOOLTIP",
        [kVisualRange] = kVTFieldRadiusNexus,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
        [kTechDataAttachOptional] = true,
        [kTechDataCostKey] = kVTNexusCost,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTNexusGateUpgrade,
        [kTechDataDisplayName] = "VT_NEXUS_GATE_UPGRADE",
        [kTechDataResearchName] = "VT_NEXUS_GATE_UPGRADE",
        [kTechDataTooltipInfo] = "VT_NEXUS_GATE_TOOLTIP",
        [kTechDataCostKey] = kVTNexusGateCost,
        [kTechDataResearchTimeKey] = kVTNexusGateTime,
    })

    -- Resource Siphon (VTSiphon, an Extractor subclass): powered by the
    -- Subvention field, not by the room's power node, so it shows field guides
    -- instead of the marine room-power indicator.
    Clone(techData, kTechId.Extractor, {
        [kTechDataId] = kTechId.VTSiphon,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/siphon/siphon.model"),   -- commander ghost
        [kTechDataMapName] = kVTMapNames.Siphon,
        [kTechDataDisplayName] = "VT_SIPHON",
        [kTechDataTooltipInfo] = "VT_SIPHON_TOOLTIP",
        [kTechDataHint] = "VT_SIPHON_TOOLTIP",
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
    })

    -- ------------------------------------------------------------------ castes
    Clone(techData, kTechId.Marine, {
        [kTechDataId] = kTechId.VTVanguard,
        [kTechDataMapName] = kVTMapNames.Vanguard,
        [kTechDataDisplayName] = "VT_VANGUARD",
        [kTechDataTooltipInfo] = "VT_VANGUARD_TOOLTIP",
        [kTechDataMaxHealth] = kVTVanguardHealth,
    })

    Clone(techData, kTechId.Marine, {
        [kTechDataId] = kTechId.VTInfiltrator,
        [kTechDataMapName] = kVTMapNames.Infiltrator,
        [kTechDataDisplayName] = "VT_INFILTRATOR",
        [kTechDataTooltipInfo] = "VT_INFILTRATOR_TOOLTIP",
        [kTechDataMaxHealth] = kVTInfiltratorHealth,
    })

    Clone(techData, kTechId.Marine, {
        [kTechDataId] = kTechId.VTSubject,
        [kTechDataMapName] = kVTMapNames.Subject,
        [kTechDataDisplayName] = "VT_SUBJECT",
        [kTechDataTooltipInfo] = "VT_SUBJECT_TOOLTIP",
        [kTechDataMaxHealth] = kVTSubjectHealth,
    })

    Clone(techData, kTechId.Exo, {
        [kTechDataId] = kTechId.VTPraetor,
        [kTechDataMapName] = kVTMapNames.Praetor,
        [kTechDataDisplayName] = "VT_PRAETOR",
        [kTechDataTooltipInfo] = "VT_PRAETOR_TOOLTIP",
        [kTechDataMaxHealth] = kVTPraetorHealth,
    })

    -- -------------------------------------------------------------- structures
    Clone(techData, kTechId.SentryBattery, {
        [kTechDataId] = kTechId.VTSubventionPylon,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/pylon/pylon.model"),   -- commander ghost
        [kTechDataMapName] = kVTMapNames.Pylon,
        [kTechDataDisplayName] = "VT_PYLON",
        [kTechDataTooltipInfo] = "VT_PYLON_TOOLTIP",
        [kTechDataHint] = "VT_PYLON_TOOLTIP",
        [kTechDataCostKey] = kVTPylonCost,
        [kTechDataBuildTime] = kVTPylonBuildTime,
        [kTechDataMaxHealth] = kVTPylonHealth,
        [kTechDataMaxArmor] = kVTPylonArmor,
        [kTechDataHotkey] = Move.P,
        [kVisualRange] = kVTFieldRadiusPylon,
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
        [kTechDataSupply] = REMOVE,
        [kTechDataBuildRequiresMethod] = REMOVE,
        [kTechDataBuildMethodFailedMessage] = REMOVE,
    })

    Clone(techData, kTechId.ArmsLab, {
        [kTechDataId] = kTechId.VTSynthesisChamber,
        [kTechDataMapName] = kVTMapNames.Chamber,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/chamber/chamber.model"),   -- commander ghost
        [kTechDataDisplayName] = "VT_CHAMBER",
        [kTechDataTooltipInfo] = "VT_CHAMBER_TOOLTIP",
        [kTechDataHint] = "VT_CHAMBER_TOOLTIP",
        [kTechDataCostKey] = kVTChamberCost,
        [kTechDataBuildTime] = kVTChamberBuildTime,
        [kTechDataMaxHealth] = kVTChamberHealth,
        [kTechDataMaxArmor] = kVTChamberArmor,
        [kTechDataHotkey] = Move.S,
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
    })

    Clone(techData, kTechId.Observatory, {
        [kTechDataId] = kTechId.VTShieldGenerator,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/shieldgen/shieldgen.model"),   -- commander ghost
        [kTechDataMapName] = kVTMapNames.ShieldGen,
        [kTechDataDisplayName] = "VT_SHIELDGEN",
        [kTechDataTooltipInfo] = "VT_SHIELDGEN_TOOLTIP",
        [kTechDataHint] = "VT_SHIELDGEN_TOOLTIP",
        [kTechDataCostKey] = kVTShieldGenCost,
        [kTechDataBuildTime] = kVTShieldGenBuildTime,
        [kTechDataMaxHealth] = kVTShieldGenHealth,
        [kTechDataMaxArmor] = kVTShieldGenArmor,
        [kTechDataHotkey] = Move.G,
        [kVisualRange] = kVTShieldGenRadius,
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
        [kTechDataSupply] = REMOVE,
        [kTechDataShowBeaconToLocation] = REMOVE,
    })

    Clone(techData, kTechId.Sentry, {
        [kTechDataId] = kTechId.VTSentinelObelisk,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/obelisk/obelisk.model"),   -- commander ghost
        [kTechDataMapName] = kVTMapNames.Obelisk,
        [kTechDataDisplayName] = "VT_OBELISK",
        [kTechDataTooltipInfo] = "VT_OBELISK_TOOLTIP",
        [kTechDataHint] = "VT_OBELISK_TOOLTIP",
        [kTechDataCostKey] = kVTObeliskCost,
        [kTechDataBuildTime] = kVTObeliskBuildTime,
        [kTechDataMaxHealth] = kVTObeliskHealth,
        [kTechDataMaxArmor] = kVTObeliskArmor,
        [kTechDataDamageType] = kDamageType.Normal,
        [kTechDataHotkey] = Move.O,
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
        [kStructureBuildNearClass] = REMOVE,
        [kStructureAttachRange] = REMOVE,
        [kTechDataBuildRequiresMethod] = REMOVE,
        [kTechDataBuildMethodFailedMessage] = REMOVE,
    })

    Clone(techData, kTechId.PrototypeLab, {
        [kTechDataId] = kTechId.VTPsionicSpire,
        [kTechDataMapName] = kVTMapNames.Spire,
        [kTechDataModel] = PrecacheAsset("models/vaelthor/spire/spire.model"),   -- commander ghost
        [kTechDataDisplayName] = "VT_SPIRE",
        [kTechDataTooltipInfo] = "VT_SPIRE_TOOLTIP",
        [kTechDataHint] = "VT_SPIRE_TOOLTIP",
        [kTechDataCostKey] = kVTSpireCost,
        [kTechDataBuildTime] = kVTSpireBuildTime,
        [kTechDataMaxHealth] = kVTSpireHealth,
        [kTechDataMaxArmor] = kVTSpireArmor,
        [kTechDataHotkey] = Move.I,
        [kTechDataRequiresPower] = false,
        [kTechDataGhostGuidesMethod] = VT_GetSubventionFieldGuides,
    })

    -- ------------------------------------------------- per-structure upgrades
    Add(techData, {
        [kTechDataId] = kTechId.VTResonantPylonUpgrade,
        [kTechDataDisplayName] = "VT_RESONANT_PYLON",
        [kTechDataResearchName] = "VT_RESONANT_PYLON",
        [kTechDataTooltipInfo] = "VT_RESONANT_PYLON_TOOLTIP",
        [kTechDataCostKey] = kVTResonantPylonCost,
        [kTechDataResearchTimeKey] = kVTResonantPylonTime,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTAegisArrayUpgrade,
        [kTechDataDisplayName] = "VT_AEGIS_ARRAY",
        [kTechDataResearchName] = "VT_AEGIS_ARRAY",
        [kTechDataTooltipInfo] = "VT_AEGIS_ARRAY_TOOLTIP",
        [kTechDataCostKey] = kVTAegisArrayCost,
        [kTechDataResearchTimeKey] = kVTAegisArrayTime,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskPrismUpgrade,
        [kTechDataDisplayName] = "VT_OBELISK_PRISM",
        [kTechDataResearchName] = "VT_OBELISK_PRISM",
        [kTechDataTooltipInfo] = "VT_OBELISK_PRISM_TOOLTIP",
        [kTechDataCostKey] = kVTObeliskPrismCost,
        [kTechDataResearchTimeKey] = kVTObeliskPrismTime,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskTrinityUpgrade,
        [kTechDataDisplayName] = "VT_OBELISK_TRINITY",
        [kTechDataResearchName] = "VT_OBELISK_TRINITY",
        [kTechDataTooltipInfo] = "VT_OBELISK_TRINITY_TOOLTIP",
        [kTechDataCostKey] = kVTObeliskTrinityCost,
        [kTechDataResearchTimeKey] = kVTObeliskTrinityTime,
    })

    -- ------------------------------------------- Sentinel Obelisk beam controls
    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskFocus,
        [kTechDataDisplayName] = "VT_OBELISK_FOCUS",
        [kTechDataTooltipInfo] = "VT_OBELISK_FOCUS_TOOLTIP",
        [kTechDataCostKey] = 0,
        [kTechDataHotkey] = Move.F,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskBeams1,
        [kTechDataDisplayName] = "VT_OBELISK_BEAMS1",
        [kTechDataTooltipInfo] = "VT_OBELISK_BEAMS1_TOOLTIP",
        [kTechDataCostKey] = 0,
        [kTechDataHotkey] = Move.Z,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskBeams2,
        [kTechDataDisplayName] = "VT_OBELISK_BEAMS2",
        [kTechDataTooltipInfo] = "VT_OBELISK_BEAMS2_TOOLTIP",
        [kTechDataCostKey] = 0,
        [kTechDataHotkey] = Move.X,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTObeliskBeams3,
        [kTechDataDisplayName] = "VT_OBELISK_BEAMS3",
        [kTechDataTooltipInfo] = "VT_OBELISK_BEAMS3_TOOLTIP",
        [kTechDataCostKey] = 0,
        [kTechDataHotkey] = Move.C,
    })

    -- --------------------------------------------- commander support abilities
    Add(techData, {
        [kTechDataId] = kTechId.VTShieldPulse,
        [kTechDataDisplayName] = "VT_SHIELD_PULSE",
        [kTechDataTooltipInfo] = "VT_SHIELD_PULSE_TOOLTIP",
        [kTechDataCostKey] = kVTShieldPulseCost,
        [kTechDataCooldown] = kVTShieldPulseCooldown,
        [kVisualRange] = kVTShieldPulseRadius,
        [kTechDataHotkey] = Move.S,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTNexusRecall,
        [kTechDataDisplayName] = "VT_NEXUS_RECALL",
        [kTechDataTooltipInfo] = "VT_NEXUS_RECALL_TOOLTIP",
        [kTechDataCostKey] = kVTNexusRecallCost,
        [kTechDataCooldown] = kVTNexusRecallCooldown,
        [kTechDataHotkey] = Move.R,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTQuotaMenu,
        [kTechDataDisplayName] = "VT_QUOTA_MENU",
        [kTechDataTooltipInfo] = "VT_QUOTA_TOOLTIP",
        [kTechDataHotkey] = Move.C,
    })

    -- -------------------------------------------------------------- directives
    Add(techData, {
        [kTechDataId] = kTechId.VTEdictRequisition,
        [kTechDataDisplayName] = "VT_EDICT_REQUISITION",
        [kTechDataTooltipInfo] = "VT_EDICT_REQUISITION_TOOLTIP",
        [kTechDataCostKey] = kVTRequisitionCost,
        [kTechDataHotkey] = Move.Q,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTEdictRelentless,
        [kTechDataDisplayName] = "VT_EDICT_RELENTLESS",
        [kTechDataTooltipInfo] = "VT_EDICT_RELENTLESS_TOOLTIP",
        [kTechDataCostKey] = kVTRelentlessCost,
        [kTechDataHotkey] = Move.W,
    })

    Add(techData, {
        [kTechDataId] = kTechId.VTEdictIronDiscipline,
        [kTechDataDisplayName] = "VT_EDICT_IRON",
        [kTechDataTooltipInfo] = "VT_EDICT_IRON_TOOLTIP",
        [kTechDataCostKey] = kVTIronDisciplineCost,
        [kTechDataHotkey] = Move.E,
    })

    -- ------------------------------------------------------------------ quotas
    local quotaButtons =
    {
        { kTechId.VTQuotaInfiltratorUp,   "VT_QUOTA_INFILTRATOR_UP" },
        { kTechId.VTQuotaInfiltratorDown, "VT_QUOTA_INFILTRATOR_DOWN" },
        { kTechId.VTQuotaSubjectUp,       "VT_QUOTA_SUBJECT_UP" },
        { kTechId.VTQuotaSubjectDown,     "VT_QUOTA_SUBJECT_DOWN" },
        { kTechId.VTQuotaPraetorUp,       "VT_QUOTA_PRAETOR_UP" },
        { kTechId.VTQuotaPraetorDown,     "VT_QUOTA_PRAETOR_DOWN" },
    }
    for _, q in ipairs(quotaButtons) do
        Add(techData, {
            [kTechDataId] = q[1],
            [kTechDataDisplayName] = q[2],
            [kTechDataTooltipInfo] = "VT_QUOTA_TOOLTIP",
            [kTechDataCostKey] = 0,
        })
    end

    -- ---------------------------------------------------------------- research
    local research =
    {
        { kTechId.VTAuthorizationTier2,  "VT_TIER2",       kVTTier2Cost,       kVTTier2Time },
        { kTechId.VTAuthorizationTier3,  "VT_TIER3",       kVTTier3Cost,       kVTTier3Time },
        { kTechId.VTOverchargeTech,      "VT_OVERCHARGE",  kVTOverchargeCost,  kVTOverchargeTime },
        { kTechId.VTSingularityTech,     "VT_SINGULARITY", kVTSingularityCost, kVTSingularityTime },
        { kTechId.VTPhaseDashTech,       "VT_PHASEDASH",   kVTPhaseDashCost,   kVTPhaseDashTime },
        { kTechId.VTTargetingVisorTech,  "VT_VISOR",       kVTTargetingVisorCost, kVTTargetingVisorTime },
        { kTechId.VTShieldOverdriveTech, "VT_OVERDRIVE",   kVTOverdriveCost,   kVTOverdriveTime },
        { kTechId.VTArchonsThrone,       "VT_THRONE",      kVTArchonsThroneCost,  kVTArchonsThroneTime },
        { kTechId.VTPhaseCloakTech,      "VT_PHASECLOAK",  kVTPhaseCloakCost,     kVTPhaseCloakTime },
        { kTechId.VTNeuralOverrideTech,  "VT_OVERRIDE",    kVTNeuralOverrideCost, kVTNeuralOverrideTime },
        { kTechId.VTPsionicEdictsTech,   "VT_PSI_EDICTS",  kVTPsionicEdictsCost,  kVTPsionicEdictsTime },
    }
    for _, r in ipairs(research) do
        Add(techData, {
            [kTechDataId] = r[1],
            [kTechDataDisplayName] = r[2],
            [kTechDataResearchName] = r[2],
            [kTechDataTooltipInfo] = r[2] .. "_TOOLTIP",
            [kTechDataCostKey] = r[3],
            [kTechDataResearchTimeKey] = r[4],
        })
    end

    -- Plasma Calibration I-III / Shield Matrix I-III: own ids, cloned from the vanilla
    -- Weapons1-3 / Armor1-3 entries (marines keep theirs untouched).
    local kWeaponIds = { kTechId.Weapons1, kTechId.Weapons2, kTechId.Weapons3 }
    local kArmorIds  = { kTechId.Armor1, kTechId.Armor2, kTechId.Armor3 }
    for level = 1, 3 do
        local name = "VT_PLASMA_CALIBRATION_" .. level
        Clone(techData, kWeaponIds[level], {
            [kTechDataId] = kTechId["VTPlasmaCalibration" .. level],
            [kTechDataDisplayName] = name,
            [kTechDataResearchName] = name,
            [kTechDataTooltipInfo] = "VT_PLASMA_CALIBRATION_TOOLTIP",
            [kTechDataCostKey] = kVTPlasmaCalibrationCost[level],
            [kTechDataResearchTimeKey] = kVTPlasmaCalibrationTime[level],
        })
        name = "VT_SHIELD_MATRIX_" .. level
        Clone(techData, kArmorIds[level], {
            [kTechDataId] = kTechId["VTShieldMatrix" .. level],
            [kTechDataDisplayName] = name,
            [kTechDataResearchName] = name,
            [kTechDataTooltipInfo] = "VT_SHIELD_MATRIX_TOOLTIP",
            [kTechDataCostKey] = kVTShieldMatrixCost[level],
            [kTechDataResearchTimeKey] = kVTShieldMatrixTime[level],
        })
    end

    -- ----------------------------------------------------------------- weapons
    Clone(techData, kTechId.Rifle, {
        [kTechDataId] = kTechId.VTPlasmaCarbine,
        [kTechDataMapName] = kVTMapNames.Carbine,
        [kTechDataModel] = "models/vaelthor/falcon/falcon.model",   -- Falcon world model (precached in VTWeapons.lua)
        [kTechDataDisplayName] = "VT_CARBINE",
        [kTechDataTooltipInfo] = "VT_CARBINE",
        [kTechDataCostKey] = 0,
    })

    Clone(techData, kTechId.Axe, {
        [kTechDataId] = kTechId.VTPsionicBlade,
        [kTechDataMapName] = kVTMapNames.Blade,
        [kTechDataDisplayName] = "VT_BLADE",
        [kTechDataTooltipInfo] = "VT_BLADE",
        [kTechDataCostKey] = 0,
    })

    Clone(techData, kTechId.Axe, {
        [kTechDataId] = kTechId.VTPsionicKnife,
        [kTechDataMapName] = kVTMapNames.Knife,
        [kTechDataModel] = "models/vaelthor/knife/knife.model",
        [kTechDataDisplayName] = "VT_KNIFE",
        [kTechDataTooltipInfo] = "VT_KNIFE",
        [kTechDataCostKey] = 0,
    })

    Clone(techData, kTechId.Axe, {
        [kTechDataId] = kTechId.VTSubjectClaws,
        [kTechDataMapName] = kVTMapNames.Claws,
        [kTechDataDisplayName] = "VT_CLAWS",
        [kTechDataTooltipInfo] = "VT_CLAWS",
        [kTechDataCostKey] = 0,
    })

    Clone(techData, kTechId.Welder, {
        [kTechDataId] = kTechId.VTEchoPulse,
        [kTechDataMapName] = kVTMapNames.EchoPulse,
        [kTechDataDisplayName] = "VT_ECHO_PULSE",
        [kTechDataTooltipInfo] = "VT_ECHO_PULSE",
        [kTechDataCostKey] = 0,
    })

    Clone(techData, kTechId.GrenadeLauncher, {
        [kTechDataId] = kTechId.VTSingularityLauncher,
        [kTechDataMapName] = kVTMapNames.Singularity,
        [kTechDataDisplayName] = "VT_SINGULARITY_LAUNCHER",
        [kTechDataTooltipInfo] = "VT_SINGULARITY_LAUNCHER",
        [kTechDataCostKey] = 0,
        [kStructureAttachId] = REMOVE,
        [kStructureAttachRange] = REMOVE,
        [kStructureAttachRequiresPower] = REMOVE,
    })

    cloneSource = nil
    return techData

end

end -- VT_HookedTechData
