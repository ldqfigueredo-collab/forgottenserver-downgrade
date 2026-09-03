local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

local TASK_LIST_MODAL_ID = 4000

local awaitingTurnIn = {}

function onCreatureAppear(cid) npcHandler:onCreatureAppear(cid) end
function onCreatureDisappear(cid) npcHandler:onCreatureDisappear(cid) end
function onCreatureSay(cid, type, msg) npcHandler:onCreatureSay(cid, type, msg) end
function onThink() npcHandler:onThink() end

local function eligibleTasks(player)
	local eligible = {}
	for id, task in pairs(Tasks) do
		if player:getLevel() >= task.minLevel then
			eligible[#eligible + 1] = {id = id, task = task}
		end
	end
	table.sort(eligible, function(a, b) return a.id < b.id end)
	return eligible
end

local function sendTaskModal(player, eligible)
	local window = ModalWindow(TASK_LIST_MODAL_ID, "Available Tasks", "Choose a task suited to your level.")
	for _, entry in ipairs(eligible) do
		local task = entry.task
		window:addChoice(entry.id, string.format("%s - Lvl %d+ - %d kills - %d exp, %d gold, %d TP",
			task.name, task.minLevel, task.killCount, task.rewards.exp, task.rewards.gold, task.rewards.points))
	end
	window:addButton(1, "Accept")
	window:addButton(0, "Cancel")
	window:setDefaultEnterButton(1)
	window:setDefaultEscapeButton(0)
	window:sendToPlayer(player)
end

local function listTasks(cid, player)
	local eligible = eligibleTasks(player)
	if #eligible == 0 then
		npcHandler:say("I have no tasks suited to your level right now.", cid)
		return
	end

	local lines = {}
	for _, entry in ipairs(eligible) do
		local task = entry.task
		lines[#lines + 1] = string.format("{%s} (Lvl %d+, %d kills, %d exp/%d gold/%d TP)",
			task.name, task.minLevel, task.killCount, task.rewards.exp, task.rewards.gold, task.rewards.points)
	end
	npcHandler:say("I have these tasks available: " .. table.concat(lines, ", ") ..
		". Say a task's name to accept it.", cid)

	if player:isUsingOtcV8() then
		sendTaskModal(player, eligible)
	end
end

local function tryAcceptTaskByName(cid, player, msg)
	for id, task in pairs(Tasks) do
		if msgcontains(msg, task.name:lower()) then
			if player:getLevel() < task.minLevel then
				npcHandler:say("You are not experienced enough for that task yet.", cid)
				return true
			end
			player:setStorageValue(PlayerStorageKeys.taskCurrentId, id)
			player:setStorageValue(PlayerStorageKeys.taskCurrentProgress, 0)
			npcHandler:say(string.format("Task accepted: kill %d %s.", task.killCount, task.name), cid)
			return true
		end
	end
	return false
end

local function creatureSayCallback(cid, type, msg)
	if not npcHandler:isFocused(cid) then
		return false
	end

	local player = Player(cid)

	if awaitingTurnIn[cid] then
		if msgcontains(msg, "yes") then
			local taskId = player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1)
			local task = Tasks[taskId]
			awaitingTurnIn[cid] = nil
			if not task then
				npcHandler:say("Something went wrong with your task, please ask me about tasks again.", cid)
				return true
			end

			player:addExperience(task.rewards.exp, true)
			player:addMoney(task.rewards.gold)
			local points = player:getStorageValue(PlayerStorageKeys.taskPoints, -1)
			if points < 0 then
				points = 0
			end
			player:setStorageValue(PlayerStorageKeys.taskPoints, points + task.rewards.points)
			player:setStorageValue(PlayerStorageKeys.taskCurrentId, -1)
			player:setStorageValue(PlayerStorageKeys.taskCurrentProgress, -1)

			npcHandler:say(string.format(
				"Well done! You earned %d experience, %d gold and %d Task Points.",
				task.rewards.exp, task.rewards.gold, task.rewards.points), cid)
		elseif msgcontains(msg, "no") then
			awaitingTurnIn[cid] = nil
			npcHandler:say("Come back when you are ready to turn it in.", cid)
		else
			npcHandler:say("Turn in your completed task? {yes}/{no}", cid)
		end
		return true
	end

	if msgcontains(msg, "task") then
		local taskId = player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1)
		local task = taskId > 0 and Tasks[taskId]

		if not task then
			listTasks(cid, player)
			return true
		end

		local progress = player:getStorageValue(PlayerStorageKeys.taskCurrentProgress, -1)
		if progress < 0 then
			progress = 0
		end

		if progress >= task.killCount then
			awaitingTurnIn[cid] = true
			npcHandler:say(string.format(
				"You have completed your task: %d/%d %s killed. Turn it in? {yes}/{no}",
				progress, task.killCount, task.name), cid)
		else
			npcHandler:say(string.format("You have killed %d/%d %s so far.", progress, task.killCount, task.name), cid)
		end
		return true
	end

	local taskId = player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1)
	if taskId <= 0 and tryAcceptTaskByName(cid, player, msg) then
		return true
	end

	return false
end

local function onAddFocus(cid) awaitingTurnIn[cid] = nil end
local function onReleaseFocus(cid) awaitingTurnIn[cid] = nil end

npcHandler:setCallback(CALLBACK_ONADDFOCUS, onAddFocus)
npcHandler:setCallback(CALLBACK_ONRELEASEFOCUS, onReleaseFocus)
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new())
