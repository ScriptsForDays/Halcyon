-- The built-in palettes. Every text role keeps a contrast of 4.5 or more on
-- the four surfaces it is drawn on; tests/theme.test.luau checks each pair.

local hex = Color3.fromHex

local function palette(name, colors)
	local roles = string.split("background,surface,card,raised,hover,stroke,text,textMuted,accent,accentHover,onAccent,focus,success,warning,danger,info", ",")
	local result = { Name = name }
	for index, role in roles do
		result[role] = hex(colors[index])
	end
	return result
end

-- Order: background, surface, card, raised, hover, stroke, text, textMuted,
-- accent, accentHover, onAccent, focus, success, warning, danger, info.
return {
	palette("Midnight", { "0F1115", "14171C", "171A20", "1E222A", "272C36", "2A2F3A", "ECEEF2", "9BA3B2", "5B8DEF", "7AA3F5", "0B1220", "8FB4FF", "3FCF8E", "F5B74F", "F0616D", "5BB8F0" }),
	palette("Onyx", { "0A0A0A", "0F0F0F", "131313", "1A1A1A", "242424", "272727", "F2F2F2", "A0A0A0", "FFFFFF", "D9D9D9", "0A0A0A", "FFFFFF", "4ADE80", "FACC15", "F87171", "7DD3FC" }),
	palette("Rose", { "141012", "191416", "1D1719", "251D20", "30262A", "33282C", "F3ECEE", "B3A5AA", "F0527F", "F5749A", "1A0810", "FF9DB8", "4FD39A", "F2B45C", "F26D6D", "6DBBEF" }),
	palette("Aqua", { "0E1216", "12171C", "151B21", "1B232B", "232D37", "26313C", "E8F1F5", "96A7B3", "22D3EE", "5FE1F4", "04161A", "7DE9F8", "3FD68F", "F5BC55", "F26B76", "5CB6F2" }),
	palette("Ember", { "12100E", "171411", "1B1714", "231E1A", "2E2722", "322A24", "F4EEE8", "B1A498", "F08C3A", "F5A562", "1A0E04", "FFC08A", "57CF8A", "F2C14E", "F0655F", "66B5E8" }),
	palette("Forest", { "0D1210", "111714", "141B18", "1A231F", "222E28", "25322C", "E9F2EE", "97AAA1", "34D399", "5FE0B0", "04160F", "86EFC4", "4ADE80", "F0C050", "F0736C", "62B8EA" }),
	palette("Amethyst", { "100E16", "15121C", "181521", "201C2B", "2A2538", "2D283C", "EEEAF6", "A69FB8", "9D7BF5", "B397F8", "100824", "C9B5FF", "4FD6A0", "F3BD5A", "F26D7E", "6BB4F5" }),
	palette("Crimson", { "120E0F", "171213", "1B1516", "231B1D", "2E2326", "32272A", "F5ECED", "B3A2A5", "EF4444", "F36B6B", "1A0606", "FF9A9A", "4FCF8C", "F2B950", "FF7A7A", "6AB6EC" }),
	palette("Glacier", { "1B1F27", "20252E", "242A34", "2B323E", "353D4B", "3A4352", "ECEFF4", "ABB5C5", "88C0D0", "A3D3E0", "10202A", "B5E0EC", "A3BE8C", "EBCB8B", "E08A93", "81A1C1" }),
	palette("Daylight", { "F6F7F9", "EEF0F3", "FFFFFF", "E9ECF0", "DDE1E7", "D3D8DF", "14171C", "525B69", "2A66D9", "1F56BF", "FFFFFF", "2A66D9", "15803D", "B45309", "C92A3A", "0B6CAB" }),
	-- True black, for OLED screens.
	palette("OLED", { "000000", "050505", "0A0A0A", "121212", "1C1C1C", "222222", "F5F5F5", "A3A3A3", "7C9CFF", "9AB2FF", "050816", "AFC3FF", "4ADE80", "FACC15", "F87171", "7DD3FC" }),
	-- The strongest contrast: white text and a yellow accent on black.
	palette("Contrast", { "000000", "0A0A0A", "101010", "1A1A1A", "2A2A2A", "6B6B6B", "FFFFFF", "D6D6D6", "FFD400", "FFE14D", "000000", "FFFFFF", "3DFF7A", "FFB000", "FF5C5C", "5CC8FF" }),
	palette("Sunset", { "15100F", "1B1413", "201817", "2A201E", "352825", "3A2C29", "F8EEEA", "BFA9A2", "FF7A59", "FF9878", "1E0A04", "FFB49E", "5BD69A", "F7C25A", "F2666F", "6DBBEF" }),
	palette("Ocean", { "0B1220", "0F1829", "121C30", "18253D", "20304D", "243552", "E6EEF8", "93A6C0", "3B82F6", "60A5FA", "06101F", "93C5FD", "34D399", "FBBF24", "F87171", "38BDF8" }),
	palette("Aurora", { "0E1015", "12151C", "151922", "1C2130", "252B3D", "293046", "ECEFF7", "9EA6BC", "2DD4BF", "5EEAD4", "04201C", "99F6E4", "4ADE80", "F5C054", "F2707F", "818CF8" }),
	palette("Latte", { "F8F4EE", "F0EAE1", "FFFDF9", "EAE3D8", "E0D7C9", "D6CCBC", "1F1A14", "5E5448", "C2410C", "A3360A", "FFFFFF", "C2410C", "15803D", "A16207", "B91C1C", "0369A1" }),
}
