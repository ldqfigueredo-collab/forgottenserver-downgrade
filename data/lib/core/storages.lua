--[[
Reserved storage ranges:
- 300000 to 301000+ reserved for achievements
- 20000 to 21000+ reserved for achievement progress
- 10000000 to 20000000 reserved for outfits and mounts on source
]] --
PlayerStorageKeys = {
	annihilatorReward = 30015,
	promotion = 30018,
	delayLargeSeaShell = 30019,
	firstRod = 30020,
	delayWallMirror = 30021,
	madSheepSummon = 30023,
	crateUsable = 30024,
	achievementsBase = 300000,
	achievementsCounter = 20000,

	-- Task system (reserved block 40000-49999, see BUILD_NOTES.md)
	taskCurrentId = 42000,
	taskCurrentProgress = 42001,
	taskPoints = 42002,

	-- Player preferences/UI toggles (reserved block 45900-45999, see BUILD_NOTES.md)
	autoLootEnabled = 45900,

	-- Auto-loot blacklist: count + up to 50 slots at (autoLootBlacklistBase + i),
	-- i = 0..49, reserving 45901-45951 within the same block
	autoLootBlacklistCount = 45901,
	autoLootBlacklistBase = 45902,

	-- Talent tree (reserved block 40000-49999, see BUILD_NOTES.md): per-node
	-- spent rank + last-respec timestamp. Available points are derived live
	-- from player level, not stored.
	talentRootCombat = 40000,
	talentRootVital = 40001,
	talentRootKiller = 40002,
	talentPhysicalMastery = 40003,
	talentArcaneMastery = 40004,
	talentFortitude = 40005,
	talentManaWell = 40006,
	talentLethality = 40007,
	talentVampirism = 40008,
	talentLastReset = 40009
}

GlobalStorageKeys = {}

-- Check duplicates player storage keys
do
	local duplicates = {}
	for name, id in pairs(PlayerStorageKeys) do
		if duplicates[id] then error("Duplicate keyStorage: " .. id) end
		duplicates[id] = name
	end

	local __index = function(self, key)
		local keyStorage = PlayerStorageKeys[key]
		if not keyStorage then debugPrint("Invalid keyStorage: " .. key) end
		return keyStorage
	end

	setmetatable(PlayerStorageKeys, {__index = __index})
end

-- Check duplicates global storage keys
do
	local duplicates = {}
	for name, id in pairs(GlobalStorageKeys) do
		if duplicates[id] then error("Duplicate keyStorage: " .. id) end
		duplicates[id] = name
	end

	local __index = function(self, key)
		local keyStorage = GlobalStorageKeys[key]
		if not keyStorage then debugPrint("Invalid keyStorage: " .. key) end
		return keyStorage
	end

	setmetatable(GlobalStorageKeys, {__index = __index})
end
