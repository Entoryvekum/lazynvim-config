-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
    local keys = require("lazy.core.handler").handlers.keys
    ---@cast keys LazyKeysHandler
    -- do not create the keymap if a lazy keys handler exists
    if not keys.active[keys.parse({ lhs, mode = mode }).id] then
        opts = opts or {}
        opts.silent = opts.silent ~= false
        if opts.remap and not vim.g.vscode then
            opts.remap = nil
        end
        vim.keymap.set(mode, lhs, rhs, opts)
    end
end

map(
    { "i", "n" },
    "<Tab>",
    function()
        if require("luasnip").expandable() then
            return '<Plug>luasnip-expand-snippet'
        else
            return "<Tab>"
        end
    end, {
        expr = true,
        silent = true,
    }
)
map(
    { "i", "n","s" },
    "<C-F10>",
    function()
        require("luasnip").jump(1)
    end, {
        silent = true,
    }
)
map(
    { "i", "n", "s" },
    "<M-C-F10>",
    function()
        require("luasnip").jump(-1)
    end, {
        silent = true,
    }
)
map(
    { "i", "n", "s" },
    "<C-E>",
    function()
        if require("luasnip").choice_active() then
            require("luasnip").change_choice(1)
        else
            return "<C-E>"
        end
    end, {
        silent = true,
    }
)
map(
    {"n"},
    "<leader>typ", "<cmd>TypstPreview<cr>",
    {desc = "Preview Typst document"}
)
map(
    {"n"},
    "<leader>pp", "<cmd>PasteImg<cr>",
    {desc = "Paste imgage in the clipboard"}
)