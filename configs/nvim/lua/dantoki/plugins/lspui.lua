return {
	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		enabled = false,
		event = "LspAttach",
		config = function()
			require("lsp_lines").setup()

			-- `virtual_text` is redundant due to lsp_lines.
			vim.diagnostic.config({ virtual_text = false })
		end,
	},
	{
		"lewis6991/hover.nvim",
		event = "BufReadPost",
		opts = {
			init = function()
				require("hover.providers.lsp")
				-- require('hover.providers.gh')
				-- require('hover.providers.gh_user')
				-- require('hover.providers.jira')
				-- require('hover.providers.man')
				-- require('hover.providers.dictionary')
			end,
		},
		keys = {
			{
				"fK",
				function()
					local ok, hover = pcall(require, "hover")
					if not ok then
						return
					end

					hover.hover()
				end,
				desc = "Hover via hover.nvim",
			},
			{
				"gK",
				function()
					local ok, hover = pcall(require, "hover")
					if not ok then
						return
					end

					hover.hover_select()
				end,
				desc = "Hover via hover.nvim (select)",
			},
		},
	},
	{
		-- Disabled since it is archived
		"lvimuser/lsp-inlayhints.nvim",
		enabled = false,
		event = "BufReadPost",
		dependencies = { "williamboman/mason-lspconfig.nvim" },
		opts = {},
		init = function()
			vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
			vim.api.nvim_create_autocmd("LspAttach", {
				group = "LspAttach_inlayhints",
				callback = function(args)
					if not (args.data and args.data.client_id) then
						return
					end

					local bufnr = args.buf
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					require("lsp-inlayhints").on_attach(client, bufnr)
				end,
			})
		end,
	},
	{
		"j-hui/fidget.nvim",
		enabled = false,
		event = "LspAttach",
		opts = {},
	},
	{
		"SmiteshP/nvim-navic",
		enabled = false,
		opts = { highlight = true, lsp = { auto_attach = true } },
	},
	{
		"utilyre/barbecue.nvim",
		version = "*",
		event = "LspAttach",
		enabled = false,
		dependencies = {
			"neovim/nvim-lspconfig",
			"SmiteshP/nvim-navic",
			"nvim-tree/nvim-web-devicons", -- optional dependency
		},
		opts = {
			attach_navic = false,
			-- create_autocmd = false,
			show_navic = true,
		},
	},
	{
		"Bekaboo/dropbar.nvim",
		event = "LspAttach",
		dependencies = {
			-- "nvim-telescope/telescope-fzf-native.nvim",
		},
		opts = {
			bar = {
				update_events = {
					win = { "CursorMoved", "WinResized" },
					-- BufModifiedSet was removed in nvim 0.13-nightly; keep the rest.
					buf = { "FileChangedShellPost", "TextChanged", "ModeChanged" },
					global = { "DirChanged", "VimResized" },
				},
			},
		},
	},
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		config = function()
			vim.diagnostic.config({ virtual_text = false })

			require("tiny-inline-diagnostic").setup()
		end,
	},
}
