minge:On("CreateMove", function(self, cmd)
	if self.Config.FlashlightSpam and input.IsKeyDown(KEY_F) then
		cmd:SetImpulse(100)
	end
end)