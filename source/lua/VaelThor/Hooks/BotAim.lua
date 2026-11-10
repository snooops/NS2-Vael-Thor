-- ============================================================================
-- Vael'Thor Empire - bot aim
--
-- BotAim looks up the in-combat turn speed by player class name and does
-- arithmetic on it unguarded, so a bot playing a Vael'Thor class crashed every
-- tick ("aimTurnRate (a nil value)" in BotMotion:GetRotateSpeed). Give the VT
-- classes their vanilla base-class speeds and fall back to "Default" for any
-- class the table doesn't list.
-- ============================================================================

local speeds = BotAim.kBotTurnSpeeds

speeds["VTVanguard"]    = speeds["Marine"]
speeds["VTInfiltrator"] = speeds["Marine"]
speeds["VTSubject"]     = speeds["Marine"]
speeds["VTPraetor"]     = speeds["Exo"]

setmetatable(speeds, { __index = function(t) return rawget(t, "Default") or 1.0 end })
