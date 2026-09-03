local TASK_LIST_MODAL_ID = 4000

local taskModalWindow = CreatureEvent("TaskModalWindow")

function taskModalWindow.onModalWindow(player, modalWindowId, buttonId, choiceId)
	if modalWindowId ~= TASK_LIST_MODAL_ID or buttonId ~= 1 then
		return true
	end

	local task = Tasks[choiceId]
	if not task then
		return true
	end

	if player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1) > 0 then
		player:sendTextMessage(MESSAGE_STATUS_DEFAULT, "You already have an active task.")
		return true
	end

	if player:getLevel() < task.minLevel then
		player:sendTextMessage(MESSAGE_STATUS_DEFAULT, "You do not meet the level requirement for that task.")
		return true
	end

	player:setStorageValue(PlayerStorageKeys.taskCurrentId, choiceId)
	player:setStorageValue(PlayerStorageKeys.taskCurrentProgress, 0)
	player:sendTextMessage(MESSAGE_STATUS_DEFAULT, string.format(
		"Task accepted: kill %d %s.", task.killCount, task.name))
	return true
end

taskModalWindow:register()
