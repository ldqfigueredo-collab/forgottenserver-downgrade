-- Outfit unlock shop config, shared by the Outfitter NPC
-- (data/npc/scripts/Outfitter.lua) and the vocation-lock creaturescript
-- (data/scripts/creaturescripts/outfit_vocation_lock.lua). Currency is Task
-- Points (PlayerStorageKeys.taskPoints, see data/npc/scripts/Task Master.lua)
-- plus gold — both pure sinks, no new faucet.
--
-- Only append entries or adjust cost/level here; never repurpose a lookType
-- for a different outfit, since a player's ownership is keyed by lookType in
-- the engine's own outfit list (Player::addOutfit).
OutfitVocationGroups = {
	knight = {name = "Knight", ids = {4, 8}},
	paladin = {name = "Paladin", ids = {3, 7}},
	sorcerer = {name = "Sorcerer", ids = {1, 5}},
	druid = {name = "Druid", ids = {2, 6}},
	assassin = {name = "Assassin", ids = {9, 10}}
}

local UNIVERSAL_COST = {base = {tp = 15, gold = 8000}, addon = {tp = 5, gold = 5000}}
local VOCATION_COST = {base = {tp = 30, gold = 20000}, addon = {tp = 12, gold = 10000}}

OutfitUnlocks = {
	-- Universal flavor outfits — any vocation, no combat identity
	{name = "Pirate", maleLookType = 151, femaleLookType = 155, minLevel = 20, cost = UNIVERSAL_COST},
	{name = "Beggar", maleLookType = 153, femaleLookType = 157, minLevel = 20, cost = UNIVERSAL_COST},
	{name = "Jester", maleLookType = 273, femaleLookType = 270, minLevel = 20, cost = UNIVERSAL_COST},

	-- Knight exclusives
	{
		name = "Brotherhood",
		maleLookType = 278,
		femaleLookType = 279,
		minLevel = 50,
		vocationGroup = "knight",
		cost = VOCATION_COST
	}, {
		name = "Warmaster",
		maleLookType = 335,
		femaleLookType = 336,
		minLevel = 50,
		vocationGroup = "knight",
		cost = VOCATION_COST
	},

	-- Paladin exclusives
	{
		name = "Demon Hunter",
		maleLookType = 289,
		femaleLookType = 288,
		minLevel = 50,
		vocationGroup = "paladin",
		cost = VOCATION_COST
	}, {
		name = "Wayfarer",
		maleLookType = 367,
		femaleLookType = 366,
		minLevel = 50,
		vocationGroup = "paladin",
		cost = VOCATION_COST
	},

	-- Sorcerer exclusives
	{
		name = "Nightmare",
		maleLookType = 268,
		femaleLookType = 269,
		minLevel = 50,
		vocationGroup = "sorcerer",
		cost = VOCATION_COST
	}, {
		name = "Yalaharian",
		maleLookType = 325,
		femaleLookType = 324,
		minLevel = 50,
		vocationGroup = "sorcerer",
		cost = VOCATION_COST
	},

	-- Druid exclusives
	{
		name = "Shaman",
		maleLookType = 154,
		femaleLookType = 158,
		minLevel = 50,
		vocationGroup = "druid",
		cost = VOCATION_COST
	}, {
		name = "Norseman",
		maleLookType = 251,
		femaleLookType = 252,
		minLevel = 50,
		vocationGroup = "druid",
		cost = VOCATION_COST
	},

	-- Assassin/Nightblade exclusive
	{
		name = "Assassin",
		maleLookType = 152,
		femaleLookType = 156,
		minLevel = 50,
		vocationGroup = "assassin",
		cost = VOCATION_COST
	}
}

-- lookType -> unlock entry, for O(1) lookup from the vocation-lock hook
OutfitUnlocksByLookType = {}
for _, unlock in ipairs(OutfitUnlocks) do
	OutfitUnlocksByLookType[unlock.maleLookType] = unlock
	OutfitUnlocksByLookType[unlock.femaleLookType] = unlock
end
