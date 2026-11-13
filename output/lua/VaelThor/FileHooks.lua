-- ============================================================================
-- Vael'Thor Empire - file hooks
--
-- The Vael'Thor replace the TSA Marines as team 1. The team keeps the engine's
-- marine team *type* (so the marine commander UI, HUD, scoreboard colours and
-- network relevancy keep working) but every gameplay system is swapped out:
-- spawning, power, classes, tech tree, commander buttons and damage rules.
-- ============================================================================

local H = "lua/VaelThor/Hooks/"

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

-- HUD: no corner minimap for the Vael'Thor (marine HUD).
ModLoader.SetupFileHook("lua/Hud/Marine/GUIMarineHUD.lua", H .. "GUIMarineHUD.lua", "post")
ModLoader.SetupFileHook("lua/GUIClassicAmmo.lua", H .. "GUIClassicAmmo.lua", "post")
-- Damage numbers / world texts in Vael'Thor colours for Vael'Thor players.
ModLoader.SetupFileHook("lua/GUIWorldText.lua",    H .. "GUIWorldText.lua",    "post")
-- Commander ghost preview of the (scaled) Vael'Thor buildings.
ModLoader.SetupFileHook("lua/GhostModelUI.lua",   H .. "GhostModelUI.lua",    "post")

-- Bots: turn-speed table is keyed by class name and has no fallback.
ModLoader.SetupFileHook("lua/bots/BotAim.lua",      H .. "BotAim.lua",          "post")

-- All Vael'Thor entity classes. Loaded once every base class exists, in every
-- VM (Client, Server, Predict) so network class registration stays in sync.
ModLoader.SetupFileHook("lua/Shared.lua",            "lua/VaelThor/Classes.lua", "post")
