-- ============================================================================
-- Vael'Thor Empire - global ids, enums and balance values
-- (post-hook of lua/TechTreeConstants.lua)
-- ============================================================================

local appendToEnum = debug.appendtoenum or function(tbl, key)
    if rawget(tbl, key) ~= nil then return end
    local maxVal = #tbl
    rawset(tbl, key, maxVal + 1)
    rawset(tbl, maxVal + 1, key)
end

local kNewTechIds =
{
    -- Castes (player classes)
    "VTVanguard", "VTInfiltrator", "VTSubject", "VTPraetor",

    -- ORDER MATTERS: the tech tree requires every prerequisite to have a lower
    -- id than the node depending on it (TechTree:ComputeHasTech).

    -- Structures. The Imperial Nexus / Resource Siphon have their own ids (and
    -- classes, subclasses of CommandStation / Extractor) so vanilla marines in
    -- the same match keep their own Command Station / Extractor rules.
    "VTNexus", "VTSiphon",
    "VTSubventionPylon", "VTSynthesisChamber", "VTShieldGenerator",

    -- Synthesis Chamber research (prereq: Synthesis Chamber / each other)
    "VTAuthorizationTier2", "VTAuthorizationTier3",
    "VTOverchargeTech", "VTPhaseDashTech", "VTShieldOverdriveTech", "VTSingularityTech",

    -- Structures that depend on research
    "VTRiftPortal",

    -- Directives (global edicts issued from the Nexus)
    "VTEdictRequisition", "VTEdictRelentless",

    -- Caste quota controls
    "VTQuotaInfiltratorUp", "VTQuotaInfiltratorDown",
    "VTQuotaSubjectUp",     "VTQuotaSubjectDown",
    "VTQuotaPraetorUp",     "VTQuotaPraetorDown",

    -- Weapons
    "VTPlasmaCarbine", "VTPsionicBlade", "VTSubjectClaws", "VTSingularityLauncher",

    -- ---- Expansion: economy & tech tree (appended; keep order) ----
    -- Structures
    "VTSentinelObelisk", "VTPsionicSpire",
    -- Per-structure upgrades
    "VTResonantPylonUpgrade", "VTAegisArrayUpgrade",
    -- Research (prereqs above: VTNexus, VTAuthorizationTier2, VTPsionicSpire)
    "VTArchonsThrone", "VTPhaseCloakTech", "VTNeuralOverrideTech", "VTPsionicEdictsTech",
    -- Directive unlocked by the Archon's Throne
    "VTEdictIronDiscipline",
    -- Nexus sub menu
    "VTQuotaMenu",
    -- Commander support abilities (Assist menu)
    "VTShieldPulse", "VTRiftRecall",

    -- Nexus Gate: upgraded Nexus (structure tech id) and its upgrade
    "VTNexusGate", "VTNexusGateUpgrade",

    -- Infiltrator scouting tool (weapon slot 2)
    "VTEchoPulse",

    -- Shield Generator research: vision mode on the flashlight key (prereq VTShieldGenerator)
    "VTTargetingVisorTech",

    -- Vanguard melee
    "VTPsionicKnife",

    -- Sentinel Obelisk beams: per-structure upgrades (Trinity prereq VTAuthorizationTier2), the commander's
    -- targeted focus and the beam count switches
    "VTObeliskPrismUpgrade", "VTObeliskTrinityUpgrade",
    "VTObeliskFocus", "VTObeliskBeams1", "VTObeliskBeams2", "VTObeliskBeams3",
}

for _, name in ipairs(kNewTechIds) do
    appendToEnum(kTechId, name)
end

-- ----------------------------------------------------------------------------
-- Faction identity
-- ----------------------------------------------------------------------------
kVTFactionName = "Vael'Thor Empire"

-- ----------------------------------------------------------------------------
-- Faction matchup (voted in the vote menu, applied on the next map load; see
-- Server.lua). The Vael'Thor always play as team 1 when they are in the match.
--   VTvsAliens      : Vael'Thor (team 1) vs. Aliens (team 2)
--   MarinesVsAliens : vanilla NS2, the mod stays dormant
--   VTvsMarines     : Vael'Thor (team 1) vs. vanilla Marines (team 2, marine team type)
-- ----------------------------------------------------------------------------
kVTMatchup = enum({ "VTvsAliens", "MarinesVsAliens", "VTvsMarines" })
kVTMatchupNames =
{
    [kVTMatchup.VTvsAliens]      = "Vael'Thor vs. Aliens",
    [kVTMatchup.MarinesVsAliens] = "Marines vs. Aliens",
    [kVTMatchup.VTvsMarines]     = "Vael'Thor vs. Marines",
}
kVTDefaultMatchup = kVTMatchup.VTvsAliens
kVTNoTeam = -1            -- kVTTeamIndex when the Vael'Thor are not in the match

