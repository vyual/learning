-- Настоящие инвентари и GUI Factorio: первый заказ и защита от повторной оплаты.
local corporations = require("__learning__/scripts/corporations")
local orders = require("__learning__/scripts/orders")
local FRAME = "corporate_dominion_hq"

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if not player.character then assert(player.create_character()) end
    local surface = player.surface
    local hq = surface.create_entity {name = "corporate-hq", position = {10, 0}, force = player.force}
    assert(hq and player.teleport({6, 0}))
    assert(player.can_reach_entity(hq))
    local inventory = assert(player.get_main_inventory())
    inventory.clear()
    local iron = {name = "iron-plate", quality = "normal"}
    local corporation = corporations.found(player.force.index, player.index, "Поставщик")
    corporation.credits = 37 -- Баланс старой корпорации не должен сброситься.
    assert(not orders.is_complete(corporation))
    assert(not orders.deliver(player, hq, nil))

    inventory.insert {name = "iron-plate", quality = "normal", count = 99}
    inventory.insert {name = "copper-plate", quality = "normal", count = 27}
    player.cursor_stack.set_stack {name = "iron-plate", count = 100}
    if prototypes.quality["uncommon"] then
        inventory.insert {name = "iron-plate", quality = "uncommon", count = 100}
    end
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_deliver}
    assert(inventory.get_item_count(iron) == 99 and corporation.credits == 37)
    assert(not orders.is_complete(corporation))
    assert(frame.body.order_result.caption[1] == "corporate-orders.not-enough")
    assert(player.cursor_stack.count == 100, "The cursor stack was consumed")

    local rival = game.create_force("step02-rival")
    local enemy_hq = surface.create_entity {name = "corporate-hq", position = {20, 0}, force = rival}
    local ok, message = orders.deliver(player, enemy_hq, corporation)
    assert(not ok and message[1] == "corporate-dominion.hq-unavailable")
    assert(player.teleport({200, 0}))
    ok, message = orders.deliver(player, hq, corporation)
    assert(not ok and message[1] == "corporate-orders.too-far")
    assert(inventory.get_item_count(iron) == 99 and corporation.credits == 37)
    assert(player.teleport({6, 0}))

    inventory.insert {name = "iron-plate", quality = "normal", count = 1}
    corporations.on_gui_click {player_index = player.index, element = frame.body.order.corporate_dominion_deliver}
    assert(inventory.get_item_count(iron) == 0, "Wrong quantity removed")
    assert(inventory.get_item_count {name = "copper-plate", quality = "normal"} == 27)
    if prototypes.quality["uncommon"] then
        assert(inventory.get_item_count {name = "iron-plate", quality = "uncommon"} == 100, "Higher quality plates were consumed")
    end
    assert(corporation.credits == 1037 and orders.is_complete(corporation))
    assert(corporation.orders[orders.definition.id].delivered == 100)
    assert(not frame.body.order.corporate_dominion_deliver.enabled)
    assert(tonumber(frame.body.balance.caption[2]) == 1037, "The balance stayed stale")
    assert(frame.body.order_result.caption[1] == "corporate-orders.success")

    inventory.insert {name = "iron-plate", quality = "normal", count = 100}
    ok, message = orders.deliver(player, hq, corporation)
    assert(not ok and message[1] == "corporate-orders.already-complete")
    assert(corporation.credits == 1037 and inventory.get_item_count(iron) == 100)
    corporations.close(player)
    local another_hq = surface.create_entity {name = "corporate-hq", position = {30, 0}, force = player.force}
    corporations.on_gui_opened {player_index = player.index, entity = another_hq}
    assert(not player.gui.screen[FRAME].body.order.corporate_dominion_deliver.enabled)
    corporations.close(player)
    hq.destroy()
    assert(corporation.credits == 1037 and orders.is_complete(corporation))
    log("STEP02 ORDERS, INVENTORIES, QUALITIES, GUI AND SHARED ORDER CHECKS PASSED")
    script.finish_test(true)
end)
