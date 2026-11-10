-- ============================================================================
-- GUIVTPlayerHUD - the Vael'Thor soldier HUD (psionic crystal style).
-- Replaces the marine HUD for living Vael'Thor soldiers (hidden by
-- Hooks/GUIMarineHUD.lua). Textures: ui/vaelthor/hud_*.dds (art/ui/make_hud_textures.py),
-- tinted at runtime.
--   top left:     location, Nexus commander, team resources, active directives
--   bottom left:  vitals (integrity = health, armor, psi shield = vtShield) + ability chips above
--   bottom right: active weapon, energy/ammo bar, weapon slots
-- The dead-player Synthesis Matrix menu and the cloak tint stay in GUIVTHud.
-- ============================================================================

class 'GUIVTPlayerHUD' (GUIScript)

local kPanelTex = PrecacheAsset("ui/vaelthor/hud_panel.dds")
local kChipTex  = PrecacheAsset("ui/vaelthor/hud_chip.dds")
local kBarTex   = PrecacheAsset("ui/vaelthor/hud_bar.dds")
local kBarTexW, kBarTexH = 256, 24

local kColPanel   = Color(1, 1, 1, 0.92)
local kColHealth  = Color(0.95, 0.32, 0.58, 1)
local kColShield  = Color(0.72, 0.42, 1.00, 1)
local kColArmor   = Color(0.66, 0.66, 0.76, 1)
local kColBurnout = Color(0.42, 0.40, 0.48, 1)
local kColEnergy  = Color(0.78, 0.45, 1.00, 1)
local kColEmpty   = Color(0.22, 0.12, 0.34, 0.75)
local kColText    = Color(0.88, 0.80, 1.00, 1)
local kColDim     = Color(0.62, 0.52, 0.78, 1)
local kColReady   = Color(0.55, 1.00, 0.85, 1)
local kColActive  = Color(1.00, 0.85, 1.00, 1)
local kColWarn    = Color(1.00, 0.42, 0.42, 1)

local kMargin = 20
local kVitalsW, kVitalsH = 380, 120
local kChipW, kChipH, kChipGap = 300, 34, 6
local kMaxChips = 5

local kCasteNames = { VTVanguard = "VANGUARD", VTInfiltrator = "INFILTRATOR", VTSubject = "SUBJECT", VTPraetor = "PRAETOR" }

local function S(x, y) return GUIScale(Vector(x, y, 0)) end

