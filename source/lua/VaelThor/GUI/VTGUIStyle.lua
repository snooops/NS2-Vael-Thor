-- ============================================================================
-- VTGUIStyle - shared look of the Vael'Thor menus (Synthesis Matrix menu,
-- Nexus Gate menu): solid dark bodies under the crystal frame textures
-- (ui/vaelthor/hud_*.dds, art/ui/make_hud_textures.py - the frames alone are
-- too translucent), violet / cyan palette, and text fitted to its box.
-- All sizes are unscaled GUI units (1920x1080 reference, GUIScale applied here).
-- ============================================================================

VTGUIStyle = VTGUIStyle or {}
local St = VTGUIStyle

St.kPanelTex = PrecacheAsset("ui/vaelthor/hud_panel.dds")
St.kChipTex  = PrecacheAsset("ui/vaelthor/hud_chip.dds")

St.kColDim           = Color(0, 0, 0, 0.55)                 -- full-screen dimming behind a menu
St.kColBody          = Color(0.035, 0.018, 0.07, 0.96)      -- solid panel body
St.kColCardBody      = Color(0.07, 0.035, 0.13, 0.97)
St.kColCardBodyHover = Color(0.13, 0.07, 0.22, 0.98)
St.kColCardBodySel   = Color(0.05, 0.16, 0.20, 0.98)
St.kColFrame         = Color(0.80, 0.70, 1.00, 1)
St.kColFrameHover    = Color(1.00, 0.92, 1.00, 1)
St.kColSelected      = Color(0.45, 1.00, 1.00, 1)
St.kColLocked        = Color(0.45, 0.43, 0.52, 1)
St.kColText          = Color(0.92, 0.86, 1.00, 1)
St.kColDimText       = Color(0.68, 0.60, 0.82, 1)
St.kColKey           = Color(0.80, 0.50, 1.00, 1)
St.kColCyan          = Color(0.35, 0.95, 1.00, 1)
St.kColReady         = Color(0.55, 1.00, 0.85, 1)
St.kColWarn          = Color(1.00, 0.45, 0.45, 1)
St.kColActive        = Color(1.00, 0.85, 1.00, 1)

St.kCursor = "ui/Cursor_MenuDefault.dds"

function St.S(x, y)
    return GUIScale(Vector(x, y, 0))
end

-- Graphic item; parent nil = a root item (the caller destroys it).
function St.Graphic(parent, tex, w, h, x, y, color, layer)
    local item = GUIManager:CreateGraphicItem()
    if tex then item:SetTexture(tex) end
    item:SetSize(St.S(w, h))
    item:SetPosition(St.S(x, y))
    item:SetColor(color or Color(1, 1, 1, 1))
    item:SetLayer(layer or kGUILayerPlayerHUDForeground1)
    if parent then
        parent:AddChild(item)
    end
    return item
end

function St.Text(parent, font, x, y, alignX, color)
    local t = GUIManager:CreateTextItem()
    t:SetFontName(font)
    t:SetScale(GetScaledVector())
    GUIMakeFontScale(t)
    t:SetTextAlignmentX(alignX or GUIItem.Align_Min)
    t:SetTextAlignmentY(GUIItem.Align_Center)
    t:SetPosition(St.S(x, y))
    t:SetColor(color or St.kColText)
    t:SetLayer(kGUILayerPlayerHUDForeground4)
    parent:AddChild(t)
    return t
end

-- A solid body with the crystal frame texture on top. Returns body, frame.
function St.Box(parent, tex, w, h, x, y, bodyColor, frameColor, layer)
    layer = layer or kGUILayerPlayerHUDForeground2
    local body = St.Graphic(parent, nil, w, h, x, y, bodyColor or St.kColCardBody, layer)
    local frame = St.Graphic(body, tex or St.kChipTex, w, h, 0, 0, frameColor or St.kColFrame, layer + 1)
    return body, frame
end

-- Sets text, shortened with "..." so it stays within maxWidth (unscaled GUI units).
function St.SetFittedText(item, text, maxWidth)
    text = text or ""
    local limit = GUIScale(maxWidth)
    local scale = item:GetScale().x
    if item:GetTextWidth(text) * scale <= limit then
        item:SetText(text)
        return
    end
    local chars = string.UTF8Encode(text)
    local lo, hi = 0, #chars
    while lo < hi do                                    -- longest prefix that fits with "..."
        local mid = math.ceil((lo + hi) / 2)
        if item:GetTextWidth(table.concat(chars, "", 1, mid) .. "...") * scale <= limit then
            lo = mid
        else
            hi = mid - 1
        end
    end
    item:SetText(table.concat(chars, "", 1, lo) .. "...")
end

function St.GetHovered(item)
    if not MouseTracker_GetIsVisible() then
        return false
    end
    local x, y = Client.GetCursorPosScreen()
    return GUIItemContainsPoint(item, x, y)
end

-- Hover / selection colours of a Box (body, frame).
function St.ColorBox(body, frame, hovered, selected)
    if selected then
        body:SetColor(St.kColCardBodySel)
        frame:SetColor(St.kColSelected)
    elseif hovered then
        body:SetColor(St.kColCardBodyHover)
        frame:SetColor(St.kColFrameHover)
    else
        body:SetColor(St.kColCardBody)
        frame:SetColor(St.kColFrame)
    end
end
