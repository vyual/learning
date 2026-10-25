script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.entity
    local player = game.get_player(event.player_index)
    if entity.name == "super-furnace" then
        if storage.free_refills == nil then
            storage.free_refills = 3 -- если значение не установлено, устанавливаем его в 3
        end
        if storage.free_refills > 0 then
            entity.insert({ name = "super-coal", count = 5 }) -- добавляем 5 единиц супер-угля в супер печь
            storage.free_refills = storage.free_refills - 1   -- уменьшаем количество бесплатных пополнений на 1
            if player and player.valid and player.gui.top.refill_label then
                player.gui.top.refill_label.caption = "Заправки: " .. storage.free_refills -- обновляем текст на интерфейсе игрока
            end
            game.print("Осталось бесплатных заправок: " .. storage.free_refills)
        else
            game.print("⚠️ Внимание: лимит заправок исчерпан!", {r = 1, g = 0.8, b = 0})
            game.print("Пожалуйста, используйте обычный уголь.")
        end
    end
end)
