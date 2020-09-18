# nvim-treesitter-refactor

Refactor modules for [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## Installation

You can install `nvim-treesitter` with your favorite package manager, or using the default `pack` feature of Neovim!

### Using a package manager

If you are using [vim-plug](https://github.com/junegunn/vim-plug), put this in your `init.vim` file:

```vim
Plug 'nvim-treesitter/nvim-treesitter-refactor'
```

## Refactor: highlight definitions

Highlights definition and usages of the current symbol under the cursor.

```lua
lua <<EOF
require'nvim-treesitter.configs'.setup {
  refactor = {
    highlight_definitions = { enable = true },
  },
}
EOF
```

## Refactor: highlight current scope

Highlights the block from the current scope where the cursor is.

```lua
lua <<EOF
require'nvim-treesitter.configs'.setup {
  refactor = {
    highlight_current_scope = { enable = true },
  },
}
EOF
```

## Refactor: smart rename

Renames the symbol under the cursor within the current scope (and current file).

```lua
lua <<EOF
require'nvim-treesitter.configs'.setup {
  refactor = {
    smart_rename = {
      enable = true,
      keymaps = {
        smart_rename = "grr",
      },
    },
  },
}
EOF
```

## Refactor: navigation

Provides "go to definition" for the symbol under the cursor,
and lists the definitions from the current file. If you use
`goto_definition_lsp_fallback` instead of `goto_definition` in the config below
`vim.lsp.buf.definition` is used if nvim-treesitter can not resolve the variable.
`goto_next_usage`/`goto_previous_usage` go to the next usage of the identifier under the cursor.


```lua
lua <<EOF
require'nvim-treesitter.configs'.setup {
  refactor = {
    navigation = {
      enable = true,
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
EOF
```
