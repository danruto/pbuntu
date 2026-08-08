return {
	{
		"nvim-tree/nvim-web-devicons",
		opts = {},
	},
	{
		"rcarriga/nvim-notify",
		enabled = false,
		config = function()
			vim.notify = require("notify")
		end,
	},
	{
		"stevearc/dressing.nvim",
		enabled = false,
		init = function()
			---@diagnostic disable-next-line: duplicate-set-field
			vim.ui.select = function(...)
				require("lazy").load({ plugins = { "dressing.nvim" } })
				return vim.ui.select(...)
			end
			---@diagnostic disable-next-line: duplicate-set-field
			vim.ui.input = function(...)
				require("lazy").load({ plugins = { "dressing.nvim" } })
				return vim.ui.input(...)
			end
		end,
	},
	{
		"jghauser/shade.nvim",
		enabled = false,
		opts = {
			overlay_opacity = 50,
			opacity_step = 1,
			keys = {
				brightness_up = "<C-Up>",
				brightness_down = "<C-Down>",
				toggle = "<Leader>ts",
			},
			exclude_filetypes = { "CHADTree", "neo-tree", "Mason" },
		},
	},
	{
		"tjdevries/express_line.nvim",
		enabled = false,
		lazy = false,
		priority = 800,
		config = function()
			require("dantoki.configs.expressline")
		end,
	},
	{
		"NvChad/nvim-colorizer.lua",
		event = "User ActuallyEditing",
		opts = {
			filetypes = { "*", "!lazy" },
			buftype = { "*", "!prompt", "!nofile" },
			user_default_options = {
				RGB = true, -- #RGB hex codes
				RRGGBB = true, -- #RRGGBB hex codes
				names = false, -- "Name" codes like Blue
				RRGGBBAA = true, -- #RRGGBBAA hex codes
				AARRGGBB = false, -- 0xAARRGGBB hex codes
				rgb_fn = true, -- CSS rgb() and rgba() functions
				hsl_fn = true, -- CSS hsl() and hsla() functions
				css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
				css_fn = true, -- Enable all CSS *functions*: rgb_fn, hsl_fn
				-- Available modes: foreground, background
				-- Available modes for `mode`: foreground, background,  virtualtext
				mode = "background", -- Set the display mode.
				virtualtext = "■",
			},
		},
	},
	{
		"Pocco81/true-zen.nvim",
		enabled = false,
		cmd = {
			"TZAtaraxis",
			"TZMinimalist",
			"TZFocus",
			"TZNarrow",
		},
		opts = {},
	},
	{
		"sindrets/winshift.nvim",
		enabled = false,
		opts = {},
	},
	{
		"folke/trouble.nvim",
		enabled = false,
		cmd = "Trouble",
		keys = {
			{
				"<Leader>n",
				function()
					local ok, t = pcall(require, "trouble")
					if not ok then
						return
					end
					t.next({ skip_groups = true, jump = true })
				end,
				desc = "Jump to next diagnostic",
			},
		},
		opts = {
			use_diagnostic_signs = true,
		},
	},
	-- {
	-- 	"nvim-pack/nvim-spectre",
	-- 	opts = {
	-- 		open_cmd = "noswapfile vnew",
	-- 	},
	-- },
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "Avante" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"echasnovski/mini.nvim",
			{
				"3rd/diagram.nvim",
				ft = { "markdown" },
				dependencies = {
					{ "3rd/image.nvim", rocks = false, opts = { backend = "kitty", processor = "magick_cli" } },
				},
				config = function(_, opts)
					require("diagram").setup(opts)
					vim.api.nvim_create_user_command("DiagramRender", function()
						local bufnr = vim.api.nvim_get_current_buf()
						local winnr = vim.api.nvim_get_current_win()
						local integration = require("diagram/integrations/markdown")
						local image_nvim = require("image")
						local diagrams = integration.query_buffer_diagrams(bufnr)
						for _, diagram in ipairs(diagrams) do
							local renderer = require("diagram/renderers/" .. diagram.renderer_id)
							local result = renderer.render(diagram.source, opts.renderer_options[diagram.renderer_id] or {})
							if result and result.file_path then
								local image = image_nvim.from_file(result.file_path, {
									buffer = bufnr,
									window = winnr,
									with_virtual_padding = true,
									inline = true,
									x = diagram.col,
									y = diagram.row,
									render_offset_top = 1,
								})
								if image then image:render() end
							end
						end
					end, {})
				end,
				opts = {
					events = {
						render_buffer = {},
						clear_buffer = { "BufLeave" },
					},
					renderer_options = {
						mermaid = {
							background = nil,
							theme = nil,
							scale = 1,
							cli_args = {},
						},
						plantuml = {
							charset = nil,
						},
						d2 = {
							theme_id = nil,
							dark_theme_id = nil,
							scale = nil,
							layout = nil,
							sketch = nil,
						},
						gnuplot = {
							size = nil,
							font = nil,
							theme = nil,
						},
					},
				},
			},
		},
		opts = {
			file_types = { "markdown", "Avante" },
		},
	},
	{
		"kndndrj/nvim-dbee",
		enabled = false,
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		-- build = function()
		-- 	-- Install tries to automatically detect the install method.
		-- 	-- if it fails, try calling it with one of these parameters:
		-- 	--    "curl", "wget", "bitsadmin", "go"
		-- 	require("dbee").install()
		-- end,
		config = function()
			require("dbee").setup(--[[optional config]])
		end,
	},
	{
		"MagicDuck/grug-far.nvim",
		opts = { headerMaxWidth = 80 },
		cmd = { "GrugFar", "GrugFarWithin" },
		keys = {
			{
				"<leader>sr",
				function()
					local grug = require("grug-far")
					local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
					grug.open({
						transient = true,
						prefills = {
							filesFilter = ext and ext ~= "" and "*." .. ext or nil,
						},
					})
				end,
				mode = { "n", "v" },
				desc = "Search and Replace",
			},
		},
	},
}
