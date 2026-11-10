-- ============================================================================
-- Vael'Thor Empire - Infiltrator cloak field: always 100%
-- (post-hook of lua/CloakableMixin.lua)
--
-- Vanilla cloak never reaches 1 for players (local cap kPlayerMaxCloak = 0.88)
-- and loses up to 0.8 with movement; anything between 0 and 1 shows the
-- distortion shimmer to enemies. While an entity reports VT_GetForceFullCloak()
-- (Infiltrator with the cloak field active) the cloak is set to exactly 1 after
-- the mixin's own update - instantly, moving or not, on server and every client
-- (they all derive it from the networked field end time).
-- Anything that reveals a cloaked unit (attacking, hacking, Echo scanning,
-- taking damage, touching an enemy) goes through TriggerUncloak, which now ends
-- the field outright: the cloak is either 100% or off.
-- ============================================================================

if CloakableMixin and not VT_HookedCloakableMixin then
VT_HookedCloakableMixin = true

local function ForceFull(self)
    if self.VT_GetForceFullCloak and self:VT_GetForceFullCloak() then
        self.desiredCloakFraction = 1
        self.cloakFraction = 1
        self.cloakingDesired = true
        self.speedScalar = 0
        if Server then
            self.fullyCloaked = true
        end
    end
end

for _, name in ipairs({ "OnUpdate", "OnProcessMove", "OnProcessSpectate" }) do
    local original = CloakableMixin[name]
    CloakableMixin[name] = function(self, ...)
        original(self, ...)
        ForceFull(self)
    end
end

local oldTriggerUncloak = CloakableMixin.TriggerUncloak
function CloakableMixin:TriggerUncloak(...)
    oldTriggerUncloak(self, ...)
    if Server and self.VT_OnUncloakTriggered then
        self:VT_OnUncloakTriggered()
    end
end

end -- VT_HookedCloakableMixin
