-- Сквозная проверка: заработать на поставке, выбрать место и оплатить готовый склад.
local corporations = require("__learning__/scripts/corporations")
local orders = require("__learning__/scripts/orders")
local projects = require("__learning__/scripts/projects")
local FRAME = "corporate_dominion_hq"

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if not player.character then assert(player.create_character()) end
    local surface = game.create_surface("corporate-project-test", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -25, 40 do for y = -25, 40 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = player.force}
    local inventory = assert(player.get_main_inventory())
    inventory.clear()
    player.clear_cursor()
    local corporation = corporations.found(player.force.index, player.index, "Строитель")
    local area = {left_top = {x = 8, y = 8}, right_bottom = {x = 9, y = 9}}
    local function material_count(name)
        return inventory.get_item_count {name = name, quality = "normal"}
    end
    local function add_materials()
        for _, item in ipairs(projects.definition.materials) do assert(inventory.insert(item) == item.count) end
    end
    local ok, message = projects.begin(player, hq, corporation)
    assert(not ok and message[1] == "corporate-projects.no-money")
    inventory.insert {name = "iron-plate", count = 100}
    assert(orders.deliver(player, hq, corporation))
    assert(corporation.credits == 1000)
    inventory.insert {name = "iron-plate", count = 32}
    if prototypes.quality.uncommon then inventory.insert {name = "iron-plate", quality = "uncommon", count = 33} end
    ok, message = projects.begin(player, hq, corporation)
    assert(not ok and message[1] == "corporate-projects.no-materials")
    inventory.insert {name = "iron-plate", count = 1}
    inventory.insert {name = "electronic-circuit", count = 1}
    inventory.insert {name = "copper-cable", count = 3}

    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    corporations.on_gui_click {player_index = player.index, element = frame.body.project.corporate_dominion_build}
    assert(not frame.valid, "The card did not close for site selection")
    assert(player.cursor_stack.valid_for_read and player.cursor_stack.name == projects.tool_name)
    assert(corporation.credits == 1000 and material_count("iron-plate") == 33, "Selecting a tool charged the player")
    local blocker = surface.create_entity {name = "stone-furnace", position = {8.5, 8.5}, force = player.force}
    ok, message = projects.build(player, surface, area, corporation)
    assert(not ok and message[1] == "corporate-projects.blocked")
    assert(corporation.credits == 1000 and material_count("iron-plate") == 33)
    assert(projects.count(corporation) == 0)
    blocker.destroy()
    local water_area = {left_top = {x = 16, y = 8}, right_bottom = {x = 17, y = 9}}
    surface.set_tiles {{name = "water", position = {16, 8}}}
    ok, message = projects.build(player, surface, water_area, corporation)
    assert(not ok and message[1] == "corporate-projects.blocked")
    ok, message = projects.build(player, surface,
        {left_top = {x = 60, y = 60}, right_bottom = {x = 61, y = 61}}, corporation)
    assert(not ok and message[1] == "corporate-projects.too-far")
    ok, message = projects.build(player, game.surfaces.nauvis, area, corporation)
    assert(not ok and message[1] == "corporate-projects.wrong-surface")
    assert(corporation.credits == 1000 and material_count("iron-plate") == 33)

    corporations.on_player_selected_area {player_index = player.index, item = projects.tool_name, surface = surface, area = area}
    assert(projects.count(corporation) == 1 and corporation.credits == 500)
    assert(material_count("iron-plate") == 0 and material_count("electronic-circuit") == 0 and material_count("copper-cable") == 0)
    if prototypes.quality.uncommon then assert(inventory.get_item_count {name = "iron-plate", quality = "uncommon"} == 33) end
    assert(#corporation.projects[1].entities == 5)
    local chests, lamps = 0, 0
    for _, entity in ipairs(corporation.projects[1].entities) do
        assert(entity.valid and entity.force == player.force)
        if entity.name == "iron-chest" then chests = chests + 1 end
        if entity.name == "small-lamp" then lamps = lamps + 1 end
    end
    assert(chests == 4 and lamps == 1)
    assert(not player.cursor_stack.valid_for_read)
    ok, message = projects.build(player, surface, area, corporation)
    assert(not ok and message[1] == "corporate-projects.no-selection")
    assert(corporation.credits == 500 and projects.count(corporation) == 1)

    add_materials()
    assert(projects.begin(player, hq, corporation))
    corporations.on_player_alt_selected_area {player_index = player.index, item = projects.tool_name}
    assert(corporation.credits == 500 and material_count("iron-plate") == 33)
    assert(projects.begin(player, hq, corporation))
    player.clear_cursor()
    projects.on_cursor_changed {player_index = player.index}
    assert(not projects.build(player, surface, area, corporation))
    assert(corporation.credits == 500 and material_count("iron-plate") == 33)
    assert(projects.begin(player, hq, corporation))
    hq.destroy()
    ok, message = projects.build(player, surface, area, corporation)
    assert(not ok and message[1] == "corporate-dominion.hq-unavailable")
    assert(corporation.credits == 500 and material_count("iron-plate") == 33)
    hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = player.force}
    assert(projects.begin(player, hq, corporation))
    assert(projects.build(player, surface,
        {left_top = {x = 20, y = 20}, right_bottom = {x = 21, y = 21}}, corporation))
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    ok, message = projects.begin(player, hq, corporation)
    assert(not ok and message[1] == "corporate-projects.no-money")
    assert(orders.is_complete(corporation), "Construction reset the completed order")
    log("STEP03 EARN, SELECT, BUILD, COLLISIONS, CANCEL AND PAYMENT CHECKS PASSED")
    script.finish_test(true)
end)
