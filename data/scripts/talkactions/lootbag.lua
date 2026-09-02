local LOOTBAG_MODAL_ID = 4001

local talk = TalkAction("/lootbag", "!lootbag")

local function findLootBag(player)
	local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)
	if not backpack then
		return nil
	end

	local container = Container(backpack.uid)
	if not container then
		return nil
	end

	local topLevelItems = container:getItems(false)
	for i = 1, #topLevelItems do
		local candidate = topLevelItems[i]
		if candidate:getId() == LootBag.itemId and candidate:isContainer() then
			return Container(candidate.uid)
		end
	end
	return nil
end

local function statusText(player)
	local lootBag = findLootBag(player)
	if lootBag then
		return ("Loot Bag found: %d/%d full. Auto-loot is filling it instead of your main backpack."):format(
			lootBag:getSize(), lootBag:getCapacity())
	end

	local bagName = ItemType(LootBag.itemId):getName()
	return ("No Loot Bag found. Put a %s inside your main backpack to route auto-loot into it."):format(bagName)
end

function talk.onSay(player, words, param)
	local text = statusText(player)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, text)

	if player:isUsingOtcV8() then
		local window = ModalWindow(LOOTBAG_MODAL_ID, "Loot Bag", text)
		window:addButton(1, "OK")
		window:setDefaultEnterButton(1)
		window:setDefaultEscapeButton(1)
		window:sendToPlayer(player)
	end

	return false
end

talk:separator(" ")
talk:register()
