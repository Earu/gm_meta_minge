local list, list_len = {}, 0
local cat_cvar = CreateClientConVar("minge_chatsounds_category", "feshpince", true, false, "Sets the chatsounds spam category")
local function initialize_list()
	if not (goluwa and goluwa.env and goluwa.env.chatsounds and goluwa.env.chatsounds.custom) then return end

	local lookup = {}
	for _, custom_list in pairs(goluwa.env.chatsounds.custom) do
		if custom_list.list then
			for k, v in pairs(custom_list.list) do
				lookup[k] = v
			end
		end
	end

	local cat = cat_cvar:GetString():Trim()
	if cat == "" or not cat or not lookup[cat] or cat == "all" then
		local tmp = {}
		for _, v in pairs(lookup) do
			tmp = table.Merge(tmp, v)
		end

		list = table.GetKeys(tmp)
		list_len = table.Count(list)
		return
	end

	list = table.GetKeys(lookup[cat])
	list_len = table.Count(list)
end

cvars.AddChangeCallback("minge_chatsounds_category", initialize_list)

if goluwa and goluwa.env and goluwa.env.chatsounds then
	initialize_list()
else
	minge:On("ChatsoundsInitialized", function(self)
		initialize_list()
		self:Off("ChatsoundsInitialized")
	end)
end

local Say = _G.SayLocal or _G.Say
local next_spew = 0
local function SpewRandomBS()
	if list_len < 1 then return end
	if CurTime() >= next_spew then
		Say(list[math.random(list_len)])
		next_spew = CurTime() + 0.5
	end
end

local valid_weps = {
	none = true,
	weapon_slap = true,
	weapon_rar = true,
	gmod_camera = true,
	weapon_crowbar = true,
	weapon_stunstick = true,
	weapon_physcannon = true,
	weapon_fists = true,
	weapon_bugbait = true,
}
minge:On("KeyPress", function(self, ply, key)
	if not self.Config.ChatsoundsSpam then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end
	if valid_weps[wep:GetClass()] and key == IN_RELOAD then
		SpewRandomBS()
	end
end)