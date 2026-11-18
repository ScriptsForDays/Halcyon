-- A ready-made config block: name a config, then save it, load it, delete
-- it or mark it to load on start. Saving over an existing name and deleting
-- both ask first. Share codes copy every setting as text and paste it back,
-- which works even where the executor can't save files. Hubs place it on
-- any tab or section with Window:ConfigSection(target), and the Settings
-- tab uses the same block.

local Env = require("../Core/Env")

local ConfigSection = {}

-- The title says what happened; the config call's own message says which
-- config and, on failure, why.
local function report(window, done, failed, ok, message)
	window:Notify({ Title = if ok then done else failed, Content = message, Kind = if ok then "success" else "warning" })
end

-- After a load or import the player can take it back from the notice.
local function reportUndoable(window, done, failed, ok, message)
	if not ok then
		report(window, done, failed, ok, message)
		return
	end
	window:Notify({
		Title = done,
		Content = message,
		Kind = "success",
		Duration = 6,
		Actions = {
			{
				Title = "Undo",
				Callback = function()
					window:Undo()
				end,
			},
		},
	})
end

-- Copy and paste rows for share codes. Without a clipboard the code shows
-- in a box to select by hand.
local function shareRows(window, section)
	local shown
	section:Button({
		Title = "Copy share code",
		Description = "Every setting as one line of text",
		Icon = "copy",
		Callback = function()
			local code = window:ExportConfig()
			if not code then
				report(window, "", "Code not made", false, "These settings could not be written as a code.")
			elseif Env.copy(code) then
				report(window, "Share code copied", "", true, "Paste it into the box below on another device or account.")
			elseif shown then
				shown:Set(code)
			else
				shown = section:Code({ Title = "Share code", Code = code })
			end
		end,
	})
	section:Input({
		Title = "Paste share code",
		Placeholder = "Halcyon1:...",
		Clearable = true,
		Callback = function(text)
			if text == "" then
				return
			end
			reportUndoable(window, "Settings imported", "Code not imported", window:ImportConfig(text))
		end,
	})
end

-- `target` is a tab (a section is made on it) or a section (used as it is).
-- Options: Title, Icon, Side, for the section made on a tab; ShareCodes =
-- false leaves out the copy and paste rows.
function ConfigSection.build(window, target, options)
	options = options or {}
	local section = target
	if type(target.Section) == "function" then
		section = target:Section({ Title = options.Title or "Configs", Icon = options.Icon or "save", Side = options.Side })
	end
	if not Env.canSave then
		section:Paragraph({ Title = "Saving is off", Content = Env.NO_FILES .. " Share codes still work.", Icon = "info" })
		if options.ShareCodes ~= false then
			shareRows(window, section)
		end
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
			reportUndoable(window, "Config loaded", "Config not loaded", window:LoadConfig(chosen()))
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
	if options.ShareCodes ~= false then
		shareRows(window, section)
	end
	return section
end

return ConfigSection
