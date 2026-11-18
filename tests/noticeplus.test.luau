-- Countdown looks, notices that update by Id, repeats that fold together,
-- pictures, click and dismiss callbacks, the Deck pile and clearing.

local window = Halcyon:CreateWindow({ Title = "Notices", Folder = "NoticePlus", SavePreferences = false })
Stub.flush()

local function card(notice)
	return notice.card
end

-- Edge: the outline drains as time passes.
local edge = window:Notify({ Title = "Edge", Countdown = "Edge", Duration = 4 })
Stub.flush()
Stub.check(edge.arc ~= nil and Stub.byName(card(edge), "Arc") ~= nil, "Edge draws an outline on the card")
Stub.equal(edge.arc:Get(), 1, "the outline starts whole")
Stub.advance(2)
Stub.check(math.abs(edge.arc:Get() - 0.5) < 0.05, "half the time gone, half the outline left")
Stub.equal(Stub.byName(card(edge), "Countdown"), nil, "Edge replaces the bar")
edge.Dismiss()

-- Ring sits on the close button.
local ring = window:Notify({ Title = "Ring", Countdown = "Ring", Duration = 4 })
Stub.flush()
Stub.check(ring.arc ~= nil and ring.arc.frame.Parent == ring.close, "Ring goes round the close button")
ring.Dismiss()

-- Top line and none.
local top = window:Notify({ Title = "Top", Countdown = "Top", Duration = 4 })
Stub.flush()
Stub.check(top.topLine ~= nil, "Top draws a line along the top")
top.Dismiss()
local none = window:Notify({ Title = "None", Countdown = "None", Duration = 4 })
Stub.flush()
Stub.check(none.arc == nil and Stub.byName(card(none), "Countdown") == nil, "None shows no countdown")
none.Dismiss()

-- The same Id updates the notice on screen.
local status = window:Notify({ Id = "farm", Title = "Farming", Content = "0 coins", Duration = 5 })
Stub.advance(3)
local again = window:Notify({ Id = "farm", Title = "Farming", Content = "12 coins", Kind = "success", Duration = 5 })
Stub.flush()
Stub.check(again == status, "a notice with the same Id returns the one showing")
Stub.equal(status.contentLabel.Text, "12 coins", "and takes the new content")
Stub.equal(status.kind, "success", "and the new kind")
Stub.check(status.left > 4.5, "its timer starts again")
status.Dismiss()

-- Identical notices fold into one with a count.
local first = window:Notify({ Title = "Item sold", Duration = 5 })
local second = window:Notify({ Title = "Item sold", Duration = 5 })
Stub.flush()
Stub.check(first == second, "a repeat folds into the notice already showing")
Stub.check(first.countLabel.Visible and first.countLabel.Text == "2", "and counts")
local apart = window:Notify({ Title = "Item sold", Duration = 5, Merge = false })
Stub.check(apart ~= first, "Merge = false keeps it apart")
first.Dismiss()
apart.Dismiss()

-- Pictures, clicks and dismiss reasons.
local reasons = {}
local clicked = 0
local avatar = window:Notify({
	Title = "Friend joined",
	Avatar = 1,
	OnClick = function()
		clicked += 1
	end,
	OnDismiss = function(reason)
		table.insert(reasons, reason)
	end,
})
Stub.flush()
Stub.check(avatar.picture ~= nil and string.find(avatar.picture.Image, "AvatarHeadShot", 1, true) ~= nil, "Avatar shows the player's headshot")
Stub.click(card(avatar))
Stub.flush()
Stub.equal(clicked, 1, "OnClick runs on a tap")
Stub.equal(reasons[1], "clicked", "OnDismiss hears why")
local timed = window:Notify({
	Title = "Short",
	Duration = 1,
	OnDismiss = function(reason)
		table.insert(reasons, reason)
	end,
})
Stub.advance(1.5)
Stub.equal(reasons[2], "timeout", "a notice that runs out reports timeout")
Stub.check(timed.done, "and is gone")

-- Deck: only the newest shows in full until the pile fans out.
Halcyon:SetNotificationDefaults({ Stack = "Deck", Duration = 30 })
local pile = {}
for index = 1, 4 do
	table.insert(pile, window:Notify({ Title = `Notice {index}` }))
end
Stub.flush()
local newest = pile[4]
Stub.check(newest.slot.AutomaticSize == Enum.AutomaticSize.Y and not newest.slot.ClipsDescendants, "the newest notice shows in full")
Stub.check(pile[3].slot.ClipsDescendants and pile[3].slot.Size.Y.Offset == 10, "the one before peeks out as an edge")
Stub.check(not pile[1].slot.Visible, "older ones wait out of sight")
newest.card.MouseEnter:Fire()
Stub.flush()
Stub.check(not pile[3].slot.ClipsDescendants and pile[1].slot.Visible, "hovering fans the pile out")
newest.card.MouseLeave:Fire()
Stub.advance(0.5)
Stub.check(pile[3].slot.ClipsDescendants, "and it folds back after the pointer leaves")
Halcyon:SetNotificationDefaults({ Stack = "List", Duration = 4 })

-- Clearing.
window:ClearNotifications()
Stub.flush()
for _, notice in pile do
	Stub.check(notice.done, `{notice.title} cleared`)
end
window:Unload()
