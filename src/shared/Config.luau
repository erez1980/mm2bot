-- All tunable numbers in one place. Distances are in studs, times in seconds.
return {
	Candy = {
		MaxOnMap = 40,
		SpawnInterval = 1.5,
		Lifetime = 60, -- uncollected candy disappears after this
		Value = 1,
		MinSpacing = 4, -- no two candies closer than this
		-- Used only when the place has no workspace.CandySpawns folder.
		Area = {
			Center = Vector3.new(0, 0, 0),
			Size = Vector3.new(180, 0, 180),
		},
		DataStoreName = "CandyLab_v1",
	},

	Bots = {
		Count = 3,
		WalkSpeed = 16,
		SafeRadius = 30, -- candy closer than this to a player is ignored
		FleeRadius = 20, -- a player closer than this makes the bot run
		FleeDistance = 35, -- length of one escape leg
		DistanceWeight = 0.5, -- how much the bot prefers near candy over far-from-people candy
		SafetyCap = 90, -- beyond this distance from people, extra distance stops adding score
		PickupRange = 4,
		StuckTimeout = 3, -- give up a waypoint after this long
		UnreachableCooldown = 10, -- skip a candy we failed to reach for this long
		RespawnDelay = 3,
	},

	AntiCheat = {
		MaxPickupDistance = 10, -- root part to candy, checked on the server
		MinPickupInterval = 0.15,
		MaxHorizontalSpeed = 40, -- default WalkSpeed is 16; leave headroom for lag
		SampleInterval = 0.5,
		SuspendSeconds = 5, -- pickups are ignored for this long after a strike
		KickAtStrikes = nil, -- set a number (e.g. 10) to kick; nil only logs
	},
}
