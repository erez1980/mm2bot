-- Finds standable ground: random spawn points for candy and bots, and "is there floor here?" for escape routes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapArea = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true -- see through invisible zones and triggers you can walk through

local function refreshFilter()
	local ignore = {}
	for _, name in { "Candy", "CandyBots", "CandySpawns" } do
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

-- Floor point below position, or nil if there is no floor (off the map).
-- The ray starts castHeight above position (default 100); keep it small indoors so it starts under the roof.
function MapArea.groundAt(position: Vector3, castHeight: number?): Vector3?
	refreshFilter()
	local height = castHeight or 100
	local origin = position + Vector3.new(0, height, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -(height + 200), 0), params)
	return hit and hit.Position
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
		local center, size, castHeight
		if #parts > 0 then
			-- Cast from the top of the zone part, so a roof above the zone is never hit.
			local part = parts[math.random(#parts)]
			center, size, castHeight = part.Position, part.Size, part.Size.Y / 2
		else
			center, size = Config.Candy.Area.Center, Config.Candy.Area.Size
		end
		local candidate = center + Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)
		local ground = MapArea.groundAt(candidate, castHeight)
		if ground then
			return ground
		end
	end
	return nil
end

return MapArea
