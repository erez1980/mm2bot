-- Server-side checks against the two things an injected auto-farm does:
--   1. teleporting from candy to candy  -> horizontal speed check
--   2. firing touch events from far away -> distance check on every pickup
-- The client is never trusted: a Touched event only means "the client says it touched".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local cfg = Config.AntiCheat

local AntiCheat = {}

type State = {
	lastPickup: number,
	lastPos: Vector3?,
	lastTime: number,
	strikes: number,
	suspendedUntil: number,
}

local states: { [Player]: State } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function strike(player: Player, reason: string)
	local state = states[player]
	if not state then
		return
	end
	state.strikes += 1
	state.suspendedUntil = os.clock() + cfg.SuspendSeconds
	warn(("[AntiCheat] %s (%d): %s — strike %d"):format(player.Name, player.UserId, reason, state.strikes))
	if cfg.KickAtStrikes and state.strikes >= cfg.KickAtStrikes then
		player:Kick("Unusual movement detected.")
	end
end

-- Call this whenever the game itself moves a player (respawn, round start, admin teleport),
-- so the jump is not counted as speeding.
function AntiCheat.allowTeleport(player: Player)
	local state = states[player]
	if state then
		state.lastPos = nil
	end
end

-- Returns true if this player may collect this candy right now.
function AntiCheat.canPickup(player: Player, candy: BasePart): boolean
	local state = states[player]
	local root = rootOf(player)
	if not state or not root then
		return false
	end
	local now = os.clock()
	if now < state.suspendedUntil then
		return false
	end
	if (root.Position - candy.Position).Magnitude > cfg.MaxPickupDistance then
		strike(player, "pickup from too far away")
		return false
	end
	-- Teleport to the candy and back between two speed samples: the sampler would see no movement,
	-- so also check that the player could have walked here since the last sample.
	if state.lastPos then
		local offset = root.Position - state.lastPos
		local moved = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if moved > cfg.MaxHorizontalSpeed * (now - state.lastTime) + cfg.MaxPickupDistance then
			strike(player, ("reached candy %.0f studs away in %.2fs"):format(moved, now - state.lastTime))
			return false
		end
	end
	if now - state.lastPickup < cfg.MinPickupInterval then
		return false -- too fast to be human, but common enough with lag that it is not a strike
	end
	state.lastPickup = now
	return true
end

local function sampleSpeeds()
	local now = os.clock()
	for player, state in states do
		local root = rootOf(player)
		if root then
			local pos = root.Position
			if state.lastPos then
				local dt = now - state.lastTime
				local moved = Vector3.new(pos.X - state.lastPos.X, 0, pos.Z - state.lastPos.Z).Magnitude
				if dt > 0 and moved / dt > cfg.MaxHorizontalSpeed then
					strike(player, ("moved %.0f studs in %.2fs"):format(moved, dt))
				end
			end
			state.lastPos, state.lastTime = pos, now
		end
	end
end

function AntiCheat.start()
	local function onPlayerAdded(player: Player)
		states[player] = { lastPickup = 0, lastPos = nil, lastTime = 0, strikes = 0, suspendedUntil = 0 }
		player.CharacterAdded:Connect(function()
			AntiCheat.allowTeleport(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.SampleInterval)
			sampleSpeeds()
		end
	end)
end

return AntiCheat
