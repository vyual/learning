-- Первый жилой квартал: один объект, фиксированное население и один товар.
local projects = require("__learning__/scripts/projects")
local stockpiles = require("__learning__/scripts/stockpiles")
local M = {tool_name = "corporate-residential-planner", interval = 3600, population = 10,
    food = {name = "raw-fish", quality = "normal", count = 5}, income = 100}
M.definition = {id = "residential-block", cost = 1000, radius = projects.definition.radius,
    built_message = "corporate-residential.built",
    materials = {{name = "stone-brick", count = 50}, {name = "iron-plate", count = 20}, {name = "electronic-circuit", count = 5}},
    layout = {{name = "corporate-residential-block", x = 0, y = 0}}}

local function pending()
    local state = storage.corporate_dominion
    state.pending_residential = state.pending_residential or {}
    return state.pending_residential
end

function M.active(housing)
    return housing and housing.entity and housing.entity.valid
        and housing.entity.name == "corporate-residential-block"
        and housing.entity.force.index == housing.force_index
        and housing.entity.surface.index == housing.surface_index
end

function M.inside(bounds, center)
    return center.x - 1.5 >= bounds.left and center.x + 1.5 <= bounds.right
        and center.y - 1.5 >= bounds.top and center.y + 1.5 <= bounds.bottom
end

function M.cancel(player)
    if storage.corporate_dominion then pending()[player.index] = nil end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == M.tool_name then cursor.clear() end
end

function M.on_cursor_changed(event)
    local state = storage.corporate_dominion
    if not state or not state.pending_residential then return end
    local player = game.get_player(event.player_index)
    local cursor = player and player.cursor_stack
    if not cursor or not cursor.valid_for_read or cursor.name ~= M.tool_name then state.pending_residential[event.player_index] = nil end
end

local function prerequisites(force, hq, corporation)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if M.active(corporation.residential) then return false, {"corporate-residential.already-built"} end
    if not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= force then return false, {"corporate-dominion.hq-unavailable"} end
    local district = corporation.district
    if not district then return false, {"corporate-districts.no-district"} end
    if not district.administrator then return false, {"corporate-districts.no-administrator"} end
    if district.surface_index ~= hq.surface.index then return false, {"corporate-projects.wrong-surface"} end
    if #stockpiles.collect(corporation, force, hq.surface) == 0 then return false, {"corporate-residential.no-depot"} end
    return true
end

function M.begin(player, hq, corporation)
    local success, message = prerequisites(player.force, hq, corporation)
    if not success then return false, message end
    if hq.surface ~= player.surface then return false, {"corporate-projects.wrong-surface"} end
    if not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    local inventory = player.get_main_inventory()
    local supplies; supplies, message = projects.check_supplies(corporation, inventory and {inventory} or {}, M.definition)
    if not supplies then return false, message end
    if not player.clear_cursor() or not player.cursor_stack or not player.cursor_stack.set_stack {name = M.tool_name, count = 1} then return false, {"corporate-projects.clear-cursor"} end
    pending()[player.index] = {hq = hq, force_index = player.force.index}
    return true, {"corporate-residential.choose-site"}
end

-- Одна проверка и операция стройки для игрока и управляющего.
function M.check_project(force, hq, surface, center, corporation, inventories)
    local success, message = prerequisites(force, hq, corporation)
    if not success then return false, message end
    if surface ~= hq.surface then return false, {"corporate-projects.wrong-surface"} end
    if not M.inside(corporation.district.bounds, center) then return false, {"corporate-residential.outside-district"} end
    return projects.check_site(force, hq, surface, center, corporation, inventories, M.definition)
end

function M.preview(player, surface, area, corporation)
    local selection = storage.corporate_dominion and pending()[player.index]
    if not selection then return false, {"corporate-projects.no-selection"} end
    if selection.force_index ~= player.force.index then return false, {"corporate-dominion.hq-unavailable"} end
    if surface ~= player.surface then return false, {"corporate-projects.wrong-surface"} end
    local inventory = player.get_main_inventory()
    return M.check_project(player.force, selection.hq, surface, projects.center(area), corporation, inventory and {inventory} or {})
end

function M.construct(force, hq, surface, center, corporation, inventories)
    local success, message = M.check_project(force, hq, surface, center, corporation, inventories)
    if not success then return false, message end
    local record
    success, message, record = projects.construct(force, hq, surface, center, corporation, inventories, M.definition)
    if not success then return false, message end
    local previous = corporation.residential
    corporation.residential = {entity = record.entities[1], position = center, surface_index = surface.index,
        force_index = force.index, hq = hq, next_tick = game.tick + M.interval, reason = "settling",
        cycles = previous and previous.cycles or 0, consumed = previous and previous.consumed or 0,
        credits_earned = previous and previous.credits_earned or 0}
    return true, message, record
end

function M.build(player, surface, area, corporation)
    local success, message = M.preview(player, surface, area, corporation)
    if not success then return false, message end
    local hq = pending()[player.index].hq
    local inventory = player.get_main_inventory()
    success, message = M.construct(player.force, hq, surface, projects.center(area), corporation, {inventory})
    if success then M.cancel(player) end
    return success, message
end

function M.rebind(player, hq, corporation)
    local housing = corporation and corporation.residential
    if not M.active(housing) then return false, {"corporate-residential.status-no-building"} end
    if not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= player.force or housing.force_index ~= player.force.index then return false, {"corporate-dominion.hq-unavailable"} end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    if hq.surface.index ~= housing.surface_index then return false, {"corporate-projects.wrong-surface"} end
    local dx, dy = housing.position.x - hq.position.x, housing.position.y - hq.position.y
    if dx * dx + dy * dy > M.definition.radius ^ 2 then return false, {"corporate-projects.too-far", M.definition.radius} end
    housing.hq = hq
    housing.reason = "queued"
    -- Перепривязка не сбрасывает срок следующей поставки и историю выплат.
    return true, {"corporate-residential.rebound"}
end

local function supply(corporation, force)
    local housing = corporation.residential
    if not M.active(housing) then return "no-building" end
    local district = corporation.district
    if not district or district.surface_index ~= housing.surface_index or not M.inside(district.bounds, housing.position) then return "outside-district" end
    if not district.administrator then return "no-administrator" end
    local hq = housing.hq
    if not force or not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= force or hq.surface.index ~= housing.surface_index then return "no-hq" end
    local inventories = stockpiles.collect(corporation, force, hq.surface)
    if #inventories == 0 then return "no-depot" end
    if not stockpiles.take(inventories, M.food) then return "no-food" end
    corporation.credits = corporation.credits + M.income
    housing.cycles = housing.cycles + 1
    housing.consumed = housing.consumed + M.food.count
    housing.credits_earned = housing.credits_earned + M.income
    return "supplied"
end

function M.tick()
    local state = storage.corporate_dominion
    local changed = {}
    for force_index, corporation in pairs(state and state.corporations or {}) do
        local housing = corporation.residential
        if housing and (not housing.next_tick or game.tick >= housing.next_tick or not M.active(housing)) then
            housing.next_tick = game.tick + M.interval
            local previous = housing.reason
            housing.reason = supply(corporation, game.forces[force_index])
            if previous ~= housing.reason or housing.reason == "supplied" then changed[#changed + 1] = force_index end
        end
    end
    return changed
end

return M
