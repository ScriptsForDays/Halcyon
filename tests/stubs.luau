-- Engine stubs for the headless tests. They model what the library reads and
-- writes: instances, properties, signals, tweens, the task scheduler and the
-- executor's file functions. Nothing here renders.

local Stub = {
	now = 0,
	passed = 0,
	failed = {},
	errors = {},
	warnings = {},
	files = {},
	folders = {},
	clipboard = nil,
	genv = {},
	request = nil,
}

local function typeof(value)
	local kind = type(value)
	if kind == "table" then
		local meta = getmetatable(value)
		if type(meta) == "table" and rawget(meta, "__type") then
			return meta.__type
		end
	end
	return kind
end

local function warn(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end
	table.insert(Stub.warnings, table.concat(parts, " "))
end

-- Scheduler -----------------------------------------------------------------

local task = {}
local timers, deferred = {}, {}
local cancelled = setmetatable({}, { __mode = "k" })

local function resume(thread, ...)
	if cancelled[thread] or coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		table.insert(Stub.errors, debug.traceback(thread, tostring(message)))
	end
end

local function toThread(target)
	return if type(target) == "thread" then target else coroutine.create(target)
end

function task.spawn(target, ...)
	local thread = toThread(target)
	resume(thread, ...)
	return thread
end

function task.defer(target, ...)
	local thread = toThread(target)
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function task.delay(seconds, target, ...)
	local thread = toThread(target)
	table.insert(timers, { at = Stub.now + seconds, thread = thread, args = table.pack(...) })
	return thread
end

function task.wait(seconds)
	seconds = seconds or 0
	table.insert(timers, { at = Stub.now + seconds, thread = coroutine.running(), args = table.pack(seconds) })
	return coroutine.yield()
end

function task.cancel(thread)
	cancelled[thread] = true
end

function Stub.flush()
	while #deferred > 0 do
		local entry = table.remove(deferred, 1)
		resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
	end
end

function Stub.advance(seconds)
	Stub.flush()
	local target = Stub.now + seconds
	while true do
		local best
		for index, timer in timers do
			if timer.at <= target and (not best or timer.at < timers[best].at) then
				best = index
			end
		end
		if not best then
			break
		end
		local timer = table.remove(timers, best)
		Stub.now = math.max(Stub.now, timer.at)
		resume(timer.thread, table.unpack(timer.args, 1, timer.args.n))
		Stub.flush()
	end
	Stub.now = target
end

-- Signals -------------------------------------------------------------------

local SignalMeta = { __type = "RBXScriptSignal" }
SignalMeta.__index = SignalMeta
local ConnectionMeta = { __type = "RBXScriptConnection" }
ConnectionMeta.__index = ConnectionMeta

function ConnectionMeta:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local index = table.find(self.signal.list, self)
	if index then
		table.remove(self.signal.list, index)
	end
end

local function newSignal()
	return setmetatable({ list = {} }, SignalMeta)
end

function SignalMeta:Connect(handler)
	local connection = setmetatable({ signal = self, handler = handler, Connected = true }, ConnectionMeta)
	table.insert(self.list, connection)
	return connection
end

function SignalMeta:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function SignalMeta:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function SignalMeta:Fire(...)
	for _, connection in table.clone(self.list) do
		if connection.Connected then
			task.spawn(connection.handler, ...)
		end
	end
end

-- Datatypes -----------------------------------------------------------------

local function valueType(name)
	local meta = { __type = name }
	meta.__index = meta
	return meta
end

local Color3Meta = valueType("Color3")
local Color3 = {}

function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta)
end

