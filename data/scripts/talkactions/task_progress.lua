local talk = TalkAction("/task", "!task")

function talk.onSay(player, words, param)
	local taskId = player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1)
	local task = taskId > 0 and Tasks[taskId]
	local points = player:getStorageValue(PlayerStorageKeys.taskPoints, -1)
	if points < 0 then
		points = 0
	end

	if not task then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			string.format("You have no active task. Task Points: %d.", points))
		return false
	end

	local progress = player:getStorageValue(PlayerStorageKeys.taskCurrentProgress, -1)
	if progress < 0 then
		progress = 0
	end

	local status = progress >= task.killCount and " (ready to turn in!)" or ""
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
		"Task: %s %d/%d%s. Task Points: %d.", task.name, progress, task.killCount, status, points))
	return false
end

talk:separator(" ")
talk:register()
