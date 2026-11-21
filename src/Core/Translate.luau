-- Shows a hub's own text (titles, descriptions, options, placeholders,
-- notices) in the player's language. Halcyon's built-in words already come
-- from the language packs in Strings; this covers what the hub wrote.
--
--   Halcyon:CreateWindow({ Language = "auto", Translate = true })
--   Translate = { From = "en", Fixes = { de = { ["Auto farm"] = "Auto-Farmen" } }, Skip = { "Halcyon" }, Service = fn }
--
-- How it works: every string a hub passes in its options (and later to
-- SetTitle, SetContent and the like) is noted as the hub's text. Text
-- objects in the hub's ScreenGuis are watched, and when one shows a noted
-- string it shows the translation instead; values, flags and callbacks
-- never see a translated word. Translations come from the hub's Fixes,
-- then a file saved per language, then the service, which is asked for
-- about forty lines at a time from a background thread. Until a line comes
-- back, and whenever the service fails, the text stays as written.
--
-- The default service is Google's free translate endpoint. It receives the
-- hub's own wording only: numbers are swapped for markers first, and text
-- typed by the player is never sent.

local HttpService = game:GetService("HttpService")

local Env = require("./Env")
local Schema = require("./Schema")
local Strings = require("./Strings")

local Translate = {
	-- True while a service is set and the player's language differs from
	-- the hub's.
	on = false,
	from = "en",
	to = "en",
}

local LINES_PER_REQUEST = 40
local CHARACTERS_PER_REQUEST = 1200
-- Lines longer than this are left as written; they are rarely labels.
local LONGEST = 400
local TRIES = 3
local SAVE_DELAY = 2

-- Option keys whose string values are words the player reads.
local SHOWN = {
	Title = true,
	Description = true,
	Content = true,
	Text = true,
	Placeholder = true,
	Subtitle = true,
	Summary = true,
	Info = true,
	Badge = true,
	LockText = true,
	LockHint = true,
	Hint = true,
	Name = true,
	Label = true,
	Done = true,
	EmptyText = true,
	Confirm = true,
	Tooltip = true,
	Spotlight = true,
	Note = true,
	Message = true,
	Caption = true,
	Group = true,
}
-- Option keys holding lists whose plain strings are words the player reads
-- (a dropdown's Values, a chart's Labels) or tables with SHOWN keys.
local LISTS = {
	Values = true,
	Options = true,
	Items = true,
	Tabs = true,
	Labels = true,
	Columns = true,
	Series = true,
	Buttons = true,
	Actions = true,
	Entries = true,
	Rarities = true,
	Menu = true,
	Updates = true,
}
-- Handle methods whose first argument is new text, and those that take a
-- new list of options.
local TEXT_SETTERS = { "SetTitle", "SetDescription", "SetContent", "SetText", "SetPlaceholder", "SetDone" }
local LIST_SETTERS = { "Refresh", "SetValues", "SetItems", "SetOptions", "SetLabels", "SetSeries" }

