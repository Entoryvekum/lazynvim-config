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
    { "i", "n", "s" },
    "<Plug>ls-expand",
    function()
        require("luasnip").expand()
    end,{
        silent = true,
    }
)
map(
    { "i", "n", "s" },
    "<Plug>ls-next-choice",
    function()
        require("luasnip").change_choice(1)
    end,{
        silent = true,
    }
)

-- map(
--     { "i", "n" },
--     "<Tab>",
--     function()
--         if require("luasnip").expandable() then
--             return "<Plug>ls-expand"
--         else
--             return "<Tab>"
--         end
--     end, {
--         silent = true,
--         expr = true,
--     }
-- )
map(
    { "i", "n", "s" },
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
            return "<Plug>ls-next-choice"
        else
            return "<C-E>"
        end
    end, {
        silent = true,
        expr = true,
    }
)
map(
    {"n"},
    "<leader>tt", "<cmd>TypstPreview<cr>",
    {desc = "Preview Typst document"}
)
map(
    {"n"},
    "<leader>pp", "<cmd>PasteImg<cr>",
    {desc = "Paste imgage in the clipboard"}
)