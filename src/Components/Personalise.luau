-- The player's own look for a hub, changed live and saved with the window's
-- preferences: font, text size, corners, density, see-through amount,
-- notice position, gradient accent, colour-blind-friendly status colours
-- and their own themes.

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Notifications = require("./Notifications")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")
local Tokens = require("../Core/Tokens")

local Personalise = {}

-- Families offered in the font picker. Inter is the library's own.
Personalise.Fonts = { "Inter", "BuilderSans", "Gotham", "Montserrat", "Roboto", "SourceSans", "Ubuntu", "Nunito", "Arimo" }
local INTER = "rbxassetid://12187365364"
local POSITIONS = { "TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight" }
Personalise.Positions = POSITIONS

local function family(name)
	if name == "Inter" then
		return INTER
	end
	local ok, font = pcall(Font.fromName, name)
	return if ok and font then font.Family else nil
end

-- Every instance the window drew, on its own screen and the overlay.
local function each(window, callback)
	for _, root in { window.gui, window.library.overlay and window.library.overlay.gui } do
		if root then
			for _, instance in root:GetDescendants() do
				callback(instance)
			end
		end
	end
end

local TEXT = { TextLabel = true, TextButton = true, TextBox = true }

-- Applies one saved or chosen setting. Returns true when it was understood.
function Personalise.apply(window, key, value)
	local personal = window.personal
	if key == "Font" then
		local wanted = family(value)
		if not wanted then
			return false
		end
		local previous = Create.family
		Create.setFamily(wanted)
		each(window, function(instance)
			-- Only text in the library's own family changes; code stays monospaced.
			if TEXT[instance.ClassName] and instance.FontFace.Family == previous then
				instance.FontFace = Font.new(wanted, instance.FontFace.Weight, instance.FontFace.Style)
			end
		end)
	elseif key == "TextSize" or key == "Radius" or key == "Density" then
		local before = { text = Tokens.textScale }
		if not table.find(Tokens[key], value) then
			return false
		end
		Tokens.set({ [key] = value })
		if key == "TextSize" then
			local ratio = Tokens.textScale / before.text
			each(window, function(instance)
				if TEXT[instance.ClassName] then
					instance.TextSize = math.round(instance.TextSize * ratio)
				end
			end)
		elseif key == "Radius" then
			each(window, function(instance)
				local base = instance:GetAttribute("HalcyonRadius")
				if base and instance:IsA("UICorner") then
					local radius = Tokens.corner(base)
					instance.CornerRadius = if radius < 0 then UDim.new(1, 0) else UDim.new(0, radius)
				end
			end)
		else
			each(window, function(instance)
				local part = instance:GetAttribute("HalcyonDensity")
				if part == "padding" then
					instance.PaddingTop = UDim.new(0, Tokens.density.rowPadding)
					instance.PaddingBottom = instance.PaddingTop
				elseif part == "height" then
					instance.MinSize = Vector2.new(0, Tokens.rowHeight())
				end
			end)
		end
	elseif key == "Transparency" then
		window:SetTransparency(value)
	elseif key == "NoticePosition" then
		if not table.find(POSITIONS, value) then
			return false
		end
		Notifications.configure(window.library, { Position = value })
	elseif key == "AccentGradient" then
		Theme.setGradient(value == true)
	elseif key == "SafeStatus" then
		Theme.setSafeStatus(value == true)
	else
		return false
	end
	personal[key] = value
	return true
end

-- Sets one setting and saves it.
function Personalise.set(window, key, value)
	local ok = Personalise.apply(window, key, value)
	if ok then
		window:savePreferences()
		-- A change made from script moves the matching row too.
		local row = window.personalRows and window.personalRows[key]
		local shown = if key == "Transparency" then math.round((tonumber(value) or 0) * 100) else value
		if row and row:Get() ~= shown then
			row:Set(shown)
		end
	end
	return ok
end

