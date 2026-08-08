local SYSTEM_PROMPT = [[
You are an agent - please keep going until the user’s query is completely resolved, before ending your turn and yielding back to the user.

Your thinking should be thorough and so it's fine if it's very long. However, avoid unnecessary repetition and verbosity. You should be concise, but thorough.

You MUST iterate and keep going until the problem is solved.

I want you to fully solve this autonomously before coming back to me.

Only terminate your turn when you are sure that the problem is solved and all items have been checked off. Go through the problem step by step, and make sure to verify that your changes are correct. NEVER end your turn without having truly and completely solved the problem, and when you say you are going to make a tool call, make sure you ACTUALLY make the tool call, instead of ending your turn.

Always tell the user what you are going to do before making a tool call with a single concise sentence. This will help them understand what you are doing and why.

If the user request is "resume" or "continue" or "try again", check the previous conversation history to see what the next incomplete step in the todo list is. Continue from that step, and do not hand back control to the user until the entire todo list is complete and all items are checked off. Inform the user that you are continuing from the last incomplete step, and what that step is.

Take your time and think through every step - remember to check your solution rigorously and watch out for boundary cases, especially with the changes you made. Your solution must be perfect. If not, continue working on it. At the end, you must test your code rigorously using the tools provided, and do it many times, to catch all edge cases. If it is not robust, iterate more and make it perfect. Failing to test your code sufficiently rigorously is the NUMBER ONE failure mode on these types of tasks; make sure you handle all edge cases, and run existing tests if they are provided.

You MUST plan extensively before each function call, and reflect extensively on the outcomes of the previous function calls. DO NOT do this entire process by making function calls only, as this can impair your ability to solve the problem and think insightfully.

# Workflow

1. Understand the problem deeply. Carefully read the issue and think critically about what is required.
2. Investigate the codebase. Explore relevant files, search for key functions, and gather context.
3. Develop a clear, step-by-step plan. Break down the fix into manageable, incremental steps. Display those steps in a simple todo list using standard markdown format. Make sure you wrap the todo list in triple backticks so that it is formatted correctly.
4. Implement the fix incrementally. Make small, testable code changes.
5. Debug as needed. Use debugging techniques to isolate and resolve issues.
6. Test frequently. Run tests after each change to verify correctness.
7. Iterate until the root cause is fixed and all tests pass.
8. Reflect and validate comprehensively. After tests pass, think about the original intent, write additional tests to ensure correctness, and remember there are hidden tests that must also pass before the solution is truly complete.

Refer to the detailed sections below for more information on each step.

## 1. Deeply Understand the Problem
Carefully read the issue and think hard about a plan to solve it before coding.

## 2. Codebase Investigation
- Explore relevant files and directories.
- Search for key functions, classes, or variables related to the issue.
- Read and understand relevant code snippets.
- Identify the root cause of the problem.
- Validate and update your understanding continuously as you gather more context.

## 3. Fetch Provided URLs
- If the user provides a URL, use the `functions.fetch_webpage` tool to retrieve the content of the provided URL.
- After fetching, review the content returned by the fetch tool.
- If you find any additional URLs or links that are relevant, use the `fetch_webpage` tool again to retrieve those links.
- Recursively gather all relevant information by fetching additional links until you have all the information you need.

## 4. Develop a Detailed Plan 
- Outline a specific, simple, and verifiable sequence of steps to fix the problem.
- Create a todo list in markdown format to track your progress.
- Each time you complete a step, check it off using `[x]` syntax.
- Each time you check off a step, display the updated todo list to the user.
- Make sure that you ACTUALLY continue on to the next step after checkin off a step instead of ending your turn and asking the user what they want to do next.

## 5. Making Code Changes
- Before editing, always read the relevant file contents or section to ensure complete context.
- Always read 2000 lines of code at a time to ensure you have enough context.
- If a patch is not applied correctly, attempt to reapply it.
- Make small, testable, incremental changes that logically follow from your investigation and plan.

## 6. Debugging
- Make code changes only if you have high confidence they can solve the problem
- When debugging, try to determine the root cause rather than addressing symptoms
- Debug for as long as needed to identify the root cause and identify a fix
- Use the #problems tool to check for any problems in the code
- Use print statements, logs, or temporary code to inspect program state, including descriptive statements or error messages to understand what's happening
- To test hypotheses, you can also add test statements or functions
- Revisit your assumptions if unexpected behavior occurs.

# Fetch Webpage
Use the `fetch_webpage` tool when the user provides a URL. Follow these steps exactly.

1. Use the `fetch_webpage` tool to retrieve the content of the provided URL.
2. After fetching, review the content returned by the fetch tool.
3. If you find any additional URLs or links that are relevant, use the `fetch_webpage` tool again to retrieve those links.
4. Go back to step 2 and repeat until you have all the information you need.

IMPORTANT: Recursively fetching links is crucial. You are not allowed skip this step, as it ensures you have all the necessary context to complete the task.

# How to create a Todo List
Use the following format to create a todo list:
```markdown
- [ ] Step 1: Description of the first step
- [ ] Step 2: Description of the second step
- [ ] Step 3: Description of the third step
```

Do not ever use HTML tags or any other formatting for the todo list, as it will not be rendered correctly. Always use the markdown format shown above.

# Creating Files
Each time you are going to create a file, use a single concise sentence inform the user of what you are creating and why.

# Reading Files
- Read 2000 lines of code at a time to ensure that you have enough context.
- Each time you read a file, use a single concise sentence to inform the user of what you are reading and why.
]]

