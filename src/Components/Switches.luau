-- The window's on/off switches in one place: the plainer names CreateWindow
-- accepts, the pieces a switch builds when the window is made, and
-- Window:Set / Window:Get for turning them on and off while the hub runs.

local Lighting = game:GetService("Lighting")

local CommandPalette = require("./CommandPalette")
local Motion = require("../Core/Motion")
local NoticeCenter = require("./NoticeCenter")

local Switches = {}

-- A plainer name a hub may use, and the older one the window still reads.
local ALIASES = { Minimize = "Minimizable", Resize = "Resizable" }

-- How strong the blur behind an open window is when Blur = true.
local BLUR_SIZE = 12

-- Returns a copy of the hub's options with every plain name filled in under
-- the name the window reads, so the hub's own table is never changed.
function Switches.normalize(options)
	local copy = table.clone(options)
	for plain, older in ALIASES do
		if copy[plain] ~= nil and copy[older] == nil then
			copy[older] = copy[plain]
		end
	end
	return copy
end

-- A table of settings, true for the defaults, or nil when switched off.
local function settings(value)
	if value == true then
		return {}
	elseif type(value) == "table" then
		return value
	end
	return nil
end

-- The game behind the window blurs while it is open (Blur = true or a size
-- from 1 to 56). The effect lives in Lighting and leaves with the window.
local function applyBlur(window)
	local wanted = window.blurSize and window.Visible and not window.minimized
	if wanted and not window.blur then
		window.blur = Instance.new("BlurEffect")
		window.blur.Name = "HalcyonBlur"
		window.blur.Size = 0
		window.blur.Parent = Lighting
		window.scope:add(window.blur)
	end
	if window.blur then
		Motion.tween(window.blur, "base", { Size = if wanted then window.blurSize else 0 })
	end
end

local function setBlur(window, value)
	if value == true then
		window.blurSize = BLUR_SIZE
	elseif type(value) == "number" then
		window.blurSize = math.clamp(math.floor(value), 1, 56)
	else
		window.blurSize = nil
	end
	applyBlur(window)
end

-- A HUD piece (Watermark, KeybindList) made from true or a table, or removed.
local function hud(field, build)
	return function(window, value)
		local wanted = settings(value)
		if window[field] then
			window[field]:Destroy()
			window[field] = nil
		end
		if wanted then
			window[field] = build(window, wanted)
		end
	end
end

-- Wraps a setter that only turns something on or off: anything but false
-- and nil counts as on.
local function flag(set)
	return function(window, value)
		set(window, value ~= false and value ~= nil)
	end
end

local SETTERS = {
	Search = flag(function(window, on)
		window.options.Search = on
		if not on and window.searchBox.Text ~= "" then
			window.searchBox.Text = ""
		end
		-- The sidebar header draws its own search box; the top bar's stays hidden.
		if window.sidebarHeader then
			window:buildNav()
		else
			window.topbarSearch.Visible = on
		end
	end),
	Profile = function(window, value)
		if type(value) == "table" then
			local changed = table.clone(value)
			changed.Enabled = true
			window:SetProfile(changed)
		else
			window:SetProfile({ Enabled = value ~= false and value ~= nil })
		end
	end,
	ShowVersion = flag(function(window, on)
		window:SetVersionVisible(on)
	end),
	Minimizable = flag(function(window, on)
		window.options.Minimizable = on
		if window.minimizeButton then
			window.minimizeButton.Visible = on
		end
	end),
	Close = flag(function(window, on)
		window.options.Close = on
		if window.closeButton then
			window.closeButton.Visible = on
		end
	end),
	Resizable = flag(function(window, on)
		window.options.Resizable = on
		if on and not window.grip and not window.library.touch then
			window:buildGrip()
		end
		if window.grip then
			window.grip.Visible = on and not (window.minimized and window.minimizeStyle == "Topbar")
		end
	end),
	Drag = flag(function(window, on)
		window.dragLocked = not on
	end),
	Shadow = flag(function(window, on)
		window.shadowOff = not on
		if on and not window.shadow then
			window:buildShadow()
		elseif window.shadow then
			window.shadow.Visible = on and window.root.Visible
		end
	end),
	Tooltips = flag(function(window, on)
		window.tooltipsOff = not on
	end),
	Animations = flag(function(window, on)
		window:SetReducedMotion(not on)
	end),
	Blur = setBlur,
	CommandPalette = flag(function(window, on)
		window.paletteOff = not on
		if on and not window.paletteBound then
			window.paletteBound = true
			CommandPalette.bind(window)
		end
	end),
	Snap = flag(function(window, on)
		window.options.Snap = on
	end),
	OpenButton = flag(function(window, on)
		window.options.OpenButton = on
		window:refreshVisibility()
	end),
	Watermark = hud("watermark", function(window, options)
		return window:Watermark(options)
	end),
	KeybindList = hud("keybindList", function(window, options)
		return window:KeybindList(options)
	end),
	NotificationCenter = flag(function(window, on)
		if on and not window.noticeButton then
			NoticeCenter.build(window)
		elseif window.noticeButton then
			window.noticeButton.Visible = on
		end
	end),
	SettingsTab = function(window, value)
		local wanted = settings(value)
		if window.settingsTab then
			window.settingsTab:SetVisible(wanted ~= nil)
		elseif wanted then
			window.settingsTab = window:SettingsTab(wanted)
		end
	end,
}

