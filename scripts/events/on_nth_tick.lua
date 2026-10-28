script.on_nth_tick(60, function(event)
    if storage.scanner_enabled then
        for _, player in pairs(game.connected_players) do
            if player.character and player.character.valid then
                local position = player.position
                local surface = player.surface
                local radius = 10 -- радиус сканирования

                -- Получаем все объекты в радиусе вокруг игрока
                local entities = surface.find_entities_filtered {
                    type = "resource",
                    area = {
                        { position.x - radius, position.y - radius },
                        { position.x + radius, position.y + radius }
                    }
                }

                -- Выводим информацию о найденных объектах в чат игрока
                for _, entity in pairs(entities) do
                    player.print("Найден объект: " ..
                    entity.name .. " на позиции (" .. entity.position.x .. ", " .. entity.position.y .. ")")
                    player.print("⚠️ Внимание: найден ресурс " .. entity.name .. "!")
                    storage.scanner_enabled = false
                    local resource_key = entity.position.x .. ":" .. entity.position.y

                    storage.reservations[resource_key] = {position = {x = entity.position.x, y = entity.position.y}, name = entity.name, worker = nil}
                    break     -- останавливаем дальнейшее сканирование после нахождения первого ресурса`
                end
            end
        end
    end
end)
