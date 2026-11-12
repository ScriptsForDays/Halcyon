-- Appended to the example when it is loaded into Roblox Studio for visual
-- checks. It lets a test harness put the window into a known state by
-- setting the "Command" attribute on ReplicatedStorage, since a script
-- cannot press real buttons. It is not part of the library or the example.

local function run(command)
	local name, argument = string.match(command, "^(%a+):(.*)$")
	if name == "tab" then
		for _, tab in Window.tabs do
			if tab.Title == argument then
				Window:SelectTab(tab)
			end
		end
	elseif name == "theme" then
		Halcyon:SetTheme(argument)
	elseif name == "style" then
		Window:SetTabStyle(argument)
	elseif name == "size" then
		local width, height = string.match(argument, "^(%d+)x(%d+)$")
		Window.size = Vector2.new(tonumber(width), tonumber(height))
		Window:layout()
	elseif name == "scroll" then
		Window.selected.page.CanvasPosition = Vector2.new(0, tonumber(argument))
	elseif name == "anonymous" then
		Window:SetAnonymous(argument == "true")
	elseif name == "search" then
		Window:Search(argument)
	elseif name == "scale" then
		Window:SetScale(tonumber(argument))
	elseif name == "notify" then
		Window:Notify({ Title = "Timer notice", Content = "Counts down before it leaves.", Kind = "warning", Style = "Timer", Duration = 60 })
		Window:Notify({ Title = "Saved", Style = "Compact", Kind = "success", Duration = 60 })
		Window:Notify({ Title = "Update ready", Content = "Version 1.1 is out.", Kind = "info", Style = "Banner", Duration = 60 })
		local job = Window:Notify({ Title = "Downloading assets", Content = "6 of 10", Style = "Progress" })
		job.SetProgress(0.6)
	elseif name == "unload" then
		Window:RequestUnload()
	elseif name == "minimize" then
		Window:SetMinimizeStyle(argument)
		Window:Minimize(true)
	elseif name == "restore" then
		Window:Minimize(false)
	elseif name == "group" then
		Window:SetGroupCollapsed(argument, not Window.collapsedGroups[argument])
	elseif name == "personal" then
		local key, value = string.match(argument, "^(%w+)=(.*)$")
		Window:SetPersonal(key, if value == "true" then true elseif value == "false" then false else tonumber(value) or value)
	elseif name == "look" then
		-- look:Preset=Glass,WindowStyle=Glass rebuilds the example in that look.
		local chosen = {}
		for key, value in string.gmatch(argument, "(%w+)=(%w+)") do
			chosen[key] = value
		end
		start(chosen)
	elseif name == "notices" then
		Window:Notify({ Title = "Connected", Style = "Island", Kind = "success", Duration = 60 })
		Window:Notify({ Title = "Config saved", Content = "Your settings were written to disk.", Style = "Accent", Kind = "success", Duration = 60 })
		Window:Notify({ Title = "Level 10 reached", Content = "Shows how this look sits on screen.", Style = "Achievement", Kind = "success", Duration = 60 })
		Window:Notify({ Title = "Item sold", Style = "Snackbar", Duration = 60, Actions = { { Title = "Undo" } } })
	elseif name == "palette" then
		Window:OpenPalette()
	elseif name == "set" then
		local flag, value = string.match(argument, "^(%w+)=(.*)$")
		local handle = Window.Flags[flag]
		handle:Set(if value == "true" then true elseif value == "false" then false else tonumber(value) or value)
	end
end

ReplicatedStorage:GetAttributeChangedSignal("Command"):Connect(function()
	local commands = ReplicatedStorage:GetAttribute("Command")
	if type(commands) == "string" then
		for command in string.gmatch(commands, "[^;]+") do
			run(command)
		end
	end
end)
