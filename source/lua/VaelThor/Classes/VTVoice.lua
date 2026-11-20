-- ============================================================================
-- Vael'Thor unit voice lines (shared: sounds must be precached on the server too).
--
-- Recorded per caste (docs/unit_voice_lines.md), built into the mod's own bank by art/sound/build_sounds.sh as
-- "sound/vaelthor.fev/<caste>/<line>_NN", one event per take. A line plays a random take (never the same one twice
-- in a row) on the soldier, positional, for everyone.
--
-- Triggers:
--   voice menu (Z / X, and the voice-over keys)  -> Hooks/VoiceOver.lua (menu), Server.lua (CreateVoiceMessage)
--   synthesized                                  -> VTTeam:SynthesizePlayer
--   commander order acknowledged                 -> Server.lua (MarineCommander:OrderEntities)
--   order complete (only the soldier hears it)   -> VTVanguard:OnOrderSelfComplete (client)
--   kill / death                                 -> Server.lua (NS2Gamerules:OnEntityKilled)
--   under fire / carbine drained                 -> VT_UpdateVoice (from VTVanguard:OnProcessMove)
--   module (Phase Dash / Shield Overdrive)       -> VTVanguard:VT_UseAbility
-- ============================================================================

-- caste class name -> { bank group, line -> number of takes }
kVTVoiceLines =
{
    VTVanguard =
    {
        group = "vanguard",
        lines =
        {
            spawn = 3, ack = 4, done = 2, req_orders = 2, req_shield = 2, req_weapon = 1, follow = 2, move = 2,
            cover = 2, spotted = 3, build = 1, taunt = 3, kill = 3, hit = 2, energy = 1, dash = 3, overdrive = 2,
            death = 3,
        },
    },
}

-- Automatic lines: chance to speak, and the minimum time before the same line can play again (seconds).
-- Voice menu lines always play (the menu has its own send limit).
kVTVoiceRules =
{
    spawn     = { chance = 1.0,  cooldown = 0  },
    ack       = { chance = 1.0,  cooldown = 3  },
    done      = { chance = 1.0,  cooldown = 3  },
    kill      = { chance = 0.4,  cooldown = 8  },
    hit       = { chance = 0.35, cooldown = 12 },
    energy    = { chance = 1.0,  cooldown = 20 },
    dash      = { chance = 0.6,  cooldown = 4  },
    overdrive = { chance = 1.0,  cooldown = 0  },
}
kVTVoiceBusyTime = 2.2     -- automatic lines don't talk over the previous line for this long

-- Vanilla voice menu id -> line, per caste (the menu entries themselves are in Hooks/VoiceOver.lua).
kVTVoiceRequestLines =
{
    VTVanguard =
    {
        MarineRequestMedpack   = "req_shield",
        MarineRequestAmmo      = "req_weapon",
        MarineRequestOrder     = "req_orders",
        MarineRequestStructure = "build",
        MarineTaunt            = "taunt",
        MarineTauntExclusive   = "taunt",
        MarineCovering         = "cover",
        MarineFollowMe         = "follow",
        MarineLetsMove         = "move",
        MarineHostiles         = "spotted",
        MarineAcknowledged     = "ack",
    },
}

local sounds = {}   -- class name -> line -> { asset, ... }
for className, voice in pairs(kVTVoiceLines) do
    sounds[className] = {}
    for line, takes in pairs(voice.lines) do
        local list = {}
        for i = 1, takes do
            list[i] = PrecacheAsset(string.format("sound/vaelthor.fev/%s/%s_%02d", voice.group, line, i))
        end
        sounds[className][line] = list
    end
end

local function GetVoiceClass(entity)
    if not entity or not entity.GetClassName then
        return nil
    end
    local className = entity:GetClassName()
    return sounds[className] and className or nil
end

function VT_GetHasVoice(entity)
    return GetVoiceClass(entity) ~= nil
end