gVTMatchup   = kVTDefaultMatchup
kVTTeamIndex = 1          -- the Vael'Thor take the marine slot (team 1); kVTNoTeam if absent

function VT_GetIsValidMatchup(matchup)
    return type(matchup) == "number" and kVTMatchupNames[matchup] ~= nil
end

function VT_GetMatchup()
    return gVTMatchup
end

function VT_GetIsVTActive()
    return kVTTeamIndex ~= kVTNoTeam
end

-- Sets the matchup in this VM (server: at map load; client: VTMatchup message).
-- Team 2 is the marine team type in Vael'Thor vs. Marines; vanilla derives every
-- entity's team type from TeamMixin's local kTeamIndexToType table, which
-- Hooks/TeamMixin.lua publishes as a global so it can be patched here.
function VT_ApplyMatchup(matchup)

    if not VT_GetIsValidMatchup(matchup) then
        matchup = kVTDefaultMatchup
    end
    gVTMatchup = matchup
    kVTTeamIndex = (matchup == kVTMatchup.MarinesVsAliens) and kVTNoTeam or 1

    local team2Type = (matchup == kVTMatchup.VTvsMarines) and kMarineTeamType or kAlienTeamType
    kTeam2Type = team2Type
    if kTeamIndexToType and kTeam2Index then
        kTeamIndexToType[kTeam2Index] = team2Type
    end

    -- Scoreboard / playing team names (vanilla: "Frontiersmen" / "Kharaa").
    kTeam1Name = (matchup == kVTMatchup.MarinesVsAliens) and "Frontiersmen" or kVTFactionName
    kTeam2Name = (matchup == kVTMatchup.VTvsMarines) and "Frontiersmen" or "Kharaa"

end

kVTMapNames =
{
    Vanguard        = "vt_vanguard",
    Infiltrator     = "vt_infiltrator",
    Subject         = "vt_subject",
    Praetor         = "vt_praetor",
    Spectator       = "vt_spectator",

    Nexus           = "vt_nexus",
    Siphon          = "vt_siphon",

    Pylon           = "vt_subventionpylon",
    Chamber         = "vt_synthesischamber",
    ShieldGen       = "vt_shieldgenerator",
    Rift            = "vt_riftportal",

    Carbine         = "vt_plasmacarbine",
    Blade           = "vt_psionicblade",
    Claws           = "vt_subjectclaws",
    Singularity     = "vt_singularitylauncher",
    EchoPulse       = "vt_echopulse",
    Knife           = "vt_psionicknife",
    SingularityBolt = "vt_singularitybolt",

    EmpireInfo      = "vt_empireinfo",

    Obelisk         = "vt_sentinelobelisk",
    Spire           = "vt_psionicspire",
}

kVTClass      = enum({ "Vanguard", "Infiltrator", "Subject", "Praetor" })
kVTModule     = enum({ "ShieldBoost", "PhaseDash", "ShieldOverdrive" })
kVTPrimaryMod = enum({ "Standard", "Overcharge" })
kVTSecondary  = enum({ "Pistol", "Singularity" })

-- ----------------------------------------------------------------------------
-- Spawning: "Synthesis Matrix"
-- ----------------------------------------------------------------------------
kVTRespawnTime          = 9      -- seconds a dead player waits in the matrix
kVTSpawnMinRange        = 2
kVTSpawnMaxRange        = 6

-- Caste quotas: { default, maximum }. Vanguard is always unlimited.
kVTQuotaDefaults = { Infiltrator = 2, Subject = 2, Praetor = 1 }
kVTQuotaMax      = { Infiltrator = 3, Subject = 4, Praetor = 2 }

-- No personal resources: castes cost team resources when synthesized.
kVTCasteCost = { Infiltrator = 4, Subject = 8, Praetor = 25 }

