-- Prints dist/Halcyon.types.luau from src/Core/Schema.luau. tools/bundle.mjs
-- runs it with the luau binary, with `Schema` already defined above this
-- file, and fails --check when the printed file and dist/ differ.
--
-- The options and values come from the schema; the method signatures below
-- are kept here by hand, next to each other, so one look shows what the
-- API is.

local out = {}
local function line(text)
	table.insert(out, text or "")
end

local function sortedKeys(map)
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- A table type from name = "type" pairs; `required` names stay non-optional.
local function record(name, fields, required, extra)
	line(`export type {name} = \{`)
	for _, key in sortedKeys(fields) do
		local kind = fields[key]
		local optional = not (required and required[key])
		local wrapped = if optional and not string.find(kind, "%?$") then (if string.find(kind, "[|&]") or string.find(kind, "->") then `({kind})?` else kind .. "?") else kind
		line(`\t{key}: {wrapped},`)
	end
	for _, extraLine in extra or {} do
		line("\t" .. extraLine)
	end
	line("}")
	line()
end

line("--!strict")
line("-- Types for Halcyon. Generated from src/Core/Schema.luau by tools/gen-types.luau;")
line("-- edit those, then run `node tools/bundle.mjs`.")
line("--")
line("-- With luau-lsp or Roblox's script editor:")
line("--   local Types = require(path.to.Halcyon.types)")
line("--   local Halcyon: Types.Halcyon = loadstring(game:HttpGet(URL))()")
line()
line("export type Image = string | number")
line("export type Callback = (...any) -> ()")
line("export type Condition = string | { any } | any")
line("export type MenuItem = { Title: string?, Icon: Image?, Callback: (() -> ())?, Danger: boolean?, Disabled: boolean?, Divider: boolean? }")
line("export type Background = string | { Kind: string?, Colors: { string | Color3 }?, Speed: number?, Intensity: number?, Image: Image?, Sheen: boolean?, Vignette: boolean?, SeeThrough: number? }")
line("export type Signal<T...> = { Connect: (self: any, (T...) -> ()) -> { Disconnect: (self: any) -> () } }")
line()

record("SharedOptions", Schema.shared)

line("export type Handle<T> = {")
for _, member in {
	"Frame: Frame,",
	"Kind: string,",
	"Flag: string?,",
	"Title: string,",
	"Changed: Signal<T>,",
	"Get: (self: any) -> T,",
	"Set: (self: any, value: T) -> (),",
	"SetSilent: (self: any, value: T) -> (),",
	"Reset: (self: any) -> (),",
	"GetDefault: (self: any) -> T,",
	"SetTitle: (self: any, text: string) -> (),",
	"SetDescription: (self: any, text: string?) -> (),",
	"SetDisabled: (self: any, disabled: boolean) -> (),",
	"SetEnabled: (self: any, enabled: boolean) -> (),",
	"SetVisible: (self: any, visible: boolean) -> (),",
	"Lock: (self: any, text: string?, icon: Image?) -> (),",
	"Unlock: (self: any) -> (),",
	"IsLocked: (self: any) -> boolean,",
	"ShowWhen: (self: any, source: any, expected: any?) -> (),",
	"EnableWhen: (self: any, source: any, expected: any?) -> (),",
	"Destroy: (self: any) -> (),",
	"[string]: any,",
} do
	line("\t" .. member)
end
line("}")
line()

local kinds = sortedKeys(Schema.elements)
for _, kind in kinds do
	local entry = Schema.elements[kind]
	local fields = table.clone(Schema.shared)
	for key, value in entry.options do
		fields[key] = value
	end
	record(kind .. "Options", fields, if Schema.untitled[kind] then nil else { Title = true })
end

-- Every container (tab, section, page, group, sheet) makes every element.
line("export type Elements = {")
for _, kind in kinds do
	line(`\t{kind}: (self: any, options: {kind}Options) -> Handle<{Schema.elements[kind].value}>,`)
