if not minge:IsOwnerClient() then return end

local has_io_events = (file.Find("lua/bin/gmcl_io_events_*","GAME"))[1] and true or false
if has_io_events then
	if not timer.Exists("IOSpewFileEvents") then -- dont require twice
		has_io_events = (pcall(require, "io_events"))
	end

	minge:On("FileChanged", function(self, path, event_type)
		if path ~= "lua/minge/config.json" or event_type ~= "CHANGED" then return end
		self:UploadConfigToServer(true, true)
	end)
end

minge:Print("Config auto-reload " .. (has_io_events and "ON" or "OFF"))