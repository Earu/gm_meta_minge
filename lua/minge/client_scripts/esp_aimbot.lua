local red = Color(255, 120, 0)
local white = Color(255, 255, 0)

local esp = CreateClientConVar("esp", "1")
local aimbot = CreateClientConVar("aimbot", "1")

local Players = player.GetAll
local TLine = util.TraceLine

surface.CreateFont("ESPFont", {
	font = "Iosevka Type",
	extended = true,
	size = 20,
	weight = 1000
})

local function DrawPlayerHitbox(p)
	if not p:Alive() then return end

	local h, mh = p:Health(), p:GetMaxHealth()
	local n = _G.UndecorateNick and _G.UndecorateNick(p:Nick()) or p:Nick()
	local mx, mn = p:OBBMaxs(), p:OBBMins()
	local ang = p:GetAngles()
	ang.pitch = 0
	ang.roll = 0

	h = h > mh and mh or h
	cam.Start2D()
	local pos = (p:EyePos() + Vector(0, 0, 10)):ToScreen()
	local hpx = mh / 200
	local x, y = pos.x - (100 * hpx), pos.y - 20
	surface.SetDrawColor(red)
	surface.DrawRect(x, y, (h * 2) * hpx, 10)
	surface.SetDrawColor(white)
	surface.DrawOutlinedRect(x, y, 200 * hpx, 10)
	draw.SimpleTextOutlined(n, "ESPFont", pos.x, pos.y - 40, red, TEXT_ALIGN_CENTER, nil, 1, white)
	cam.End2D()
end

local function GetClosestPlayer()
	local mindist = 2e6
	local lp = LocalPlayer()
	local lpos = lp:GetPos()
	local ret
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then
			local dist = ply:GetPos():Distance(lpos)
			if dist < mindist then
				ret = ply
				mindist = dist
			end
		end
	end

	return ret
end

rawset(minge, "Aimbot", function(self)
	if not aimbot:GetBool() then return end

	local ply = GetClosestPlayer()
	if IsValid(ply) then
		--local headid = ply:LookupBone("ValveBiped.Bip01_Spine")
		--if headid then
			local headpos = ply:EyePos()
			local lp = LocalPlayer()
			local wep = lp:GetActiveWeapon()
			local pos = lp:EyePos()
			local tr = TLine({
				start = pos,
				endpos = headpos,
				filter = {lp, wep}
			})

			if tr.Entity == ply and pos:Distance(headpos) <= 2000 then
				if IsValid(wep) and type(wep.Primary) == "table" then
					wep.Primary.Recoil = 0
					wep.Primary.Cone = 0
				end

				lp:SetEyeAngles((headpos - pos):Angle())
			end
		--end
	end
end)

minge:On("PostDrawTranslucentRenderables", function(self)
	if not self.Config.ESP then return end
	for _, ply in ipairs(Players()) do
		if ply ~= LocalPlayer() then
			DrawPlayerHitbox(ply)
		end
	end
end)

minge:On("PreDrawHalos", function(self)
	if not self.Config.ESP then return end
	halo.Add(player.GetAll(), red, 3, 3, 5, true, true)
end)

minge:On("PlayerSwitchWeapon", function(self, ply, oldwep, wep)
	self:MingeWeapon(oldwep)
	self:MingeWeapon(wep)
end)

minge:MingeWeapon(LocalPlayer():GetActiveWeapon())