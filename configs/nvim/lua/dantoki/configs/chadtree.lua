if not pcall(require, "chadtree") then
	return
end

-- local opts = {noremap = true, silent = true}
-- nnoremap {'<Space>e', '<CMD>CHADopen<CR>', opts}

vim.keymap.set("n", "<Space>e", "<CMD>CHADopen<CR>", { silent = true })

local chadtree_settings = {
	theme = {
		-- icon_glyph_set = "devicons"
		text_colour_set = "nord",
	},
}

vim.api.nvim_set_var("chadtree_settings", chadtree_settings)
