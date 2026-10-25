script.on_init(function()
    storage.free_refills = 3
    storage.scanner_enabled = false
end)

require("scripts.commands")
require("scripts.events.player")
require("scripts.events.furnace")
require("scripts.events.on_nth_tick")
require("scripts.events.on_ai_command_completed")
