local model_list = table.Copy(player_manager.AllValidModels())
for k,v in pairs(model_list) do
	if not v:lower():match("group") then
		model_list[k] = nil
	end
end

local next_check = 0
local next_sound = 0
minge:On("Tick", function(self)
	if not self.Config.AutoRevive then return end
	if CurTime() < next_check then return end

	local lp = LocalPlayer()
	if lp:IsValid() and not lp:Alive() then
		if self.Config.RandomizePlayermodel then
			local path, name = table.Random(model_list)
			if pacx then pacx.SetModel(path) end
			RunConsoleCommand("cl_playermodel", name)
		end

		RunConsoleCommand("aowl", "revive")

		if CurTime() > next_sound then
			LocalPlayer():ConCommand("saysound you fat bald bastard you piece of subhuman trash")
			next_sound = CurTime() + 2
		end
	end

	next_check = CurTime() + 0.25
end)