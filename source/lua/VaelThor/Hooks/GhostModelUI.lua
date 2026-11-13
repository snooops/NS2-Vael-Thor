-- ============================================================================
-- Commander ghost preview: Vael'Thor buildings are drawn at kVTStructureModelScale
-- (VT_InstallStructureScale), so the placement preview is scaled the same way.
-- ============================================================================

local oldGetGhostModelCoords = GhostModelUI_GetGhostModelCoords
function GhostModelUI_GetGhostModelCoords()
    local coords = oldGetGhostModelCoords()
    local modelName = GhostModelUI_GetModelName()
    if coords and modelName and kVTScaledStructureModels and kVTScaledStructureModels[modelName] then
        -- new object: the commander keeps its ghost coords between frames, scaling them in place would compound
        local s = kVTStructureModelScale
        local scaled = Coords()
        scaled.origin = Vector(coords.origin)
        scaled.xAxis = coords.xAxis * s
        scaled.yAxis = coords.yAxis * s
        scaled.zAxis = coords.zAxis * s
        coords = scaled
    end
    return coords
end
