-- Entry point: anti-cheat first, so it is tracking players before any candy can be picked up.
local AntiCheat = require(script.Parent.AntiCheat)
local CandyService = require(script.Parent.CandyService)
local CandyBots = require(script.Parent.CandyBots)

AntiCheat.start()
CandyService.start()
CandyBots.start()
