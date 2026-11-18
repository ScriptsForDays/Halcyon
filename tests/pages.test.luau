-- Sub-pages: opened from a row, left by the back arrow, the breadcrumb or
-- Escape; searchable; the navigation marks the tab they belong to.

local window = Halcyon:CreateWindow({ Title = "Pages", Folder = "PagesHub", SavePreferences = false })
local combat = window:Tab({ Title = "Combat", Icon = "swords" })
local main = combat:Section({ Title = "Aim" })
main:Toggle({ Title = "Aimbot", Flag = "Aimbot" })
local tuning = main:Page({ Title = "Prediction", Description = "How far ahead to aim" })
local lead = tuning:Section({ Title = "Lead" }):Slider({ Title = "Lead time", Flag = "Lead", Min = 0, Max = 1, Step = 0.05 })
local deeper = tuning:Page({ Title = "Advanced" })
deeper:Toggle({ Title = "Gravity drop", Flag = "Drop" })
local other = window:Tab({ Title = "Visuals" })
Stub.flush()

Stub.check(tuning.link ~= nil and Stub.byText(main.root, "Prediction") ~= nil, "the section shows a row for the page")
Stub.click(Stub.byText(main.root, "Prediction"))
Stub.equal(window.selected, tuning, "pressing the row opens the page")
Stub.check(tuning.page.Visible and not combat.page.Visible, "the page replaces the tab's page")
Stub.check(Stub.byText(tuning.page, "How far ahead to aim") ~= nil, "the description shows under the breadcrumb")
Stub.check(Stub.byText(tuning.page, "Combat") ~= nil, "the breadcrumb names the tab above")

Stub.click(Stub.byText(tuning.page, "Advanced"))
Stub.equal(window.selected, deeper, "pages nest")
Stub.click(Stub.byName(deeper.page, "Back"))
Stub.equal(window.selected, tuning, "the back arrow goes up one level")
Stub.key(Enum.KeyCode.Escape)
Stub.equal(window.selected, combat, "Escape goes up one level")

-- Search reaches rows inside pages and opens the page that has them.
window:Search("gravity")
Stub.flush()
Stub.equal(window.selected, deeper, "a match inside a page opens that page")
window:Search("")
Stub.flush()

-- Values on pages are flags like any other.
lead:Set(0.4)
Stub.equal(window:GetValues().Lead, 0.4, "page rows are flagged")
window:SelectTab(other)
Stub.equal(window.selected, other, "other tabs still open")
window:Unload()