local GETTERS = {
	Search = function(window)
		return window.options.Search ~= false
	end,
	Profile = function(window)
		return window.profile.Enabled ~= false
	end,
	ShowVersion = function(window)
		return window.options.ShowVersion ~= false
	end,
	Minimizable = function(window)
		return window.options.Minimizable ~= false
	end,
	Close = function(window)
		return window.options.Close ~= false
	end,
	Resizable = function(window)
		return window.grip ~= nil and window.grip.Visible
	end,
	Drag = function(window)
		return not window.dragLocked
	end,
	Shadow = function(window)
		return window.shadow ~= nil and not window.shadowOff
	end,
	Tooltips = function(window)
		return not window.tooltipsOff
	end,
	Animations = function()
		return not Motion.reduced
	end,
	Blur = function(window)
		return window.blurSize ~= nil
	end,
	CommandPalette = function(window)
		return window.paletteBound == true and not window.paletteOff
	end,
	Snap = function(window)
		return window.options.Snap == true
	end,
	OpenButton = function(window)
		return window.options.OpenButton == true
	end,
	Watermark = function(window)
		return window.watermark ~= nil
	end,
	KeybindList = function(window)
		return window.keybindList ~= nil
	end,
	SettingsTab = function(window)
		return window.settingsTab ~= nil and not window.settingsTab.Hidden
	end,
	NotificationCenter = function(window)
		return window.noticeButton ~= nil and window.noticeButton.Visible
	end,
}

-- Lets other modules add a switch of their own (the notice centre, the header).
function Switches.define(name, set, get)
	SETTERS[name], GETTERS[name] = set, get
end

local function canonical(name)
	return ALIASES[name] or name
end

-- Every switch name Window:Set accepts, sorted, for docs and the example.
function Switches.names()
	local names = {}
	for name in SETTERS do
		table.insert(names, name)
	end
	for plain in ALIASES do
		table.insert(names, plain)
	end
	table.sort(names)
	return names
end

function Switches.set(window, name, value)
	local set = SETTERS[canonical(name)]
	if not set then
		warn(`[Halcyon] Window:Set doesn't know the switch "{tostring(name)}".`)
		return false
	end
	set(window, value)
	return true
end

function Switches.get(window, name)
	local get = GETTERS[canonical(name)]
	if not get then
		return nil
	end
	return get(window)
end

-- What a switch builds when the window is made. The settings tab waits for
-- the hub's own tabs, so it comes after them in the navigation.
function Switches.build(window)
	local options = window.options
	window.dragLocked = options.Drag == false
	window.tooltipsOff = options.Tooltips == false
	if options.Blur then
		setBlur(window, options.Blur)
		window.scope:connect(window.root:GetPropertyChangedSignal("Visible"), function()
			applyBlur(window)
		end)
	end
	if options.NotificationCenter then
		NoticeCenter.build(window)
	end
	if options.Watermark then
		SETTERS.Watermark(window, options.Watermark)
	end
	if options.KeybindList then
		SETTERS.KeybindList(window, options.KeybindList)
	end
	if settings(options.SettingsTab) then
		task.defer(function()
			if not window.scope.cleaned and not window.settingsTab then
				SETTERS.SettingsTab(window, options.SettingsTab)
			end
		end)
	end
end

Switches.applyBlur = applyBlur

return Switches