function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	assert(#hex == 6 and not string.find(hex, "%X"), "invalid hex colour")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end

function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local sector = i % 6
	if sector == 0 then
		return Color3.new(v, t, p)
	elseif sector == 1 then
		return Color3.new(q, v, p)
	elseif sector == 2 then
		return Color3.new(p, v, t)
	elseif sector == 3 then
		return Color3.new(p, q, v)
	elseif sector == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end

Color3Meta.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

function Color3Meta:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local high, low = math.max(r, g, b), math.min(r, g, b)
	local delta = high - low
	local h = 0
	if delta > 0 then
		if high == r then
			h = ((g - b) / delta) % 6
		elseif high == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h /= 6
	end
	return h, if high == 0 then 0 else delta / high, high
end

function Color3Meta:ToHex()
	return string.format("%02x%02x%02x", math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255))
end

function Color3Meta:Lerp(goal, alpha)
	return Color3.new(self.R + (goal.R - self.R) * alpha, self.G + (goal.G - self.G) * alpha, self.B + (goal.B - self.B) * alpha)
end

local Vector2Meta = valueType("Vector2")
local Vector2 = {}

function Vector2.new(x, y)
	x, y = x or 0, y or 0
	return setmetatable({ X = x, Y = y, Magnitude = math.sqrt(x * x + y * y) }, Vector2Meta)
end

Vector2Meta.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2Meta.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
Vector2Meta.__mul = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	elseif type(a) == "number" then
		return Vector2.new(a * b.X, a * b.Y)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
Vector2Meta.__div = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
Vector2Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

local Vector3Meta = valueType("Vector3")
local Vector3 = {}

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end

Vector3Meta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.zero = Vector3.new(0, 0, 0)

local UDimMeta = valueType("UDim")
local UDim = {}

function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMeta)
end

UDimMeta.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end

local UDim2Meta = valueType("UDim2")
local UDim2 = {}

function UDim2.new(xScale, xOffset, yScale, yOffset)
	if typeof(xScale) == "UDim" then
		return setmetatable({ X = xScale, Y = xOffset, Width = xScale, Height = xOffset }, UDim2Meta)
	end
	local x, y = UDim.new(xScale, xOffset), UDim.new(yScale, yOffset)
	return setmetatable({ X = x, Y = y, Width = x, Height = y }, UDim2Meta)
end

function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end

function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

UDim2Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2Meta.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end

local CFrameMeta = valueType("CFrame")
local CFrame = {}

function CFrame.new(x, y, z)
	local position = if typeof(x) == "Vector3" then x else Vector3.new(x, y, z)
	return setmetatable({ Position = position, LookVector = Vector3.new(0, 0, -1) }, CFrameMeta)
end

CFrame.Angles = function()
	return CFrame.new()
end
CFrame.lookAt = function(origin)
	return CFrame.new(origin)
end
CFrameMeta.__mul = function(a, b)
	if typeof(b) == "Vector3" then
		return a.Position + b
	end
	return CFrame.new(a.Position + b.Position)
end

local function plain(name)
	local meta = valueType(name)
	return {
		new = function(...)
			return setmetatable({ args = table.pack(...) }, meta)
		end,
	}
end

local TweenInfo, Rect, NumberRange = plain("TweenInfo"), plain("Rect"), plain("NumberRange")
local ColorSequence, ColorSequenceKeypoint = plain("ColorSequence"), plain("ColorSequenceKeypoint")
local NumberSequence, NumberSequenceKeypoint = plain("NumberSequence"), plain("NumberSequenceKeypoint")

local FontMeta = valueType("Font")
local Font = {}

function Font.new(family, weight, style)
	return setmetatable({ Family = family, Weight = weight, Style = style }, FontMeta)
end

function Font.fromEnum(font)
	return Font.new("rbxasset://fonts/families/" .. font.Name .. ".json")
end

-- Enums ---------------------------------------------------------------------

local KEY_NAMES = string.split(
	"Unknown,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,Zero,One,Two,Three,Four,Five,Six,Seven,Eight,Nine,"
		.. "F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12,LeftShift,RightShift,LeftControl,RightControl,LeftAlt,RightAlt,"
		.. "Space,Return,Escape,Backspace,Tab,Insert,Delete,Home,End,Up,Down,Left,Right",
	","
)
local EnumItemMeta = valueType("EnumItem")
EnumItemMeta.__tostring = function(self)
	return "Enum." .. self.EnumType.Name .. "." .. self.Name
