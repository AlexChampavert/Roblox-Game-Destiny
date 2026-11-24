-- Anti-exploit helpers:
--  * per-player, per-remote rate limiting (token bucket)
--  * server-side movement check (horizontal speed) with allowances for dashes/teleports
--  * suspicious-player log (warn + analytics + kick after many strikes)

local Players = game:GetService("Players")

local Security = {}

local KICK_AFTER_STRIKES = 40
local MOVE_CHECK_INTERVAL = 0.5

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}
local strikes: { [Player]: number } = {}
local allowUntil: { [Player]: number } = {}
local lastValid: { [Player]: CFrame } = {}

local flagHook: ((Player, string) -> ())? = nil
function Security.OnFlag(cb: (Player, string) -> ())
	flagHook = cb
end

-- Returns false if the player is sending `key` faster than `perSecond` (burst = 2x)
function Security.Allow(player: Player, key: string, perSecond: number): boolean
	local now = os.clock()
	local map = buckets[player]
	if not map then
		map = {}
		buckets[player] = map
	end
	local b = map[key]
	if not b then
		b = { tokens = perSecond * 2, last = now }
		map[key] = b
	end
	b.tokens = math.min(perSecond * 2, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Wrap a RemoteEvent handler with type-agnostic rate limiting
function Security.Guard(key: string, perSecond: number, handler: (Player, ...any) -> ()): (Player, ...any) -> ()
	return function(player: Player, ...)
		if not Security.Allow(player, key, perSecond) then
			Security.Flag(player, "rate:" .. key, 0.1)
			return
		end
		handler(player, ...)
	end
end

function Security.Flag(player: Player, reason: string, weight: number?)
	strikes[player] = (strikes[player] or 0) + (weight or 1)
	if (weight or 1) >= 1 then
		warn(("[Security] %s flagged: %s (strikes %.1f)"):format(player.Name, reason, strikes[player]))
	end
	if flagHook then
		flagHook(player, reason)
	end
	if strikes[player] >= KICK_AFTER_STRIKES then
		player:Kick("Connection issue detected. Please rejoin.")
	end
end

-- Call before the server (or a server-approved ability) moves a player fast
function Security.AllowMovement(player: Player, seconds: number)
	allowUntil[player] = math.max(allowUntil[player] or 0, os.clock() + seconds)
end

function Security.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			Security.AllowMovement(player, 3)
			lastValid[player] = nil
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		strikes[player] = nil
		allowUntil[player] = nil
		lastValid[player] = nil
	end)

	-- Decay strikes slowly so honest lag spikes don't add up
	task.spawn(function()
		while true do
			task.wait(30)
			for p, s in strikes do
				strikes[p] = math.max(0, s - 3)
			end
		end
	end)

	-- Movement check
	task.spawn(function()
		while true do
			task.wait(MOVE_CHECK_INTERVAL)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and root and hum.Health > 0 then
					local prev = lastValid[player]
					if prev and now > (allowUntil[player] or 0) then
						local delta = root.Position - prev.Position
						local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
						local maxDist = (hum.WalkSpeed * 1.4 + 10) * MOVE_CHECK_INTERVAL
						if horizontal > maxDist then
							Security.Flag(player, ("speed %.0f studs/s"):format(horizontal / MOVE_CHECK_INTERVAL), 1)
							char:PivotTo(prev) -- rubber-band
							continue
						end
					end
					lastValid[player] = root.CFrame
				end
			end
		end
	end)
end

return Security
