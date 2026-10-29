-- Корпорация: сохранённая карточка и первый заказ на поставку.
local orders = require("__learning__/scripts/orders")
local projects = require("__learning__/scripts/projects")
local districts = require("__learning__/scripts/districts")
local auto_supply = require("__learning__/scripts/auto_supply")
local residential = require("__learning__/scripts/residential")
local residential_gui = require("__learning__/scripts/residential_gui")
local construction_projects = require("__learning__/scripts/construction_projects")
local M = {}
local FRAME = "corporate_dominion_hq"
local UI_REVISION = 5

-- storage сохраняется вместе с картой. Обычная local-таблица этого не делает.
function M.initialize()
    storage.corporate_dominion = storage.corporate_dominion or {
        corporations = {},
        open_hqs = {}
    }
    return storage.corporate_dominion
end

function M.get(force_index)
    return M.initialize().corporations[force_index]
end

function M.found(force_index, founder_index, raw_name)
    local state = M.initialize()
    -- Два игрока одной команды не могут создать две корпорации или сбросить баланс.
    if state.corporations[force_index] then
        return state.corporations[force_index]
    end
    local name = raw_name:match("^%s*(.-)%s*$")
    -- Убираем продолжения UTF-8: русская буква считается одним символом.
    local characters = #name:gsub("[\128-\191]", "")
    if characters == 0 or characters > 40 or name:find("[%c]") then
        return nil, {"corporate-dominion.invalid-name"}
    end
    local corporation = {
        name = name,
        credits = 0,
        founded_tick = game.tick,
        founder_index = founder_index
    }
    state.corporations[force_index] = corporation
    return corporation
end

