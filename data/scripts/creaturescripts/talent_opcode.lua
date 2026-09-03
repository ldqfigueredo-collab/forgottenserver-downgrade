-- Handles the client<->server talent-tree protocol over extended opcode 10.
--
-- Opcode chosen deliberately outside this client's low reserved range:
-- ~/otclient's ExtendedIds (modules/gamelib/const.lua) names opcodes 0-7 for
-- built-in client features -- 0 (Activate) and 2 (Ping) are hardcoded at the
-- C++ level (ProtocolGame::parseExtendedOpcode, protocolgameparse.cpp:3808)
-- and never reach a Lua handler at all, which is exactly what silently broke
-- the loot-blacklist feature's first attempt at opcode 2 (see
-- data/scripts/creaturescripts/loot_blacklist_opcode.lua, now on opcode 5).
-- 1 (Locale) is used by this server's own language handler
-- (data/creaturescripts/scripts/extendedopcode.lua) and 5 is now claimed by
-- loot blacklist; 3/4/6/7 are named-but-currently-unwired client features
-- that could get implemented later. 10 sits clear of all of that and of
-- GAME_SHOP_CODE (201, ~/otclient/modules/game_shop/game_shop.lua) --
-- confirmed via grep across ~/otclient/modules and this repo's own opcode
-- handlers before picking it.
--
-- Protocol (JSON string payload):
--   client -> server: {"action":"get"}
--                      {"action":"add","node":<node id>,"amount":<n>}
--                      {"action":"remove","node":<node id>,"amount":<n>}
--                      {"action":"reset"}
--   server -> client: always the full authoritative state, sent after every
--                      action (including malformed/unrecognized ones):
--     {
--       "level": <n>, "totalPoints": <n>, "availablePoints": <n>,
--       "spentPoints": <n>, "resetCooldownRemaining": <seconds, 0 if ready>,
--       "nodes": [
--         {"id": "root_combat", "name": "Combat Instinct", "rank": <n>,
--          "maxRank": 5, "unlocked": true, "requiresRoot": <id or absent>,
--          "effectAtCurrent": "<string>", "effectAtMax": "<string>"},
--         ... one entry per Talents.Order, in that order ...
--       ]
--     }
--
-- Node ids are the same strings Talents.Nodes/Talents.Order already use
-- (e.g. "physical_mastery") -- no separate client-facing id scheme needed,
-- unlike the loot blacklist's client-id/server-id item conversion, since
-- talent nodes aren't sprites with two id spaces.
local json = dofile('data/lib/json.lua')

local OPCODE_TALENTS = 10

local function buildState(player)
	local nodes = {}
	for _, nodeId in ipairs(Talents.Order) do
		local node = Talents.Nodes[nodeId]
		local rank = Talents.getRank(player, nodeId)
		nodes[#nodes + 1] = {
			id = nodeId,
			name = node.name,
			rank = rank,
			maxRank = node.maxRank,
			unlocked = Talents.isUnlocked(player, nodeId),
			requiresRoot = node.requiresRoot,
			effectAtCurrent = Talents.formatEffect(node, rank),
			effectAtMax = Talents.formatEffect(node, node.maxRank)
		}
	end

	return {
		level = player:getLevel(),
		totalPoints = Talents.getTotalPoints(player),
		availablePoints = Talents.getAvailablePoints(player),
		spentPoints = Talents.getSpentPoints(player),
		resetCooldownRemaining = Talents.getResetCooldownRemaining(player),
		nodes = nodes
	}
end

local function sendState(player) player:sendExtendedOpcode(OPCODE_TALENTS, json.encode(buildState(player))) end

local opcodeEvent = CreatureEvent("TalentOpcode")

function opcodeEvent.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE_TALENTS then return end

	local ok, data = pcall(json.decode, buffer)
	if ok and type(data) == "table" and type(data.action) == "string" then
		local amount = tonumber(data.amount) or 1
		if data.action == "add" and type(data.node) == "string" then
			Talents.addRank(player, data.node, amount)
		elseif data.action == "remove" and type(data.node) == "string" then
			Talents.removeRank(player, data.node, amount)
		elseif data.action == "reset" then
			Talents.reset(player)
		end
		-- "get" (or anything else recognized/unrecognized) just falls
		-- through to the resend below.
	end

	sendState(player)
end

opcodeEvent:register()
