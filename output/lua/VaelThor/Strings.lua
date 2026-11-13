-- ============================================================================
-- Vael'Thor Empire - text (English). Hooked into Locale on the client; the
-- server uses the table directly for chat announcements.
-- ============================================================================

kVTStrings =
{
    VT_NEXUS                       = "Imperial Nexus",
    VT_NEXUS_TOOLTIP               = "Core of the empire: spawn point, command chair and Subvention field. Can be built anywhere. The empire falls when every Nexus is destroyed.",
    VT_SIPHON                      = "Resource Siphon",
    VT_SIPHON_TOOLTIP              = "Strips the planet of raw material. Must stand inside the Subvention field to operate.",

    VT_VANGUARD                    = "Vanguard Legionnaire",
    VT_VANGUARD_TOOLTIP            = "Core infantry. Plasma Carbine and a tactical module. Unlimited quota.",
    VT_INFILTRATOR                 = "Infiltrator",
    VT_INFILTRATOR_TOOLTIP         = "Scout/assassin. Cloaking field (B) and Psionic Blade; right-click with the blade hacks nearby enemy structures.",
    VT_SUBJECT                     = "Subject (Bio-Construct)",
    VT_SUBJECT_TOOLTIP             = "Engineered war-beast. Huge health pool and brutal melee. Double-tap a direction to dodge, jump again in mid-air to double jump. Costs team resources to synthesize.",
    VT_PRAETOR                     = "Praetor",
    VT_PRAETOR_TOOLTIP             = "Heavy elite. Gatling-Plasma cannons and Teleport Dash (B).",

    VT_PYLON                       = "Subvention Pylon",
    VT_PYLON_TOOLTIP               = "Extends the Subvention field. Structures only function inside the field; units inside it regenerate shields.",
    VT_CHAMBER                     = "Synthesis Chamber",
    VT_CHAMBER_TOOLTIP             = "Spawn point of the Synthesis Matrix. Researches authorization tiers and weapon modifications.",
    VT_SHIELDGEN                   = "Shield Generator",
    VT_SHIELDGEN_TOOLTIP           = "Halves ranged and artillery damage taken by nearby imperial structures.",

    VT_EDICT_REQUISITION           = "Directive: Requisition Mandate",
    VT_EDICT_REQUISITION_TOOLTIP   = "For 30 seconds all imperial construction is 75% faster.",
    VT_EDICT_RELENTLESS            = "Directive: Relentless Advance",
    VT_EDICT_RELENTLESS_TOOLTIP    = "For 20 seconds all imperial forces deal 20% more damage.",

    VT_QUOTA_INFILTRATOR_UP        = "Infiltrator quota +1",
    VT_QUOTA_INFILTRATOR_DOWN      = "Infiltrator quota -1",
    VT_QUOTA_SUBJECT_UP            = "Subject quota +1",
    VT_QUOTA_SUBJECT_DOWN          = "Subject quota -1",
    VT_QUOTA_PRAETOR_UP            = "Praetor quota +1",
    VT_QUOTA_PRAETOR_DOWN          = "Praetor quota -1",
    VT_QUOTA_TOOLTIP               = "Caste quotas limit how many soldiers may be synthesized in each caste.",

    VT_TIER2                       = "Authorization Tier II",
    VT_TIER2_TOOLTIP               = "Unlocks the Subject caste.",
    VT_TIER3                       = "Authorization Tier III",
    VT_TIER3_TOOLTIP               = "Unlocks the Praetor caste.",
    VT_OVERCHARGE                  = "Overcharge Core",
    VT_OVERCHARGE_TOOLTIP          = "Loadout (rank II): the Plasma Carbine fires slower, heavy armor-breaking bolts.",
    VT_SINGULARITY                 = "Singularity Launcher",
    VT_SINGULARITY_TOOLTIP         = "Loadout (rank III): fires gravity anomalies that slow enemies and pull light units together.",
    VT_PHASEDASH                   = "Phase Dash Module",
    VT_PHASEDASH_TOOLTIP           = "Vanguard module: short directional teleport.",
    VT_VISOR                       = "Targeting Visor",
    VT_VISOR_TOOLTIP               = "All castes: the flashlight key toggles a visor that marks enemies in your line of sight.",
    VT_OVERDRIVE                   = "Shield Overdrive",
    VT_OVERDRIVE_TOOLTIP           = "Vanguard module (rank II): full shields and +20% speed for 5s, then 8s without shields.",

    VT_PLASMA_CALIBRATION_1        = "Plasma Calibration I",
    VT_PLASMA_CALIBRATION_2        = "Plasma Calibration II",
    VT_PLASMA_CALIBRATION_3        = "Plasma Calibration III",
    VT_SHIELD_MATRIX_1             = "Shield Matrix I",
    VT_SHIELD_MATRIX_2             = "Shield Matrix II",
    VT_SHIELD_MATRIX_3             = "Shield Matrix III",
    VT_SHIELD_MATRIX_TOOLTIP       = "Soldiers: +15 maximum psi shield per level. Armor and integrity are permanent - only the psi shield regenerates.",
    VT_PLASMA_CALIBRATION_TOOLTIP  = "Plasma weapons: +10% damage per level.",

    VT_CARBINE                     = "Plasma Carbine",
    VT_BLADE                       = "Psionic Blade",
    VT_KNIFE                       = "Psionic Knife",
    VT_ECHO_PULSE                  = "Echo Scanner",
    VT_CLAWS                       = "Bio-Construct Claws",
    VT_SINGULARITY_LAUNCHER        = "Singularity Launcher",

    VT_MSG_REQUISITION             = "The Archon decrees: REQUISITION MANDATE. Build faster!",
    VT_MSG_RELENTLESS              = "The Archon decrees: RELENTLESS ADVANCE. Weapons overcharged!",
    VT_MSG_QUOTA_FULL              = "Caste quota full - synthesized as Vanguard.",
    VT_MSG_CASTE_LOCKED            = "Caste not yet authorized by the Synthesis Chamber - synthesized as Vanguard.",
    VT_MSG_NO_RES                  = "Not enough team resources to synthesize that caste - synthesized as Vanguard.",
    VT_MSG_NO_SPAWN                = "No Synthesis Chamber or Nexus is online - the matrix cannot synthesize you!",

    VT_VOTE_MATCHUP                = "Vote faction matchup",
    VT_VOTE_MATCHUP_QUERY          = "Change the faction matchup to %s?",
    VT_MSG_MATCHUP_NOW             = "Faction matchup: %s. Reloading the map...",
    VT_MSG_MATCHUP_NEXT            = "Faction matchup: %s - starts with the next map.",

    VT_OBELISK                     = "Sentinel Obelisk",
    VT_OBELISK_TOOLTIP             = "Psionic beam turret: a steady beam on one target. Fires only while standing inside the Subvention field - no battery needed.",
    VT_OBELISK_PRISM               = "Prism Lens",
    VT_OBELISK_PRISM_TOOLTIP       = "Upgrades this Obelisk: up to 2 beams. 1 beam 115% damage, 2 beams 90% each.",
    VT_OBELISK_TRINITY             = "Trinity Lens",
    VT_OBELISK_TRINITY_TOOLTIP     = "Upgrades this Obelisk (needs the Prism Lens): up to 3 beams. 1 beam 130%, 2 beams 90% each, 3 beams 70% each.",
    VT_OBELISK_FOCUS               = "Focus Beam",
    VT_OBELISK_FOCUS_TOOLTIP       = "Click an enemy: the selected Obelisks lock their first beam on it while it is in range. Click the ground to release.",
    VT_OBELISK_BEAMS1              = "Single Beam",
    VT_OBELISK_BEAMS1_TOOLTIP      = "One beam at full power (100%, 115% with the Prism Lens, 130% with the Trinity Lens).",
    VT_OBELISK_BEAMS2              = "Split Beam (2)",
    VT_OBELISK_BEAMS2_TOOLTIP      = "Two beams on two different targets, 90% damage each. Needs the Prism Lens.",
    VT_OBELISK_BEAMS3              = "Split Beam (3)",
    VT_OBELISK_BEAMS3_TOOLTIP      = "Three beams on three different targets, 70% damage each. Needs the Trinity Lens.",
    VT_SPIRE                       = "Psionic Spire",
    VT_SPIRE_TOOLTIP               = "Psionic research: cloaking, hacking and Directive upgrades.",
    VT_RESONANT_PYLON              = "Resonant Pylon",
    VT_RESONANT_PYLON_TOOLTIP      = "Upgrades this Pylon: field radius 11 -> 15 m and +50% shield regeneration inside it.",
    VT_AEGIS_ARRAY                 = "Aegis Array",
    VT_AEGIS_ARRAY_TOOLTIP         = "Upgrades this Shield Generator: its aura also halves ranged damage taken by soldiers.",
    VT_THRONE                      = "Archon's Throne",
    VT_THRONE_TOOLTIP              = "Unlocks the Directive Iron Discipline.",
    VT_PHASECLOAK                  = "Phase Cloak",
    VT_PHASECLOAK_TOOLTIP          = "Infiltrator cloaking field lasts 15 s instead of 10 s.",
    VT_OVERRIDE                    = "Neural Override",
    VT_OVERRIDE_TOOLTIP            = "Infiltrator hack pulse: 9 m radius, structures stay disabled for 15 s.",
    VT_PSI_EDICTS                  = "Psionic Edicts",
    VT_PSI_EDICTS_TOOLTIP          = "Directives last 50% longer and recharge 25% faster.",
    VT_EDICT_IRON                  = "Directive: Iron Discipline",
    VT_EDICT_IRON_TOOLTIP          = "For 20 seconds all imperial soldiers take 23% less damage. Requires the Archon's Throne.",
    VT_MSG_IRON                    = "The Archon decrees: IRON DISCIPLINE. Hold the line!",
    VT_QUOTA_MENU                  = "Caste Quotas",
    VT_SHIELD_PULSE                = "Shield Pulse",
    VT_SHIELD_PULSE_TOOLTIP        = "Instantly recharges the shields of all soldiers within 6 m of the target point.",
    VT_NEXUS_RECALL                = "Nexus Recall",
    VT_NEXUS_RECALL_TOOLTIP        = "Teleports the targeted soldier to the nearest Nexus Gate.",

    VT_NEXUS_GATE                  = "Nexus Gate",
    VT_NEXUS_GATE_TOOLTIP          = "Once upgraded, any soldier can teleport here from any Pylon on the map: press E on a Pylon and pick the gate.",
    VT_NEXUS_GATE_UPGRADE          = "Upgrade to Nexus Gate",

    VT_MODULE_1                    = "Shield Boost",
    VT_MODULE_2                    = "Phase Dash",
    VT_MODULE_3                    = "Shield Overdrive",
    VT_PRIMARY_1                   = "Standard plasma",
    VT_PRIMARY_2                   = "Overcharge Core",
    VT_SECONDARY_1                 = "None",
    VT_SECONDARY_2                 = "Singularity Launcher",
}

