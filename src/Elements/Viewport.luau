-- A 3D preview of a model: a pet, a weapon, an outfit, the player's own
-- character. The model is copied, so the original stays where it is. Drag to
-- turn it; Spin turns it on its own while the row is on screen.
--
-- Options: Model (any Model or BasePart), Character (true previews the local
-- player), Height [180], Spin (degrees a second), Distance (camera distance;
-- fitted to the model when left out), FieldOfView [40].

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Row = require("./Row")

local Viewport = {}

-- Turning per pixel dragged, and how far the model may tip up or down.
local TURN = 0.012
local TIP = math.rad(60)

-- A copy that can be shown: archivable for the clone, scripts removed so
-- nothing in the preview runs.
local function copyOf(source)
	if typeof(source) ~= "Instance" then
		return nil
	end
	local archivable = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(source.Clone, source)
	source.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	if copy:IsA("BasePart") then
		local holder = Instance.new("Model")
		copy.Parent = holder
		return holder
	end
	return copy
end

function Viewport.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local scope = row.scope
	local source = options.Model
	local model, size = nil, Vector3.one
	local yaw, pitch = math.rad(-25), math.rad(-10)

	local frame = Create.new("ViewportFrame", {
		Name = "Preview",
		Size = UDim2.new(1, 0, 0, options.Height or 180),
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = row.belowTitle(),
	})
	Create.corner(8, frame)
	local camera = Create.new("Camera", { FieldOfView = options.FieldOfView or 40, Parent = frame })
	frame.CurrentCamera = camera

	-- The model sits at the origin; the camera stays put and the model turns.
	local function place()
		if not model then
			return
		end
		local turned = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		pcall(model.PivotTo, model, turned)
		local radius = size.Magnitude / 2
		local distance = options.Distance or (radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.15)
		camera.CFrame = CFrame.new(0, 0, distance)
	end

	local function show(newSource)
		if model then
			model:Destroy()
			model = nil
		end
		source = newSource
		model = copyOf(source)
		if not model then
			return
		end
		-- Centre the model on its bounding box so it turns about its middle.
		local ok, box, extent = pcall(model.GetBoundingBox, model)
		if ok and box then
			size = extent
			pcall(function()
				model.WorldPivot = box
			end)
		end
		model.Parent = frame
		place()
	end

	local last = Vector2.zero
	Drag.track(scope, frame, function(position)
		last = position
		return true
	end, function(position)
		local travel = position - last
		last = position
		yaw += travel.X * TURN
		pitch = math.clamp(pitch + travel.Y * TURN, -TIP, TIP)
		place()
	end)

	-- Spin runs only while the row's tab is open and the window is showing.
	if type(options.Spin) == "number" and options.Spin ~= 0 then
		local speed = math.rad(options.Spin)
		scope:connect(RunService.RenderStepped, function(step)
			local window = row.window
			if model and window.Visible and (handle.Tab == nil or window.selected == handle.Tab) then
				yaw += speed * step
				place()
			end
		end)
	end

	function handle:Get()
		return source
	end

	-- Shows another model (or the character again with Set(nil) when
	-- Character is on).
	function handle:Set(newSource)
		if newSource == nil and options.Character then
			newSource = Players.LocalPlayer.Character
		end
		show(newSource)
		row.fire(source)
	end
	handle.SetModel = handle.Set

	-- Turns the model back to where it started.
	function handle:ResetView()
		yaw, pitch = math.rad(-25), math.rad(-10)
		place()
	end

	if options.Character then
		show(Players.LocalPlayer.Character)
		scope:connect(Players.LocalPlayer.CharacterAdded, function(character)
			-- The new character is filled in over a few frames.
			task.wait(0.5)
			if not scope.cleaned then
				show(character)
			end
		end)
	else
		show(source)
	end
	return handle
end

return Viewport
