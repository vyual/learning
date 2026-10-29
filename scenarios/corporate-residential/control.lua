local corporations = require("__learning__/scripts/corporations")
local projects = require("__learning__/scripts/projects")
local orders = require("__learning__/scripts/orders")
local districts = require("__learning__/scripts/districts")
local residential = require("__learning__/scripts/residential")
local stockpiles = require("__learning__/scripts/stockpiles")
local preview = require("__learning__/scripts/planner_preview")
local FRAME = "corporate_dominion_hq"
script.on_nth_tick(120, corporations.on_district_tick)

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if storage.residential_test then
        local test = storage.residential_test
        local corporation = corporations.get(player.force.index)
        if game.tick < test.due then
            assert(corporation.credits == test.credits and corporation.residential.cycles == test.cycles, "Early residential payment")
            return
        end
        if game.tick < test.check_tick then return end
        assert(corporation.credits == test.credits + residential.income)
        assert(corporation.residential.cycles == test.cycles + 1 and corporation.residential.consumed == 15)
        assert(test.stock.get_item_count {name = "raw-fish", quality = "normal"} == 0)
        assert(player.gui.screen[FRAME].body.residential.status.caption[1] == "corporate-residential.status-supplied")
        log("RESIDENTIAL PASSED: BUILD, DISTRICT, PREVIEW, ATOMIC COST, FOOD, QUALITY, REAL TIMER, RECOVERY, HISTORY, NO FREE PAYMENTS")
        script.finish_test(true)
        return
    end
    if not player.character then assert(player.create_character()) end
    local surface = game.create_surface("residential-test", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -30, 32 do for y = -30, 32 do tiles[#tiles+1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local force = player.force
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = force}
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    local corporation = corporations.found(force.index, player.index, "Housing Test")
    assert(not corporation.residential and not residential.begin(player, hq, corporation))
    inventory.insert {name = "iron-plate", count = 100}; assert(orders.deliver(player, hq, corporation))
    assert(districts.begin(player, hq, corporation))
    local district_area = {left_top = {x = 7, y = 7}, right_bottom = {x = 19, y = 19}}
    assert(districts.define(player, surface, district_area, corporation))
    assert(not residential.begin(player, hq, corporation))
    assert(districts.assign(corporation, "Housing Admin"))
    assert(not residential.begin(player, hq, corporation), "Housing needs a depot")
    for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
    assert(projects.construct(force, hq, surface, {x = 10.5, y = -8.5}, corporation, {inventory}))
    for _, material in ipairs(residential.definition.materials) do inventory.insert(material) end
    assert(not residential.begin(player, hq, corporation), "Insufficient credits must block selection")
    inventory.insert {name = "iron-plate", count = 100}; assert(orders.deliver_supply(player, hq, corporation))
    assert(corporation.credits == 1000)
    assert(residential.begin(player, hq, corporation)); residential.cancel(player)
    assert(corporation.credits == 1000 and not corporation.residential)
    assert(residential.begin(player, hq, corporation))
    local function area(x, y) return {left_top = {x = x, y = y}, right_bottom = {x = x+1, y = y+1}} end
    local site = area(10, 10)
    local function show(box)
        preview.on_area {player_index = player.index, item = residential.tool_name, surface = surface,
            area = box, cursor_position = box.right_bottom, selection_mode = defines.selection_mode.select}
        return storage.corporate_dominion.planner_previews[player.index]
    end
    local p = show(area(4, 9))
    assert(p.objects.text.text[4][1] == "corporate-residential.outside-district" and p.objects.text.color.r > 0.9)
    assert(not residential.build(player, surface, area(4, 9), corporation))
    local blocker = surface.create_entity {name = "iron-chest", position = projects.center(site), force = force}
    p = show(site); assert(p.objects.text.text[4][1] == "corporate-projects.blocked")
    assert(not residential.build(player, surface, site, corporation) and corporation.credits == 1000)
    blocker.destroy()
    p = show(site); assert(p.objects.text.color.g > 0.9)
    assert(residential.build(player, surface, site, corporation))
    preview.clear(player.index)
    assert(corporation.credits == 0 and projects.count(corporation) == 2)
    assert(inventory.get_item_count("stone-brick") == 0 and inventory.get_item_count("electronic-circuit") == 0)
    local housing = corporation.residential
    assert(residential.active(housing) and housing.cycles == 0 and housing.next_tick == game.tick + residential.interval)
    assert(not residential.build(player, surface, site, corporation) and not residential.begin(player, hq, corporation))
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    assert(tonumber(frame.body.residential.population.caption[2]) == 10 and not frame.body.residential.corporate_residential_build.enabled)
    local stock = stockpiles.collect(corporation, force, surface)
    assert(#stock == 4, "Residential entity must not become a depot")
    inventory.insert {name = "raw-fish", count = 50}; player.cursor_stack.set_stack {name = "raw-fish", count = 5}
    local ordinary = surface.create_entity {name = "iron-chest", position = {-10.5, -10.5}, force = force}
    ordinary.insert {name = "raw-fish", count = 20}
    local rival = game.create_force("housing-rival")
    local foreign = surface.create_entity {name = "iron-chest", position = {-12.5, -10.5}, force = rival}
    foreign.insert {name = "raw-fish", count = 20}
    stock[1].insert {name = "raw-fish", count = 4}
    if prototypes.quality.uncommon then stock[1].insert {name = "raw-fish", quality = "uncommon", count = 5} end
    residential.tick(); assert(corporation.credits == 0 and housing.cycles == 0)
    local function due()
        housing.next_tick = game.tick
        corporations.on_district_tick()
    end
    due(); assert(housing.reason == "no-food" and corporation.credits == 0 and stock[1].get_item_count {name = "raw-fish", quality = "normal"} == 4)
    stock[2].insert {name = "raw-fish", count = 1}
    due(); assert(housing.reason == "supplied" and corporation.credits == 100 and housing.cycles == 1)
    residential.tick(); assert(corporation.credits == 100)
    assert(inventory.get_item_count("raw-fish") == 50 and player.cursor_stack.count == 5)
    assert(ordinary.get_item_count("raw-fish") == 20 and foreign.get_item_count("raw-fish") == 20)
    if prototypes.quality.uncommon then assert(stock[1].get_item_count {name = "raw-fish", quality = "uncommon"} == 5) end
    stock[1].insert {name = "raw-fish", count = 15}
    housing.next_tick = 0
    residential.tick(); residential.tick()
    assert(housing.cycles == 2 and housing.credits_earned == 200 and housing.consumed == 10)
    assert(corporation.credits == 200 and stock[1].get_item_count {name = "raw-fish", quality = "normal"} == 10)
    local administrator = corporation.district.administrator
    corporation.district.administrator = nil
    due(); assert(housing.reason == "no-administrator" and corporation.credits == 200)
    corporation.district.administrator = administrator
    local history = corporation.projects; corporation.projects = {}
    due(); assert(housing.reason == "no-depot" and corporation.credits == 200)
    corporation.projects = history
    housing.hq = ordinary
    due(); assert(housing.reason == "no-hq" and corporation.credits == 200)
    local previous_due = housing.next_tick
    corporations.on_gui_click {player_index = player.index, element = frame.body.residential.corporate_residential_rebind}
    assert(housing.hq == hq and housing.next_tick == previous_due and housing.cycles == 2 and housing.reason == "queued")
    assert(districts.begin(player, hq, corporation))
    local success, message = districts.define(player, surface,
        {left_top = {x = -12, y = -12}, right_bottom = {x = -6, y = -6}}, corporation)
    assert(not success and message[1] == "corporate-residential.keep-inside")
    districts.cancel_selection(player)
    assert(corporation.district.bounds.left == 7)
    housing.entity.force = rival
    due(); assert(housing.reason == "no-building" and corporation.credits == 200)
    housing.entity.force = force
    housing.entity.destroy()
    due(); assert(housing.reason == "no-building" and corporation.credits == 200)
    assert(not residential.rebind(player, hq, corporation))
    inventory.insert {name = "iron-plate", count = 200}
    assert(orders.deliver_supply(player, hq, corporation)); assert(orders.deliver_supply(player, hq, corporation))
    for _, material in ipairs(residential.definition.materials) do inventory.insert(material) end
    assert(residential.begin(player, hq, corporation))
    assert(residential.build(player, surface, site, corporation))
    housing = corporation.residential
    assert(corporation.credits == 200 and housing.cycles == 2 and housing.credits_earned == 200)
    assert(projects.count(corporation) == 3 and residential.active(housing))
    stock[1].remove {name = "raw-fish", quality = "normal", count = 100}
    stock[1].insert {name = "raw-fish", count = 5}
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    storage.residential_test = {credits = corporation.credits, cycles = housing.cycles, stock = stock[1], due = housing.next_tick,
        check_tick = math.ceil(housing.next_tick / 120) * 120 + 1}
end)