end
line("}")
line()

record("TabOptions", Schema.tab, { Title = true })
record("SectionOptions", Schema.section)
record("NotifyOptions", Schema.notify)
record("WindowOptions", Schema.window)

line("export type Notice = {")
for _, member in {
	"Dismiss: () -> (),",
	"SetTitle: (text: string) -> (),",
	"SetContent: (text: string) -> (),",
	"SetKind: (kind: string) -> (),",
	"SetProgress: (fraction: number) -> (),",
	"Restart: (seconds: number?) -> (),",
	"Done: (title: string?, kind: string?) -> (),",
} do
	line("\t" .. member)
end
line("}")
line()

line("export type Section = Elements & {")
for _, member in {
	"SetTitle: (self: Section, text: string) -> (),",
	"SetBadge: (self: Section, value: any) -> (),",
	"SetCollapsed: (self: Section, collapsed: boolean) -> (),",
	"SetVisible: (self: Section, visible: boolean) -> (),",
	"SetEnabled: (self: Section, enabled: boolean) -> (),",
	"ShowWhen: (self: Section, source: any, expected: any?) -> (),",
	"EnableWhen: (self: Section, source: any, expected: any?) -> (),",
	"Group: (self: Section, options: { Columns: number? }?) -> Elements,",
	"Tab: (self: Section, name: string) -> Elements,",
	"SelectTab: (self: Section, name: string) -> (),",
	"Page: (self: Section, options: TabOptions) -> Tab,",
	"PopOut: (self: Section, open: boolean?) -> (),",
	"IsPoppedOut: (self: Section) -> boolean,",
	"SetBackground: (self: Section, spec: Background?) -> (),",
	"Destroy: (self: Section) -> (),",
} do
	line("\t" .. member)
end
line("}")
line()

line("export type Tab = Elements & {")
for _, member in {
	"Title: string,",
	"Section: (self: Tab, options: SectionOptions?) -> Section,",
	"Page: (self: Tab, options: TabOptions) -> Tab,",
	"Select: (self: Tab) -> (),",
	"SetTitle: (self: Tab, text: string) -> (),",
	"SetVisible: (self: Tab, visible: boolean) -> (),",
	"ShowWhen: (self: Tab, source: any, expected: any?) -> (),",
	"SetBadge: (self: Tab, value: any) -> (),",
	"Notice: (self: Tab, options: { Title: string?, Content: string?, Kind: string?, Dismissible: boolean? }) -> any,",
	"EmptyState: (self: Tab, options: { [string]: any }) -> any,",
} do
	line("\t" .. member)
end
line("}")
line()

