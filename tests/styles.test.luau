-- The style registry, presets and the radius, density and text-size settings.
local Internal = Halcyon.Internal
local Styles, Tokens = Internal.Styles, Internal.Tokens

-- Every built-in kind lists its looks, default first.
local sections = Halcyon:GetStyles("Section")
Stub.equal(sections[1], "Card", "the first section look is the default")
for _, name in { "Outlined", "Flat", "Glass", "Accent", "Inset", "Header" } do
	Stub.check(table.find(sections, name) ~= nil, "section look " .. name .. " is registered")
end
Stub.equal(#Halcyon:GetStyles("Navigation"), 4, "the four navigation styles are listed")
Stub.equal(#Halcyon:GetStyles("Minimize"), 3, "the three minimise styles are listed")
Stub.check(table.find(Halcyon:GetStyles("ButtonEffect"), "Ripple") ~= nil, "button effects are listed")
Stub.check(table.find(Halcyon:GetStyles(), "Section") ~= nil, "GetStyles with no kind lists the kinds")
Stub.equal(#Halcyon:GetStyles("NoSuchKind"), 0, "an unknown kind has no looks")

-- AddStyle validates and extends.
local ok = Halcyon:AddStyle("Section", 5, {})
Stub.check(ok == false, "a look needs a string name")
ok = Halcyon:AddStyle("Section", "Bad", "not a table")
Stub.check(ok == false, "a look needs a table")
ok = Halcyon:AddStyle("Section", "Warm", { stroke = "warning" }, "Card")
Stub.check(ok == true, "a look can extend a built-in one")
local warm = Styles.get("Section", "Warm")
Stub.equal(warm.fill, "card", "an extended look keeps the base look's fields")
Stub.equal(warm.stroke, "warning", "and changes the ones given")
Stub.equal(Styles.get("Section", "Card").stroke, "stroke", "extending never changes the base look")
ok = Halcyon:AddStyle("Section", "Orphan", {}, "Missing")
Stub.check(ok == false, "extending a look that does not exist fails")

-- Picking: element, then window default, then the first look; typos fall back.
local window = { styles = { Section = "Flat" } }
local _, name = Styles.pick("Section", "Glass", window)
Stub.equal(name, "Glass", "an element's own look wins")
_, name = Styles.pick("Section", nil, window)
Stub.equal(name, "Flat", "then the window's default")
_, name = Styles.pick("Section", "Glsas", { styles = {} })
Stub.equal(name, "Card", "a misspelt look falls back to the default")

-- The older single options still choose a kind's default; Styles wins.
local chosen = Styles.defaults({ SectionStyle = "Outlined", ToggleThumb = "Oval", Styles = { Section = "Inset" } })
Stub.equal(chosen.Section, "Inset", "a Styles entry wins over SectionStyle")
Stub.equal(chosen.Thumb, "Oval", "ToggleThumb still chooses the thumb")

-- Presets fill in only what the hub left unset.
Stub.equal(Halcyon:GetPresets()[1], "Classic", "Classic is the first preset")
local hub = Halcyon:CreateWindow({ Title = "Preset Hub", Folder = "PresetHub", Preset = "Compact", Radius = "Round", Styles = { Toggle = "Checkbox" } })
Stub.equal(Tokens.names.density, "Compact", "the preset sets the density")
Stub.equal(Tokens.names.radius, "Round", "the hub's own Radius wins over the preset")
Stub.equal(hub.styles.Toggle, "Checkbox", "the hub's own toggle look wins over the preset")
Stub.equal(hub.styles.Section, "Outlined", "the preset's section look fills the gap")
Stub.equal(hub.styles.Slider, "Thin", "the preset's slider look fills the gap")

-- Density and radius reach the rows and corners built after them.
local tab = hub:Tab({ Title = "Movement" })
local section = tab:Section({ Title = "Box", Description = "Explains the box", Badge = 3, IconColor = Color3.new(1, 0, 0), Icon = "star" })
local toggle = section:Toggle({ Title = "Thing" })
local content = toggle.Frame:FindFirstChild("Content")
local limit = content:FindFirstChildOfClass("UISizeConstraint")
Stub.equal(limit.MinSize.Y, 36, "compact rows are 36 tall")
local corner = section.root:FindFirstChildOfClass("UICorner")
Stub.equal(corner.CornerRadius.Offset, 14, "a Round radius makes a 10 px corner 14")
Stub.check(Stub.byText(section.root, "Explains the box") ~= nil, "a section can carry a description")
Stub.check(Stub.byText(section.root, "3") ~= nil, "a section can carry a count badge")
section:SetBadge(nil)
Stub.check(Stub.byText(section.root, "3") == nil, "the badge can be removed")
local icon = Stub.byName(section.header, "Icon")
Stub.equal(icon.ImageColor3, Color3.new(1, 0, 0), "a section icon can be tinted")

-- Each new section look builds.
for _, look in { "Glass", "Accent", "Inset", "Header", "Warm" } do
	local built = tab:Section({ Title = look, Style = look })
	Stub.check(built.root ~= nil, "a " .. look .. " section builds")
end
local accent = tab:Section({ Title = "Edge", Style = "Accent" })
Stub.check(Stub.byName(accent.body, "Edge") ~= nil, "an accent section has its stripe")
accent:SetCollapsed(true)
Stub.check(not Stub.byName(accent.body, "Edge").Visible, "a folded accent section hides its stripe")
accent:SetCollapsed(false)
Stub.check(Stub.byName(accent.body, "Edge").Visible, "an opened accent section shows its stripe again")
local folded = tab:Section({ Title = "Folded", Style = "Accent", Collapsed = true })
Stub.check(not Stub.byName(folded.body, "Edge").Visible, "an accent section that starts folded has no stripe stub")
local banded = tab:Section({ Title = "Band", Style = "Header" })
banded:SetCollapsed(true)
Stub.check(not banded.bandFill.Visible, "a folded header band rounds its lower corners")

-- Large text scales sizes asked for.
hub:Unload()
local big = Halcyon:CreateWindow({ Title = "Big", Folder = "BigHub", TextSize = "Large" })
Stub.equal(Tokens.textScale, 1.15, "Large text scales by 1.15")
local label = big:Tab({ Title = "T" }):Section({ Title = "S" }):Label({ Title = "Hello" })
local text = Stub.byText(label.Frame, "Hello")
Stub.equal(text.TextSize, 15, "a 13 px label becomes 15 px")
big:Unload()
local plain = Halcyon:CreateWindow({ Title = "Plain", Folder = "PlainHub" })
Stub.equal(Tokens.textScale, 1, "a later window without the option is back to normal size")
Stub.equal(Tokens.names.density, "Default", "and normal density")
plain:Unload()
