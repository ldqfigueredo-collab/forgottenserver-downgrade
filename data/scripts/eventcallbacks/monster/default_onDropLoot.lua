local event = Event()

event.onDropLoot = function(self, corpse)
	if configManager.getNumber(configKeys.RATE_LOOT) == 0 then return end

	local player = Player(corpse:getCorpseOwner())
	local mType = self:getType()
	if not player or player:getStamina() > 840 then
		local monsterLoot = mType:getLoot()
		for i = 1, #monsterLoot do
			-- Note: createLootItem returns true/false (success), not the
			-- created Item — it's a pure-Lua helper in
			-- data/lib/core/container.lua, not a C++ binding. Don't use
			-- its return value as an item reference; read the corpse's
			-- actual contents afterward instead (see below).
			if not corpse:createLootItem(monsterLoot[i]) then
				print("[Warning] DropLoot:", "Could not add loot item to corpse.")
			end
		end

		if player then
			-- Item rarity: roll once per freshly-created loot item (see
			-- data/scripts/lib/rarity.lua). Must happen before the loot
			-- message text is built below, so rarity-renamed items show up
			-- correctly in the broadcast.
			local droppedItems = corpse:getItems(false)
			for i = 1, #droppedItems do
				Rarity.tryApplyOnDrop(droppedItems[i])
			end

			-- Build the loot message before auto-loot moves anything, so
			-- it always reflects what actually dropped.
			local text = ("Loot of %s: %s"):format(mType:getNameDescription(),
			                                       corpse:getContentDescription())

			if player:getStorageValue(PlayerStorageKeys.autoLootEnabled, 1) ~= 0 then
				local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)
				if backpack then
					local container = Container(backpack.uid)
					if container then
						-- If a Loot Bag (see data/scripts/lib/loot_bag.lua)
						-- is nested at the top level of the equipped
						-- backpack, route loot into it instead of loose
						-- into the backpack. First match wins; falls back
						-- to the backpack itself if none is found.
						local topLevelItems = container:getItems(false)
						for i = 1, #topLevelItems do
							local candidate = topLevelItems[i]
							if candidate:getId() == LootBag.itemId and candidate:isContainer() then
								container = Container(candidate.uid)
								break
							end
						end

						-- Read the corpse's actual current contents rather
						-- than tracking createLootItem's return value (see
						-- note above). Non-recursive: moves each top-level
						-- loot item/bag as a whole, same as a manual drag.
						local lootItems = corpse:getItems(false)
						-- flags = 0 is required: moveTo()'s default flags
						-- include FLAG_NOLIMIT, which bypasses capacity
						-- checks entirely. With flags = 0, a full backpack
						-- makes the move fail and the item simply stays in
						-- the corpse — nothing is ever lost.
						for i = 1, #lootItems do
							if not AutoLootBlacklist.contains(player, lootItems[i]:getId()) then
								lootItems[i]:moveTo(container, 0)
							end
						end
					end
				end
			end

			local party = player:getParty()
			if party then
				party:broadcastPartyLoot(text)
			else
				player:sendTextMessage(MESSAGE_INFO_DESCR, text)
			end
		end
	else
		local text = ("Loot of %s: nothing (due to low stamina)"):format(
			             mType:getNameDescription())
		local party = player:getParty()
		if party then
			party:broadcastPartyLoot(text)
		else
			player:sendTextMessage(MESSAGE_INFO_DESCR, text)
		end
	end
end

event:register()
