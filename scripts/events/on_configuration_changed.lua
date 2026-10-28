script.on_configuration_changed(function(event)
    -- Обработка изменений конфигурации мода
    if event.mod_changes then
        for mod_name, changes in pairs(event.mod_changes) do
            if mod_name == "learning" then
                if changes.old_version then
                    game.print("Мод 'learning' обновлен с версии " ..
                    changes.old_version .. " на " .. changes.new_version)
                else
                    game.print("Мод 'learning' установлен впервые.")
                end
                storage.workers = storage.workers or {}                    -- инициализируем таблицу рабочих, если её нет
                storage.free_refills = storage.free_refills or
                0                                                          -- инициализируем счетчик бесплатных заправок, если его нет
                storage.scanner_enabled = storage.scanner_enabled or false -- инициализируем флаг сканера, если его нет
                storage.reservations = storage.reservations or {} -- инициализируем таблицу резерваций, если её нет
                -- миграция данных рабочих, если у них нет таблицы предметов
                for _, worker in pairs(storage.workers) do
                    if worker.items == nil then
                        worker.items = {
                            super_coal = 0,
                            drills = 0,
                        }
                    else
                        if worker.items then
                            if worker.items.super_coal == nil then
                                worker.items.super_coal = 0
                            end
                            if worker.items.drills == nil then
                                worker.items.drills = 0
                            end
                        end
                    end
                end
            end
        end
    end
end)
