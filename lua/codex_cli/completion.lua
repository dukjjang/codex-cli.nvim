local M = {}

local function shorten(text, width)
	text = vim.trim((text or ""):gsub("%s+", " "))
	if width <= 0 then return "" end
	if vim.fn.strdisplaywidth(text) <= width then return text end
	local count = vim.fn.strchars(text)
	repeat
		count = count - 1
	until count == 0 or vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, count)) <= width - 1
	return vim.fn.strcharpart(text, 0, count) .. "…"
end

function M.setup(buf, commands, load_skills)
	local previous
	local group = vim.api.nvim_create_augroup("codex_completion_" .. buf, { clear = true })
	vim.api.nvim_create_autocmd("CompleteDone", {
		group = group,
		buffer = buf,
		callback = function()
			local cursor = vim.api.nvim_win_get_cursor(0)
			previous = { row = cursor[1], prefix = vim.api.nvim_get_current_line():sub(1, cursor[2]) }
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
		group = group,
		buffer = buf,
		callback = function()
			local cursor = vim.api.nvim_win_get_cursor(0)
			local prefix = vim.api.nvim_get_current_line():sub(1, cursor[2])
			if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected >= 0 then
				return
			end
			if previous and previous.row == cursor[1] and previous.prefix == prefix then
				return
			end
			previous = { row = cursor[1], prefix = prefix }
			local start = prefix:match("()%$[%w_:%-%.]*$")
			local slash = prefix:match("^/[%w%-]*$")
			if not start and not slash then
				return
			end
			start = start or 1
			local token = prefix:sub(start)
			local tick = vim.api.nvim_buf_get_changedtick(buf)
			local function show(items)
				if vim.api.nvim_get_current_buf() ~= buf or vim.fn.mode() ~= "i"
					or vim.api.nvim_buf_get_changedtick(buf) ~= tick
					or vim.api.nvim_win_get_cursor(0)[1] ~= cursor[1]
					or vim.api.nvim_win_get_cursor(0)[2] ~= cursor[2] then
					return
				end
				local matches = {}
				for _, item in ipairs(items) do
					if item.word:sub(1, #token):lower() == token:lower() then
						table.insert(matches, item)
					end
				end
				if #matches > 0 then
					local width = math.max(1, math.min(72, vim.api.nvim_win_get_width(0) - 4))
					local name_width = 0
					for _, item in ipairs(matches) do
						name_width = math.max(name_width, vim.fn.strdisplaywidth(item.word))
					end
					name_width = math.min(name_width, width)
					for index, item in ipairs(matches) do
						matches[index] = vim.tbl_extend("force", item, {
							abbr = shorten(item.word, name_width),
							menu = shorten(item.menu, math.min(24, width - name_width - 2)),
						})
					end
					vim.schedule(function()
						if vim.api.nvim_get_current_buf() == buf and vim.fn.mode() == "i"
							and vim.api.nvim_buf_get_changedtick(buf) == tick then
							vim.fn.complete(start, matches)
						end
					end)
				end
			end
			if slash then
				show(commands)
			else
				load_skills(function(skills)
					local items = {}
					for _, skill in ipairs(skills) do
						table.insert(items, { word = "$" .. skill.name, menu = skill.description, dup = 1 })
					end
					show(items)
				end)
			end
		end,
	})
end

return M
