script.on_event(defines.events.on_ai_command_completed, function(event)
    local workers = storage.workers
    if not workers then return end

    local worker_data = workers[event.unit_number]
    if not worker_data or worker_data.task ~= "moving" then return end

    worker_data.task = "idle"

    local worker = worker_data.entity
    local player = game.get_player(worker_data.player_idx)
    if worker and worker.valid and player and player.valid then
        player.print("Юнит " .. worker.name .. " достиг цели. Добыча ресурсов пока не реализована.")
    end
end)
