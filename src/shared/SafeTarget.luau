-- Pure decision logic for the bots: which candy is worth taking, and which way is "away from people".
-- No services and no side effects, so it is easy to read and reason about on its own.
local SafeTarget = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Horizontal distance from position to the closest of others (math.huge when there is nobody).
function SafeTarget.nearestDistance(position: Vector3, others: { Vector3 }): number
	local best = math.huge
	for _, other in others do
		local d = flat(other - position).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

function SafeTarget.within(position: Vector3, others: { Vector3 }, radius: number): { Vector3 }
	local result = {}
	for _, other in others do
		if flat(other - position).Magnitude <= radius then
			table.insert(result, other)
		end
	end
	return result
end

-- Higher is better; nil means the candy is too close to someone.
-- Score = how empty the area around the candy is, minus a cost for how far the bot has to walk.
function SafeTarget.score(candyPos: Vector3, botPos: Vector3, people: { Vector3 }, cfg): number?
	local away = SafeTarget.nearestDistance(candyPos, people)
	if away < cfg.SafeRadius then
		return nil
	end
	local safety = math.min(away, cfg.SafetyCap)
	return safety - cfg.DistanceWeight * flat(candyPos - botPos).Magnitude
end

-- isSkipped(candy) lets the caller exclude candies claimed by another bot or recently unreachable.
function SafeTarget.pick(candies: { BasePart }, botPos: Vector3, people: { Vector3 }, cfg, isSkipped): BasePart?
	local bestCandy, bestScore = nil, -math.huge
	for _, candy in candies do
		if not isSkipped(candy) then
			local s = SafeTarget.score(candy.Position, botPos, people, cfg)
			if s and s > bestScore then
				bestCandy, bestScore = candy, s
			end
		end
	end
	return bestCandy
end

-- Unit vector pointing away from people; closer people push harder (1/distance).
function SafeTarget.fleeDirection(botPos: Vector3, people: { Vector3 }): Vector3
	local push = Vector3.zero
	for _, person in people do
		local offset = flat(botPos - person)
		local d = offset.Magnitude
		if d > 0.01 then
			push += offset.Unit / d
		end
	end
	if push.Magnitude < 1e-6 then
		local angle = math.random() * 2 * math.pi
		return Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	return push.Unit
end

return SafeTarget
