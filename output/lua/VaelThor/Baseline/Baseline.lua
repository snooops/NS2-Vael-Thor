-- ============================================================================
-- Vael'Thor isolation - vanilla baseline snapshot
--
-- Loaded by Baseline/FileHooks.lua, which the high-priority entry
-- lua/entry/VaelThorBaseline.entry registers before every other mod. Its hooks
-- run directly after each vanilla file (ModLoader runs pre/post hooks in
-- registration order), so what is captured here is vanilla, not modded:
--   VTBaseline.values    balance constants defined by Balance/BalanceHealth/BalanceMisc
--   VTBaseline.classes   own fields of the marine classes the Vael'Thor inherit from
--   VTBaseline.mixins    the marine-only mixins those classes use
--   VTBaseline.functions single global functions (BuildTechData, ...)
--   VTBaseline.upvalues  file-local "k..." constants (upvalues) of captured functions,
--                        so ReplaceLocals() by other mods can't reach the frozen copies
-- Classes/VTFreeze.lua turns this into frozen copies for the Vael'Thor classes;
-- the console command vt_isolation reports on it (Baseline/Isolation.lua).
-- ============================================================================

if VTBaseline then
    return
end

VTBaseline =
{
    values    = {},   -- name -> number/string/boolean
    valueFile = {},   -- name -> balance file that defined it
    classes   = {},   -- class name -> { field -> value }
    mixins    = {},   -- mixin name -> { field -> value }
    functions = {},   -- global name -> function
    upvalues  = {},   -- function -> { [index] = value }  (captured "k..." scalars only)
    shared    = {},   -- class name -> { field -> shared base name } fields equal to a shared (both-teams) base
    files     = {},   -- vanilla file -> true once its post hook ran
    order     = {},   -- capture order, for the report
}

-- Marine classes the Vael'Thor inherit from (most derived files first is not required).
VTBaseline.kClassNames =
{
    "Marine", "Exo", "ExoWeaponHolder",
    "ClipWeapon", "Rifle", "Axe", "Minigun", "GrenadeLauncher", "Grenade", "Builder", "Welder",
    "CommandStructure", "CommandStation", "ResourceTower", "Extractor",
    "SentryBattery", "ArmsLab", "Observatory", "Sentry", "PrototypeLab",
    "MarineTeam", "MarineSpectator",
}

-- Mixins only marine-side entities use (LaserMixin is never loaded by vanilla). Not here on purpose:
--   * the receiving end of alien abilities (Parasite, Webable, Stun, Disorientable,
--     Corrode): alien mods may change what aliens do to anyone;
--   * mixins the Vael'Thor patch themselves (OrderSelfMixin, WeldableMixin);
--   * mixins both teams use (Live, Construct, Cloakable, ...).
VTBaseline.kMixinNames =
{
    "AutoWeldMixin", "AxeVariantMixin", "BuilderVariantMixin", "BulletsMixin", "CatPackMixin",
    "DetectorMixin", "ExoVariantMixin", "ExoWeaponSlotMixin", "ExtractorVariantMixin",
    "GhostStructureMixin", "GrenadeLauncherVariantMixin", "LadderMoveMixin",
    "MarineActionFinderMixin", "MarineOutlineMixin", "MarineStructureVariantMixin",
    "MarineVariantMixin", "NanoShieldMixin", "PhaseGateUserMixin", "PickupableWeaponMixin",
    "PowerConsumerMixin", "RecycleMixin", "RegenerationMixin", "RifleVariantMixin",
    "SprintMixin", "WelderVariantMixin",
}

-- Global functions the Vael'Thor build their data from.
VTBaseline.kFunctionNames = { "BuildTechData", "NS2Gamerules_GetUpgradedDamageScalar" }

-- Bases both teams share: a marine class field equal to one of these is not marine-specific
-- and is not frozen (a mod changing it changes aliens/everyone alike).
VTBaseline.kSharedBases = { "Player", "Weapon", "ScriptActor", "PlayingTeam", "TeamSpectator",
                            "PredictedProjectile", "Entity" }

local function IsScalar(v)
    local t = type(v)
    return t == "number" or t == "string" or t == "boolean"