return {
	{
		"Exafunction/codeium.nvim",
		enabled = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		event = "LspAttach",
		cmd = "Codeium",
		build = ":Codeium Auth",
		opts = {},
	},
	{
		"monkoose/neocodeium",
		enabled = false,
		event = "VeryLazy",
		cmd = "NeoCodeium",
		build = ":NeoCodeium auth",
		config = function()
			local neocodeium = require("neocodeium")
			neocodeium.setup()
			vim.keymap.set("i", "<C-a>", function()
				require("neocodeium").accept()
			end)
			vim.keymap.set("i", "<A-e>", function()
				require("neocodeium").cycle_or_complete()
			end)
			vim.keymap.set("i", "<A-r>", function()
				require("neocodeium").cycle_or_complete(-1)
			end)
		end,
	},
	{
		"zbirenbaum/copilot.lua",
		enabled = false,
		cmd = "Copilot",
		event = "InsertEnter",
		opts = {
			suggestion = { enabled = false },
			panel = { enabled = false },
		},
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			vim.diagnostic.config({
				virtual_text = {
					enabled = true,
					prefix = function(diagnostic)
						if diagnostic.severity == vim.diagnostic.severity.ERROR then
							return "🭰× "
						elseif diagnostic.severity == vim.diagnostic.severity.WARN then
							return "🭰▲ "
						else
							return "🭰• "
						end
					end,
					suffix = "🭵",
				},
				underline = true,
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ×",
						[vim.diagnostic.severity.WARN] = " ▲",
						[vim.diagnostic.severity.HINT] = " •",
						[vim.diagnostic.severity.INFO] = " •",
					},
				},
			})

			vim.filetype.add({
				extension = {
					env = "env",
				},
				filename = {
					[".env"] = "env",
				},
				pattern = {
					["%.env%.[%w_.-]+"] = "env",
				},
			})

			-- Not required with lazy-lsp preferred servers
			local servers = {
				-- "basedpyright",
				"bashls",
				"biome",
				"dartls",
				"dockerls",
				"fish_lsp",
				"gh_actions_ls",
				"golangci_lint_ls",
				-- "gopls",
				"graphql",
				"html",
				"jsonls",
				"lua_ls",
				-- "nil_ls",
				-- "ruff",
				-- "rust_analyzer",
				-- "roslyn_ls", -- Use version from roslyn.nvim instead
				"tailwindcss",
				-- "ts_ls", -- Use the version from typescript-tools instead
				"ty",
				-- "zls",
			}
			vim.lsp.enable(servers)

			vim.lsp.config.lua_ls = {
				settings = {
					Lua = {
						workspace = {
							ignoreSubmodules = true,
							library = { vim.env.VIMRUNTIME },
						},
					},
				},
			}

			vim.lsp.config.nil_ls = {
				settings = {
					["nil"] = {
						nix = {
							autoArchive = true,
						},
					},
				},
			}
		end,
	},
	{
		"dundalek/lazy-lsp.nvim",
		event = "InsertEnter",
		dependencies = {
			"neovim/nvim-lspconfig",
		},
		opts = {
			use_vim_lsp_config = true,
			excluded_servers = {
				"sqls",
				"denols",
				"flow",
				"nixd",
				"tsserver",
				"rust_analyzer",
				"bazelrc-lsp",
				"ruff_lsp",
				"bufls",
				"typst_lsp",
				"omnisharp",
				"csharp_ls",
			},
			preferred_servers = {
				python = { "basedpyright", "ruff" },
				-- rust = { "rust_analyzer" },
				rust = {},
				-- nix = { "nil" },
				javascript = { "tsserver" },
				javascriptreact = {},
				["javascript.tsx"] = {},
				typescript = { "biome", "eslint" },
				typescriptreact = { "biome", "eslint" },
				["typescript.tsx"] = {},
				-- typescript = { "typescript-tools" },
				-- ["typescript.tsx"] = { "typescript-tools" },
				-- typescriptreact = { "typescript-tools" },
				go = { "gopls" },
				yaml = { "yamlls" },
				zig = { "zls" },
			},
			prefer_local = true,
		},
	},
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		opts = {
			completion = {
				cmp = { enabled = false },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		keys = {
			{
				"<leader>cF",
				function()
					require("conform").format({ async = true, lsp_fallback = true, formatters = { "injected" } })
				end,
				mode = { "n", "v" },
				desc = "Format Injected Langs",
			},
		},
		opts = function()
			local js_formatters = { "biome-check", "prettierd", "prettier", "eslint_d", stop_after_first = true }
			return {
				formatters_by_ft = {
					lua = { "stylua" },
					json = { "fixjson" },
					python = { "isort", "black" },
					nix = { "nixpkgs_fmt" },
					javascript = js_formatters,
					typescript = js_formatters,
					javascriptreact = js_formatters,
					typescriptreact = js_formatters,
				},
				-- Set up format-on-save
				format_on_save = { timeout_ms = 500, lsp_fallback = true },
				formatters = {
					stylua = {},
				},
			}
		end,
	},
	{
		"pmizio/typescript-tools.nvim",
		-- event = "LspAttach",
		ft = { "typescript", "typescriptreact", "typescript.tsx" },
		dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
		opts = {
			-- CodeLens
			-- WARNING: Experimental feature also in VSCode, because it might hit performance of server.
			-- possible values: ("off"|"all"|"implementations_only"|"references_only")
			code_lens = "all",
		},
	},
	{
		"simrat39/rust-tools.nvim",
		enabled = false,
		ft = "rust",
		dependencies = { "neovim/nvim-lspconfig" },
		opts = function()
			-- TODO: Change from mason to lazy-lsp / nix to pull info
			local ok, mason_registry = pcall(require, "mason-registry")
			local adapter ---@type any
			if ok then
				-- rust tools configuration for debugging support
				local codelldb = mason_registry.get_package("codelldb")
				local extension_path = codelldb:get_install_path() .. "/extension/"
				local codelldb_path = extension_path .. "adapter/codelldb"
				local liblldb_path = ""
				if vim.loop.os_uname().sysname:find("Windows") then
					liblldb_path = extension_path .. "lldb\\bin\\liblldb.dll"
				elseif vim.fn.has("mac") == 1 then
					liblldb_path = extension_path .. "lldb/lib/liblldb.dylib"
				else
					liblldb_path = extension_path .. "lldb/lib/liblldb.so"
				end
				adapter = require("rust-tools.dap").get_codelldb_adapter(codelldb_path, liblldb_path)
			end
			return {
				dap = {
					adapter = adapter,
				},
				tools = {
					on_initialized = function()
						vim.cmd([[
                          augroup RustLSP
                            autocmd CursorHold                      *.rs silent! lua vim.lsp.buf.document_highlight()
                            autocmd CursorMoved,InsertEnter         *.rs silent! lua vim.lsp.buf.clear_references()
                            autocmd BufEnter,CursorHold,InsertLeave *.rs silent! lua vim.lsp.codelens.refresh()
                          augroup END
                        ]])
					end,
				},
			}
		end,
		config = function() end,
	},
	{
		"mrcjkb/rustaceanvim",
		dependencies = { "neovim/nvim-lspconfig" },
		version = "^6", -- Recommended
		lazy = false,
		ft = { "rust" },
	},
	{
		"seblyng/roslyn.nvim",
		---@module 'roslyn.config'
		---@type RoslynNvimConfig
		ft = { "cs" },
		opts = {
			-- your configuration comes here; leave empty for default settings
		},
	},
	{
		"olexsmir/gopher.nvim",
		ft = "go",
		build = function()
			vim.cmd.GoInstallDeps()
		end,
		opts = {},
	},
	{
		"saghen/blink.cmp",
		-- name = "blink-cmp",
		lazy = false, -- lazy loading handled internally
		-- optional: provides snippets for the snippet source
		dependencies = {
			"rafamadriz/friendly-snippets",
			{ "L3MON4D3/LuaSnip", version = "v2.*" },
			"Kaiser-Yang/blink-cmp-avante",
		},

		-- use a release tag to download pre-built binaries
		version = "*",

		-- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
		-- build = "cargo build --release",
		--
		keys = {
			{ "<Leader>a", vim.lsp.buf.code_action, desc = "Code actions" },
			{ "<Leader>rn", vim.lsp.buf.rename, desc = "Rename" },
			{ "K", vim.lsp.buf.hover, desc = "Hover" },
			{
				"<Leader>F",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				desc = "Format document",
			},
			{ "[d", vim.diagnostic.goto_prev, desc = "Go to prev diagnostic" },
			{ "]d", vim.diagnostic.goto_next, desc = "Go to next diagnostic" },
			{ "<Leader>?", vim.diagnostic.open_float, desc = "Line Diagnostics" },
		},

		opts = {
			appearance = {
				nerd_font_variant = "mono",
			},

			-- experimental auto-brackets support
			-- accept = { auto_brackets = { enabled = true } }
			signature = { enabled = true },

			keymap = {
				preset = "enter",
				["<Tab>"] = { "select_and_accept", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },
				-- ['<CR>'] = { 'select_and_accept' },
			},

			fuzzy = {
				prebuilt_binaries = {
					download = false,
				},
				implementation = "prefer_rust_with_warning",
			},

			completion = {
				ghost_text = {
					enabled = true,
				},
				documentation = {
					auto_show = true,
				},
				menu = {
					-- auto_show = function(ctx)
					-- 	return ctx.mode ~= "default"
					-- end,
					-- auto_show = false,
				},
			},

			snippets = {
				preset = "luasnip",
			},

			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},

			cmdline = {
				enabled = false,
			},
		},
		opts_extend = { "sources.default" },
	},
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false, -- Never set this value to "*"! Never!
		enabled = false,
		opts = {
			providers = {
				ollama = {
					endpoint = "http://127.0.0.1:11434", -- Note that there is no /v1 at the end.
					model = "gemma3:4b",
				},
				gemini = {
					-- GEMINI_API_KEY,
					model = "gemini-2.0-flash",
					-- model = "gemini-2.5-flash-preview-04-17",
					-- model = "gemini-2.5-pro-preview-03-25"
				},
			},
			provider = "gemini",
			system_prompt = SYSTEM_PROMPT,
		},
		dependencies = {
			"Kaiser-Yang/blink-cmp-avante",
			"nvim-treesitter/nvim-treesitter",
			"stevearc/dressing.nvim",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			-- {
			-- 	-- support for image pasting
			-- 	"HakonHarnes/img-clip.nvim",
			-- 	event = "VeryLazy",
			-- 	opts = {
			-- 		-- recommended settings
			-- 		default = {
			-- 			embed_image_as_base64 = false,
			-- 			prompt_for_file_name = false,
			-- 			drag_and_drop = {
			-- 				insert_mode = true,
			-- 			},
			-- 			-- required for Windows users
			-- 			use_absolute_path = true,
			-- 		},
			-- 	},
			-- },
			"MeanderingProgrammer/render-markdown.nvim",
		},
	},
	{
		"olimorris/codecompanion.nvim",
		enabled = false,
		cmd = "CodeCompanionActions",
		opts = {
			strategies = {
				chat = {
					adapter = "gemini",
				},
				inline = {
					adapter = "gemini",
				},
				cmd = {
					adapter = "gemini",
				},
			},
			adapters = {
				ollama = function()
					return require("codecompanion.adapters").extend("ollama", {
						schema = {
							model = {
								-- default = preferred_model_picker({
								-- 	"qwen2.5-coder:14b",
								-- 	"qwen2.5-coder:7b",
								-- 	"qwen2.5-coder:3b",
								-- 	"qwen2.5-coder:1.5b",
								-- 	"qwen2.5-coder:0.5b",
								-- }),
								default = "gemma3:4b",
							},
						},
					})
				end,
				gemini = function()
					return require("codecompanion.adapters").extend("gemini", {
						env = {
							api_key = "cmd:tail ~/keys/gemini",
						},
					})
				end,
			},
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
	},
}
