-- Story flags per player + the weekly chapter (live, evolving story).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Story = require(Shared.Config.Story)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local StoryService = {}

function StoryService.SetFlag(player: Player, flag: string)
	local profile = DataService.Get(player)
	if profile then
		profile.storyFlags[flag] = true
	end
end

function StoryService.HasFlag(player: Player, flag: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.storyFlags[flag] == true
end

function StoryService.GetChapterInfo()
	local chapter = Story.currentChapter()
	return {
		season = Story.SeasonName,
		week = Story.currentWeek(),
		title = chapter.title,
		message = chapter.solMessage,
		featuredMission = chapter.featuredMission,
		modifier = chapter.modifier,
	}
end

function StoryService.Start()
	-- Greet players with this week's SOL message the first time they see it
	local function onPlayer(player: Player)
		DataService.WaitFor(player)
		if workspace:GetAttribute("Mode") ~= "Hub" then
			return
		end
		local chapter = Story.currentChapter()
		local seenFlag = ("SeenChapter_%d"):format(chapter.week)
		if not StoryService.HasFlag(player, seenFlag) then
			StoryService.SetFlag(player, seenFlag)
			task.wait(3)
			Net.event("Notify"):FireClient(player, "SOL: " .. chapter.solMessage, "story")
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return StoryService
