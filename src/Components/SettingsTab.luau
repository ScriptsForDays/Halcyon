-- A ready-made Settings tab: appearance, the menu key, anonymous mode,
-- configs and unload. Hubs call Window:SettingsTab() instead of rebuilding
-- these rows in every script.

local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Theme = require("../Core/Theme")

local STYLES = { "Sidebar", "Rail", "Top", "Dock" }

local SettingsTab = {}

-- `done` and `failed` title the notice; the message from the config call
-- says which config and why.
local function report(window, done, failed, ok, message)
	window:Notify({ Title = if ok then done else failed, Content = message, Kind = if ok then "success" else "warning" })
end

-- Options: Title, Icon, Group, and one switch per row. Every row is on
-- unless its switch is false:
--   Theme, Accent, Navigation, Scale, ReduceMotion, MenuKey, Minimize,
--   Anonymous, Configs, Unload
function SettingsTab.build(window, options)
	options = options or {}
	local function wants(...)
		for _, name in { ... } do
			if options[name] ~= false then
				return true
			end
		end
		return false
	end
	local tab = window:Tab({ Title = options.Title or "Settings", Icon = options.Icon or "settings", Group = options.Group })
	local scope = tab.scope

	if wants("Theme", "Accent", "Navigation", "Scale", "ReduceMotion") then
		local look = tab:Section({ Title = "Appearance", Icon = "palette" })
		if wants("Theme") then
			local themes = look:Dropdown({
				Title = "Theme",
				Values = Theme.names(),
				Default = Theme.current.Name,
				Callback = function(name)
					if name and name ~= Theme.current.Name then
						Theme.set(name)
					end
				end,
			})
			-- Follows theme changes made from script, including themes added later.
			scope:add(Theme.Changed:Connect(function(name)
				if themes:Get() ~= name then
					themes:Refresh(Theme.names())
					themes:Set(name)
				end
			end))
		end
		if wants("Accent") then
			look:ColorPicker({
				Title = "Accent colour",
				Description = "Laid over whichever theme is active",
				Default = Theme.color("accent"),
				Callback = function(color)
					window:SetAccent(color)
				end,
			})
		end
		if wants("Navigation") then
			look:Dropdown({
				Title = "Navigation",
				Description = "Narrow screens always use the tab strip",
				Values = STYLES,
				Default = window.tabStyle,
				Callback = function(style)
					window:SetTabStyle(style)
				end,
			})
		end
		if wants("Scale") then
			look:Stepper({
				Title = "Interface scale",
				Min = 75,
				Max = 125,
				Step = 5,
				Suffix = "%",
				Default = math.round(window.scale * 100),
				Callback = function(percent)
					window:SetScale(percent / 100)
				end,
			})
		end
		if wants("ReduceMotion") then
			look:Toggle({
				Title = "Reduce motion",
				Description = "Changes apply at once, without animation",
				Default = Motion.reduced,
				Callback = function(reduced)
					window:SetReducedMotion(reduced)
				end,
			})
		end
	end

	local anonymous = wants("Anonymous") and window.profile.Enabled
	if wants("MenuKey", "Minimize") or anonymous then
		local menu = tab:Section({ Title = "Menu", Icon = "keyboard", Side = "Right" })
		if wants("MenuKey") then
			menu:Keybind({
				Title = "Menu key",
				Description = "Shows and hides this window",
				Default = window.toggleKey,
				ChangedCallback = function(key)
					window:SetToggleKey(key)
				end,
			})
		end
		if wants("Minimize") then
			menu:Dropdown({
				Title = "Minimise to",
				Description = "What the minimise button leaves on screen",
				Values = { "Topbar", "Pill", "Chip" },
				Default = window.minimizeStyle,
				Callback = function(style)
					window:SetMinimizeStyle(style)
				end,
			})
		end
		if anonymous then
			menu:Toggle({
				Title = "Anonymous mode",
				Description = "Hides your name and avatar in this window",
				Default = window.profile.Anonymous,
				Callback = function(hidden)
					if hidden ~= window.profile.Anonymous then
						window:SetAnonymous(hidden)
					end
				end,
			})
		end
	end

	if options.Configs ~= false then
		local configs = tab:Section({ Title = "Configs", Icon = "save", Side = "Right" })
		if Env.canSave then
			local name = configs:Input({ Title = "Config name", Placeholder = "default" })
			local saved = configs:Dropdown({ Title = "Saved configs", Values = window:ListConfigs(), AllowNone = true, Placeholder = "None" })
			local function chosen()
				local typed = name:Get()
				return if typed ~= "" then typed else saved:Get()
			end
			configs:Button({
				Title = "Save",
				Description = "Writes every saved setting to this config",
				Icon = "save",
				Callback = function()
					local ok, message = window:SaveConfig(chosen() or "default")
					saved:Refresh(window:ListConfigs())
					report(window, "Config saved", "Config not saved", ok, message)
				end,
			})
			configs:Button({
				Title = "Load",
				Icon = "download",
				Callback = function()
					report(window, "Config loaded", "Config not loaded", window:LoadConfig(chosen()))
				end,
			})
			configs:Button({
				Title = "Load on start",
				Description = "Marks the config that Window:LoadAutoload() loads",
				Icon = "pin",
				Callback = function()
					report(window, "Loads on start", "Autoload not set", window:SetAutoload(chosen()))
				end,
			})
			configs:Button({
				Title = "Delete",
				Icon = "trash-2",
				Callback = function()
					local target = chosen()
					if not target then
						report(window, "Config deleted", "Nothing deleted", false, "Pick a config to delete.")
						return
					end
					window:Dialog({
						Title = `Delete "{target}"?`,
						Content = "The config file is removed from this device.",
						Buttons = {
							{ Title = "Keep" },
							{
								Title = "Delete",
								Variant = "Danger",
								Callback = function()
									local ok, message = window:DeleteConfig(target)
									saved:Refresh(window:ListConfigs())
									report(window, "Config deleted", "Config not deleted", ok, message)
								end,
							},
						},
					})
				end,
			})
		else
			configs:Paragraph({ Title = "Saving is off", Content = Env.NO_FILES, Icon = "info" })
		end
	end

	if wants("Unload") then
		tab:Section({ Title = "Session", Icon = "power" }):Button({
			Title = "Unload",
			Variant = "Danger",
			Callback = function()
				window:Unload()
			end,
		})
	end
	return tab
end

return SettingsTab
