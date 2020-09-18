lua << EOF
require "nvim-treesitter-refactor".init()
EOF

highlight default link TSDefinitionUsage Visual
highlight default link TSDefinition Search
highlight default link TSCurrentScope CursorLine