end

-- Lua (not engine/C) function? NS2 raises an error for debug.getupvalue on C functions.
function VTBaseline_IsLuaFunction(fn)
    if type(fn) ~= "function" then
        return false
    end
    local ok, info = pcall(debug.getinfo, fn, "S")
    return ok and info ~= nil and info.what ~= "C"
end

-- Record the "k..." scalar upvalues of fn (and of the local helper functions it
-- references), as they are right now.
local function CaptureUpvalues(fn, seen)
    if seen[fn] or VTBaseline.upvalues[fn] or not VTBaseline_IsLuaFunction(fn) then
        return
    end
    seen[fn] = true
    local captured = {}
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then
            break
        end
        if IsScalar(value) and name:match("^k") then
            captured[i] = value
        elseif type(value) == "function" then
            CaptureUpvalues(value, seen)
        end
        i = i + 1
    end
    VTBaseline.upvalues[fn] = captured
end

local function CaptureTable(source)
    local copy = {}
    local seen = {}
    for k, v in pairs(source) do
        copy[k] = v
        if type(v) == "function" then
            CaptureUpvalues(v, seen)
        end
    end
    return copy
end

local function CaptureClass(name)
    local cls = rawget(_G, name)
    if type(cls) ~= "table" or VTBaseline.classes[name] then
        return
    end
    VTBaseline.classes[name] = CaptureTable(cls)
    local shared = {}
    for field, value in pairs(cls) do
        if type(value) == "function" then
            for _, baseName in ipairs(VTBaseline.kSharedBases) do
                local base = rawget(_G, baseName)
                if type(base) == "table" and base ~= cls and rawget(base, field) == value then
                    shared[field] = baseName
                    break
                end
            end
        end
    end
    VTBaseline.shared[name] = shared
    VTBaseline.order[#VTBaseline.order + 1] = "class " .. name
end

local function CaptureMixin(name)
    local mixin = rawget(_G, name)
    if type(mixin) ~= "table" or VTBaseline.mixins[name] then
        return
    end
    VTBaseline.mixins[name] = CaptureTable(mixin)
    VTBaseline.order[#VTBaseline.order + 1] = "mixin " .. name
end

local function CaptureFunctions()
    for _, name in ipairs(VTBaseline.kFunctionNames) do
        local fn = rawget(_G, name)
        if type(fn) == "function" and not VTBaseline.functions[name] then
            VTBaseline.functions[name] = fn
            CaptureUpvalues(fn, {})
            VTBaseline.order[#VTBaseline.order + 1] = "function " .. name
        end
    end
end

-- ---- balance files: pre hook remembers which "k..." globals exist, post hook takes the new ones.
-- Balance.lua loads BalanceHealth.lua and BalanceMisc.lua itself and then sets some of their
-- values again (e.g. kAlienSpawnTime 2 -> 10), so the outer file's post hook overwrites the
-- values the nested files captured: the vanilla result is what the outer file leaves behind.
local balanceKeysBefore = {}

function VTBaseline_BeforeBalanceFile(file)
    local keys = {}
    for k in pairs(_G) do
        if type(k) == "string" then
            keys[k] = true
        end
    end
    balanceKeysBefore[file] = keys
end

function VTBaseline_AfterBalanceFile(file)
    local before = balanceKeysBefore[file] or {}
    local count = 0
    for k, v in pairs(_G) do
        if type(k) == "string" and not before[k] and k:match("^k") and IsScalar(v) then
            VTBaseline.values[k] = v
            VTBaseline.valueFile[k] = file
            count = count + 1
        end
    end
    VTBaseline.files[file] = true
    VTBaseline.order[#VTBaseline.order + 1] = string.format("values %s (%d)", file, count)
end

-- Post hook of every other watched vanilla file: capture whatever is defined by now and not yet captured.
function VTBaseline_AfterFile(file)
    VTBaseline.files[file] = true
    for _, name in ipairs(VTBaseline.kClassNames) do
        CaptureClass(name)
    end
    for _, name in ipairs(VTBaseline.kMixinNames) do
        CaptureMixin(name)
    end
    CaptureFunctions()
end
