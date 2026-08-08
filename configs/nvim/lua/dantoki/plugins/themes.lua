return {
	{
		"projekt0n/github-nvim-theme",
		config = function() end,
	},
	{
		"Shatur/neovim-ayu",
		config = function() end,
	},
	-- {
	-- 	"nocksock/bloop.nvim",
	-- 	dependencies = { "rktjmp/lush.nvim" },
	-- 	config = function() end,
	-- },
	-- {
	-- 	"NLKNguyen/papercolor-theme",
	-- 	config = function()
	-- 		-- vim.cmd([[ colorscheme papercolor ]])
	-- 	end,
	-- },
	{ "pappasam/papercolor-theme-slim" },
	{
		"yuttie/snowy-vim",
		config = function()
			-- vim.cmd([[ colorscheme snowy ]])
		end,
	},
	{
		"Yazeed1s/oh-lucy.nvim",
		config = function()
			-- vim.cmd([[ colorscheme oh-lucy ]])
		end,
	},
	-- {
	--     "arturgoms/moonbow.nvim",
	--     config = function()
	--         -- vim.cmd([[ colorscheme moonbow ]])
	--     end,
	-- },
	{
		"igorgue/danger",
		-- lazy = false,
		-- priority = 1000,
		opts = {
			style = "dark",
			-- alacritty = true,
		},
	},
	-- {
	-- 	"uloco/bluloco.nvim",
	-- 	dependencies = { "rktjmp/lush.nvim" },
	-- 	opts = {
	-- 		style = "light",
	-- 	},
	-- },
	-- {
	-- 	"themercorp/themer.lua",
	-- 	opts = {
	-- 		enable_installer = true,
	-- 	},
	-- },
	-- {
	--     "dharmx/nvim-colo",
	--     commit = "a401cad1762b458332d563484c05eb149bfa7a48",
	--     cmd = { "Colo", "ColoTele" },
	--     opts = {
	--         manual = true,
	--     },
	--     requires = {
	--         "nvim-lua/plenary.nvim",
	--     },
	-- },
	{
		"folke/tokyonight.nvim",
		priority = 1000,
		-- lazy = false,
		-- config = function()
		-- 	vim.cmd([[ colorscheme tokyonight-night ]])
		-- end,
		opts = {
			style = "night",
			styles = {
				comments = { italic = false },
				keywords = { italic = false },
			},
		},
	},
	-- { "Alexis12119/nightly.nvim" },
	{
		"CWood-sdf/pineapple",
		-- dependencies = require("dantoki.pineapple"),
		enabled = false,
		opts = {
			installedRegistry = "dantoki.pineapple",
			colorschemeFile = "after/plugin/theme.lua",
		},
		cmd = "Pineapple",
	},
	{
		"catppuccin/nvim",
		-- lazy = false,
		name = "catppuccin",
		priority = 1000,
		config = function()
			-- vim.cmd.colorscheme("catppuccin")
		end,
		opts = {
			flavour = "macchiato",
			no_italic = true,
		},
	},
	{
		"fynnfluegge/monet.nvim",
		opts = {
			dark_mode = false,
			transparent_background = false,
		},
	},
	{
		"diegoulloao/neofusion.nvim",
		config = true,
		opts = {
			italic = {
				strings = false,
				emphasis = false,
				comments = false,
				operators = false,
				folds = false,
			},
		},
	},
	{
		"nyoom-engineering/oxocarbon.nvim",
		config = function()
			vim.opt.background = "dark"
			-- vim.cmd.colorscheme("oxocarbon")
		end,
	},
	{
		"Skardyy/makurai-nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("makurai_dark")
		end,
	},
	-- {
	-- 	"comfysage/cuddlefish.nvim",
	-- 	config = function()
	-- 		require("cuddlefish").setup({
	-- 			theme = {
	-- 				accent = "pink",
	-- 			},
	-- 			editor = {
	-- 				transparent_background = false,
	-- 			},
	-- 			style = {
	-- 				tabline = { "reverse" },
	-- 				search = { "reverse" },
	-- 				incsearch = { "reverse" },
	-- 				-- types = { "normal" },
	-- 				-- keyword = { "normal" },
	-- 				-- comment = { "normal" },
	-- 			},
	-- 			overrides = function(colors)
	-- 				return {}
	-- 			end,
	-- 		})
	-- 	end,
	-- },
}
