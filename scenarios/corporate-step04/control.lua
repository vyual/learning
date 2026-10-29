local corporations = require("__learning__/scripts/corporations")
local orders = require("__learning__/scripts/orders")
local projects = require("__learning__/scripts/projects")
local districts = require("__learning__/scripts/districts")
local FRAME = "corporate_dominion_hq"

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if not player.character then assert(player.create_character()) end
    local force = player.force
    local surface = game.create_surface("district-test", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -25, 40 do for y = -25, 40 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = force}
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    local corporation = corporations.found(force.index, player.index, "Делегирование")
    inventory.insert {name = "iron-plate", count = 100}
    assert(orders.deliver(player, hq, corporation))
    local area = {left_top = {x = 7, y = 7}, right_bottom = {x = 19, y = 19}}
    assert(districts.begin(player, hq, corporation))
    local ok, message = districts.define(player, surface,
        {left_top = {x = 7, y = 7}, right_bottom = {x = 9, y = 9}}, corporation)
    assert(not ok and message[1] == "corporate-districts.bad-size")
    assert(districts.define(player, surface, area, corporation))
    local district = corporation.district
    assert(district.outline.valid and district.bounds.left == 7 and corporation.credits == 1000)
    assert(not districts.issue(player, hq, corporation))
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    frame.body.district.administrator_name.text = " "
    corporations.on_gui_click {player_index = player.index, element = frame.body.district.corporate_district_assign}
    assert(not district.administrator)
    frame.body.district.administrator_name.text = "  Ирина Волкова  "
    corporations.on_gui_click {player_index = player.index, element = frame.body.district.corporate_district_assign}
    assert(district.administrator.name == "Ирина Волкова")
    corporations.on_gui_click {player_index = player.index, element = frame.body.district.corporate_district_issue}
    assert(district.order.status == "pending" and district.order.budget == 500)
    assert(not districts.begin(player, hq, corporation))
    corporations.on_district_tick()
    assert(district.order.reason == "no-depot" and corporation.credits == 1000)
    assert(frame.body.district.status.caption[1] == "corporate-districts.status-no-depot")
    corporations.on_gui_click {player_index = player.index, element = frame.body.district.corporate_district_cancel}
    assert(not district.order)

    for _, item in ipairs(projects.definition.materials) do inventory.insert(item) end
    assert(projects.begin(player, hq, corporation))
    assert(projects.build(player, surface,
        {left_top = {x = 8, y = -9}, right_bottom = {x = 9, y = -8}}, corporation))
    assert(corporation.credits == 500)
    local stock = {}
    for _, entity in ipairs(corporation.projects[1].entities) do
        if entity.name == "iron-chest" then stock[#stock + 1] = entity.get_inventory(defines.inventory.chest) end
    end
    assert(#stock == 4)
    -- Администратор не имеет права тратить личный инвентарь даже при наличии материалов.
    for _, item in ipairs(projects.definition.materials) do inventory.insert(item) end
    assert(districts.issue(player, hq, corporation))
    corporations.on_district_tick()
    assert(district.order.reason == "no-materials" and corporation.credits == 500)
    corporation.credits = 499
    corporations.on_district_tick()
    assert(district.order.reason == "no-money")
    corporation.credits = 500
    hq.destroy()
    corporations.on_district_tick()
    assert(district.order.reason == "no-hq" and corporation.credits == 500)
    assert(districts.cancel_order(corporation))
    hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = force}
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    frame = player.gui.screen[FRAME]
    assert(districts.issue(player, hq, corporation))
    stock[1].insert {name = "iron-plate", count = 16}
    stock[2].insert {name = "iron-plate", count = 17}
    stock[3].insert {name = "electronic-circuit", count = 1}
    stock[4].insert {name = "copper-cable", count = 3}
    if prototypes.quality.uncommon then stock[1].insert {name = "iron-plate", quality = "uncommon", count = 33} end
    local water = {}
    for x = 7, 18 do for y = 7, 18 do water[#water + 1] = {name = "water", position = {x, y}} end end
    surface.set_tiles(water, false)
    corporations.on_district_tick()
    assert(district.order.reason == "blocked" and corporation.credits == 500)
    for _, tile in ipairs(water) do tile.name = "grass-1" end
    surface.set_tiles(water, false)
    local blocker = surface.create_entity {name = "stone-furnace", position = {8.5, 8.5}, force = force}
    corporations.on_district_tick()
    assert(district.order.status == "completed" and district.order.reason == "completed")
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    local built = corporation.projects[district.order.project_index]
    assert(built.position.x == 11.5 and built.position.y == 8.5, "Administrator did not skip the blocked site")
    assert(blocker.valid and #built.entities == 5)
    assert(frame.body.district.status.caption[1] == "corporate-districts.status-completed")
    assert(inventory.get_item_count {name = "iron-plate", quality = "normal"} == 33)
    assert(inventory.get_item_count {name = "electronic-circuit", quality = "normal"} == 1)
    for _, inv in ipairs(stock) do
        assert(inv.get_item_count {name = "iron-plate", quality = "normal"} == 0)
        assert(inv.get_item_count {name = "electronic-circuit", quality = "normal"} == 0)
        assert(inv.get_item_count {name = "copper-cable", quality = "normal"} == 0)
    end
    if prototypes.quality.uncommon then assert(stock[1].get_item_count {name = "iron-plate", quality = "uncommon"} == 33) end
    corporations.on_district_tick()
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    assert(not districts.issue(player, hq, corporation) and not districts.cancel_order(corporation))
    local old_outline = district.outline
    assert(districts.begin(player, hq, corporation))
    assert(districts.define(player, surface,
        {left_top = {x = 10, y = 7}, right_bottom = {x = 22, y = 19}}, corporation))
    assert(not old_outline.valid and district.outline.valid and district.order.status == "completed")

    local rival = game.create_force("district-rival")
    player.force = rival
    assert(player.teleport({4.5, -7.5}, surface))
    local rival_hq = surface.create_entity {name = "corporate-hq", position = {0.5, -7.5}, force = rival}
    local rival_corp = corporations.found(rival.index, player.index, "Сосед")
    assert(districts.begin(player, rival_hq, rival_corp))
    ok, message = districts.define(player, surface,
        {left_top = {x = 10, y = 7}, right_bottom = {x = 16, y = 13}}, rival_corp)
    assert(not ok and message[1] == "corporate-districts.overlap")
    districts.cancel_selection(player); player.force = force
    log("STEP04 DISTRICT, ADMINISTRATOR, STOCK SUPPLIES, WAITING, BUDGET AND NO DUPLICATES PASSED")
    script.finish_test(true)
end)
