function onLogin(player)
	local serverName = configManager.getString(configKeys.SERVER_NAME)
	local loginStr = "Welcome to " .. serverName .. "!"
	if player:getLastLoginSaved() <= 0 then
		loginStr = loginStr .. " Please choose your outfit."
		player:sendOutfitWindow()
	else
		loginStr = string.format("Your last visit in %s: %s.", serverName,
		                         os.date("%d %b %Y %X", player:getLastLoginSaved()))
	end
	player:sendTextMessage(MESSAGE_STATUS_DEFAULT, loginStr)

	-- Promotion (premium-independent: promotions never get reverted on login, see BUILD_NOTES.md)
	local vocation = player:getVocation()
	if player:isPremium() then
		local value = player:getStorageValue(PlayerStorageKeys.promotion)
		if value and value == 1 then player:setVocation(vocation:getPromotion()) end
	end

	-- Refresh HP/mana regen percent in case a persisted regen condition predates a vocation change
	player:updateRegenPercent()

	-- Re-establish the talent-bonus condition, since it isn't persisted like an item ability
	Talents.applyBonuses(player)

	-- Events
	player:registerEvent("PlayerDeath")
	player:registerEvent("DropLoot")
	player:registerEvent("TaskKill")
	player:registerEvent("TaskModalWindow")
	player:registerEvent("LootBlacklistOpcode")
	player:registerEvent("TalentOpcode")

	-- Update Experience Rate Stamina
	player:updateStamina()
	return true
end
