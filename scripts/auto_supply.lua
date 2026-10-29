-- Одна добровольно включённая поставка за интервал. Без отдельного backend и NPC.
local orders = require("__learning__/scripts/orders")
local construction_projects = require("__learning__/scripts/construction_projects")
local stockpiles = require("__learning__/scripts/stockpiles")
local M = {interval = 600}

function M.enabled(corporation)
    return corporation.auto_supply ~= nil and corporation.auto_supply.enabled == true
end

function M.set_enabled(player, hq, corporation, enabled)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if not enabled then
        if corporation.auto_supply then
            corporation.auto_supply.enabled = false
            corporation.auto_supply.reason = "off"
            corporation.auto_supply.next_tick = nil
            corporation.auto_supply.hq = nil
        end
        return true, {"corporate-auto.disabled"}
    end
    if not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= player.force then
        return false, {"corporate-dominion.hq-unavailable"}
    end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    if not orders.is_complete(corporation) then return false, {"corporate-orders.finish-first"} end
    local district = corporation.district
    if not district then return false, {"corporate-districts.no-district"} end
    if not district.administrator then return false, {"corporate-districts.no-administrator"} end
    if district.surface_index ~= hq.surface.index then return false, {"corporate-projects.wrong-surface"} end
    if M.enabled(corporation) then return true, {"corporate-auto.enabled"} end
    local state = corporation.auto_supply or {shipments = 0}
    state.enabled, state.reason, state.hq = true, "queued", hq
    state.next_tick = game.tick + M.interval
    corporation.auto_supply = state
    return true, {"corporate-auto.enabled"}
end

-- Пока есть активная стройка, её железо не считается излишком для продажи.
function M.reserve(corporation, surface)
    local district = corporation.district
    if district and district.surface_index == surface.index and district.order and district.order.status == "pending" then
        local definition = construction_projects.get(district.order.project_id)
        for _, material in ipairs(definition and definition.materials or {}) do
            if material.name == orders.supply_definition.item then return material.count end
        end
    end
    return 0
end

local function deliver(corporation, force)
    local district, state = corporation.district, corporation.auto_supply
    if not district or not district.administrator then return "no-administrator" end
    local hq = state.hq
    if not force or not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= force
        or hq.surface.index ~= district.surface_index then return "no-hq" end
    if not orders.is_complete(corporation) then return "first-order" end
    local inventories = stockpiles.collect(corporation, force, hq.surface)
    if #inventories == 0 then return "no-depot" end
    if not orders.deliver_from_stock(corporation, inventories, M.reserve(corporation, hq.surface)) then return "stock" end
    state.shipments = (state.shipments or 0) + 1
    state.last_delivery_tick = game.tick
    return "delivered"
end

function M.tick()
    local changed = {}
    local state = storage.corporate_dominion
    if not state then return changed end
    for force_index, corporation in pairs(state.corporations) do
        local auto = corporation.auto_supply
        if M.enabled(corporation) and (not auto.next_tick or game.tick >= auto.next_tick) then
            -- Новый срок устанавливается и при неудаче: нет догоняющих выплат после паузы/загрузки.
            auto.next_tick = game.tick + M.interval
            local previous = auto.reason
            auto.reason = deliver(corporation, game.forces[force_index])
            if previous ~= auto.reason or auto.reason == "delivered" then changed[#changed + 1] = force_index end
        end
    end
    return changed
end

return M
