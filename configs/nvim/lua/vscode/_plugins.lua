-- git clone https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/opt/packer.nvim
local execute = vim.api.nvim_command
local fn = vim.fn

require('dantoki._global')
if global.is_windows then
    local install_path = "C:\\Users\\danny\\AppData\\Local\\nvim-data" ..
                         "/site/pack/packer/opt/packer.nvim"
else
    local install_path = fn.stdpath("data") .. "/site/pack/packer/opt/packer.nvim"
end

if fn.empty(fn.glob(install_path)) > 0 then
    execute("!git clone https://github.com/wbthomason/packer.nvim " ..
                install_path)
    execute("packadd packer.nvim")
end

vim.cmd([[ packadd packer.nvim ]])

vim.cmd("autocmd BufWritePost _plugins.lua PackerCompile") -- Auto compile when there are changes in _plugins.lua

local ok, packer = pcall(require, "packer")

if ok then
    local use = packer.use
    packer.init()

    local os_name = vim.loop.os_uname().sysname
    local is_windows = os_name == "Windows" or os_name == "Windows_NT"

    local plugins = function()
        -- This, plugin manager
        use({"wbthomason/packer.nvim", opt = true})

        -- TODO: TBD
        use({
            "chentau/marks.nvim",
            opt = true,
            config = function() require("marks").setup() end
        })

    end

    packer.startup(plugins)
end