-- Imperial Authorization: round score needed for each rank
kVTRank2Score           = 15
kVTRank3Score           = 40

-- ----------------------------------------------------------------------------
-- Subvention Network
-- ----------------------------------------------------------------------------
kVTFieldRadiusPylon         = 11
kVTFieldRadiusNexus         = 16
kVTFieldUpdateInterval      = 0.5
-- Self-assembly: unbuilt structures construct themselves at a fixed rate while
-- at least one living soldier stands within this radius (same as pylon range).
kVTAutoBuildRadius          = kVTFieldRadiusPylon
kVTAutoBuildInterval        = 0.1
kVTFieldPlayerShieldRegen   = 4      -- psi shield per second (only the shield regenerates; armor + health are permanent)
kVTFieldStructureShieldRegen= 10
kVTFieldRegenDelay          = 3      -- seconds without taking damage before field shields recharge
kVTStructureShieldRegenDelay= 6      -- structures: cannot be repaired, shield recharges anywhere after this
kVTFieldAmmoRegenInterval   = 6      -- seconds between reserve-ammo top ups in the field

kVTShieldGenRadius          = 9
kVTShieldGenDamageScalar    = 0.5    -- ranged damage taken by protected structures
kVTShieldGenMeleeRange      = 4      -- attackers closer than this count as melee

-- ----------------------------------------------------------------------------
-- Directives (edicts)
-- ----------------------------------------------------------------------------
kVTRequisitionCost          = 10
kVTRequisitionDuration      = 30
kVTRequisitionCooldown      = 90
kVTRequisitionBuildScalar   = 1.75

kVTRelentlessCost           = 15
kVTRelentlessDuration       = 20
kVTRelentlessCooldown       = 120
kVTRelentlessDamageScalar   = 1.2

kVTIronDisciplineCost       = 15
kVTIronDisciplineDuration   = 20
kVTIronDisciplineCooldown   = 120
kVTIronDisciplineDamageScalar = 0.77  -- damage taken by imperial soldiers (~ +30% effective HP)

-- Psionic Edicts research (Psionic Spire)
kVTPsionicEdictsDurationScalar = 1.5
kVTPsionicEdictsCooldownScalar = 0.75

-- Commander support abilities
kVTShieldPulseCost          = 3
kVTShieldPulseCooldown      = 8
kVTShieldPulseRadius        = 6
kVTRiftRecallCost           = 4
kVTRiftRecallCooldown       = 20
kVTRiftRecallTargetRange    = 2.5    -- how close to the click a soldier must be

-- ----------------------------------------------------------------------------
-- Structures
-- ----------------------------------------------------------------------------
kVTPylonCost = 8        kVTPylonBuildTime = 8         kVTPylonHealth = 700      kVTPylonArmor = 100
kVTChamberCost = 15     kVTChamberBuildTime = 18      kVTChamberHealth = 1600   kVTChamberArmor = 300
kVTShieldGenCost = 12   kVTShieldGenBuildTime = 14    kVTShieldGenHealth = 1100 kVTShieldGenArmor = 250
kVTRiftCost = 15        kVTRiftBuildTime = 15         kVTRiftHealth = 1500      kVTRiftArmor = 200
kVTNexusCost = 25       -- free placement: not bound to tech points

-- Nexus Gate network
kVTNexusGateCost = 20           kVTNexusGateTime = 45
kVTGateTeleportCooldown     = 8      -- per player
kVTGateUseRange             = 4      -- max distance to the pylon when the jump is requested
kVTGateArrivalMinRange      = 2.5
kVTGateArrivalMaxRange      = 6
kVTObeliskCost = 12     kVTObeliskBuildTime = 10      kVTObeliskHealth = 600    kVTObeliskArmor = 150
-- Obelisk beams (Classes/VTStructures.lua). Base damage = the vanilla sentry's sustained DPS (5 per 0.15 s).
-- kVTObeliskBeamScalars[upgrade level][beam count] = damage of EACH beam relative to the base.
kVTObeliskBeamDPS           = 33.3
kVTObeliskRange             = 20     -- = vanilla sentry range
kVTObeliskTickInterval      = 0.1    -- damage/target update period (s)
kVTObeliskConfusedScalar    = 0.5    -- while stunned/confused
kVTObeliskFocusLeash        = 1.5    -- focus is dropped beyond range x this
kVTObeliskBeamScalars =
{
    [0] = { 1.0 },                    -- no upgrade: one beam
    [1] = { 1.15, 0.9 },              -- Prism Lens: up to two beams
    [2] = { 1.3, 0.9, 0.7 },          -- Trinity Lens: up to three beams
}
kVTObeliskPrismCost = 10        kVTObeliskPrismTime = 30
kVTObeliskTrinityCost = 15      kVTObeliskTrinityTime = 45

