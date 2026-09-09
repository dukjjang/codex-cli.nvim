local M = {}

function M.list(rpc, cwd, callback)
	rpc:request("skills/list", { cwds = { cwd }, forceReload = true }, function(result, err)
		if err then
			callback(nil, err)
			return
		end
		local skills = {}
		for _, entry in ipairs(result.data) do
			if entry.cwd == cwd then
				for _, skill in ipairs(entry.skills) do
					if skill.enabled then
						table.insert(skills, skill)
					end
				end
			end
		end
		callback(skills)
	end)
end

-- Match whole skill names; never derive a path from user input.
function M.inputs(text, skills)
	local inputs, seen = {}, {}
	for name in text:gmatch("%$([%w_:%-%.]+)") do
		for _, skill in ipairs(skills) do
			if skill.name == name and not seen[skill.path] then
				seen[skill.path] = true
				table.insert(inputs, { type = "skill", name = skill.name, path = skill.path })
			end
		end
	end
	return inputs
end

return M
