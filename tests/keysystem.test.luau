local Internal = Halcyon.Internal
local KeySystem = Internal.KeySystem

local function tierCard(card, name)
	local node = Stub.byText(card, name)
	while node and node.ClassName ~= "TextButton" do
		node = node.Parent
	end
	return node
end

local function dialog()
	for _, gui in Stub.guis() do
		local found = Stub.byName(gui, "Dialog")
		if found then
			return found
		end
	end
	return nil
end

local options = {
	Title = "Farm Hub",
	Note = "Keys are posted in the Discord.",
	MaxAttempts = 2,
	Cooldown = 5,
	Tiers = {
		{ Name = "Free", Keys = { "FREE-KEY" }, Link = "https://example.com/free", Duration = 3600, Description = "Resets every hour" },
		{
			Name = "Paid",
			Link = "https://example.com/buy",
			Validate = function(key)
				return key == "PAID-KEY", "Paid keys start with PAID."
			end,
		},
		{ Name = "Staff", Remote = { Url = "https://api.example.com/check" } },
	},
}

-- Validation rules.
Stub.equal(KeySystem.check(options, 1, "FREE-KEY"), 1, "a listed key unlocks its tier")
Stub.equal(KeySystem.check(options, 2, "  FREE-KEY  "), 1, "a listed key works whichever tier is selected, and is trimmed")
Stub.equal(KeySystem.check(options, 2, "PAID-KEY"), 2, "a validator accepts its key")
local index, message = KeySystem.check(options, 2, "nope")
Stub.equal(index, nil, "a wrong key unlocks nothing")
Stub.equal(message, "Paid keys start with PAID.", "the validator's message is shown")
index, message = KeySystem.check(options, 1, "   ")
Stub.equal(message, "Enter your key first.", "an empty key is caught before any check")

local sent
Stub.request = function(request)
	sent = request
	return { StatusCode = 200, Body = '{"valid":true}' }
end
Stub.equal(KeySystem.check(options, 3, "STAFF-1"), 3, "a remote check accepts a valid reply")
Stub.equal(sent.Method, "POST", "the key is sent by POST")
Stub.check(string.find(sent.Body, "STAFF-1", 1, true) ~= nil and string.find(sent.Url, "STAFF-1", 1, true) == nil, "the key travels in the body, not the URL")
Stub.request = function()
	return { StatusCode = 200, Body = '{"valid":false,"message":"That key has expired."}' }
end
index, message = KeySystem.check(options, 3, "STAFF-1")
Stub.equal(message, "That key has expired.", "the server's message is shown")
Stub.request = nil
index, message = KeySystem.check(options, 3, "STAFF-1")
Stub.equal(message, "That key is not valid.", "an unreachable or refusing server never unlocks")
index, message = KeySystem.check({
	Validate = function()
		error("validator bug")
	end,
}, 1, "x")
Stub.check(index == nil and message == "The key could not be checked. Try again.", "a validator that errors is reported, not trusted")
index = KeySystem.check({
	Tiers = { { Name = "Free" }, { Name = "Paid" } },
	Validate = function(key)
		return if key == "gold" then "Paid" else false
	end,
}, 1, "gold")
Stub.equal(index, 2, "a shared validator can name the tier")

-- Closing the prompt.
local result = "pending"
local function open(settings)
	result = "pending"
	task.spawn(function()
		result = Halcyon:CreateWindow(settings)
	end)
end
local hub = { Title = "Farm Hub", Folder = "FarmHub", KeySystem = options }
open(hub)
Stub.equal(result, "pending", "CreateWindow waits for a key")
Stub.check(dialog() ~= nil, "the key prompt is showing")
Stub.click(Stub.byName(dialog(), "Close"))
Stub.equal(result, nil, "closing the prompt returns nil")
Stub.equal(dialog(), nil, "the prompt is gone")

-- Wrong keys, the lockout, then the right key.
open(hub)
local card = dialog()
Stub.click(tierCard(card, "Paid"))
local input, verify = Stub.byName(card, "Key"), Stub.byText(card, "Verify key")
input.Text = "wrong"
Stub.click(verify)
Stub.check(Stub.byText(card, "Paid keys start with PAID.") ~= nil, "a wrong key shows why")
Stub.click(verify)
Stub.check(Stub.byText(card, "Too many attempts. Try again in 5 s.") ~= nil, "too many attempts lock the prompt")
input.Text = "PAID-KEY"
Stub.click(verify)
Stub.equal(result, "pending", "a locked prompt accepts nothing")
Stub.advance(5.1)
Stub.click(verify)
Stub.check(type(result) == "table", "the right key creates the window")
Stub.equal(result:GetTier(), "Paid", "the window knows the tier")
Stub.check(result:HasTier("Free") and not result:HasTier("Staff"), "a tier includes the ones below it and not those above")
Stub.check(Stub.files["Halcyon/FarmHub/key.json"] ~= nil, "the key is saved")
Stub.equal(result.access.Key, "PAID-KEY", "the accepted key is available to the hub")

