-- Every option Halcyon reads, with its Luau type. Three things use it:
--   * Debug = true warns about option names Halcyon doesn't know, which is
--     how a typo ("Defualt") or an invented option shows up;
--   * Halcyon:Build checks a whole hub spec against it;
--   * tools/gen-types.luau turns it into dist/Halcyon.d.luau for editors.
-- The tests fail when an element reads an option that is missing here, or
-- when LLM.txt doesn't mention one, so this list can't drift.
--
-- Type text uses the names declared at the top of the generated file:
-- Image, Condition, MenuItem, Callback, Background.

local Schema = {}

-- Options every element takes.
Schema.shared = {
	Title = "string",
	Description = "string",
	Icon = "Image",
	Flag = "string",
	Callback = "Callback",
	Tier = "string",
	PaidOnly = "boolean",
	LockText = "string",
	LockHint = "string",
	Badge = "string | { Text: string, Color: Color3? }",
	Info = "string",
	Tooltip = "string | boolean | { Title: string?, Text: string?, Key: string?, Style: string? }",
	Spotlight = "string | { Title: string?, Text: string?, Id: string? }",
	Requires = "{ string }",
	Style = "string",
	Menu = "{ MenuItem } | () -> { MenuItem }",
	Visible = "boolean",
	Disabled = "boolean",
	Enabled = "boolean",
	ShowWhen = "Condition",
	EnableWhen = "Condition",
	Favourite = "boolean",
}

local values = "{ any }"