kVTSpireCost = 25       kVTSpireBuildTime = 20        kVTSpireHealth = 1800     kVTSpireArmor = 300

-- Structure upgrades
kVTResonantPylonCost = 10       kVTResonantPylonTime = 30
kVTResonantFieldRadius      = 15
kVTResonantRegenScalar      = 1.5
kVTAegisArrayCost = 15          kVTAegisArrayTime = 40

-- ----------------------------------------------------------------------------
-- Research
-- ----------------------------------------------------------------------------
kVTTier2Cost = 20           kVTTier2Time = 60
kVTTier3Cost = 35           kVTTier3Time = 90
kVTOverchargeCost = 20      kVTOverchargeTime = 60
kVTSingularityCost = 25     kVTSingularityTime = 75
kVTPhaseDashCost = 15       kVTPhaseDashTime = 45
kVTTargetingVisorCost = 20  kVTTargetingVisorTime = 60   -- Shield Generator research
kVTOverdriveCost = 20       kVTOverdriveTime = 60
kVTArchonsThroneCost = 30   kVTArchonsThroneTime = 75
kVTPhaseCloakCost = 15      kVTPhaseCloakTime = 45
kVTNeuralOverrideCost = 20  kVTNeuralOverrideTime = 60
kVTPsionicEdictsCost = 25   kVTPsionicEdictsTime = 60

-- ----------------------------------------------------------------------------
-- Castes
-- ----------------------------------------------------------------------------
kVTVanguardHealth = 80          kVTVanguardArmor = 40     -- 160 effective HP, same as a marine (100/30)
kVTInfiltratorHealth = 85       kVTInfiltratorArmor = 20     kVTInfiltratorSpeedScalar = 1.12
kVTSubjectHealth = 320          kVTSubjectArmor = 80         kVTSubjectSpeedScalar = 1.15
kVTSubjectModelScale = 1.3

-- ----------------------------------------------------------------------------
-- Building model scale (VT_InstallStructureScale): every Vael'Thor building is
-- drawn at this size via OnAdjustModelCoords; the models themselves are built
-- at the heights in art/buildings/build_all.sh (= kVTStructureModelHeights).
-- ----------------------------------------------------------------------------
kVTStructureModelScale = 0.8

-- Model heights in m as built (art/buildings/build_all.sh), before kVTStructureModelScale.
kVTStructureModelHeights =
{
    nexus = 4.2, chamber = 2.6, spire = 5.0, pylon = 3.2,
    siphon = 3.2, shieldgen = 2.4, obelisk = 3.8, rift = 3.0,
}

-- Model files of the scaled buildings (the commander ghost preview is scaled too, Hooks/GhostModelUI.lua).
kVTScaledStructureModels = {}
for name in pairs(kVTStructureModelHeights) do
    kVTScaledStructureModels[string.format("models/vaelthor/%s/%s.model", name, name)] = true
end

-- Draws cls at kVTStructureModelScale (rendering, attach points, model origin
-- and - as far as the engine applies the scale - the collision model all follow
-- _modelCoords) and puts its health bar just above the scaled model.
function VT_InstallStructureScale(cls, modelName)
    local previous = cls.OnAdjustModelCoords
    function cls:OnAdjustModelCoords(modelCoords)
        if previous then
            modelCoords = previous(self, modelCoords)
        end
        local s = kVTStructureModelScale
        modelCoords.xAxis = modelCoords.xAxis * s
        modelCoords.yAxis = modelCoords.yAxis * s
        modelCoords.zAxis = modelCoords.zAxis * s
        return modelCoords
    end
    local height = kVTStructureModelHeights[modelName]
    if height then
        function cls:GetHealthbarOffset()
            return height * kVTStructureModelScale + 0.4
        end
    end
end

