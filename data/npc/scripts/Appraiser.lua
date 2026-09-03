local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local pendingReroll = {}

-- Reroll cost scales with the item's CURRENT tier — the fee is the gold
-- sink; the reroll itself is a fresh random roll (Rarity.reroll), not a
-- guaranteed upgrade. It can come back lower, or even ordinary.
local rerollCost = {
	[Rarity.RARE] = 5000,
	[Rarity.EPIC] = 15000,
	[Rarity.LEGENDARY] = 40000
}

local rerollSlots = {
	{slot = CONST_SLOT_HEAD, name = "helmet"},
	{slot = CONST_SLOT_NECKLACE, name = "amulet"},
	{slot = CONST_SLOT_ARMOR, name = "armor"},
	{slot = CONST_SLOT_RIGHT, name = "right hand"},
	{slot = CONST_SLOT_LEFT, name = "left hand"},
	{slot = CONST_SLOT_LEGS, name = "legs"},
	{slot = CONST_SLOT_FEET, name = "boots"},
	{slot = CONST_SLOT_RING, name = "ring"}
}

local function findRarityItems(player)
	local found = {}
	for _, entry in ipairs(rerollSlots) do
		local item = player:getSlotItem(entry.slot)
		if item and item:getActionId() == Rarity.actionId then
			found[#found + 1] = {item = item, slotName = entry.name}
		end
	end
	return found
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then return false end
	local player = Player(cid)

	if pendingReroll[cid] then
		local pending = pendingReroll[cid]
		if msgcontains(msg, "yes") then
			pendingReroll[cid] = nil
			local item = pending.item
			if not item or item:getActionId() ~= Rarity.actionId then
				npcHandler:say(
					"That item is no longer where it was, please ask me again.",
					cid)
				return true
			end
			if player:getMoney() < pending.cost then
				npcHandler:say("You don't have enough gold anymore.", cid)
				return true
			end

			player:removeMoney(pending.cost)
			Rarity.reroll(item)
			npcHandler:say("There you go, the item's fate has been rewoven.",
			                cid)
		elseif msgcontains(msg, "no") then
			pendingReroll[cid] = nil
			npcHandler:say("Very well.", cid)
		else
			npcHandler:say("Do you accept? {yes}/{no}", cid)
		end
		return true
	end

	if msgcontains(msg, "reroll") or msgcontains(msg, "appraise") then
		local candidates = findRarityItems(player)
		if #candidates == 0 then
			npcHandler:say(
				"Wear a rare, epic or legendary item and ask me again.", cid)
			return true
		elseif #candidates > 1 then
			npcHandler:say(
				"You're wearing more than one rare item -- remove all but the one you want rerolled, then ask again.",
				cid)
			return true
		end

		local entry = candidates[1]
		local tier = entry.item:getCustomAttribute("rarityTier")
		local cost = rerollCost[tier]
		pendingReroll[cid] = {item = entry.item, cost = cost}
		npcHandler:say(string.format(
			               "I can reroll your %s's rarity for %d gold -- it might come out better, or worse, or ordinary. Do you accept? {yes}/{no}",
			               entry.slotName, cost), cid)
		return true
	end

	return false
end

local function onAddFocus(cid) pendingReroll[cid] = nil end
local function onReleaseFocus(cid) pendingReroll[cid] = nil end

npcHandler:setCallback(CALLBACK_ONADDFOCUS, onAddFocus)
npcHandler:setCallback(CALLBACK_ONRELEASEFOCUS, onReleaseFocus)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
