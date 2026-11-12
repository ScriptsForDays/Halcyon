-- Presets: a coordinated set of looks in one option.
--
--   Halcyon:CreateWindow({ Title = "Hub", Preset = "Glass" })
--
-- A preset only fills in what the hub did not set itself, so
-- `Preset = "Glass", Styles = { Toggle = "Checkbox" }` keeps the checkbox.

local Presets = {
	order = { "Classic", "Minimal", "Glass", "Neon", "Compact" },
	list = {
		-- Halcyon's own default look.
		Classic = {},
		-- Quiet: flat sections, thin controls, no button effects.
		Minimal = {
			Radius = "Soft",
			SectionStyle = "Flat",
			ButtonEffect = "None",
			Styles = { Toggle = "Slim", Slider = "Thin", TabIndicator = "Underline", Input = "Underline" },
		},
		-- Translucent panels, round corners and soft glows.
		Glass = {
			Radius = "Round",
			WindowStyle = "Glass",
			SectionStyle = "Glass",
			ButtonEffect = "Glow",
			Styles = { Toggle = "Large", TabIndicator = "Pill", Button = "Soft" },
		},
		-- Accent edges, glowing switches and a gradient window.
		Neon = {
			WindowStyle = "Gradient",
			SectionStyle = "Accent",
			ButtonEffect = "Sweep",
			Styles = { Toggle = "Glow", Slider = "Thick", TabIndicator = "Glow" },
		},
		-- Dense rows for hubs with a lot on each tab.
		Compact = {
			Density = "Compact",
			Radius = "Soft",
			SectionStyle = "Outlined",
			Styles = { Toggle = "Square", Slider = "Thin" },
		},
	},
}

function Presets.names()
	return table.clone(Presets.order)
end

function Presets.register(name, preset)
	if type(name) ~= "string" or type(preset) ~= "table" then
		return false, "AddPreset expects a name and a table"
	end
	if not Presets.list[name] then
		table.insert(Presets.order, name)
	end
	Presets.list[name] = preset
	return true, nil
end

-- Returns the window options with the named preset filled in underneath.
-- The table passed in is not changed.
function Presets.apply(options)
	local preset = Presets.list[options.Preset]
	if not preset then
		return options
	end
	local merged = table.clone(options)
	for key, value in preset do
		if key == "Styles" then
			local styles = if type(options.Styles) == "table" then table.clone(options.Styles) else {}
			for kind, name in value do
				if styles[kind] == nil then
					styles[kind] = name
				end
			end
			merged.Styles = styles
		elseif merged[key] == nil then
			merged[key] = value
		end
	end
	return merged
end

return Presets