local function draw_body(frame, corporation)
    local body = frame.body
    body.clear()
    frame.tags = {ui_revision = UI_REVISION}
    if corporation then
        body.add {type = "label", caption = corporation.name, style = "bold_label"}
        body.add {type = "label", name = "balance", caption = {"corporate-dominion.balance", corporation.credits}}
        local contract = body.add {type = "frame", name = "order", direction = "vertical",
            caption = {"corporate-orders.title"}}
        local definition = orders.definition
        contract.add {type = "label", caption = {"corporate-orders.requirement", definition.amount}}
        contract.add {type = "label", caption = {"corporate-orders.reward", definition.reward}}
        local hint = contract.add {type = "label", caption = {"corporate-orders.inventory-hint"}}
        hint.style.single_line = false
        hint.style.maximal_width = 380
        local completed = orders.is_complete(corporation)
        contract.add {type = "button", name = "corporate_dominion_deliver",
            caption = {completed and "corporate-orders.completed" or "corporate-orders.deliver"},
            enabled = not completed}
        if completed then
            local supply = orders.supply_definition
            contract.add {type = "line"}
            contract.add {type = "label", caption = {"corporate-orders.supply-title"}, style = "bold_label"}
            contract.add {type = "label", caption = {"corporate-orders.requirement", supply.amount}}
            contract.add {type = "label", caption = {"corporate-orders.reward", supply.reward}}
            local repeat_hint = contract.add {type = "label", caption = {"corporate-orders.supply-hint"}}
            repeat_hint.style.single_line = false
            repeat_hint.style.maximal_width = 380
            contract.add {type = "label", name = "supply_count", caption = {"corporate-orders.supply-count", orders.supply_count(corporation)}}
            contract.add {type = "button", name = "corporate_dominion_supply", caption = {"corporate-orders.deliver-supply"}}
            local auto = corporation.auto_supply
            local auto_hint = contract.add {type = "label", caption = {"corporate-auto.hint",
                supply.amount, supply.reward, auto_supply.interval / 60}}
            auto_hint.style.single_line = false
            auto_hint.style.maximal_width = 380
            local auto_status = contract.add {type = "label", name = "auto_status",
                caption = {"corporate-auto.status-" .. (auto and auto.reason or "off")}}
            auto_status.style.single_line = false
            auto_status.style.maximal_width = 380
            contract.add {type = "label", name = "auto_count", caption = {"corporate-auto.count", auto and auto.shipments or 0}}
            contract.add {type = "button", name = "corporate_dominion_auto_supply",
                caption = {auto_supply.enabled(corporation) and "corporate-auto.disable" or "corporate-auto.enable"}}
        end
        local feedback = contract.add {type = "label", name = "feedback", caption = ""}
        feedback.style.single_line = false
        feedback.style.maximal_width = 380
        local project = body.add {type = "frame", name = "project", direction = "vertical",
            caption = {"corporate-projects.title"}}
        local description = project.add {type = "label", caption = {"corporate-projects.description"}}
        description.style.single_line = false
        description.style.maximal_width = 380
        project.add {type = "label", caption = {"corporate-projects.cost", projects.definition.cost}}
        for _, material in ipairs(projects.definition.materials) do
            project.add {type = "label", caption = {"", "[item=" .. material.name .. "] ",
                {"item-name." .. material.name}, ": ", material.count}}
        end
        project.add {type = "label", caption = {"corporate-projects.count", projects.count(corporation)}}
        project.add {type = "button", name = "corporate_dominion_build", caption = {"corporate-projects.select"}}
        local district_ui = body.add {type = "frame", name = "district", direction = "vertical",
            caption = {"corporate-districts.title"}}
        local district = corporation.district
        local selecting = district and district.order and district.order.status == "pending"
        district_ui.add {type = "button", name = "corporate_district_select",
            caption = {district and "corporate-districts.redefine" or "corporate-districts.select"}, enabled = not selecting}
        if district then
            local b = district.bounds
            district_ui.add {type = "label", caption = {"corporate-districts.size", b.right - b.left, b.bottom - b.top}}
            district_ui.add {type = "textfield", name = "administrator_name",
                text = district.administrator and district.administrator.name or "Ирина Волкова"}
            district_ui.add {type = "button", name = "corporate_district_assign", caption = {"corporate-districts.assign"}}
            local help = district_ui.add {type = "label", caption = {"corporate-districts.supply-hint", district.order and district.order.budget or projects.definition.cost}}
            help.style.single_line = false
            help.style.maximal_width = 380
            if district.order then
                district_ui.add {type = "label", caption = {"corporate-districts.selected-project", construction_projects.title(district.order.project_id)}}
            end
            local reason = district.order and district.order.reason or "idle"
            local status_key = "corporate-districts.status-" .. reason
            if reason == "completed" and district.order.project_id == residential.definition.id then status_key = "corporate-residential.managed-completed" end
            local status = district_ui.add {type = "label", name = "status", caption = {status_key}}
            status.style.single_line = false
            status.style.maximal_width = 380
            district_ui.add {type = "button", name = "corporate_district_issue", caption = {"corporate-districts.issue"},
                enabled = district.administrator ~= nil and not selecting and not districts.completed(district, projects.definition.id)}
            district_ui.add {type = "button", name = "corporate_district_cancel", caption = {"corporate-districts.cancel-order"},
                enabled = selecting == true}
        end
        residential_gui.draw(body, corporation)
        local result = body.add {type = "label", name = "order_result", caption = ""}
        result.style.single_line = false
        result.style.maximal_width = 400
    else
        local hint = body.add {type = "label", caption = {"corporate-dominion.introduction"}}
        hint.style.single_line = false
        hint.style.maximal_width = 400
        body.add {type = "label", caption = {"corporate-dominion.name-label"}}
        local input = body.add {type = "textfield", name = "corporation_name", text = "NEXUS"}
        input.style.width = 400
        body.add {type = "button", name = "corporate_dominion_found", caption = {"corporate-dominion.found"}}
        body.add {type = "label", name = "error", caption = ""}
    end
end

-- Обновляем общий баланс и статус заказа у всех открытых штабов команды.
-- Это выполняется по событию, а не каждый игровой тик.
local function refresh_team(force_index)
    for _, player in pairs(game.players) do
        if player.force.index == force_index then
            local frame = player.gui.screen[FRAME]
            if frame then draw_body(frame, M.get(force_index)) end
        end
    end
end

