local corporations = require("__learning__/scripts/corporations")
local projects = require("__learning__/scripts/projects")
local districts = require("__learning__/scripts/districts")
local preview = require("__learning__/scripts/planner_preview")
local orders = require("__learning__/scripts/orders")
local FRAME = "corporate_dominion_hq"

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if not player.character then assert(player.create_character()) end
    local surface = game.create_surface("preview-test", {width = 128, height = 128})
    surface.request_to_generate_chunks({0, 0}, 2); surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -40, 40 do for y = -40, 40 do tiles[#tiles+1] = {name = "grass-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    assert(player.teleport({4.5, 0.5}, surface))
    local inventory = player.get_main_inventory(); inventory.clear(); player.clear_cursor()
    local hq = surface.create_entity {name = "corporate-hq", position = {0.5, 0.5}, force = player.force}
    local corporation = corporations.found(player.force.index, player.index, "Preview Test")
    corporation.credits = 2000
    local function area(left, top, right, bottom)
        return {left_top = {x = left, y = top}, right_bottom = {x = right, y = bottom}}
    end
    local function show(item, box, mode)
        preview.on_area {player_index = player.index, item = item, area = box, surface = surface,
            cursor_position = box.right_bottom, selection_mode = mode or defines.selection_mode.select}
        return storage.corporate_dominion.planner_previews[player.index]
    end
    local function is_red(p) return p.objects.outline.color.r > 0.9 and p.objects.text.color.g < 0.3 end
    local function is_green(p) return p.objects.outline.color.g > 0.9 and p.objects.text.color.r < 0.3 end
    assert(prototypes.item[districts.tool_name].name and defines.events.on_player_change_selected_area)
    assert(districts.begin(player, hq, corporation))
    local p = show(districts.tool_name, area(7, 7, 13, 13))
    assert(is_green(p))
    assert(p.objects.text.text[2][1] == "corporate-preview.district")
    assert(tonumber(p.objects.text.text[2][2]) == 6 and tonumber(p.objects.text.text[2][3]) == 6)
    assert(p.objects.text.players[1].index == player.index)
    local object = p.objects.text
    p = show(districts.tool_name, area(7, 7, 32, 13))
    assert(p.objects.text == object and is_red(p), "Preview must reuse render objects")
    assert(p.objects.text.text[4][1] == "corporate-districts.bad-size")
    assert(not districts.define(player, surface, area(7, 7, 32, 13), corporation))
    assert(not corporation.district and corporation.credits == 2000)
    assert(is_red(show(districts.tool_name, area(7, 7, 12, 13))))
    assert(is_green(show(districts.tool_name, area(-12, -12, 12, 12))))
    p = show(districts.tool_name, area(22, 22, 28, 28))
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-districts.outside-radius")
    local rival = game.create_force("rival-preview")
    storage.corporate_dominion.corporations[rival.index] = {district = {surface_index = surface.index,
        bounds = {left = 7, top = 7, right = 13, bottom = 13}}}
    p = show(districts.tool_name, area(7, 7, 13, 13))
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-districts.overlap")
    storage.corporate_dominion.corporations[rival.index] = nil
    preview.clear(player.index); assert(not object.valid)
    assert(districts.define(player, surface, area(7, 7, 13, 13), corporation))
    assert(corporation.credits == 2000 and corporation.district.bounds.right == 13)

    -- Фактический размер склада постоянный, даже если игрок растянул большую область.
    for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
    assert(projects.begin(player, hq, corporation))
    local site = area(9, -10, 13, -6)
    p = show(projects.tool_name, site)
    assert(is_green(p))
    local bounds = p.objects.outline
    assert(bounds.right_bottom.position.x - bounds.left_top.position.x == 3)
    assert(bounds.right_bottom.position.y - bounds.left_top.position.y == 3)
    assert(projects.center(area(-3, -3, -2, -2)).x == -2.5)
    local center = projects.center(site)
    local blocker = surface.create_entity {name = "iron-chest", position = center, force = player.force}
    p = show(projects.tool_name, site)
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-projects.blocked")
    assert(not projects.build(player, surface, site, corporation))
    assert(corporation.credits == 2000 and projects.count(corporation) == 0)
    blocker.destroy()
    corporation.credits = 0
    p = show(projects.tool_name, site)
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-projects.no-money")
    corporation.credits = 2000
    inventory.clear()
    p = show(projects.tool_name, site)
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-projects.no-materials")
    for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
    p = show(projects.tool_name, area(38, 0, 39, 1))
    assert(is_red(p) and p.objects.text.text[4][1] == "corporate-projects.too-far")
    p = show(projects.tool_name, site)
    object = p.objects.text
    preview.on_cursor_changed {player_index = player.index}
    assert(not object.valid and not storage.corporate_dominion.planner_previews[player.index])
    -- Никаких предварительных событий: подтверждение всё равно работает.
    assert(projects.build(player, surface, site, corporation))
    assert(corporation.credits == 1500 and projects.count(corporation) == 1)
    assert(not projects.build(player, surface, site, corporation))
    assert(corporation.credits == 1500)
    for _, material in ipairs(projects.definition.materials) do inventory.insert(material) end
    assert(projects.begin(player, hq, corporation))
    p = show(projects.tool_name, area(15, -10, 16, -9)); object = p.objects.text
    player.clear_cursor(); projects.on_cursor_changed {player_index = player.index}; preview.on_tick()
    assert(not object.valid, "Missed cursor event must be cleaned up")
    assert(projects.begin(player, hq, corporation))
    p = show(projects.tool_name, site); object = p.objects.text
    show(projects.tool_name, site, defines.selection_mode.alt_select)
    assert(not object.valid)
    projects.cancel(player)

    -- Старое окно могло сохраниться в сейве до добавления повторяемой поставки.
    corporation.orders = {[orders.definition.id] = {delivered = 100, completed_tick = game.tick}}
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    frame.body.order.corporate_dominion_supply.destroy()
    frame.tags = {}
    corporations.on_district_tick()
    assert(frame.body.order.corporate_dominion_supply.enabled)
    assert(corporation.credits == 1500 and projects.count(corporation) == 1)
    log("PREVIEW REGRESSION PASSED: BOUNDARIES, RADIUS, OVERLAP, BLOCKING, FUNDS, MATERIALS, CLEANUP, GUI UPGRADE")
    script.finish_test(true)
end)