-- Restores what the player saved, before or after the window is drawn.
-- Settings that only change new instances (tokens, font) are applied
-- early; the rest once the window exists.
function Personalise.restore(window, saved, early)
	if type(saved) ~= "table" then
		return
	end
	for _, key in if early then { "TextSize", "Radius", "Density" } else { "Font", "Transparency", "NoticePosition", "AccentGradient", "SafeStatus" } do
		if saved[key] ~= nil then
			if early then
				if table.find(Tokens[key], saved[key]) then
					Tokens.set({ [key] = saved[key] })
					window.personal[key] = saved[key]
				end
			else
				Personalise.apply(window, key, saved[key])
			end
		end
	end
end

-- Themes ----------------------------------------------------------------------

-- A palette as plain hex strings, for saving and sharing.
function Personalise.encodeTheme(palette)
	local plain = { Name = palette.Name }
	for _, role in Theme.Roles do
		plain[role] = palette[role]:ToHex()
	end
	return plain
end

-- Reads a plain palette back. Returns the Color3 table, or nil and why not.
function Personalise.decodeTheme(plain)
	if type(plain) ~= "table" or type(plain.Name) ~= "string" then
		return nil, Strings.get("That is not a theme.")
	end
	local palette = { Name = string.sub(plain.Name, 1, 32) }
	for _, role in Theme.Roles do
		local hex = plain[role]
		if type(hex) ~= "string" or not string.match(hex, "^#?%x%x%x%x%x%x$") then
			return nil, Strings.get('The theme is missing a valid "{role}" colour.', { role = role })
		end
		palette[role] = Color3.fromHex(hex)
	end
	return palette, nil
end

-- Registers and remembers a player-made theme.
function Personalise.saveTheme(window, palette)
	local ok, message = Theme.add(palette)
	if not ok then
		return false, message
	end
	window.customThemes[palette.Name] = Personalise.encodeTheme(Theme.palettes[palette.Name])
	window:savePreferences()
	return true, message
end

-- The share string for a theme: JSON the player can paste into another hub.
function Personalise.exportTheme(name)
	local palette = Theme.palettes[name]
	if not palette then
		return nil
	end
	local ok, text = Env.encode(Personalise.encodeTheme(palette))
	return if ok then text else nil
end

function Personalise.importTheme(window, text)
	local ok, plain = Env.decode(tostring(text or ""))
	if not ok then
		return false, Strings.get("That text is not a theme.")
	end
	local palette, problem = Personalise.decodeTheme(plain)
	if not palette then
		return false, problem
	end
	return Personalise.saveTheme(window, palette)
end

-- Rows ------------------------------------------------------------------------

-- The Personalise section: the rows a player uses to make the hub theirs.
-- Options: Title, Side, and one switch per row (each on unless false):
-- Font, TextSize, Corners, Density, Transparency, NoticePosition,
-- AccentGradient, SafeStatus.
function Personalise.section(window, tab, options)
	options = options or {}
	local personal = window.personal
	local section = tab:Section({ Title = options.Title or Strings.get("Personalise"), Icon = "paintbrush", Side = options.Side })
	window.personalRows = window.personalRows or {}
	local rows = window.personalRows
	if options.Font ~= false then
		rows.Font = section:Dropdown({
			Title = Strings.get("Font"),
			Values = Personalise.Fonts,
			Default = personal.Font or "Inter",
			Callback = function(name)
				Personalise.set(window, "Font", name)
			end,
		})
	end
	if options.TextSize ~= false then
		rows.TextSize = section:Segmented({
			Title = Strings.get("Text size"),
			Values = Tokens.TextSize,
			Default = Tokens.names.text,
			Callback = function(name)
				Personalise.set(window, "TextSize", name)
			end,
		})
	end
	if options.Corners ~= false then
		rows.Radius = section:Segmented({
			Title = Strings.get("Corners"),
			Values = Tokens.Radius,
			Default = Tokens.names.radius,
			Callback = function(name)
				Personalise.set(window, "Radius", name)
			end,
		})
	end
	if options.Density ~= false then
		rows.Density = section:Segmented({
			Title = Strings.get("Spacing"),
			Values = Tokens.Density,
			Default = Tokens.names.density,
			Callback = function(name)
				Personalise.set(window, "Density", name)
			end,
		})
	end
	if options.Transparency ~= false then
		rows.Transparency = section:Slider({
			Title = Strings.get("See-through window"),
			Min = 0,
			Max = 60,
			Step = 5,
			Suffix = "%",
			Default = math.round((window.transparency or 0) * 100),
			Callback = function(percent)
				Personalise.set(window, "Transparency", percent / 100)
			end,
		})
	end
	if options.NoticePosition ~= false then
		rows.NoticePosition = section:Dropdown({
			Title = Strings.get("Notice position"),
			Values = POSITIONS,
			Default = personal.NoticePosition or Notifications.Defaults.Position,
			Callback = function(position)
				Personalise.set(window, "NoticePosition", position)
			end,
		})
	end
	if options.AccentGradient ~= false then
		rows.AccentGradient = section:Toggle({
			Title = Strings.get("Gradient accent"),
			Default = personal.AccentGradient == true,
			Callback = function(on)
				Personalise.set(window, "AccentGradient", on)
			end,
		})
	end
	if options.SafeStatus ~= false then
		rows.SafeStatus = section:Toggle({
			Title = Strings.get("Colour-blind friendly"),
			Default = personal.SafeStatus == true,
			Callback = function(on)
				Personalise.set(window, "SafeStatus", on)
			end,
		})
	end
	return section
