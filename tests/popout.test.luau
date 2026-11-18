-- Popped-out sections: the rows move into their own panel, stay working
-- while the hub is hidden, resize from the corner, and come back.

local window = Halcyon:CreateWindow({ Title = "Panels", Folder = "PopHub" })
local tab = window:Tab({ Title = "Farm" })
local stats = tab:Section({ Title = "Stats", PopOut = true })
local coins = stats:Toggle({ Title = "Auto collect", Flag = "Collect" })
Stub.flush()

local button = Stub.byName(stats.root, "PopOutButton")
Stub.check(button ~= nil, "PopOut = true puts a button in the header")
Stub.click(button)
Stub.flush()
Stub.check(stats:IsPoppedOut(), "pressing it pops the section out")
local panel = stats.panel
Stub.check(panel ~= nil and coins.Frame:IsDescendantOf(panel), "the rows now live in the panel")
Stub.check(Stub.byName(stats.root, "PoppedOut") ~= nil, "the section shows where they went")
coins:Set(true)
Stub.equal(coins:Get(), true, "the rows still work from the panel")
window:Hide()
Stub.flush()
Stub.check(panel.Parent ~= nil and panel:IsDescendantOf(window.library.overlay.gui), "the panel stays while the hub is hidden")
window:Show()

-- The corner grip resizes with the top-left corner fixed.
panel.Position = UDim2.fromOffset(100, 100)
local grip = Stub.byName(panel, "Resize")
local before = panel.Size
Stub.drag(grip, Vector2.new(400, 380), { Vector2.new(460, 420) })
Stub.equal(panel.Size.X.Offset, before.X.Offset + 60, "dragging the grip widens the panel by the pointer's travel")
Stub.equal(panel.Size.Y.Offset, before.Y.Offset + 40, "and heightens it the same")
Stub.equal(panel.Position, UDim2.fromOffset(100, 100), "the top-left corner stays put")

-- Remembered, then docked.
Stub.advance(1)
window:Unload()
local again = Halcyon:CreateWindow({ Title = "Panels", Folder = "PopHub" })
local tab2 = again:Tab({ Title = "Farm" })
local stats2 = tab2:Section({ Title = "Stats", PopOut = true })
stats2:Toggle({ Title = "Auto collect", Flag = "Collect" })
Stub.flush()
Stub.check(stats2:IsPoppedOut(), "a section that was out comes out again")
Stub.equal(stats2.panel.Size.X.Offset, before.X.Offset + 60, "at the size it had")
stats2:PopOut(false)
Stub.flush()
Stub.check(not stats2:IsPoppedOut() and stats2.body.Parent == stats2.root, "PopOut(false) puts the rows back")
Stub.equal(Stub.byName(stats2.root, "PoppedOut"), nil, "and removes the note")
again:Unload()

-- A section's moving background goes with it: it fills the panel, is laid
-- out again as the panel is resized, and keeps moving while another tab is
-- open, since the panel is still on screen.
local third = Halcyon:CreateWindow({ Title = "Panels", Folder = "PopHubBackground", SavePreferences = false })
local farm = third:Tab({ Title = "Farm" })
local other = third:Tab({ Title = "Other" })
local live = farm:Section({ Title = "Live", PopOut = true, Background = { Kind = "Glow" } })
live:Toggle({ Title = "Auto collect" })
Stub.flush()
local layer = Stub.byName(live.body, "MovingBackground")
live:PopOut(true)
Stub.flush()
Stub.equal(layer.Parent, live.panel, "a popped-out section's background fills its panel")
Stub.place(live.panel, 0, 0, 320, 300)
Stub.flush()
local light = Stub.byName(layer, "Light")
local narrow = light.Size.X.Offset
Stub.place(live.panel, 0, 0, 480, 420)
Stub.flush()
Stub.check(narrow > 0 and light.Size.X.Offset > narrow, "and is laid out again when the panel is resized")
third:SelectTab(other)
Stub.flush()
Stub.check(layer.Visible, "it keeps showing while another tab is open")
live:PopOut(false)
Stub.flush()
Stub.equal(layer.Parent, live.body, "docking puts it back in the section")
Stub.check(not layer.Visible, "where it rests while its tab is hidden")
third:Unload()

-- In the card the pieces fill the rows, not the layer, so lights laid out
-- for a tall panel can't hold the card open once it is docked again, and a
-- folded section hides its background with its rows.
local fourth = Halcyon:CreateWindow({ Title = "Panels", Folder = "PopHubDock", SavePreferences = false })
local docked = fourth:Tab({ Title = "Farm" }):Section({ Title = "Live", PopOut = true, Collapsible = true, Background = { Kind = "Glow" } })
docked:Toggle({ Title = "Auto collect" })
Stub.flush()
local glow = Stub.byName(docked.body, "MovingBackground")
docked:PopOut(true)
Stub.flush()
Stub.place(docked.panel, 0, 0, 300, 600)
Stub.flush()
local tall = Stub.byName(glow, "Light").Size.Y.Offset
docked:PopOut(false)
Stub.place(docked.rows, 0, 0, 300, 120)
Stub.flush()
Stub.check(tall >= 600 and Stub.byName(glow, "Light").Size.Y.Offset <= 120, "docked, the lights fit the rows again")
docked:SetCollapsed(true)
Stub.flush()
Stub.check(not glow.Visible, "a folded section hides its background")
docked:SetCollapsed(false)
Stub.flush()
Stub.check(glow.Visible, "and shows it again when opened")
fourth:Unload()
