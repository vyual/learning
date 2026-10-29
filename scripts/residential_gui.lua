local residential = require("__learning__/scripts/residential")
local M = {}
function M.draw(body, corporation)
    local frame = body.add {type = "frame", name = "residential", direction = "vertical", caption = {"corporate-residential.title"}}
    local definition = residential.definition
    local description = frame.add {type = "label", caption = {"corporate-residential.description", residential.population,
        residential.food.count, residential.interval / 60, residential.income}}
    description.style.single_line = false; description.style.maximal_width = 380
    frame.add {type = "label", caption = {"corporate-projects.cost", definition.cost}}
    for _, material in ipairs(definition.materials) do
        frame.add {type = "label", caption = {"", "[item=" .. material.name .. "] ", {"item-name." .. material.name}, ": ", material.count}}
    end
    local housing = corporation.residential
    local active = residential.active(housing)
    frame.add {type = "label", name = "population", caption = {"corporate-residential.population", active and residential.population or 0}}
    local status = frame.add {type = "label", name = "status", caption = {"corporate-residential.status-" .. (housing and (active and housing.reason or "no-building") or "unbuilt")}}
    status.style.single_line = false; status.style.maximal_width = 380
    frame.add {type = "label", name = "earnings", caption = {"corporate-residential.earnings", housing and housing.credits_earned or 0}}
    frame.add {type = "button", name = "corporate_residential_build", caption = {"corporate-residential.select"}, enabled = not active}
    local district = corporation.district
    local busy = district and district.order and district.order.status == "pending"
    frame.add {type = "button", name = "corporate_residential_issue", caption = {"corporate-residential.issue", definition.cost},
        enabled = not active and district ~= nil and district.administrator ~= nil and not busy}
    local management_hint = frame.add {type = "label", caption = {"corporate-residential.management-hint"}}
    management_hint.style.single_line = false; management_hint.style.maximal_width = 380
    if active then frame.add {type = "button", name = "corporate_residential_rebind", caption = {"corporate-residential.rebind"}} end
    local feedback = frame.add {type = "label", name = "feedback", caption = ""}
    feedback.style.single_line = false; feedback.style.maximal_width = 380
end
return M
