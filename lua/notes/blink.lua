local notes = require("notes")
local async = require("blink.cmp.lib.async")
local kind = require("blink.cmp.types").CompletionItemKind

local M = {}

local function update()
  notes.update(false, function(data)
    local items = {}
    for key, _ in pairs(data) do
      table.insert(items, {
        label = key,
        insertText = key .. "]]",
        kind = kind.File,
      })
    end
    M.items = items
  end)
end

function M.new(opts)
  opts = vim.tbl_deep_extend("keep", opts, {}, { items = {}, })
  update()
  return setmetatable(opts, { __index = M })
end

function M:enabled()
  return vim.bo.filetype == 'markdown'
end

---@param context blink.cmp.Context
function M:get_completions(context, callback)
  local task = async.task.empty():map(function()
    local items = {}
    if context.line:sub(context.bounds.start_col - 2, context.bounds.start_col - 1) == "[[" then
      items = M.items
    end
    callback({
      items = items,
      context = context,
    })
    update()
  end)
  return function()
    task:cancel()
  end
end

return M
