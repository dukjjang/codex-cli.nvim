-- The legacy nvim-treesitter directives request the pre-0.12 all=false API.
-- Adapt only their registration; leave Neovim's global API unchanged afterward.
local M = {}
function M.setup()
	if vim.fn.has("nvim-0.12") == 0 or not package.loaded["nvim-treesitter.query_predicates"] then
		return
	end
	local query = vim.treesitter.query
	local original = { add_predicate = query.add_predicate, add_directive = query.add_directive }
	for name, register in pairs(original) do
		query[name] = function(id, handler, opts)
			if type(opts) == "table" and opts.all == false then
				local legacy_handler = handler
				handler = function(match, ...)
					local legacy = {}
					for capture, nodes in pairs(match) do
						if type(capture) == "number" then
							legacy[capture] = nodes[#nodes]
						end
					end
					return legacy_handler(legacy, ...)
				end
				opts = vim.tbl_extend("force", opts, { all = true })
			end
			return register(id, handler, opts)
		end
	end
	package.loaded["nvim-treesitter.query_predicates"] = nil
	local ok, err = pcall(require, "nvim-treesitter.query_predicates")
	for name, register in pairs(original) do
		query[name] = register
	end
	if not ok then
		error(err)
	end
end
return M
