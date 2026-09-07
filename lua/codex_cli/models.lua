local M = {}

function M.select(rpc, current_model, active, done)
	local models = {}
	local function select_model()
		vim.ui.select(models, {
			prompt = "Codex · 모델 선택",
			format_item = function(model)
				return model.displayName .. (model.model == current_model and " · 현재" or "")
					.. (model.isDefault and " · 기본" or "")
			end,
		}, function(model)
			if not active() then
				return
			end
			if not model then
				done()
				return
			end
			if #model.supportedReasoningEfforts == 0 then
				done(model.model, vim.NIL)
				return
			end
			vim.ui.select(model.supportedReasoningEfforts, {
				prompt = "Codex · 추론 강도 · " .. model.displayName,
				format_item = function(effort)
					return effort.reasoningEffort
						.. (effort.reasoningEffort == model.defaultReasoningEffort and " · 기본" or "")
						.. " — " .. effort.description
				end,
			}, function(effort)
				if active() then
					done(effort and model.model, effort and effort.reasoningEffort)
				end
			end)
		end)
	end
	local function page(cursor)
		rpc:request("model/list", { limit = 100, includeHidden = false, cursor = cursor }, function(result, err)
			if not active() then
				return
			end
			if err then
				done(nil, nil, err.message)
				return
			end
			for _, model in ipairs(result.data) do
				if not model.hidden then
					table.insert(models, model)
				end
			end
			if type(result.nextCursor) == "string" and result.nextCursor ~= "" then
				page(result.nextCursor)
			elseif #models == 0 then
				done(nil, nil, "사용 가능한 모델이 없습니다.")
			else
				select_model()
			end
		end)
	end
	page()
end

return M
