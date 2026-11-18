-- Moving backgrounds on the window and on sections: built from tweens,
-- paused while hidden, still under reduced motion, recoloured by themes.

local window = Halcyon:CreateWindow({ Title = "Moving", Folder = "MovingHub", SavePreferences = false, Background = { Kind = "Aurora", Intensity = 0.4 } })
Stub.flush()
local backdrop = Stub.byName(window.root, "MovingBackground")
Stub.check(backdrop ~= nil and backdrop.ClassName == "CanvasGroup", "Background puts a moving layer in the window")
Stub.equal(backdrop.ZIndex, 0, "behind the content")
Stub.check(math.abs(backdrop.GroupTransparency - 0.6) < 1e-6, "Intensity sets how strongly it shows")
local function count(layer, name)
	local found = 0
	for _, child in layer:GetChildren() do
		if child.Name == name then
			found += 1
		end
	end
	return found
end
Stub.equal(count(backdrop, "Light"), 4, "Aurora behind the window drifts four fields of light")
Stub.equal(count(backdrop, "Vignette"), 2, "the window's background shades its edges by default")
window:SetBackground({ Kind = "Aurora", Sheen = true, Vignette = false })
local sheened = Stub.byName(window.root, "MovingBackground")
Stub.check(Stub.byName(sheened, "Sheen") ~= nil and count(sheened, "Vignette") == 0, "Sheen and Vignette are options")

-- Each kind builds.
for _, kind in { "Glow", "Gradient", "Mesh", "Pattern", "Image" } do
	window:SetBackground({ Kind = kind, Colors = { "accent", Color3.fromRGB(255, 0, 0) } })
	Stub.check(window.movingBackground ~= nil and window.movingBackground.Kind == kind, kind .. " builds")
end
window:SetBackground(nil)
Stub.equal(Stub.byName(window.root, "MovingBackground"), nil, "SetBackground(nil) removes it")

-- Sections.
local tab = window:Tab({ Title = "Farm" })
local card = tab:Section({ Title = "Stats", Background = { Kind = "Gradient" } })
Stub.flush()
Stub.check(Stub.byName(card.body, "MovingBackground") ~= nil, "a section can have one too")
card:SetBackground({ Kind = "Glow" })
local inner = Stub.byName(card.body, "MovingBackground")
Stub.equal(count(inner, "Light"), 2, "Glow has a light the pointer leads and a faint field behind it")
Stub.equal(count(inner, "Vignette"), 0, "sections leave the edges unshaded unless asked")
card:SetBackground(false)
Stub.equal(Stub.byName(card.root, "MovingBackground"), nil, "and lose it")

-- Solid cards let a window background through, and go solid again without one.
Stub.check(math.abs(card.root.BackgroundTransparency - 0) < 1e-6, "no window background, solid card")
window:SetBackground({ Kind = "Aurora", SeeThrough = 0.4 })
Stub.check(math.abs(card.root.BackgroundTransparency - 0.4) < 1e-6, "SeeThrough lets the background show through cards")
local later = tab:Section({ Title = "Later" })
Stub.check(math.abs(later.root.BackgroundTransparency - 0.4) < 1e-6, "cards made afterwards match")
window:SetBackground(nil)
Stub.check(card.root.BackgroundTransparency == 0, "removing the background makes cards solid again")

-- Theme changes recolour it.
window:SetBackground({ Kind = "Pattern", Colors = { "accent" } })
local lines = Stub.byName(window.root, "MovingBackground")
Halcyon:SetTheme("Rose")
Stub.equal(lines.BackgroundColor3, Halcyon.Internal.Theme.color("accent"), "a theme change recolours it")
Halcyon:SetTheme("Midnight")
window:Unload()
