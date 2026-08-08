-- Keymaps {{{
-- ----------------------------------------------------------------------------

-- Map the leader
vim.g.mapleader = ","

-- VSCode style saving
vim.keymap.set("n", "<C-s>", "<CMD>w!<CR>")
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<ESC><CMD>w!<CR>")
vim.keymap.set({ "n", "i", "v" }, "<C-q>", "<ESC><CMD>q!<CR>")
vim.keymap.set("i", "<C-e>", "<C-o>A")

-- move vertically by visual line on wrapped lines
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- better indenting experience
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- toggle hlsearch
vim.keymap.set("n", "<Leader><Space>", "<CMD>nohlsearch<CR>")

-- copy to system clipboard
vim.keymap.set("v", "<C-c>", '"+y')
-- better yank behaviour
vim.keymap.set("n", "Y", "y$")
-- paste from clipboard
-- "+p

-- resize buffer easier
vim.keymap.set("n", "<M-l>", "<CMD>vertical resize +2<CR>")
vim.keymap.set("n", "<M-h>", "<CMD>vertical resize -2<CR>")
vim.keymap.set("n", "<M-k>", "<CMD>resize +2<CR>")
vim.keymap.set("n", "<M-j>", "<CMD>resize -2<CR>")

-- Resize fullscreen windows
vim.keymap.set("n", "<Leader>sh", "<C-w>|")
vim.keymap.set("n", "<Leader>sv", "<C-w>_")

-- Handle splits
vim.keymap.set("n", "<Leader>sl", "<CMD>vs<CR>")
vim.keymap.set("n", "<Leader>sj", "<CMD>split<CR>")

-- better movement between windows
vim.keymap.set("n", "<C-h>", "<C-w><C-h>")
vim.keymap.set("n", "<C-j>", "<C-w><C-j>")
vim.keymap.set("n", "<C-k>", "<C-w><C-k>")
vim.keymap.set("n", "<C-l>", "<C-w><C-l>")

-- terminal navigations
vim.keymap.set({ "t", "i" }, "<C-h>", "<C-\\><C-N><C-w>h")
vim.keymap.set({ "t", "i" }, "<C-j>", "<C-\\><C-N><C-w>j")
vim.keymap.set({ "t", "i" }, "<C-k>", "<C-\\><C-N><C-w>k")
vim.keymap.set({ "t", "i" }, "<C-l>", "<C-\\><C-N><C-w>l")
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- remove annoying exmode
vim.keymap.set("n", "Q", "<Nop>")
vim.keymap.set("n", "q:", "<Nop>")

-- Remap annoying mistakes
vim.cmd([[
  cnoreabbrev <expr> W ((getcmdtype() is# ':' && getcmdline() is# 'W')?('w'):('W'))
  cnoreabbrev <expr> Q ((getcmdtype() is# ':' && getcmdline() is# 'Q')?('q'):('Q'))
  cnoreabbrev <expr> WQ ((getcmdtype() is# ':' && getcmdline() is# 'WQ')?('wq'):('WQ'))
  cnoreabbrev <expr> Wq ((getcmdtype() is# ':' && getcmdline() is# 'Wq')?('wq'):('Wq'))
  cnoreabbrev <expr> Qa ((getcmdtype() is# ':' && getcmdline() is# 'Qa')?('qa'):('Qa'))
  cnoreabbrev <expr> Qall ((getcmdtype() is# ':' && getcmdline() is# 'Qall')?('qall'):('Qall'))
]])

-- Center on jumps
vim.keymap.set("n", "n", "nzz")
vim.keymap.set("n", "N", "Nzz")
vim.keymap.set("n", "*", "*zz")
vim.keymap.set("n", "#", "#zz")
vim.keymap.set("n", "g*", "g*zz")
vim.keymap.set("n", "g#", "g#zz")

-- Multi replace
-- nnoremap {'<C-n>', '*Ncgn', {silent = true}}

-- Reload lua vim? Not sure this is legit anymore
vim.keymap.set("n", "<Leader><CR>", "<CMD>so ~/.config/nvim/init.lua<CR>")

-- Toggle float term TODO: Move this to the float term lua
vim.keymap.set("n", "<Leader>z", '<CMD>lua require("FTerm").toggle()<CR>', { silent = true })
vim.keymap.set("t", "<Leader>z", '<C-\\><C-n><CMD>lua require("FTerm").toggle()<CR>', { silent = true })

-- Gitgutter key maps (TODO: move to own file too)
vim.keymap.set("n", "<Leader>gs", function()
	require("neogit").open()
end)

-- Set shell to bash when on mac since fish is too slow
vim.cmd([[
if has('mac')
    set shell=/bin/bash\ -l
end
]])

-- Use <Tab> and <S-Tab> to navigate through popup menu
vim.cmd([[ inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>" ]])
vim.cmd([[ inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>" ]])

-- }}}
