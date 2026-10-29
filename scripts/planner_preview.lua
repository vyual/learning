-- Только визуальные подсказки. Предсобытия могут пропадать в multiplayer:
-- оплата и изменение границ выполняются исключительно в обычном selected_area.
local districts = require("__learning__/scripts/districts")
local projects = require("__learning__/scripts/projects")
local residential = require("__learning__/scripts/residential")
local M = {}
local green = {r = 0.2, g = 1, b = 0.45, a = 1}
local red = {r = 1, g = 0.18, b = 0.12, a = 1}
local lifetime = 600

function M.clear(player_index)
    local state = storage.corporate_dominion
    local previews = state and state.planner_previews
    local preview = previews and previews[player_index]
    if not preview then return end
    for _, object in pairs(preview.objects) do if object.valid then object.destroy() end end
    previews[player_index] = nil
end

function M.on_area(event)
    if event.item ~= districts.tool_name and event.item ~= projects.tool_name and event.item ~= residential.tool_name then return end
    local player = game.get_player(event.player_index)
    local state = storage.corporate_dominion
    if not player or not state then return end
    local cursor = player.cursor_stack
    if not cursor or not cursor.valid_for_read or cursor.name ~= event.item
        or event.surface ~= player.surface or event.selection_mode ~= defines.selection_mode.select then
        M.clear(event.player_index)
        return
    end
    local corporation = state.corporations[player.force.index]
    local success, result, bounds, text, pending
    if event.item == districts.tool_name then
        success, result = districts.check_area(player, event.surface, event.area, corporation)
        bounds = districts.bounds(event.area)
        text = {"corporate-preview.district", bounds.right - bounds.left, bounds.bottom - bounds.top,
            districts.min_size, districts.max_size}
        pending = state.pending_districts and state.pending_districts[player.index]
    elseif event.item == residential.tool_name then
        success, result = residential.preview(player, event.surface, event.area, corporation)
        local center = projects.center(event.area)
        bounds = {left = center.x - 1.5, top = center.y - 1.5, right = center.x + 1.5, bottom = center.y + 1.5}
        text = {"corporate-residential.preview", residential.definition.cost}
        pending = state.pending_residential and state.pending_residential[player.index]
    else
        success, result = projects.preview(player, event.surface, event.area, corporation)
        local center = projects.center(event.area)
        bounds = {left = center.x - 1.5, top = center.y - 1.5, right = center.x + 1.5, bottom = center.y + 1.5}
        text = {"corporate-preview.project", projects.definition.cost}
        pending = state.pending_projects and state.pending_projects[player.index]
    end
    if not pending then M.clear(player.index); return end
    local color = success and green or red
    local caption = {"", text, "\n", success and {"corporate-preview.ready"} or result}
    state.planner_previews = state.planner_previews or {}
    local preview = state.planner_previews[player.index]
    if preview and (preview.surface_index ~= event.surface.index or not preview.objects.text.valid
        or not preview.objects.outline.valid or not preview.objects.radius.valid) then
        M.clear(player.index); preview = nil
    end
    local target = {event.cursor_position.x + 0.7, event.cursor_position.y + 0.7}
    if not preview then
        local hq = pending.hq
        if not hq or not hq.valid then return end
        preview = {surface_index = event.surface.index, force_index = player.force.index, objects = {}}
        preview.objects.text = rendering.draw_text {
            text = caption, surface = event.surface, target = target, color = color,
            players = {player}, font = "default-bold", scale = 1.2, scale_with_zoom = false, time_to_live = lifetime
        }
        preview.objects.outline = rendering.draw_rectangle {
            left_top = {bounds.left, bounds.top}, right_bottom = {bounds.right, bounds.bottom},
            surface = event.surface, color = color, players = {player}, width = 4, filled = false, time_to_live = lifetime
        }
        preview.objects.radius = rendering.draw_circle {
            target = hq.position, radius = projects.definition.radius, surface = event.surface,
            color = {r = 0.4, g = 0.7, b = 1, a = 0.65}, players = {player}, width = 2,
            draw_on_ground = true, time_to_live = lifetime
        }
        state.planner_previews[player.index] = preview
    else
        preview.objects.text.text = caption
        preview.objects.text.target = target
        preview.objects.text.color = color
        preview.objects.outline.left_top = {bounds.left, bounds.top}
        preview.objects.outline.right_bottom = {bounds.right, bounds.bottom}
        preview.objects.outline.color = color
        for _, object in pairs(preview.objects) do object.time_to_live = lifetime end
    end
end

function M.on_cursor_changed(event)
    M.clear(event.player_index)
end

function M.on_tick()
    local state = storage.corporate_dominion
    for player_index, preview in pairs(state and state.planner_previews or {}) do
        local player = game.get_player(player_index)
        local cursor = player and player.cursor_stack
        if not player or not player.connected or player.surface.index ~= preview.surface_index
            or player.force.index ~= preview.force_index or not cursor or not cursor.valid_for_read
            or (cursor.name ~= districts.tool_name and cursor.name ~= projects.tool_name and cursor.name ~= residential.tool_name)
            or not preview.objects.text.valid then M.clear(player_index) end
    end
end

return M