end

-- The theme builder: pick a role, change its colour and see it live, then
-- save the result under a name, or share it as text.
function Personalise.builder(window, tab, options)
	options = options or {}
	local section = tab:Section({ Title = options.Title or Strings.get("Theme builder"), Icon = "palette", Side = options.Side })
	local draft = table.clone(Theme.current)
	draft.Name = "Custom"
	local role = "accent"

	local function preview()
		local ok = Theme.add(draft)
		if ok then
			Theme.set(draft.Name)
		end
	end

	local picker
	section:Dropdown({
		Title = Strings.get("Colour"),
		Values = Theme.Roles,
		Default = role,
		Callback = function(name)
			role = name
			picker:Set(draft[role])
		end,
	})
	picker = section:ColorPicker({
		Title = Strings.get("Value"),
		Default = draft[role],
		Palette = true,
		Callback = function(color)
			draft[role] = color
			preview()
		end,
	})
	local name = section:Input({ Title = Strings.get("Name"), Placeholder = Strings.get("My theme"), MaxLength = 32 })
	-- Says how a save, copy or import went; hidden until one happens.
	local status = section:Label({ Title = "", Visible = false })
	local setStatus = status.SetTitle
	function status.SetTitle(target, text)
		setStatus(target, text)
		target:SetVisible(text ~= "")
	end
	section:Buttons({
		Buttons = {
			{
				Title = Strings.get("Save"),
				Icon = "save",
				Callback = function()
					local chosen = name:Get()
					if chosen == "" then
						status:SetTitle(Strings.get("Give the theme a name first."))
						return
					end
					local saving = table.clone(draft)
					saving.Name = chosen
					local ok, message = Personalise.saveTheme(window, saving)
					if ok then
						Theme.set(chosen)
					end
					status:SetTitle(if ok then message or Strings.get('Saved "{name}".', { name = chosen }) else message)
				end,
			},
			{
				Title = Strings.get("Copy"),
				Icon = "copy",
				Variant = "Outline",
				Callback = function()
					local text = Personalise.exportTheme(Theme.current.Name)
					local copied = text ~= nil and Env.copy(text)
					status:SetTitle(if copied then Strings.get("Copied. Paste it into Import to share.") else Strings.get("This executor can't copy text."))
				end,
			},
		},
	})
	section:Input({
		Title = Strings.get("Import"),
		Placeholder = Strings.get("Paste a theme"),
		Callback = function(text)
			if text == "" then
				return
			end
			local ok, message = Personalise.importTheme(window, text)
			status:SetTitle(if ok then "Imported." else message)
		end,
	})
	return section
end

-- Registers the themes the player made before.
function Personalise.loadThemes(window, saved)
	for _, plain in if type(saved) == "table" then saved else {} do
		local palette = Personalise.decodeTheme(plain)
		if palette and Theme.add(palette) then
			window.customThemes[palette.Name] = plain
		end
	end
end

return Personalise
