local talk = TalkAction("/autoloot", "!autoloot")

function talk.onSay(player, words, param)
	param = param:lower()

	if param == "" then
		local enabled = player:getStorageValue(PlayerStorageKeys.autoLootEnabled, 1) ~= 0
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			("Auto-loot is currently %s. Use !autoloot on or !autoloot off to change it."):format(
				enabled and "on" or "off"))
		return false
	end

	if param == "on" then
		player:setStorageValue(PlayerStorageKeys.autoLootEnabled, 1)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Auto-loot enabled.")
	elseif param == "off" then
		player:setStorageValue(PlayerStorageKeys.autoLootEnabled, 0)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Auto-loot disabled.")
	else
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: !autoloot on|off")
	end

	return false
end

talk:separator(" ")
talk:register()
