return {
	"windwp/nvim-ts-autotag",
	"editorconfig/editorconfig-vim",
	"alvan/vim-closetag",
	"AndrewRadev/tagalong.vim",
	{
		"nvim-treesitter/nvim-treesitter",
		version = false,
		dependencies = {
			{
				"nvim-treesitter/nvim-treesitter-context",
				opts = { mode = "cursor", max_lines = 3 },
			},
			"nvim-treesitter/nvim-treesitter-textobjects",
			"RRethy/nvim-treesitter-endwise",
		},
		build = ":TSUpdate",
		lazy = false,
		cmd = {
			"TSInstall",
			"TSUpdate",
			"TSContext",
		},
		init = function(plugin)
			vim.opt.runtimepath:prepend(plugin.dir .. "/runtime")
		end,
		config = function()
			vim.treesitter.language.register("c_sharp", "cs")

			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"bash", "c", "cs", "cpp", "css", "dockerfile", "fish",
					"gitignore", "gleam", "go", "graphql", "html", "http", "hurl",
					"javascript", "json", "json5", "just", "lua", "markdown",
					"nix", "python", "regex", "rust", "scss", "sql", "svelte", "toml",
					"typescript", "typescriptreact", "javascriptreact", "tsx",
					"vim", "yaml", "zig"
				},
				callback = function(args)
					pcall(vim.treesitter.start, args.buf)
				end,
			})
		end,
	},
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		---@type Flash.Config
		opts = {},
		-- stylua: ignore
		keys = {
			{ "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
			{ "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
			{ "r", mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
			{ "R", mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
			--- { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
		},
	},
	{
		"JoosepAlviste/nvim-ts-context-commentstring",
		opts = {
			enable_autocmd = false,
		},
	},
	{
		"nvim-mini/mini.nvim",
		version = false,
		config = function()
			require("mini.ai").setup()
			-- require("mini.animate").setup()
			require("mini.bracketed").setup()
			require("mini.comment").setup({
				options = {
					custom_commentstring = function()
						return require("ts_context_commentstring").calculate_commentstring() or vim.bo.commentstring
					end,
				},
			})
			require("mini.cursorword").setup()
			require("mini.doc").setup()
			-- require("mini.hues").setup({
			-- 	background = "#0a0e14",
			-- 	foreground = "#73d0ff",
			-- 	saturation = "high",
			-- })
			-- require("mini.files").setup()
			require("mini.icons").setup()
			-- require("mini.indentscope").setup()
			require("mini.pairs").setup()
			require("mini.notify").setup()
			-- require("mini.sessions").setup({
			-- 	autoread = true,
			-- })
			require("mini.splitjoin").setup()
			require("mini.surround").setup({
				mappings = {
					add = "sa", -- Add surrounding in Normal and Visual modes
					delete = "sd", -- Delete surrounding
					find = "sf", -- Find surrounding (to the right)
					find_left = "sF", -- Find surrounding (to the left)
					highlight = "sh", -- Highlight surrounding
					replace = "sr", -- Replace surrounding
					update_n_lines = "sn", -- Update `n_lines`
				},
			})
			require("mini.statusline").setup()
			require("mini.trailspace").setup()
		end,
		specs = {
			{ "nvim-tree/nvim-web-devicons", enabled = false, optional = true },
		},
		init = function()
			package.preload["nvim-web-devicons"] = function()
				require("mini.icons").mock_nvim_web_devicons()
				return package.loaded["nvim-web-devicons"]
			end
		end,
	},
}
