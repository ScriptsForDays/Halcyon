-- The resize grip keeps the window's bottom-right corner under the pointer,
-- wherever the window sits and at any scale, and stops at the screen edge
-- without running ahead of what is shown.

local function bottomRight(window)
	local root = window.root
	local shown = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset) * window.scale
	local centre = Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
	return centre + shown / 2
end

local function near(a, b)
	return math.abs(a.X - b.X) <= 1 and math.abs(a.Y - b.Y) <= 1
end

local function follows(window, label, path)
	local start = bottomRight(window)
	local misses = {}
	local points = {}
	for _, step in path do
		table.insert(points, start + step)
	end
	Stub.drag(window.grip, start, points, function(point)
		if not near(bottomRight(window), point) then
			local got = bottomRight(window)
			table.insert(misses, `{point.X},{point.Y} got {got.X},{got.Y}`)
		end
	end)
	Stub.check(#misses == 0, `{label}: corner follows the pointer ({table.concat(misses, "; ")})`)
end

Stub.viewport(1280, 720)

-- A window that was never moved sits centred.
local centred = Halcyon:CreateWindow({ Title = "Grip Hub", Folder = "GripHub", SavePreferences = false, Size = Vector2.new(600, 400) })
Stub.flush()
follows(centred, "centred", { Vector2.new(10, 5), Vector2.new(40, 30), Vector2.new(120, 60), Vector2.new(60, 20) })
centred:Unload()

-- A window the player dragged keeps its top-left corner where it was.
local moved = Halcyon:CreateWindow({ Title = "Moved Hub", Folder = "MovedHub", SavePreferences = false, Size = Vector2.new(600, 400) })
Stub.flush()
moved.placed = Vector2.new(40, 30)
moved:layout()
follows(moved, "dragged", { Vector2.new(10, 10), Vector2.new(50, 40), Vector2.new(150, 90) })
Stub.equal(moved.placed, Vector2.new(40, 30), "resizing leaves the top-left corner in place")

-- Scaled up, the pointer still lands on the corner.
moved:SetScale(1.25)
Stub.flush()
follows(moved, "scale 1.25", { Vector2.new(20, 15), Vector2.new(80, 50) })
moved:SetScale(1)
Stub.flush()

-- Past the screen edge the window stops at the edge, and coming back moves
-- it straight away instead of after a dead zone.
moved.size = Vector2.new(600, 400)
moved:layout()
local start = bottomRight(moved)
Stub.drag(moved.grip, start, { Vector2.new(2000, start.Y), Vector2.new(start.X + 100, start.Y) })
Stub.check(near(bottomRight(moved), Vector2.new(start.X + 100, start.Y)), "dragging back from past the edge follows at once")
Stub.check(moved.size.X <= (1280 - moved.placed.X), "the saved size never exceeds what fits on screen")

-- Never smaller than the minimum.
local before = bottomRight(moved)
Stub.drag(moved.grip, before, { before - Vector2.new(1000, 1000) })
Stub.check(moved.size.X >= 420 and moved.size.Y >= 300, "the grip stops at the minimum size")
moved:Unload()