-- A saved key skips the prompt while it still validates.
result:Unload()
open(hub)
Stub.check(type(result) == "table" and result.access.Saved, "a saved key skips the prompt")
result:Unload()

-- A saved key that has time left reports when it expires.
Stub.files["Halcyon/FarmHub/key.json"] = `\{"version":1,"key":"FREE-KEY","tier":"Free","savedAt":{os.time() - 100}\}`
open(hub)
Stub.check(type(result) == "table" and result.access.Saved, "a saved key with time left skips the prompt")
Stub.check(math.abs(result:GetKeyExpiry() - 3500) <= 1, "the window knows when the key expires")
Stub.check(Stub.find(result.root, function(instance)
	return instance.Name == "Expiry" and string.find(instance.Text, "Key expires in 58m", 1, true) ~= nil
end) ~= nil, "the profile card counts down to the key's expiry")
result:Unload()

-- A saved key past its Duration is forgotten.
Stub.files["Halcyon/FarmHub/key.json"] = `\{"version":1,"key":"FREE-KEY","tier":"Free","savedAt":{os.time() - 4000}\}`
open(hub)
Stub.equal(result, "pending", "an expired key shows the prompt again")
Stub.equal(Stub.files["Halcyon/FarmHub/key.json"], nil, "the expired key file is removed")
Stub.click(Stub.byText(dialog(), "Get a key"))
Stub.equal(Stub.clipboard, "https://example.com/free", "Get a key copies the selected tier's link")
Stub.check(Stub.byText(dialog(), "Resets every hour") ~= nil, "the selected tier's description shows")
Stub.check(Stub.find(dialog(), function(instance)
	return instance.Name == "Tag" and instance.Text == "Key required · 1h"
end) ~= nil, "a tier card says what it takes and how long its key lasts")
Stub.check(Stub.byText(dialog(), "Keys for Free last 1h. Your key is saved on this device.") ~= nil, "the footer says how long a key lasts")
Stub.click(Stub.byName(dialog(), "Close"))

-- A tier that needs no key, and success callbacks.
local succeeded
open({
	Title = "Open Hub",
	Folder = "OpenHub",
	KeySystem = {
		Tiers = { { NoKey = true }, { Name = "Free", Keys = { "F-1" } }, { Name = "Premium", Keys = { "P-1" } } },
		OnSuccess = function(access)
			succeeded = access.Tier
		end,
	},
})
Stub.check(tierCard(dialog(), "Keyless") ~= nil, "a tier that needs no key is called Keyless")
Stub.click(tierCard(dialog(), "Free"))
Stub.check(Stub.byName(dialog(), "Key").Visible, "the Free tier asks for a key")
Stub.click(tierCard(dialog(), "Keyless"))
Stub.click(Stub.byText(dialog(), "Continue with Keyless"))
Stub.check(type(result) == "table" and result:GetTier() == "Keyless", "Keyless continues without a key")
Stub.equal(succeeded, "Keyless", "OnSuccess receives the access table")
Stub.check(result:Tab({ Title = "Farm" }):Toggle({ Title = "Free row", Tier = "Free" }):IsLocked(), "Keyless ranks below Free")
Stub.equal(Stub.files["Halcyon/OpenHub/key.json"], nil, "no key file is written for a keyless tier")
local gated = result:Tab({ Title = "Farm" }):Toggle({ Title = "Auto farm", Tier = "Premium" })
Stub.check(gated:IsLocked(), "free players see premium rows locked")
result:Unload()

-- Standalone authentication with the single-tier shorthand.
local access = "pending"
task.spawn(function()
	access = Halcyon:Authenticate({ Folder = "Auth", Keys = { "abc" }, SaveKey = false })
end)
Stub.byName(dialog(), "Key").Text = "abc"
Stub.byName(dialog(), "Key").FocusLost:Fire(true)
Stub.check(type(access) == "table" and access.Tier == "Access" and access.Rank == 1, "Authenticate returns the access table")
Stub.equal(Stub.files["Halcyon/Auth/key.json"], nil, "SaveKey = false writes nothing")

-- A Discord invite under the prompt, only when given.
Stub.genv.setclipboard = function(text)
	Stub.clipboard = text
