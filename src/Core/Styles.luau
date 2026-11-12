-- The looks each kind of control can take, by name.
--
--   Styles.register("Toggle", "Switch", spec)
--   local spec, name = Styles.pick("Toggle", options.Style, window)
--
-- A spec is a plain table the control's builder reads (sizes, corners,
-- roles). Registration order is the order menus list the looks in, and the
-- first look registered for a kind is its default. Hub developers add their
-- own looks with Halcyon:AddStyle, using the same fields as a built-in one.

local Styles = { kinds = {} }

local function entry(kind)
	local found = Styles.kinds[kind]
	if not found then
		found = { order = {}, specs = {} }
		Styles.kinds[kind] = found
	end
	return found
end

-- Adds or replaces a look. Returns true, or false and why not.
function Styles.register(kind, name, spec)
	if type(kind) ~= "string" or type(name) ~= "string" or name == "" then
		return false, "AddStyle expects a kind and a name"
	end
	if type(spec) ~= "table" then
		return false, "AddStyle expects a table describing the look"
	end
	local found = entry(kind)
	if not found.specs[name] then
		table.insert(found.order, name)
	end
	found.specs[name] = spec
	return true
end

-- Registers a look based on another one, changing only the fields given.
function Styles.extend(kind, base, name, changes)
	local parent = Styles.get(kind, base)
	if not parent then
		return false, string.format("%s has no look called %q", kind, tostring(base))
	end
	local spec = table.clone(parent)
	for key, value in changes do
		spec[key] = value
	end
	return Styles.register(kind, name, spec)
end

function Styles.get(kind, name)
	local found = Styles.kinds[kind]
	return if found and type(name) == "string" then found.specs[name] else nil
end

function Styles.has(kind, name)
	return Styles.get(kind, name) ~= nil
end

-- The names of a kind's looks, in the order they were registered.
function Styles.names(kind)
	local found = Styles.kinds[kind]
	return if found then table.clone(found.order) else {}
end

-- The element's own choice wins, then the window's default for the kind,
-- then the first look registered. Unknown names fall through rather than
-- error, so a typo shows the default look instead of breaking the hub.
function Styles.pick(kind, explicit, window)
	local found = Styles.kinds[kind]
	if not found then
		return nil, nil
	end
	if found.specs[explicit] then
		return found.specs[explicit], explicit
	end
	local preferred = window and window.styles and window.styles[kind]
	if found.specs[preferred] then
		return found.specs[preferred], preferred
	end
	local first = found.order[1]
	return found.specs[first], first
end

-- The older single options each name one kind's default look. They still
-- work; a Styles table entry for the same kind wins over them.
local LEGACY = {
	ToggleThumb = "Thumb",
	SliderTooltipStyle = "SliderTooltip",
	SectionStyle = "Section",
	ButtonEffect = "ButtonEffect",
	TabStyle = "Navigation",
	MinimizeStyle = "Minimize",
	WindowStyle = "Window",
	OpenAnimation = "Open",
	PageTransition = "PageTransition",
	TopbarControls = "Controls",
	TabIndicator = "TabIndicator",
}

-- The window's chosen default look for each kind.
function Styles.defaults(options)
	local chosen = {}
	for option, kind in LEGACY do
		if type(options[option]) == "string" then
			chosen[kind] = options[option]
		end
	end
	if type(options.Styles) == "table" then
		for kind, name in options.Styles do
			if type(kind) == "string" and type(name) == "string" then
				chosen[kind] = name
			end
		end
	end
	return chosen
end

return Styles
