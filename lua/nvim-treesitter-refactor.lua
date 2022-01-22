local queries = require "nvim-treesitter.query"

local M = {}

function M.init()
  require("nvim-treesitter").define_modules {
    refactor = {
      highlight_definitions = {
        module_path = "nvim-treesitter-refactor.highlight_definitions",
        enable = false,
        disable = {},
        is_supported = queries.has_locals,
        clear_on_cursor_move = true,
      },
      highlight_current_scope = {
        module_path = "nvim-treesitter-refactor.highlight_current_scope",
        enable = false,
        disable = {},
        is_supported = queries.has_locals,
      },
      smart_rename = {
        module_path = "nvim-treesitter-refactor.smart_rename",
        enable = false,
        disable = {},
        is_supported = queries.has_locals,
        keymaps = {
          smart_rename = "grr",
        },
      },
      navigation = {
        module_path = "nvim-treesitter-refactor.navigation",
        enable = false,
        disable = {},
        is_supported = queries.has_locals,
        keymaps = {
          goto_definition = "gnd",
          list_definitions = "gnD",
          list_definitions_toc = "gO",
          goto_next_usage = "<a-*>",
          goto_previous_usage = "<a-#>",
        },
      },
    },
  }
end

return M
