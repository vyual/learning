-- Первый заказ даёт стартовый бонус; регулярная поставка поддерживает дальнейшее развитие.
local stockpiles = require("__learning__/scripts/stockpiles")
local M = {}
M.definition = {id = "first-iron-delivery", item = "iron-plate", quality = "normal", amount = 100, reward = 1000}
M.supply_definition = {id = "regular-iron-delivery", item = "iron-plate", quality = "normal", amount = 100, reward = 500}

function M.is_complete(corporation)
    return corporation.orders and corporation.orders[M.definition.id] ~= nil
end

function M.supply_count(corporation)
    local record = corporation.orders and corporation.orders[M.supply_definition.id]
    return record and record.batches or 0
end

-- Обе поставки используют одинаковые проверки и реальное списание предметов.
local function take_shipment(player, hq, order)
    if not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= player.force then
        return false, {"corporate-dominion.hq-unavailable"}
    end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    local inventory = player.get_main_inventory()
    if not inventory then return false, {"corporate-orders.no-inventory"} end
    local success, removed = stockpiles.take({inventory}, {name = order.item, quality = order.quality, count = order.amount})
    if not success then return false, {"corporate-orders.not-enough", order.amount} end
    return true, removed
end

function M.deliver(player, hq, corporation)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if M.is_complete(corporation) then return false, {"corporate-orders.already-complete"} end
    local order = M.definition
    local success, result = take_shipment(player, hq, order)
    if not success then return false, result end
    corporation.orders = corporation.orders or {}
    corporation.orders[order.id] = {delivered = result, completed_tick = game.tick}
    corporation.credits = corporation.credits + order.reward
    return true, {"corporate-orders.success", order.amount, order.reward}
end

local function record_supply(corporation, delivered)
    local order = M.supply_definition
    local record = corporation.orders[order.id] or {batches = 0, delivered = 0, credits_earned = 0}
    record.batches = record.batches + 1
    record.delivered = record.delivered + delivered
    record.credits_earned = record.credits_earned + order.reward
    record.last_completed_tick = game.tick
    corporation.orders[order.id] = record
    corporation.credits = corporation.credits + order.reward
    return true, {"corporate-orders.supply-success", order.amount, order.reward}
end

function M.deliver_supply(player, hq, corporation)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if not M.is_complete(corporation) then return false, {"corporate-orders.finish-first"} end
    local order = M.supply_definition
    local success, result = take_shipment(player, hq, order)
    if not success then return false, result end
    return record_supply(corporation, result)
end

-- Складские поставки проходят то же списание и учёт, что и ручные.
function M.deliver_from_stock(corporation, inventories, reserve)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if not M.is_complete(corporation) then return false, {"corporate-orders.finish-first"} end
    local order = M.supply_definition
    local success, result = stockpiles.take(inventories,
        {name = order.item, quality = order.quality, count = order.amount}, reserve)
    if not success then return false, {"corporate-orders.not-enough", order.amount} end
    return record_supply(corporation, result)
end

return M
