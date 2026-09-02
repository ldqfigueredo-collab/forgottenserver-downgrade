local talk = TalkAction("/blacklist", "!blacklist")

function talk.onSay(player, words, param)
	local args = {}
	for word in param:gmatch("%S+") do
		args[#args + 1] = word
	end

	local subcommand = table.remove(args, 1)

	if not subcommand or subcommand == "" then
		local list = AutoLootBlacklist.getList(player)
		if #list == 0 then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Your auto-loot blacklist is empty.")
			return false
		end

		local names = {}
		for i = 1, #list do
			names[#names + 1] = list[i].name
		end
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			"Blacklisted items: " .. table.concat(names, ", "))
		return false
	end

	subcommand = subcommand:lower()

	if subcommand == "clear" then
		AutoLootBlacklist.clear(player)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Auto-loot blacklist cleared.")
		return false
	end

	if subcommand == "add" or subcommand == "remove" then
		local rest = table.concat(args, " ")
		if rest == "" then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
				"Usage: !blacklist " .. subcommand .. " <item name or id>")
			return false
		end

		local itemType = ItemType(rest)
		if itemType:getId() == 0 then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
				"No item found matching \"" .. rest .. "\".")
			return false
		end

		local success, reason
		if subcommand == "add" then
			success, reason = AutoLootBlacklist.add(player, itemType:getId())
		else
			success, reason = AutoLootBlacklist.remove(player, itemType:getId())
		end

		if success then
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, ("%s %s auto-loot blacklist."):format(
				itemType:getName(), subcommand == "add" and "added to" or "removed from"))
		else
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, reason)
		end
		return false
	end

	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: !blacklist [add|remove|clear] <item name or id>")
	return false
end

talk:separator(" ")
talk:register()
