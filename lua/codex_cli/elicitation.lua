local M = {}
local function present(value)
  return value ~= nil and value ~= vim.NIL
end

-- MCP uses action/content, unlike command approvals' decision response.
function M.request(params, active, done, auto_approve)
  local finished = false
  local function finish(action, content)
    if finished then return end
    finished = true
    if not active() then action, content = "cancel", nil end
    done({ action = action, content = content })
  end
  local schema = params.requestedSchema
  if active() and params.mode == "form" and type(schema) == "table" and schema.type == "object"
    and type(schema.properties) == "table" and next(schema.properties) == nil
    and (not present(schema.required) or (type(schema.required) == "table" and next(schema.required) == nil)) then
    for _, tool in ipairs((auto_approve or {})[params.serverName] or {}) do
      if params.message == ('Allow the %s MCP server to run tool "%s"?'):format(params.serverName, tool) then
        finish("accept", vim.empty_dict())
        return
      end
    end
  end
  local title = "MCP · " .. tostring(params.serverName) .. ": " .. tostring(params.message)
  vim.ui.select({ "거절", "승인" }, { prompt = title }, function(choice)
    if not active() or not choice then finish("cancel"); return end
    if choice ~= "승인" then finish("decline"); return end
    if params.mode == "url" then
      if type(params.url) ~= "string" or not params.url:match("^https?://") then
        vim.notify("MCP: 지원하지 않는 인증 URL", vim.log.levels.WARN)
        finish("cancel"); return
      end
      vim.ui.select({ "취소", "브라우저에서 열기" }, { prompt = params.url }, function(open)
        if not active() or open ~= "브라우저에서 열기" then finish("cancel"); return end
        local ok, _, err = pcall(vim.ui.open, params.url)
        if not ok or err then finish("cancel"); return end
        finish("accept")
      end)
      return
    end
    local schema = params.requestedSchema
    if params.mode ~= "form" or type(schema) ~= "table" or schema.type ~= "object"
      or type(schema.properties) ~= "table" then
      vim.notify("MCP: 지원하지 않는 입력 양식 (" .. tostring(params.mode) .. ")", vim.log.levels.WARN)
      finish("cancel"); return
    end
    local keys, content, index = vim.tbl_keys(schema.properties), vim.empty_dict(), 0
    table.sort(keys)
    local function next_field()
      if not active() then finish("cancel"); return end
      index = index + 1
      local key = keys[index]
      if not key then finish("accept", content); return end
      local field = schema.properties[key]
      local required = type(schema.required) == "table" and vim.tbl_contains(schema.required, key)
      local prompt = (type(field.title) == "string" and field.title or key) .. (required and " *" or "")
      if type(field.description) == "string" then prompt = prompt .. " · " .. field.description end
      local function receive(value)
        if value == nil then finish("cancel"); return end
        if value ~= vim.NIL then content[key] = value end
        next_field()
      end
      if field.type == "boolean" or type(field.enum) == "table" or type(field.oneOf) == "table" then
        local choices = {}
        if not required then choices[#choices + 1] = { label = "생략", value = vim.NIL } end
        if field.type == "boolean" then
          vim.list_extend(choices, { { label = "예", value = true }, { label = "아니요", value = false } })
        elseif type(field.oneOf) == "table" then
          for _, option in ipairs(field.oneOf) do choices[#choices + 1] = { label = option.title, value = option.const } end
        else
          for i, value in ipairs(field.enum) do
            choices[#choices + 1] = { label = type(field.enumNames) == "table" and field.enumNames[i] or value, value = value }
          end
        end
        vim.ui.select(choices, { prompt = prompt, format_item = function(item) return item.label end }, function(item)
          receive(item and item.value)
        end)
        return
      end
      if field.type ~= "string" and field.type ~= "number" and field.type ~= "integer" and field.type ~= "array" then
        vim.notify("MCP: 지원하지 않는 필드 형식 " .. tostring(field.type), vim.log.levels.WARN)
        finish("cancel"); return
      end
      local function input()
        local default = present(field.default) and (field.type == "array" and vim.json.encode(field.default) or tostring(field.default)) or ""
        vim.ui.input({ prompt = prompt .. (field.type == "array" and " (JSON 배열)" or "") .. ": ", default = default }, function(text)
          if not active() or text == nil then finish("cancel"); return end
          if text == "" and not required then receive(vim.NIL); return end
          local value, valid = text, true
          if field.type == "number" or field.type == "integer" then
            value = tonumber(text)
            valid = value ~= nil and value == value and math.abs(value) ~= math.huge
              and (field.type ~= "integer" or value % 1 == 0)
              and (not present(field.minimum) or value >= field.minimum)
              and (not present(field.maximum) or value <= field.maximum)
          elseif field.type == "array" then
            local ok, decoded = pcall(vim.json.decode, text)
            value = decoded
            valid = ok and type(value) == "table" and vim.islist(value) and text:match("^%s*%[") ~= nil
            if valid then
              valid = (not present(field.minItems) or #value >= field.minItems) and (not present(field.maxItems) or #value <= field.maxItems)
              for _, entry in ipairs(value) do
                local allowed = field.items and field.items.enum
                if type(field.items) == "table" and type(field.items.anyOf) == "table" then
                  allowed = vim.tbl_map(function(option) return option.const end, field.items.anyOf)
                end
                if type(entry) ~= "string" or (type(allowed) == "table" and not vim.tbl_contains(allowed, entry)) then valid = false end
              end
            end
          else
            valid = (not present(field.minLength) or vim.fn.strchars(text) >= field.minLength)
              and (not present(field.maxLength) or vim.fn.strchars(text) <= field.maxLength)
          end
          if not valid then vim.notify("MCP: 입력값이 양식 조건에 맞지 않습니다", vim.log.levels.WARN); vim.schedule(input); return end
          receive(value)
        end)
      end
      input()
    end
    next_field()
  end)
end
return M
