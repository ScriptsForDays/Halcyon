-- The option lists that dropdowns, radio groups, checklists, chips and
-- tiles share.
--
-- An option is a plain value, or a table: { Text, Value, Icon, Image,
-- Description, Disabled }. { Heading = "Name" } starts a titled group.

local Options = {}

-- Returns the entries in order and the selectable values alone.
function Options.entries(list)
	local entries, values = {}, {}
	for _, raw in list or {} do
		if type(raw) == "table" then
			if raw.Heading ~= nil then
				table.insert(entries, { heading = tostring(raw.Heading) })
			else
				local value = if raw.Value ~= nil then raw.Value else (raw.Text or raw.Title)
				if value ~= nil then
					table.insert(entries, {
						value = value,
						text = tostring(raw.Text or raw.Title or value),
						icon = raw.Icon,
						image = raw.Image,
						description = raw.Description,
						disabled = raw.Disabled == true,
					})
					table.insert(values, value)
				end
			end
		else
			table.insert(entries, { value = raw, text = tostring(raw) })
			table.insert(values, raw)
		end
	end
	return entries, values
end

function Options.ordered(values, picked)
	local list = {}
	for _, value in values do
		if picked[value] then
			table.insert(list, value)
		end
	end
	return list
end

-- Replaces `picked` with the wanted values the list still offers.
function Options.pick(values, picked, wanted, multi)
	table.clear(picked)
	wanted = if multi and type(wanted) == "table" then wanted else { wanted }
	for _, item in wanted do
		if table.find(values, item) then
			picked[item] = true
			if not multi then
				break
			end
		end
	end
end

return Options
