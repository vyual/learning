script.on_event(defines.events.on_ai_command_completed, function(event)
    local workers = storage.workers
    if not workers then return end

    local worker_data = workers[event.unit_number]
    if not worker_data or worker_data.task ~= "moving" then return end

    worker_data.task = "idle"

    local worker = worker_data.entity
    local player = game.get_player(worker_data.player_idx)
    if worker and worker.valid and player and player.valid then
        player.print("Юнит " .. worker.name .. " завершил команду.")
    end
    local drills = worker_data.items.drills or 0
    local super_coal = worker_data.items.super_coal or 0
    if drills > 0 and super_coal >= 5 then
        worker_data.items.drills = drills - 1
        worker_data.task = "building"
        local drill = worker.surface.create_entity({
            name = "burner-mining-drill",
            position = worker.position,
            force = worker.force
        })
        local drill_inventory = drill.get_inventory(defines.inventory.fuel)
        worker_data.items.super_coal = super_coal - 5
        drill_inventory.insert({ name = "super-coal", count = 5 })
        worker_data.task = "idle"
    else
        if player and player.valid then
            if drills <= 0 and super_coal < 5 then
                player.print("⚠️ Внимание: у юнита " .. worker.name .. " нет буровой установки и недостаточно супер-угля для работы.")
            elseif drills <= 0 then
                player.print("⚠️ Внимание: у юнита " .. worker.name .. " нет буровой установки для добычи ресурсов.")
            elseif super_coal < 5 then
                player.print("⚠️ Внимание: у юнита " .. worker.name .. " недостаточно супер-угля для работы буровой установки.")
            end
        end
    end
end)