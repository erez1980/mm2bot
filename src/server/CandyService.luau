-- Spawns candy, decides who gets it (server-authoritative), and saves each player's total.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiCheat = require(script.Parent.AntiCheat)
local MapArea = require(script.Parent.MapArea)

local cfg = Config.Candy
local store = DataStoreService:GetDataStore(cfg.DataStoreName)

local CandyService = {}

local candyFolder: Folder
local loaded: { [Player]: boolean } = {} -- only players whose data loaded are saved, so a failed load never wipes a save

function CandyService.getCandies(): { BasePart }
	return candyFolder:GetChildren() :: { BasePart }
end

local function candyStat(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Candy") :: IntValue?
end

-- collector is a Player or a bot Model (tagged "CandyBot"). Returns true if the candy was taken.
function CandyService.collect(candy: BasePart, collector: Player | Model): boolean
	if candy.Parent ~= candyFolder or candy:GetAttribute("Taken") then
		return false
	end
	candy:SetAttribute("Taken", true)
	candy:Destroy()
	if typeof(collector) == "Instance" and collector:IsA("Player") then
		local stat = candyStat(collector)
		if stat then
			stat.Value += cfg.Value
		end
	else
		collector:SetAttribute("Candy", (collector:GetAttribute("Candy") or 0) + cfg.Value)
	end
	return true
end

local function onTouched(candy: BasePart, hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		if AntiCheat.canPickup(player, candy) then
			CandyService.collect(candy, player)
		end
	elseif CollectionService:HasTag(character, "CandyBot") then
		CandyService.collect(candy, character :: Model)
	end
end

local function tooCloseToOtherCandy(position: Vector3): boolean
	for _, other in candyFolder:GetChildren() do
		if (other.Position - position).Magnitude < cfg.MinSpacing then
			return true
		end
	end
	return false
end

local function spawnCandy()
	local ground = MapArea.randomPoint()
	if not ground then
		return
	end
	local position = ground + Vector3.new(0, 1.5, 0)
	if tooCloseToOtherCandy(position) then
		return
	end

	local candy = Instance.new("Part")
	candy.Name = "Candy"
	candy.Shape = Enum.PartType.Ball
	candy.Size = Vector3.new(1.5, 1.5, 1.5)
	candy.Color = Color3.fromRGB(255, 140, 0)
	candy.Material = Enum.Material.Neon
	candy.Anchored = true
	candy.CanCollide = false
	candy.Position = position
	candy.Touched:Connect(function(hit)
		onTouched(candy, hit)
	end)
	candy.Parent = candyFolder

	task.delay(cfg.Lifetime, function()
		if candy.Parent then
			candy:Destroy()
		end
	end)
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function onPlayerAdded(player: Player)
	-- Reuse the game's own leaderstats if it already made one; two folders would break the leaderboard.
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local candy = Instance.new("IntValue")
	candy.Name = "Candy"
	candy.Parent = stats

	local ok, saved = pcall(store.GetAsync, store, key(player))
	if ok then
		candy.Value = saved or 0
		loaded[player] = true
	else
		warn("[CandyService] Could not load data for " .. player.Name .. ": " .. tostring(saved))
	end
end

local function save(player: Player)
	local stat = candyStat(player)
	if not loaded[player] or not stat then
		return
	end
	local ok, err = pcall(store.SetAsync, store, key(player), stat.Value)
	if not ok then
		warn("[CandyService] Could not save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function CandyService.start()
	candyFolder = Instance.new("Folder")
	candyFolder.Name = "Candy"
	candyFolder.Parent = workspace

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			if #candyFolder:GetChildren() < cfg.MaxOnMap then
				spawnCandy()
			end
			task.wait(cfg.SpawnInterval)
		end
	end)
end

return CandyService
