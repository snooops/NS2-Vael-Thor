-- ============================================================================
-- Vael'Thor isolation - report: console command "vt_isolation" (server)
--
-- Shows whether the vanilla baseline was captured before other mods, whether
-- frozen copies work in this VM, and what other mods changed:
--   * balance values that differ from the shipped vanilla reference
--     (VanillaReference.lua, art/tools/extract_vanilla_balance.lua) - changed
--     before the snapshot, e.g. by a mod replacing a balance file: these DO
--     reach the Vael'Thor;
--   * balance values / marine class and mixin fields changed after the snapshot
--     (by later mods): the Vael'Thor ignore these;
--   * per Vael'Thor class: frozen methods / constants and missing bases.
-- ============================================================================

local kMaxListed = 25

-- The Vael'Thor's own patches of vanilla marine classes (for vanilla marines in
-- Vael'Thor vs. Marines): expected, listed separately.
local kOwnPatches =
{
    ["MarineTeam.ResetTeam"]              = "Server.lua: starting res for marines on team 2",
    ["MarineTeam.SpawnWarmUpStructures"]  = "Server.lua: warmup structures for marines on team 2",
    ["Sentry.OnInitialized"]              = "Hooks/TargetSelectors.lua: sentry targeting in Vael'Thor vs. Marines",
}

local function Out(fmt, ...)
    Shared.Message(string.format(fmt, ...))
end

local function List(title, items)
    table.sort(items)
    Out("  %s: %d", title, #items)
    for i = 1, math.min(#items, kMaxListed) do
        Out("    %s", items[i])
    end
    if #items > kMaxListed then
        Out("    ... %d more", #items - kMaxListed)
    end
end

-- The engine wraps every class's OnCreate / OnInitialized once all mods are loaded
-- (core/lua/MixinFinalizer.lua: chunk "<Class>:OnCreate", wrapped function in upvalue "old").
local function Unwrap(fn)
    if not VTBaseline_IsLuaFunction(fn) then
        return fn
    end
    local info = debug.getinfo(fn, "S")
    if info and type(info.source) == "string" and info.source:match(":On%a+$") then
        local i = 1
        while true do
            local name, value = debug.getupvalue(fn, i)
            if not name then break end
            if name == "old" then return value end
            i = i + 1
        end
    end
    return fn
end

local function CompareTables(name, snapshot, live, changed, added)
    if type(live) ~= "table" then
        return
    end
    for field, value in pairs(snapshot) do
        local current = rawget(live, field)
        if field ~= "isa" and current ~= value and Unwrap(current) ~= value then
            changed[#changed + 1] = name .. "." .. tostring(field)
        end
    end
    for field, value in pairs(live) do
        if snapshot[field] == nil and type(value) == "function" then
            added[#added + 1] = name .. "." .. tostring(field)
        end
    end
end

local function Report()

    Out("[Vael'Thor] isolation report")

    if not VTBaseline then
        Out("  NO BASELINE: lua/entry/VaelThorBaseline.entry wasn't loaded - the Vael'Thor are not isolated.")
        return
    end

    local nValues = 0
    for _ in pairs(VTBaseline.values) do nValues = nValues + 1 end
    local nClasses, nMixins = 0, 0
    for _ in pairs(VTBaseline.classes) do nClasses = nClasses + 1 end
    for _ in pairs(VTBaseline.mixins) do nMixins = nMixins + 1 end
    Out("  baseline: %d balance values, %d/%d classes, %d/%d mixins", nValues,
            nClasses, #VTBaseline.kClassNames, nMixins, #VTBaseline.kMixinNames)

    local missing = {}
    for _, name in ipairs(VTBaseline.kClassNames) do
        if not VTBaseline.classes[name] then missing[#missing + 1] = "class " .. name end
    end
    for _, name in ipairs(VTBaseline.kMixinNames) do
        if not VTBaseline.mixins[name] then missing[#missing + 1] = "mixin " .. name end
    end
    for _, name in ipairs(VTBaseline.kFunctionNames) do
        if not VTBaseline.functions[name] then missing[#missing + 1] = "function " .. name end
    end
    if #missing > 0 then
        List("NOT captured (inherited live, mods reach the Vael'Thor here)", missing)
    end

    Out("  frozen copies: %s (%s)%s", VTFreeze and VTFreeze.supported and "yes" or "NO",
            VTFreeze and VTFreeze.reason or "Freeze.lua missing",
            VTFreeze and not VTFreeze.enabled and " - DISABLED" or "")

    -- balance values
    local beforeSnapshot, afterSnapshot = {}, {}
    if VTVanillaReference then
        for k, ref in pairs(VTVanillaReference) do
            local base = rawget(VTBaseline.values, k)
            if base ~= nil and base ~= ref and not (type(base) == "number" and type(ref) == "number" and math.abs(base - ref) < 1e-6) then
                beforeSnapshot[#beforeSnapshot + 1] = string.format("%s = %s (vanilla %s)", k, tostring(base), tostring(ref))
            end
        end
    end
    for k, base in pairs(VTBaseline.values) do
        local live = rawget(_G, k)
        if live ~= base then
            afterSnapshot[#afterSnapshot + 1] = string.format("%s = %s (Vael'Thor keep %s)", k, tostring(live), tostring(base))
        end
    end
    List("balance values changed BEFORE the snapshot (reach the Vael'Thor)", beforeSnapshot)
    List("balance values changed after the snapshot (ignored by the Vael'Thor)", afterSnapshot)

    -- classes / mixins
    local all, added = {}, {}
    for name, snapshot in pairs(VTBaseline.classes) do
        CompareTables(name, snapshot, rawget(_G, name), all, added)
    end
    for name, snapshot in pairs(VTBaseline.mixins) do
        CompareTables(name, snapshot, rawget(_G, name), all, added)
    end
    local changed, own = {}, {}
    for _, field in ipairs(all) do
        if kOwnPatches[field] then
            own[#own + 1] = field .. "  (" .. kOwnPatches[field] .. ")"
        else
            changed[#changed + 1] = field
        end
    end
    List("Vael'Thor's own patches for vanilla marines (expected)", own)
    List("marine class / mixin fields changed by other mods (ignored by the Vael'Thor)", changed)
    List("functions mods added to marine classes / mixins (not used by the Vael'Thor)", added)

    -- Vael'Thor classes
    local classes = {}
    if VTFreeze then
        for className, r in pairs(VTFreeze.report) do
            local line = string.format("%s: %d methods, %d constants frozen", className, r.frozen, r.constants or 0)
            if #r.missing > 0 then
                line = line .. "  MISSING BASE " .. table.concat(r.missing, ", ")
            end
            classes[#classes + 1] = line
        end
    end
    List("Vael'Thor classes", classes)

end

Event.Hook("Console_vt_isolation", function(client)
    Report()
end)

-- "vt_isolation_selftest" (cheats): patches marine code the way balance / gameplay mods do,
-- checks that marines see it and the Vael'Thor don't, then undoes everything.
local function SelfTest()

    if not Shared.GetCheatsEnabled() then
        Out("[Vael'Thor] vt_isolation_selftest needs cheats 1")
        return
    end

    local results = {}
    local function Check(label, ok)
        results[#results + 1] = string.format("  %s %s", ok and "PASS" or "FAIL", label)
    end

    -- 1) Class_ReplaceMethod on a marine-specific method (as gameplay mods do)
    local tests =
    {
        { "Marine", "GetMaxSpeed", { "VTVanguard", "VTInfiltrator", "VTSubject" } },
        { "Rifle",  "GetSpread",   { "VTPlasmaCarbine" } },
        { "Axe",    "GetRange",    { "VTPsionicKnife", "VTPsionicBlade", "VTSubjectClaws" } },
    }
    for _, t in ipairs(tests) do
        local base, method, vtClasses = t[1], t[2], t[3]
        if rawget(_G, base) and _G[base][method] then
            local before = {}
            for _, name in ipairs(vtClasses) do before[name] = _G[name] and _G[name][method] end
            local patched = function(self, ...) return 0 end
            local original = Class_ReplaceMethod(base, method, patched)
            Check(string.format("%s.%s patched for marines", base, method), _G[base][method] == patched)
            for _, name in ipairs(vtClasses) do
                Check(string.format("%s.%s untouched", name, method), _G[name] and _G[name][method] == before[name])
            end
            Class_ReplaceMethod(base, method, original)
        else
            Check(string.format("%s.%s exists", base, method), false)
        end
    end

    -- 2) a balance value changed by a mod
    local old = kRifleDamage
    kRifleDamage = old * 3
    Check("kRifleDamage changed for marines, Vael'Thor keep " .. tostring(VT_Vanilla("kRifleDamage")),
            VT_Vanilla("kRifleDamage") == rawget(VTBaseline.values, "kRifleDamage") and kRifleDamage ~= VT_Vanilla("kRifleDamage"))
    -- frozen vanilla code reads the vanilla value through its environment
    if VTFreeze.supported and VTFreeze.enabled then
        Check("frozen code sees vanilla kRifleDamage", VTFreeze.env.kRifleDamage == rawget(VTBaseline.values, "kRifleDamage"))
    end
    kRifleDamage = old

    Out("[Vael'Thor] isolation self-test")
    for _, line in ipairs(results) do
        Out(line)
    end

end

Event.Hook("Console_vt_isolation_selftest", function(client)
    SelfTest()
end)
