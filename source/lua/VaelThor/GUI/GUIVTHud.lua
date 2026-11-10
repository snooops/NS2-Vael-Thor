-- ============================================================================
-- GUIVTHud - minimal text HUD for the Vael'Thor prototype.
--   * dead (Synthesis Matrix): caste / loadout picker with quotas and locks
--   * alive: caste ability cooldown
--   * everyone on the team: active Directives
-- ============================================================================

class 'GUIVTHud' (GUIScript)

local kTextColor      = Color(0.75, 0.55, 1.0, 1)     -- imperial violet
local kSelectedColor  = Color(0.35, 0.95, 1.0, 1)     -- cyan conduit
local kLockedColor    = Color(0.55, 0.55, 0.6, 1)

local kCasteNames = { "Infiltrator", "Subject", "Praetor" }

local function GetLocalRank()
    local ok, score = pcall(Scoreboard_GetPlayerData, Client.GetLocalClientIndex(), "Score")
    score = ok and tonumber(score) or 0
    return VT_GetRankForScore(score), score
end

local function LockReason(requirement, rank)
    if not requirement then
        return nil
    end
    if requirement.rank and rank < requirement.rank then
        return string.format("rank %d", requirement.rank)
    end
    if requirement.tech and not VT_GetTeamHasTech(requirement.tech) then
        return VT_GetString(LookupTechData(kTechId[requirement.tech], kTechDataDisplayName, requirement.tech))
    end
    return nil
end

function GUIVTHud:Initialize()

    self.updateInterval = 0.1

    self.text = GUIManager:CreateTextItem()
    self.text:SetFontName(Fonts.kAgencyFB_Small)
    self.text:SetScale(GetScaledVector())
    GUIMakeFontScale(self.text)
    self.text:SetAnchor(GUIItem.Left, GUIItem.Center)
    self.text:SetTextAlignmentX(GUIItem.Align_Min)
    self.text:SetTextAlignmentY(GUIItem.Align_Center)
    self.text:SetPosition(GUIScale(Vector(24, 0, 0)))
    self.text:SetColor(kTextColor)
    self.text:SetLayer(kGUILayerPlayerHUD)
    self.text:SetIsVisible(false)

    -- Full-screen tint while the local Infiltrator's cloaking field is active.
    self.cloakTint = GUIManager:CreateGraphicItem()
    self.cloakTint:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.cloakTint:SetPosition(Vector(0, 0, 0))
    self.cloakTint:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))
    self.cloakTint:SetColor(Color(0.25, 0.85, 1.0, 0))
    self.cloakTint:SetLayer(kGUILayerPlayerHUD - 1)
    self.cloakTint:SetIsVisible(false)

end

function GUIVTHud:Uninitialize()
    if self.text then
        GUI.DestroyItem(self.text)
        self.text = nil
    end
    if self.cloakTint then
        GUI.DestroyItem(self.cloakTint)
        self.cloakTint = nil
    end
end

function GUIVTHud:UpdateCloakTint(player)
    local fraction = 0
    if player:isa("VTInfiltrator") and player.GetCloakFraction then
        fraction = player:GetCloakFraction()
    end
    if fraction > 0.01 then
        self.cloakTint:SetColor(Color(0.25, 0.85, 1.0, 0.18 * fraction))
        self.cloakTint:SetIsVisible(true)
    else
        self.cloakTint:SetIsVisible(false)
    end
end

function GUIVTHud:OnResolutionChanged(oldX, oldY, newX, newY)
    self:Uninitialize()
    self:Initialize()
end

