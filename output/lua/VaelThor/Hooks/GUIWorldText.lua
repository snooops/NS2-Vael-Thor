-- ============================================================================
-- Vael'Thor Empire - damage numbers and world texts in Vael'Thor colours
-- (post-hook of lua/GUIWorldText.lua, client)
--
-- Vanilla colours damage numbers with the "marine" advanced option (dmgcolor_m,
-- default marine blue 0x4DDBFF) and other world texts (resources gained, ...)
-- with kMarineTeamColorFloat whenever the local player is on a marine-type team.
-- For a Vael'Thor player both become violet - in every matchup. A damage colour
-- the player picked in the options is kept.
-- ============================================================================

if GUIWorldText and not VT_HookedWorldText then
VT_HookedWorldText = true

local kVanillaMarineDamageColor = ColorIntToColor(0x4DDBFF)   -- AdvancedOptions dmgcolor_m default

local function IsVanillaDefault(c)
    local d = kVanillaMarineDamageColor
    return c and math.abs(c.r - d.r) < 0.01 and math.abs(c.g - d.g) < 0.01 and math.abs(c.b - d.b) < 0.01
end

local oldUpdate = GUIWorldText.Update
function GUIWorldText:Update(deltaTime)

    if not (VT_GetLocalIsVT and VT_GetLocalIsVT() and kVTDamageColor) then
        return oldUpdate(self, deltaTime)
    end

    -- swap in the Vael'Thor colours for this update only (vanilla reads both at runtime)
    local damageColor = GUIWorldText.kMarineDamageColor
    local teamColor = kMarineTeamColorFloat
    if IsVanillaDefault(damageColor) then
        GUIWorldText.kMarineDamageColor = Color(kVTDamageColor)
    end
    kMarineTeamColorFloat = kVTTeamColorFloat

    local ok, err = pcall(oldUpdate, self, deltaTime)

    GUIWorldText.kMarineDamageColor = damageColor
    kMarineTeamColorFloat = teamColor
    if not ok then
        error(err, 0)
    end

end

end
