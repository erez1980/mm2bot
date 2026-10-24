-- NPC collectors: each bot picks the candy in the emptiest spot, walks there with pathfinding,
-- and runs away whenever a player comes close.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SafeTarget = require(ReplicatedStorage.Shared.SafeTarget)
local CandyService = require(script.Parent.CandyService)
local MapArea = require(script.Parent.MapArea)

local cfg = Config.Bots

local CandyBots = {}

local botFolder: Folder
local claims: { [BasePart]: Model } = setmetatable({}, { __mode = "k" }) :: any -- destroyed candy drops out

-- Escape directions to try, in order, when straight away from people runs off the map.
local FLEE_ANGLES = { 0, 45, -45, 90, -90, 135, -135 }

local function peoplePositions(): { Vector3 }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			table.insert(list, root.Position)
		end
	end
	return list
end

-- Walks along a computed path. Returns true if it arrived, false if it aborted, got stuck or had no path.
local function walkTo(humanoid: Humanoid, root: BasePart, goal: Vector3, shouldAbort: () -> boolean): boolean
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(path.ComputeAsync, path, root.Position, goal)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return false
	end

	for _, waypoint in path:GetWaypoints() do
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)

		local finished, reached = false, false
		local connection = humanoid.MoveToFinished:Once(function(r)
			finished, reached = true, r
		end)
		local started = os.clock()
		while not finished do
			if shouldAbort() or os.clock() - started > cfg.StuckTimeout or humanoid.Health <= 0 then
				connection:Disconnect()
				humanoid:MoveTo(root.Position) -- stop in place
				return false
			end
			task.wait(0.1)
		end
		if not reached then
			return false
		end
	end
	return true
end

local function flee(humanoid: Humanoid, root: BasePart, from: { Vector3 })
	local away = SafeTarget.fleeDirection(root.Position, from)
	for _, angle in FLEE_ANGLES do
		local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(away)
		local goal = MapArea.groundAt(root.Position + direction * cfg.FleeDistance)
		if goal and walkTo(humanoid, root, goal, function()
			return false -- finish the escape leg; the next loop re-checks
		end) then
			return
		end
	end
	task.wait(0.5) -- cornered: nothing walkable, try again shortly
end

local function goForCandy(bot: Model, humanoid: Humanoid, root: BasePart, people: { Vector3 }, unreachable): boolean
	local now = os.clock()
	local candy = SafeTarget.pick(CandyService.getCandies(), root.Position, people, cfg, function(c)
		local owner = claims[c]
		return (owner ~= nil and owner ~= bot and owner.Parent ~= nil) or (unreachable[c] or 0) > now
	end)
	if not candy then
		return false
	end

	claims[candy] = bot
	local arrived = walkTo(humanoid, root, candy.Position, function()
		if candy.Parent == nil then
			return true
		end
		local current = peoplePositions()
		return #SafeTarget.within(root.Position, current, cfg.FleeRadius) > 0
			or SafeTarget.nearestDistance(candy.Position, current) < cfg.SafeRadius
	end)
	if claims[candy] == bot then
		claims[candy] = nil
	end

	if candy.Parent and (root.Position - candy.Position).Magnitude <= cfg.PickupRange then
		CandyService.collect(candy, bot)
	elseif not arrived and candy.Parent then
		unreachable[candy] = os.clock() + cfg.UnreachableCooldown
	end
	return true
end

local function think(bot: Model, humanoid: Humanoid, root: BasePart)
	local unreachable = setmetatable({}, { __mode = "k" })
	while bot.Parent and humanoid.Health > 0 do
		local people = peoplePositions()
		local threats = SafeTarget.within(root.Position, people, cfg.FleeRadius)
		if #threats > 0 then
			flee(humanoid, root, threats)
		elseif not goForCandy(bot, humanoid, root, people, unreachable) then
			-- No safe candy right now: drift to the emptiest part of the map and wait there.
			if SafeTarget.nearestDistance(root.Position, people) < cfg.SafetyCap then
				flee(humanoid, root, people)
			else
				task.wait(0.5)
			end
		end
		task.wait(0.05)
	end
end

local function spawnBot(index: number)
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = "CandyBot" .. index
	model:SetAttribute("Candy", 0)
	CollectionService:AddTag(model, "CandyBot")

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = cfg.WalkSpeed
	humanoid.DisplayName = "Candy Bot " .. index

	local start = MapArea.randomPoint() or Vector3.zero
	model:PivotTo(CFrame.new(start + Vector3.new(0, 4, 0)))
	model.Parent = botFolder
	root:SetNetworkOwner(nil) -- the server simulates the bot, so its touches are trustworthy

	humanoid.Died:Connect(function()
		task.wait(cfg.RespawnDelay)
		model:Destroy()
		spawnBot(index)
	end)
	task.spawn(think, model, humanoid, root)
end

function CandyBots.start()
	botFolder = Instance.new("Folder")
	botFolder.Name = "CandyBots"
	botFolder.Parent = workspace
	for i = 1, cfg.Count do
		spawnBot(i)
	end
end

return CandyBots