-- A random take of the line, never the one this entity played last.
local function PickTake(entity, className, line)
    local list = sounds[className][line]
    if not list or #list == 0 then
        return nil
    end
    entity.vtVoiceLastTake = entity.vtVoiceLastTake or {}
    local last = entity.vtVoiceLastTake[line]
    local index = math.random(1, #list)
    if #list > 1 and index == last then
        index = index % #list + 1
    end
    entity.vtVoiceLastTake[line] = index
    return list[index]
end

-- Line for a vanilla voice menu id, or nil when this soldier has no own line for it.
function VT_GetVoiceRequestLine(player, voiceId)
    local className = GetVoiceClass(player)
    local map = className and kVTVoiceRequestLines[className]
    local name = map and voiceId and kVoiceId and kVoiceId[voiceId]
    return name and map[name] or nil
end

-- Plays a line on the soldier. options.force skips chance, cooldown and the busy check (voice menu, death).
-- options.origin plays it at a fixed point instead (the dying soldier is replaced right away).
-- Server: heard by everyone. Client: only by this client (order complete).
function VT_PlayVoice(entity, line, options)

    local className = GetVoiceClass(entity)
    if not className or not sounds[className][line] then
        return false
    end

    options = options or {}
    local now = Shared.GetTime()

    if not options.force then
        local rule = kVTVoiceRules[line] or {}
        if (entity.vtVoiceBusyUntil or 0) > now then
            return false
        end
        entity.vtVoiceNext = entity.vtVoiceNext or {}
        if (entity.vtVoiceNext[line] or 0) > now then
            return false
        end
        if math.random() > (rule.chance or 1) then
            return false
        end
        entity.vtVoiceNext[line] = now + (rule.cooldown or 0)
    end

    local asset = PickTake(entity, className, line)
    if not asset then
        return false
    end
    entity.vtVoiceBusyUntil = now + kVTVoiceBusyTime

    if options.origin then
        StartSoundEffectAtOrigin(asset, options.origin)
    else
        StartSoundEffectOnEntity(asset, entity)
    end
    return true

end

-- Per-move checks on the server (VTVanguard:OnProcessMove): taking damage, carbine cell running dry.
function VT_UpdateVoice(player)

    if not Server or not player:GetIsAlive() then
        return
    end

    local damageTime = player.GetTimeOfLastDamage and player:GetTimeOfLastDamage()
    if damageTime and damageTime ~= player.vtVoiceSeenDamage then
        player.vtVoiceSeenDamage = damageTime
        VT_PlayVoice(player, "hit")
    end

    local carbine = VTPlasmaCarbine and player:GetWeapon(VTPlasmaCarbine.kMapName)
    if carbine then
        local clip = carbine.clip or 0
        if clip <= 0 and (player.vtVoiceLastClip or 0) > 0
                and not (VT_GetIsPointInField and VT_GetIsPointInField(player:GetOrigin())) then
            VT_PlayVoice(player, "energy")
        end
        player.vtVoiceLastClip = clip
    end

end

-- The vanilla marine death scream would play on top of our death line (effect components match classnames with
-- isa): an empty "stop" component for every voiced caste goes FIRST in the death blocks that have a Marine sound
-- component (cinematic / ragdoll blocks stay untouched; same trick as the Artificer, Hooks/DamageEffects.lua; components are baked by AddEffectData, so the
-- stop component is made through it too). The order-complete voice is replaced in VTVanguard:OnOrderSelfComplete.
do
    local manager = GetEffectManager and GetEffectManager()
    local data = manager and manager.data
    if data and not VT_PatchedVoiceEffects then
        VT_PatchedVoiceEffects = true
        local patched = 0
        for className in pairs(kVTVoiceLines) do
            manager:AddEffectData("VaelThorVoiceStop", {
                vt_voice_stop_template = { stop = { { sound = "", classname = className, done = true } } },
            })
            local template = data.vt_voice_stop_template
            local stop = template and template[1] and template[1][1]
            data.vt_voice_stop_template = nil
            if stop then
                for _, block in ipairs(data.death or {}) do
                    for _, component in ipairs(block) do
                        if component.classname == "Marine" and component.assetType == "sound" then
                            table.insert(block, 1, stop)
                            patched = patched + 1
                            break
                        end
                    end
                end
            end
        end
        if patched == 0 then
            Shared.Message("[Vael'Thor] warning: no marine death sound effect found to silence for voiced castes")
        end
    end
end