-- Each element's own options and the value its handle holds.
Schema.elements = {
	Toggle = {
		value = "boolean",
		options = {
			Default = "boolean",
			Thumb = "string",
			Outline = "boolean",
			OutlineColor = "Color3",
			Keybind = "{ Default: Enum.KeyCode?, Mode: string?, Flag: string?, Modifiers: boolean? }",
			Color = "{ Default: Color3?, Alpha: number?, Flag: string?, Callback: Callback? }",
			Exclusive = "string",
			Confirm = "boolean | string",
		},
	},
	Button = {
		value = "nil",
		options = {
			Variant = "string",
			TrailingIcon = "Image",
			Effect = "string",
			Hold = "boolean | number",
			Confirm = "boolean | string",
			ShowDone = "boolean",
			Keybind = "Enum.KeyCode | { Default: Enum.KeyCode?, Flag: string?, Modifiers: boolean? }",
		},
	},
	Buttons = {
		value = "string",
		options = { Buttons = "{ { Title: string, Icon: Image?, Variant: string?, Callback: Callback? } }" },
	},
	Slider = {
		value = "number | { number }",
		options = {
			Min = "number",
			Max = "number",
			Step = "number",
			Default = "number | { number }",
			Suffix = "string",
			Prefix = "string",
			Percent = "boolean",
			Format = "(number) -> string",
			Display = "string",
			DefaultMarker = "boolean",
			Range = "boolean",
			Stacked = "boolean",
			Width = "number",
			TooltipStyle = "string",
			Live = "boolean",
		},
	},
	Dropdown = {
		value = "any",
		options = {
			Values = values,
			Default = "any",
			Multi = "boolean",
			AllowNone = "boolean",
			Placeholder = "string",
			Searchable = "boolean",
			Width = "number",
			Players = "boolean",
			ExcludeSelf = "boolean",
		},
	},
	Radio = { value = "any", options = { Values = values, Default = "any", Inline = "boolean", AllowNone = "boolean" } },
	Checklist = { value = "{ any }", options = { Values = values, Default = "{ any }", Inline = "boolean", SelectAll = "boolean | string" } },
	Chips = { value = "any", options = { Values = values, Default = "any", Multi = "boolean", AllowNone = "boolean" } },
	Tiles = {
		value = "any",
		options = {
			Items = "{ { Title: string?, Icon: Image?, Image: Image?, Description: string?, Value: any?, Disabled: boolean? } }",
			Values = values,
			Columns = "number",
			Multi = "boolean",
			Default = "any",
			AllowNone = "boolean",
			Height = "number",
		},
	},
	Segmented = { value = "any", options = { Values = values, Default = "any", Stacked = "boolean" } },
	Input = {
		value = "string | number",
		options = {
			Default = "string | number",
			Placeholder = "string",
			Numeric = "boolean",
			Min = "number",
			Max = "number",
			MaxLength = "number",
			Counter = "boolean",
			Live = "boolean",
			Width = "number",
			LeadingIcon = "Image",
			Clearable = "boolean",
			Password = "boolean",
			MultiLine = "boolean",
			Lines = "number",
			Validate = "(string | number) -> (boolean?, string?)",
		},
	},
	Keybind = {
		value = "Enum.KeyCode? | { Key: Enum.KeyCode, Ctrl: boolean, Shift: boolean, Alt: boolean }?",
		options = {
			Default = "Enum.KeyCode | string | { Key: Enum.KeyCode, Ctrl: boolean?, Shift: boolean?, Alt: boolean? }",
			Modifiers = "boolean",
			Mode = "string",
			ModePicker = "boolean",
			ChangedCallback = "(Enum.KeyCode?) -> ()",
			ModeChangedCallback = "(string) -> ()",
		},
	},
	ColorPicker = {
		value = "Color3",
		options = { Default = "Color3", Alpha = "boolean", Transparency = "number", Palette = "boolean | { Color3 }", Recent = "boolean" },
	},
	DatePicker = {
		value = "{ Year: number, Month: number, Day: number, Hour: number?, Minute: number? }",
		options = { Default = "{ Year: number?, Month: number?, Day: number?, Hour: number?, Minute: number? }", Time = "boolean", WeekStart = "string", Width = "number" },
	},
	Stepper = {
		value = "number",
		options = { Min = "number", Max = "number", Step = "number", Default = "number", Suffix = "string", Drag = "boolean" },
	},
	Rating = { value = "number", options = { Max = "number", Default = "number", AllowNone = "boolean" } },
	Progress = { value = "number", options = { Value = "number", Max = "number", Suffix = "string" } },
	Status = { value = "string", options = { Status = "string", Kind = "string", Pulse = "boolean" } },
	Countdown = { value = "number", options = { Seconds = "number", Ends = "number", Done = "string", Format = "(number) -> string" } },
	Table = {
		value = "{ { any } }",
		options = {
			Columns = "{ string | { Title: string, Width: number?, Align: string? } }",
			Rows = "{ { any } }",
			Sortable = "boolean",
			MaxHeight = "number",
			Striped = "boolean",
			EmptyText = "string",
		},
	},
	Accordion = { value = "string", options = { Content = "string", Open = "boolean" } },
	Paragraph = {
		value = "string",
		options = { Content = "string", Image = "Image", ImageSize = "number", Buttons = "{ { Title: string, Variant: string?, Callback: Callback? } }" },
	},
	Label = { value = "string", options = {} },
	Divider = { value = "nil", options = {} },
	Space = { value = "nil", options = { Height = "number" } },
	Code = { value = "string", options = { Code = "string" } },
	Image = { value = "Image", options = { Image = "Image", Height = "number", Crop = "boolean" } },
	MenuButton = { value = "nil", options = { Text = "string", Items = "{ MenuItem }", Width = "number" } },
	Link = { value = "string", options = { Url = "string" } },
	List = {
		value = "any",
		options = { Values = values, Default = "any", Multi = "boolean", Search = "boolean", Reorder = "boolean", Height = "number", AllowNone = "boolean" },
	},
	Tags = {
		value = "{ string }",
		options = { Default = "{ string }", Placeholder = "string", Suggestions = "{ string }", Max = "number", AllowDuplicates = "boolean" },
	},
	PlayerList = {
		value = "string?",
		options = {
			Actions = "{ { Title: string, Icon: Image?, Callback: (Player) -> () } }",
			Search = "boolean",
			ShowSelf = "boolean",
			Selectable = "boolean",
			Height = "number",
		},
	},
	Stat = {
		value = "any",
		options = { Value = "any", Unit = "string", Change = "string", Kind = "string" },
	},
	Stats = {
		value = "{ [string]: any }",
		options = {
			Items = "{ { Title: string, Value: any?, Unit: string?, Change: string?, Kind: string?, Icon: Image?, Key: string? } }",
			Columns = "number",
		},
	},
	Graph = {
		value = "{ number }",
		options = {
			Values = "{ number }",
			Max = "number",
			Min = "number",
			Ceiling = "number",
			Height = "number",
			Suffix = "string",
			Format = "(number) -> string",
			Role = "string",
		},
	},
	Log = { value = "{ string }", options = { Height = "number", MaxLines = "number", Timestamps = "boolean", EmptyText = "string" } },
	Viewport = {
		value = "Instance?",
		options = { Model = "Instance", Character = "boolean", Height = "number", Spin = "number", Distance = "number", FieldOfView = "number" },
	},
	Gauge = {
		value = "number",
		options = {
			Value = "number",
			Min = "number",
			Max = "number",
			Suffix = "string",
			Format = "(number) -> string",
			Size = "number",
			Thickness = "number",
			Role = "string",
			Thresholds = "{ { At: number, Role: string } }",
		},
	},
	Knob = {
		value = "number",
		options = {
			Min = "number",
			Max = "number",
			Step = "number",
			Default = "number",
			Suffix = "string",
			Format = "(number) -> string",
			Size = "number",
			Thickness = "number",
			Role = "string",
			Live = "boolean",
		},
	},
	Chart = {
		value = "{ any }",
		options = {
			Type = "string",
			Items = "{ { Name: string, Value: number, Role: string? } }",
			Series = "{ { Name: string, Values: { number }, Role: string? } }",
			Labels = "{ string | number }",
			Height = "number",
			Min = "number",
			Max = "number",
			Suffix = "string",
			Format = "(number) -> string",
		},
	},
	ItemGrid = {
		value = "any",
		options = {
			Items = "{ { Title: string?, Name: string?, Image: Image?, Icon: Image?, Rarity: string?, Count: number?, Value: any?, Disabled: boolean? } }",
			Rarities = "{ { Name: string, Role: string?, Color: Color3? } }",
			Multi = "boolean",
			Default = "any",
			AllowNone = "boolean",
			Search = "boolean",
			Sort = "string",
			Columns = "number",
			Height = "number",
		},
	},
	Waypoints = {
		value = "{ { Name: string, CFrame: CFrame } }",
		options = {
			Teleport = "(CFrame, string) -> ()",
			GetPosition = "() -> CFrame?",
			Default = "{ { Name: string, CFrame: CFrame } }",
			Max = "number",
			Height = "number",
		},
	},
	-- Made by Tab:Page and Section:Page, not called directly.
	PageLink = { value = "any", options = { Page = "any" } },
	Banner = {
		value = "string",
		options = { Text = "string", Image = "Image", Height = "number", Button = "{ Title: string, Callback: Callback? }" },
	},
}

