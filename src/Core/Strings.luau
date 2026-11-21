-- Every word Halcyon writes on its own (buttons, prompts, notices, settings
-- rows) goes through Strings.get, keyed by its English text. A language
-- pack or the hub's own `Strings` table replaces any of them; whatever it
-- leaves out stays English. Text is read when a part is built, so set the
-- language before CreateWindow.
--
--   Strings.get("Delete \"{name}\"?", { name = "Main" })

local Locales = require("../Locales/Locales")

local Strings = {
	-- The pack in use, by its code ("en", "pt-br", ...).
	language = "en",
}

local overrides = {}
local pack = {}
-- Every key asked for so far, so GetStrings can list them.
local seen = {}
-- Every text handed out, so Translate can tell Halcyon's own words (already
-- in the player's language) from the hub's.
local given = {}

local function fill(text, values)
	if not values then
		return text
	end
	return (string.gsub(text, "{(%w+)}", function(name)
		local value = values[name]
		return if value ~= nil then tostring(value) else nil
	end))
end

function Strings.get(key, values)
	seen[key] = true
	local text = fill(overrides[key] or pack[key] or key, values)
	given[text] = true
	return text
end

-- Whether Halcyon wrote `text` itself.
function Strings.isBuiltIn(text)
	return given[text] == true
end

-- Picks a pack by code. "auto" follows the player's Roblox language and
-- falls back to English. Returns the code used.
function Strings.setLanguage(code)
	local chosen = Locales.resolve(code)
	Strings.language = chosen
	pack = Locales.packs[chosen] or {}
	return chosen
end

-- The hub's own wording, English text -> replacement. Merged over earlier
-- calls; `false` as a value removes an override.
function Strings.set(map)
	for key, value in map do
		if type(key) == "string" then
			overrides[key] = if type(value) == "string" then value else nil
		end
	end
end

-- Every key Halcyon has used so far with its current text.
function Strings.list()
	local list = {}
	for key in seen do
		list[key] = Strings.get(key)
	end
	return list
end

function Strings.languages()
	return Locales.codes()
end

return Strings
