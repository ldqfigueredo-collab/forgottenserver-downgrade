local talk = TalkAction("!talent")

local formatEffect = Talents.formatEffect

local function sendSummary(player)
	local lines = {}
	lines[#lines + 1] = ("Talent points: %d available, %d spent, %d total (level-based)."):format(
		Talents.getAvailablePoints(player), Talents.getSpentPoints(player), Talents.getTotalPoints(player))

	for _, nodeId in ipairs(Talents.Order) do
		local node = Talents.Nodes[nodeId]
		local rank = Talents.getRank(player, nodeId)
		if node.requiresRoot then
			if Talents.isUnlocked(player, nodeId) then
				lines[#lines + 1] = ("  %s: %d/%d (%s)"):format(node.name, rank, node.maxRank, formatEffect(node, rank))
			else
				local rootNode = Talents.Nodes[node.requiresRoot]
				lines[#lines + 1] =
					("  %s: locked -- max %s (%d/%d) first"):format(node.name, rootNode.name,
						Talents.getRank(player, node.requiresRoot), rootNode.maxRank)
			end
		else
			lines[#lines + 1] = ("%s: %d/%d (%s)"):format(node.name, rank, node.maxRank, formatEffect(node, rank))
		end
	end

	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, table.concat(lines, "\n"))
end

local function sendInfo(player, nodeId)
	local node = Talents.Nodes[nodeId]
	if not node then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Unknown talent. Use !talent to see the full list.")
		return
	end

	local rank = Talents.getRank(player, nodeId)
	local lines = {
		node.name .. (": %d/%d"):format(rank, node.maxRank), "Current: " .. formatEffect(node, rank),
		"At max: " .. formatEffect(node, node.maxRank)
	}
	if node.requiresRoot and not Talents.isUnlocked(player, nodeId) then
		local rootNode = Talents.Nodes[node.requiresRoot]
		lines[#lines + 1] = ("Locked -- requires %s at %d/%d (currently %d)"):format(rootNode.name, rootNode.maxRank,
			rootNode.maxRank, Talents.getRank(player, node.requiresRoot))
	end
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, table.concat(lines, "\n"))
end

function talk.onSay(player, words, param)
	local args = {}
	for word in param:gmatch("%S+") do args[#args + 1] = word end

	local subcommand = table.remove(args, 1)
	if not subcommand or subcommand == "" then
		sendSummary(player)
		return false
	end
	subcommand = subcommand:lower()

	if subcommand == "reset" then
		local success, reason = Talents.reset(player)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			success and "All talent points have been refunded." or reason)
		return false
	end

	if subcommand == "info" then
		local nodeId = Talents.resolveNodeId(args[1])
		if not nodeId then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: !talent info <talent>")
			return false
		end
		sendInfo(player, nodeId)
		return false
	end

	if subcommand == "add" then
		local nodeId = Talents.resolveNodeId(args[1])
		if not nodeId then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: !talent add <talent> [amount]")
			return false
		end
		local amount = tonumber(args[2]) or 1
		local success, reason = Talents.addRank(player, nodeId, math.floor(amount))
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			success and (reason or (Talents.Nodes[nodeId].name .. " increased.")) or reason)
		return false
	end

	if subcommand == "remove" then
		local nodeId = Talents.resolveNodeId(args[1])
		if not nodeId then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: !talent remove <talent> [amount]")
			return false
		end
		local amount = tonumber(args[2]) or 1
		local success, reason = Talents.removeRank(player, nodeId, math.floor(amount))
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			success and (reason or (Talents.Nodes[nodeId].name .. " decreased.")) or reason)
		return false
	end

	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		"Usage: !talent | !talent info <talent> | !talent add <talent> [amount] | !talent remove <talent> [amount] | !talent reset")
	return false
end

talk:separator(" ")
talk:register()
