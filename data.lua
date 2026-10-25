require("prototypes.super-coal")
require("prototypes.super-furnace")


local recipes_steel_processing = { "super-coal", "super-furnace" }
local tech_steel_processing = data.raw.technology["steel-processing"]

for index, recipe_name in ipairs(recipes_steel_processing) do
  if tech_steel_processing and tech_steel_processing.effects then
    table.insert(tech_steel_processing.effects, {
      type = "unlock-recipe",
      recipe = recipe_name
    })
  end
end
