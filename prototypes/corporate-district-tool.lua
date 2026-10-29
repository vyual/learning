data:extend({{
    type = "selection-tool", name = "corporate-district-planner",
    icon = "__base__/graphics/icons/radar.png", icon_size = 64,
    flags = {"only-in-cursor", "not-stackable"}, hidden = true, stack_size = 1,
    select = {border_color = {0.2, 0.9, 0.5}, mode = {"any-tile"}, cursor_box_type = "copy"},
    alt_select = {border_color = {0.9, 0.4, 0.2}, mode = {"any-tile"}, cursor_box_type = "not-allowed"},
    always_include_tiles = true,
    send_pre_selection_events = true
}})
