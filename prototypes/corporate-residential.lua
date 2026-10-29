-- Временный вид жилого купола использует статичную графику ванильной лаборатории.
local picture = table.deepcopy(data.raw.lab.lab.off_animation)
data:extend({{
    type = "simple-entity-with-owner", name = "corporate-residential-block",
    icon = "__base__/graphics/icons/lab.png", icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    max_health = 500, minable = {mining_time = 1},
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}}, selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    picture = picture
}})
local planner = table.deepcopy(data.raw["selection-tool"]["corporate-project-planner"])
planner.name = "corporate-residential-planner"
planner.icon = "__base__/graphics/icons/lab.png"
data:extend({planner})
