-- Определение по сохранённому id. Старые поручения без id означают склад.
local projects = require("__learning__/scripts/projects")
local residential = require("__learning__/scripts/residential")
local M = {}
function M.get(id)
    if id == nil or id == projects.definition.id then return projects.definition end
    if id == residential.definition.id then return residential.definition end
end
function M.title(id)
    if id == residential.definition.id then return {"corporate-residential.title"} end
    if id == nil or id == projects.definition.id then return {"corporate-projects.title"} end
    return {"corporate-districts.unknown-project"}
end
return M
