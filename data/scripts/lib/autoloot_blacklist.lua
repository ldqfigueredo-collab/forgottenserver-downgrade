-- Per-player auto-loot blacklist, backed by a compact array of storage
-- keys: autoLootBlacklistCount holds how many entries exist, and slot i
-- (0-indexed) lives at autoLootBlacklistBase + i. Removal shifts later
-- entries down to keep the array packed, so lookups only ever scan
-- 0..count-1 — no gaps to handle.
AutoLootBlacklist = {}

local MAX_SLOTS = 50

function AutoLootBlacklist.getList(player)
	local count = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
	if count < 0 then count = 0 end

	local list = {}
	for i = 0, count - 1 do
		local id = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistBase + i, -1)
		if id > 0 then
			local name = ItemType(id):getName()
			-- Some items exist in items.otb (the client sprite/id registry)
			-- with no matching items.xml entry, so they have no name at all
			-- server-side. Fall back to something displayable rather than
			-- an empty string.
			if name == "" then
				name = ("Unknown Item (#%d)"):format(id)
			end
			list[#list + 1] = {id = id, name = name}
		end
	end
	return list
end

function AutoLootBlacklist.contains(player, itemId)
	local count = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
	if count < 0 then count = 0 end

	for i = 0, count - 1 do
		if player:getStorageValue(PlayerStorageKeys.autoLootBlacklistBase + i, -1) == itemId then
			return true
		end
	end
	return false
end

function AutoLootBlacklist.add(player, itemId)
	if AutoLootBlacklist.contains(player, itemId) then
		return false, "That item is already blacklisted."
	end

	local count = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
	if count < 0 then count = 0 end

	if count >= MAX_SLOTS then
		return false, ("Your blacklist is full (%d items max)."):format(MAX_SLOTS)
	end

	player:setStorageValue(PlayerStorageKeys.autoLootBlacklistBase + count, itemId)
	player:setStorageValue(PlayerStorageKeys.autoLootBlacklistCount, count + 1)
	return true
end

function AutoLootBlacklist.remove(player, itemId)
	local count = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
	if count < 0 then count = 0 end

	local found = false
	local ids = {}
	for i = 0, count - 1 do
		local id = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistBase + i, -1)
		if id == itemId then
			found = true
		else
			ids[#ids + 1] = id
		end
	end

	if not found then
		return false, "That item is not on your blacklist."
	end

	for i = 1, #ids do
		player:setStorageValue(PlayerStorageKeys.autoLootBlacklistBase + (i - 1), ids[i])
	end
	player:setStorageValue(PlayerStorageKeys.autoLootBlacklistCount, #ids)
	return true
end

function AutoLootBlacklist.clear(player)
	local count = player:getStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
	if count < 0 then count = 0 end

	for i = 0, count - 1 do
		player:setStorageValue(PlayerStorageKeys.autoLootBlacklistBase + i, -1)
	end
	player:setStorageValue(PlayerStorageKeys.autoLootBlacklistCount, 0)
end
