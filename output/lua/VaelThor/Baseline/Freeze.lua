-- ============================================================================
-- Vael'Thor isolation - frozen copies of vanilla marine code
--
-- VTFreeze.Clone(fn) returns a copy of a captured vanilla function that
--   * keeps the vanilla "k..." file locals (VTBaseline.upvalues) instead of
--     sharing them, so ReplaceLocals() by other mods doesn't reach it,
--   * runs in VTFreeze.env: global lookups see the frozen class views
--     (VTBase.Marine...), the frozen marine-only mixins and the vanilla balance
--     constants (VTBaseline.values) before the live (possibly modded) _G;
--     writes still go to _G.
-- VT_FreezeClass(cls, { "Rifle", "ClipWeapon" }) installs frozen copies of the inherited
-- methods (forwarders for methods shared with a both-teams base) and the vanilla
-- values of class constants. It runs right after the class line, before the
-- Vael'Thor define or wrap their own methods. NS2 copies
-- base methods into derived classes and Class_ReplaceMethod only replaces a
-- derived method while it still equals the original, so later mod patches stop
-- at the frozen copy automatically.
-- If the VM can't copy functions (no string.dump / setfenv / debug.upvaluejoin)
-- the vanilla functions are installed as they are: still immune to later
-- Class_ReplaceMethod patches, but they read the live globals.
-- Loaded by Baseline/FileHooks.lua right after Baseline.lua (every VM).
-- ============================================================================

if VTFreeze then
    return
end

VTFreeze =
{
    enabled   = true,     -- kill switch for debugging (vt_isolation shows the state)
    supported = false,    -- function copying works in this VM
    reason    = "",
    memo      = {},       -- original fn -> frozen copy
    views     = {},       -- class / mixin name -> frozen view table
    report    = {},       -- VT class name -> { frozen = n, own = n, missing = {...} }
}

local function Probe()
    if not (string.dump and loadstring and setfenv and debug and debug.getupvalue and debug.setupvalue and debug.upvaluejoin) then
        return false, "string.dump / loadstring / setfenv / debug.upvaluejoin missing"
    end
    local ok, err = pcall(function()
        local kProbeLocal = 5
        local shared = { n = 1 }
        local function probe()
            return kProbeLocal + kVTFreezeProbeGlobal + shared.n
        end
        local clone = loadstring(string.dump(probe))
        debug.setupvalue(clone, 1, 7)             -- own copy of the "k" local
        debug.upvaluejoin(clone, 2, probe, 2)     -- shared table stays shared
        setfenv(clone, setmetatable({ kVTFreezeProbeGlobal = 100 }, { __index = _G }))
        assert(clone() == 108, "unexpected result")
        shared.n = 2
        assert(clone() == 109, "upvalue join failed")
    end)
    return ok, ok and "ok" or tostring(err)
end

VTFreeze.supported, VTFreeze.reason = Probe()

-- Globals seen by frozen code: frozen views, then vanilla balance values, then the live _G.
-- Plain-table __index chain (no Lua function per lookup): env -> views -> values -> _G.
-- Read VTFreeze.views / VTBaseline.values with rawget where the fallback isn't wanted.
setmetatable(VTBaseline.values, { __index = _G })
setmetatable(VTFreeze.views, { __index = VTBaseline.values })
VTFreeze.env = setmetatable({}, {
    __index = VTFreeze.views,
    __newindex = function(_, k, v)
        _G[k] = v
    end,
})

function VTFreeze.Clone(fn)

    if type(fn) ~= "function" or not VTFreeze.supported or not VTFreeze.enabled then
        return fn
    end
    local memo = VTFreeze.memo
    if memo[fn] then
        return memo[fn]
    end

    local ok, dumped = pcall(string.dump, fn)
    local clone = ok and loadstring(dumped) or nil
    if not clone then
        memo[fn] = fn   -- C function or not dumpable: keep the original
        return fn
    end
    memo[fn] = clone   -- before recursing: helpers may reference each other

    local captured = VTBaseline.upvalues[fn] or {}
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then
            break
        end
        if captured[i] ~= nil then
            debug.setupvalue(clone, i, captured[i])              -- vanilla "k" local
        elseif VTBaseline.upvalues[value] and VTBaseline_IsLuaFunction(value) then
            debug.setupvalue(clone, i, VTFreeze.Clone(value))     -- vanilla local helper: frozen too
        else
            debug.upvaluejoin(clone, i, fn, i)                    -- state shared with the original
        end
        i = i + 1
    end

    setfenv(clone, VTFreeze.env)
    return clone

