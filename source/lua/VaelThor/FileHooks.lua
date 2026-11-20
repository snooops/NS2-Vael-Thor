-- ============================================================================
-- Vael'Thor Empire - file hooks
--
-- The Vael'Thor replace the TSA Marines as team 1. The team keeps the engine's
-- marine team *type* (so the marine commander UI, HUD, scoreboard colours and
-- network relevancy keep working) but every gameplay system is swapped out:
-- spawning, power, classes, tech tree, commander buttons and damage rules.
-- ============================================================================

local H = "lua/VaelThor/Hooks/"

-- Predict VM: register vanilla's server/client-only "hitreg" message too, so network message ids match the
-- other VMs (otherwise every Vael'Thor message has the wrong id in the Predict VM).
ModLoader.SetupFileHook("lua/Hitreg.lua",            H .. "Hitreg.lua",          "post")

-- Skin lookups keyed by class name: alias Vael'Thor classes to marine ones.
ModLoader.SetupFileHook("lua/Globals.lua",           H .. "Cosmetics.lua",       "post")
ModLoader.SetupFileHook("lua/MarineVariantMixin.lua", H .. "MarineVariantMixin.lua", "post")

-- Must run before any network class registers an "enum kTechId" field.
ModLoader.SetupFileHook("lua/TechTreeConstants.lua", H .. "Globals.lua",         "post")

ModLoader.SetupFileHook("lua/DamageTypes.lua",       H .. "DamageTypes.lua",     "post")
-- Plasma bolt impacts (half-size railgun impact, scorch decal, ricochet sound).
ModLoader.SetupFileHook("lua/DamageEffects.lua",     H .. "DamageEffects.lua",   "post")
ModLoader.SetupFileHook("lua/TechData.lua",          H .. "TechData.lua",        "post")
ModLoader.SetupFileHook("lua/TechTreeButtons.lua",   H .. "TechTreeButtons.lua", "post")
ModLoader.SetupFileHook("lua/ConstructMixin.lua",    H .. "ConstructMixin.lua",  "post")
ModLoader.SetupFileHook("lua/MarineCommander.lua",   H .. "MarineCommander.lua", "post")
-- Infestation corrodes the psi shield of empire structures instead of their (permanent) armor.
ModLoader.SetupFileHook("lua/CorrodeMixin.lua",      H .. "CorrodeMixin.lua",    "post")
ModLoader.SetupFileHook("lua/PowerPoint.lua",        H .. "PowerPoint.lua",      "post")
ModLoader.SetupFileHook("lua/NS2Utility.lua",        H .. "NS2Utility.lua",      "post")
ModLoader.SetupFileHook("lua/WeldableMixin.lua",     H .. "WeldableMixin.lua",   "post")
-- Infiltrator cloak field: always exactly 100%, any reveal ends it.
ModLoader.SetupFileHook("lua/CloakableMixin.lua",    H .. "CloakableMixin.lua",  "post")
ModLoader.SetupFileHook("lua/TeamMixin.lua",         H .. "TeamMixin.lua",       "post")
-- Hacked Shades stop cloaking.
ModLoader.SetupFileHook("lua/Shade.lua",             H .. "Shade.lua",           "post")
-- Clientless players (spawn cheat) crashed the auto-order timer every second.
ModLoader.SetupFileHook("lua/OrderSelfMixin.lua",    H .. "OrderSelfMixin.lua",  "post")
-- Dead Vael'Thor players (VTSpectator) joining the ready room asserted "Player isn't on team!".
ModLoader.SetupFileHook("lua/ReadyRoomTeam.lua",     H .. "ReadyRoomTeam.lua",   "post")

-- HUD: no corner minimap for the Vael'Thor (marine HUD).
ModLoader.SetupFileHook("lua/Hud/Marine/GUIMarineHUD.lua", H .. "GUIMarineHUD.lua", "post")
ModLoader.SetupFileHook("lua/GUIClassicAmmo.lua", H .. "GUIClassicAmmo.lua", "post")
-- No "Hold G to eject" badge for the Praetor (every Exo shows it since the 2026-11-17 game update).
ModLoader.SetupFileHook("lua/GUIExoEject.lua",    H .. "GUIExoEject.lua",     "post")
-- Damage numbers / world texts in Vael'Thor colours for Vael'Thor players.
ModLoader.SetupFileHook("lua/GUIWorldText.lua",    H .. "GUIWorldText.lua",    "post")
-- UI team checks: vanilla compares team number with team type (Vael'Thor on team 2 looked alien).
ModLoader.SetupFileHook("lua/Player_Client.lua",  H .. "Player_Client.lua",   "post")
-- Commander research strip: vanilla passes the team type as team index (breaks the team-2 commander).
ModLoader.SetupFileHook("lua/GUIProduction.lua",  H .. "GUIProduction.lua",   "post")
-- Tech map (J): Vael'Thor layout instead of the marine tree (vanilla picks it by team type).
ModLoader.SetupFileHook("lua/GUITechMap.lua",    H .. "GUITechMap.lua",      "post")
-- Commander ghost preview of the (scaled) Vael'Thor buildings.
ModLoader.SetupFileHook("lua/GhostModelUI.lua",   H .. "GhostModelUI.lua",    "post")

-- Voice menu (Z / X) for the voiced castes (Vanguard), Classes/VTVoice.lua.
ModLoader.SetupFileHook("lua/VoiceOver.lua",        H .. "VoiceOver.lua",       "post")

-- Bots: turn-speed table is keyed by class name and has no fallback.
ModLoader.SetupFileHook("lua/bots/BotAim.lua",      H .. "BotAim.lua",          "post")

-- All Vael'Thor entity classes. Loaded once every base class exists, in every
-- VM (Client, Server, Predict) so network class registration stays in sync.
ModLoader.SetupFileHook("lua/Shared.lua",            "lua/VaelThor/Classes.lua", "post")
