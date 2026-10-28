commands.add_command("reset-refills", "Сбрасывает счетчик бесплатных заправок печи", function(command)
    if command.parameter == nil then
        game.print("Пожалуйста, укажите количество бесплатных заправок для сброса. Например: /reset-refills 3")
        return
    end

    local num = tonumber(command.parameter)
    if num == nil or num < 0 or num % 1 ~= 0 then
        game.print("Пожалуйста, укажите целое неотрицательное число для сброса.")
        return
    end

    storage.free_refills = num
    game.print("Счетчик бесплатных заправок сброшен.")
    local player = command.player_index and game.get_player(command.player_index)
    if player and player.valid and player.gui.top.refill_label then
        player.gui.top.refill_label.caption = "Заправки: " ..
            storage.free_refills -- обновляем текст на интерфейсе игрока
    end
end)

commands.add_command("toggle-scanner", "Включает или выключает сканер", function(command)
    storage.scanner_enabled = not storage.scanner_enabled
    local status = storage.scanner_enabled and "включен" or "выключен"
    game.print("Сканер теперь " .. status .. ".")
end)

commands.add_command("spawn-worker", "Спавнит рабочего рядом с игроком", function(command)
    local player = game.get_player(command.player_index)
    if player and player.valid and player.character then
        local position = { x = player.position.x + 2, y = player.position.y } -- спавн на 2 клетки правее игрока
        local surface = player.surface
        local worker = surface.create_entity { name = "small-biter", position = position, force = player.force }

        if worker then
            game.print("Рабочий успешно заспавнен рядом с игроком " .. player.name .. ".")
            storage.workers = storage.workers or {}
            local worker_data = {
                entity = worker,
                task = "idle",
                player_idx = command.player_index,
                items = {
                    drills = 0,
                    super_coal = 0,
                } -- создаем пустой инвентарь для хранения ресурсов
            }

            storage.workers[worker.unit_number] = worker_data
        else
            game.print("Не удалось заспавнить рабочего.")
        end
    else
        game.print("Игрок не найден или не имеет персонажа.")
    end
end)


commands.add_command("debug-give-items", "Выдает рабочим предметы для добычи ресурсов", function(command)
    if not storage.workers or next(storage.workers) == nil then
        game.print("Нет заспавненных рабочих для выдачи предметов.")
        return
    end

    for _, worker_data in pairs(storage.workers) do
        local worker = worker_data.entity -- извлекаем ссылку на рабочего из таблицы
        if worker and worker.valid then
            -- Выдаем рабочему буровую установку и топливо
            worker_data.items.drills = (worker_data.items.drills or 0) + 1
            worker_data.items.super_coal = (worker_data.items.super_coal or 0) + 5
            game.print("Рабочему " .. worker.name .. " выдана буровая установка для добычи ресурсов.")
        end
    end
end)

commands.add_command("remove-workers", "Удаляет всех заспавненных рабочих", function(command)
    if storage.workers then
        for _, worker_data in pairs(storage.workers) do
            local worker = worker_data.entity -- извлекаем ссылку на рабочего из таблицы
            if worker and worker.valid then
                worker.destroy()
            end
        end
        storage.workers = nil -- очищаем список рабочих после удаления
        game.print("Все заспавненные рабочие удалены.")
    else
        game.print("Нет заспавненных рабочих для удаления.")
    end
end)

commands.add_command("send-worker", "Отправляет рабочего к ближайшему ресурсу", function(command)
    if not storage.nearest_resource then
        game.print("Нет информации о ближайшем ресурсе. Пожалуйста, сначала используйте сканер.")
        return
    end

    if not storage.workers or next(storage.workers) == nil then
        game.print("Нет заспавненных рабочих для отправки.")
        return
    end

    local nearest_resource = storage.nearest_resource
    local resource_position = nearest_resource.position

    for _, worker_data in pairs(storage.workers) do
        local worker = worker_data.entity -- извлекаем ссылку на рабочего из таблицы
        if worker and worker.valid and worker_data.task == "idle" then
            worker.commandable.set_command({
                type = defines.command.go_to_location,
                destination = resource_position,
                radius = 1,
                distraction = defines.distraction.none
            })
            worker_data.task = "moving" -- обновляем статус рабочего на "moving"
            game.print("Рабочий отправлен к ресурсу: " ..
                nearest_resource.name .. " на позиции (" .. resource_position.x .. ", " .. resource_position.y .. ").")
            break -- отправляем только одного рабочего к ресурсу, если нужно отправить всех, уберите break
        end
    end
end)
