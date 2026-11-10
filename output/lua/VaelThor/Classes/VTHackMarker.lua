-- ============================================================================
-- VTHackMarker - tells every client that a structure is hacked by an
-- Infiltrator, so it can be drawn with a pulsing green glow.
--
-- The hack itself is server-side (target.vtHackedUntil, see Hooks/NS2Utility).
-- One marker per hacked structure; a re-hack extends the existing marker.
-- ============================================================================

class 'VTHackMarker' (Entity)

VTHackMarker.kMapName = "vt_hackmarker"

kVTHackGlowMaterial = PrecacheAsset("materials/vaelthor/hack_glow.material")
kVTHackLightColor   = Color(0.25, 1.0, 0.35)

local networkVars =
{
    targetId = "entityid",
    endTime  = "time",
}

function VTHackMarker:OnCreate()

    Entity.OnCreate(self)

    self.targetId = Entity.invalidId
    self.endTime = 0

    if Server then
        self:SetPropagate(Entity.Propagate_Always)
        self:SetUpdates(true)
    end

end

function VTHackMarker:GetTarget()
    return self.targetId ~= Entity.invalidId and Shared.GetEntity(self.targetId) or nil
end

function VTHackMarker:GetIsActive()
    return Shared.GetTime() < self.endTime and self:GetTarget() ~= nil
end

if Server then

    function VTHackMarker:OnUpdate(deltaTime)
        local target = self:GetTarget()
        if Shared.GetTime() >= self.endTime or not target or (target.GetIsAlive and not target:GetIsAlive()) then
            DestroyEntity(self)
        end
    end

    -- Hack a structure until endTime and show it to every client.
    function VT_MarkHacked(target, endTime)

        target.vtHackedUntil = endTime
        if target.VT_OnHacked then
            target:VT_OnHacked()            -- e.g. Shade: reveal its cloak field at once (Hooks/Shade.lua)
        end

        local targetId = target:GetId()
        for _, marker in ientitylist(Shared.GetEntitiesWithClassname("VTHackMarker")) do
            if marker.targetId == targetId then
                marker.endTime = math.max(marker.endTime, endTime)
                return marker
            end
        end

        local marker = Server.CreateEntity(VTHackMarker.kMapName)
        marker.targetId = targetId
        marker.endTime = endTime
        return marker

    end

end

Shared.LinkClassToMap("VTHackMarker", VTHackMarker.kMapName, networkVars)
