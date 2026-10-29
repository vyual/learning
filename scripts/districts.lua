-- Шаг 4: один район и одно поручение управляющему, без автономного градостроения.
local projects = require("__learning__/scripts/projects")
local stockpiles = require("__learning__/scripts/stockpiles")
local residential = require("__learning__/scripts/residential")
local construction_projects = require("__learning__/scripts/construction_projects")
local M = {tool_name = "corporate-district-planner", min_size = 6, max_size = 24}

local function pending()
    local state = storage.corporate_dominion
    state.pending_districts = state.pending_districts or {}
    return state.pending_districts
end

local function valid_hq(player, hq)
    return hq and hq.valid and hq.name == "corporate-hq" and hq.force == player.force
end

local function inside_radius(bounds, hq)
    for _, x in ipairs({bounds.left, bounds.right}) do
        for _, y in ipairs({bounds.top, bounds.bottom}) do
            local dx, dy = x - hq.position.x, y - hq.position.y
            if dx * dx + dy * dy > projects.definition.radius ^ 2 then return false end
        end
    end
    return true
end

function M.cancel_selection(player)
    if storage.corporate_dominion then pending()[player.index] = nil end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == M.tool_name then cursor.clear() end
end

function M.on_cursor_changed(event)
    local state = storage.corporate_dominion
    if not state or not state.pending_districts or not state.pending_districts[event.player_index] then return end
    local player = game.get_player(event.player_index)
    local cursor = player and player.cursor_stack
    if not cursor or not cursor.valid_for_read or cursor.name ~= M.tool_name then state.pending_districts[event.player_index] = nil end
end

function M.begin(player, hq, corporation)
    if not corporation then return false, {"corporate-orders.no-corporation"} end
    if not valid_hq(player, hq) then return false, {"corporate-dominion.hq-unavailable"} end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    local district = corporation.district
    if district and district.order and district.order.status == "pending" then return false, {"corporate-districts.busy"} end
    if not player.clear_cursor() or not player.cursor_stack or not player.cursor_stack.set_stack {name = M.tool_name, count = 1} then
        return false, {"corporate-projects.clear-cursor"}
    end
    pending()[player.index] = {hq = hq, force_index = player.force.index}
    return true, {"corporate-districts.choose-area", M.min_size, M.max_size, projects.definition.radius}
end

function M.bounds(area)
    return {left = math.floor(area.left_top.x), top = math.floor(area.left_top.y),
        right = math.ceil(area.right_bottom.x), bottom = math.ceil(area.right_bottom.y)}
end

-- Проверка общая для предпросмотра и подтверждения; не меняет игровой мир.
function M.check_area(player, surface, area, corporation)
    local selection = storage.corporate_dominion and pending()[player.index]
    if not selection or not corporation then return false, {"corporate-projects.no-selection"} end
    if selection.force_index ~= player.force.index or not valid_hq(player, selection.hq) then
        return false, {"corporate-dominion.hq-unavailable"}
    end
    if surface ~= selection.hq.surface or surface ~= player.surface then return false, {"corporate-projects.wrong-surface"} end
    if corporation.district and corporation.district.order and corporation.district.order.status == "pending" then
        return false, {"corporate-districts.busy"}
    end
    local bounds = M.bounds(area)
    local width, height = bounds.right - bounds.left, bounds.bottom - bounds.top
    if width < M.min_size or height < M.min_size or width > M.max_size or height > M.max_size then
        return false, {"corporate-districts.bad-size", M.min_size, M.max_size}
    end
    local housing = corporation.residential
    if housing and housing.entity.valid and housing.entity.force == player.force and housing.surface_index == surface.index then
        local center = housing.position
        if center.x - 1.5 < bounds.left or center.x + 1.5 > bounds.right or center.y - 1.5 < bounds.top or center.y + 1.5 > bounds.bottom then
            return false, {"corporate-residential.keep-inside"}
        end
    end
    if not inside_radius(bounds, selection.hq) then return false, {"corporate-districts.outside-radius", projects.definition.radius} end
    for force_index, other in pairs(storage.corporate_dominion.corporations) do
        local district = other.district
        if force_index ~= player.force.index and district and district.surface_index == surface.index then
            local b = district.bounds
            if bounds.left < b.right and bounds.right > b.left and bounds.top < b.bottom and bounds.bottom > b.top then
                return false, {"corporate-districts.overlap"}
            end
        end
    end
    return true, bounds
end

function M.define(player, surface, area, corporation)
    local success, result = M.check_area(player, surface, area, corporation)
    if not success then
        if result[1] == "corporate-dominion.hq-unavailable" then M.cancel_selection(player) end
        return false, result
    end
    local selection = pending()[player.index]
    local bounds = result
    local width, height = bounds.right - bounds.left, bounds.bottom - bounds.top
    local district = corporation.district or {}
    if district.outline and district.outline.valid then district.outline.destroy() end
    district.bounds, district.surface_index, district.hq = bounds, surface.index, selection.hq
    district.outline = rendering.draw_rectangle {
        color = {r = 0.2, g = 0.9, b = 0.5, a = 0.8}, width = 2, filled = false,
        left_top = {bounds.left, bounds.top}, right_bottom = {bounds.right, bounds.bottom},
        surface = surface, forces = {player.force}, draw_on_ground = true
    }
    corporation.district = district
    M.cancel_selection(player)
    return true, {"corporate-districts.defined", width, height}
