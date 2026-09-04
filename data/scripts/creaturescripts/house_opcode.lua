-- Handles the client<->server house-window protocol over extended opcode
-- 11. Opcode chosen following the exact precedent of talent_opcode.lua
-- (data/scripts/creaturescripts/talent_opcode.lua) -- confirmed unused via
-- grep across ~/otclient/modules and ~/otclient/mods before picking it (0/2
-- are client-reserved and hardcoded in C++, 1/5/10/201 are already claimed
-- by this server's own features).
--
-- Protocol (JSON string payload):
--   client -> server: {"action":<action>,"town":<id, optional>,"page":<n, optional>,
--                       "filter":<s, optional>, ...action-specific fields}
--                      actions: "get", "pay_rent", "cancel_transfer",
--                      "transfer" (+ "target":"<player name>"),
--                      "buy_house" (+ "houseId":<id>),
--                      "go_to_house" (+ "houseId":<id>) -- walk-only: queues
--                        real movement toward the door if within 2000 tiles
--                        (HouseNavigation.walkTo, data/scripts/lib/house_rent.lua);
--                        no cross-town travel exists on this map, so a
--                        farther house just replies with a "too far"
--                        message and no movement.
--                      "town"/"page"/"filter" are echoed/applied on every
--                      action, not just "get", since every reply carries the
--                      current browse-list state regardless of what
--                      triggered it. "filter" is a case-insensitive plain
--                      substring match against house names (no Lua pattern
--                      chars), applied server-side before pagination so
--                      totalCount/housePageCount reflect the filtered set.
--   server -> client: always the full authoritative state, sent after every
--                      action (including malformed/unrecognized ones):
--     {
--       "hasHouse": <bool>,
--       "house": {"name": <s>, "rent": <n>, "rentDueIn": <seconds, negative if overdue>,
--                 "warnings": <n>,
--                 "pendingTransfer": {"toName": <s>, "transferIn": <seconds>} or null},
--       "incomingTransfers": [{"houseName": <s>, "fromName": <s>, "transferIn": <seconds>}, ...],
--       "towns": [{"id": <n>, "name": <s>}, ...],
--       "selectedTown": <id>,  -- echoes back the resolved town (request's
--                                  "town", or the player's own town if
--                                  omitted/invalid)
--       "houses": [{"id": <n>, "name": <s>, "rent": <n>, "size": <n>}, ...],
--                 -- up to 50 unowned houses in selectedTown, sorted by name
--                 -- (one page -- see "housePage"/"housePageCount" below)
--       "housesTotal": <n>,  -- true unowned count in selectedTown, which
--                                may exceed the 50 actually listed
--       "housePage": <n>,  -- 0-based, echoes back the resolved/clamped page
--       "housePageCount": <n>,  -- total pages for selectedTown, always >= 1
--       "message": <s or null>  -- result/error of the last action, if any
--     }
--   Countdowns are sent as seconds-remaining (server-computed), not absolute
--   timestamps, so the client never needs to reason about clock skew --
--   same convention as the talent tree's resetCooldownRemaining. The client
--   is expected to echo back the "town"/"page" it last selected on every
--   request (defaulting to the player's own town and page 0 on first load)
--   so every reply can include a freshly-filtered, correctly-paged "houses"
--   list without a separate round trip.
--
--   The "houses" list is capped at 50 per page for a hard protocol reason,
--   not just UI tidiness: NetworkMessage::addString (src/networkmessage.cpp)
--   silently drops the ENTIRE payload -- no length prefix, no data -- if it
--   exceeds 8192 bytes, desyncing the whole connection for every message
--   after it. Measured live: an uncapped list for Thais (134 houses)
--   serialized to 8445 bytes and Edron (136) to 8510, both over the limit --
--   this is what caused the very first "get" reply after login to corrupt
--   the connection. Pagination (not a bigger page) is how the rest of a big
--   town's houses become reachable -- see HousePurchase.listAvailable
--   (data/scripts/lib/house_rent.lua).
--
-- Actual rent/purchase/transfer logic lives in HouseRent/HousePurchase/
-- HouseTransfers (data/scripts/lib/house_rent.lua), shared with the
-- !buyhouse/!transferhouse talkactions and the recurring HouseRentBilling
-- globalevent so no front-end can drift from another.
local json = dofile('data/lib/json.lua')

local OPCODE_HOUSE = 11

local function resolveTown(player, requestedTown)
	if requestedTown then
		for _, town in ipairs(Game.getTowns()) do
			if town:getId() == requestedTown then return requestedTown end
		end
	end

	local playerTown = player:getTown()
	return playerTown and playerTown:getId() or 0
end

local HOUSES_PER_PAGE = 50

local function buildState(player, requestedTown, requestedPage, nameFilter, message)
	local currentTime = os.time()
	local house = player:getHouse()
	local houseData = nil
	if house then
		local pendingData = nil
		local pending = HouseTransfers.getPending(house:getId())
		if pending then
			local toPlayer = Player(pending.toGuid) or OfflinePlayer(pending.toGuid)
			pendingData = {
				toName = toPlayer and toPlayer:getName() or "unknown",
				transferIn = pending.executesAt - currentTime
			}
		end

		houseData = {
			name = house:getName(),
			rent = house:getRent(),
			rentDueIn = house:getPaidUntil() - currentTime,
			warnings = house:getPayRentWarnings(),
			pendingTransfer = pendingData
		}
	end

	local incoming = {}
	for _, row in ipairs(HouseTransfers.getIncoming(player:getGuid())) do
		local fromPlayer = Player(row.fromGuid) or OfflinePlayer(row.fromGuid)
		local incomingHouse = House(row.houseId)
		incoming[#incoming + 1] = {
			houseName = incomingHouse and incomingHouse:getName() or "unknown",
			fromName = fromPlayer and fromPlayer:getName() or "unknown",
			transferIn = row.executesAt - currentTime
		}
	end

	local towns = {}
	for _, town in ipairs(Game.getTowns()) do towns[#towns + 1] = {id = town:getId(), name = town:getName()} end
	table.sort(towns, function(a, b) return a.name < b.name end)

	local townId = resolveTown(player, requestedTown)

	-- Page size capped at 50 -- see the comment on HousePurchase.listAvailable
	-- (data/scripts/lib/house_rent.lua) for why this isn't optional: an
	-- uncapped list for a big town silently corrupts the whole connection
	-- (NetworkMessage::addString's 8192-byte hard limit). A "page" (not a
	-- bigger page) is how the rest of a big town's houses become reachable.
	-- One unpaginated scan gets both the filtered list and its totalCount;
	-- the page is sliced from that in Lua below instead of re-scanning
	-- Game.getHouses() a second time just to apply the offset/limit.
	local available, totalCount = HousePurchase.listAvailable(townId, nil, nil, nameFilter)
	local pageCount = math.max(1, math.ceil(totalCount / HOUSES_PER_PAGE))
	local page = requestedPage or 0
	if page < 0 then
		page = 0
	elseif page >= pageCount then
		page = pageCount - 1
	end

	local offset = page * HOUSES_PER_PAGE
	local houses = {}
	for i = offset + 1, math.min(offset + HOUSES_PER_PAGE, totalCount) do houses[#houses + 1] = available[i] end

	return {
		hasHouse = house ~= nil,
		house = houseData,
		incomingTransfers = incoming,
		towns = towns,
		selectedTown = townId,
		houses = houses,
		housesTotal = totalCount,
		housePage = page,
		housePageCount = pageCount,
		message = message
	}
end

local function sendState(player, requestedTown, requestedPage, nameFilter, message)
	player:sendExtendedOpcode(OPCODE_HOUSE,
		json.encode(buildState(player, requestedTown, requestedPage, nameFilter, message)))
end

local opcodeEvent = CreatureEvent("HouseOpcode")

function opcodeEvent.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE_HOUSE then return end

	local ok, data = pcall(json.decode, buffer)
	local message = nil
	local requestedTown = nil
	local requestedPage = nil
	local nameFilter = nil
	if ok and type(data) == "table" then
		requestedTown = tonumber(data.town)
		requestedPage = tonumber(data.page)
		if type(data.filter) == "string" then nameFilter = data.filter end

		if type(data.action) == "string" then
			local house = player:getHouse()
			if data.action == "pay_rent" then
				if not house then
					message = "You do not own a house."
				elseif not HouseRent.canAfford(player, house) then
					message = "You do not have enough money in your bank account."
				else
					HouseRent.chargeAndExtend(player, house, os.time())
					message = "Rent paid."
				end
			elseif data.action == "transfer" and type(data.target) == "string" then
				if not house then
					message = "You do not own a house."
				else
					local success, reason = HouseTransfers.initiate(player, house, data.target)
					message = success and "Transfer started." or reason
				end
			elseif data.action == "cancel_transfer" then
				if not house then
					message = "You do not own a house."
				else
					local success, reason = HouseTransfers.cancel(player, house)
					message = success and "Transfer cancelled." or reason
				end
			elseif data.action == "buy_house" and tonumber(data.houseId) then
				local targetHouse = House(tonumber(data.houseId))
				if not targetHouse then
					message = "That house no longer exists."
				else
					local success, reason = HousePurchase.buy(player, targetHouse)
					message = success and "House purchased." or reason
				end
			elseif data.action == "go_to_house" and tonumber(data.houseId) then
				local targetHouse = House(tonumber(data.houseId))
				if not targetHouse then
					message = "That house no longer exists."
				else
					local success, reason = HouseNavigation.walkTo(player, targetHouse)
					message = success and nil or reason
				end
			end
		end
		-- "get" (or anything else recognized/unrecognized) just falls
		-- through to the resend below.
	end

	sendState(player, requestedTown, requestedPage, nameFilter, message)
end

opcodeEvent:register()
