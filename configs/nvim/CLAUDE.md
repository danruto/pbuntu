# Neovim / Treesitter

- Uses **neovim-nightly-overlay** with **post-rewrite nvim-treesitter** from pkgs-unstable
- **DO NOT** use `require("nvim-treesitter.configs").setup()` — this module was removed in the nvim-treesitter rewrite. The modern API uses `vim.treesitter.start(buf)` via FileType autocmds (see `coding.lua`)
- Treesitter queries live at `${nvim-treesitter}/runtime/queries/`, not at the plugin root
- RTP prepend for treesitter must happen in `initLua` BEFORE `lazy.setup()` — `plugin/` files run too late
- Parsers come from `allGrammars` symlinked to `~/.config/nvim/parser/`
