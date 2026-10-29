-- Загружается ТОЛЬКО в изолированную копию control.lua для --test-save --test-arg reload.
-- Проверяет реальные сохранённые данные. Оригинал сейва не перезаписывается.
local corporations = require("__learning__/scripts/corporations")
local orders = require("__learning__/scripts/orders")
local projects = require("__learning__/scripts/projects")
local preview = require("__learning__/scripts/planner_preview")
local auto_supply = require("__learning__/scripts/auto_supply")
local residential = require("__learning__/scripts/residential")
assert(script.test_arg == "reload", "Saved-game regression must only run in test mode")

script.on_nth_tick(1, function()
    local player = game.get_player(1)
    assert(player)
    -- Тестовой поставке нужен персонаж; исходный сейв может быть в god/editor mode.
    if not player.character then
        if player.controller_type == defines.controllers.editor then player.toggle_map_editor() end
        if not player.character then player.set_controller {type = defines.controllers.god}; assert(player.create_character()) end
    end
    local corporation = corporations.get(player.force.index)
    assert(corporation and orders.is_complete(corporation), "Fixture needs an existing corporation with its first order completed")
    local hq = corporation.district and corporation.district.hq
    if not hq or not hq.valid then
        hq = player.surface.find_entities_filtered {name = "corporate-hq", force = player.force}[1]
    end
    assert(hq and hq.valid)
    local position = hq.surface.find_non_colliding_position("character", {hq.position.x + 5, hq.position.y}, 12, 0.5)
    assert(position and player.teleport(position, hq.surface) and player.can_reach_entity(hq))
    assert(not auto_supply.enabled(corporation), "Auto-deliveries must remain off in saves predating the feature")
    assert(not corporation.residential, "A residential block must not appear automatically in an old save")
    local first = corporation.orders[orders.definition.id]
    local count, shipments = projects.count(corporation), orders.supply_count(corporation)
    local district, name = corporation.district, corporation.name
    corporation.credits = 0 -- Воспроизводим тупик в копии загруженного сейва.
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen.corporate_dominion_hq
    frame.body.order.corporate_dominion_supply.destroy(); frame.tags = {}
    corporations.on_district_tick()
    assert(frame.body.order.corporate_dominion_supply.enabled)
    assert(frame.body.residential.corporate_residential_build.enabled)
    assert(tonumber(frame.body.residential.population.caption[2]) == 0)
    residential.tick(); assert(not corporation.residential)
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    inventory.insert {name = "iron-plate", count = 99}
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_supply}
    assert(corporation.credits == 0 and orders.supply_count(corporation) == shipments)
    inventory.insert {name = "iron-plate", count = 1}
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_supply}
    assert(corporation.credits == 500 and orders.supply_count(corporation) == shipments + 1)
    assert(not orders.deliver_supply(player, hq, corporation))
    assert(corporation.orders[orders.definition.id] == first and corporation.district == district)
    assert(corporation.name == name and projects.count(corporation) == count)
    for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
    assert(projects.begin(player, hq, corporation))
    preview.on_area {player_index = player.index, item = projects.tool_name, surface = hq.surface,
        area = {left_top = {x = hq.position.x + 6, y = hq.position.y},
            right_bottom = {x = hq.position.x + 7, y = hq.position.y + 1}},
        cursor_position = {x = hq.position.x + 7, y = hq.position.y + 1},
        selection_mode = defines.selection_mode.select}
    local object = storage.corporate_dominion.planner_previews[player.index].objects.text
    assert(object.valid)
    projects.cancel(player); preview.on_cursor_changed {player_index = player.index}
    assert(not object.valid and corporation.credits == 500 and projects.count(corporation) == count)
    if corporation.district and corporation.district.administrator then
        assert(auto_supply.set_enabled(player, hq, corporation, true))
        assert(corporation.auto_supply.next_tick == game.tick + auto_supply.interval)
        auto_supply.tick()
        assert(corporation.credits == 500 and corporation.auto_supply.shipments == 0)
        assert(auto_supply.set_enabled(player, hq, corporation, false))
    end
    log("SAVED GAME REGRESSION PASSED: OLD DATA LOADED, GUI UPGRADED, ZERO BALANCE RECOVERED, HISTORY PRESERVED, PREVIEW CANCELLED")
    script.finish_test(true)
end)
