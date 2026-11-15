-- ============================================================================
-- Vael'Thor Empire - dead soldiers going to the ready room
-- (post-hook of lua/ReadyRoomTeam.lua)
--
-- A dead Vael'Thor player is a VTSpectator. Vanilla only maps its own
-- spectator classes to the previous life form, so the ready room tried to
-- respawn a "vt_spectator" - and VTSpectator forces itself onto the Vael'Thor
-- team on creation. Team:RespawnPlayer then asserted "Player isn't on team!"
-- (playtest 2026-11-15, 35x) and the player stayed a Vael'Thor spectator
-- instead of reaching the ready room. Dead Vael'Thor players become plain
-- ready room players.
-- ============================================================================

if ReadyRoomTeam and not VT_HookedReadyRoomTeam then
VT_HookedReadyRoomTeam = true

local oldGetRespawnMapName = ReadyRoomTeam.GetRespawnMapName
function ReadyRoomTeam:GetRespawnMapName(player)
    local mapName = oldGetRespawnMapName(self, player)
    if mapName == kVTMapNames.Spectator then
        mapName = ReadyRoomPlayer.kMapName
    end
    return mapName
end

end -- VT_HookedReadyRoomTeam
