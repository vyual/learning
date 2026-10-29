local corporations = require("scripts.corporations")

script.on_init(function()
    corporations.initialize()
    storage.free_refills = 3
    storage.scanner_enabled = false
    storage.reservations = {}
end)

require("scripts.commands")
require("scripts.events.player")
require("scripts.events.furnace")
require("scripts.events.on_nth_tick")
require("scripts.events.on_ai_command_completed")
require("scripts.events.on_configuration_changed")
require("scripts.events.corporations")
