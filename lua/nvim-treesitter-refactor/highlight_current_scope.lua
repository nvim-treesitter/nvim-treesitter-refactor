-- This module highlights the current scope of at the cursor position

local configs = require "nvim-treesitter.configs"
local ts_utils = require "nvim-treesitter.ts_utils"
local locals = require "nvim-treesitter.locals"
local api = vim.api
local cmd = api.nvim_command

local M = {}

local current_scope_namespace = api.nvim_create_namespace "nvim-treesitter-current-scope"

function M.highlight_current_scope(bufnr)
  M.clear_highlights(bufnr)

  local node_at_point = ts_utils.get_node_at_cursor()
  local current_scope = locals.containing_scope(node_at_point, bufnr)

  if current_scope then
    local config = configs.get_module "refactor.highlight_current_scope"
    -- Highlight range [start_line, end_line) 0-based
    local highlighter = function(start_line, end_line)
      vim.api.nvim_buf_set_extmark(bufnr, current_scope_namespace, math.max(vim.fn.line "w0" - 1, start_line), 0, {
        end_row = math.min(vim.fn.line "w$", end_line),
        end_col = 0,
        hl_group = "TSCurrentScope",
        hl_eol = config.highlight_eol,
      })
    end
    local start_line, _, end_line, _ = current_scope:range()

    if start_line ~= 0 or end_line ~= vim.fn.line "$" then
      highlighter(start_line, vim.fn.line "." + (config.highlight_cursor and 0 or -1))
      highlighter(vim.fn.line ".", end_line + 1)
    end
  end
end

function M.clear_highlights(bufnr)
  api.nvim_buf_clear_namespace(bufnr, current_scope_namespace, 0, -1)
end

function M.attach(bufnr)
  cmd(string.format("augroup NvimTreesitterCurrentScope_%d", bufnr))
  cmd "au!"
  -- luacheck: push ignore 631
  cmd(
    string.format(
      [[autocmd CursorMoved,WinScrolled <buffer=%d> lua require'nvim-treesitter-refactor.highlight_current_scope'.highlight_current_scope(%d)]],
      bufnr,
      bufnr
    )
  )
  cmd(
    string.format(
      [[autocmd BufLeave <buffer=%d> lua require'nvim-treesitter-refactor.highlight_current_scope'.clear_highlights(%d)]],
      bufnr,
      bufnr
    )
  )
  -- luacheck: pop
  cmd "augroup END"
end

function M.detach(bufnr)
  M.clear_highlights(bufnr)
  cmd(string.format("autocmd! NvimTreesitterCurrentScope_%d CursorMoved", bufnr))
  cmd(string.format("autocmd! NvimTreesitterCurrentScope_%d BufLeave", bufnr))
end

return M
