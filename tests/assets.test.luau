-- Custom images, Discord buttons, the top-bar image and the update log.
local Internal = Halcyon.Internal
local Assets = Internal.Assets
local URL = "https://cdn.example.com/art/logo.png?size=64"

local downloads = 0
Stub.request = function(options)
	if options.Url == URL then
		downloads += 1
		return { StatusCode = 200, Body = "PNGDATA" }
	elseif options.Url == "https://cdn.example.com/huge.png" then
		return { StatusCode = 200, Body = string.rep("x", Assets.MAX_BYTES + 1) }
	end
	return { StatusCode = 404, Body = "" }
end

-- Kinds and safety.
Stub.equal(Assets.kind(123), "asset", "a number is an asset id")
Stub.equal(Assets.kind("rbxassetid://5"), "asset", "an rbxassetid passes through")
Stub.equal(Assets.kind(URL), "url", "an https link is a URL")
Stub.equal(Assets.kind("ftp://example.com/a.png"), nil, "other schemes are not images")
Stub.equal(Assets.kind("logos/hub.png"), "file", "a workspace image path is a file")
Stub.equal(Assets.kind("house"), nil, "an icon name is left to the icon packs")
Stub.equal(Assets.safePath("../secret.png"), nil, "a path cannot climb out of the workspace")
Stub.equal(Assets.safePath("C:/Windows/a.png"), nil, "nor point at a drive")
Stub.equal(Assets.safePath("logos/hub.png"), "logos/hub.png", "a plain workspace path is fine")
Stub.check(string.find(Assets.cachePath(URL), "^Halcyon/assets/%x+%.png$") ~= nil, "downloads are cached under Halcyon/assets with their extension")

-- A URL downloads once, then comes from the cache.
local got
Stub.equal(Halcyon:Image(URL, function(id)
	got = id
end), nil, "a URL is not ready at once")
Stub.flush()
Stub.check(got ~= nil and string.find(got, "^rbxasset://custom/Halcyon/assets/") ~= nil, "it loads through getcustomasset")
Stub.equal(Halcyon:Image(URL), got, "the second ask is answered from memory")
Assets.reset()
Halcyon:Image(URL, function() end)
Stub.flush()
Stub.equal(downloads, 1, "and a fresh run reads the file it saved instead of downloading again")
local tooBig
Halcyon:Image("https://cdn.example.com/huge.png", function(id, problem)
	tooBig = problem
end)
Stub.flush()
Stub.check(tooBig ~= nil and string.find(tooBig, "5 MB", 1, true) ~= nil, "an image over 5 MB is refused")
local refused
Halcyon:Image("../outside.png", function(id, problem)
	refused = problem
end)
Stub.check(refused ~= nil, "a file outside the workspace is refused with a reason")

-- Any image slot takes a URL.
local window = Halcyon:CreateWindow({
	Title = "Asset Hub",
	Folder = "AssetHub",
	TopbarImage = URL,
	TopbarImageStyle = "Ring",
	Profile = { Discord = "https://discord.gg/example" },
	UpdateLog = { Popup = true, Updates = {
		{ Version = "1.2.0", Title = "Faster farming", Date = "2026-11-01", Entries = { { Kind = "New", Text = "Auto replant" }, { Kind = "Fixed", Text = "Crop counter" } } },
		{ Version = "1.10.0", Title = "Shop rework", Entries = { "Bulk buy", { Kind = "Security", Text = "Rate limit purchases" } } },
	} },
})
local farm = window:Tab({ Title = "Farming" })
local picture = farm:Section({ Title = "Art" }):Image({ Image = URL })
Stub.flush()
Stub.check(string.find(Stub.byName(picture.Frame, "Image").Image, "rbxasset://custom/", 1, true) ~= nil, "the Image element shows a URL image")