function VT_GetString(key)
    return kVTStrings[key] or key
end

-- Vanilla keys shown differently to Vael'Thor players only. Empty since Plasma
-- Calibration / Shield Matrix have their own tech ids; kept for future relabels.
kVTViewerOverrides =
{
}

local function GetLocalIsVT()
    return Client.GetLocalClientTeamNumber and kVTTeamIndex ~= kVTNoTeam
            and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end

if Client and Locale and Locale.ResolveString then
    local oldResolveString = Locale.ResolveString
    Locale.ResolveString = function(key, ...)
        local s = kVTStrings[key]
        if s then
            return s
        end
        local override = kVTViewerOverrides[key]
        if override and GetLocalIsVT() then
            return kVTStrings[override]
        end
        -- Team names (scoreboard, team join, ...) for everyone: team 1 is the Vael'Thor
        -- unless the match is vanilla; in Vael'Thor vs. Marines team 2 is the marines.
        if (key == "NAME_TEAM_1" or key == "NAME_TEAM_2") and VT_GetMatchup then
            local matchup = VT_GetMatchup()
            if key == "NAME_TEAM_1" and matchup ~= kVTMatchup.MarinesVsAliens then
                return kVTFactionName
            elseif key == "NAME_TEAM_2" and matchup == kVTMatchup.VTvsMarines then
                return oldResolveString("NAME_TEAM_1", ...)
            end
        end
        return oldResolveString(key, ...)
    end
end
