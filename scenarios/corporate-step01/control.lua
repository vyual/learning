-- Проверка в настоящем движке Factorio; выполняется только как тестовый сценарий.
local corporations = require("__learning__/scripts/corporations")
local FRAME = "corporate_dominion_hq"

script.on_event(defines.events.on_tick, function()
    local player = game.get_player(1)
    if not player then return end
    if storage.step01_passed then
        if game.tick > storage.step01_passed + 5 then
            log("STEP01 ALL CHECKS PASSED")
            script.finish_test(true)
        end
        return
    end

    corporations.initialize()
    assert(not corporations.get(player.force.index))
    assert(not corporations.found(player.force.index, player.index, "   "))
    assert(not corporations.found(player.force.index, player.index, string.rep("Я", 41)))
    assert(not corporations.found(player.force.index, player.index, "Line\nBreak"))
    local hq = player.surface.create_entity {name = "corporate-hq", position = {10, 0}, force = player.force}
    assert(hq and hq.valid)

    -- Реальная регистрация мода: запись в opened вызывает on_gui_opened.
    player.opened = hq
    local actual_frame = player.opened
    assert(actual_frame and actual_frame.object_name == "LuaGuiElement")
    assert(actual_frame.name == FRAME and actual_frame.get_mod() == "learning")
    assert(actual_frame.body.corporation_name.text == "NEXUS")
    player.opened = nil
    assert(not actual_frame.valid, "Escape/close handler did not remove the HQ card")

    -- Те же функции с настоящими LuaGuiElement, но в хранилище сценария.
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    local frame = player.gui.screen[FRAME]
    assert(frame and frame.valid)
    frame.body.corporation_name.text = " "
    corporations.on_gui_click {player_index = player.index, element = frame.body.corporate_dominion_found}
    assert(not corporations.get(player.force.index))
    frame.body.corporation_name.text = "  Нексус  "
    corporations.on_gui_click {player_index = player.index, element = frame.body.corporate_dominion_found}
    local corporation = corporations.get(player.force.index)
    assert(corporation.name == "Нексус" and corporation.credits == 0)
    assert(not frame.body.corporation_name, "Founding form was not replaced by the profile")
    corporation.credits = 37
    assert(corporations.found(player.force.index, player.index, "Replacement") == corporation)
    assert(corporation.credits == 37, "Repeat founding reset the balance")
    corporations.close(player)
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    assert(corporations.get(player.force.index).name == "Нексус")
    corporations.on_gui_closed {player_index = player.index, element = player.gui.screen[FRAME]}
    assert(not player.gui.screen[FRAME])

    local rival = game.create_force("step01-test-rival")
    local rival_corporation = corporations.found(rival.index, player.index, "Rival")
    assert(rival_corporation ~= corporation)
    hq.force = rival
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    assert(not player.gui.screen[FRAME], "A foreign headquarters opened our corporation")
    hq.force = player.force
    corporations.on_gui_opened {player_index = player.index, entity = hq}
    corporations.close(player)
    hq.destroy()
    assert(corporations.get(player.force.index).credits == 37, "Removing the HQ deleted the corporation")
    corporations.initialize()
    assert(corporations.get(player.force.index).credits == 37, "Initialization reset saved data")

    storage.step01_passed = game.tick
    log("STEP01 STATE AND GUI CHECKS PASSED")
end)
