-- Notices: the Accent edge, the close button, hover pausing the countdown,
-- swiping a card away, the waiting count and the history the notice centre
-- reads.
local Internal = Halcyon.Internal
local Theme, library = Internal.Theme, Internal.library
local UserInputService = game:GetService("UserInputService")

local function holder()
	return library.toasts.holder
end

-- Accent: the card is the notice's colour; the panel sits a few pixels in.
local accent = Halcyon:Notify({ Title = "Saved", Content = "Written to disk.", Style = "Accent", Kind = "success", Duration = 0 })
local card = Stub.byName(holder(), "Card")
local panel = Stub.byName(card, "Panel")
Stub.equal(card.BackgroundColor3, Theme.color("success"), "an Accent card is filled with the notice's colour")
Stub.check(panel ~= nil and panel.Position.X.Offset > 0, "its panel sits in from the left, leaving a coloured edge")
Stub.equal(panel.Size.Y.Scale, 0, "the panel grows with its words, not with the card")
Stub.check(Stub.byName(card, "Edge") == nil, "there is no separate stripe any more")
accent.Dismiss()
Stub.advance(1)

-- The close button.
local closable = Halcyon:Notify({ Title = "Closable", Duration = 0 })
local close = Stub.byName(holder(), "Close")
Stub.check(close ~= nil, "a card has a close button")
Stub.click(close)
Stub.check(closable.done, "pressing it dismisses the notice")
Stub.advance(1)
Halcyon:Notify({ Title = "No close", Duration = 0, Close = false })
Stub.check(Stub.byName(holder(), "Close") == nil, "Close = false leaves it out")
for _, toast in table.clone(library.toasts.active) do
	toast.Dismiss()
end
Stub.advance(1)

-- Hovering pauses the countdown.
local paused = Halcyon:Notify({ Title = "Hold on", Duration = 2 })
local hovered = Stub.byName(holder(), "Card")
hovered.MouseEnter:Fire()
Stub.advance(3)
Stub.check(not paused.done, "a hovered notice waits")
hovered.MouseLeave:Fire()
Stub.advance(2.2)
Stub.check(paused.done, "and leaves once the pointer moves off")
Stub.advance(1)

-- Swiping a card sideways dismisses it; a short drag springs back.
local swiped = Halcyon:Notify({ Title = "Swipe me", Duration = 0 })
local target = Stub.byName(holder(), "Card")
local press = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(100, 10, 0) }
target.InputBegan:Fire(press)
UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(120, 10, 0) })
UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(120, 10, 0) })
Stub.flush()
Stub.check(not swiped.done, "a short drag leaves the notice where it was")
target.InputBegan:Fire(press)
UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(220, 10, 0) })
UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(220, 10, 0) })
Stub.flush()
Stub.check(swiped.done, "a long drag sideways dismisses it")
Stub.advance(1)

-- More notices than fit: the rest wait, and the stack says how many.
Halcyon:SetNotificationDefaults({ MaxVisible = 2 })
local first = Halcyon:Notify({ Title = "One", Duration = 0 })
Halcyon:Notify({ Title = "Two", Duration = 0 })
Halcyon:Notify({ Title = "Three", Duration = 0 })
Halcyon:Notify({ Title = "Four", Duration = 0 })
local more = library.toasts.more
Stub.check(more.Visible and more.Text == "+2 more", "the stack shows how many are waiting")
first.Dismiss()
Stub.equal(more.Text, "+1 more", "the count drops as one moves up")
for _, toast in table.clone(library.toasts.active) do
	toast.Dismiss()
end
for _, toast in table.clone(library.toasts.active) do
	toast.Dismiss()
end
Stub.check(not more.Visible, "and hides when nothing waits")
Halcyon:SetNotificationDefaults({ MaxVisible = 4 })
Stub.advance(1)

-- Progress: no amount yet, then one.
local job = Halcyon:Notify({ Title = "Loading map", Style = "Progress", Indeterminate = true })
Stub.equal(Stub.byName(holder(), "Fill").Size.X.Scale, 0.3, "an indeterminate bar runs a short piece across")
job.SetProgress(0.4)
Stub.advance(1)
Stub.equal(Stub.byName(holder(), "Fill").Size.X.Scale, 0.4, "it shows the amount once one is given")
job.Complete("Map loaded")
Stub.check(Stub.byText(holder(), "Map loaded") ~= nil, "Complete is another name for Done")
Stub.advance(4)

-- Content given later shows on a card that started without any.
local later = Halcyon:Notify({ Title = "Joining", Duration = 0 })
later.SetContent("Server 4")
Stub.check(Stub.byText(holder(), "Server 4") ~= nil, "SetContent fills in content on any card")
later.Dismiss()
Stub.advance(1)

-- Island and Snackbar keep their dark fill in a light theme.
Halcyon:SetTheme("Daylight")
Halcyon:Notify({ Title = "Connected", Style = "Island", Duration = 0 })
local island = Stub.byName(library.toasts.island, "Card")
Stub.check(island.BackgroundColor3.R < 0.2, "an Island stays dark in a light theme")
Halcyon:SetTheme("Midnight")

-- History for the notice centre: newest first, with an unread count.
local log = Internal.Notifications.history(library)
Stub.check(#log.entries >= 10, "every notice is kept in the history")
Stub.equal(log.entries[1].title, "Connected", "newest first")
Stub.check(log.unread >= 10, "and counted as unread until the centre is opened")

-- The notice centre: a bell with the unread count, a list, and Clear all.
local hub = Halcyon:CreateWindow({ Title = "Bell Hub", Folder = "BellHub", SavePreferences = false, NotificationCenter = true })
local bell = Stub.byName(hub.root, "Notices")
Stub.check(bell ~= nil, "NotificationCenter = true puts a bell in the top bar")
local unread = Stub.byName(bell, "Unread")
Stub.check(unread.Visible and unread.Text ~= "0", "the bell counts notices not seen yet")
Stub.click(bell)
Stub.check(library.popup ~= nil and Stub.byText(library.popup.frame, "Connected") ~= nil, "pressing it lists past notices")
Stub.check(not unread.Visible, "and clears the count")
Halcyon:Notify({ Title = "Fresh one", Duration = 0 })
Stub.check(Stub.byText(library.popup.frame, "Fresh one") ~= nil, "a notice shown while the list is open joins it")
Stub.click(Stub.byText(library.popup.frame, "Clear all"))
Stub.check(Stub.byText(library.popup.frame, "No notices yet") ~= nil, "Clear all empties the list")
hub:Set("NotificationCenter", false)
Stub.check(not bell.Visible and not hub:Get("NotificationCenter"), "the bell can be switched off")
hub:Unload()
local quiet = Halcyon:CreateWindow({ Title = "Quiet Hub", Folder = "QuietHub", SavePreferences = false })
Stub.check(Stub.byName(quiet.root, "Notices") == nil, "there is no bell unless the hub asks for one")
quiet:Unload()

-- A Banner's band is tinted with the notice's colour, not left clear.
local tintedBanner = Halcyon:Notify({ Title = "Update ready", Style = "Banner", Kind = "info", Duration = 0 })
local tintedBand = Stub.byName(library.toasts.holder, "Band")
Stub.equal(tintedBand.BackgroundTransparency, 0, "a Banner's band is drawn")
Stub.check(tintedBand.BackgroundColor3 ~= Theme.color("surface"), "in a tint of the notice's colour")
tintedBanner.Dismiss()