-- Subject mobility (Unreal Tournament style)
kVTDodgeTapWindow           = 0.25   -- max seconds between the two taps of a direction key
kVTDodgeSpeed               = 9      -- horizontal launch speed (marine run speed is 5.75)
kVTDodgeUpSpeed             = 3.5    -- small hop so the dodge clears the ground
kVTDodgeCooldown            = 1.0
kVTSubjectAirJumps          = 1      -- extra jumps while airborne (1 = double jump)
-- Claw climb (Subject): Skulk-style wall walking on walls and ceilings at run speed while stamina lasts.
kVTClimbStamina             = 2.0    -- seconds of wall walking
kVTClimbStaminaRegen        = 1.0    -- per second, only on the ground (empty -> full in 2 s)
kVTClimbMinStamina          = 0.3    -- needed to attach again
kVTClimbReach               = 0.3    -- surface must be this close beyond the collision radius
kVTClimbKickSpeed           = 5.5    -- jumping off a wall pushes away this fast
-- Subject sprint (Shift on the ground): kVTSubjectSprintDuration seconds at kVTSubjectSprintSpeed with full
-- steering, then kVTSubjectSprintCooldown (counted from the start). Shift on a wall holds the position and
-- keeps climb stamina full.
kVTSubjectSprintDuration    = 3      -- seconds (was a 7 m / 12 m distance limit)
kVTSubjectSprintSpeed       = 14     -- m/s (marine run speed is 5.75, the Subject's ~6.6)
kVTSubjectSprintCooldown    = 8
kVTPraetorHealth = 150          -- armor comes from the exo chassis

-- ----------------------------------------------------------------------------
-- Psi shield (Protoss style): a third pool in front of armor and health. Only the
-- shield regenerates (Subvention field, VTTeam:UpdateSubventionNetwork); armor and
-- health are never restored. Absorbs damage 1:1 after the damage-type rules
-- (Classes/VTShield.lua, Hooks/DamageTypes.lua).
-- ----------------------------------------------------------------------------
kVTMaxShield =
{
    VTVanguard          = 50,
    VTInfiltrator       = 35,
    VTSubject           = 100,
    VTPraetor           = 200,
    VTNexus             = 800,   -- Imperial Nexus
    VTSiphon            = 500,   -- Resource Siphon
    VTSubventionPylon   = 250,
    VTSynthesisChamber  = 500,
    VTShieldGenerator   = 400,
    VTRiftPortal        = 450,
    VTSentinelObelisk   = 200,
    VTPsionicSpire      = 550,
}
kVTShieldPerUpgradeLevel    = 15     -- Shield Matrix I-III (Armor1-3 ids): + max shield per level, soldiers only
kVTShieldGlowFadeTime       = 0.4    -- purple shell after a shield hit
kVTInfestationRegenBlock    = 1.5    -- structures on infestation: no shield regen (the creep drains it instead)

-- Bile Bomb vs. soldiers: this fraction of the raw bile damage drains the psi
-- shield first, the rest removes armor points; never health. Structures: the
-- shield absorbs the bile first, the remainder takes the vanilla bile rules.
kVTBileArmorFraction        = 0.1

-- Abilities (TertiaryAttack, default key: B)
kVTShieldBoostCooldown      = 20
kVTPhaseDashDistance        = 7
kVTPhaseDashCooldown        = 8
kVTOverdriveDuration        = 5
kVTOverdriveSpeedScalar     = 1.2
kVTOverdriveBurnout         = 8      -- seconds without shields after Overdrive ends
kVTOverdriveCooldown        = 22
kVTCloakDuration            = 10
kVTPhaseCloakDuration       = 15     -- with Phase Cloak research
kVTCloakCooldown            = 15
kVTCloakMovementPenalty     = 0.35   -- 1 = vanilla camouflage (full speed leaves ~20% cloak)
kVTHackRadius               = 7
kVTHackDuration             = 10
kVTNeuralOverrideRadius     = 9      -- with Neural Override research
kVTNeuralOverrideDuration   = 15
kVTHackCooldown             = 35
-- Echo Scan (Infiltrator, weapon slot 2): while fire is held, enemy players, structures
-- and eggs inside a cone in front of the Infiltrator are outlined through walls for the
-- whole Vael'Thor team; on release (or leaving the cone) they fade out. Replaces the marine scan.
kVTEchoPulseRange           = 30     -- metres from the Infiltrator's eyes
kVTEchoPulseHalfAngle       = 35     -- degrees either side of the view direction (70 deg cone)
kVTEchoScanFadeTime         = 0.5    -- seconds the outline takes to fade after the scan stops
-- Targeting Visor (all castes, after research): flashlight key toggles a vision mode that marks
-- enemies in the player's OWN line of sight (exosuit target reticles + purple outline + violet tint).
kVTVisorRange               = 35     -- metres (outline renderer reaches 38 m)
kVTPraetorDashDistance      = 12     -- 10 x 1.2 (range +20%, 2026-11-03)
kVTPraetorDashEnergyCost    = 20     -- taken from the minigun energy pool (vtEnergy)
kVTPraetorDashCooldown      = 10

-- Weapons
kVTCarbineDamageScalar      = 1.15   -- per bolt vs the marine rifle (kRifleDamage)
kVTCarbineSpreadScalar      = 0.75   -- bolt spread cone vs the marine rifle (2.8 deg -> 2.1 deg)
-- Psionic Knife: the Vanguard's structure breaker. Axe damage (25 structural, x2 vs structures in vanilla)
-- times this vs structures only -> 100 per swing vs a Harvester (2400 effective HP): ~24 swings, ~10-13 s
-- (marine axe or rifle: ~20-34 s, skulk vs extractor: ~27 s). Player damage stays at axe level.
kVTKnifeStructureDamageScalar = 2.0
-- Weapon switch: draw animations play this much faster for the Vanguard's weapons (catalyst_speed while drawing).
kVTDrawSpeedScalar          = 1.5
kVTKnifeDrawTime            = 0.8    -- axe_view.model 'draw' length (s); the knife has no deploy flag
-- Plasma bolts: projectiles instead of hitscan - a bit harder to hit, but each hit lands harder.
kVTCarbineFireRateScalar    = 0.85   -- fire animation speed vs the marine rifle (rate of fire is tag-driven)
kVTCarbineBoltSpeed         = 80     -- m/s (marine rifle: hitscan; gorge spit: 45)
kVTCarbineBoltRadius        = 0.05   -- collision radius; small = needs real aim
kVTCarbineBoltLifetime      = 1.5    -- s (~120 m)
kVTCarbineBoltLightRadius   = 3.5
kVTCarbineBoltLightIntensity = 5
-- Praetor plasma miniguns: same blaster rules as the carbine (bolts, x0.85 rate, x1.15 damage per hit).
-- One bolt carries kVTPraetorBoltBatch minigun bullets so a Praetor doesn't spawn ~50 projectiles a second.
kVTPraetorFireRateScalar    = 1.275  -- 0.85 x 1.5 (fire rate raised 50%, 2026-11-03)
kVTPraetorBoltDamageScalar  = 1.15
kVTPraetorBoltBatch         = 3
kVTPraetorSpread            = 5      -- degrees, bolt spread cone of the plasma miniguns (crosshair ring uses it)
kVTPraetorSplashRadius      = 1.8    -- m; enemies around a Praetor bolt impact take splash damage
kVTPraetorSplashDamage      = 1.0    -- x the bolt's base damage at the centre, falling off to 0 at the edge
-- Plasma Carbine energy cell: no clips, no reload. Recharges round by round
-- inside the Subvention field, slower than it can be emptied (~8 s to empty
-- at rifle fire rate, ~13 s to refill).
kVTCarbineEnergy            = 80
kVTCarbineRechargeDelay     = 0.5    -- seconds after the last shot before recharging starts
kVTCarbineRechargeRate      = 16     -- rounds per second while inside the field (empty -> full in 5 s)
-- Praetor energy: one shared pool for both plasma miniguns, 1 per bolt.
-- Inside a pylon/Nexus field it recharges like the Vanguard's carbine (same delay and rate: empty -> full in 6.25 s).
-- Outside a field it slowly regenerates, but only out of combat (no damage dealt/taken for kCombatTimeOut = 3 s,
-- no bolt for kVTPraetorSlowRechargeDelay): empty -> full in 60 s.
kVTPraetorEnergy            = 100
kVTPraetorEnergyPerBolt     = 1
kVTPraetorRechargeDelay     = kVTCarbineRechargeDelay
kVTPraetorRechargeRate      = kVTCarbineRechargeRate
kVTPraetorSlowRechargeDelay = 3
kVTPraetorSlowRechargeRate  = kVTPraetorEnergy / 60
kVTOverchargeDamageScalar   = 1.9    -- per bolt
kVTOverchargeFireDelay      = 0.2    -- min seconds between heavy bolts
kVTBladeDamage              = 45
kVTClawsDamage              = 60
kVTClawsRange               = 1.6
kVTSingularityDamage        = 25
kVTSingularityRadius        = 4.5
kVTSingularityPull          = 7      -- m/s impulse toward the anomaly
kVTSingularityPullMaxMass   = 200    -- only light units get pulled
kVTSingularitySlowDuration  = 3

-- ----------------------------------------------------------------------------
-- Helpers usable in every VM
-- ----------------------------------------------------------------------------
function VT_GetIsVTTeam(teamNumber)
    return teamNumber == kVTTeamIndex
end

function VT_GetIsVTEntity(entity)
    return entity ~= nil and kVTTeamIndex ~= kVTNoTeam and HasMixin(entity, "Team")
            and entity:GetTeamNumber() == kVTTeamIndex
end

-- Commander placement aid (kTechDataGhostGuidesMethod): while placing a
-- structure, draw the Subvention field of every Pylon and Nexus, so the
-- commander can see whether the new building will be powered.
function VT_GetSubventionFieldGuides(commander)

    local entities = {}
    local ranges = {}
    local teamNumber = commander:GetTeamNumber()

    for _, pylon in ipairs(GetEntitiesForTeam("VTSubventionPylon", teamNumber)) do
        if pylon:GetIsAlive() then
            entities[#entities + 1] = pylon
            ranges[pylon] = pylon.GetVTFieldRadius and pylon:GetVTFieldRadius() or kVTFieldRadiusPylon
        end
    end

    for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", teamNumber)) do
        if nexus:GetIsAlive() then
            entities[#entities + 1] = nexus
            ranges[nexus] = kVTFieldRadiusNexus
        end
    end

    return entities, ranges

end

-- Map power nodes are hard-wired to team 1 by the engine, but they are not part
-- of the empire: never build, repair or shield them.
function VT_GetIsEmpireEntity(entity)
    return VT_GetIsVTEntity(entity) and not entity:isa("PowerPoint")
end

function VT_GetRankForScore(score)
    score = score or 0
    if score >= kVTRank3Score then
        return 3
    elseif score >= kVTRank2Score then
        return 2
    end
    return 1
end

kVTClassMapNames =
{
    [kVTClass.Vanguard]    = kVTMapNames.Vanguard,
    [kVTClass.Infiltrator] = kVTMapNames.Infiltrator,
    [kVTClass.Subject]     = kVTMapNames.Subject,
    [kVTClass.Praetor]     = kVTMapNames.Praetor,
}

kVTClassNames =
{
    [kVTClass.Vanguard]    = "VANGUARD",
    [kVTClass.Infiltrator] = "INFILTRATOR",
    [kVTClass.Subject]     = "SUBJECT",
    [kVTClass.Praetor]     = "PRAETOR",
}

-- Requirements for each loadout choice: minimum Authorization rank and the
-- team research that must be complete.
kVTModuleRequirements =
{
    [kVTModule.ShieldBoost]     = { rank = 1 },
    [kVTModule.PhaseDash]       = { rank = 1, tech = "VTPhaseDashTech" },
    [kVTModule.ShieldOverdrive] = { rank = 2, tech = "VTShieldOverdriveTech" },
}

kVTPrimaryModRequirements =
{
    [kVTPrimaryMod.Standard]   = { rank = 1 },
    [kVTPrimaryMod.Overcharge] = { rank = 2, tech = "VTOverchargeTech" },
}

kVTSecondaryRequirements =
{
    [kVTSecondary.Pistol]      = { rank = 1 },
    [kVTSecondary.Singularity] = { rank = 3, tech = "VTSingularityTech" },
}

kVTClassRequirements =
{
    [kVTClass.Vanguard]    = { },
    [kVTClass.Infiltrator] = { },
    [kVTClass.Subject]     = { tech = "VTAuthorizationTier2" },
    [kVTClass.Praetor]     = { tech = "VTAuthorizationTier3" },
}
