-- ============================================================================
-- Vael'Thor Empire - weapon view-material index lookup by class name
-- (post-hook of lua/MarineVariantMixin.lua; aliases from Hooks/Cosmetics.lua)
-- Separate file on purpose: Script.Load runs each path only once, so one hook
-- file cannot be attached to two vanilla files.
-- ============================================================================

if GetMaterialIndexPerWeapon and not VT_HookedMaterialIndex then
    VT_HookedMaterialIndex = true
    local oldGetMaterialIndexPerWeapon = GetMaterialIndexPerWeapon
    function GetMaterialIndexPerWeapon(wepClass, ...)
        return oldGetMaterialIndexPerWeapon(VT_GetCosmeticClassName(wepClass), ...)
    end
end
