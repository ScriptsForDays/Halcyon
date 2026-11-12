-- New themes, live personalisation, saved choices, the theme builder,
-- gradient accents, colour-blind-friendly status colours and the focus ring.
local Internal = Halcyon.Internal
local Theme, Tokens = Internal.Theme, Internal.Tokens
local GuiService = game:GetService("GuiService")

for _, name in { "OLED", "Contrast", "Sunset", "Ocean", "Aurora", "Latte" } do
	Stub.check(table.find(Halcyon:GetThemes(), name) ~= nil, name .. " is a built-in theme")
	local worst = Theme.worstContrast(Theme.palettes[name])
	Stub.check(worst >= 4.5, name .. " keeps every text role readable")
end

local window = Halcyon:CreateWindow({ Title = "Personal Hub", Folder = "PersonalHub" })
local tab = window:Tab({ Title = "Combat" })
local section = tab:Section({ Title = "Aim" })
local toggle = section:Toggle({ Title = "Silent aim" })
local slider = section:Slider({ Title = "Field of view", Min = 0, Max = 100, Default = 50 })

-- Text size changes everything on screen at once.
local title = Stub.byName(toggle.Frame, "Title")
local before = title.TextSize
Stub.check(window:SetPersonal("TextSize", "Larger"), "Larger is a text size")
Stub.equal(title.TextSize, math.round(before * 1.3), "text on screen grows")
window:SetPersonal("TextSize", "Default")
Stub.equal(title.TextSize, before, "and returns to its size")
Stub.check(not window:SetPersonal("TextSize", "Huge"), "an unknown size is refused")

-- Corners and spacing retune what is already drawn.
local corner = section.root:FindFirstChildOfClass("UICorner")
window:SetPersonal("Radius", "Sharp")
Stub.equal(corner.CornerRadius.Offset, 3, "sharp corners shrink a 10 px corner")
window:SetPersonal("Radius", "Default")
Stub.equal(corner.CornerRadius.Offset, 10, "and put it back")
local minimum = Stub.byName(toggle.Frame, "Content"):FindFirstChildOfClass("UISizeConstraint")
window:SetPersonal("Density", "Spacious")
Stub.equal(minimum.MinSize.Y, 52, "spacious rows are taller")
window:SetPersonal("Density", "Default")

-- Font, transparency and notice position.
Stub.check(window:SetPersonal("Font", "Inter"), "Inter can be picked")
Stub.check(not window:SetPersonal("Font", 12), "a font that is not a name is refused")
local SEE_THROUGH = 0.3
window:SetPersonal("Transparency", SEE_THROUGH)
Stub.equal(window.root.BackgroundTransparency, SEE_THROUGH, "the window can be made see-through")
Stub.check(window:SetPersonal("NoticePosition", "TopLeft"), "notices can move")
Stub.check(not window:SetPersonal("NoticePosition", "Middle"), "to the six places only")

-- Gradient accent and safe status colours.
window:SetPersonal("AccentGradient", true)
local fill = Stub.byName(slider.Frame, "Fill")
local gradient = fill:FindFirstChild("AccentGradient")
Stub.check(gradient ~= nil and gradient.Enabled, "a gradient accent reaches slider fills")
window:SetPersonal("AccentGradient", false)
Stub.check(not gradient.Enabled, "and turns off again")
Stub.equal(fill.BackgroundColor3, Theme.color("accent"), "leaving the fill in the accent colour")
local success = Theme.color("success")
window:SetPersonal("SafeStatus", true)
Stub.check(Theme.color("success") ~= success, "colour-blind friendly status colours replace green")
window:SetPersonal("SafeStatus", false)
Stub.equal(Theme.color("success"), success, "and can be turned off")

-- Saved and restored.
window:SetPersonal("TextSize", "Large")
window:SetPersonal("Radius", "Round")
Stub.advance(1)
local saved = Stub.files["Halcyon/PersonalHub/settings.json"]
Stub.check(saved ~= nil and string.find(saved, '"TextSize":"Large"', 1, true) ~= nil, "the player's choices are saved")

-- Theme builder: save, export and import.
local settings = window:SettingsTab({ Personalise = true, ThemeBuilder = true })
Stub.check(Stub.byText(settings.page, "Theme builder") ~= nil, "the theme builder is offered when asked for")
Stub.check(Stub.byText(settings.page, "Colour-blind friendly") ~= nil, "the personalise rows are offered when asked for")
local Personalise = Internal.Personalise
local custom = table.clone(Theme.palettes.Midnight)
custom.Name = "Mine"
custom.accent = Color3.fromRGB(255, 0, 128)
Stub.check(Personalise.saveTheme(window, custom), "a player theme saves")
local shared = Personalise.exportTheme("Mine")
Stub.check(type(shared) == "string" and string.find(shared, "ff0080", 1, true) ~= nil, "a theme exports as text with its colours")
local copy = string.gsub(shared, '"Mine"', '"Mine copy"')
Stub.check(Personalise.importTheme(window, copy), "pasted text imports as a theme")
Stub.check(table.find(Halcyon:GetThemes(), "Mine copy") ~= nil, "and joins the theme list")
local refused, why = Personalise.importTheme(window, "not json")
Stub.check(not refused and type(why) == "string", "text that is not a theme is refused with a reason")
local unreadable = table.clone(Theme.palettes.Midnight)
unreadable.Name = "Unreadable"
unreadable.text = unreadable.background
Stub.check(not Personalise.saveTheme(window, unreadable), "a theme nobody could read is refused")
Stub.advance(1)
window:Unload()

local reopened = Halcyon:CreateWindow({ Title = "Personal Hub", Folder = "PersonalHub" })
Stub.equal(Tokens.names.text, "Large", "a reopened hub restores the player's text size")
Stub.equal(Tokens.names.radius, "Round", "and corners")
Stub.equal(reopened.root.BackgroundTransparency, SEE_THROUGH, "and see-through amount")
Stub.check(table.find(Halcyon:GetThemes(), "Mine") ~= nil, "and the themes they made")

-- Focus ring.
local tabTwo = reopened:Tab({ Title = "Visuals" })
local row = tabTwo:Section({ Title = "ESP" }):Toggle({ Title = "Boxes" })
Stub.check(row.Frame.SelectionImageObject ~= nil and row.Frame.SelectionImageObject.Name == "FocusRing", "selectable rows use the accent focus ring")
game:GetService("UserInputService").InputBegan:Fire({ KeyCode = Enum.KeyCode.ButtonSelect, UserInputType = Enum.UserInputType.Gamepad1 }, false)
Stub.check(not reopened.Visible, "the gamepad's Select button hides the window")
game:GetService("UserInputService").InputBegan:Fire({ KeyCode = Enum.KeyCode.ButtonSelect, UserInputType = Enum.UserInputType.Gamepad1 }, false)
Stub.check(reopened.Visible and GuiService.SelectedObject == reopened.selected.button, "and shows it with the selection on the open tab")
reopened:Unload()
Tokens.reset()
