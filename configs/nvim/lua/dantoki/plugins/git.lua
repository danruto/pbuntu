return {
	{
		"lewis6991/gitsigns.nvim",
		ft = "gitcommit",
		event = "User ActuallyEditing",
		dependencies = "nvim-lua/plenary.nvim",
		opts = {
			add = { hl = "DiffAdd", text = "│", numhl = "GitSignsAddNr" },
			change = { hl = "DiffChange", text = "│", numhl = "GitSignsChangeNr" },
			delete = { hl = "DiffDelete", text = "", numhl = "GitSignsDeleteNr" },
			topdelete = { hl = "DiffDelete", text = "‾", numhl = "GitSignsDeleteNr" },
			changedelete = { hl = "DiffChangeDelete", text = "~", numhl = "GitSignsChangeNr" },
		},
	},
	{
		"NeoGitOrg/neogit",
		keys = {
			{ "<Space>gs", "<cmd>Neogit<cr>", desc = "Neogit" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
		},
		opts = {
			integrations = { diffview = true },
			disable_commit_confirmation = true,
			mappings = { status = { [">"] = "Toggle" } },
		},
	},
}
