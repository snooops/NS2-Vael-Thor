-- ============================================================================
-- Vael'Thor Empire - network message ids in the Predict VM (post-hook of lua/Hitreg.lua)
--
-- Vanilla registers the "hitreg" debug message only on the server and the client
-- (Hitreg.lua: local register = (Server or Client) and ...). Network message ids follow the registration order,
-- so in the client's Predict VM every message registered after it has an id one lower than on the server: a few
-- vanilla debug messages and all of the Vael'Thor's. The Predict VM then decoded VTBoltImpact (sent on every
-- plasma bolt hit) as VTMatchup and never saw the real VTMatchup (found 2026-11-14 by logging the registration
-- order in every VM: server = client = 108 messages, Predict 107, "hitreg" missing at position 99).
-- Registering the same message here, right where vanilla does on the other VMs, lines the ids up again. The
-- Predict VM never hooks or receives it. Layout copied from Hitreg.lua (hitregNetworkVars; both string lengths
-- are file-local constants = 500 there).
-- ============================================================================
if Predict and not VT_RegisteredPredictHitreg then
VT_RegisteredPredictHitreg = true

Shared.RegisterNetworkMessage("hitreg",
{
    moveSerial     = "integer",
    time           = "float",
    hitSerial      = "integer (0 to 255)",
    hit            = "boolean",
    entity         = "entityid",
    entity_data    = "string (500)",
    entity_anim    = "string (500)",
    trace_start    = "vector",
    trace_end      = "vector",
    trace_fraction = "float",
})

end
