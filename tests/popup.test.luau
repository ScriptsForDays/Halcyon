-- Found in Roblox Studio: the first popup of a session closed at once,
-- because the overlay ScreenGui it created reported its size a frame later
-- and that looked like a screen resize.
local library = Halcyon.Internal.library

Stub.lateLayout = true
local window = Halcyon:CreateWindow({ Title = "Popup Hub" })
Stub.layout()
local dropdown = window:Tab({ Title = "Choices" }):Dropdown({ Title = "Part", Values = { "Head", "Torso" } })

Stub.click(dropdown.Frame)
Stub.check(library.popup ~= nil, "the first popup opens")
Stub.layout()
Stub.check(library.popup ~= nil, "the overlay's first size report does not close the popup")
Stub.viewport(800, 600)
Stub.equal(library.popup, nil, "a real screen resize closes the popup")

Stub.click(dropdown.Frame)
local anchor = library.popup.anchor
anchor.AbsolutePosition = Vector2.new(40, 90)
Stub.flush()
Stub.equal(library.popup, nil, "a popup closes when its anchor moves")

Halcyon:Unload()
