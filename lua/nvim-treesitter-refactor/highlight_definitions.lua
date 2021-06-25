-- This module highlights reference usages and the corresponding
-- definition on cursor hold.

local configs = require "nvim-treesitter.configs"
local ts_utils = require "nvim-treesitter.ts_utils"
local locals = require "nvim-treesitter.locals"
local api = vim.api
local cmd = api.nvim_command

local M = {}

local usage_namespace = api.nvim_create_namespace "nvim-treesitter-usages"
local last_nodes = {}

function M.highlight_usages(bufnr)
  local node_at_point = ts_utils.get_node_at_cursor()
  -- Don't calculate usages again if we are on the same node.
  if node_at_point and node_at_point == last_nodes[bufnr] and M.has_highlights(bufnr) then
    return
  else
    last_nodes[bufnr] = node_at_point
  end

  M.clear_usage_highlights(bufnr)
  if not node_at_point then
    return
  end

  local def_node, scope = locals.find_definition(node_at_point, bufnr)
  local usages = locals.find_usages(def_node, scope, bufnr)

  for _, usage_node in ipairs(usages) do
    if usage_node ~= node_at_point then
      ts_utils.highlight_node(usage_node, bufnr, usage_namespace, "TSDefinitionUsage")
    end
  end

  if def_node ~= node_at_point then
    ts_utils.highlight_node(def_node, bufnr, usage_namespace, "TSDefinition")
  end
end

function M.has_highlights(bufnr)
  return #api.nvim_buf_get_extmarks(bufnr, usage_namespace, 0, -1, {}) > 0
end

function M.clear_usage_highlights(bufnr)
  api.nvim_buf_clear_namespace(bufnr, usage_namespace, 0, -1)
end

function M.attach(bufnr)
  local config = configs.get_module "refactor.highlight_definitions"
  cmd(string.format("augroup NvimTreesitterUsages_%d", bufnr))
  cmd "au!"
  -- luacheck: push ignore 631
  cmd(
    string.format(
      [[autocmd CursorHold <buffer=%d> lua require'nvim-treesitter-refactor.highlight_definitions'.highlight_usages(%d)]],
      bufnr,
      bufnr
    )
  )
  if config.clear_on_cursor_move then
    cmd(
      string.format(
        [[autocmd CursorMoved <buffer=%d> lua require'nvim-treesitter-refactor.highlight_definitions'.clear_usage_highlights(%d)]],
        bufnr,
        bufnr
      )
    )
  end
  cmd(
    string.format(
      [[autocmd InsertEnter <buffer=%d> lua require'nvim-treesitter-refactor.highlight_definitions'.clear_usage_highlights(%d)]],
      bufnr,
      bufnr
    )
  )
  -- luacheck: pop
  cmd "augroup END"
end

function M.detach(bufnr)
  M.clear_usage_highlights(bufnr)
  cmd(string.format("autocmd! NvimTreesitterUsages_%d CursorHold", bufnr))
  cmd(string.format("autocmd! NvimTreesitterUsages_%d CursorMoved", bufnr))
  cmd(string.format("autocmd! NvimTreesitterUsages_%d InsertEnter", bufnr))
  last_nodes[bufnr] = nil
end

return M
