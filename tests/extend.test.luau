-- Custom element kinds and building a whole hub from one table.

local Create = Halcyon.Internal.Create

-- A counter: a number with a plus button.
Halcyon:RegisterElement("Counter", {
	Options = { Step = "number", Default = "number" },
	Value = "number",
	Build = function(row, options, handle)
		local value = options.Default or 0
		local plus = Create.new("TextButton", { Name = "Plus", Size = UDim2.fromOffset(row.reach, row.reach), Text = "+", Parent = row.slot })
		function handle:Get()
			return value
		end
		function handle:Set(newValue)
			value = tonumber(newValue) or 0
			row.fire(value)
		end
		row.scope:connect(plus.Activated, function()
			handle:Set(value + (options.Step or 1))
		end)
	end,
})

local window = Halcyon:CreateWindow({ Title = "Extend", Folder = "ExtendHub", SavePreferences = false, Debug = true })
local tab = window:Tab({ Title = "Main" })
local section = tab:Section({ Title = "Custom" })
local got = {}
local counter = section:Counter({ Title = "Clicks", Flag = "Clicks", Step = 2, Callback = function(value)
	table.insert(got, value)
end })
Stub.flush()
Stub.click(Stub.byName(counter.Frame, "Plus"))
Stub.equal(counter:Get(), 2, "a custom element works like a built-in one")
Stub.equal(got[1], 2, "its Callback runs")
Stub.equal(window.Flags.Clicks, counter, "it takes a Flag")
Stub.check(window:SaveConfig("custom"), "configs save it")
counter:Set(9)
Stub.check(window:LoadConfig("custom") and counter:Get() == 2, "and load it")
counter:Reset()
Stub.equal(counter:Get(), 0, "Reset works on custom kinds")
local loose = tab:Counter({ Title = "On the tab" })
Stub.check(loose ~= nil, "tabs have the new kind too")
local grouped = section:Group({ Columns = 2 }):Counter({ Title = "In a group" })
Stub.check(grouped ~= nil, "and groups made before or after it was registered")
section:Counter({ Title = "Typo", Stpe = 1 })
local warned = false
for _, line in Stub.warnings do
	if string.find(line, 'Counter "Typo": unknown option "Stpe", did you mean "Step"?', 1, true) then
		warned = true
	end
end
Stub.check(warned, "Debug checks a custom kind's options")
Stub.check(not pcall(Halcyon.RegisterElement, Halcyon, "Toggle", { Build = function() end }), "a built-in kind can't be replaced")
Stub.check(not pcall(Halcyon.RegisterElement, Halcyon, "bad name", { Build = function() end }), "kinds are capitalised words")
window:Unload()
Halcyon:SetDebug(false)

-- Build.
local built, elements = Halcyon:Build({
	Window = { Title = "Built", Folder = "BuiltHub", SavePreferences = false },
	Tabs = {
		{
			Title = "Farm",
			Icon = "sprout",
			Sections = {
				{ Title = "Auto", Elements = {
					{ "Toggle", Title = "Auto farm", Flag = "AutoFarm" },
					{ "Slider", Title = "Range", Flag = "Range", Min = 0, Max = 100, Default = 50 },
				} },
			},
			Pages = {
				{ Title = "Advanced", Sections = { { Title = "Timing", Elements = { { "Stepper", Title = "Delay", Id = "delay" } } } } },
			},
		},
		{ Title = "World", Elements = { { "Button", Title = "Rejoin", Id = "rejoin" } } },
	},
	SettingsTab = true,
})
Stub.flush()
Stub.check(built ~= nil and #built.tabs >= 3, "Build makes the window, its tabs and the settings tab")
Stub.check(elements.AutoFarm ~= nil and elements.Range:Get() == 50, "elements come back by Flag")
Stub.check(elements.delay ~= nil and elements.rejoin ~= nil, "or by Id, pages included")
Stub.equal(#built.subPages, 1, "pages are built")
built:Unload()

local ok, message = pcall(Halcyon.Build, Halcyon, {
	Window = { Title = "Broken", Folder = "BrokenHub", SavePreferences = false },
	Tabs = { { Title = "Farm", Sections = { { Title = "Auto", Elements = { { "Togle", Title = "Fly" } } } } } },
})
Stub.check(not ok and string.find(tostring(message), 'Tabs[1].Sections[1].Elements[1]: unknown kind "Togle", did you mean "Toggle"?', 1, true) ~= nil, "a mistake names where it is: " .. tostring(message))
for _, gui in Stub.guis() do
	if gui.Name ~= "HalcyonOverlay" then
		pcall(function()
			gui:Destroy()
		end)
	end
end
Halcyon:Unload()
