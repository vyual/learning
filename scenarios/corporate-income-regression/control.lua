-- Воспроизводим тупик: первый заказ оплачен, два склада построены, управляющий ждёт денег.
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
    local surface = game.create_surface("income-regression", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -25, 40 do for y = -25, 40 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = force}
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    local corporation = corporations.found(force.index, player.index, "NEXUS")
    inventory.insert {name = "iron-plate", count = 100}
    assert(not orders.deliver_supply(player, hq, corporation))
    assert(inventory.get_item_count("iron-plate") == 100 and corporation.credits == 0)
    assert(orders.deliver(player, hq, corporation))
    local first_record = corporation.orders[orders.definition.id]
    for i = 1, 2 do
        for _, item in ipairs(projects.definition.materials) do inventory.insert(item) end
        assert(projects.construct(force, hq, surface, {x = 5.5 + i*6, y = -8.5}, corporation, {inventory}))
    end
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    assert(districts.begin(player, hq, corporation))
    assert(districts.define(player, surface,
        {left_top = {x = 7, y = 7}, right_bottom = {x = 19, y = 19}}, corporation))
    assert(districts.assign(corporation, "Ирина Волкова"))
    assert(districts.issue(player, hq, corporation))
    local stock = corporation.projects[1].entities[1].get_inventory(defines.inventory.chest)
    for _, item in ipairs(projects.definition.materials) do stock.insert(item) end
    corporations.on_district_tick()
    assert(corporation.district.order.reason == "no-money")
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    assert(not frame.body.order.corporate_dominion_deliver.enabled)
    assert(frame.body.order.corporate_dominion_supply.enabled and orders.supply_count(corporation) == 0)
    inventory.insert {name = "iron-plate", count = 99}
    player.cursor_stack.set_stack {name = "iron-plate", count = 100}
    if prototypes.quality.uncommon then inventory.insert {name = "iron-plate", quality = "uncommon", count = 100} end
    local function click_supply()
        corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_supply}
    end
    click_supply()
    assert(corporation.credits == 0 and orders.supply_count(corporation) == 0)
    assert(frame.body.order.feedback.caption[1] == "corporate-orders.not-enough")
    assert(inventory.get_item_count {name = "iron-plate", quality = "normal"} == 99)
    inventory.insert {name = "iron-plate", count = 1}
    click_supply()
    assert(corporation.credits == 500 and orders.supply_count(corporation) == 1)
    assert(inventory.get_item_count {name = "iron-plate", quality = "normal"} == 0)
    assert(player.cursor_stack.count == 100)
    if prototypes.quality.uncommon then assert(inventory.get_item_count {name = "iron-plate", quality = "uncommon"} == 100) end
    corporations.on_district_tick()
    assert(corporation.district.order.status == "completed")
    assert(corporation.credits == 0 and projects.count(corporation) == 3)
    click_supply()
    assert(corporation.credits == 0 and orders.supply_count(corporation) == 1, "Duplicate event paid without goods")
    inventory.insert {name = "iron-plate", count = 250}
    click_supply(); click_supply()
    assert(corporation.credits == 1000 and orders.supply_count(corporation) == 3)
    assert(inventory.get_item_count {name = "iron-plate", quality = "normal"} == 50)
    click_supply()
    assert(corporation.credits == 1000 and orders.supply_count(corporation) == 3)
    local record = corporation.orders[orders.supply_definition.id]
    assert(record.delivered == 300 and record.credits_earned == 1500)
    assert(corporation.orders[orders.definition.id] == first_record, "The startup order was reset")
    assert(not orders.deliver(player, hq, corporation))
    corporations.close(player)
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    assert(tonumber(player.gui.screen[FRAME].body.order.supply_count.caption[2]) == 3)
    assert(corporation.district.administrator.name == "Ирина Волкова" and projects.count(corporation) == 3)
    log("INCOME REGRESSION PASSED: ZERO BALANCE RECOVERED, ADMIN RESUMED, REPEATED SHIPMENTS PAID ONLY WITH GOODS")
    script.finish_test(true)
end)
