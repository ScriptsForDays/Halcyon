-- Moving backgrounds on the window and on sections: built from tweens,
-- paused while hidden, still under reduced motion, recoloured by themes.

local window = Halcyon:CreateWindow({ Title = "Moving", Folder = "MovingHub", SavePreferences = false, Background = { Kind = "Aurora", Intensity = 0.4 } })
Stub.flush()
local backdrop = Stub.byName(window.root, "MovingBackground")
Stub.check(backdrop ~= nil and backdrop.ClassName == "CanvasGroup", "Background puts a moving layer in the window")
Stub.equal(backdrop.ZIndex, 0, "behind the content")
Stub.check(math.abs(backdrop.GroupTransparency - 0.6) < 1e-6, "Intensity sets how strongly it shows")
local blobs = 0
for _, child in backdrop:GetChildren() do
	if child.Name == "Blob" then
		blobs += 1
	end
end
Stub.equal(blobs, 3, "Aurora drifts three blobs")

-- Each kind builds.
for _, kind in { "Gradient", "Mesh", "Pattern", "Image" } do
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
card:SetBackground(false)
Stub.equal(Stub.byName(card.root, "MovingBackground"), nil, "and lose it")

-- Theme changes recolour it.
window:SetBackground({ Kind = "Pattern", Colors = { "accent" } })
local lines = Stub.byName(window.root, "MovingBackground")
Halcyon:SetTheme("Rose")
Stub.equal(lines.BackgroundColor3, Halcyon.Internal.Theme.color("accent"), "a theme change recolours it")
Halcyon:SetTheme("Midnight")
window:Unload()
