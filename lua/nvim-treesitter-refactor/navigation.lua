-- Definition based navigation module

local ts_utils = require'nvim-treesitter.ts_utils'
local utils = require'nvim-treesitter.utils'
local locals = require'nvim-treesitter.locals'
local configs = require'nvim-treesitter.configs'
local api = vim.api

local M = {}

function M.goto_definition(bufnr, fallback_function)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local node_at_point = ts_utils.get_node_at_cursor()

  if not node_at_point then return end

  local definition = locals.find_definition(node_at_point, bufnr)

  if fallback_function and definition.id == node_at_point.id then
    fallback_function()
  else
    ts_utils.goto_node(definition)
  end
end

function M.goto_definition_lsp_fallback(bufnr) M.goto_definition(bufnr, vim.lsp.buf.definition) end

--- Get definitions of bufnr (unique and sorted by order of appearance).
local function get_definitions(bufnr)
  local local_nodes = locals.get_locals(bufnr)

  -- Make sure the nodes are unique.
  local nodes_set = {}
  for _, loc in ipairs(local_nodes) do
    if loc.definition then
      locals.recurse_local_nodes(loc.definition, function(_, node, _, match)
        -- lua doesn't compare tables by value,
        -- use the value from byte count instead.
        local _, _, start = node:start()
        nodes_set[start] = {node = node, type = match or ""}
      end)
    end
  end

  -- Sort by order of appearance.
  local definition_nodes = vim.tbl_values(nodes_set)
  table.sort(definition_nodes, function (a, b)
    local _, _, start_a = a.node:start()
    local _, _, start_b = b.node:start()
    return start_a < start_b
  end)

  return definition_nodes
end

function M.list_definitions(bufnr)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local definitions = get_definitions(bufnr)

  if #definitions < 1 then return end

  local qf_list = {}

  for _, node in ipairs(definitions) do
    local lnum, col, _ = node.node:start()
    local type = string.upper(node.type:sub(1, 1))
    local text = ts_utils.get_node_text(node.node)[1] or ""
    table.insert(qf_list, {
      bufnr = bufnr,
      lnum = lnum + 1,
      col = col + 1,
      text = text,
      type = type,
    })
  end

  vim.fn.setqflist(qf_list, 'r')
  api.nvim_command('copen')
end

function M.list_definitions_toc()
  local winnr = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winnr)
  local definitions = get_definitions(bufnr)

  if #definitions < 1 then return end

  local loc_list = {}

  -- Force some types to act like they are parents
  -- instead of neighbors of the next nodes.
  local containers = {
    ['function'] = true,
    ['type'] = true,
    ['method'] = true,
  }

  local parents = {}

  for _, def in ipairs(definitions) do
    -- Get indentation level by putting all parents in a stack.
    -- The length of the stack minus one is the current level of indentation.
    local n = #parents
    for i=1, n do
      local index = n + 1 - i
      local parent_def = parents[index]
      if ts_utils.is_parent(parent_def.node, def.node)
          or (containers[parent_def.type] and ts_utils.is_parent(parent_def.node:parent(), def.node)) then
        break
      else
        parents[index] = nil
      end
    end
    parents[#parents + 1] = def

    local lnum, col, _ = def.node:start()
    local type = string.upper(def.type:sub(1, 1))
    local text = ts_utils.get_node_text(def.node)[1] or ""
    table.insert(loc_list, {
      bufnr = bufnr,
      lnum = lnum + 1,
      col = col + 1,
      text = string.rep('  ', #parents - 1) .. text,
      type = type,
    })
  end

  vim.fn.setloclist(winnr, loc_list, 'r')
  -- The title needs to end with `TOC`,
  -- so Neovim displays it like a TOC instead of an error list.
  vim.fn.setloclist(winnr, {}, 'a', {title = 'Definitions TOC'})
  api.nvim_command('lopen')
end

function M.goto_adjacent_usage(bufnr, delta)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local node_at_point = ts_utils.get_node_at_cursor()
  if not node_at_point then return end

  local def_node, scope = locals.find_definition(node_at_point, bufnr)
  local usages = locals.find_usages(def_node, scope, bufnr)

  local index = utils.index_of(usages, node_at_point)
  if not index then return end

  local target_index = (index + delta + #usages - 1) % #usages + 1
  ts_utils.goto_node(usages[target_index])
end

function M.goto_next_usage(bufnr) return M.goto_adjacent_usage(bufnr, 1) end
function M.goto_previous_usage(bufnr) return M.goto_adjacent_usage(bufnr, -1) end

function M.get_function_or_method_definitions(bufnr, node_at_point)
  local local_nodes = locals.get_locals(bufnr)

  local defs = {}

  for _, loc in ipairs(local_nodes) do
    if loc.definition and loc.definition.method and loc.definition.method.node then
      if not M.node_a_at_b(node_at_point, loc.definition.method.node) then
        table.insert(defs, loc.definition.method.node)
      end
    end
    if loc.definition and loc.definition["function"] and loc.definition["function"].node then
      if not M.node_a_at_b(node_at_point, loc.definition["function"].node) then
        table.insert(defs, loc.definition["function"].node)
      end
    end
  end

  table.sort(defs, M.node_a_before_b)
  return defs
end

function M.node_a_before_b(node_a, node_b)
  local start_row_a, start_col_a, _, _ = node_a:range()
  local start_row_b, start_col_b, _, _ = node_b:range()
  if start_row_a == start_row_b then return start_col_a < start_col_b end
  return start_row_a < start_row_b
end

function M.node_a_at_b(node_a, node_b)
  local start_row_a, start_col_a, _, _ = node_a:range()
  local start_row_b, start_col_b, _, _ = node_b:range()
  return (start_row_a == start_row_b) and (start_col_a == start_col_b)
end

function M.get_surrounding_nodes(sorted_nodes, node_at_point)
  if #sorted_nodes == 0 then return nil, nil end
  local left = nil
  local right = sorted_nodes[1]
  for i=1, #sorted_nodes do
    local node = sorted_nodes[i]
    if M.node_a_before_b(node, node_at_point) then
      left = node
      right = sorted_nodes[i+1]
    else
      break
    end
  end
  return left, right
end

function M.get_surrounding_function_or_method(bufnr)
  local bufnr = bufnr or api.nvim_get_current_buf()
  local node_at_point = ts_utils.get_node_at_cursor()
  if not node_at_point then return nil, nil end

  local defs = M.get_function_or_method_definitions(bufnr, node_at_point)
  local previous, next = M.get_surrounding_nodes(defs, node_at_point)
  return previous, next
end

function M.goto_next_function_or_method(bufnr)
  local _, next = M.get_surrounding_function_or_method(bufnr)
  if next then ts_utils.goto_node(next) end
end

function M.goto_previous_function_or_method(bufnr)
  local previous, _ = M.get_surrounding_function_or_method(bufnr)
  if previous then ts_utils.goto_node(previous) end
end

function M.attach(bufnr)
  local config = configs.get_module('refactor.navigation')

  for fn_name, mapping in pairs(config.keymaps) do
    local cmd = string.format([[:lua require'nvim-treesitter-refactor.navigation'.%s(%d)<CR>]], fn_name, bufnr)

    api.nvim_buf_set_keymap(bufnr, 'n', mapping, cmd, { silent = true, noremap = true })
  end
end

function M.detach(bufnr)
  local config = configs.get_module('refactor.navigation')

  for _, mapping in pairs(config.keymaps) do
    api.nvim_buf_del_keymap(bufnr, 'n', mapping)
  end
end

return M
