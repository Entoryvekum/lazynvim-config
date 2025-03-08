-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.listchars = { space = "•", tab = "<->" }

if vim.g.neovide then
	vim.g.neovide_cursor_animation_length = 0.07
	vim.g.neovide_cursor_trail_size = 0.3
	vim.o.guifont = "FiraCode Nerd Font:h13"
end