-- Top-bar image.
local topbar = window.topbarImage
Stub.check(topbar ~= nil and string.find(topbar.Image, "rbxasset://custom/", 1, true) ~= nil, "TopbarImage shows the hub's picture")
Stub.check(topbar:FindFirstChildOfClass("UIStroke") ~= nil, "the Ring look outlines it")
for _, look in Halcyon:GetStyles("TopbarImage") do
	local test = Halcyon:CreateWindow({ Title = "Look " .. look, Folder = "Look" .. look, TopbarImage = "rbxassetid://1", TopbarImageStyle = look })
	Stub.check(test.topbarImage ~= nil, "top-bar image look " .. look .. " builds")
	test:Unload()
end
local plainWindow = Halcyon:CreateWindow({ Title = "Plain", Folder = "PlainTop", Icon = "sparkles", TopbarImage = false })
Stub.check(plainWindow.topbarImage == nil, "TopbarImage = false keeps the plain icon")
plainWindow:Unload()

-- Discord on the profile card.
Stub.genv.setclipboard = function(text)
	Stub.clipboard = text
end
local discord = Stub.byName(window.root, "Discord")
Stub.check(discord ~= nil, "the profile card shows a Discord button")
Stub.click(discord)
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "pressing it copies the invite")

-- Update log.
Stub.flush()
local log = window.updateLog
Stub.check(log ~= nil, "UpdateLog = { ... } builds the log")
Stub.equal(window.tabs[#window.tabs], log.tab, "the log tab comes after the hub's own tabs")
Stub.equal(log.updates[1].Version, "1.10.0", "releases are ordered by version number, 1.10 before 1.2")
Stub.equal(log.sections[1].collapsed, false, "the newest release is open")
Stub.equal(log.sections[2].collapsed, true, "older ones start folded")
Stub.check(Stub.byText(log.sections[1].root, "LATEST") ~= nil, "the newest is marked Latest")
Stub.check(Stub.byText(log.sections[1].root, "SECURITY") ~= nil, "changes are grouped by kind")
Stub.equal(log.tab.badge, "New", "an unseen release badges the tab")
window:SelectTab(log.tab)
Stub.equal(log.tab.badge, nil, "opening the tab clears it")
Stub.equal(window.updateSeen, "1.10.0", "and remembers the release")
log.chips:Set("Fixed")
Stub.check(log.sections[1].Hidden, "filtering hides releases without that kind")
Stub.check(not log.sections[2].Hidden, "and keeps those with it")
log.chips:Set("All")
window:AddUpdate({ Version = "1.11.0", Title = "Hotfix", Entries = { { Kind = "Fixed", Text = "Crash on join" } } })
Stub.equal(log.updates[1].Version, "1.11.0", "AddUpdate puts a newer release on top")
Stub.equal(log.tab.badge, nil, "while the tab is open no badge is needed")
local overlay
for _, gui in Stub.guis() do
	overlay = overlay or Stub.byName(gui, "Dialog")
end
Stub.check(overlay ~= nil, "Popup = true shows the newest release once as What's new")
window:Unload()

local quiet = Halcyon:CreateWindow({ Title = "Quiet", Folder = "QuietHub", UpdateLog = false })
Stub.flush()
Stub.check(quiet.updateLog == nil, "UpdateLog = false builds nothing")
quiet:AddUpdate({ Version = "1.0" })
Stub.check(#Stub.warnings > 0, "AddUpdate without a log warns instead of failing")
quiet:Unload()

-- Without getcustomasset a URL image shows the fallback icon.
Stub.noAssets = true
Assets.reset()
local fallback = Halcyon:CreateWindow({ Title = "Fallback", Folder = "FallbackHub", TopbarImage = "https://cdn.example.com/other.png" })
Stub.flush()
Stub.equal(fallback.topbarImage:GetAttribute("HalcyonIcon"), "https://cdn.example.com/other.png", "the label still remembers what it asked for")
Stub.check(fallback.topbarImage.Image ~= "", "and shows the fallback icon instead of nothing")
fallback:Unload()
Stub.noAssets = false
