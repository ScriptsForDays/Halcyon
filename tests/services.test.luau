-- The update check, the executor support panel and the errors panel.

-- An update address answering with JSON.
local asked
Stub.request = function(options)
	asked = options.Url
	return { StatusCode = 200, Body = '{"version":"1.4.0","notes":"Faster farming"}' }
end
local heard = {}
local window = Halcyon:CreateWindow({
	Title = "Services",
	Folder = "ServiceHub",
	SavePreferences = false,
	Version = "1.3.2",
	UpdateCheck = {
		Url = "https://example.com/version.json",
		OnUpdate = function(latest, notes)
			table.insert(heard, { latest, notes })
		end,
	},
})
Stub.advance(1.5)
Stub.equal(asked, "https://example.com/version.json", "the hub asks its update address after opening")
Stub.equal(heard[1] and heard[1][1], "1.4.0", "OnUpdate hears the newer version")
Stub.equal(heard[1] and heard[1][2], "Faster farming", "with its notes")
Stub.check(Stub.find(game:GetService("Players").LocalPlayer.PlayerGui, function(instance)
	return instance.Text == "Update available"
end) ~= nil, "and the player gets a notice")

-- Plain text, and the same version, are fine too.
Stub.request = function()
	return { StatusCode = 200, Body = "1.3.2\n" }
end
local ok, latest = window:CheckForUpdate()
Stub.check(ok and latest == nil, "the same version is not an update")
Stub.request = function()
	return { StatusCode = 200, Body = "1.10.0" }
end
ok, latest = window:CheckForUpdate()
Stub.check(ok and latest == "1.10.0", "1.10 is newer than 1.3.2")
Stub.request = function()
	return { StatusCode = 500, Body = "" }
end
ok = window:CheckForUpdate()
Stub.check(not ok, "a failed request reports failure")
Stub.request = nil

-- Support panel.
local tab = window:Tab({ Title = "Combat" })
tab:Toggle({ Title = "Silent aim", Requires = { "hookmetamethod" } })
Stub.flush()
local panel = window:SupportPanel()
Stub.flush()
Stub.check(panel.IsOpen, "the support panel opens")
Stub.check(Stub.byText(panel.layer or window.body, "hookmetamethod") ~= nil, "it lists the functions it checked")
Stub.check(Stub.find(window.body, function(instance)
	return instance.Text == "Silent aim"
end) ~= nil, "and the rows locked for this executor")

-- Errors panel.
tab:Button({ Title = "Broken", Callback = function()
	error("no target")
end }):Press()
Stub.flush()
local errors = window:ErrorsPanel()
Stub.flush()
Stub.check(errors.IsOpen, "the errors panel opens")
Stub.check(Stub.find(window.body, function(instance)
	return type(instance.Text) == "string" and string.find(instance.Text, "Broken", 1, true) == 1
end) ~= nil, "it lists each failed callback")
window:Unload()
