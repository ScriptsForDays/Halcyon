-- Header looks: Bar, Tall, Wordmark and Sidebar, the Logo option, Icon and
-- TopbarImage switched off, the Text tab marker and the Panel section look.
local Internal = Halcyon.Internal
local Theme = Internal.Theme

Stub.check(#Halcyon:GetStyles("Header") == 4, "there are four header looks")

-- Bar is the default.
local bar = Halcyon:CreateWindow({ Title = "Bar Hub", Folder = "BarHub", SavePreferences = false })
Stub.equal(bar.topbar.Size.Y.Offset, 48, "the default top bar is 48 high")
Stub.equal(bar.body.Position.Y.Offset, 48, "and the page starts under it")
bar:Unload()

-- Tall: a taller bar, a larger picture and larger titles.
local tall = Halcyon:CreateWindow({ Title = "Tall Hub", Subtitle = "Farming", Folder = "TallHub", SavePreferences = false, HeaderStyle = "Tall", TopbarImage = "rbxassetid://1" })
Stub.equal(tall.topbar.Size.Y.Offset, 64, "a Tall header is 64 high")
Stub.equal(Stub.byName(tall.topbar, "TopbarImage").Size.X.Offset, 44, "with a 44 px picture")
Stub.equal(tall.titleLabel.TextSize, 16, "and a larger title")
tall:Unload()

-- Wordmark: the logo where the title was.
local wordmark = Halcyon:CreateWindow({ Title = "Word Hub", Folder = "WordHub", SavePreferences = false, HeaderStyle = "Wordmark", Version = "v1" })
local logo = Stub.byName(wordmark.brand, "Logo")
Stub.check(logo ~= nil and Stub.byText(logo, "Word Hub") ~= nil, "a Wordmark header draws the title as the logo when there is no image")
Stub.check(wordmark.versionTag.Visible, "the version tag sits beside it")
wordmark:SetTitle("Renamed")
Stub.check(Stub.byText(logo, "Renamed") ~= nil, "SetTitle changes the wordmark")
wordmark:Unload()
local pictured = Halcyon:CreateWindow({ Title = "Picture Hub", Folder = "PictureHub", SavePreferences = false, HeaderStyle = "Wordmark", Logo = { Image = "rbxassetid://5", Width = 120, Height = 28 } })
local image = Stub.byName(pictured.brand, "Logo")
Stub.check(image ~= nil and image.ClassName == "ImageLabel" and image.Size.X.Offset == 120, "Logo = { Image, Width, Height } draws the picture at that size")
local numbered = Halcyon:CreateWindow({ Title = "Number Hub", Folder = "NumberHub", SavePreferences = false, HeaderStyle = "Wordmark", Logo = 123456 })
local byId = Stub.byName(numbered.brand, "Logo")
Stub.check(byId ~= nil and byId.ClassName == "ImageLabel", "Logo takes a bare asset id like any other image option")
numbered:Unload()
pictured:Unload()

-- Sidebar: no top bar; the logo heads the sidebar with search under it.
local side = Halcyon:CreateWindow({ Title = "Side Hub", Subtitle = "Example", Folder = "SideHub", SavePreferences = false, HeaderStyle = "Sidebar" })
local farm = side:Tab({ Title = "Farm" })
farm:Section({ Title = "Auto" }):Toggle({ Title = "Auto harvest" })
side:Tab({ Title = "Shop" })
Stub.check(side.sidebarHeader, "the Sidebar header is on while the sidebar shows")
Stub.check(not side.brand.Visible, "the top bar's own title is hidden")
local column = Stub.byName(side.root, "Column")
local brand = Stub.byName(column, "SidebarBrand")
Stub.check(brand ~= nil and Stub.byText(brand, "Side Hub") ~= nil, "the sidebar starts with the logo")
Stub.check(Stub.byText(brand, "Example") ~= nil, "and the subtitle under it")
Stub.check(Stub.byName(column, "SearchArea") ~= nil, "search sits under the logo")
Stub.check(not side.topbarSearch.Visible, "the top bar's search box is hidden")
Stub.equal(side.body.Position.Y.Offset, 0, "the sidebar runs the full height")
Stub.check(side.topbar.Position.X.Offset > 0, "the buttons sit in a strip over the page")
side.searchBox.Text = "harvest"
Stub.equal(side.query, "harvest", "the sidebar's search filters the rows")
side.searchBox.Text = ""
side:SetMinimizeStyle("Topbar")
side:Minimize(true)
Stub.check(side.pill.Visible and not side.root.Visible, "with no top bar, minimising docks to the pill")
side:Minimize(false)
side:SetTitle("Side Hub 2")
Stub.check(Stub.byText(Stub.byName(side.root, "SidebarBrand"), "Side Hub 2") ~= nil, "SetTitle changes the sidebar's logo text")
side:Set("Search", false)
Stub.check(Stub.byName(Stub.byName(side.root, "Column"), "SearchArea") == nil, "Search = false removes the sidebar's search")
Stub.check(not side.topbarSearch.Visible, "and doesn't bring back the top bar's")
side:Set("Search", true)
-- A narrow window has no sidebar, so the top bar comes back.
Stub.viewport(500, 600)
Stub.flush()
Stub.check(not side.sidebarHeader and side.brand.Visible, "a narrow window puts the title back in the top bar")
Stub.check(side.topbarSearch.Visible, "with its search box")
Stub.check(Stub.byText(side.brand, "Side Hub 2") ~= nil, "and the current title")
Stub.viewport(1280, 720)
Stub.flush()
Stub.check(side.sidebarHeader, "a wide window goes back to the sidebar header")
side:Unload()

-- Logo options.
local plain = Halcyon:CreateWindow({ Title = "No Logo", Folder = "NoLogo", SavePreferences = false, HeaderStyle = "Sidebar", Logo = false })
plain:Tab({ Title = "Farm" })
Stub.check(Stub.byName(plain.root, "SidebarBrand") == nil, "Logo = false leaves the sidebar without a logo")
plain:Unload()
local imaged = Halcyon:CreateWindow({ Title = "Image Logo", Folder = "ImageLogo", SavePreferences = false, HeaderStyle = "Sidebar", Logo = "rbxassetid://7" })
imaged:Tab({ Title = "Farm" })
local picture = Stub.byName(Stub.byName(imaged.root, "SidebarBrand"), "Logo")
Stub.check(picture ~= nil and picture.ClassName == "ImageLabel", "Logo = an image draws it across the sidebar")
imaged:Unload()

-- Icon and TopbarImage switched off.
local bare = Halcyon:CreateWindow({ Title = "Bare", Folder = "Bare", SavePreferences = false, Icon = false, TopbarImage = false })
Stub.check(Stub.byName(bare.brand, "TopbarImage") == nil, "TopbarImage = false draws no picture")
local icons = 0
for _, child in bare.brand:GetChildren() do
	if child:IsA("ImageLabel") then
		icons += 1
	end
end
Stub.equal(icons, 0, "Icon = false draws no icon before the title")
bare:Unload()

-- The Text tab marker and the Panel section look.
local marked = Halcyon:CreateWindow({ Title = "Marked", Folder = "Marked", SavePreferences = false, TabIndicator = "Text" })
local first = marked:Tab({ Title = "First", Icon = "house" })
Stub.equal(first.buttonLabel.TextColor3, Theme.color("accent"), "the Text marker colours the open tab's title")
Stub.equal(first.button.BackgroundTransparency, 1, "with no fill behind it")
local panel = first:Section({ Title = "Movement", Style = "Panel" })
local speed = panel:Slider({ Title = "Walk speed", Min = 16, Max = 100 })
Stub.equal(speed.Frame.BackgroundTransparency, 0, "a Panel section's rows sit on their own inset")
Stub.equal(speed.Frame.BackgroundColor3, Theme.color("background"), "in the page colour")
marked:Unload()

-- On a narrow window the top-bar search folds to its icon, and opens while
-- it holds a query.
local slim = Halcyon:CreateWindow({ Title = "Slim Hub", Folder = "SlimHub", SavePreferences = false })
slim.size = Vector2.new(380, 500)
slim:layout()
Stub.equal(slim.topbarSearch.Size.X.Offset, 34, "a narrow window folds its search to the icon")
slim.topbarBox.Text = "walk"
slim.topbarBox.FocusLost:Fire(false)
Stub.equal(slim.topbarSearch.Size.X.Offset, 150, "a query keeps it open")
slim.size = Vector2.new(900, 500)
slim:layout()
Stub.equal(slim.topbarSearch.Size.X.Offset, 170, "a wide window shows the full box")
slim:Unload()
