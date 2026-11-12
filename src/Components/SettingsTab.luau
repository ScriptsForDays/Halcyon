-- A ready-made Settings tab: appearance, the menu key, anonymous mode,
-- configs and unload. Hubs call Window:SettingsTab() instead of rebuilding
-- these rows in every script.

local ConfigSection = require("./ConfigSection")
local Motion = require("../Core/Motion")
local Theme = require("../Core/Theme")

local STYLES = { "Sidebar", "Rail", "Top", "Dock" }

local SettingsTab = {}

-- Options: Title, Icon, Group, and one switch per row. Every row is on
-- unless its switch is false:
--   Theme, Accent, Navigation, Scale, ReduceMotion, MenuKey, Minimize,
--   Anonymous, Configs, Unload
-- ScaleControl picks "Stepper" (default) or "Slider" for the interface scale.
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
			local scale = {
				Title = "Interface scale",
				Min = 75,
				Max = 125,
				Step = 5,
				Suffix = "%",
				Default = math.round(window.scale * 100),
				-- The window resizes under the pointer, so the slider applies
				-- the scale when the drag ends rather than at every step.
				Live = false,
				Callback = function(percent)
					window:SetScale(percent / 100)
				end,
			}
			if options.ScaleControl == "Slider" then
				look:Slider(scale)
			else
				look:Stepper(scale)
			end
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
		ConfigSection.build(window, tab, { Side = "Right" })
	end

	if wants("Unload") then
		tab:Section({ Title = "Session", Icon = "power" }):Button({
			Title = "Unload",
			Variant = "Danger",
			Callback = function()
				window:RequestUnload()
			end,
		})
	end
	return tab
end

return SettingsTab
