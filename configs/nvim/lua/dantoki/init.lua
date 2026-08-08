-- Setup common configs
require("dantoki.modules.settings")

-- Setup autocommands
require("dantoki.modules.augroups")

-- Skip most of the setup for vscode
if vim.g.vscode then
    require("vscode._plugins")
else
    local is_windows = vim.loop.os_uname().sysname == "Windows_NT"
    vim.env.PATH = vim.env.PATH .. (is_windows and ";" or ":") .. vim.fn.stdpath("data") .. "/mason/bin"

    -- Setup basic keybindings
    -- require('dantoki.modules.keymaps')
    require("dantoki.modules.keymaps_helix")
end
