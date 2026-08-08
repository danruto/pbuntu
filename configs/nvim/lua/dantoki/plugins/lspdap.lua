local enable_dap = true

return {
	{
		"mfussenegger/nvim-dap",
		enabled = enable_dap,
		keys = {
			{ ",db", "<CMD>DapToggleBreakpoint<CR>", desc = "Toggle dap breakpoint" },
			{ ",dc", "<CMD>DapContinue<CR>", desc = "Continue run" },
			{ ",do", "<CMD>DapStepOver<CR>", desc = "Step over" },
			{ ",de", "<CMD>DapTerminate<CR>", desc = "Terminate" },
			{ ",dfs", "<CMD>!firefox -start-debugger-server<CR>", desc = "Start firefox debug server" },
			{ ",dgs", "<CMD>lua require'dap-go'.debug_test()", desc = "Start dap go test" },
		},
		dependencies = {
			{
				"rcarriga/nvim-dap-ui",
				enabled = false,
				keys = {
					{
						",dt",
						function()
							local ok, dapui = pcall(require, "dapui")
							if not ok then
								return
							end

							dapui.toggle()
						end,
						desc = "Toggle DAP UI",
					},
				},
			},
			{ "miroshQa/debugmaster.nvim" },
			{ "leoluz/nvim-dap-go" },
			{ "nvim-neotest/nvim-nio" },
		},
		config = function()
			local dap = require("dap")
			local dapui_ok, dapui = pcall(require, "dapui")

			local function get_arguments()
				return coroutine.create(function(dap_run_co)
					local args = {}
					vim.ui.input({ prompt = "Args: " }, function(input)
						args = vim.split(input or "", " ")
						coroutine.resume(dap_run_co, args)
					end)
				end)
			end

			local dm = require("debugmaster")
			-- make sure you don't have any other keymaps that starts with "<leader>d" to avoid delay
			-- Alternative keybindings to "<leader>d" could be: "<leader>m", "<leader>;"
			vim.keymap.set({ "n", "v" }, ",dt", dm.mode.toggle, { nowait = true })
			-- If you want to disable debug mode in addition to leader+d using the Escape key:
			-- vim.keymap.set("n", "<Esc>", dm.mode.disable)
			-- This might be unwanted if you already use Esc for ":noh"
			vim.keymap.set("t", "<C-\\>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

			require("dap-go").setup({
				-- Additional dap configurations can be added.
				-- dap_configurations accepts a list of tables where each entry
				-- represents a dap configuration. For more details do:
				-- :help dap-configuration
				dap_configurations = {
					{
						type = "delve",
						name = "Debug",
						request = "launch",
						program = "${file}",
						args = get_arguments,
					},
					{
						type = "delve",
						name = "Debug test", -- configuration for debugging test files
						request = "launch",
						mode = "test",
						program = "${file}",
					},
					-- works with go.mod packages and sub packages
					{
						type = "delve",
						name = "Debug test (go.mod)",
						request = "launch",
						mode = "test",
						program = "./${relativeFileDirname}",
						args = get_arguments,
					},
				},
				-- delve configurations
				delve = {
					-- the path to the executable dlv which will be used for debugging.
					-- by default, this is the "dlv" executable on your PATH.
					-- path = "dlv",
					-- time to wait for delve to initialize the debug session.
					-- default to 20 seconds
					--initialize_timeout_sec = 20,
					-- a string that defines the port to start delve debugger.
					-- default to string "${port}" which instructs nvim-dap
					-- to start the process in a random available port
					port = "${port}",
					-- additional args to pass to dlv
					-- args = {},
					-- the build flags that are passed to delve.
					-- defaults to empty string, but can be used to provide flags
					-- such as "-tags=unit" to make sure the test suite is
					-- compiled during debugging, for example.
					-- passing build flags using args is ineffective, as those are
					-- ignored by delve in dap mode.
					-- build_flags = "-tags=util,integration,core",
					type = "server",
					host = "127.0.0.1",
				},
			})

			dap.adapters.codelldb = {
				type = "server",
				host = "127.0.0.1",
				port = 13000, -- 💀 Use the port printed out or specified with `--port`
			}

			dap.configurations.cpp = {
				{
					name = "Launch file",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
				},
			}

			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp

			-- dap.adapters.delve = {
			-- 	type = "server",
			-- 	host = "127.0.0.1",
			-- 	port = "8086",
			-- 	executable = {
			-- 		command = "dlv",
			-- 		args = { "dap", "-l", "127.0.0.1:8086", "--log" },
			-- 	},
			-- }

			-- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
			-- dap.configurations.go = {
			-- 	{
			-- 		type = "delve",
			-- 		name = "Debug",
			-- 		request = "launch",
			-- 		program = "${file}",
			-- 	},
			-- 	{
			-- 		type = "delve",
			-- 		name = "Debug test", -- configuration for debugging test files
			-- 		request = "launch",
			-- 		mode = "test",
			-- 		program = "${file}",
			-- 	},
			-- 	-- works with go.mod packages and sub packages
			-- 	{
			-- 		type = "delve",
			-- 		name = "Debug test (go.mod)",
			-- 		request = "launch",
			-- 		mode = "test",
			-- 		program = "./${relativeFileDirname}",
			-- 	},
			-- }

			dap.configurations.javascript = {
				{
					name = "Launch",
					type = "node2",
					request = "launch",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					console = "integratedTerminal",
				},
				{
					-- For this to work you need to make sure the node process is started with the `--inspect` flag.
					name = "Attach to process",
					type = "node2",
					request = "attach",
					processId = require("dap.utils").pick_process,
				},
			}
			dap.configurations.typescript = dap.configurations.javascript

			dap.configurations.typescriptreact = {
				{
					name = "Debug with Firefox",
					type = "firefox",
					request = "launch",
					url = "http://localhost:3000",
					webRoot = "${workspaceFolder}",
					firefoxExecutable = "/usr/bin/firefox",
					timeout = 30000,
				},
				{
					-- For this to work you need to make sure the node process is started with the `--inspect` flag.
					name = "Attach to process",
					type = "firefox",
					request = "attach",
					host = "127.0.0.1",
					timeout = 30000,
					processId = require("dap.utils").pick_process,
				},
			}

			-- DAP UI Setup (optional)
			if dapui_ok then
				dapui.setup()

				dap.listeners.after.event_initialized["dapui_config"] = function()
					dapui.open()
				end
				dap.listeners.before.event_terminated["dapui_config"] = function()
					dapui.close()
				end
				dap.listeners.before.event_exited["dapui_config"] = function()
					dapui.close()
				end
			end
		end,
	},
}