-- Elements without a Title of their own.
Schema.untitled = { Divider = true, Code = true, Image = true, Buttons = true, Space = true, Table = true, Stats = true }

Schema.tab = {
	Title = "string",
	Icon = "Image",
	Group = "string",
	Description = "string",
	SectionStyle = "string",
	Tier = "string",
	PaidOnly = "boolean",
	LockText = "string",
	LockHint = "string",
	Visible = "boolean",
	ShowWhen = "Condition",
}

Schema.section = {
	Title = "string",
	Icon = "Image",
	IconColor = "string | Color3",
	Description = "string",
	Badge = "string | { Text: string, Color: Color3? }",
	Style = "string",
	Side = "string",
	Collapsible = "boolean",
	Collapsed = "boolean",
	Tabs = "{ string }",
	Switch = "{ Default: boolean?, Flag: string?, Callback: Callback? }",
	MaxHeight = "number",
	PopOut = "boolean",
	Background = "Background",
	Tier = "string",
	PaidOnly = "boolean",
	LockText = "string",
	LockHint = "string",
	Visible = "boolean",
	Disabled = "boolean",
	Enabled = "boolean",
	ShowWhen = "Condition",
	EnableWhen = "Condition",
}

Schema.notify = {
	Title = "string",
	Content = "string",
	Kind = "string",
	Style = "string",
	Icon = "Image",
	Duration = "number",
	Progress = "boolean",
	Sound = "boolean | string | number",
	Close = "boolean",
	Indeterminate = "boolean",
	Actions = "{ { Title: string, Callback: Callback? } }",
	Countdown = "string",
	Id = "string",
	Merge = "boolean",
	Image = "Image",
	Avatar = "number",
	OnClick = "(any) -> ()",
	OnDismiss = "(string) -> ()",
}

