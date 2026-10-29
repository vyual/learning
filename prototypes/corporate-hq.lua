data:extend({
    {
        type = "item",
        name = "corporate-hq",
        icon = "__learning__/graphics/icons/nexus-hq-static.png",
        icon_size = 256,
        subgroup = "production-machine",
        order = "z[corporate-hq]",
        place_result = "corporate-hq",
        stack_size = 10
    }
})

data:extend({
    {
        type = "recipe",
        name = "corporate-hq",
        enabled = true,
        energy_required = 5,
        ingredients = {
            { type = "item", name = "iron-plate",         amount = 50 },
            { type = "item", name = "electronic-circuit", amount = 20 }
        },
        results = {
            { type = "item", name = "corporate-hq", amount = 1 }
        }
    }
})

data:extend({
    {
        type = "assembling-machine",
        name = "corporate-hq",
        icon = "__learning__/graphics/icons/nexus-hq-static.png",
        icon_size = 256,

        flags = { "placeable-neutral", "player-creation" },
        minable = { mining_time = 1, result = "corporate-hq" },
        max_health = 500,
        corpse = "big-remnants",

        collision_box = { { -2.4, -2.4 }, { 2.4, 2.4 } },
        selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } },

        crafting_categories = { "crafting" },
        crafting_speed = 1,
        energy_source = {
            type = "electric",
            usage_priority = "secondary-input"
        },
        energy_usage = "300kW",

        graphics_set = {
            animation = {
                filename = "__learning__/graphics/entity/corporate-hq/nexus-hq-static.png",
                width = 256,
                height = 256,
                frame_count = 1,
                scale = 1,
                shift = util.by_pixel(0, -16)
            },

            working_visualisations = {
                {
                    always_draw = true,
                    constant_speed = true,

                    animation = {
                        filename = "__learning__/graphics/entity/corporate-hq/nexus-hq-HQ_Status_Loop.png",
                        priority = "high",
                        width = 512,
                        height = 512,
                        shift = { 0.000000, -1.532609 },
                        frame_count = 48,
                        line_length = 7,
                        animation_speed = 0.4,
                        scale = 0.562679708
                    }
                }
            }
        }
    }
})
