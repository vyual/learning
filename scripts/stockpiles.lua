-- Общий доступ к физическим запасам корпорации. Никакого поиска по всей карте.
local M = {}

function M.collect(corporation, force, surface)
    local inventories, seen = {}, {}
    for _, project in ipairs(corporation.projects or {}) do
        if project.surface_index == surface.index then
            for _, entity in ipairs(project.entities) do
                if entity.valid and entity.name == "iron-chest" and entity.force == force
                    and entity.surface == surface and not seen[entity.unit_number] then
                    seen[entity.unit_number] = true
                    local inventory = entity.get_inventory(defines.inventory.chest)
                    if inventory and inventory.valid then inventories[#inventories + 1] = inventory end
                end
            end
        end
    end
    return inventories
end

-- Одна операция: проверка всей партии + резерва, списание, возврат при частичной неудаче.
function M.take(inventories, item, reserve)
    local total = 0
    for _, inventory in ipairs(inventories) do
        if not inventory.valid then return false end
        total = total + inventory.get_item_count {name = item.name, quality = item.quality}
    end
    if total < item.count + (reserve or 0) then return false end
    local remaining, removed = item.count, {}
    for _, inventory in ipairs(inventories) do
        if remaining > 0 then
            local count = inventory.remove {name = item.name, quality = item.quality, count = remaining}
            removed[#removed + 1] = {inventory = inventory, count = count}
            remaining = remaining - count
        end
    end
    if remaining > 0 then
        for _, entry in ipairs(removed) do
            if entry.count > 0 then entry.inventory.insert {name = item.name, quality = item.quality, count = entry.count} end
        end
        return false
    end
    return true, item.count
end

return M