function M.close(player)
    local frame = player.gui.screen[FRAME]
    if frame then frame.destroy() end
    M.initialize().open_hqs[player.index] = nil
end

function M.on_gui_opened(event)
    local entity = event.entity
    if not entity or not entity.valid or entity.name ~= "corporate-hq" then return end
    local player = game.get_player(event.player_index)
    if not player or entity.force ~= player.force then return end
    M.close(player)
    local frame = player.gui.screen.add {
        type = "frame", name = FRAME, direction = "vertical",
        caption = {"corporate-dominion.title"}
    }
    local body = frame.add {type = "scroll-pane", name = "body", direction = "vertical",
        vertical_scroll_policy = "auto", horizontal_scroll_policy = "never"}
    body.style.maximal_height = math.max(240, math.min(640, math.floor(player.display_resolution.height / player.display_scale) - 180))
    body.style.minimal_width = 420
    draw_body(frame, M.get(player.force.index))
    frame.add {type = "button", name = "corporate_dominion_close", caption = {"gui.close"}}
    frame.auto_center = true
    M.initialize().open_hqs[player.index] = entity
    -- Esc и E теперь закрывают нашу карточку вместо интерфейса сборочного автомата.
    player.opened = frame
end

function M.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local frame = player.gui.screen[FRAME]
    if not frame then return end
    if element.name == "corporate_dominion_close" and element.parent == frame then
        M.close(player)
        return
    end
    if element.name == "corporate_dominion_deliver" and element.parent == frame.body.order then
        local corporation = M.get(player.force.index)
        local hq = M.initialize().open_hqs[player.index]
        local success, message = orders.deliver(player, hq, corporation)
        if success then refresh_team(player.force.index) end
        if frame.valid and frame.body.order_result then
            frame.body.order_result.caption = message
            frame.body.order.feedback.caption = message
        end
        return
    end
    if element.name == "corporate_dominion_supply" and element.parent == frame.body.order then
        local success, message = orders.deliver_supply(player, M.initialize().open_hqs[player.index], M.get(player.force.index))
        if success then refresh_team(player.force.index) end
        if frame.valid and frame.body.order_result then
            frame.body.order_result.caption = message
            frame.body.order.feedback.caption = message
        end
        return
    end
    if element.name == "corporate_dominion_auto_supply" and element.parent == frame.body.order then
        local corporation = M.get(player.force.index)
        local success, message = auto_supply.set_enabled(player, M.initialize().open_hqs[player.index], corporation,
            corporation and not auto_supply.enabled(corporation))
        if success then refresh_team(player.force.index) end
        if frame.valid and frame.body.order_result then
            frame.body.order_result.caption = message
            frame.body.order.feedback.caption = message
        end
        return
    end
    if element.name == "corporate_residential_issue" and element.parent == frame.body.residential then
        local success, message = districts.issue(player, M.initialize().open_hqs[player.index], M.get(player.force.index), residential.definition.id)
        if success then refresh_team(player.force.index) end
        if frame.valid then frame.body.residential.feedback.caption = message end
        return
    end
    if element.name == "corporate_residential_rebind" and element.parent == frame.body.residential then
        local success, message = residential.rebind(player, M.initialize().open_hqs[player.index], M.get(player.force.index))
        if success then refresh_team(player.force.index) end
        if frame.valid then frame.body.residential.feedback.caption = message end
        return
    end
    if element.name == "corporate_residential_build" and element.parent == frame.body.residential then
        local success, message = residential.begin(player, M.initialize().open_hqs[player.index], M.get(player.force.index))
        if success then M.close(player); player.print(message)
        else frame.body.residential.feedback.caption = message end
        return
    end
    if element.name == "corporate_dominion_build" and element.parent == frame.body.project then
        local success, message = projects.begin(player, M.initialize().open_hqs[player.index], M.get(player.force.index))
        if success then
            M.close(player)
            player.print(message)
        else
            frame.body.order_result.caption = message
        end
        return
    end
    if element.parent == frame.body.district then
        local corporation = M.get(player.force.index)
        local hq = M.initialize().open_hqs[player.index]
        if not hq or not hq.valid or hq.force ~= player.force then
            M.close(player); player.print {"corporate-dominion.hq-unavailable"}; return
        end
        local success, message
        if element.name == "corporate_district_select" then
            success, message = districts.begin(player, hq, corporation)
            if success then M.close(player); player.print(message); return end
        elseif element.name == "corporate_district_assign" then
            success, message = districts.assign(corporation, frame.body.district.administrator_name.text)
        elseif element.name == "corporate_district_issue" then
            success, message = districts.issue(player, hq, corporation)
        elseif element.name == "corporate_district_cancel" then
            success, message = districts.cancel_order(corporation)
        else return end
        if success then refresh_team(player.force.index) end
        if frame.valid then frame.body.order_result.caption = message end
        return
    end
    if element.name ~= "corporate_dominion_found" then return end
    if element.parent ~= frame.body then return end
    local hq = M.initialize().open_hqs[player.index]
    if not hq or not hq.valid or hq.force ~= player.force then
        M.close(player)
        player.print {"corporate-dominion.hq-unavailable"}
        return
    end
    local corporation, message = M.found(player.force.index, player.index, frame.body.corporation_name.text)
    if not corporation then
        frame.body.error.caption = message
        return
    end
    refresh_team(player.force.index)