-- Words a translator gets wrong without context. Gaming jargon players
-- read in English everywhere stays as written (as do short all-capital
-- acronyms such as FPS), and a few common hub words have set translations.
local KEEP = {
	Ping = true,
	Aimbot = true,
	Noclip = true,
	Hitbox = true,
	["Anti-AFK"] = true,
	Discord = true,
	Roblox = true,
	Keyless = true,
}
local GLOSSARY = {
	Dashboard = {
		de = "Übersicht",
		ru = "Панель",
		fr = "Tableau de bord",
		es = "Panel",
		["pt-br"] = "Painel",
		tr = "Panel",
		vi = "Bảng điều khiển",
		id = "Dasbor",
	},
	Memory = {
		de = "Speicher",
		ru = "Память",
		fr = "Mémoire",
		es = "Memoria",
		["pt-br"] = "Memória",
		tr = "Bellek",
		vi = "Bộ nhớ",
		id = "Memori",
	},
	Free = {
		de = "Kostenlos",
		ru = "Бесплатно",
		fr = "Gratuit",
		es = "Gratis",
		["pt-br"] = "Grátis",
		tr = "Ücretsiz",
		vi = "Miễn phí",
		id = "Gratis",
	},
	Paid = {
		de = "Bezahlt",
		ru = "Платный",
		fr = "Payant",
		es = "De pago",
		["pt-br"] = "Pago",
		tr = "Ücretli",
		vi = "Trả phí",
		id = "Berbayar",
	},
	Features = {
		de = "Funktionen",
		ru = "Функции",
		fr = "Fonctions",
		es = "Funciones",
		["pt-br"] = "Funções",
		tr = "Özellikler",
		vi = "Tính năng",
		id = "Fitur",
	},
	News = {
		de = "Neuigkeiten",
		ru = "Новости",
		fr = "Actualités",
		es = "Novedades",
		["pt-br"] = "Novidades",
		tr = "Haberler",
		vi = "Tin tức",
		id = "Berita",
	},
}

local configured = false
-- Above zero while Halcyon builds its own parts (the Settings tab, the
-- config block): their words come from the language packs, and values such
-- as config names are the player's, so none of it is the hub's text.
local quiet = 0
local service = nil
local folder = nil
local fixes = {}
local skip = {}
local sources = {}
-- Translations by language, keyed by the line as it was sent, with its
-- numbers still masked.
local results = {}
local queue, queued = {}, {}
local waiting = {}
-- Callbacks waiting on a line, for text built around the hub's words.
local later = {}
local working, saving, stopped = false, false, false
local failures = 0
-- Text objects being watched (-> the property that holds their text), and
-- what each one is showing in place of the hub's text.
local watched = setmetatable({}, { __mode = "k" })
local shown = setmetatable({}, { __mode = "k" })
local guis = setmetatable({}, { __mode = "k" })

