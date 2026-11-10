-- ============================================================================
-- Vael'Thor Empire - faction matchup vote (loaded by Server.lua and Client.lua)
--
-- Vote menu entry "Vote faction matchup" with three choices (kVTMatchup):
--   Vael'Thor vs. Aliens / Marines vs. Aliens / Vael'Thor vs. Marines
-- Teams are built once per map load (NS2Gamerules:BuildTeam), so a passed vote
-- stores the matchup in config://VaelThorConfig.json and
--   * before the round has started: reloads the current map right away,
--   * during a round: it starts with the next map.
-- Admins: sv_vt_matchup <1|2|3> does the same without a vote.
-- ============================================================================

local kExecuteVoteDelay = 5

RegisterVoteType("VoteVTMatchup", { matchup = "integer (1 to 3)" })

if Client then

    local function GetMatchupOptions()
        local options = {}
        for matchup = 1, #kVTMatchup do
            local name = kVTMatchupNames[matchup]
            if matchup == VT_GetMatchup() then
                name = name .. " (current)"
            end
            options[#options + 1] = { text = name, extraData = { matchup = matchup } }
        end
        return options
    end

    local function SetupMatchupVote(voteMenu)

        local function StartMatchupVote(data)
            AttemptToStartVote("VoteVTMatchup", { matchup = data.matchup })
        end
        voteMenu:AddMainMenuOption(VT_GetString("VT_VOTE_MATCHUP"), GetMatchupOptions, StartMatchupVote)

        AddVoteStartListener("VoteVTMatchup", function(data)
            return string.format(VT_GetString("VT_VOTE_MATCHUP_QUERY"), kVTMatchupNames[data.matchup] or "?")
        end)

    end
    AddVoteSetupCallback(SetupMatchupVote)

end

if Server then

    local function Announce(text)
        Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Vael'Thor", -1, kTeamReadyRoom, kNeutralTeamType, text), true)
        Shared.Message("[Vael'Thor] " .. text)
    end

    -- Store the matchup; reload the map now unless a round is running.
    function VT_SetNextMatchup(matchup)

        if not VT_GetIsValidMatchup(matchup) then
            return false
        end

        VT_SaveMatchupSetting(matchup)        -- own file (Server.lua); ServerConfig.json drops unknown keys

        local gamerules = GetGamerules()
        local name = kVTMatchupNames[matchup]
        if gamerules and gamerules:GetGameStarted() then
            Announce(string.format(VT_GetString("VT_MSG_MATCHUP_NEXT"), name))
        else
            Announce(string.format(VT_GetString("VT_MSG_MATCHUP_NOW"), name))
            MapCycle_ChangeMap(Shared.GetMapName())
        end

        return true

    end

    SetVoteSuccessfulCallback("VoteVTMatchup", kExecuteVoteDelay, function(data)
        VT_SetNextMatchup(data.matchup)
    end)

    local function OnAdminMatchup(client, arg)
        if not VT_SetNextMatchup(tonumber(arg)) then
            local lines = {}
            for matchup = 1, #kVTMatchup do
                lines[#lines + 1] = string.format("%d = %s", matchup, kVTMatchupNames[matchup])
            end
            local usage = "usage: sv_vt_matchup <" .. table.concat(lines, ", ") .. ">"
            if ServerAdminPrint then
                ServerAdminPrint(client, usage)
            else
                Shared.Message(usage)
            end
        end
    end

    if CreateServerAdminCommand then
        CreateServerAdminCommand("Console_sv_vt_matchup", OnAdminMatchup,
                "<1|2|3>, sets the faction matchup (1 Vael'Thor vs. Aliens, 2 Marines vs. Aliens, 3 Vael'Thor vs. Marines)")
    end

end