end

function M.assign(corporation, raw_name)
    local district = corporation and corporation.district
    if not district then return false, {"corporate-districts.no-district"} end
    local name = raw_name:match("^%s*(.-)%s*$")
    local length = #name:gsub("[\128-\191]", "")
    if length == 0 or length > 40 or name:find("[%c]") then return false, {"corporate-districts.bad-name"} end
    district.administrator = {name = name}
    return true, {"corporate-districts.assigned", name}
end

local function archive(district)
    local order = district.order
    if order and order.status == "completed" and not order.archived then
        district.completed_orders = district.completed_orders or {}
        district.completed_orders[#district.completed_orders + 1] = order
        order.archived = true
    end
end

function M.completed(district, project_id)
    if not district then return false end
    local function matches(order)
        return order.status == "completed" and (order.project_id or projects.definition.id) == project_id
    end
    if district.order and matches(district.order) then return true end
    for _, order in ipairs(district.completed_orders or {}) do if matches(order) then return true end end
    return false
end

function M.issue(player, hq, corporation, project_id)
    local definition = construction_projects.get(project_id)
    if not definition then return false, {"corporate-districts.unknown-project"} end
    local district = corporation and corporation.district
    if not district then return false, {"corporate-districts.no-district"} end
    if not district.administrator then return false, {"corporate-districts.no-administrator"} end
    if district.order and district.order.status == "pending" then return false, {"corporate-districts.busy"} end
    if definition.id == projects.definition.id and M.completed(district, definition.id) then return false, {"corporate-districts.already-complete"} end
    if definition.id == residential.definition.id and residential.active(corporation.residential) then return false, {"corporate-residential.already-built"} end
    if not valid_hq(player, hq) then return false, {"corporate-dominion.hq-unavailable"} end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then return false, {"corporate-orders.too-far"} end
    if district.surface_index ~= hq.surface.index or not inside_radius(district.bounds, hq) then
        return false, {"corporate-districts.outside-radius", projects.definition.radius}
    end
    archive(district) -- Сохраняет также завершённые поручения из старых сейвов.
    district.hq = hq
    district.order = {status = "pending", reason = "queued", budget = definition.cost,
        project_id = definition.id, issued_tick = game.tick}
    return true, {"corporate-districts.issued", definition.cost}
end

function M.cancel_order(corporation)
    local district = corporation and corporation.district
    if not district or not district.order or district.order.status ~= "pending" then return false, {"corporate-districts.no-order"} end
    district.order = nil
    return true, {"corporate-districts.order-cancelled"}
end

local function work(corporation, force)
    local district, order = corporation.district, corporation.district.order
    local definition = construction_projects.get(order.project_id)
    if not definition then return "unknown-project" end
    -- Ручная стройка могла выполнить ту же цель между выдачей и проверкой поручения.
    if definition.id == residential.definition.id and residential.active(corporation.residential) then
        order.status, order.completed_tick = "completed", game.tick
        return "already-built"
    end
    local hq = district.hq
    local surface = game.surfaces[district.surface_index]
    if not force or not surface or not hq or not hq.valid or hq.force ~= force then return "no-hq" end
    if not district.administrator then return "no-administrator" end
    if definition.cost > order.budget then return "over-budget" end
    if corporation.credits < definition.cost then return "no-money" end
    local inventories = stockpiles.collect(corporation, force, surface)
    if #inventories == 0 then return "no-depot" end
    if not projects.check_supplies(corporation, inventories, definition) then return "no-materials" end
    -- Обе постройки 3x3; максимум 64 площадки в районе 24x24.
    local b = district.bounds
    for y = b.top + 1.5, b.bottom - 1.5, 3 do
        for x = b.left + 1.5, b.right - 1.5, 3 do
            local center = {x = x, y = y}
            if projects.can_place(force, surface, center, definition) then
                local success
                if definition.id == residential.definition.id then
                    success = residential.construct(force, hq, surface, center, corporation, inventories)
                else
                    success = projects.construct(force, hq, surface, center, corporation, inventories, definition)
                end
                if not success then return "construction-failed" end
                order.status, order.completed_tick = "completed", game.tick
                order.project_index = #corporation.projects
                return "completed"
            end
        end
    end
    return "blocked"
end

-- Повторяем только незавершённые поручения. Ожидание ничего не списывает.
function M.tick()
    local state = storage.corporate_dominion
    local changed = {}
    if not state then return changed end
    for force_index, corporation in pairs(state.corporations) do
        local district = corporation.district
        if district and district.order and district.order.status == "pending" then
            local old_reason = district.order.reason
            district.order.reason = work(corporation, game.forces[force_index])
            archive(district)
            if old_reason ~= district.order.reason then changed[#changed + 1] = force_index end
        end
    end
    return changed
end

return M
