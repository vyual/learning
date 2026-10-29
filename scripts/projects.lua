-- Шаг 3: один готовый строительный проект, пока без ИИ и времени стройки.
local M = {}
M.tool_name = "corporate-project-planner"
M.definition = {
    id = "small-supply-depot", cost = 500, radius = 32,
    materials = {
        {name = "iron-plate", count = 33},
        {name = "electronic-circuit", count = 1},
        {name = "copper-cable", count = 3}
    }
}
local layout = {
    {name = "iron-chest", x = -1, y = -1}, {name = "iron-chest", x = 1, y = -1},
    {name = "iron-chest", x = -1, y = 1}, {name = "iron-chest", x = 1, y = 1},
    {name = "small-lamp", x = 0, y = 0}
}

local function pending_projects()
    local state = storage.corporate_dominion
    state.pending_projects = state.pending_projects or {}
    return state.pending_projects
end

-- Общая проверка снабжения: один инвентарь персонажа или несколько складских сундуков.
function M.check_supplies(corporation, inventories, definition)
    definition = definition or M.definition
    if not corporation then return nil, {"corporate-orders.no-corporation"} end
    if corporation.credits < definition.cost then return nil, {"corporate-projects.no-money", definition.cost} end
    if #inventories == 0 then return nil, {"corporate-orders.no-inventory"} end
    for _, inventory in ipairs(inventories) do
        if not inventory.valid then return nil, {"corporate-orders.no-inventory"} end
    end
    for _, material in ipairs(definition.materials) do
        local count = 0
        for _, inventory in ipairs(inventories) do
            count = count + inventory.get_item_count {name = material.name, quality = "normal"}
        end
        if count < material.count then return nil, {"corporate-projects.no-materials"} end
    end
    return inventories
end

local function resources(player, corporation)
    local inventory = player.get_main_inventory()
    local supplies, message = M.check_supplies(corporation, inventory and {inventory} or {})
    if not supplies then return nil, message end
    return inventory
end

local function valid_hq(player, hq)
    return hq and hq.valid and hq.name == "corporate-hq" and hq.force == player.force
end

function M.count(corporation)
    return corporation.projects and #corporation.projects or 0
end

function M.cancel(player)
    if storage.corporate_dominion then pending_projects()[player.index] = nil end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.name == M.tool_name then cursor.clear() end
end

function M.begin(player, hq, corporation)
    if not valid_hq(player, hq) then return false, {"corporate-dominion.hq-unavailable"} end
    if hq.surface ~= player.surface or not player.can_reach_entity(hq) then
        return false, {"corporate-orders.too-far"}
    end
    local inventory, message = resources(player, corporation)
    if not inventory then return false, message end
    if not player.clear_cursor() then return false, {"corporate-projects.clear-cursor"} end
    if not player.cursor_stack or not player.cursor_stack.set_stack {name = M.tool_name, count = 1} then
        return false, {"corporate-projects.clear-cursor"}
    end
    -- Бюджет и материалы пока не трогаем: сначала игрок должен выбрать место.
    pending_projects()[player.index] = {hq = hq, force_index = player.force.index}
    return true, {"corporate-projects.choose-site", M.definition.radius}
end

function M.on_cursor_changed(event)
    local state = storage.corporate_dominion
    if not state or not state.pending_projects or not state.pending_projects[event.player_index] then return end
    local player = game.get_player(event.player_index)
    local cursor = player and player.cursor_stack
    if not cursor or not cursor.valid_for_read or cursor.name ~= M.tool_name then
        state.pending_projects[event.player_index] = nil
    end
end

function M.build(player, surface, area, corporation)
    local pending = storage.corporate_dominion and pending_projects()[player.index]
    if not pending then return false, {"corporate-projects.no-selection"} end
    local hq = pending.hq
    if pending.force_index ~= player.force.index or not valid_hq(player, hq) then
        M.cancel(player)
        return false, {"corporate-dominion.hq-unavailable"}
    end
    if surface ~= hq.surface or surface ~= player.surface then
        return false, {"corporate-projects.wrong-surface"}
    end
    local center = M.center(area)
    local inventory = player.get_main_inventory()
    local success, message = M.construct(player.force, hq, surface, center, corporation, inventory and {inventory} or {})
    if success then M.cancel(player) end
    return success, message
