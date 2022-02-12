local function MatchPac(input)
	input = tostring(input):lower()
	return input:match("^pac_") or input:match("^pac.") or input:match("pac3")
end

local function PacEradicate()
	local r_count, h_count, cvar_count, cmd_count, reg_count = 0, 0, 0, 0, 0
	for k,v in pairs(net.Receivers) do
		if MatchPac(k) then
			net.Receivers[k] = function() end
			r_count = r_count + 1
		end
	end

	for h, hs in pairs(hook.GetTable()) do
		h = tostring(h)
		for name,_ in pairs(hs) do
			name = tostring(name)
			if MatchPac(name) then
				hook.Remove(h,name)
				h_count = h_count + 1
			end
		end
	end

	local cvarrs = debug.getupvalues(cvars.GetConVarCallbacks).ConVars
	for cvarr, cbs in pairs(cvarrs) do
		if MatchPac(cvarr) then
			cvar_count = cvar_count + #cbs
			cvarrs[cvarr] = {}
		end
	end

	for name, _ in pairs(concommand.GetTable()) do
		name = tostring(name)
		if MatchPac(name) then
			concommand.Remove(name)
			cmd_count = cmd_count + 1
		end
	end

	local reg = debug.getregistry()
	for name, v in pairs(reg) do
		if type(v) == "function" then
			local src = debug.getinfo(reg[name]).source
			if MatchPac(src) then
				reg[name] = function() end
				reg_count =  reg_count + 1
			end
		end
	end

	_G.pac = nil
	_G.pace = nil
	_G.pacx = nil
	_G.pac_loaded_particle_effects = nil

	chat.AddText(Color(255, 255, 255, 255),
		("[PAC3 ERADICATOR] Removed: %d net receivers, %d hooks, %d cvar callbacks, %d concommands and %d functions in the registry")
		:format(r_count, h_count, cvar_count, cmd_count, reg_count)
	)
end

if minge.Config.EradicatePAC then
	RunConsoleCommand("pac_enable", "0") -- This needs to be done otherwise, some players become invisible
	timer.Simple(1, PacEradicate)
end