local super_furnace = table.deepcopy(data.raw["furnace"]["stone-furnace"])
super_furnace.name = "super-furnace"
super_furnace.crafting_speed = 50                                            -- увеличиваем скорость плавки в 50 раз
super_furnace.minable = { mining_time = 1, result = "super-furnace" }        -- делаем супер-печь добываемой и указываем, что при добыче будет получен предмет "super-furnace"
local super_furnace_item = table.deepcopy(data.raw["item"]["stone-furnace"]) -- создаем копию предмета "stone-furnace" и присваиваем ее переменной "super_furnace_item"
super_furnace_item.name = "super-furnace"
super_furnace_item.place_result =
"super-furnace" -- указываем, что при установке предмета "super-furnace" будет создан объект "super-furnace"

local super_furnace_recipe = {
  type = "recipe",
  name = "super-furnace",
  energy_required = 5,
  enabled = false,
  ingredients = {
    { type = "item", name = "stone-furnace", amount = 1 },
    { type = "item", name = "steel-plate",   amount = 10 }
  },
  results = { { type = "item", name = "super-furnace", amount = 1 } }
}

data:extend(
  {
    super_furnace,
    super_furnace_item,
    super_furnace_recipe,
  }
)