end

-- A method the marine class shares unchanged with a both-teams base (Player, Weapon,
-- ScriptActor...): forward to that base's live method. Mods changing the shared base
-- reach the Vael'Thor like everyone else; a mod patching only the marine class
-- (Class_ReplaceMethod("Marine", ...)) doesn't, because the forwarder is a different
-- function than the one it replaces.
local forwarders = {}
local function GetForwarder(baseName, field)
    local key = baseName .. "." .. field
    local fwd = forwarders[key]
    if not fwd then
        fwd = function(...)
            return _G[baseName][field](...)
        end
        forwarders[key] = fwd
    end
    return fwd
end

-- Frozen view of a captured class or mixin: the vanilla fields, marine-specific
-- functions as frozen copies, shared ones as forwarders; anything not captured
-- falls back to the live table.
local function BuildView(snapshot, live, shared)
    local view = {}
    for field, value in pairs(snapshot) do
        if type(value) == "function" then
            local baseName = shared and shared[field]
            view[field] = baseName and GetForwarder(baseName, field) or VTFreeze.Clone(value)
        else
            view[field] = value
        end
    end
    return setmetatable(view, { __index = live })
end

function VTFreeze.GetView(name)
    local view = rawget(VTFreeze.views, name)
    if view then
        return view
    end
    local snapshot = VTBaseline.classes[name]
    local shared = VTBaseline.shared[name]
    if not snapshot then
        snapshot = VTBaseline.mixins[name]
    end
    if not snapshot then
        return rawget(_G, name)   -- not captured: live table
    end
    view = BuildView(snapshot, rawget(_G, name), shared)
    rawset(VTFreeze.views, name, view)
    return view
end

-- Build all views up front so frozen code finds every frozen mixin / class in VTFreeze.env.
function VTFreeze.BuildViews()
    for _, name in ipairs(VTBaseline.kClassNames) do
        if VTBaseline.classes[name] then
            VTFreeze.GetView(name)
        end
    end
    for _, name in ipairs(VTBaseline.kMixinNames) do
        if VTBaseline.mixins[name] then
            VTFreeze.GetView(name)
        end
    end
end

-- Vanilla value of a balance constant, for Vael'Thor code that builds on a marine value
-- (the frozen vanilla code reads the same): baseline, else the shipped reference, else live.
function VT_Vanilla(name)
    local v = rawget(VTBaseline.values, name)
    if v == nil and VTVanillaReference then
        v = VTVanillaReference[name]
    end
    if v == nil then
        v = _G[name]
    end
    return v
end

-- VTBase.Marine.OnCreate(self): the frozen vanilla method, for explicit base calls in Vael'Thor code.
VTBase = setmetatable({}, {
    __index = function(_, name)
        return VTFreeze.GetView(name)
    end,
})

-- Install frozen copies of the marine-specific methods the Vael'Thor class inherits.
-- baseNames: the class's marine ancestors, most derived first.
function VT_FreezeClass(cls, baseNames)

    local className = getmetatable(cls) and getmetatable(cls).name or tostring(cls)
    local report = { frozen = 0, constants = 0, missing = {} }
    VTFreeze.report[className] = report

    if not VTFreeze.enabled then
        return
    end
    VTFreeze.BuildViews()

    local done = {}
    for _, baseName in ipairs(baseNames) do

        local snapshot = VTBaseline.classes[baseName]
        local live = rawget(_G, baseName)
        if not snapshot or not live then
            report.missing[#report.missing + 1] = baseName
        else
            local view = VTFreeze.GetView(baseName)
            for field, value in pairs(snapshot) do
                -- "isa" and other engine (C) functions are managed by the engine per class: never copy them
                local engineField = field == "isa" or (type(value) == "function" and not VTBaseline_IsLuaFunction(value))
                if not done[field] and field ~= "kMapName" and not engineField then
                    done[field] = true
                    local current = cls[field]
                    local t = type(value)
                    -- an inherited copy still equals the live base field (or the vanilla one): freeze it
                    local inherited = current == nil or current == live[field] or current == value
                    if t == "function" then
                        if inherited then
                            rawset(cls, field, view[field])   -- frozen copy, or forwarder for shared methods
                            report.frozen = report.frozen + 1
                        end
                    elseif (t == "number" or t == "string" or t == "boolean") and inherited and current ~= value then
                        rawset(cls, field, value)            -- class constant changed by a mod: vanilla value
                        report.constants = report.constants + 1
                    end
                end
            end
        end

    end

end
