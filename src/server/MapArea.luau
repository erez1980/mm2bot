-- Finds standable ground: random spawn points for candy and bots, and "is there floor here?" for escape routes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapArea = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function refreshFilter()
	local ignore = {}
	for _, name in { "Candy", "CandyBots" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
end

-- Point on the floor below (or above) position, or nil if there is no floor (off the map).
function MapArea.groundAt(position: Vector3): Vector3?
	refreshFilter()
	local origin = Vector3.new(position.X, position.Y + 100, position.Z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -300, 0), params)
	if hit and hit.Instance.CanCollide then
		return hit.Position
	end
	return nil
end

local function spawnParts(): { BasePart }
	local parts = {}
	local folder = workspace:FindFirstChild("CandySpawns")
	if folder then
		for _, child in folder:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
	end
	return parts
end

-- Random floor point: inside a random part of workspace.CandySpawns if it exists, otherwise in Config.Candy.Area.
function MapArea.randomPoint(): Vector3?
	local parts = spawnParts()
	for _ = 1, 10 do
		local center, size
		if #parts > 0 then
			local part = parts[math.random(#parts)]
			center, size = part.Position, part.Size
		else
			center, size = Config.Candy.Area.Center, Config.Candy.Area.Size
		end
		local candidate = center + Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)
		local ground = MapArea.groundAt(candidate)
		if ground then
			return ground
		end
	end
	return nil
end

return MapArea
