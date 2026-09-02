-- Handles the client<->server loot-blacklist protocol over extended opcode
-- 5 (opcode 1 is already used by the existing language handler in
-- data/creaturescripts/scripts/extendedopcode.lua — both fire independently,
-- see Game::parsePlayerExtendedOpcode, no conflict). This is a separate
-- revscript CreatureEvent rather than editing that legacy file, so it has
-- access to AutoLootBlacklist (data/scripts/lib/), which a legacy
-- creaturescript would not.
--
-- NOTE: opcode was originally 2, changed to 5 after discovering the
-- mehah/otclient client build (~/otclient, the one actually in use — see
-- BUILD_NOTES.md "Client mismatch" entry) hardcodes sub-opcode 2 at the C++
-- level for its own internal extended-ping-back mechanism
-- (ProtocolGame::parseExtendedOpcode, protocolgameparse.cpp:3808): any
-- incoming message on opcode 2 is routed straight to parsePingBack() and
-- NEVER reaches the Lua onExtendedOpcode callback chain, no matter what's
-- registered client-side. This silently broke every server->client reply
-- (window always empty) and also corrupted the client's real ping timing
-- (our JSON getting fed to the ping-back parser), which is what caused the
-- recurring "Got an invalid ping from server" client log errors. The old
-- OTCv8 fork (~/otclientv8) only reserves opcode 0, so opcode 2 was safe
-- there — this collision is specific to the newer fork. 5 is clear of both
-- forks' reserved opcodes (0, 2) and this project's other custom protocol
-- (opcode 1, language).
--
-- Protocol (JSON string payload):
--   client -> server: {"action":"get"}
--                      {"action":"add","id":<CLIENT itemid>}
--                      {"action":"remove","id":<CLIENT itemid>}
--                      {"action":"remove_many","ids":[<CLIENT itemid>, ...]}
--                      {"action":"clear"}
--   server -> client: {"items":[{"id":<CLIENT itemid>,"name":<string>}, ...]}
--                      (always the current authoritative list, sent after
--                      every action)
--
-- IMPORTANT: the wire protocol uses CLIENT (sprite) ids throughout, since
-- that's the only id space the client ever knows about — item:getId() on
-- the client side returns a client id, not a server id. AutoLootBlacklist
-- itself (Stage 1) is keyed by SERVER ids internally, to match what
-- item:getId() returns on real server-side Item objects during loot
-- generation (default_onDropLoot.lua). This handler converts at the
-- boundary: Game.getItemTypeByClientId() going in, ItemType:getClientId()
-- going out.
local json = dofile('data/lib/json.lua')

local OPCODE_LOOT_BLACKLIST = 5

local function sendBlacklist(player)
	local serverList = AutoLootBlacklist.getList(player)

	local clientList = {}
	for i = 1, #serverList do
		local entry = serverList[i]
		local clientId = ItemType(entry.id):getClientId()
		if clientId and clientId > 0 then
			clientList[#clientList + 1] = {id = clientId, name = entry.name}
		end
	end

	player:sendExtendedOpcode(OPCODE_LOOT_BLACKLIST, json.encode({items = clientList}))
end

local opcodeEvent = CreatureEvent("LootBlacklistOpcode")

function opcodeEvent.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE_LOOT_BLACKLIST then
		return
	end

	local ok, data = pcall(json.decode, buffer)
	if not ok or type(data) ~= "table" or type(data.action) ~= "string" then
		return
	end

	if data.action == "add" or data.action == "remove" then
		if type(data.id) == "number" then
			local itemType = Game.getItemTypeByClientId(data.id)
			if itemType and itemType:getId() ~= 0 then
				if data.action == "add" then
					AutoLootBlacklist.add(player, itemType:getId())
				else
					AutoLootBlacklist.remove(player, itemType:getId())
				end
			end
		end
	elseif data.action == "remove_many" then
		if type(data.ids) == "table" then
			for i = 1, #data.ids do
				local clientId = data.ids[i]
				if type(clientId) == "number" then
					local itemType = Game.getItemTypeByClientId(clientId)
					if itemType and itemType:getId() ~= 0 then
						AutoLootBlacklist.remove(player, itemType:getId())
					end
				end
			end
		end
	elseif data.action == "clear" then
		AutoLootBlacklist.clear(player)
	end
	-- "get" (or anything else recognized/unrecognized) just falls through
	-- to the resend below.

	sendBlacklist(player)
end

opcodeEvent:register()
