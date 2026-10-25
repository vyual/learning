script.on_event(defines.events.on_player_created, function(event)
    -- Получаем объект конкретного игрока по его номеру (player_index) из события
    local player = game.get_player(event.player_index)

    -- Пишем игроку приветствие в чат
    player.print("Добро пожаловать! Твой стартовый набор выдан.")
end)

script.on_event(defines.events.on_cutscene_cancelled, function(event)
    local random_loot = {
        { name = "iron-plate",   count = 10 },
        { name = "copper-plate", count = 8 },
        { name = "coal",         count = 15 }
    }
    local player = game.get_player(event.player_index)
    local random_item = random_loot
        [math.random(#random_loot)] -- # - оператор длины таблицы, math.random выбирает случайный индекс)

    -- Создаем текстовую надпись в верхней части интерфейса игрока
    if not player.gui.top.refill_label then
        local label = player.gui.top.add({
            type = "label", -- тип элемента (текстовая надпись)
            name = "refill_label", -- уникальное имя внутри родителя
            caption = "Заправки: " .. storage.free_refills -- текст, который увидит игрок
        })
    end

    player.insert({ name = random_item.name, count = random_item.count })
    player.insert({ name = "super-coal", count = 10 })
    player.insert({ name = "super-furnace", count = 1 })

    log("Debug: Игрок " ..
        player.name ..
        " получил стартовый набор: " ..
        random_item.name .. " x" .. random_item.count .. ", супер-уголь x10, супер-печь x1")
    player.print("Добро пожаловать! Твой стартовый набор выдан.")
end)