-- Numbers are swapped for the markers 11, 12, 13 ... before a line is
-- sent, so "123 coins" and "124 coins" are one line to translate, and are
-- put back by marker afterwards. Services keep plain numbers as they are.
-- Names (the hub's own, Skip entries, kept jargon) inside a longer line
-- travel the same way as numbers, so "Halcyon example" comes back with
-- Halcyon in it rather than a translation of the word.
local names = {}

local function escape(text)
	return (string.gsub(text, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"))
end

local function mask(text)
	local numbers = {}
	local found = {}
	for index, name in names do
		text = string.gsub(text, "%f[%w]" .. escape(name) .. "%f[%W]", function()
			table.insert(found, name)
			return "\1" .. string.char(64 + #found) .. "\1"
		end)
		if #found > 9 then
			break
		end
	end
	local masked = string.gsub(text, "%d+", function(digits)
		table.insert(numbers, digits)
		return tostring(10 + #numbers)
	end)
	masked = string.gsub(masked, "\1(%u)\1", function(letter)
		table.insert(numbers, found[string.byte(letter) - 64])
		return tostring(10 + #numbers)
	end)
	return masked, numbers
end

local function unmask(text, numbers)
	if #numbers == 0 then
		return text
	end
	local used = {}
	local result = string.gsub(text, "%d+", function(digits)
		local index = (tonumber(digits) or 0) - 10
		local value = numbers[index]
		if value then
			used[index] = true
			return value
		end
		return digits
	end)
	for index = 1, #numbers do
		if not used[index] then
			-- A marker went missing; the line as written is safer than a
			-- sentence with a number dropped.
			return nil
		end
	end
	return result
end

local function translatable(text)
	return type(text) == "string"
		and #text > 0
		and #text <= LONGEST
		and (string.find(text, "%a") ~= nil or string.find(text, "[\128-\255]") ~= nil)
		-- Rich text would reach the service with its tags.
		and string.find(text, "<%a") == nil
		and not skip[text]
		and not KEEP[text]
		-- One word with digits or symbols is a code, version, file or link.
		and not (string.find(text, "%s") == nil and string.find(text, "[%d%p]") ~= nil and string.match(text, "^[%a%-']+$") == nil)
		-- Something besides names and numbers is left to translate.
		and (string.find(select(1, mask(text)), "%a") ~= nil or string.find(select(1, mask(text)), "[\128-\255]") ~= nil)
		and not string.match(text, "^[%u%d%s%-]+$")
		-- Halcyon's own words are already in the player's language.
		and not Strings.isBuiltIn(text)
		-- More numbers than there are markers.
		and select(2, string.gsub(text, "%d+", "")) <= 9
end

-- Notes one string as the hub's own text.
function Translate.add(text)
	if configured and quiet == 0 and translatable(text) then
		sources[text] = true
	end
end

local function walk(value, depth, listed)
	if depth > 5 or type(value) ~= "table" then
		return
	end
	for key, item in value do
		local kind = type(item)
		if type(key) == "number" then
			if listed and kind == "string" then
				Translate.add(item)
			elseif kind == "table" then
				walk(item, depth + 1, false)
			end
		elseif type(key) == "string" then
			if SHOWN[key] and kind == "string" then
				Translate.add(item)
			elseif kind == "table" then
				walk(item, depth + 1, SHOWN[key] or LISTS[key])
			end
		end
	end
end

-- Notes every word a player would read in an options table.
function Translate.collect(options)
	if configured and quiet == 0 and type(options) == "table" then
		walk(options, 0, false)
	end
end

-- Notes the strings in a list (a dropdown's new Values).
function Translate.collectList(list)
	if configured and quiet == 0 and type(list) == "table" then
		walk(list, 0, true)
	end
end

local function cachePath(language)
	return if folder then `Halcyon/{folder}/translations/{Translate.from}-{language}.json` else nil
end

local function load(language)
	if results[language] then
		return
	end
	results[language] = {}
	local path = cachePath(language)
	local text = path and Env.read(path)
	if not text then
		return
	end
	local ok, saved = Env.decode(text)
	if ok and type(saved) == "table" then
		for line, translated in saved do
			if type(line) == "string" and type(translated) == "string" then
				results[language][line] = translated
			end
		end
	end
end

local function save()
	if saving or not folder then
		return
	end
	saving = true
	task.delay(SAVE_DELAY, function()
		saving = false
		for language, lines in results do
			local path = cachePath(language)
			if path and next(lines) ~= nil then
				local ok, text = Env.encode(lines)
				if ok then
					Env.write(path, text)
				end
			end
		end
	end)
end

-- The translation of one line of the hub's text into the current language,
-- or nil when there isn't one yet.
function Translate.lookup(text)
	local language = Translate.to
	local fixed = fixes[language] and fixes[language][text]
	if type(fixed) == "string" then
		return fixed
	end
	-- Set translations apply when the hub is written in English.
	local known = Translate.from == "en" and GLOSSARY[text] and GLOSSARY[text][language]
	if known then
		return known
	end
	local masked, numbers = mask(text)
	local done = results[language] and results[language][masked]
	if done == nil then
		return nil
	end
	return unmask(done, numbers) or text
end

local apply

local function deliver(masked)
	local labels = waiting[masked]
	waiting[masked] = nil
	if labels then
		for label, property in labels do
			if label.Parent then
				apply(label, property)
			end
		end
	end
	local callbacks = later[masked]
	later[masked] = nil
	for _, callback in callbacks or {} do
		task.spawn(callback)
	end
end

local function work()
	if working or stopped or not service then
		return
	end
	working = true
	task.spawn(function()
		while #queue > 0 and Translate.on and not stopped do
			local batch, size = {}, 0
			while #queue > 0 and #batch < LINES_PER_REQUEST and (#batch == 0 or size + #queue[1] <= CHARACTERS_PER_REQUEST) do
				local line = table.remove(queue, 1)
				size += #line
				table.insert(batch, line)
			end
			local language = Translate.to
			local ok, translated = pcall(service, batch, Translate.from, language)
			if ok and type(translated) == "table" then
				failures = 0
				load(language)
				for index, line in batch do
					queued[line] = nil
					local text = translated[index]
					if type(text) == "string" and text ~= "" then
						results[language][line] = text
					end
					deliver(line)
				end
				save()
				task.wait(0.2)
			else
				failures += 1
				for index = #batch, 1, -1 do
					table.insert(queue, 1, batch[index])
				end
				if failures >= TRIES then
					stopped = true
					Schema.warn(`Translate: the translation service failed {TRIES} times ({tostring(translated)}); the hub's text stays as written.`)
					break
				end
				task.wait(2 ^ failures)
			end
		end
		working = false
	end)
end

local function request(text, label, property)
	local masked = mask(text)
	waiting[masked] = waiting[masked] or setmetatable({}, { __mode = "k" })
	waiting[masked][label] = property
	if not queued[masked] then
		queued[masked] = true
		table.insert(queue, masked)
	end
	work()
end

-- The current translation of one of the hub's lines, or the line itself;
-- for text Halcyon builds around the hub's words, such as "Continue with
-- {tier}".
function Translate.text(text)
	if not Translate.on or type(text) ~= "string" or not sources[text] then
		return text
	end
	return Translate.lookup(text) or text
end

-- Runs `callback` once, when the translation of `text` arrives, so that
-- built text can be drawn again with it. Does nothing when there is
-- nothing to wait for.
function Translate.whenReady(text, callback)
	if not Translate.on or stopped or type(text) ~= "string" or not sources[text] or Translate.lookup(text) then
		return
	end
	local masked = mask(text)
	later[masked] = later[masked] or {}
	table.insert(later[masked], callback)
	if not queued[masked] then
		queued[masked] = true
		table.insert(queue, masked)
	end
	work()
end

-- Shows the translation on one text object when its text is the hub's.
function apply(label, property)
	local current = label[property]
	local entry = shown[label]
	if entry and entry.text == current then
		-- Our own write coming back as a change.
		return
	end
	shown[label] = nil
	if not Translate.on or not sources[current] then
		return
	end
	local translated = Translate.lookup(current)
	if translated then
		shown[label] = { source = current, text = translated }
		label[property] = translated
	elseif not stopped then
		request(current, label, property)
	end
end

local function hook(instance)
	if watched[instance] then
		return
	end
	local property = if instance:IsA("TextBox")
		then "PlaceholderText"
		elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then "Text"
		else nil
	if not property then
		return
	end
	watched[instance] = property
	instance:GetPropertyChangedSignal(property):Connect(function()
		apply(instance, property)
	end)
	apply(instance, property)
end

-- Watches every text object in a ScreenGui, now and later.
function Translate.watch(gui)
	if not configured or guis[gui] then
		return
	end
	guis[gui] = gui.DescendantAdded:Connect(hook)
	for _, descendant in gui:GetDescendants() do
		hook(descendant)
	end
end

-- Google's free endpoint: several q= lines in, a JSON list of lines out.
local GOOGLE_CODES = { ["pt-br"] = "pt" }
local function google(lines, from, to)
	local query = {}
	for _, line in lines do
		table.insert(query, "q=" .. HttpService:UrlEncode(line))
	end
	local source = HttpService:UrlEncode(GOOGLE_CODES[from] or from)
	local target = HttpService:UrlEncode(GOOGLE_CODES[to] or to)
	local url = `https://translate.googleapis.com/translate_a/t?client=gtx&sl={source}&tl={target}`
	local ok, body
	if Env.request then
		ok, body = Env.http({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
			Body = table.concat(query, "&"),
		})
	else
		ok, body = Env.http({ Url = url .. "&" .. table.concat(query, "&") })
	end
	if not ok then
		error(body, 0)
	end
	local decoded, list = Env.decode(body)
	if not decoded then
		error("the reply was not JSON", 0)
	end
	if type(list) == "string" then
		return { list }
	end
	local out = {}
	for index, item in list do
		-- Some replies pair each line with the language it was read as.
		out[index] = if type(item) == "table" then item[1] else item
	end
	return out
end

-- Called by CreateWindow with the window's Translate option, the language
-- Strings picked and the hub's folder.
function Translate.configure(option, language, hubFolder, hubName)
	configured = option == true or type(option) == "table"
	local settings = if type(option) == "table" then option else {}
	service = if type(settings.Service) == "function" then settings.Service elseif configured then google else nil
	folder = hubFolder
	Translate.from = if type(settings.From) == "string" then string.lower(settings.From) else "en"
	fixes = {}
	if type(settings.Fixes) == "table" then
		for code, map in settings.Fixes do
			if type(code) == "string" and type(map) == "table" then
				fixes[string.lower(code)] = map
			end
		end
	end
	skip = {}
	names = {}
	if type(settings.Skip) == "table" then
		for _, text in settings.Skip do
			if type(text) == "string" then
				skip[text] = true
				table.insert(names, text)
			end
		end
	end
	if type(hubName) == "string" and #hubName >= 3 then
		skip[hubName] = true
		table.insert(names, hubName)
	end
	for word in KEEP do
		table.insert(names, word)
	end
	-- Longest first, so "Blox Fruits" is kept whole before "Blox".
	table.sort(names, function(a, b)
		return #a > #b
	end)
	sources, results, queue, queued, waiting, later = {}, {}, {}, {}, {}, {}
	stopped, failures = false, 0
	Translate.setLanguage(language)
end

-- Turns every watched text object to the new language (or back to the
-- hub's own text when the player picks the language it is written in).
function Translate.setLanguage(language)
	if language ~= Translate.to then
		-- A new language gets a fresh go at a service that failed before.
		stopped, failures = false, 0
	end
	Translate.to = language or "en"
	Translate.on = configured and service ~= nil and Translate.to ~= Translate.from
	if Translate.on then
		load(Translate.to)
	end
	for label, property in watched do
		local entry = shown[label]
		if entry and label[property] == entry.text then
			shown[label] = nil
			label[property] = entry.source
		end
		if label.Parent then
			apply(label, property)
		end
	end
end

-- Runs one of Halcyon's own builders without noting its text as the hub's.
function Translate.quietly(build, ...)
	quiet += 1
	local results = table.pack(pcall(build, ...))
	quiet -= 1
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Wraps a handle's setters so text and lists given later are noted too.
function Translate.wrap(handle)
	if not configured or quiet > 0 then
		return
	end
	for _, name in TEXT_SETTERS do
		local original = handle[name]
		if type(original) == "function" then
			handle[name] = function(self, text, ...)
				Translate.add(text)
				return original(self, text, ...)
			end
		end
	end
	-- A chart's Set takes new items with names; other kinds' Set takes a
	-- value, which may be the player's own words, so it isn't noted.
	local setters = if handle.Kind == "Chart" then table.clone(LIST_SETTERS) else LIST_SETTERS
	if handle.Kind == "Chart" then
		table.insert(setters, "Set")
	end
	for _, name in setters do
		local original = handle[name]
		if type(original) == "function" then
			handle[name] = function(self, list, ...)
				if type(list) == "table" then
					Translate.collectList(list)
				end
				return original(self, list, ...)
			end
		end
	end
end

-- Lower-case translations of a row's title and description, for search.
function Translate.searchable(handle)
	if not Translate.on then
		return ""
	end
	local words = {}
	for _, text in { handle.Title, handle.Options and handle.Options.Description } do
		local translated = type(text) == "string" and Translate.lookup(text)
		if translated then
			table.insert(words, string.lower(translated))
		end
	end
	return table.concat(words, " ")
end

return Translate