function GUIVTPlayerHUD:Graphic(parent, tex, w, h, x, y, color, layer)
    local item = GUIManager:CreateGraphicItem()
    if tex then item:SetTexture(tex) end
    item:SetSize(S(w, h))
    item:SetPosition(S(x, y))
    item:SetColor(color or Color(1, 1, 1, 1))
    item:SetLayer(layer or kGUILayerPlayerHUD)
    if parent then
        parent:AddChild(item)
    else
        self.roots[#self.roots + 1] = item
    end
    return item
end

function GUIVTPlayerHUD:Text(parent, font, x, y, alignX, color)
    local t = GUIManager:CreateTextItem()
    t:SetFontName(font)
    t:SetScale(GetScaledVector())
    GUIMakeFontScale(t)
    t:SetTextAlignmentX(alignX or GUIItem.Align_Min)
    t:SetTextAlignmentY(GUIItem.Align_Center)
    t:SetPosition(S(x, y))
    t:SetColor(color or kColText)
    t:SetLayer(kGUILayerPlayerHUDForeground3)
    parent:AddChild(t)
    return t
end

function GUIVTPlayerHUD:Bar(parent, x, y, w, h)
    local back = self:Graphic(parent, kBarTex, w, h, x, y, kColEmpty, kGUILayerPlayerHUDForeground1)
    local fill = self:Graphic(parent, kBarTex, w, h, x, y, kColEnergy, kGUILayerPlayerHUDForeground2)
    return { back = back, fill = fill, w = w, h = h }
end

local function SetBar(bar, frac, color)
    frac = Clamp(frac or 0, 0, 1)
    bar.fill:SetIsVisible(frac > 0.002)
    bar.fill:SetSize(S(bar.w * frac, bar.h))
    bar.fill:SetTexturePixelCoordinates(0, 0, kBarTexW * frac, kBarTexH)
    if color then bar.fill:SetColor(color) end
end

local function Anchored(item, ax, ay, x, y)
    item:SetAnchor(ax, ay)
    item:SetPosition(S(x, y))
end

function GUIVTPlayerHUD:Initialize()

    self.updateInterval = 0.05
    self.roots = {}

    -- ---- top left: location / nexus / resources / directives
    self.topPanel = self:Graphic(nil, kPanelTex, 360, 74, 0, 0, kColPanel)
    Anchored(self.topPanel, GUIItem.Left, GUIItem.Top, kMargin, kMargin)
    self.location  = self:Text(self.topPanel, Fonts.kAgencyFB_Medium, 18, 20, nil, kColText)
    self.nexus     = self:Text(self.topPanel, Fonts.kAgencyFB_Small, 18, 42, nil, kColDim)
    -- team resources moved to the top bar (GUIVTTopBar)
    self.directives = self:Text(self.topPanel, Fonts.kAgencyFB_Small, 18, 62, nil, kColActive)
    self.directives:SetTextAlignmentY(GUIItem.Align_Min)

    -- ---- bottom left: vitals
    self.vitals = self:Graphic(nil, kPanelTex, kVitalsW, kVitalsH, 0, 0, kColPanel)
    Anchored(self.vitals, GUIItem.Left, GUIItem.Bottom, kMargin, -kMargin - kVitalsH)
    self.caste       = self:Text(self.vitals, Fonts.kAgencyFB_Small, 18, 15, nil, kColDim)
    self.healthLabel = self:Text(self.vitals, Fonts.kAgencyFB_Small, 18, 33, nil, kColText)
    self.healthValue = self:Text(self.vitals, Fonts.kAgencyFB_Small, kVitalsW - 18, 33, GUIItem.Align_Max, kColText)
    self.healthBar   = self:Bar(self.vitals, 18, 42, kVitalsW - 36, 14)
    self.armorLabel  = self:Text(self.vitals, Fonts.kAgencyFB_Small, 18, 64, nil, kColText)
    self.armorValue  = self:Text(self.vitals, Fonts.kAgencyFB_Small, kVitalsW - 18, 64, GUIItem.Align_Max, kColText)
    self.armorBar    = self:Bar(self.vitals, 18, 73, kVitalsW - 36, 7)
    self.shieldLabel = self:Text(self.vitals, Fonts.kAgencyFB_Small, 18, 89, nil, kColText)
    self.shieldValue = self:Text(self.vitals, Fonts.kAgencyFB_Small, kVitalsW - 18, 89, GUIItem.Align_Max, kColText)
    self.shieldBar   = self:Bar(self.vitals, 18, 98, kVitalsW - 36, 11)
    self.healthLabel:SetText("INTEGRITY")
    self.armorLabel:SetText("ARMOR")

    -- ---- ability chips (stacked upwards above the vitals)
    self.chips = {}
    for i = 1, kMaxChips do
        local y = -kMargin - kVitalsH - 10 - i * kChipH - (i - 1) * kChipGap
        local chip = self:Graphic(nil, kChipTex, kChipW, kChipH, 0, 0, kColPanel)
        Anchored(chip, GUIItem.Left, GUIItem.Bottom, kMargin, y)
        self.chips[i] = {
            frame = chip,
            key   = self:Text(chip, Fonts.kAgencyFB_Small, 14, 14, nil, kColEnergy),
            name  = self:Text(chip, Fonts.kAgencyFB_Small, 58, 14, nil, kColText),
            state = self:Text(chip, Fonts.kAgencyFB_Small, kChipW - 14, 14, GUIItem.Align_Max, kColReady),
            bar   = self:Bar(chip, 58, 25, kChipW - 72, 4),
        }
    end

    -- ---- bottom right: weapon
    self.weapon = self:Graphic(nil, kPanelTex, kVitalsW, kVitalsH, 0, 0, kColPanel)
    Anchored(self.weapon, GUIItem.Right, GUIItem.Bottom, -kMargin - kVitalsW, -kMargin - kVitalsH)
    self.weaponName  = self:Text(self.weapon, Fonts.kAgencyFB_Medium, 18, 22, nil, kColText)
    self.weaponValue = self:Text(self.weapon, Fonts.kAgencyFB_Small, kVitalsW - 18, 22, GUIItem.Align_Max, kColText)
    self.weaponBar   = self:Bar(self.weapon, 18, 40, kVitalsW - 36, 12)
    self.slots = {}
    for i = 1, 4 do
        local box = self:Graphic(self.weapon, kChipTex, 80, 22, 18 + (i - 1) * 87, 62, kColPanel, kGUILayerPlayerHUDForeground1)
        self.slots[i] = { box = box, text = self:Text(box, Fonts.kAgencyFB_Small, 40, 11, GUIItem.Align_Center, kColDim) }
    end

    self.visible = true
    self:SetVisible(false)

end

function GUIVTPlayerHUD:Uninitialize()
    for _, item in ipairs(self.roots or {}) do
        GUI.DestroyItem(item)
    end
    self.roots = {}
end

function GUIVTPlayerHUD:OnResolutionChanged(oldX, oldY, newX, newY)
    self:Uninitialize()
    self:Initialize()
end

function GUIVTPlayerHUD:SetVisible(visible)
    if self.visible == visible then return end
    self.visible = visible
    for _, item in ipairs(self.roots) do
        item:SetIsVisible(visible)
    end
end

-- Living Vael'Thor soldier that this client controls (not dead/matrix, not commander).
local function GetHUDPlayer()
    if not Client.GetIsControllingPlayer() then return nil end
    local player = Client.GetLocalPlayer()
    if not player or player:GetTeamNumber() ~= kVTTeamIndex or not player:GetIsAlive() then return nil end
    if player:isa("Commander") or player:isa("Spectator") then return nil end
    return player
end

-- ---- ability chips ----------------------------------------------------------
local function CasteAbility(player)
    if player:isa("VTVanguard") then
        if player.vtModule == kVTModule.PhaseDash then return "PHASE DASH", kVTPhaseDashCooldown end
        if player.vtModule == kVTModule.ShieldOverdrive then return "OVERDRIVE", kVTOverdriveCooldown end
        return "SHIELD BOOST", kVTShieldBoostCooldown
    elseif player:isa("VTInfiltrator") then
        return "CLOAK FIELD", kVTCloakCooldown
    elseif player:isa("VTPraetor") then
        return "TELEPORT DASH", kVTPraetorDashCooldown
    end
    return nil
end

function GUIVTPlayerHUD:BuildChips(player)
    local now = Shared.GetTime()
    local rows = {}

    local isInfiltrator = player:isa("VTInfiltrator")
    local parasited = player.GetIsParasited and player:GetIsParasited()

    if parasited then
        local left = (player.GetParasitePercentageRemaining and player:GetParasitePercentageRemaining() or 0)
        rows[#rows + 1] = { key = "!", name = "PARASITED", state = string.format("%.0fs", left * kParasiteDuration),
                            frac = left, color = kColWarn, stateColor = kColWarn }
    end

    local name, cooldown = CasteAbility(player)
    if name then
        local row = { key = "[B]", name = name }
        if isInfiltrator and parasited then
            row.state, row.frac, row.stateColor, row.color = "BLOCKED", 0, kColWarn, kColWarn
        elseif player.VT_GetAbilityActive and player:VT_GetAbilityActive() then
            local left = (player.vtAbilityActiveEnd or now) - now
            row.state, row.frac, row.stateColor = string.format("ACTIVE %.0fs", left), 1, kColActive
            row.color = Color(kColActive.r, kColActive.g, kColActive.b, 0.6 + 0.4 * math.sin(now * 8))
        else
            local remaining = player.VT_GetAbilityCooldownRemaining and player:VT_GetAbilityCooldownRemaining() or 0
            if remaining > 0 then
                row.state, row.frac, row.stateColor = string.format("%.0fs", remaining), 1 - remaining / cooldown, kColDim
            elseif player:isa("VTPraetor") and (player.vtEnergy or 0) < kVTPraetorDashEnergyCost then
                row.state, row.frac = string.format("NEEDS %d ENERGY", kVTPraetorDashEnergyCost), (player.vtEnergy or 0) / kVTPraetorDashEnergyCost
                row.stateColor, row.color = kColWarn, kColWarn
            else
                row.state, row.frac, row.stateColor = "READY", 1, kColReady
            end
        end
        rows[#rows + 1] = row
    elseif player:isa("VTSubject") then
        rows[#rows + 1] = { key = "2x", name = "DODGE", state = "double-tap", frac = 1, stateColor = kColDim }
        -- sprint burst (Shift on the ground)
        local sprintLeft = player.VT_GetSprintCooldownRemaining and player:VT_GetSprintCooldownRemaining() or 0
        local sprinting = player.VT_GetIsSprintBursting and player:VT_GetIsSprintBursting()
        rows[#rows + 1] = { key = "[SHIFT]", name = "SPRINT",
                            state = sprinting and "SPRINTING" or (sprintLeft > 0 and string.format("%.0fs", sprintLeft) or "READY"),
                            frac = sprintLeft > 0 and 1 - sprintLeft / kVTSubjectSprintCooldown or 1,
                            stateColor = sprinting and kColActive or (sprintLeft > 0 and kColDim or kColReady) }
        local stamina = player.vtClimbStamina or kVTClimbStamina
        local frac = stamina / kVTClimbStamina
        local holding = player.VT_GetIsWallHolding and player:VT_GetIsWallHolding()
        rows[#rows + 1] = { key = "WALL", name = player.vtClimbing and "CLAW CLIMB  [SHIFT] hold" or "CLAW CLIMB",
                            state = holding and "HOLDING" or (player.vtClimbing and string.format("CLIMBING %.1fs", stamina)
                                    or (frac >= 1 and "READY" or string.format("%.0f%%", frac * 100))),
                            frac = frac, color = frac < 0.25 and kColWarn or kColEnergy,
                            stateColor = (holding or player.vtClimbing) and kColActive or (frac >= 1 and kColReady or kColDim) }
    end

    if isInfiltrator then
        local remaining = (player.vtHackReadyTime or 0) - now
        local weapon = player:GetActiveWeapon()
        local bladesOut = weapon and weapon:isa("VTPsionicBlade")
        rows[#rows + 1] = { key = "[RMB]", name = bladesOut and "HACK" or "HACK (blades: 1)",
                            state = remaining > 0 and string.format("%.0fs", remaining) or "READY",
                            frac = remaining > 0 and 1 - remaining / kVTHackCooldown or 1,
                            stateColor = remaining > 0 and kColDim or kColReady }
        if player.GetWeapon and player:GetWeapon(kVTMapNames.EchoPulse) then
            local scanning = player.vtEchoScanning
            rows[#rows + 1] = { key = "[2]", name = "ECHO SCAN", state = scanning and "SCANNING" or "hold fire",
                                frac = scanning and 1 or 0, stateColor = scanning and kColActive or kColDim }
        end
    end

    if VT_GetTeamHasTech("VTTargetingVisorTech") then
        local on = VT_VisionScript and VT_VisionScript:GetIsActive()
        rows[#rows + 1] = { key = "[F]", name = "TARGETING VISOR", state = on and "ON" or "off",
                            frac = on and 1 or 0, stateColor = on and kColActive or kColDim }
    end

    return rows
end

function GUIVTPlayerHUD:UpdateChips(player)
    local rows = self:BuildChips(player)
    for i, chip in ipairs(self.chips) do
        local row = rows[i]
        chip.frame:SetIsVisible(row ~= nil)
        if row then
            chip.key:SetText(row.key)
            chip.name:SetText(row.name)
            chip.state:SetText(row.state or "")
            chip.state:SetColor(row.stateColor or kColText)
            SetBar(chip.bar, row.frac or 0, row.color or kColEnergy)
        end
    end
end

-- ---- weapon panel -------------------------------------------------------------
local kShortNames = {
    VTPlasmaCarbine = "CARBINE", VTPsionicKnife = "KNIFE", VTPsionicBlade = "BLADES", VTEchoPulse = "SCANNER",
    VTSingularityLauncher = "LAUNCHER", VTSubjectClaws = "CLAWS",
}

local function WeaponName(weapon)
    local key = LookupTechData(weapon:GetTechId(), kTechDataDisplayName, weapon:GetClassName())
    return string.upper(Locale.ResolveString(key) or key)
end

function GUIVTPlayerHUD:UpdateWeapon(player)
    local weapon = player:GetActiveWeapon()
    if player:isa("VTPraetor") then
        -- the exo weapon holder has no useful name/slots: show the shared minigun energy instead
        local energy = math.floor(player.vtEnergy or 0)
        local frac = energy / kVTPraetorEnergy
        self.weaponName:SetText("PLASMA MINIGUNS")
        self.weaponValue:SetText(string.format("ENERGY %d / %d", energy, kVTPraetorEnergy))
        SetBar(self.weaponBar, frac, frac < 0.25 and kColWarn or kColEnergy)
        for _, s in ipairs(self.slots) do
            s.box:SetIsVisible(false)
        end
        return
    end
    if not weapon then
        self.weaponName:SetText(""); self.weaponValue:SetText(""); SetBar(self.weaponBar, 0)
    else
        self.weaponName:SetText(WeaponName(weapon))
        if weapon:isa("VTPlasmaCarbine") then
            local clip = weapon.clip or 0
            self.weaponValue:SetText(string.format("ENERGY %d / %d", clip, kVTCarbineEnergy))
            SetBar(self.weaponBar, clip / kVTCarbineEnergy, clip / kVTCarbineEnergy < 0.25 and kColWarn or kColEnergy)
        elseif weapon.clip and weapon.GetClipSize then
            local size = math.max(1, weapon:GetClipSize())
            self.weaponValue:SetText(string.format("%d  |  %d", weapon.clip, weapon.ammo or 0))
            SetBar(self.weaponBar, weapon.clip / size, kColEnergy)
        elseif weapon:isa("VTEchoPulse") then
            self.weaponValue:SetText(player.vtEchoScanning and "SCANNING" or "HOLD FIRE TO SCAN")
            SetBar(self.weaponBar, player.vtEchoScanning and 1 or 0, kColActive)
        else
            self.weaponValue:SetText("MELEE")
            SetBar(self.weaponBar, 1, Color(kColEnergy.r, kColEnergy.g, kColEnergy.b, 0.55))
        end
    end

    local list = player.GetHUDOrderedWeaponList and player:GetHUDOrderedWeaponList() or {}
    local bySlot = {}
    for _, w in ipairs(list) do
        local slot = w.GetHUDSlot and w:GetHUDSlot() or 0
        if slot >= 1 and slot <= 4 then bySlot[slot] = w end
    end
    for i, s in ipairs(self.slots) do
        local w = bySlot[i]
        s.box:SetIsVisible(w ~= nil)
        if w then
            local active = w == weapon
            s.text:SetText(string.format("%d %s", i, kShortNames[w:GetClassName()] or string.upper(w:GetClassName())))
            s.text:SetColor(active and kColActive or kColDim)
            s.box:SetColor(active and Color(1, 0.85, 1, 1) or Color(1, 1, 1, 0.55))
        end
    end
end

-- ---- top left -------------------------------------------------------------------
function GUIVTPlayerHUD:UpdateTop(player)
    self.location:SetText(string.upper(PlayerUI_GetLocationName() or ""))
    local commander = PlayerUI_GetCommanderName and PlayerUI_GetCommanderName() or ""
    self.nexus:SetText(commander ~= "" and ("NEXUS: " .. commander) or "NO NEXUS COMMANDER")
    self.nexus:SetColor(commander ~= "" and kColDim or kColWarn)

    local info = VT_GetEmpireInfo and VT_GetEmpireInfo()
    local lines = {}
    if info then
        local now = Shared.GetTime()
        if info.requisitionEnd > now then lines[#lines + 1] = string.format("REQUISITION MANDATE  %.0fs", info.requisitionEnd - now) end
        if info.relentlessEnd > now then lines[#lines + 1] = string.format("RELENTLESS ADVANCE  %.0fs", info.relentlessEnd - now) end
        if info.ironEnd > now then lines[#lines + 1] = string.format("IRON DISCIPLINE  %.0fs", info.ironEnd - now) end
    end
    self.directives:SetText(table.concat(lines, "\n"))
end

-- ---- vitals ------------------------------------------------------------------------
function GUIVTPlayerHUD:UpdateVitals(player)
    self.caste:SetText(kCasteNames[player:GetClassName()] or string.upper(player:GetClassName()))
    local hp, maxHp = player:GetHealth(), math.max(1, player:GetMaxHealth())
    local ar, maxAr = player:GetArmor(), math.max(1, player:GetMaxArmor())
    local sh, maxSh = player.vtShield or 0, math.max(1, player.vtMaxShield or 0)
    self.healthValue:SetText(string.format("%d / %d", math.ceil(hp), maxHp))
    SetBar(self.healthBar, hp / maxHp, hp / maxHp < 0.3 and kColWarn or kColHealth)
    self.armorValue:SetText(string.format("%d / %d", math.ceil(ar), maxAr))
    SetBar(self.armorBar, ar / maxAr, kColArmor)

    local burnout = player.VT_GetIsShieldBurntOut and player:VT_GetIsShieldBurntOut()
    self.shieldLabel:SetText(burnout and "PSI SHIELD - BURNOUT" or "PSI SHIELD")
    self.shieldLabel:SetColor(burnout and kColWarn or kColText)
    self.shieldValue:SetText(string.format("%d / %d", math.ceil(sh), maxSh))
    SetBar(self.shieldBar, sh / maxSh, burnout and kColBurnout or kColShield)
end

function GUIVTPlayerHUD:Update(deltaTime)
    PROFILE("GUIVTPlayerHUD:Update")
    local player = GetHUDPlayer()
    self:SetVisible(player ~= nil)
    if not player then return end
    self:UpdateTop(player)
    self:UpdateVitals(player)
    self:UpdateChips(player)
    self:UpdateWeapon(player)
end
