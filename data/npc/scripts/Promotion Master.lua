local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

local awaitingConfirm = {}

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local function offerPromotion(cid, player, promotedVocation)
	awaitingConfirm[cid] = promotedVocation:getId()
	npcHandler:say(string.format(
		"For %d pieces of cheese, I can promote you to %s. Do you accept? {yes}/{no}",
		PromotionCost.count, promotedVocation:getName()), cid)
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local player = Player(cid)

	if awaitingConfirm[cid] then
		local promotedVocationId = awaitingConfirm[cid]
		if msgcontains(msg, "yes") then
			awaitingConfirm[cid] = nil
			if player:getVocation():getId() == 0 or not player:getVocation():getPromotion() or
				player:getVocation():getPromotion():getId() ~= promotedVocationId then
				npcHandler:say("Something changed since we last spoke, please ask me about promotion again.", cid)
				return true
			end

			if player:getItemCount(PromotionCost.item) < PromotionCost.count then
				npcHandler:say(string.format("You no longer have %d pieces of cheese.", PromotionCost.count), cid)
				return true
			end

			player:removeItem(PromotionCost.item, PromotionCost.count)
			player:setVocation(promotedVocationId)
			player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
			npcHandler:say("Congratulations! You have been promoted.", cid)
		elseif msgcontains(msg, "no") then
			awaitingConfirm[cid] = nil
			npcHandler:say("Very well. Come back when you are ready.", cid)
		else
			npcHandler:say("Do you accept? {yes}/{no}", cid)
		end
		return true
	end

	if msgcontains(msg, "promot") then
		local vocation = player:getVocation()
		if vocation:getId() == 0 then
			npcHandler:say("You must choose a vocation first. Speak to the Oracle.", cid)
			return true
		end

		local promotedVocation = vocation:getPromotion()
		if not promotedVocation then
			npcHandler:say("You are already at the peak of your vocation.", cid)
			return true
		end

		if player:getLevel() < PromotionMinLevel then
			npcHandler:say(string.format("Come back when you have reached level %d.", PromotionMinLevel), cid)
			return true
		end

		if player:getItemCount(PromotionCost.item) < PromotionCost.count then
			npcHandler:say(string.format("You need %d pieces of cheese for me to promote you.",
				PromotionCost.count), cid)
			return true
		end

		offerPromotion(cid, player, promotedVocation)
		return true
	end

	return false
end

local function onAddFocus(cid) awaitingConfirm[cid] = nil end
local function onReleaseFocus(cid) awaitingConfirm[cid] = nil end

npcHandler:setCallback(CALLBACK_ONADDFOCUS, onAddFocus)
npcHandler:setCallback(CALLBACK_ONRELEASEFOCUS, onReleaseFocus)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
