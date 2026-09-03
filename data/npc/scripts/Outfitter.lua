local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

local pendingPurchase = {}

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

-- Returns {unlock, lookType, step} for every outfit the player qualifies for
-- (level + vocation) and hasn't fully unlocked yet. step is "base", "addon1"
-- or "addon2" — the next purchasable step for that outfit.
local function eligibleUnlocks(player)
	local vocationId = player:getVocation():getId()
	local level = player:getLevel()
	local eligible = {}

	for _, unlock in ipairs(OutfitUnlocks) do
		if level >= unlock.minLevel then
			local group = unlock.vocationGroup and OutfitVocationGroups[unlock.vocationGroup]
			if not group or table.contains(group.ids, vocationId) then
				local lookType = player:getSex() == 0 and unlock.femaleLookType or unlock.maleLookType

				local step
				if not player:hasOutfit(lookType, 0) then
					step = "base"
				elseif not player:hasOutfit(lookType, 1) then
					step = "addon1"
				elseif not player:hasOutfit(lookType, 2) then
					step = "addon2"
				end

				if step then
					eligible[#eligible + 1] = {unlock = unlock, lookType = lookType, step = step}
				end
			end
		end
	end

	return eligible
end

local function stepLabel(step)
	if step == "base" then return "outfit" end
	if step == "addon1" then return "1st addon" end
	return "2nd addon"
end

local function stepCost(unlock, step) return step == "base" and unlock.cost.base or unlock.cost.addon end

local function stepAddonBits(step)
	if step == "addon1" then return 1 end
	if step == "addon2" then return 2 end
	return 0
end

local function matchEligibleByMessage(player, msg)
	for _, entry in ipairs(eligibleUnlocks(player)) do
		if msgcontains(msg, entry.unlock.name:lower()) then return entry end
	end
	return nil
end

local function matchEligibleByName(player, name)
	name = name:lower()
	for _, entry in ipairs(eligibleUnlocks(player)) do
		if entry.unlock.name:lower() == name then return entry end
	end
	return nil
end

local function listUnlocks(cid, player)
	local eligible = eligibleUnlocks(player)
	if #eligible == 0 then
		npcHandler:say("I have nothing left to offer you right now.", cid)
		return
	end

	local lines = {}
	for _, entry in ipairs(eligible) do
		local cost = stepCost(entry.unlock, entry.step)
		lines[#lines + 1] = string.format("{%s} %s (%d TP, %d gold)", entry.unlock.name, stepLabel(entry.step),
			cost.tp, cost.gold)
	end
	npcHandler:say("I can unlock: " .. table.concat(lines, ", ") .. ". Say an outfit's name to buy the next step.",
		cid)
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then return false end

	local player = Player(cid)

	if pendingPurchase[cid] then
		local pending = pendingPurchase[cid]
		if msgcontains(msg, "yes") then
			pendingPurchase[cid] = nil

			local entry = matchEligibleByName(player, pending.name)
			if not entry or entry.step ~= pending.step then
				npcHandler:say("Something changed since we last spoke, please ask me about outfits again.", cid)
				return true
			end

			local cost = stepCost(entry.unlock, entry.step)
			local points = player:getStorageValue(PlayerStorageKeys.taskPoints, -1)
			if points < 0 then points = 0 end

			if points < cost.tp then
				npcHandler:say(string.format("You need %d Task Points for that.", cost.tp), cid)
				return true
			end
			if player:getMoney() < cost.gold then
				npcHandler:say(string.format("You need %d gold for that.", cost.gold), cid)
				return true
			end

			player:setStorageValue(PlayerStorageKeys.taskPoints, points - cost.tp)
			player:removeMoney(cost.gold)
			player:addOutfit(entry.lookType, stepAddonBits(entry.step))

			npcHandler:say(string.format("Done! You unlocked the %s %s.", entry.unlock.name, stepLabel(entry.step)),
				cid)
		elseif msgcontains(msg, "no") then
			pendingPurchase[cid] = nil
			npcHandler:say("Very well. Come back when you are ready.", cid)
		else
			npcHandler:say("Do you accept? {yes}/{no}", cid)
		end
		return true
	end

	if msgcontains(msg, "outfit") then
		listUnlocks(cid, player)
		return true
	end

	local entry = matchEligibleByMessage(player, msg)
	if entry then
		local cost = stepCost(entry.unlock, entry.step)
		pendingPurchase[cid] = {name = entry.unlock.name, step = entry.step}
		npcHandler:say(string.format("The %s %s costs %d Task Points and %d gold. Do you accept? {yes}/{no}",
			entry.unlock.name, stepLabel(entry.step), cost.tp, cost.gold), cid)
		return true
	end

	return false
end

local function onAddFocus(cid) pendingPurchase[cid] = nil end
local function onReleaseFocus(cid) pendingPurchase[cid] = nil end

npcHandler:setCallback(CALLBACK_ONADDFOCUS, onAddFocus)
npcHandler:setCallback(CALLBACK_ONRELEASEFOCUS, onReleaseFocus)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