end

local function newEnumType(name)
	local items, order = {}, {}
	local enumType = { Name = name }
	local function item(itemName)
		if not items[itemName] then
			items[itemName] = setmetatable({ Name = itemName, EnumType = enumType, Value = #order }, EnumItemMeta)
			table.insert(order, items[itemName])
		end
		return items[itemName]
	end
	if name == "KeyCode" then
		for _, keyName in KEY_NAMES do
			item(keyName)
		end
	end
	function enumType.GetEnumItems()
		return table.clone(order)
	end
	return setmetatable(enumType, {
		__type = "Enum",
		__index = function(_, key)
			return item(key)
		end,
	})
end

local Enum = setmetatable({}, {
	__index = function(self, name)
		local enumType = newEnumType(name)
		rawset(self, name, enumType)
		return enumType
	end,
})

-- JSON ----------------------------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function jsonEncode(value)
	local kind = type(value)
	if kind == "nil" then
		return "null"
	elseif kind == "boolean" or kind == "number" then
		return tostring(value)
	elseif kind == "string" then
		return '"' .. string.gsub(value, '[%c"\\]', function(character)
			return ESCAPES[character] or string.format("\\u%04x", string.byte(character))
		end) .. '"'
	end
	assert(kind == "table", "cannot encode " .. typeof(value))
	local parts = {}
	if #value > 0 or next(value) == nil then
		for index, item in ipairs(value) do
			parts[index] = jsonEncode(item)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		table.insert(parts, jsonEncode(tostring(key)) .. ":" .. jsonEncode(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local UNESCAPES = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }

local function jsonDecode(text)
	local position = 1
	local parseValue

	local function skip()
		position = string.find(text, "%S", position) or #text + 1
	end

	local function parseString()
		local out = {}
		position += 1
		while true do
			local character = string.sub(text, position, position)
			assert(character ~= "", "unterminated string")
			if character == '"' then
				position += 1
				return table.concat(out)
			elseif character == "\\" then
				local escaped = string.sub(text, position + 1, position + 1)
				if escaped == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(text, position + 2, position + 5), 16)))
					position += 6
				else
					table.insert(out, UNESCAPES[escaped] or escaped)
					position += 2
				end
			else
				table.insert(out, character)
				position += 1
			end
		end
	end

	function parseValue()
		skip()
		local character = string.sub(text, position, position)
		if character == "{" then
			local object = {}
			position += 1
			skip()
			if string.sub(text, position, position) == "}" then
				position += 1
				return object
			end
			while true do
				skip()
				local key = parseString()
				skip()
				assert(string.sub(text, position, position) == ":", "expected ':'")
				position += 1
				object[key] = parseValue()
				skip()
				local separator = string.sub(text, position, position)
				position += 1
				if separator == "}" then
					return object
				end
				assert(separator == ",", "expected ',' in object")
			end
		elseif character == "[" then
			local array = {}
			position += 1
			skip()
			if string.sub(text, position, position) == "]" then
				position += 1
				return array
			end
			while true do
				table.insert(array, parseValue())
				skip()
				local separator = string.sub(text, position, position)
				position += 1
				if separator == "]" then
					return array
				end
				assert(separator == ",", "expected ',' in array")
			end
		elseif character == '"' then
			return parseString()
		end
		for literal, result in { ["true"] = true, ["false"] = false } do
			if string.sub(text, position, position + #literal - 1) == literal then
				position += #literal
				return result
			end
		end
		if string.sub(text, position, position + 3) == "null" then
			position += 4
			return nil
		end
		local number = string.match(text, "^-?%d+%.?%d*[eE]?[+-]?%d*", position)
		assert(number and number ~= "", "unexpected character in JSON")
		position += #number
		return tonumber(number)
	end

	local result = parseValue()
	skip()
	assert(position > #text, "trailing characters in JSON")
	return result
end

-- Instances -----------------------------------------------------------------

local EVENTS = {}
for _, name in
	string.split(
		"Activated,MouseEnter,MouseLeave,MouseButton1Down,MouseButton1Up,MouseButton1Click,InputBegan,InputChanged,"
			.. "InputEnded,FocusLost,Focused,Destroying,ChildAdded,ChildRemoved,Changed,Heartbeat,RenderStepped,"
			.. "CharacterAdded,Completed,SelectionGained,SelectionLost,TouchTap,ReturnPressedFromOnScreenKeyboard",
		","
	)
do
	EVENTS[name] = true
end

local GUI_OBJECTS = {}
for _, name in string.split("Frame,TextLabel,TextButton,TextBox,ImageLabel,ImageButton,ScrollingFrame,CanvasGroup,ViewportFrame", ",") do
	GUI_OBJECTS[name] = true
end

local InstanceMeta = { __type = "Instance" }
local Methods = {}
local screenGuis = {}
local viewport = Vector2.new(1280, 720)
local services = {}

InstanceMeta.__index = function(self, key)
	local value = rawget(self, "props")[key]
	if value ~= nil then
		return value
	end
	if Methods[key] then
		return Methods[key]
	end
	if EVENTS[key] then
		local signals = rawget(self, "signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "children") do
		if rawget(child, "props").Name == key then
			return child
		end
	end
	return nil
end

local function fireChanged(self, key)
	local signal = rawget(self, "changed")[key]
	if signal then
		signal:Fire()
	end
end

local function setParent(self, parent)
	local props = rawget(self, "props")
	local previous = props.Parent
	if previous == parent then
		return
	end
	if previous then
		local siblings = rawget(previous, "children")
		table.remove(siblings, table.find(siblings, self))
	end
	props.Parent = parent
	if parent then
		table.insert(rawget(parent, "children"), self)
		local added = rawget(parent, "signals").ChildAdded
		if added then
			added:Fire(self)
		end
	end
	fireChanged(self, "Parent")
end

InstanceMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local props = rawget(self, "props")
	if props[key] == value then
		return
	end
	props[key] = value
	fireChanged(self, key)
end

local function newInstance(className)
	local props = { ClassName = className, Name = className }
	if GUI_OBJECTS[className] then
		props.AbsoluteSize = Vector2.zero
		props.AbsolutePosition = Vector2.zero
		props.Visible = true
		props.Text = ""
		props.TextBounds = Vector2.zero
		props.CanvasPosition = Vector2.zero
		props.Size = UDim2.new(0, 0, 0, 0)
		props.Position = UDim2.new(0, 0, 0, 0)
		props.AnchorPoint = Vector2.zero
	elseif className == "UIListLayout" or className == "UIGridLayout" then
		props.AbsoluteContentSize = Vector2.zero
	elseif className == "ScreenGui" then
		-- The engine sizes a new ScreenGui on the next frame; `lateLayout`
		-- models that, and Stub.layout() is the frame.
		props.AbsoluteSize = if Stub.lateLayout then Vector2.zero else viewport
		props.AbsolutePosition = Vector2.zero
		props.Enabled = true
	elseif className == "UIScale" then
		props.Scale = 1
	end
	local instance = setmetatable({ props = props, signals = {}, changed = {}, children = {}, attributes = {} }, InstanceMeta)
	if className == "ScreenGui" then
		table.insert(screenGuis, instance)
	end
	return instance
end

function Methods:GetChildren()
	return table.clone(rawget(self, "children"))
end

function Methods:GetDescendants()
	local found = {}
	local function visit(instance)
		for _, child in rawget(instance, "children") do
			table.insert(found, child)
			visit(child)
		end
	end
	visit(self)
	return found
end

function Methods:FindFirstChild(name, recursive)
	for _, child in if recursive then self:GetDescendants() else rawget(self, "children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end

Methods.WaitForChild = Methods.FindFirstChild

function Methods:IsA(className)
	local own = self.ClassName
	return own == className
		or className == "Instance"
		or (className == "GuiObject" and GUI_OBJECTS[own] == true)
		or (className == "GuiButton" and (own == "TextButton" or own == "ImageButton"))
		or (className == "BasePart" and (own == "Part" or own == "MeshPart"))
end

function Methods:FindFirstChildOfClass(className)
	for _, child in rawget(self, "children") do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

function Methods:FindFirstChildWhichIsA(className, recursive)
	for _, child in if recursive then self:GetDescendants() else rawget(self, "children") do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function Methods:IsDescendantOf(ancestor)
	local parent = self.Parent
	while parent do
		if parent == ancestor then
			return true
		end
		parent = parent.Parent
	end
	return false
end

function Methods:GetPropertyChangedSignal(property)
	local changed = rawget(self, "changed")
	changed[property] = changed[property] or newSignal()
	return changed[property]
end

function Methods:GetAttribute(name)
	return rawget(self, "attributes")[name]
end

function Methods:SetAttribute(name, value)
	rawget(self, "attributes")[name] = value
end

function Methods:Destroy()
	if rawget(self, "destroyed") then
		return
	end
	rawset(self, "destroyed", true)
	local destroying = rawget(self, "signals").Destroying
	if destroying then
		destroying:Fire()
	end
	setParent(self, nil)
	for _, child in table.clone(rawget(self, "children")) do
		child:Destroy()
	end
	for _, group in { rawget(self, "signals"), rawget(self, "changed") } do
		for _, signal in group do
			for _, connection in table.clone(signal.list) do
				connection:Disconnect()
			end
		end
	end
end

function Methods:ClearAllChildren()
	for _, child in table.clone(rawget(self, "children")) do
		child:Destroy()
	end
end

function Methods:Clone()
	local copy = newInstance(self.ClassName)
	for key, value in rawget(self, "props") do
		if key ~= "Parent" then
			rawget(copy, "props")[key] = value
		end
	end
	for _, child in rawget(self, "children") do
		child:Clone().Parent = copy
	end
	return copy
end

function Methods:CaptureFocus()
	rawset(self, "focused", true)
	self.Focused:Fire()
end

function Methods:ReleaseFocus(submitted)
	rawset(self, "focused", false)
	self.FocusLost:Fire(submitted == true)
end

function Methods:IsFocused()
	return rawget(self, "focused") == true
end

function Methods:GetService(name)
	if not services[name] then
		services[name] = newInstance(name)
	end
	return services[name]
end

function Methods:Create(target, _, goals)
	local tween = newInstance("Tween")
	rawset(tween, "target", target)
	rawset(tween, "goals", goals)
	return tween
end

function Methods:Play()
	local target = rawget(self, "target")
	if not rawget(target, "destroyed") then
		for key, value in rawget(self, "goals") do
			target[key] = value
		end
	end
	self.Completed:Fire(Enum.PlaybackState.Completed)
end

function Methods:Cancel() end

function Methods:JSONEncode(value)
	return jsonEncode(value)
end

function Methods:JSONDecode(text)
	return jsonDecode(text)
end

function Methods:GetUserThumbnailAsync(userId)
	return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150", true
end

function Methods:GetGuiInset()
	return Vector2.new(0, 36), Vector2.zero
end

function Methods:IsStudio()
	return false
end

function Methods:GetFocusedTextBox()
	return nil
end

function Methods:GetNetworkPing()
	return 0.05
end

local Instance = {}

function Instance.new(className, parent)
	local instance = newInstance(className)
	if parent then
		instance.Parent = parent
	end
	return instance
end

local game = newInstance("DataModel")
rawget(game, "props").PlaceId = 1
local workspace = game:GetService("Workspace")
workspace.CurrentCamera = newInstance("Camera")
workspace.CurrentCamera.ViewportSize = viewport

do
	local players = game:GetService("Players")
	local player = newInstance("Player")
	player.Name = "TestUser"
	player.DisplayName = "Tester"
	player.UserId = 1
	newInstance("PlayerGui").Parent = player
	player.Parent = players
	players.LocalPlayer = player

	local input = game:GetService("UserInputService")
	input.TouchEnabled = false
	input.KeyboardEnabled = true
	input.MouseEnabled = true
end

-- Executor functions --------------------------------------------------------

local function writefile(path, content)
	Stub.files[path] = content
end

local function readfile(path)
	assert(Stub.files[path] ~= nil, "file not found: " .. path)
	return Stub.files[path]
end

local function isfile(path)
	return Stub.files[path] ~= nil
end

local function isfolder(path)
	return Stub.folders[path] == true
end

local function makefolder(path)
	Stub.folders[path] = true
end

local function delfile(path)
	Stub.files[path] = nil
end

local function listfiles(folder)
	local found = {}
	for path in Stub.files do
		if string.sub(path, 1, #folder + 1) == folder .. "/" and not string.find(path, "/", #folder + 2, true) then
			table.insert(found, path)
		end
	end
	table.sort(found)
	return found
end

local function setclipboard(text)
	Stub.clipboard = text
end

local function identifyexecutor()
	return "TestExecutor", "1.0"
end

local function getgenv()
	return Stub.genv
end

local function request(options)
	if Stub.request then
		return Stub.request(options)
	end
	return { StatusCode = 404, Body = "" }
end

-- Test helpers --------------------------------------------------------------

function Stub.check(condition, label)
	if condition then
		Stub.passed += 1
	else
		table.insert(Stub.failed, label)
	end
end

function Stub.equal(actual, expected, label)
	if actual == expected then
		Stub.passed += 1
	else
		table.insert(Stub.failed, `{label}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

function Stub.viewport(width, height)
	viewport = Vector2.new(width, height)
	workspace.CurrentCamera.ViewportSize = viewport
	for _, gui in screenGuis do
		if not rawget(gui, "destroyed") then
			gui.AbsoluteSize = viewport
		end
	end
	Stub.flush()
end

function Stub.layout()
	Stub.viewport(viewport.X, viewport.Y)
end

function Stub.place(instance, x, y, width, height)
	instance.AbsolutePosition = Vector2.new(x, y)
	instance.AbsoluteSize = Vector2.new(width, height)
end

function Stub.find(root, predicate)
	for _, descendant in root:GetDescendants() do
		if predicate(descendant) then
			return descendant
		end
	end
	return nil
end

function Stub.byText(root, text)
	return Stub.find(root, function(instance)
		return instance.Text == text
	end)
end

function Stub.byName(root, name)
	return root:FindFirstChild(name, true)
end

function Stub.click(button)
	button.Activated:Fire()
	Stub.flush()
end

function Stub.key(keyCode, processed, ended)
	local input = { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero }
	local service = game:GetService("UserInputService")
	if ended then
		service.InputEnded:Fire(input, processed == true)
	else
		service.InputBegan:Fire(input, processed == true)
	end
	Stub.flush()
end

function Stub.inputConnections()
	local service = game:GetService("UserInputService")
	local count = 0
	for _, signal in rawget(service, "signals") do
		count += #signal.list
	end
	return count
end

function Stub.guis()
	local live = {}
	for _, gui in screenGuis do
		if not rawget(gui, "destroyed") then
			table.insert(live, gui)
		end
	end
	return live
end

function Stub.report()
	Stub.flush()
	for _, message in Stub.errors do
		table.insert(Stub.failed, "thread error: " .. message)
	end
	if #Stub.failed == 0 then
		print(`PASS {Stub.passed} assertions`)
	else
		print(`FAIL {#Stub.failed} of {Stub.passed + #Stub.failed}`)
		for _, label in Stub.failed do
			print("  - " .. label)
		end
	end
end