line("export type Window = {")
for _, member in {
	"Flags: { [string]: Handle<any> },",
	"Visible: boolean,",
	"Errors: { { Title: string, Message: string, Trace: string?, Time: number } },",
	"OnUnload: Signal<>,",
	"TabChanged: Signal<Tab>,",
	"ConfigChanged: Signal<string, string?>,",
	"KeybindsChanged: Signal<>,",
	"ErrorsChanged: Signal<any>,",
	"SectionPopped: Signal<Section, boolean>,",
	"UpdateAvailable: Signal<string, string?>,",
	"Tab: (self: Window, options: TabOptions | string) -> Tab,",
	"SelectTab: (self: Window, tab: Tab) -> (),",
	"SettingsTab: (self: Window, options: { [string]: any }?) -> Tab,",
	"ConfigSection: (self: Window, target: Tab | Section, options: { [string]: any }?) -> Section,",
	"Sheet: (self: Window, options: { Title: string?, Width: number? }?) -> Elements & { Open: (any) -> (), Close: (any) -> (), IsOpen: boolean },",
	"QuickBar: (self: Window, options: { Items: { any } }) -> any,",
	"Notify: (self: Window, options: NotifyOptions | string) -> Notice,",
	"ClearNotifications: (self: Window) -> (),",
	"Dialog: (self: Window, options: { [string]: any }) -> any,",
	"Loading: (self: Window, options: { Title: string?, Text: string?, Icon: Image? }?) -> any,",
	"Show: (self: Window) -> (),",
	"Hide: (self: Window) -> (),",
	"Toggle: (self: Window) -> (),",
	"Minimize: (self: Window, minimized: boolean?) -> (),",
	"Set: (self: Window, name: string, value: any) -> boolean,",
	"Get: (self: Window, name: string) -> any,",
	"Search: (self: Window, query: string) -> (),",
	"JumpToMatch: (self: Window, step: number?) -> Handle<any>?,",
	"SetBackground: (self: Window, spec: Background?) -> (),",
	"SetLanguage: (self: Window, code: string) -> string,",
	"GetValues: (self: Window) -> { [string]: any },",
	"SetValues: (self: Window, values: { [string]: any }, silent: boolean?) -> number,",
	"ResetValues: (self: Window) -> (),",
	"Undo: (self: Window) -> (boolean, string?),",
	"ExportConfig: (self: Window) -> string?,",
	"ImportConfig: (self: Window, code: string) -> (boolean, string?),",
	"SaveConfig: (self: Window, name: string) -> (boolean, string?),",
	"LoadConfig: (self: Window, name: string) -> (boolean, string?),",
	"DeleteConfig: (self: Window, name: string) -> (boolean, string?),",
	"ListConfigs: (self: Window) -> { string },",
	"SetAutoload: (self: Window, name: string?) -> (boolean, string?),",
	"LoadAutoload: (self: Window) -> (boolean, string?),",
	"CheckForUpdate: (self: Window) -> (boolean, string?, string?),",
	"SupportPanel: (self: Window) -> any,",
	"ErrorsPanel: (self: Window) -> any,",
	"ClearErrors: (self: Window) -> (),",
	"RequestUnload: (self: Window) -> (),",
	"Unload: (self: Window) -> (),",
	"[string]: any,",
} do
	line("\t" .. member)
end
line("}")
line()

line("export type Halcyon = {")
for _, member in {
	"Version: string,",
	"CreateWindow: (self: Halcyon, options: WindowOptions?) -> Window?,",
	"Build: (self: Halcyon, spec: { Window: WindowOptions?, Tabs: { any }?, SettingsTab: any?, Autoload: boolean? }) -> (Window?, { [string]: Handle<any> }),",
	"RegisterElement: (self: Halcyon, kind: string, definition: { Build: (row: any, options: { [string]: any }, handle: Handle<any>) -> (), Options: { [string]: string }?, Value: string?, Untitled: boolean? }) -> boolean,",
	"Notify: (self: Halcyon, options: NotifyOptions | string) -> Notice,",
	"SetNotificationDefaults: (self: Halcyon, settings: { [string]: any }) -> (),",
	"ClearNotifications: (self: Halcyon) -> (),",
	"SetTheme: (self: Halcyon, name: string) -> (boolean, string?),",
	"AddTheme: (self: Halcyon, palette: { [string]: any }) -> (boolean, string?),",
	"SetAccent: (self: Halcyon, color: Color3?) -> (),",
	"SetLanguage: (self: Halcyon, code: string) -> string,",
	"GetLanguages: (self: Halcyon) -> { { Code: string, Name: string } },",
	"SetStrings: (self: Halcyon, map: { [string]: string | false }) -> (),",
	"GetStrings: (self: Halcyon) -> { [string]: string },",
	"SetDebug: (self: Halcyon, enabled: boolean) -> (),",
	"AddStyle: (self: Halcyon, kind: string, name: string, spec: { [string]: any }, base: string?) -> (boolean, string?),",
	"Unload: (self: Halcyon) -> (),",
	"[string]: any,",
} do
	line("\t" .. member)
end
line("}")
line()
line("return nil")

print(table.concat(out, "\n"))
