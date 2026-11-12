local Internal = Halcyon.Internal
local Theme, Scope, Signal, Icons, Config, Env = Internal.Theme, Internal.Scope, Internal.Signal, Internal.Icons, Internal.Config, Internal.Env

-- Themes: ten palettes, each readable.
local names = Theme.names()
Stub.equal(#names, 16, "sixteen built-in themes")
for _, name in names do
	local worst, pair = Theme.worstContrast(Theme.palettes[name])
	Stub.check(worst >= 4.5, `{name}: {pair} contrast is {string.format("%.2f", worst)}`)
	for _, status in { "success", "warning", "danger", "info", "accent" } do
		local ratio = Theme.contrast(Theme.palettes[name][status], Theme.palettes[name].card)
		Stub.check(ratio >= 3, `{name}: {status} on card contrast is {string.format("%.2f", ratio)}`)
	end
end

-- Theme binding follows a switch and lets go of destroyed instances.
local frame = Instance.new("Frame")
Theme.bind(frame, "BackgroundColor3", "card")
Stub.equal(frame.BackgroundColor3, Theme.palettes.Midnight.card, "bind applies the current colour")
Stub.check(Theme.set("Daylight"), "set an existing theme")
Stub.equal(frame.BackgroundColor3, Theme.palettes.Daylight.card, "bound property follows a theme switch")
frame:Destroy()
Stub.equal(Theme.bindings[frame], nil, "binding released on destroy")
Stub.check(not Theme.set("Nope"), "unknown theme refused")
Theme.set("Midnight")

-- Custom themes.
local ok, message = Theme.add({ Name = "Broken", background = Color3.new() })
Stub.check(not ok and string.find(message, "missing") ~= nil, "theme missing roles refused")
ok = Theme.add({ Name = "Mine", Base = "Midnight", accent = Color3.fromRGB(255, 120, 40) })
Stub.check(ok, "theme with Base inherits roles")
Stub.equal(Theme.palettes.Mine.text, Theme.palettes.Midnight.text, "inherited role copied")
ok, message = Theme.add({ Name = "Invisible", Base = "Midnight", text = Theme.palettes.Midnight.background })
Stub.check(not ok and string.find(message, "unreadable") ~= nil, "unreadable theme refused")
ok, message = Theme.add({ Name = "Dim", Base = "Midnight", textMuted = Color3.fromHex("6B7280") })
Stub.check(ok and message ~= nil, "low-contrast theme accepted with a warning")
Stub.equal(#Theme.names(), 18, "custom themes listed")

-- Signal and Scope.
local signal, fired = Signal.new(), 0
local connection = signal:Connect(function(amount)
	fired += amount
end)
signal:Fire(2)
connection.Disconnect()
signal:Fire(5)
Stub.equal(fired, 2, "disconnected handler stays silent")

local scope, order = Scope.new(), {}
local owned = Instance.new("Frame")
scope:add(owned)
scope:add(function()
	table.insert(order, "function")
end)
local inner = scope:child()
inner:add(function()
	table.insert(order, "child")
end)
scope:clean()
Stub.equal(table.concat(order, ","), "child,function", "scope cleans newest first")
Stub.check(rawget(owned, "destroyed"), "scope destroys instances")
local late = Instance.new("Frame")
scope:add(late)
Stub.check(rawget(late, "destroyed"), "adding to a cleaned scope releases at once")

-- Icons.
Stub.check(Icons.resolve("settings") ~= nil, "core lucide icon resolves")
Stub.equal(Icons.resolve(123).Image, "rbxassetid://123", "numeric id resolves")
Stub.equal(Icons.resolve("rbxassetid://9").Image, "rbxassetid://9", "content string passes through")
local flat = Icons.parse('return {\n\t["home-bold"] = "rbxassetid://11",\n\t["user-linear"] = "rbxassetid://22",\n}')
Stub.equal(flat["user-linear"], "rbxassetid://22", "flat pack parsed")
local sheet = Icons.parse(
	'return { Spritesheets = { ["1"] = "rbxassetid://77" }, Icons = { accessibility = { Image = 1, ImageRectPosition = Vector2.new(128, 0), ImageRectSize = Vector2.new(128, 128), }, ["arrow-up"] = { Image = 1, ImageRectPosition = Vector2.new(256, 0), ImageRectSize = Vector2.new(128, 128), }, } }'
)
Stub.equal(sheet["arrow-up"].Image, "rbxassetid://77", "sprite pack parsed")
Stub.equal(sheet.accessibility.RectOffset.X, 128, "sprite offset parsed")
local reordered = Icons.parse(
	'return { Spritesheets = { ["1"] = "rbxassetid://88" }, Icons = { ["axis-stroke"] = { ImageRectPosition = Vector2.new(96, 0), ImageRectSize = Vector2.new(96, 96), Image = 1, }, ["with-parts"] = { Image = 1, ImageRectPosition = Vector2.new(0, 0), ImageRectSize = Vector2.new(96, 96), Parts = { [1] = "axis-stroke", }, }, } }'
)
Stub.equal(reordered["axis-stroke"].RectOffset.X, 96, "sprite fields are read in any order")
Stub.check(reordered["with-parts"] ~= nil, "an entry with a nested table is still read")
Stub.equal(Icons.parse("os.exit()"), nil, "a file with no icons is rejected")

local requested
Stub.request = function(options)
	requested = options.Url
	return { StatusCode = 200, Body = 'return {\n\t["rocket-bold"] = "rbxassetid://555",\n}' }
end
local image = Instance.new("ImageLabel")
Stub.check(not Icons.apply(image, "solar:rocket-bold") or image.Image ~= "", "remote icon applies after load")
Stub.equal(image.Image, "rbxassetid://555", "remote pack icon drawn")
Stub.check(string.find(requested, "46d30c19ba7bc601d6ec794a48dc3a89568b1eec/solar", 1, true) ~= nil, "pack fetched from the pinned commit")
Stub.check(Stub.files["Halcyon/cache/icons/solar.lua"] ~= nil, "pack cached on disk")
Stub.request = nil
Stub.check(not Icons.apply(image, "gravity:missing"), "failed pack leaves the icon blank")
Stub.equal(image.Image, "", "blank after failed pack")
Stub.check(#Stub.warnings > 0, "failed pack warns once")
Stub.check(Icons.addPack("mine", { logo = 42 }), "custom pack added")
Stub.equal(Icons.resolve("mine:logo").Image, "rbxassetid://42", "custom pack icon resolves")

-- Config and file safety.
Stub.equal(Env.safeName("../../evil"), "evil", "path traversal stripped from names")
Stub.equal(Env.safeName("///"), nil, "empty name refused")
local config = Config.new("TestHub")
local stored = true
config.flags.Fly = {
	Get = function()
		return stored
	end,
	Set = function(_, value)
		stored = value
	end,
}
Stub.check(config:save("main"), "config saved")
Stub.check(Stub.files["Halcyon/TestHub/configs/main.json"] ~= nil, "config written under the hub folder")
stored = false
config.flags.Removed = nil
Stub.check(config:load("main"), "config loaded")
Stub.equal(stored, true, "loaded value applied through Set")
Stub.equal(config:list()[1], "main", "config listed")
Stub.check(not config:load("absent"), "missing config reported")
Stub.check(config:setAutoload("main"), "autoload set")
Stub.equal(config:getAutoload(), "main", "autoload read back")
Stub.check(config:delete("main"), "config deleted")
Stub.equal(config:getAutoload(), nil, "deleting the autoload config clears autoload")
Stub.equal(Env.executor(), "TestExecutor", "executor name read")
