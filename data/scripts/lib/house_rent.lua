-- House rent billing and delayed transfer logic. Shared by the buyhouse
-- talkaction, the !transferhouse talkaction, the HouseRentBilling
-- globalevent (data/scripts/globalevents/house_rent.lua), and the house
-- client-mod window opcode handler -- one implementation behind several
-- front-ends, same "logic first, window on top" pattern as Talents
-- (data/scripts/lib/talents.lua).
--
-- Design approved by the user before implementation (design rule 4, see
-- BUILD_NOTES.md).
HouseRent = {}
HouseTransfers = {}
HousePurchase = {}
HouseNavigation = {}

local TRANSFER_DELAY_SECONDS = 24 * 60 * 60

-- Walk-only per approved design: no cross-town travel exists on this map
-- (checked -- Captain.xml/ship.lua are never spawned, and even spawned
-- would teleport to a different, unused map's coordinates), so a house
-- farther than this is simply out of reach for now, not routed anywhere.
-- Raised 500 -> 2000 per user request; costs more pathfinding CPU per
-- click (src/map.cpp's A* search is bounded by this value in each axis,
-- src/map.cpp:744-745), but "Go" is a one-off manual action, not a hot
-- loop, so that tradeoff is fine.
local MAX_WALK_DISTANCE = 2000

local HOUSE_BUY_LEVEL_REQUIREMENT = 1
local HOUSE_BUY_REQUIRES_PREMIUM = true

local function currentRentPeriod() return Game.getRentPeriodHouse(configManager.getString(configKeys.HOUSE_RENT_PERIOD)) end

-- True if the player's bank balance can cover this house's rent right now.
-- Callers should check this BEFORE granting ownership -- never hand out a
-- house nobody can afford the first period of.
function HouseRent.canAfford(player, house) return house:getRent() <= 0 or player:getBankBalance() >= house:getRent() end

-- Buys an unowned house for player -- same checks/price/rent-charge
-- regardless of whether the purchase was triggered by standing at the
-- house's door (!buyhouse) or picked from the client-mod window's house
-- list (data/scripts/creaturescripts/house_opcode.lua), so both front-ends
-- share one implementation. Returns success, reason.
function HousePurchase.buy(player, house)
	local housePrice = configManager.getNumber(configKeys.HOUSE_PRICE)
	if housePrice == -1 then return false, "House buying is currently disabled." end

	if player:getLevel() < HOUSE_BUY_LEVEL_REQUIREMENT then
		return false, "You need level " .. HOUSE_BUY_LEVEL_REQUIREMENT .. " or higher to buy a house."
	end

	if HOUSE_BUY_REQUIRES_PREMIUM and not player:isPremium() then return false, "You need a premium account." end

	if house:getOwnerGuid() > 0 then return false, "This house already has an owner." end

	if player:getHouse() then return false, "You are already the owner of a house." end

	local price = house:getTileCount() * housePrice
	local rent = house:getRent()

	-- Checked before any money moves. Can't just check HouseRent.canAfford
	-- against the current bank balance in isolation: removeTotalMoney()
	-- below draws the price from cash first, then the bank for whatever's
	-- left -- so a bank balance that covers rent right now can still come
	-- up short for rent once the price purchase has eaten into it. Simulate
	-- that draw here so the two charges (price, then rent) are checked
	-- together against what will actually be left.
	local cash = player:getMoney()
	local bank = player:getBankBalance()
	if cash + bank < price then return false, "You do not have enough money." end

	local bankLeftAfterPrice = bank - math.max(0, price - cash)
	if rent > 0 and bankLeftAfterPrice < rent then
		return false, "You do not have enough money in your bank account to cover this house's rent."
	end

	if not player:removeTotalMoney(price) then return false, "You do not have enough money." end

	house:setOwnerGuid(player:getGuid())
	HouseRent.chargeAndExtend(player, house, os.time())
	return true
end

-- List of {id, name, rent, size} for every unowned house in the given town
-- whose name contains nameFilter (case-insensitive, plain substring -- no
-- Lua pattern chars), sorted by name. Used by the house client-mod window's
-- browse list.
--
-- Returns list, totalCount. totalCount is the filtered count (i.e. matches
-- the actual pageable set, not the town's unfiltered total) so paging stays
-- consistent with whatever's currently searched. When limit is given, list
-- is a `limit`-sized page starting at `offset` (0-based) into that filtered
-- set -- callers should show totalCount/paginate rather than let a capped
-- page look like the whole picture (see the window's Prev/Next controls).
--
-- The per-page cap exists for a hard engine reason, not just UI tidiness:
-- NetworkMessage::addString (src/networkmessage.cpp) silently drops the
-- ENTIRE string -- no length prefix, no data, nothing -- if it exceeds 8192
-- bytes, which desyncs the whole connection for every message after it
-- (the client then misreads unrelated bytes as a new message boundary).
-- Measured live: a full, uncapped house list for Thais (134 houses) serializes
-- to 8445 bytes and Edron (136 houses) to 8510 -- both over the limit --
-- while every other town was under it. A page size of 50 keeps every
-- town's payload comfortably clear of 8192 with room to spare, and is also
-- a more usable list size in a compact scrolling window than 130+ rows at
-- once -- pagination (not a bigger page) is how the rest becomes reachable.
function HousePurchase.listAvailable(townId, limit, offset, nameFilter)
	local lowerFilter = nameFilter and nameFilter ~= "" and nameFilter:lower() or nil

	local available = {}
	for _, house in ipairs(Game.getHouses()) do
		local town = house:getTown()
		if house:getOwnerGuid() == 0 and town and town:getId() == townId then
			local name = house:getName()
			if not lowerFilter or name:lower():find(lowerFilter, 1, true) then
				available[#available + 1] = {id = house:getId(), name = name, rent = house:getRent(), size = house:getTileCount()}
			end
		end
	end
	table.sort(available, function(a, b) return a.name < b.name end)

	local totalCount = #available
	if limit then
		offset = offset or 0
		local page = {}
		for i = offset + 1, math.min(offset + limit, totalCount) do page[#page + 1] = available[i] end
		available = page
	end

	return available, totalCount
end

-- Charges the first rent period immediately (no free first period like the
-- engine's own default setOwner behavior) and sets the next due date from
-- now. Caller must already have verified HouseRent.canAfford and granted
-- ownership via house:setOwnerGuid() before calling this.
function HouseRent.chargeAndExtend(player, house, currentTime)
	local rent = house:getRent()
	if rent <= 0 then return end

	local duration = Game.getRentPeriodDuration(currentRentPeriod())
	if duration <= 0 then return end

	player:setBankBalance(player:getBankBalance() - rent)
	house:setPaidUntil(currentTime + duration)
	house:setPayRentWarnings(0)
end

-- Recurring billing for one house whose rent is due. Mirrors the engine's
-- own Houses::payHouses (src/house.cpp:606-702) -- reimplemented here since
-- no payHouses binding is exposed to Lua, and the previous Lua
-- reimplementation (removed from data/lib/core/game.lua, see BUILD_NOTES.md)
-- was confirmed broken. On the 7th missed payment this hands off to
-- house:setOwnerGuid(0), which triggers the engine's own item-to-depot
-- sweep for free -- no separate sweep logic needed here.
function HouseRent.processDue(house, currentTime)
	local rent = house:getRent()
	if rent <= 0 or house:getPaidUntil() > currentTime then return end

	local town = house:getTown()
	if not town then return end

	local ownerGuid = house:getOwnerGuid()
	local player = Player(ownerGuid) or OfflinePlayer(ownerGuid)
	if not player then return end

	if player:getBankBalance() >= rent then
		player:setBankBalance(player:getBankBalance() - rent)
		house:setPaidUntil(currentTime + Game.getRentPeriodDuration(currentRentPeriod()))
		house:setPayRentWarnings(0)
	else
		local warnings = house:getPayRentWarnings()
		if warnings < 7 then
			local daysLeft = 7 - warnings
			local stampedLetter = Game.createItem(ITEM_LETTER_STAMPED, 1)
			stampedLetter:setAttribute(ITEM_ATTRIBUTE_TEXT, string.format(
				"Warning! \nThe %s rent of %d gold for your house \"%s\" is payable. Have it within %d days or you will lose this house.",
				Game.getNameRentPeriodHouse(currentRentPeriod()), rent, house:getName(), daysLeft))

			local depot = player:getDepotChest(town:getId(), true)
			depot:addItemEx(stampedLetter, INDEX_WHEREEVER, FLAG_NOLIMIT)
			house:setPayRentWarnings(warnings + 1)
		else
			house:setOwnerGuid(0)
		end
	end

	player:save()
end

-- Row shape: {fromGuid, toGuid, executesAt}, or nil if none pending.
function HouseTransfers.getPending(houseId)
	local resultId = db.storeQuery(
		"SELECT `from_guid`, `to_guid`, `executes_at` FROM `house_transfers` WHERE `house_id` = " .. houseId)
	if not resultId then return nil end

	local row = {
		fromGuid = result.getNumber(resultId, "from_guid"),
		toGuid = result.getNumber(resultId, "to_guid"),
		executesAt = result.getNumber(resultId, "executes_at")
	}
	result.free(resultId)
	return row
end

-- List of {houseId, fromGuid, executesAt} for every pending transfer where
-- playerGuid is the incoming (to_guid) owner.
function HouseTransfers.getIncoming(playerGuid)
	local incoming = {}
	local resultId = db.storeQuery(
		"SELECT `house_id`, `from_guid`, `executes_at` FROM `house_transfers` WHERE `to_guid` = " .. playerGuid)
	if resultId then
		repeat
			incoming[#incoming + 1] = {
				houseId = result.getNumber(resultId, "house_id"),
				fromGuid = result.getNumber(resultId, "from_guid"),
				executesAt = result.getNumber(resultId, "executes_at")
			}
		until not result.next(resultId)
		result.free(resultId)
	end
	return incoming
end

-- Registers a pending house transfer, finalized ~24h later by the
-- HouseRentBilling globalevent. No money changes hands and the current
-- owner keeps full normal use of the house until it finalizes -- approved
-- design, see BUILD_NOTES.md. Deliberately bypasses the native
-- house:startTrade()/trade-window mechanic (src/luahouse.cpp,
-- HouseTransferItem in src/house.cpp), which is synchronous and has no
-- delay concept: the client-mod window is the primary UI for this feature,
-- so there's no UX reason to route through the native trade item.
-- Returns success, targetPlayerOrReason.
function HouseTransfers.initiate(player, house, targetName)
	if house:getOwnerGuid() ~= player:getGuid() then return false, "You are not the owner of this house." end

	-- Cheap abuse guard: setOwnerGuid() unconditionally resets
	-- payRentWarnings to 0, so an owner in arrears could otherwise use a
	-- transfer to an alt to dodge an impending eviction in one command.
	if house:getPayRentWarnings() > 0 then
		return false, "You must clear your rent arrears before transferring this house."
	end

	if HouseTransfers.getPending(house:getId()) then
		return false, "This house already has a pending transfer."
	end

	local targetPlayer = Player(targetName)
	if not targetPlayer then return false, "Player not found." end

	if targetPlayer:getGuid() == player:getGuid() then return false, "You cannot transfer a house to yourself." end

	if targetPlayer:getHouse() then return false, "That player already owns a house." end

	local executesAt = os.time() + TRANSFER_DELAY_SECONDS
	db.query(string.format(
		"INSERT INTO `house_transfers` (`house_id`, `from_guid`, `to_guid`, `executes_at`) VALUES (%d, %d, %d, %d)",
		house:getId(), player:getGuid(), targetPlayer:getGuid(), executesAt))

	return true, targetPlayer
end

-- Only the initiating (from_guid) player may cancel. Returns success, reason.
function HouseTransfers.cancel(player, house)
	local pending = HouseTransfers.getPending(house:getId())
	if not pending then return false, "There is no pending transfer to cancel." end
	if pending.fromGuid ~= player:getGuid() then
		return false, "Only the player who initiated the transfer can cancel it."
	end

	db.query("DELETE FROM `house_transfers` WHERE `house_id` = " .. house:getId())
	return true
end

-- Finalizes every transfer whose delay has elapsed. Delete-then-act
-- ordering, each row wrapped in pcall: the row is removed before the
-- ownership flip is attempted, so a mid-processing error lapses that one
-- transfer instead of risking a double-apply on the next tick. If the
-- house's current owner no longer matches from_guid (e.g. evicted for
-- unpaid rent in the meantime), the transfer silently lapses instead of
-- transferring a house out from under its rightful current owner.
-- house:setOwnerGuid() triggers the engine's own item-to-depot sweep for
-- the outgoing owner -- no separate sweep logic needed here.
function HouseTransfers.processDue(currentTime)
	local resultId = db.storeQuery(
		"SELECT `house_id`, `from_guid`, `to_guid` FROM `house_transfers` WHERE `executes_at` <= " .. currentTime)
	if not resultId then return end

	local due = {}
	repeat
		due[#due + 1] = {
			houseId = result.getNumber(resultId, "house_id"),
			fromGuid = result.getNumber(resultId, "from_guid"),
			toGuid = result.getNumber(resultId, "to_guid")
		}
	until not result.next(resultId)
	result.free(resultId)

	for _, row in ipairs(due) do
		db.query("DELETE FROM `house_transfers` WHERE `house_id` = " .. row.houseId)

		pcall(function()
			local house = House(row.houseId)
			if house and house:getOwnerGuid() == row.fromGuid then house:setOwnerGuid(row.toGuid) end
		end)
	end
end

-- Makes player actually walk (real, speed-paced movement, not a teleport)
-- to house's door, if a path exists within MAX_WALK_DISTANCE tiles.
-- Cross-town/long-distance travel is explicitly out of scope (see the
-- MAX_WALK_DISTANCE comment) -- a house farther than this just isn't
-- reachable yet. Returns success, reason (reason only set on failure).
function HouseNavigation.walkTo(player, house)
	local path = player:getPathTo(house:getExitPosition(), 0, 1, true, true, MAX_WALK_DISTANCE)
	if not path then return false, "That house is too far away to walk to." end

	player:autoWalk(path)
	return true
end
