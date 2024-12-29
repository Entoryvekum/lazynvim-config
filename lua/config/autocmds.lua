-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
<<<<<<< HEAD
=======

vim.api.nvim_create_autocmd(
    {
        "BufNewFile",
        "BufRead",
    },
    {
        pattern = "*.typ",
        callback = function()
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_option(buf, "filetype", "typst")
        end
    }
)
>>>>>>> 80d7e6a (remove vscode settings, move from typst.vim to tinymist, optimize snippet)