Schema.window = {
	-- Identity
	Title = "string",
	Subtitle = "string",
	Icon = "Image | false",
	Version = "string",
	ShowVersion = "boolean",
	Folder = "string",
	TopbarImage = "Image | boolean",
	TopbarImageStyle = "string",
	HeaderStyle = "string",
	Logo = "Image | false | { Image: Image?, Text: string?, Icon: Image?, Height: number?, Width: number? }",
	-- Layout
	Size = "Vector2",
	Scale = "number",
	TabStyle = "string",
	SidebarWidth = "number",
	SidebarToggle = "boolean",
	CollapsedGroups = "{ string }",
	CollapsibleGroups = "boolean",
	MinimizeStyle = "string",
	Minimize = "boolean",
	Minimizable = "boolean",
	Resize = "boolean",
	Resizable = "boolean",
	Close = "boolean",
	Drag = "boolean",
	Snap = "boolean",
	ToggleKey = "Enum.KeyCode",
	OpenButton = "boolean",
	-- Looks
	Preset = "string",
	Styles = "{ [string]: string }",
	SectionStyle = "string",
	TabIndicator = "string",
	WindowStyle = "string",
	OpenAnimation = "string",
	PageTransition = "string",
	TopbarControls = "string",
	ButtonEffect = "string",
	ToggleThumb = "string",
	SliderTooltipStyle = "string",
	Radius = "string",
	Density = "string",
	TextSize = "string",
	Theme = "string | { [string]: any }",
	Font = "string | Enum.Font | Font",
	IconPack = "string",
	AccentGradient = "boolean | Color3",
	SafeStatusColors = "boolean",
	Transparency = "number",
	BackgroundImage = "Image",
	Background = "Background",
	BackgroundImageTransparency = "number",
	Shadow = "boolean",
	ShadowImage = "Image",
	ShadowTransparency = "number",
	SliderTooltips = "boolean",
	ToggleOutline = "boolean",
	ToggleOutlineColor = "Color3",
	LockShimmer = "boolean",
	FocusRing = "boolean",
	-- Behaviour
	Search = "boolean",
	CommandPalette = "boolean",
	PaletteKey = "Enum.KeyCode",
	Tooltips = "boolean",
	Animations = "boolean",
	Blur = "boolean | number",
	NotificationCenter = "boolean",
	Watermark = "boolean | { [string]: any }",
	KeybindList = "boolean | { [string]: any }",
	SettingsTab = "boolean | { [string]: any }",
	ConfirmUnload = "boolean",
	SavePreferences = "boolean",
	DisplayOrder = "number",
	Notifications = "{ [string]: any }",
	Configs = "{ PerGame: (string | boolean)? }",
	ShowErrors = "boolean",
	UpdateCheck = "{ Url: string, Current: string?, Notify: boolean?, OnUpdate: ((string, string?) -> ())? }",
	Favourites = "boolean",
	TabReorder = "boolean",
	Debug = "boolean",
	Language = "string",
	Strings = "{ [string]: string }",
	Translate = "boolean | { From: string?, Fixes: { [string]: { [string]: string } }?, Skip: { string }?, Service: ((lines: { string }, from: string, to: string) -> { string })? }",
	-- Access
	KeySystem = "{ [string]: any }",
	Tiers = "{ string }",
	Tier = "string",
	PaidTier = "string",
	LockText = "string",
	PaidLockText = "string",
	LockHint = "string",
	PaidLockHint = "string",
	-- Extras
	Profile = "false | { [string]: any }",
	UpdateLog = "boolean | { [string]: any }",
}

-- Keys an element kind accepts: shared ones plus its own.
function Schema.accepts(kind, key)
	local entry = Schema.elements[kind]
	return Schema.shared[key] ~= nil or (entry ~= nil and entry.options[key] ~= nil)
end

-- The known name closest to a typo, when it is close enough to be a guess.
-- Two swapped letters count as one slip ("Stpe" is one away from "Step").
local function distance(a, b)
	a, b = string.lower(a), string.lower(b)
	local rows = {}
	for i = 0, #a do
		rows[i] = { [0] = i }
	end
	for j = 1, #b do
		rows[0][j] = j
	end
	for i = 1, #a do
		for j = 1, #b do
			local here, there = string.sub(a, i, i), string.sub(b, j, j)
			local cost = if here == there then 0 else 1
			local best = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and here == string.sub(b, j - 1, j - 1) and string.sub(a, i - 1, i - 1) == there then
				best = math.min(best, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = best
		end
	end
	return rows[#a][#b]
end

function Schema.closest(name, known)
	local best, bestScore = nil, math.huge
	for candidate in known do
		local score = distance(name, candidate)
		-- Ties go to the alphabetically first name, so the guess never
		-- depends on table order.
		if score < bestScore or (score == bestScore and best ~= nil and candidate < best) then
			best, bestScore = candidate, score
		end
	end
	return if bestScore <= math.max(2, #name // 4) then best else nil
end

-- Debug warnings, each printed once.
local warned = {}
Schema.enabled = false

function Schema.warn(message)
	if not Schema.enabled or warned[message] then
		return
	end
	warned[message] = true
	warn("[Halcyon debug] " .. message)
end

-- Warns about keys in `options` that `known` (a set or a function) doesn't
-- accept. `what` names the thing for the message: 'Toggle "Fly"'.
function Schema.check(what, options, known, shared)
	if not Schema.enabled or type(options) ~= "table" then
		return
	end
	for key in options do
		if type(key) == "string" and known[key] == nil and (shared == nil or shared[key] == nil) then
			local pool = table.clone(known)
			for name in shared or {} do
				pool[name] = true
			end
			local guess = Schema.closest(key, pool)
			Schema.warn(`{what}: unknown option "{key}"{if guess then `, did you mean "{guess}"?` else "; Halcyon ignores it."}`)
		end
	end
end

return Schema
