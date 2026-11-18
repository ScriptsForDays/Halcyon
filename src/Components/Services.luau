-- Things a released hub needs besides its features: telling players a newer
-- version is out, showing what this executor can and can't do, and listing
-- the callbacks that failed so a bug report has something to go on.

local Env = require("../Core/Env")
local Sheet = require("./Sheet")
local Strings = require("../Core/Strings")

local Services = {}

-- Functions hubs commonly lean on, checked for the support panel.
local CHECKED = {
	"writefile",
	"readfile",
	"isfile",
	"listfiles",
	"delfile",
	"makefolder",
	"getcustomasset",
	"setclipboard",
	"request",
	"identifyexecutor",
	"getgenv",
	"gethui",
	"hookfunction",
	"hookmetamethod",
	"getrawmetatable",
	"getnamecallmethod",
	"setreadonly",
	"getconnections",
	"firesignal",
	"fireproximityprompt",
	"firetouchinterest",
	"sethiddenproperty",
	"queue_on_teleport",
	"setfpscap",
	"Drawing.new",
}

-- Version text compares number by number: 2.10 is newer than 2.9.
function Services.isNewer(candidate, current)
	local left, right = {}, {}
	for number in string.gmatch(tostring(candidate or ""), "%d+") do
		table.insert(left, tonumber(number))
	end
	for number in string.gmatch(tostring(current or ""), "%d+") do
		table.insert(right, tonumber(number))
	end
	for index = 1, math.max(#left, #right) do
		local x, y = left[index] or 0, right[index] or 0
		if x ~= y then
			return x > y
		end
	end
	return false
end

-- Reads `Url` and reports whether it names a newer version than Current.
-- The address may answer with plain text ("2.4.0") or JSON
-- { "version": "2.4.0", "notes": "..." }. Nothing downloaded is ever run.
-- Returns ok, latest, notes (ok is false with a reason when the check fails).
function Services.fetchLatest(settings)
	local ok, body = Env.http({ Url = settings.Url })
	if not ok then
		return false, body
	end
	local latest, notes
	local decoded, reply = Env.decode(body)
	if decoded and type(reply) == "table" then
		latest = reply.version or reply.Version
		notes = reply.notes or reply.Notes
	else
		latest = string.match(body, "^%s*([%w%.%-]+)%s*$")
	end
	if type(latest) ~= "string" then
		return false, Strings.get("The update address didn't name a version.")
	end
	return true, latest, if type(notes) == "string" then notes else nil
end

-- UpdateCheck = { Url, Current (the window's Version by default), Notify
-- [true], OnUpdate(latest, notes) }. Checks once, a moment after the hub
-- opens, so a slow address never holds the window up.
function Services.watchUpdates(window, settings)
	if type(settings) ~= "table" or type(settings.Url) ~= "string" then
		return
	end
	window.scope:add(task.delay(1, function()
		window:CheckForUpdate()
	end))
end

function Services.check(window)
	local settings = window.options.UpdateCheck
	if type(settings) ~= "table" or type(settings.Url) ~= "string" then
		return false, Strings.get("No update address is set.")
	end
	local current = settings.Current or window.options.Version
	local ok, latest, notes = Services.fetchLatest(settings)
	if not ok then
		return false, latest
	end
	if not Services.isNewer(latest, current) then
		return true, nil
	end
	window.UpdateAvailable:Fire(latest, notes)
	Env.call("Update check", settings.OnUpdate, latest, notes)
	if settings.Notify ~= false then
		window:Notify({
			Id = "halcyon-update",
			Title = Strings.get("Update available"),
			Content = Strings.get("Version {latest} is out; this is {current}. Run the script again to get it.", {
				latest = latest,
				current = current or "?",
			}),
			Kind = "info",
			Icon = "download",
			Duration = 10,
		})
	end
	return true, latest, notes
end

-- One open panel at a time; opening again rebuilds it with fresh details.
local function openSheet(window, key, title, build)
	if window[key] then
		window[key]:Destroy()
	end
	local panel = Sheet.new(window, { Title = title, Width = 380 })
	window[key] = panel
	build(panel)
	panel:Open()
	return panel
end

-- Everything the panel shows, as text a player can paste into a report.
function Services.report(window)
	local name, version = Env.executor()
	local lines = { `Halcyon {window.library.version or ""}`, `{window.Title} {window.options.Version or ""}`, `Executor: {name} {version or ""}` }
	local missing = Env.missing(CHECKED)
	table.insert(lines, if #missing == 0 then "Missing: none" else "Missing: " .. table.concat(missing, ", "))
	for _, entry in window.Errors do
		table.insert(lines, `Error in {entry.Title}: {entry.Message}`)
	end
	return table.concat(lines, "\n")
end

function Services.supportPanel(window)
	return openSheet(window, "supportSheet", Strings.get("Executor support"), function(panel)
		local name, version = Env.executor()
		local about = panel:Section({ Title = Strings.get("This executor") })
		about:Status({ Title = name, Status = version or Strings.get("Version unknown"), Kind = "info" })
		about:Status({
			Title = Strings.get("Saving files"),
			Status = if Env.canSave then Strings.get("Works") else Strings.get("Not available"),
			Kind = if Env.canSave then "success" else "warning",
		})
		local list = panel:Section({ Title = Strings.get("Functions") })
		local rows = {}
		for _, functionName in CHECKED do
			local present = Env.has(functionName)
			table.insert(rows, { functionName, if present then Strings.get("Yes") else Strings.get("No") })
		end
		list:Table({ Columns = { Strings.get("Function"), { Title = Strings.get("Present"), Width = 0.3 } }, Rows = rows, MaxHeight = 260 })

		-- Rows the hub locked because something they need is missing.
		local locked = {}
		for _, tab in window.tabs do
			for _, entry in tab.entries do
				if entry.handle.MissingText then
					table.insert(locked, { entry.handle.Title, entry.handle.MissingText })
				end
			end
		end
		if #locked > 0 then
			panel:Section({ Title = Strings.get("Locked here") }):Table({ Columns = { Strings.get("Feature"), Strings.get("Needs") }, Rows = locked })
		end
		panel:Section({}):Button({
			Title = Strings.get("Copy report"),
			Icon = "copy",
			Callback = function()
				local copied = Env.copy(Services.report(window))
				window:Notify({
					Title = if copied then Strings.get("Report copied") else Strings.get("Can't copy"),
					Content = if copied then nil else Strings.get("This executor has no clipboard."),
					Kind = if copied then "success" else "warning",
				})
			end,
		})
	end)
end

function Services.errorsPanel(window)
	return openSheet(window, "errorsSheet", Strings.get("Errors"), function(panel)
		local section = panel:Section({ Title = Strings.get("Callbacks that failed") })
		if #window.Errors == 0 then
			section:Label({ Title = Strings.get("Nothing has failed this session."), Style = "Success" })
			return
		end
		for index = #window.Errors, 1, -1 do
			local entry = window.Errors[index]
			section:Accordion({
				Title = `{entry.Title}  ·  {os.date("%H:%M:%S", entry.Time)}`,
				Content = tostring(entry.Trace or entry.Message),
			})
		end
		panel:Section({}):Buttons({
			Buttons = {
				{
					Title = Strings.get("Copy report"),
					Icon = "copy",
					Callback = function()
						Env.copy(Services.report(window))
					end,
				},
				{
					Title = Strings.get("Clear"),
					Icon = "trash-2",
					Variant = "Danger",
					Callback = function()
						window:ClearErrors()
						Services.errorsPanel(window)
					end,
				},
			},
		})
	end)
end

return Services