function GUIVTHud:BuildMatrixText(player, info)

    local rank, score = GetLocalRank()
    local lines = {}

    lines[#lines + 1] = "SYNTHESIS MATRIX - awaiting synthesis"
    lines[#lines + 1] = string.format("Imperial Authorization: rank %d  (score %d)", rank, score)
    lines[#lines + 1] = ""

    local function CasteLine(key, class, label, extra)
        local marker = player.vtDesiredClass == class and ">> " or "   "
        local lock = LockReason(kVTClassRequirements[class], 3)
        local text = string.format("%s[%s] %s%s", marker, key, label, extra or "")
        if lock then
            text = text .. "  (locked: " .. lock .. ")"
        end
        lines[#lines + 1] = text
    end

    CasteLine("1", kVTClass.Vanguard, "Vanguard", "  - unlimited")
    for i, caste in ipairs(kCasteNames) do
        local class = kVTClass[caste]
        local quota = info and string.format("  - %d/%d", info:GetCount(caste), info:GetQuota(caste)) or ""
        local cost = kVTCasteCost[caste] or 0
        if cost > 0 then
            quota = quota .. string.format(", %d team res", cost)
        end
        CasteLine(tostring(i + 1), class, caste, quota)
    end

    lines[#lines + 1] = ""

    local function ChoiceLine(key, label, prefix, value, requirements)
        local lock = LockReason(requirements[value], rank)
        local text = string.format("[%s] %s: %s", key, label, VT_GetString(prefix .. tostring(value)))
        if lock then
            text = text .. "  (locked: " .. lock .. " - default used)"
        end
        lines[#lines + 1] = text
    end

    ChoiceLine("5", "Module",    "VT_MODULE_",    player.vtModule,     kVTModuleRequirements)
    ChoiceLine("R", "Primary",   "VT_PRIMARY_",   player.vtPrimaryMod, kVTPrimaryModRequirements)
    ChoiceLine("E", "Secondary", "VT_SECONDARY_", player.vtSecondary,  kVTSecondaryRequirements)

    return lines

end

-- While following a teammate in first person the client's moves don't reach
-- our VTSpectator (vanilla drives that mode through network messages), so the
-- menu keys are caught here and sent as VTMatrixChoice. Consuming them also
-- stops GUIFirstPersonSpectate from treating 1/2 as camera-mode switches.
local kMatrixKeyBindings = { "Weapon1", "Weapon2", "Weapon3", "Weapon4", "Weapon5", "Reload", "Use" }

function GUIVTHud:SendKeyEvent(key, down)

    if Client.GetIsControllingPlayer() or Client.GetLocalClientTeamNumber() ~= kVTTeamIndex then
        return false
    end
    if GetIsTextBeingEntered and GetIsTextBeingEntered() then
        return false
    end

    for choice, binding in ipairs(kMatrixKeyBindings) do
        if GetIsBinding(key, binding) then
            if down then
                Client.SendNetworkMessage("VTMatrixChoice", { choice = choice }, true)
            end
            return true
        end
    end

    return false

end

function GUIVTHud:Update(deltaTime)

    PROFILE("GUIVTHud:Update")

    local player = Client.GetLocalPlayer()
    -- While spectating (kill cam on the killer, or following a teammate) the
    -- local player isn't us: go by our own team instead.
    local spectating = not Client.GetIsControllingPlayer() and Client.GetLocalClientTeamNumber() == kVTTeamIndex
    if not player or (player:GetTeamNumber() ~= kVTTeamIndex and not spectating) then
        self.text:SetIsVisible(false)
        self.cloakTint:SetIsVisible(false)
        return
    end

    self:UpdateCloakTint(player)

    local info = VT_GetEmpireInfo()
    local lines

    -- Dead and following a teammate in first person: the local player is the
    -- teammate, so show our own matrix choices mirrored from the server.
    local matrixSource
    if player:isa("VTSpectator") then
        matrixSource = player
    elseif spectating then
        matrixSource = VT_MatrixLoadout or { vtDesiredClass = kVTClass.Vanguard, vtModule = kVTModule.ShieldBoost,
                                             vtPrimaryMod = kVTPrimaryMod.Standard, vtSecondary = kVTSecondary.Pistol }
    end

    -- Living soldiers: everything is on GUIVTPlayerHUD now; this script keeps the matrix menu + cloak tint.
    if not matrixSource then
        self.text:SetIsVisible(false)
        return
    end

    if matrixSource then
        lines = self:BuildMatrixText(matrixSource, info)
    else
        lines = {}
        if player.VT_GetAbilityCooldownRemaining then
            local remaining = player:VT_GetAbilityCooldownRemaining()
            if player:isa("VTInfiltrator") and player.VT_GetIsParasited and player:VT_GetIsParasited() then
                lines[#lines + 1] = "[B] cloak field: BLOCKED (parasited)"
            elseif player:isa("VTInfiltrator") and player:VT_GetAbilityActive() and player.GetCloakFraction then
                lines[#lines + 1] = string.format("[B] CLOAK FIELD %d%%  (%.0fs)",
                        math.floor(player:GetCloakFraction() * 100 + 0.5), player.vtAbilityActiveEnd - Shared.GetTime())
            elseif player.VT_GetAbilityActive and player:VT_GetAbilityActive() then
                lines[#lines + 1] = "[B] ability ACTIVE"
            elseif remaining > 0 then
                lines[#lines + 1] = string.format("[B] ability: %.0fs", remaining)
            else
                lines[#lines + 1] = "[B] ability: ready"
            end
        end
        if VT_GetTeamHasTech("VTTargetingVisorTech") and (player:isa("Marine") or player:isa("Exo")) then
            local on = VT_VisionScript and VT_VisionScript:GetIsActive()
            lines[#lines + 1] = on and "[F] targeting visor: ON" or "[F] targeting visor: off"
        end
        if player.GetWeapon and player:GetWeapon(kVTMapNames.EchoPulse) then
            lines[#lines + 1] = player.vtEchoScanning and "[2] echo scan: SCANNING" or "[2] echo scan: hold fire"
        end
        -- Hack pulse (right-click with the Psionic Blades out)
        if player:isa("VTInfiltrator") and player.vtHackReadyTime then
            local weapon = player:GetActiveWeapon()
            local remaining = player.vtHackReadyTime - Shared.GetTime()
            local text = remaining > 0 and string.format("[RMB] hack: %.0fs", remaining) or "[RMB] hack: ready"
            if not (weapon and weapon:isa("VTPsionicBlade")) then
                text = text .. "  (blades: 1)"
            end
            lines[#lines + 1] = text
        end
    end

    if info then
        local now = Shared.GetTime()
        if info.requisitionEnd > now then
            lines[#lines + 1] = string.format("Directive: Requisition Mandate %.0fs", info.requisitionEnd - now)
        end
        if info.relentlessEnd > now then
            lines[#lines + 1] = string.format("Directive: Relentless Advance %.0fs", info.relentlessEnd - now)
        end
        if info.ironEnd > now then
            lines[#lines + 1] = string.format("Directive: Iron Discipline %.0fs", info.ironEnd - now)
        end
    end

    if #lines == 0 then
        self.text:SetIsVisible(false)
        return
    end

    self.text:SetText(table.concat(lines, "\n"))
    self.text:SetColor(matrixSource and kTextColor or kSelectedColor)
    self.text:SetIsVisible(true)

end