end

function M.can_place(force, surface, center, definition)
    for x = -1, 1 do
        for y = -1, 1 do
            local position = {x = center.x + x, y = center.y + y}
            if not surface.is_chunk_generated {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
                or not surface.can_place_entity {name = "iron-chest", position = position, force = force} then
                return false
            end
        end
    end
    for _, part in ipairs(definition and definition.layout or layout) do
        if not surface.can_place_entity {name = part.name, position = {center.x + part.x, center.y + part.y}, force = force} then return false end
    end
    return true
end

-- Одинаковое округление центра в предпросмотре и при подтверждении.
function M.center(area)
    return {
        x = math.floor((area.left_top.x + area.right_bottom.x) / 2) + 0.5,
        y = math.floor((area.left_top.y + area.right_bottom.y) / 2) + 0.5
    }
end

-- Авторитетная проверка площадки: предпросмотр и стройка используют одни правила.
function M.check_site(force, hq, surface, center, corporation, inventories, definition)
    definition = definition or M.definition
    if not hq or not hq.valid or hq.name ~= "corporate-hq" or hq.force ~= force then
        return false, {"corporate-dominion.hq-unavailable"}
    end
    if surface ~= hq.surface then return false, {"corporate-projects.wrong-surface"} end
    local dx, dy = center.x - hq.position.x, center.y - hq.position.y
    if dx * dx + dy * dy > definition.radius ^ 2 then
        return false, {"corporate-projects.too-far", definition.radius}
    end
    local supplies, message = M.check_supplies(corporation, inventories, definition)
    if not supplies then return false, message end
    if not M.can_place(force, surface, center, definition) then return false, {"corporate-projects.blocked"} end
    return true
end

function M.preview(player, surface, area, corporation)
    local selection = storage.corporate_dominion and pending_projects()[player.index]
    if not selection then return false, {"corporate-projects.no-selection"} end
    if selection.force_index ~= player.force.index then return false, {"corporate-dominion.hq-unavailable"} end
    if surface ~= player.surface then return false, {"corporate-projects.wrong-surface"} end
    local inventory = player.get_main_inventory()
    return M.check_site(player.force, selection.hq, surface, M.center(area), corporation, inventory and {inventory} or {})
end

function M.construct(force, hq, surface, center, corporation, inventories, definition)
    definition = definition or M.definition
    local success, message = M.check_site(force, hq, surface, center, corporation, inventories, definition)
    if not success then return false, message end
    local created = {}
    local function rollback()
        for _, entity in ipairs(created) do if entity.valid then entity.destroy() end end
    end
    for _, part in ipairs(definition.layout or layout) do
        local entity = surface.create_entity {
            name = part.name, position = {center.x + part.x, center.y + part.y}, force = force
        }
        if not entity then rollback(); return false, {"corporate-projects.failed"} end
        created[#created + 1] = entity
    end
    local removed = {}
    for _, material in ipairs(definition.materials) do
        local remaining = material.count
        for _, inventory in ipairs(inventories) do
            if remaining > 0 then
                local count = inventory.remove {name = material.name, count = remaining, quality = "normal"}
                removed[#removed + 1] = {inventory = inventory, name = material.name, count = count}
                remaining = remaining - count
            end
        end
        if remaining > 0 then
            for _, item in ipairs(removed) do
                if item.count > 0 then item.inventory.insert {name = item.name, count = item.count, quality = "normal"} end
            end
            rollback()
            return false, {"corporate-projects.no-materials"}
        end
    end
    corporation.credits = corporation.credits - definition.cost
    corporation.projects = corporation.projects or {}
    corporation.projects[#corporation.projects + 1] = {
        id = definition.id, position = center, surface_index = surface.index,
        entities = created, built_tick = game.tick, cost = definition.cost
    }
    return true, {definition.built_message or "corporate-projects.built", definition.cost}, corporation.projects[#corporation.projects]
end

return M
