local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local formatEffect = Talents.formatEffect

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then return false end

	local player = Player(cid)

	if msgcontains(msg, "talent") then
		local lines = {}
		lines[#lines + 1] = ("You have %d talent point(s) available (%d spent of %d total)."):format(
			Talents.getAvailablePoints(player), Talents.getSpentPoints(player), Talents.getTotalPoints(player))

		for _, nodeId in ipairs(Talents.Order) do
			local node = Talents.Nodes[nodeId]
			local rank = Talents.getRank(player, nodeId)
			if node.requiresRoot and not Talents.isUnlocked(player, nodeId) then
				local rootNode = Talents.Nodes[node.requiresRoot]
				lines[#lines + 1] = ("%s: locked, max %s first"):format(node.name, rootNode.name)
			else
				lines[#lines + 1] = ("%s: %d/%d (%s)"):format(node.name, rank, node.maxRank, formatEffect(node, rank))
			end
		end

		lines[#lines + 1] =
			"Use !talent add/remove <talent> [amount] to spend or refund single points, !talent info <talent> for details, !talent reset to refund everything (once per day), or open the Talents window from your main panel."

		npcHandler:say(table.concat(lines, "\n"), cid)
		return true
	end

	return false
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
