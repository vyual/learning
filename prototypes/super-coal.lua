local super_coal = {
  type = "item", name = "super-coal", stack_size = 1000,
}
super_coal.icons = {
  {
    icon = "__base__/graphics/icons/coal.png",
    tint = { r = 1, g = 0.2, b = 0.2, a = 1 } -- красноватый оттенок (r = red, g = green, b = blue, a = прозрачность)
  }
}
super_coal.fuel_categories = { "chemical" }
super_coal.fuel_value = "50MJ"

local super_coal_recipe = {
  type = "recipe",     -- тип объекта, указывающий, что это рецепт
  name = "super-coal", -- имя рецепта, которое будет использоваться в игре
  energy_required = 3, -- число, указывающее, сколько секунд создается предмет
  enabled = false,     -- указывает, доступен ли рецепт сразу или его нужно разблокировать через технологию
  ingredients = {      -- список ингредиентов, необходимых для создания предмета
    {
      type = "item",
      name = "coal",
      amount = 5
    },
    {
      type = "item",
      name = "wood",
      amount = 2
    } },
  results = { { -- список результатов, которые будут получены после создания предмета
    type = "item",
    name = "super-coal",
    amount = 1
  } },
}

data:extend(
  {
    super_coal,
    super_coal_recipe,
  }
)