end
task.spawn(function()
	Halcyon:Authenticate({ Folder = "AuthDiscord", Keys = { "abc" }, SaveKey = false, Discord = "https://discord.gg/example" })
end)
local invite = Stub.byName(dialog(), "Discord")
Stub.check(invite ~= nil, "Discord = link puts an invite button on the key prompt")
Stub.click(invite)
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "pressing it copies the invite")
Stub.check(Stub.byText(dialog(), "Discord invite copied. Paste it into your browser.") ~= nil, "and the prompt says so")
-- The words beside the button are part of it.
Stub.clipboard = nil
Stub.click(Stub.byText(dialog(), "Join the Discord"))
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "pressing the label copies the invite too")
-- With a Discord client listening, the invite opens there and nothing is copied.
local asked = {}
Stub.request = function(options)
	table.insert(asked, options)
	if options.Url == "http://127.0.0.1:6464/rpc?v=1" then
		return { StatusCode = 200, Body = "{}" }
	end
	return { StatusCode = 0, Body = "" }
end
Stub.clipboard = nil
Stub.click(invite)
Stub.flush()
Stub.equal(#asked, 2, "it tries Discord's ports in order and stops at the first that answers")
Stub.equal(asked[2].Method, "POST", "the invite goes to Discord as a POST")
Stub.equal(asked[2].Headers.Origin, "https://discord.com", "with the origin Discord expects")
Stub.check(string.find(asked[2].Body, '"code":"example"', 1, true) ~= nil and string.find(asked[2].Body, "INVITE_BROWSER", 1, true) ~= nil, "naming the invite code")
Stub.equal(Stub.clipboard, nil, "an opened invite is not copied as well")
Stub.check(Stub.byText(dialog(), "Opened the invite in Discord.") ~= nil, "and the prompt says it opened")
-- Discord answering with an error, such as a dead invite: copy instead.
Stub.request = function()
	return { StatusCode = 200, Body = '{"cmd":"INVITE_BROWSER","evt":"ERROR","data":{"code":4011}}' }
end
Stub.clipboard = nil
Stub.click(invite)
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "an invite Discord refuses is copied instead")
-- No client answering: back to copying.
Stub.request = function()
	return { StatusCode = 0, Body = "" }
end
Stub.click(invite)
Stub.flush()
Stub.equal(Stub.clipboard, "https://discord.gg/example", "with Discord closed it copies the invite instead")
Stub.request = nil
Stub.byName(dialog(), "Key").Text = "abc"
Stub.byName(dialog(), "Key").FocusLost:Fire(true)
task.spawn(function()
	Halcyon:Authenticate({ Folder = "AuthNoDiscord", Keys = { "abc" }, SaveKey = false, Discord = false })
end)
Stub.check(Stub.byName(dialog(), "Discord") == nil, "Discord = false leaves it out")
Stub.byName(dialog(), "Key").Text = "abc"
Stub.byName(dialog(), "Key").FocusLost:Fire(true)

-- An ad service on the free tier: the hub's Confirm decides, not the prompt.
open({
	Title = "Ad Hub",
	Folder = "AdHub",
	KeySystem = {
		SaveKey = false,
		Tiers = {
			{
				Name = "Free",
				AdService = {
					Name = "Linkvertise",
					Link = "https://example.com/ad",
					Confirm = function(key)
						return key == "AD-KEY", "That key was not issued by the ad step."
					end,
				},
			},
			{ Name = "Paid", Keys = { "PAID-1" } },
		},
	},
})
card = dialog()
Stub.click(Stub.byText(card, "Open Linkvertise"))
Stub.equal(Stub.clipboard, "https://example.com/ad", "the ad service's link is handed out under its own name")
Stub.byName(card, "Key").Text = "guess"
Stub.click(Stub.byText(card, "Verify key"))
Stub.check(Stub.byText(card, "That key was not issued by the ad step.") ~= nil, "a key the ad service did not confirm is refused")
Stub.byName(card, "Key").Text = "AD-KEY"
Stub.click(Stub.byText(card, "Verify key"))
Stub.check(type(result) == "table" and result:GetTier() == "Free", "a key the ad service confirms unlocks the free tier")
Stub.check(not result:IsPaid(), "an ad key is not a paid key")

