-- The translation packs and how a language code picks one. Each pack maps
-- Halcyon's English text to that language; text a pack leaves out stays
-- English, so a pack never has to be complete to be useful.

local LocalizationService = game:GetService("LocalizationService")

local Locales = {
	packs = {
		["pt-br"] = require("./Portuguese"),
		es = require("./Spanish"),
		vi = require("./Vietnamese"),
		id = require("./Indonesian"),
		ru = require("./Russian"),
		tr = require("./Turkish"),
		fr = require("./French"),
		de = require("./German"),
	},
	-- Each language's name in itself, for the Settings tab's picker.
	names = {
		en = "English",
		["pt-br"] = "Português (Brasil)",
		es = "Español",
		vi = "Tiếng Việt",
		id = "Bahasa Indonesia",
		ru = "Русский",
		tr = "Türkçe",
		fr = "Français",
		de = "Deutsch",
	},
}

local ORDER = { "en", "pt-br", "es", "vi", "id", "ru", "tr", "fr", "de" }

-- A code Halcyon has a pack for. "auto" reads the player's Roblox language;
-- "es-mx" falls back to "es", any Portuguese to "pt-br", anything unknown
-- to English.
function Locales.resolve(code)
	if code == nil or code == "auto" then
		local ok, locale = pcall(function()
			return LocalizationService.RobloxLocaleId
		end)
		code = if ok and type(locale) == "string" then locale else "en"
	end
	code = string.gsub(string.lower(tostring(code)), "_", "-")
	if code == "en" or Locales.packs[code] then
		return code
	end
	local base = string.match(code, "^%a+") or "en"
	if base == "pt" then
		return "pt-br"
	end
	return if Locales.packs[base] then base else "en"
end

-- { { Code, Name } } in the order the picker shows them.
function Locales.codes()
	local list = {}
	for _, code in ORDER do
		table.insert(list, { Code = code, Name = Locales.names[code] })
	end
	return list
end

return Locales
