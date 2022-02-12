local answer_lines = {
	"yes barney what is it",
	"yes judith what is it",
	"yes yes im not deaf",
	"yes im talking to you",
	"what now#2",
	function(nick)
		return "ok " .. nick .. "!"
	end,
	function(nick)
		return "Yes " .. nick .. "?"
	end,

}

local question_answer_lines = {
	"jeopardy",
	"i dont know",
	"good question",
	function(nick)
		return "idk " .. nick
	end,
}

local question_words = {"why","when","what","how","can you","can i","do you"}
local function IsQuestion(txt)
	for _, word in ipairs(question_words) do
		if txt:match(word) then return true end
	end

	return txt:EndsWith("?")
end

local function IsCmd(txt)
	return txt:match("^[!|/|%.]")
end

local hello_words = {"hi","hey","ey","sup","henlo","hello","oy","hai"}
local function IsHello(txt)
	for _, word in ipairs(hello_words) do
		if txt:match("^" .. word) or txt:match(word .. "$") or txt:match(" " .. word .. " ") then
			return true
		end
	end

	return false
end

local function SayCallback(self, nick, txt, say_function)
	if not self.Config.AutoReplier then return end
	if IsCmd(txt) then return end
	if nick == "Discord" then return end -- dont reply to discord

	txt = txt:lower()
	local my_name = UndecorateNick(LocalPlayer():Nick())
	local sayer_name = (UndecorateNick(nick))
	if txt == "earu" or txt == my_name then
		local res = answer_lines[math.random(#answer_lines)]
		if not isfunction(res) then
			say_function(res)
		else
			say_function(res(sayer_name))
		end
		return true
	elseif txt:StartWith("earu") or txt:StartWith(my_name) or txt:EndsWith("earu") or txt:EndsWith(my_name) then
		if IsHello(txt) then
			say_function("Hi " .. sayer_name)
		elseif IsQuestion(txt) then
			local res = question_answer_lines[math.random(#answer_lines)]
			if not isfunction(res) then
				say_function(res)
			else
				say_function(res(sayer_name))
			end
		else
			say_function("Ok " .. sayer_name)
		end
		return true
	end

	return false
end

minge:On("OnPlayerChat", function(self, ply, txt, _, _, islocal)
	if not IsValid(ply) then return end
	if ply == LocalPlayer() then return end
	local replied = SayCallback(self, ply:Nick(), txt, islocal and _G.SayLocal or _G.Say)
	if replied and (LocalPlayer():IsAFK() or not system.HasFocus()) then
		RunConsoleCommand("aowl", "goto", ply:Nick())
	end
end)

minge:On("IRCSay", function(self, nick, txt)
	SayCallback(self, nick, txt, _G.Say)
end)