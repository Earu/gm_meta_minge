if not minge:IsOwnerClient() then return end

local PANEL = {}

local text_color = Color(255, 255, 255, 255)
local focus_color = Color(15, 114, 242, 255)
local red_color = Color(204, 0, 0, 255)
local bg_color = Color(30, 30, 30, 255)
local head_color = Color(60, 60, 60, 255)

PANEL.SelectedPlayer = NULL
function PANEL:Init()
	self:SetTitle("Minge")

	local i, j = 1, 1
	local keys = table.GetKeys(minge.Config)
	table.sort(keys)
	for _, key in pairs(keys) do
		local checkbox = vgui.Create("DCheckBox", self)
		checkbox:SetPos(15 + (j - 1) * 150, 10 + 25 * i)
		checkbox:SetValue(minge.Config[key])

		function checkbox:OnChange(state)
			minge.Config[key] = state
			minge:UploadConfigToServer(false, true)
		end

		function checkbox:Paint(w, h)
			surface.SetDrawColor(head_color)
			surface.DrawRect(0, 0, w, h)

			if self:GetChecked() then
				surface.SetDrawColor(focus_color)
				surface.DrawRect(2, 2, w - 4, h - 4)
			end
		end

		local label = vgui.Create("DLabel", self)
		label:SetPos(35 + (j - 1) * 150, 7 + 25 * i)
		label:SetText(key)
		label:SetWide(150)
		label:SetTextColor(text_color)

		i = i + 1
		if (i - 1) % 5 == 0 then
			j = j + 1
			i = 1
		end
	end

	local total_height = (i + 5 * j) * 5 + 10
	local function UpdateHeight(element)
		local _, y = element:GetPos()
		total_height = y + element:GetTall()
	end

	local total_width = 0
	local function UpdateWidth(element)
		local x, _ = element:GetPos()
		total_width = x + element:GetWide()
	end

	local cs_category_label = vgui.Create("DLabel", self)
	cs_category_label:SetTextColor(text_color)
	cs_category_label:SetText("Chatsounds Spam Category")
	cs_category_label:SetPos(15, total_height)
	cs_category_label:SetSize(280, 15)

	local player_list_label = vgui.Create("DLabel", self)
	player_list_label:SetTextColor(text_color)
	player_list_label:SetText("Player List")
	player_list_label:SetPos(cs_category_label:GetWide() + 55, total_height)
	player_list_label:SetSize(200, 15)

	UpdateHeight(cs_category_label)

	local cs_category = vgui.Create("DTextEntry", self)
	cs_category:SetTall(25)
	cs_category:SetWide(280)
	cs_category:SetPos(15, total_height + 5)

	function cs_category:OnEnter()
		local category = self:GetValue():Trim()

		RunConsoleCommand("minge_chatsounds_category", category)
		minge:Print("Changed chatsounds category: " .. (category == "" and "all" or category))

		if IsValid(self.Menu) then self.Menu:Remove() end
		self.DontBuildMenu = true
		self:GetParent():Close()
	end

	function cs_category:Paint(w, h)
		surface.SetDrawColor(head_color)
		surface.DrawRect(0, 0, w, h)

		local value = self:GetValue()
		surface.SetTextColor(text_color)
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(value)
		surface.SetTextPos(5, h / 2 - th / 2)
		surface.DrawText(value)

		if self:HasFocus() or self:IsHovered() then
			if math.sin(RealTime() * 4) >= 0 then -- cursor
				surface.SetDrawColor(text_color)
				surface.DrawRect(5 + tw, h / 2 - th / 2, 1, h / 2)
			end

			surface.SetDrawColor(focus_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	local cs_list = {}
	if goluwa and goluwa.env and goluwa.env.chatsounds and goluwa.env.chatsounds.custom then
		for _, custom_list in pairs(cs_list) do
			if custom_list.list then
				for k, v in pairs(custom_list.list) do
					cs_list[k] = v
				end
			end
		end
	end

	function cs_category:GetAutoComplete(text)
		if self.DontBuildMenu then return {} end
		if not self:HasFocus() then return end

		local suggestions = {}
		if ("all"):StartWith(text) then
			table.insert(suggestions, "all")
		end

		for category, _ in pairs(cs_list) do
			if category:StartWith(text) then
				table.insert(suggestions, category)
			end
		end

		return suggestions
	end

	function cs_category:OnKeyCodeTyped (key_code)
		if key_code == KEY_TAB then
			local suggestion = self:GetAutoComplete(self:GetValue())[1]
			if suggestion then
				self:SetText(suggestion)
			end

			timer.Simple(0, function()
				self:RequestFocus()  -- keep focus
				self:SetCaretPos(#self:GetValue())
			end)
			return true
		elseif key_code == KEY_ESCAPE then
			gui.HideGameUI()
			self.DontBuildMenu = true
			self:GetParent():Close()
			return true
		elseif key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
			self:OnEnter()
			return true
		end
	end

	self.ChatsoundsCategory = cs_category
	UpdateWidth(cs_category)

	local UndecorateNick = _G.UndecorateNick or function(nick) return nick end

	local player_list = vgui.Create("DComboBox", self)
	player_list:SetPos(total_width + 40, total_height + 5)
	player_list:SetSize(200, 25)
	player_list:SetTextColor(text_color)
	for _, v in ipairs(player.GetAll()) do
		player_list:AddChoice(UndecorateNick(v:Nick()), v)
	end

	function player_list:OnSelect(index, _, data)
		self:GetParent().SelectedPlayer = data
	end

	function player_list:Paint(w, h)
		surface.SetDrawColor(head_color)
		surface.DrawRect(0, 0, w, h)

		if self:IsMenuOpen() or self:IsHovered() then
			surface.SetDrawColor(focus_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	self.PlayerList = player_list
	UpdateWidth(player_list)

	local allow_btn = vgui.Create("DButton", self)
	allow_btn:SetPos(total_width + 10, total_height + 5)
	allow_btn:SetSize(100, 25)
	allow_btn:SetTextColor(text_color)
	allow_btn:SetText("Allow")

	function allow_btn:DoClick()
		local ply = self:GetParent().SelectedPlayer
		if not IsValid(ply) then return end
		if not _G.luadev then return end

		local cmd = ("lua_run_sv minge:Allow(_%d)"):format(ply:EntIndex())
		LocalPlayer():ConCommand(cmd)
	end

	function allow_btn:Paint(w, h)
		surface.SetDrawColor(head_color)
		surface.DrawRect(0, 0, w, h)

		if self:IsHovered() then
			surface.SetDrawColor(focus_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	UpdateWidth(allow_btn)

	local disallow_btn = vgui.Create("DButton", self)
	disallow_btn:SetPos(total_width + 10, total_height + 5)
	disallow_btn:SetSize(100, 25)
	disallow_btn:SetTextColor(text_color)
	disallow_btn:SetText("Disallow")

	function disallow_btn:DoClick()
		local ply = self:GetParent().SelectedPlayer
		if not IsValid(ply) then return end
		if not _G.luadev then return end

		local cmd = ("lua_run_sv minge:Disallow(_%d)"):format(ply:EntIndex())
		LocalPlayer():ConCommand(cmd)
	end

	function disallow_btn:Paint(w, h)
		surface.SetDrawColor(head_color)
		surface.DrawRect(0, 0, w, h)

		if self:IsHovered() then
			surface.SetDrawColor(focus_color)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	UpdateHeight(cs_category)

	self.lblTitle:SetTextColor(text_color)
	self.btnMinim:Hide()
	self.btnMaxim:Hide()

	self.btnClose:SetSize(30, 20)
	function self.btnClose:Paint(w, h)
		surface.SetDrawColor(red_color)
		surface.DisableClipping(true)
			surface.DrawRect(0, 0, w + 4, h - 1)
			if self:IsHovered() then
				surface.SetDrawColor(Color(255, 0, 0))
				surface.DrawOutlinedRect(0, 0, w + 4, h - 1)
			end
		surface.DisableClipping(false)
	end

	self:SetWide(155 * (j))
	self:SetTall(total_height + 10)

	cs_category:RequestFocus()
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(bg_color)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(head_color)
	surface.DrawRect(0, 0, w, 23)
end

function PANEL:OnClose()
	self.PlayerList:CloseMenu()
	self.ChatsoundsCategory.DontBuildMenu = true
	local menu = self.ChatsoundsCategory.Menu
	if IsValid(menu) then
		menu:Remove()
	end
end

vgui.Register("MingeConfigPanel", PANEL, "DFrame")

concommand.Add("mconfig", function()
	local p = vgui.Create("MingeConfigPanel")
	p:SetPos(ScrW() / 2 - p:GetWide() / 2, ScrH() / 2 - p:GetTall() / 2)
	p:MakePopup()
end)