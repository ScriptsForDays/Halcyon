-- A ready-made config block: name a config, then save it, load it, delete
-- it or mark it to load on start. Saving over an existing name and deleting
-- both ask first. Hubs place it on any tab or section with
-- Window:ConfigSection(target), and the Settings tab uses the same block.

local Env = require("../Core/Env")

local ConfigSection = {}

-- The title says what happened; the config call's own message says which
-- config and, on failure, why.
local function report(window, done, failed, ok, message)
	window:Notify({ Title = if ok then done else failed, Content = message, Kind = if ok then "success" else "warning" })
end

-- `target` is a tab (a section is made on it) or a section (used as it is).
-- Options: Title, Icon, Side, for the section made on a tab.
function ConfigSection.build(window, target, options)
	options = options or {}
	local section = target
	if type(target.Section) == "function" then
		section = target:Section({ Title = options.Title or "Configs", Icon = options.Icon or "save", Side = options.Side })
	end
	if not Env.canSave then
		section:Paragraph({ Title = "Saving is off", Content = Env.NO_FILES, Icon = "info" })
		return section
	end

	local name = section:Input({ Title = "Config name", Placeholder = "default" })
	local saved = section:Dropdown({ Title = "Saved configs", Values = window:ListConfigs(), AllowNone = true, Placeholder = "None" })
	-- A typed name wins over the one picked in the list.
	local function chosen()
		local typed = name:Get()
		return if typed ~= "" then typed else saved:Get()
	end
	-- The list follows configs saved or deleted from anywhere, including hub code.
	section.scope:add(window.ConfigChanged:Connect(function()
		saved:Refresh(window:ListConfigs())
	end))

	local function save(configName)
		report(window, "Config saved", "Config not saved", window:SaveConfig(configName))
	end

	section:Button({
		Title = "Save",
		Icon = "save",
		Callback = function()
			local configName = chosen() or "default"
			if not window:ConfigExists(configName) then
				save(configName)
				return
			end
			window:Dialog({
				Title = `Overwrite "{Env.safeName(configName)}"?`,
				Content = "Its saved settings are replaced with the current ones.",
				Buttons = {
					{ Title = "Keep" },
					{
						Title = "Overwrite",
						Variant = "Primary",
						Callback = function()
							save(configName)
						end,
					},
				},
			})
		end,
	})
	section:Button({
		Title = "Load",
		Icon = "download",
		Callback = function()
			report(window, "Config loaded", "Config not loaded", window:LoadConfig(chosen()))
		end,
	})
	section:Button({
		Title = "Load on start",
		Description = "Loads it when the hub starts",
		Icon = "pin",
		Callback = function()
			report(window, "Loads on start", "Autoload not set", window:SetAutoload(chosen()))
		end,
	})
	section:Button({
		Title = "Delete",
		Icon = "trash-2",
		Callback = function()
			local configName = chosen()
			if not configName then
				report(window, "Config deleted", "Nothing deleted", false, "Pick a config to delete.")
				return
			end
			window:Dialog({
				Title = `Delete "{Env.safeName(configName) or configName}"?`,
				Content = "This can't be undone.",
				Buttons = {
					{ Title = "Keep" },
					{
						Title = "Delete",
						Variant = "Danger",
						Callback = function()
							report(window, "Config deleted", "Config not deleted", window:DeleteConfig(configName))
						end,
					},
				},
			})
		end,
	})
	return section
end

return ConfigSection
