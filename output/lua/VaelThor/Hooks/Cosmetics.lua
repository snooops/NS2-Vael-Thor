-- ============================================================================
-- Vael'Thor Empire - cosmetic (skin) lookups
-- (post-hooks of lua/Globals.lua and lua/MarineVariantMixin.lua)
--
-- The marine skin system keys its material tables by class name ("Rifle",
-- "Axe", ...). Vael'Thor subclasses reuse the marine models, so they borrow
-- the skins of the class they are prototyped on.
-- ============================================================================

kVTCosmeticClassAliases =
{
    VTPlasmaCarbine       = "Rifle",
    VTPsionicBlade        = "Axe",
    VTSubjectClaws        = "Axe",
    VTPsionicKnife        = "Axe",
    VTSingularityLauncher = "GrenadeLauncher",
    VTPlasmaMinigun       = "Minigun",
    VTEchoPulse           = "Builder",

    VTVanguard            = "Marine",
    VTInfiltrator         = "Marine",
    VTSubject             = "Marine",
    VTPraetor             = "Exo",

    VTNexus               = "CommandStation",
    VTSiphon              = "Extractor",
    VTSubventionPylon     = "SentryBattery",
    VTSynthesisChamber    = "ArmsLab",
    VTShieldGenerator     = "Observatory",
    VTRiftPortal          = "PhaseGate",
    VTSentinelObelisk     = "Sentry",
    VTPsionicSpire        = "PrototypeLab",
}

function VT_GetCosmeticClassName(className)
    return className and kVTCosmeticClassAliases[className] or className
end

-- Weapons with their own models: whatever skin the player owns, the skin system gets the weapon's own
-- material back, so an equipped rifle/axe skin can't paint marine textures onto the Falcon or the knife
-- (it was sampled with the knife's UVs -> striped blade in first person).
-- Override materials must be precached (like vanilla's kPrecachedCosmeticMaterials); an override with a
-- non-precached material renders as the yellow/black missing-material pattern.
kVTOwnWeaponMaterials =
{
    VTPlasmaCarbine = { world = PrecacheAsset("models/vaelthor/falcon/falcon.material"),
                        view  = PrecacheAsset("models/vaelthor/falcon/falcon_view.material") },
    VTPsionicKnife  = { world = PrecacheAsset("models/vaelthor/knife/knife.material"),
                        view  = PrecacheAsset("models/vaelthor/knife/knife_view.material") },
    VTPsionicBlade  = { world = PrecacheAsset("models/vaelthor/blades/blades_hidden.material"),
                        view  = PrecacheAsset("models/vaelthor/blades/blades_view.material") },
    VTSubjectClaws  = { world = PrecacheAsset("models/vaelthor/blades/blades_hidden.material"),
                        view  = PrecacheAsset("models/vaelthor/claws/claws_view.material") },
}

if GetPrecachedCosmeticMaterial and not VT_HookedCosmeticMaterial then
    VT_HookedCosmeticMaterial = true
    local oldGetPrecachedCosmeticMaterial = GetPrecachedCosmeticMaterial
    function GetPrecachedCosmeticMaterial(className, variantId, viewOnly, ...)
        local own = className and kVTOwnWeaponMaterials[className]
        if own then
            return viewOnly and own.view or own.world
        end
        return oldGetPrecachedCosmeticMaterial(VT_GetCosmeticClassName(className), variantId, viewOnly, ...)
    end
end
