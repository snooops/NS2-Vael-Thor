-- ============================================================================
-- Vael'Thor warp-in construction (user design 2026-11-18, Protoss style)
--
-- A placed Vael'Thor building is a warp field (a small singularity) until it has been warped in:
--   * the warp progresses while a living soldier is within kVTAutoBuildRadius (VTTeam:UpdateAutoConstruction)
--   * with nobody near, the field degenerates: vtWarpStability drains from 1 to 0 in kVTWarpCollapseTime (10 s);
--     a soldier coming back restores it (kVTWarpRecoverScalar times as fast). At 0 the field collapses: the
--     structure is removed and its cost is lost.
--   * warp fields are indestructible (GetCanTakeDamageOverride = false until built)
--   * no blueprint stage: vanilla marine structures start as ghost structures (GhostStructureMixin: nothing
--     happens until someone builds, enemies nearby cancel them with a refund, the commander can cancel for 75%).
--     A Vael'Thor building is a warp field the moment it is placed, so ghost mode is switched off in OnCreate
--     (before ObstacleMixin puts it into the pathing mesh, so it gets the structure area right away).
-- Visuals (client): VTBuildingAnim.lua hides the building and draws the singularity (art/effects/build_warp.sh).
-- ============================================================================

kVTWarpNetworkVars =
{
    vtWarpStability = "float (0 to 1 by 0.01)",
}

function VT_AddWarpNetworkVars(networkVars)
    for name, def in pairs(kVTWarpNetworkVars) do
        networkVars[name] = def
    end
    return networkVars
end

-- vanilla sounds (precached here: client-only sound precaches get no index)
kVTWarpInSound     = PrecacheAsset("sound/NS2.fev/marine/structures/infantry_portal_player_spawn")
kVTWarpCollapseSound = PrecacheAsset("sound/NS2.fev/marine/power_node/destroyed_powerdown")

function VT_GetIsGhostStructure(ent)
    return ent.GetIsGhostStructure ~= nil and ent:GetIsGhostStructure()
end

-- true while ent is a warp field (placed, started, not yet built)
function VT_GetIsWarping(ent)
    return ent.vtWarpStability ~= nil and ent.GetIsBuilt ~= nil and not ent:GetIsBuilt() and not VT_GetIsGhostStructure(ent)
end

function VT_InstallWarpField(cls)

    local baseOnCreate = cls.OnCreate
    function cls:OnCreate(...)
        baseOnCreate(self, ...)
        self.vtWarpStability = 1
        if self.isGhostStructure ~= nil then
            self.isGhostStructure = false
        end
    end

    local baseCanTakeDamage = cls.GetCanTakeDamageOverride
    function cls:GetCanTakeDamageOverride()
        if VT_GetIsWarping(self) then
            return false
        end
        return baseCanTakeDamage == nil or baseCanTakeDamage(self)
    end

end
