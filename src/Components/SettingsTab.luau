-- A ready-made Settings tab: appearance, the menu key, anonymous mode,
-- configs and unload. Hubs call Window:SettingsTab() instead of rebuilding
-- these rows in every script.

local ConfigSection = require("./ConfigSection")
local Personalise = require("./Personalise")
local Motion = require("../Core/Motion")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local STYLES = { "Sidebar", "Rail", "Top", "Dock" }

-- Look names stay the values; only the wording shown is translated.
local function choices(names)
	local list = {}
	for _, name in names do
		table.insert(list, { Text = Strings.get(name), Value = name })
	end
	return list
end

local SettingsTab = {}

-- Options: Title, Icon, Group, and one switch per row. Every row is on
-- unless its switch is false:
--   Theme, Accent, Navigation, Scale, Language, ReduceMotion, MenuKey, Minimize,
--   Anonymous, Configs, Unload
-- ScaleControl picks "Stepper" (default) or "Slider" for the interface scale.
-- Two sections are added only when asked for: Personalise = true (or a
-- table of its row switches) and ThemeBuilder = true.
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
	local tab = window:Tab({ Title = options.Title or Strings.get("Settings"), Icon = options.Icon or "settings", Group = options.Group })
	local scope = tab.scope

	if wants("Theme", "Accent", "Navigation", "Scale", "Language", "ReduceMotion") then
		local look = tab:Section({ Title = Strings.get("Appearance"), Icon = "palette" })
		if wants("Theme") then
			local themes = look:Dropdown({
				Title = Strings.get("Theme"),
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
				Title = Strings.get("Accent colour"),
				Default = Theme.color("accent"),
				Callback = function(color)
					window:SetAccent(color)
				end,
			})
		end
		if wants("Navigation") then
			look:Dropdown({
				Title = Strings.get("Tab layout"),
				Values = choices(STYLES),
				Default = window.tabStyle,
				Callback = function(style)
					window:SetTabStyle(style)
				end,
			})
		end
		if wants("Scale") then
			local scale = {
				Title = Strings.get("Interface scale"),
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
		if wants("Language") then
			local languages = {}
			for _, language in Strings.languages() do
				table.insert(languages, { Text = language.Name, Value = language.Code })
			end
			look:Dropdown({
				Title = Strings.get("Language"),
				Values = languages,
				Default = Strings.language,
				Callback = function(code)
					if code and code ~= Strings.language then
						window:SetLanguage(code)
						window:Notify({
							Title = Strings.get("Language changed"),
							Content = Strings.get("Run the hub again to see every part in the new language."),
						})
					end
				end,
			})
		end
		if wants("ReduceMotion") then
			look:Toggle({
				Title = Strings.get("Reduce motion"),
				Default = Motion.reduced,
				Callback = function(reduced)
					window:SetReducedMotion(reduced)
				end,
			})
		end
	end

	local anonymous = wants("Anonymous") and window.profile.Enabled
	if wants("MenuKey", "Minimize") or anonymous then
		local menu = tab:Section({ Title = Strings.get("Menu"), Icon = "keyboard", Side = "Right" })
		if wants("MenuKey") then
			menu:Keybind({
				Title = Strings.get("Toggle key"),
				Default = window.toggleKey,
				ChangedCallback = function(key)
					window:SetToggleKey(key)
				end,
			})
		end
		if wants("Minimize") then
			menu:Dropdown({
				Title = Strings.get("Minimise to"),
				Values = choices({ "Topbar", "Pill", "Chip" }),
				Default = window.minimizeStyle,
				Callback = function(style)
					window:SetMinimizeStyle(style)
				end,
			})
		end
		if anonymous then
			menu:Toggle({
				Title = Strings.get("Anonymous mode"),
				Description = Strings.get("Hides your name and picture"),
				Default = window.profile.Anonymous,
				Callback = function(hidden)
					if hidden ~= window.profile.Anonymous then
						window:SetAnonymous(hidden)
					end
				end,
			})
		end
	end

	if options.Personalise then
		Personalise.section(window, tab, if type(options.Personalise) == "table" then options.Personalise else nil)
	end
	if options.ThemeBuilder then
		Personalise.builder(window, tab, { Side = "Right" })
	end

	if options.Configs ~= false then
		ConfigSection.build(window, tab, { Side = "Right" })
	end

	if wants("Unload") then
		tab:Section({ Title = Strings.get("Session"), Icon = "power" }):Button({
			Title = Strings.get("Unload"),
			Variant = "Danger",
			Callback = function()
				window:RequestUnload()
			end,
		})
	end
	return tab
end

return SettingsTab