end

function M.on_player_selected_area(event)
    if event.item == residential.tool_name then
        local player = game.get_player(event.player_index)
        if not player then return end
        local success, message = residential.build(player, event.surface, event.area, M.get(player.force.index))
        if success then refresh_team(player.force.index) end
        player.print(message)
        return
    end
    if event.item == districts.tool_name then
        local player = game.get_player(event.player_index)
        if not player then return end
        local success, message = districts.define(player, event.surface, event.area, M.get(player.force.index))
        if success then refresh_team(player.force.index) end
        player.print(message)
        return
    end
    if event.item ~= projects.tool_name then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local success, message = projects.build(player, event.surface, event.area, M.get(player.force.index))
    if success then refresh_team(player.force.index) end
    player.print(message)
end

function M.on_player_alt_selected_area(event)
    if event.item == residential.tool_name then
        local player = game.get_player(event.player_index)
        if player then residential.cancel(player); player.print {"corporate-projects.cancelled"} end
        return
    end
    if event.item == districts.tool_name then
        local player = game.get_player(event.player_index)
        if player then districts.cancel_selection(player); player.print {"corporate-projects.cancelled"} end
        return
    end
    if event.item ~= projects.tool_name then return end
    local player = game.get_player(event.player_index)
    if player then projects.cancel(player); player.print {"corporate-projects.cancelled"} end
end

function M.on_cursor_changed(event)
    projects.on_cursor_changed(event)
    districts.on_cursor_changed(event)
    residential.on_cursor_changed(event)
end

function M.on_district_tick()
    for _, force_index in ipairs(residential.tick()) do refresh_team(force_index) end
    -- Сначала доход, затем стройка: управляющий может оплатить поручение этой же проверкой.
    for _, force_index in ipairs(auto_supply.tick()) do refresh_team(force_index) end
    -- GUI сохраняется вместе с картой, включая старые кнопки и подписи.
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.screen[FRAME]
        if frame and frame.tags.ui_revision ~= UI_REVISION then draw_body(frame, M.get(player.force.index)) end
    end
    for _, force_index in ipairs(districts.tick()) do
        refresh_team(force_index)
        local district = M.get(force_index).district
        if district.order.status == "completed" then
            for _, player in pairs(game.connected_players) do
                if player.force.index == force_index then
                    local key = "corporate-districts.report-completed"
                    if district.order.reason == "already-built" then key = "corporate-residential.report-existing"
                    elseif district.order.project_id == residential.definition.id then key = "corporate-residential.report-managed" end
                    player.print {key, district.administrator.name}
                end
            end
        end
    end
end

function M.on_gui_closed(event)
    local element = event.element
    if element and element.valid and element.name == FRAME then
        local player = game.get_player(event.player_index)
        if player and player.gui.screen[FRAME] == element then M.close(player) end
    end
end

return M
