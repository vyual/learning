local corporations = require("__learning__/scripts/corporations")
local orders = require("__learning__/scripts/orders")
local projects = require("__learning__/scripts/projects")
local districts = require("__learning__/scripts/districts")
local auto_supply = require("__learning__/scripts/auto_supply")
local stockpiles = require("__learning__/scripts/stockpiles")
local FRAME = "corporate_dominion_hq"

script.on_nth_tick(120, corporations.on_district_tick)
script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if storage.auto_regression then
        local test = storage.auto_regression
        if game.tick < test.check_tick then return end
        local corporation = corporations.get(player.force.index)
        assert(corporation.credits == test.credits + orders.supply_definition.reward)
        assert(corporation.auto_supply.shipments == test.shipments + 1)
        assert(test.inventory.get_item_count {name = "iron-plate", quality = "normal"} == 0)
        assert(corporation.auto_supply.next_tick > game.tick)
        log("AUTO SUPPLY PASSED: REAL TIMER, PHYSICAL GOODS, QUALITY, RESERVE, BUILD, GUI, STOP, FORCE, SURFACE, NO DUPLICATES")
        script.finish_test(true)
        return
    end
    if not player.character then assert(player.create_character()) end
    local surface = game.create_surface("auto-test", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -30, 30 do for y = -30, 30 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local force = player.force
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = force}
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    local corporation = corporations.found(force.index, player.index, "Auto Test")
    assert(not auto_supply.enabled(corporation) and not corporation.auto_supply)
    assert(not auto_supply.set_enabled(player, hq, corporation, true))
    inventory.insert {name = "iron-plate", count = 100}
    assert(orders.deliver(player, hq, corporation))
    local first_record = corporation.orders[orders.definition.id]
    local function build(center)
        for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
        assert(projects.construct(force, hq, surface, center, corporation, {inventory}))
    end
    build {x = 10.5, y = -8.5}; build {x = 16.5, y = -8.5}
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    assert(not auto_supply.set_enabled(player, hq, corporation, true))
    assert(districts.begin(player, hq, corporation))
    assert(districts.define(player, surface,
        {left_top = {x = 7, y = 7}, right_bottom = {x = 19, y = 19}}, corporation))
    assert(not auto_supply.set_enabled(player, hq, corporation, true))
    assert(districts.assign(corporation, "Auto Admin"))
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_auto_supply}
    assert(auto_supply.enabled(corporation) and corporation.auto_supply.next_tick == game.tick + auto_supply.interval)
    local due = corporation.auto_supply.next_tick
    assert(auto_supply.set_enabled(player, hq, corporation, true))
    assert(corporation.auto_supply.next_tick == due, "Duplicate enable must not alter the timer")
    auto_supply.tick(); assert(corporation.credits == 0 and orders.supply_count(corporation) == 0)
    local stock = stockpiles.collect(corporation, force, surface)
    assert(#stock == 8)
    local rival = game.create_force("auto-rival")
    local foreign = surface.create_entity {name = "iron-chest", position = {-10.5, -10.5}, force = rival}
    local ordinary = surface.create_entity {name = "iron-chest", position = {-12.5, -10.5}, force = force}
    foreign.insert {name = "iron-plate", count = 100}; ordinary.insert {name = "iron-plate", count = 100}
    local other = game.create_surface("auto-other")
    local elsewhere = other.create_entity {name = "iron-chest", position = {0.5, 0.5}, force = force}
    elsewhere.insert {name = "iron-plate", count = 100}
    local fake = {projects = {corporation.projects[1], corporation.projects[1],
        {surface_index = surface.index, entities = {foreign, elsewhere}},
        {surface_index = other.index, entities = {elsewhere}}}}
    assert(#stockpiles.collect(fake, force, surface) == 4, "Duplicate and foreign inventories must be excluded")
    inventory.insert {name = "iron-plate", count = 100}
    player.cursor_stack.set_stack {name = "iron-plate", count = 100}
    local function attempt()
        corporation.auto_supply.next_tick = game.tick
        corporations.on_district_tick()
    end
    attempt()
    assert(corporation.auto_supply.reason == "stock" and corporation.credits == 0)
    stock[1].insert {name = "iron-plate", count = 99}
    if prototypes.quality.uncommon then stock[1].insert {name = "iron-plate", quality = "uncommon", count = 100} end
    attempt(); assert(corporation.credits == 0 and stock[1].get_item_count {name = "iron-plate", quality = "normal"} == 99)
    stock[2].insert {name = "iron-plate", count = 1}
    attempt(); assert(corporation.credits == 500 and orders.supply_count(corporation) == 1)
    assert(corporation.auto_supply.shipments == 1)
    corporations.on_district_tick(); assert(corporation.credits == 500, "Same-tick repeat paid twice")
    assert(inventory.get_item_count("iron-plate") == 100 and player.cursor_stack.count == 100)
    assert(foreign.get_item_count("iron-plate") == 100 and ordinary.get_item_count("iron-plate") == 100)
    assert(elsewhere.get_item_count("iron-plate") == 100)
    if prototypes.quality.uncommon then assert(stock[1].get_item_count {name = "iron-plate", quality = "uncommon"} == 100) end
    build {x = -10.5, y = -8.5}
    assert(corporation.credits == 0)
    assert(districts.issue(player, hq, corporation))
    stock[1].insert {name = "iron-plate", count = 99}
    stock[2].insert {name = "iron-plate", count = 33}
    stock[2].insert {name = "electronic-circuit", count = 1}; stock[2].insert {name = "copper-cable", count = 3}
    assert(auto_supply.reserve(corporation, surface) == 33)
    attempt()
    assert(corporation.credits == 0 and corporation.district.order.status == "pending")
    assert(stock[1].get_item_count {name = "iron-plate", quality = "normal"} == 99)
    stock[2].insert {name = "iron-plate", count = 1}
    attempt()
    assert(corporation.district.order.status == "completed" and projects.count(corporation) == 4)
    assert(corporation.credits == 0 and orders.supply_count(corporation) == 2)
    assert(stock[1].get_item_count {name = "iron-plate", quality = "normal"} == 0)
    assert(stock[2].get_item_count {name = "iron-plate", quality = "normal"} == 0)
    assert(auto_supply.reserve(corporation, surface) == 0)
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_supply}
    assert(corporation.credits == 500 and orders.supply_count(corporation) == 3)
    assert(corporation.auto_supply.shipments == 2)
    assert(tonumber(frame.body.order.auto_count.caption[2]) == 2)
    stock[1].insert {name = "iron-plate", count = 100}
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_auto_supply}
    assert(not auto_supply.enabled(corporation) and corporation.auto_supply.reason == "off")
    corporation.auto_supply.next_tick = game.tick
    corporations.on_district_tick(); assert(corporation.credits == 500 and stock[1].get_item_count("iron-plate") >= 100)
    assert(auto_supply.set_enabled(player, hq, corporation, true))
    local administrator = corporation.district.administrator
    corporation.district.administrator = nil
    attempt(); assert(corporation.auto_supply.reason == "no-administrator" and corporation.credits == 500)
    corporation.district.administrator = administrator
    local history = corporation.projects; corporation.projects = {}
    attempt(); assert(corporation.auto_supply.reason == "no-depot" and corporation.credits == 500)
    corporation.projects = history
    hq.force = rival
    attempt(); assert(corporation.auto_supply.reason == "no-hq" and corporation.credits == 500)
    hq.force = force
    local doomed = surface.create_entity {name = "corporate-hq", position = {-20, 10}, force = force}
    corporation.auto_supply.hq = doomed; doomed.destroy()
    attempt(); assert(corporation.auto_supply.reason == "no-hq" and corporation.credits == 500)
    corporation.auto_supply.hq = hq
    corporation.orders[orders.definition.id] = nil
    attempt(); assert(corporation.auto_supply.reason == "first-order" and corporation.credits == 500)
    corporation.orders[orders.definition.id] = first_record
    assert(auto_supply.set_enabled(player, nil, corporation, false), "Stopping must work even when the HQ is gone")
    assert(auto_supply.set_enabled(player, hq, corporation, true))
    corporations.close(player); corporations.on_gui_opened {player_index = player.index, entity = hq}
    assert(player.gui.screen[FRAME].body.order.corporate_dominion_auto_supply.caption[1] == "corporate-auto.disable")
    -- Последняя партия проходит по настоящим тикам: до срока никакой выплаты.
    storage.auto_regression = {credits = corporation.credits, shipments = corporation.auto_supply.shipments,
        inventory = stock[1], check_tick = (math.ceil(corporation.auto_supply.next_tick / 120) * 120) + 1}
end)