-- Paid-only rows, their badge and its wording.
local farm = result:Tab({ Title = "Farm" })
local paidRow = farm:Toggle({ Title = "Auto farm", PaidOnly = true })
local worded = farm:Toggle({ Title = "Auto sell", PaidOnly = true, LockText = "VIP members" })
Stub.check(paidRow:IsLocked(), "a paid-only row is locked for a free key")
Stub.check(Stub.byText(paidRow.Frame, "Paid only") ~= nil, "the lock badge carries the default wording")
Stub.check(Stub.byText(worded.Frame, "VIP members") ~= nil, "a row can carry its own lock wording")
result:SetLockText(nil, "Buy a key to unlock")
Stub.check(Stub.byText(paidRow.Frame, "Buy a key to unlock") ~= nil, "the wording can be changed for the whole window")
Stub.check(Stub.byText(worded.Frame, "VIP members") ~= nil, "a row's own wording is kept")
local paidSection = farm:Section({ Title = "Bosses", PaidOnly = true, LockText = "Paid bosses", LockHint = "Ask in the Discord" })
local bossRow = paidSection:Toggle({ Title = "Auto boss" })
local overlay = Stub.byName(paidSection.root, "LockOverlay")
Stub.equal(overlay.Parent.Name, "Body", "the overlay lies across the rows, outside the section's list layout")
Stub.check(bossRow:IsLocked() and overlay.Visible, "a locked section locks every row and shows one overlay")
Stub.check(Stub.byText(overlay, "Paid bosses") ~= nil and Stub.byText(overlay, "Ask in the Discord") ~= nil, "the overlay carries the section's wording and hint")
Stub.check(not Stub.byName(bossRow.Frame, "Lock").Visible, "rows under the overlay carry no badge of their own")
Stub.check(Stub.byName(paidSection:Toggle({ Title = "Staff boss", Tier = "Paid" }).Frame, "Lock").Visible, "a row with its own lock keeps its badge")
result:SetLockHint(nil, "Buy a key in the shop")
local hinted = farm:Section({ Title = "Raids", PaidOnly = true })
Stub.check(Stub.byText(Stub.byName(hinted.root, "LockOverlay"), "Buy a key in the shop") ~= nil, "the hint can be changed for the whole window")
Stub.check(result:SetTier("Paid") and result:IsPaid() and not paidRow:IsLocked() and not worded:IsLocked(), "a paid tier opens paid-only rows")
Stub.check(not overlay.Visible and not bossRow:IsLocked(), "a paid tier lifts the section overlay")
result:Unload()

-- An ad service that confirms the player with no key to type.
local finished = false
open({
	Title = "Ad Hub",
	Folder = "AdHubKeyless",
	KeySystem = {
		Tiers = {
			{
				Name = "Free",
				AdService = {
					Name = "Lootlabs",
					RequiresKey = false,
					Link = "https://example.com/task",
					Confirm = function()
						return finished
					end,
				},
			},
		},
	},
})
card = dialog()
Stub.check(not Stub.byName(card, "Key").Visible, "no key box when the ad service needs no key")
Stub.click(Stub.byText(card, "I finished Lootlabs"))
Stub.equal(result, "pending", "an unconfirmed ad step unlocks nothing")
Stub.check(Stub.byText(card, "The Lootlabs step is not confirmed yet. Finish it, then try again.") ~= nil, "the prompt says the step is not confirmed")
finished = true
Stub.click(Stub.byText(card, "I finished Lootlabs"))
Stub.check(type(result) == "table" and result:GetTier() == "Free", "a confirmed ad step unlocks the tier")
Stub.equal(Stub.files["Halcyon/AdHubKeyless/key.json"], nil, "nothing is saved when there was no key")
result:Unload()

-- ShowExpiry = false keeps expiry off the prompt and the profile card.
Stub.files["Halcyon/QuietHub/key.json"] = `\{"version":1,"key":"Q-1","tier":"Free","savedAt":{os.time() - 100}\}`
open({ Title = "Quiet Hub", Folder = "QuietHub", KeySystem = { ShowExpiry = false, Tiers = { { Name = "Free", Keys = { "Q-1" }, Duration = 3600 } } } })
Stub.check(type(result) == "table" and result:GetKeyExpiry() ~= nil, "the expiry is still known to the hub")
Stub.equal(Stub.byName(result.root, "Expiry"), nil, "but it is not shown")
result:Unload()

-- No key system at all: the window is Keyless.
local warningsBefore = #Stub.warnings
local keyless = Halcyon:CreateWindow({ Title = "Keyless Hub", Folder = "KeylessHub" })
Stub.equal(keyless:GetTier(), "Keyless", "a window without a key system is Keyless")
Stub.check(not keyless:IsPaid(), "Keyless is not paid")
local rows = keyless:Tab({ Title = "Rows" })
Stub.check(not rows:Toggle({ Title = "Open row" }):IsLocked(), "ordinary rows are open in a Keyless window")
Stub.check(rows:Toggle({ Title = "Paid row", PaidOnly = true }):IsLocked(), "paid-only rows stay locked in a Keyless window")
Stub.check(rows:Toggle({ Title = "Tier row", Tier = "Paid" }):IsLocked(), "tier rows stay locked in a Keyless window")
Stub.equal(#Stub.warnings, warningsBefore, "locking in a Keyless window warns about nothing")
Stub.check(Stub.byText(keyless.root, "Keyless") ~= nil, "the profile card shows the tier")
keyless:Unload()

Halcyon:Unload()
Stub.equal(#Stub.guis(), 0, "everything removed")
