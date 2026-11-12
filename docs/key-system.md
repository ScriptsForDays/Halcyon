# Key system

## What it is, and what it is not

The prompt runs on the player's machine. Anyone who can read your script can remove the check, so the prompt is a gate for honest users and **not a security boundary**. If the script itself must be protected, have your server deliver it only after the key is validated there. Halcyon makes the client side tidy; it cannot replace the server side.

## Tiers

Tiers are listed lowest to highest. A key for a higher tier opens everything a lower tier opens.

```lua
local Window = Halcyon:CreateWindow({
	Title = "My Hub",
	KeySystem = {
		Title = "My Hub access",
		Note = "Keys are posted in our Discord.",
		SaveKey = true, -- default; remembers an accepted key
		MaxAttempts = 5, -- default
		Cooldown = 30, -- seconds locked after too many wrong keys; default
		Tiers = {
			{ Name = "Free", Keys = { "FREE-2026" }, Link = "https://example.com/key", Duration = 86400 },
			{ Name = "Paid", Validate = function(key) return checkWithMyServer(key) end, Link = "https://example.com/buy" },
			{ Name = "Staff", Keys = { "STAFF-ONLY" }, Paid = true },
		},
	},
})
if not Window then
	return -- the prompt was closed
end
```

| Tier option | Meaning |
|---|---|
| `Name` | Shown in the prompt and on the profile card |
| `Description` | A line under the tier selector |
| `Keys` | A list of accepted keys. Checked for every tier, so a paid key works whichever tier is selected |
| `Validate` | `function(key) return ok, message end`. May yield. A second return that is not a string is passed on as `access.Data` |
| `Remote` | Ask your own server; see below |
| `AdService` | Tie the tier to an ad step; see below |
| `Link`, `GetLink`, `LinkLabel` | What the "Get a key" button copies, as text or as a function returning text, and the button's label |
| `Duration` | Seconds a saved key lasts before the prompt returns |
| `NoKey` | `true` lets the player continue on this tier with no key |
| `Icon`, `Tag` | The icon and the line shown on the tier's card in the prompt *(defaults depend on the tier: "No key needed", "Via Linkvertise", "Premium", "Key required")* |
| `Paid` | Marks the tier as paid. By default the tier named `"Paid"` is paid, and so is every tier above a paid one |

With one tier you can skip `Tiers` and put `Keys`, `Remote` and `Link` at the top level. A top-level `Validate(key)` may return `true`, or the name of the tier the key belongs to.

`ShowExpiry` *(default true)* shows how long a key lasts on the tier cards and in the prompt's footer, and counts down to expiry on the profile card. Set it to `false` to show none of that; `Window:GetKeyExpiry()` still reports the seconds left.

`ButtonEffect` picks the finish on the prompt's buttons, as on the window.

`OnSuccess(access)` and `OnFail(message)` run after each attempt. `DefaultTier` picks the tier selected at first.

### What you get back

`Window.access`, also passed to `OnSuccess` and returned by `Halcyon:Authenticate`:

```lua
{ Tier = "Paid", Rank = 2, Tiers = { "Free", "Paid", "Staff" }, PaidRank = 2, Key = "…", Saved = true, Data = nil, ExpiresAt = 1795000000, ShowExpiry = true }
```

## Your own server

```lua
{
	Name = "Paid",
	Remote = {
		Url = "https://api.example.com/keys/check",
		Method = "POST", -- default
		Headers = { ["Content-Type"] = "application/json" }, -- default
		Body = function(key) -- default: {"key":"…"}
			return game:GetService("HttpService"):JSONEncode({ key = key })
		end,
		Accept = function(body, status) -- default: status 2xx and JSON with valid = true
			return status == 200 and body == "OK", "That key is not active."
		end,
	},
}
```

By default the key travels in the request body, not the URL, so it does not end up in server logs. Needs an executor with `request`.

## Free keys through an ad service

A free tier can send the player through an ad step (Linkvertise, Lootlabs, Work.ink or any other) before the key is accepted.

```lua
{
	Name = "Free",
	Duration = 86400,
	AdService = {
		Name = "Linkvertise", -- shown on the button: "Open Linkvertise"
		Link = "https://link-to-your-ad-step", -- or GetLink = function() return url end
		Confirm = function(key)
			-- Ask YOUR server whether this key was issued after the ad was finished.
			return myServerConfirms(key), "Finish the ad step to get a valid key."
		end,
		-- or Remote = { Url = "https://api.example.com/ad/confirm" }
	},
}
```

The flow the player sees: press **Open Linkvertise** (the link is copied), finish the step in a browser, come back with the key, press **Verify key**.

Some services confirm the player with no key to type. Set `RequiresKey = false`; the key box is replaced by an **I finished …** button and `Confirm()` is called with no argument:

```lua
AdService = {
	Name = "Lootlabs",
	RequiresKey = false,
	Link = "https://link-to-your-ad-step",
	Confirm = function()
		return myServerSaysThisPlayerFinished()
	end,
}
```

Halcyon cannot see whether an ad was watched. `Confirm` (or `Remote`) is the only proof it has, so that function must ask something you trust: your server, or the ad service's own API. Check that service's current documentation for how; Halcyon does not bundle any service's endpoints.

## Keyless

A window created without a `KeySystem` (and without `Tiers`) is **Keyless**: `Window:GetTier()` returns `"Keyless"` and the profile card shows it. Keyless ranks below every tier, so ordinary rows are open and rows marked `Tier` or `PaidOnly` stay locked.

## Locking features

```lua
Tab:Toggle({ Title = "Kill aura", PaidOnly = true }) -- any paid tier
Tab:Toggle({ Title = "Staff tools", Tier = "Staff" }) -- this tier or higher
Tab:Section({ Title = "Bosses", PaidOnly = true }) -- every row inside
Window:Tab({ Title = "Premium", PaidOnly = true }) -- every row in the tab
```

A locked row dims and carries an accent badge in place of its control. A locked section or tab instead lays one overlay across its rows, with a crown or lock, the wording and a hint, so it reads as one offer. The wording is yours:

```lua
Halcyon:CreateWindow({
	LockText = "Needs {tier}", -- for Tier locks; {tier} becomes the tier's name
	PaidLockText = "Buy a key to unlock", -- for PaidOnly locks
	PaidLockHint = "Keys are in our Discord", -- the second line on locked sections
})
Tab:Section({ Title = "Raids", PaidOnly = true, LockText = "Raid pack", LockHint = "Included with every paid key" })
Tab:Toggle({ Title = "Auto sell", PaidOnly = true, LockText = "VIP members" }) -- one row
Window:SetLockText("Needs {tier}", "Upgrade to unlock") -- later
```

`Window:HasTier(name)`, `Window:IsPaid()` and `Window:GetTier()` let your own code branch on the tier. `Window:SetTier(name)` moves the player to another tier and re-evaluates every lock, for hubs that upgrade a player while the window is open.

Locks only change what the interface offers. A feature that must stay paid has to be enforced where the player cannot edit it.

## Saved keys

An accepted key is written to `Halcyon/<Folder>/key.json` in the executor's workspace, as plain text. On the next run it is validated again; one that has expired or stopped validating is deleted and the prompt returns. `SaveKey = false` writes nothing. A tier with `NoKey`, or an ad service with `RequiresKey = false`, has no key to save.

## Without a window

```lua
local access = Halcyon:Authenticate({ Folder = "MyHub", Keys = { "abc" } })
if access then
	print(access.Tier)
end
```
