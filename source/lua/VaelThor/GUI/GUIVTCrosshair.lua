-- ============================================================================
-- GUIVTCrosshair - per caste / per weapon crosshairs for Vael'Thor soldiers.
-- Replaces the vanilla crosshair (and the Praetor's exo crosshair), see Client.lua.
-- Atlas: ui/vaelthor/crosshair_atlas.dds (art/ui/build_crosshair.sh), white shapes tinted here.
--
--   Plasma Carbine (Vanguard)    four crystal shards on the live spread cone (moving/jumping widens it),
--                                10 energy pips under the reticle; Overcharge: hot pink, wider shards
--   Psionic Knife (Vanguard)     dagger tip + side pips that snap in when an enemy is within reach
--   Singularity Launcher         spinning vortex ring, drop marks for 10/20/30 m, loaded-shot pips
--   Psionic Blades (Infiltrator) twin crescents that close when an enemy is in reach, hack-ready diamond
--                                above; fades while cloaked
--   Echo Scanner (Infiltrator)   brackets on the real 70 deg scan cone, vortex spins while scanning
--   Claws (Subject)              claw slashes that flare in reach, climb pips while wall-walking
--   Plasma Miniguns (Praetor)    5 deg spread ring with a gun shard on each side, corner frame, energy
--                                arcs left + right; the ring turns into a spinning vortex while firing
-- Every design: brief white flash + corner hit marker when you deal damage.
-- Positions that depend on the view (spread, cone, drop) are projected with Client.WorldToScreen,
-- so they stay correct for any FOV / resolution.
-- ============================================================================

class 'GUIVTCrosshair' (GUIScript)

local kAtlas = PrecacheAsset("ui/vaelthor/crosshair_atlas.dds")
local kCell = 128

-- atlas cells {col, row} and the fraction of the cell the shape spans (to size by the shape itself)
local kDot      = { 0, 0, 0.14 }
local kPip      = { 1, 0, 0.25 }
local kRing     = { 2, 0, 0.86 }
local kVortex   = { 3, 0, 0.80 }
local kShardD   = { 0, 1, 0.625 }
local kShardU   = { 1, 1, 0.625 }
local kShardR   = { 2, 1, 0.625 }
local kShardL   = { 3, 1, 0.625 }
local kCrescL   = { 0, 2, 0.78 }
local kCrescR   = { 1, 2, 0.78 }
local kClaws    = { 2, 2, 0.70 }
local kChevron  = { 3, 2, 0.44 }
local kCornerTL = { 0, 3, 0.69 }
local kCornerTR = { 1, 3, 0.69 }
local kCornerBL = { 2, 3, 0.69 }
local kCornerBR = { 3, 3, 0.69 }

local kColVanguard    = Color(0.78, 0.45, 1.00, 1)
local kColOvercharge  = Color(1.00, 0.50, 0.85, 1)
local kColInfiltrator = Color(0.45, 1.00, 0.85, 1)
local kColSubject     = Color(1.00, 0.42, 0.80, 1)
local kColPraetor     = Color(0.86, 0.62, 1.00, 1)
local kColAccent      = Color(1.00, 0.95, 1.00, 1)
local kColDim         = Color(0.45, 0.35, 0.60, 0.6)
local kColWarn        = Color(1.00, 0.42, 0.42, 1)

local kGrenadeSpeed = 25        -- GrenadeLauncher.kGrenadeSpeed
local kGravity = 9.81           -- PredictedProjectile default
local kDropMarks = { 10, 20, 30 }

local function U(v) return GUIScale(v) end

local function Mix(a, b, t)
    return Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
end

local function WithAlpha(c, a)
    return Color(c.r, c.g, c.b, c.a * a)
end

function GUIVTCrosshair:Initialize()
    self.updateInterval = 0
    self.root = GUIManager:CreateGraphicItem()
    self.root:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.root:SetSize(Vector(0, 0, 0))
    self.root:SetColor(Color(0, 0, 0, 0))
    self.root:SetLayer(kGUILayerPlayerHUD)
    self.items = {}
    self.frame = 0
    self.lastEnergy = nil
    self.lastEnergyDrop = 0
end

function GUIVTCrosshair:Uninitialize()
    if self.root then
        GUI.DestroyItem(self.root)
        self.root = nil
    end
    self.items = {}
end

function GUIVTCrosshair:OnResolutionChanged()
    self:Uninitialize()
    self:Initialize()
end

-- Draw one shape this frame. key: stable id; shapeSize: on-screen size of the *shape* in px.
function GUIVTCrosshair:Put(key, cell, x, y, shapeSize, color)
    local item = self.items[key]
    if not item then
        item = GUIManager:CreateGraphicItem()
        item:SetTexture(kAtlas)
        item:SetLayer(kGUILayerPlayerHUD)
        self.root:AddChild(item)
        self.items[key] = item
    end
    local size = shapeSize / cell[3]
    item:SetTexturePixelCoordinates(cell[1] * kCell, cell[2] * kCell, (cell[1] + 1) * kCell, (cell[2] + 1) * kCell)
    item:SetSize(Vector(size, size, 0))
    item:SetPosition(Vector(x - size * 0.5, y - size * 0.5, 0))
    item:SetColor(color)
    item:SetIsVisible(true)
    item.vtFrame = self.frame
end

function GUIVTCrosshair:HideUnused()
    for _, item in pairs(self.items) do
        if item.vtFrame ~= self.frame then
            item:SetIsVisible(false)
        end
    end
end

-- ---- view helpers ------------------------------------------------------------
-- Screen offset (from the screen centre) of a world direction from the eye.
local function Project(player, dir)
    local eye = player:GetEyePos()
    local p = Client.WorldToScreen(eye + dir * 10)
    return p.x - Client.GetScreenWidth() * 0.5, p.y - Client.GetScreenHeight() * 0.5
end

-- On-screen radius of a cone with the given half angle (radians) around the view direction.
local function ConeRadius(player, halfAngle)
    local view = player:GetViewCoords()
    local _, y = Project(player, view.zAxis * math.cos(halfAngle) + view.yAxis * math.sin(halfAngle))
    return math.abs(y)
end

local function EnemyInReach(player, weapon, range)
    local eye = player:GetEyePos()
    local trace = Shared.TraceCapsule(eye, eye + player:GetViewCoords().zAxis * range, 0.25, 0,
            CollisionRep.Damage, PhysicsMask.Bullets, EntityFilterTwo(player, weapon))
    local ent = trace.entity
    return ent ~= nil and HasMixin(ent, "Live") and ent:GetIsAlive() and GetAreEnemies(player, ent)
end

local function MeleeRange(weapon)
    return (weapon.GetRange and weapon:GetRange() or 1) + 0.5     -- melee capsule starts at the eye + 0.5
end

-- ---- shared pieces -------------------------------------------------------------
function GUIVTCrosshair:HitMarker(flash)
    if flash <= 0.01 then return end
    local d = U(15) + U(6) * (1 - flash)
    local s = U(9)
    local c = WithAlpha(kColAccent, flash)
    self:Put("hitTL", kCornerTL, -d, -d, s, c)
    self:Put("hitTR", kCornerTR,  d, -d, s, c)
    self:Put("hitBL", kCornerBL, -d,  d, s, c)
    self:Put("hitBR", kCornerBR,  d,  d, s, c)
end

-- Row of pips on an arc around the centre. a0/a1 in degrees, 0 = right, 90 = down (screen space).
function GUIVTCrosshair:PipArc(prefix, n, frac, radius, a0, a1, size, onColor, offColor)
    local lit = math.floor(frac * n + 0.5)
    for i = 1, n do
        local a = math.rad(a0 + (a1 - a0) * (i - 1) / math.max(1, n - 1))
        local on = i <= lit
        self:Put(prefix .. i, kPip, math.cos(a) * radius, math.sin(a) * radius, size, on and onColor or offColor)
    end
end

-- ---- designs -------------------------------------------------------------------
function GUIVTCrosshair:DrawCarbine(player, weapon, flash)
    local over = weapon.vtOvercharged
    local base = over and kColOvercharge or kColVanguard
    local col = Mix(base, kColAccent, flash * 0.7)

    local spread = weapon:GetSpread() * (weapon.GetInaccuracyScalar and weapon:GetInaccuracyScalar(player) or 1)
    local gap = math.max(U(7), ConeRadius(player, spread)) + U(2)
    local len = (over and U(19) or U(15)) * (1 + flash * 0.2)
    local off = gap + len * 0.5
    self:Put("c_up",    kShardD, 0, -off, len, col)
    self:Put("c_down",  kShardU, 0,  off, len, col)
    self:Put("c_left",  kShardR, -off, 0, len, col)
    self:Put("c_right", kShardL,  off, 0, len, col)
    self:Put("c_dot", kDot, 0, 0, U(3), col)

    local energy = (weapon.clip or 0) / kVTCarbineEnergy
    local pipCol = energy < 0.25 and kColWarn or base
    self:PipArc("c_e", 10, energy, off + len * 0.5 + U(14), 125, 55, U(5), pipCol, kColDim)
end

function GUIVTCrosshair:DrawKnife(player, weapon, flash)
    local reach = EnemyInReach(player, weapon, MeleeRange(weapon))
    local col = Mix(kColVanguard, kColAccent, math.max(flash, reach and 0.6 or 0))
    self:Put("k_dot", kDot, 0, 0, U(3), col)
    self:Put("k_tip", kChevron, 0, U(13), U(12) * (reach and 1.25 or 1), col)
    local side = reach and U(10) or U(18)
    self:Put("k_l", kPip, -side, 0, U(7), col)
    self:Put("k_r", kPip,  side, 0, U(7), col)
end

function GUIVTCrosshair:DrawSingularity(player, weapon, flash)
    local col = Mix(kColVanguard, kColAccent, flash * 0.7)
    self:Put("s_vortex", kVortex, 0, 0, U(30), col)
    local spin = self.items["s_vortex"]
    spin:SetRotation(Vector(0, 0, Shared.GetTime() * 1.5))
    self:Put("s_dot", kDot, 0, 0, U(3), col)

    -- where the shot lands: aim direction minus gravity drop at 10/20/30 m
    local view = player:GetViewCoords()
    for i, dist in ipairs(kDropMarks) do
        local t = dist / kGrenadeSpeed
        local drop = 0.5 * kGravity * t * t
        local eye = player:GetEyePos()
        local p = Client.WorldToScreen(eye + view.zAxis * dist - Vector(0, drop, 0))
        local x = p.x - Client.GetScreenWidth() * 0.5
        local y = p.y - Client.GetScreenHeight() * 0.5
        self:Put("s_drop" .. i, kPip, x, y, U(9 - i * 1.5), WithAlpha(col, 1 - (i - 1) * 0.22))
    end

    local clip = weapon.clip or 0
    local size = math.max(1, weapon.GetClipSize and weapon:GetClipSize() or 4)
    for i = 1, size do
        self:Put("s_ammo" .. i, kPip, U(26), U(-12) + (i - 1) * U(8), U(6), i <= clip and col or kColDim)
    end
end

function GUIVTCrosshair:DrawBlades(player, weapon, flash)
    local reach = EnemyInReach(player, weapon, MeleeRange(weapon))
    local cloaked = HasMixin(player, "Cloakable") and player:GetCloakFraction() > 0.5
    local col = Mix(kColInfiltrator, kColAccent, math.max(flash, reach and 0.5 or 0))
    if cloaked then col = WithAlpha(col, 0.5) end
    local side = reach and U(9) or U(15)
    self:Put("b_l", kCrescL, -side, 0, U(20), col)
    self:Put("b_r", kCrescR,  side, 0, U(20), col)
    self:Put("b_dot", kDot, 0, 0, U(3), col)

    local ready = Shared.GetTime() >= (player.vtHackReadyTime or 0)
    self:Put("b_hack", kPip, 0, -U(22), U(ready and 9 or 6), ready and kColInfiltrator or kColDim)
end

function GUIVTCrosshair:DrawEchoScanner(player, weapon, flash)
    local scanning = player.vtEchoScanning
    local col = scanning and kColInfiltrator or WithAlpha(kColInfiltrator, 0.45)
    local view = player:GetViewCoords()
    local half = math.rad(kVTEchoPulseHalfAngle)
    local x = math.abs((Project(player, view.zAxis * math.cos(half) + view.xAxis * math.sin(half))))
    local y = ConeRadius(player, half)
    local maxX, maxY = Client.GetScreenWidth() * 0.5 - U(24), Client.GetScreenHeight() * 0.5 - U(24)
    x, y = math.min(x, maxX), math.min(y, maxY)
    local s = U(scanning and 30 or 24)
    self:Put("e_tl", kCornerTL, -x, -y, s, col)
    self:Put("e_tr", kCornerTR,  x, -y, s, col)
    self:Put("e_bl", kCornerBL, -x,  y, s, col)
    self:Put("e_br", kCornerBR,  x,  y, s, col)
    self:Put("e_vortex", kVortex, 0, 0, U(22), col)
    if scanning then
        self.items["e_vortex"]:SetRotation(Vector(0, 0, Shared.GetTime() * 4))
    end
    self:Put("e_dot", kDot, 0, 0, U(3), Mix(col, kColAccent, flash))
end

function GUIVTCrosshair:DrawClaws(player, weapon, flash)
    local reach = EnemyInReach(player, weapon, MeleeRange(weapon))
    local col = Mix(kColSubject, kColAccent, math.max(flash, reach and 0.55 or 0))
    self:Put("cl_claws", kClaws, 0, 0, U(reach and 34 or 28), WithAlpha(col, reach and 1 or 0.8))
    self:Put("cl_dot", kDot, 0, 0, U(3), col)
    if player.vtClimbing then
        self:Put("cl_climbL", kShardL, -U(30), 0, U(12), kColSubject)
        self:Put("cl_climbR", kShardR,  U(30), 0, U(12), kColSubject)
    end
end

function GUIVTCrosshair:DrawPraetor(player, flash)
    local energy = player.vtEnergy or 0
    local now = Shared.GetTime()
    if self.lastEnergy and energy < self.lastEnergy - 0.01 then
        self.lastEnergyDrop = now
    end
    self.lastEnergy = energy
    local firing = now - self.lastEnergyDrop < 0.3

    local col = Mix(kColPraetor, kColAccent, flash * 0.7)
    local r = math.max(U(14), ConeRadius(player, math.rad(kVTPraetorSpread)))
    if firing then
        self:Put("p_vortex", kVortex, 0, 0, r * 2, col)
        self.items["p_vortex"]:SetRotation(Vector(0, 0, now * 6))
    else
        self:Put("p_ring", kRing, 0, 0, r * 2, WithAlpha(col, 0.45))
    end
    self:Put("p_dot", kDot, 0, 0, U(4), col)
    local len = U(16)
    self:Put("p_gunL", kShardR, -(r + len * 0.5 + U(2)), 0, len, col)
    self:Put("p_gunR", kShardL,  (r + len * 0.5 + U(2)), 0, len, col)

    local f = r * 1.25 + U(8)
    local s = U(14)
    self:Put("p_tl", kCornerTL, -f, -f, s, WithAlpha(col, 0.6))
    self:Put("p_tr", kCornerTR,  f, -f, s, WithAlpha(col, 0.6))
    self:Put("p_bl", kCornerBL, -f,  f, s, WithAlpha(col, 0.6))
    self:Put("p_br", kCornerBR,  f,  f, s, WithAlpha(col, 0.6))

    local frac = energy / kVTPraetorEnergy
    local pipCol = frac < 0.25 and kColWarn or kColPraetor
    local ar = r + len + U(16)
    self:PipArc("p_el", 8, frac, ar, 125, 235, U(6), pipCol, kColDim)    -- left arc, bottom -> top
    self:PipArc("p_er", 8, frac, ar, 55, -55, U(6), pipCol, kColDim)     -- right arc, bottom -> top
end

-- ---- update ----------------------------------------------------------------------
local function GetCrosshairPlayer()
    if not Client.GetIsControllingPlayer() then return nil end
    local player = Client.GetLocalPlayer()
    if not player or not player:GetIsAlive() or not VT_GetIsVTEntity(player) then return nil end
    if player:isa("Commander") or player:isa("Spectator") then return nil end
    if player:GetIsThirdPerson() or MainMenu_GetIsOpened() or PlayerUI_GetBuyMenuDisplaying() then return nil end
    return player
end

function GUIVTCrosshair:Update(deltaTime)
    PROFILE("GUIVTCrosshair:Update")
    self.frame = self.frame + 1

    local player = GetCrosshairPlayer()
    if player then
        local show, pct = PlayerUI_GetShowGiveDamageIndicator()
        local flash = show and (1 - pct) or 0
        if player:isa("VTPraetor") then
            self:DrawPraetor(player, flash)
        else
            local weapon = player:GetActiveWeapon()
            if weapon then
                if weapon:isa("VTPlasmaCarbine") then
                    self:DrawCarbine(player, weapon, flash)
                elseif weapon:isa("VTPsionicKnife") then
                    self:DrawKnife(player, weapon, flash)
                elseif weapon:isa("VTSingularityLauncher") then
                    self:DrawSingularity(player, weapon, flash)
                elseif weapon:isa("VTPsionicBlade") then
                    self:DrawBlades(player, weapon, flash)
                elseif weapon:isa("VTEchoPulse") then
                    self:DrawEchoScanner(player, weapon, flash)
                elseif weapon:isa("VTSubjectClaws") then
                    self:DrawClaws(player, weapon, flash)
                else
                    self:Put("x_dot", kDot, 0, 0, U(4), kColVanguard)
                end
            end
        end
        self:HitMarker(flash)
    end

    self:HideUnused()
end

-- Client.lua uses this to hide the vanilla / exo crosshairs exactly when ours is drawn.
function VT_GetShowsOwnCrosshair()
    local player = Client.GetLocalPlayer()
    return player ~= nil and player:GetIsAlive() and VT_GetIsVTEntity(player)
            and not player:isa("Commander") and not player:isa("Spectator")
end
