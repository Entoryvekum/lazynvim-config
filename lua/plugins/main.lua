local mainConf={
    -- color scheme
    {
        "EdenEast/nightfox.nvim",
    },
    -- load color scheme
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "nightfox",
        },
    },
    -- show the notice for longer time
    {
        "rcarriga/nvim-notify",
        opts = {
            timeout = 5000
        }
    },
    -- treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = {
                "lua",
                "markdown",
                "markdown_inline",
                "python",
                "javascript",
                "typescript",
                "julia",
                "scala",
                "cpp",
                "rust"
            },
        },
    },
    -- mason
    {
        "williamboman/mason.nvim",
        lazy=false,
        opts = {
            ensure_installed = {
                "stylua",
                "shfmt",
                "flake8",
                "clangd",
                "clang-format",
                "julia-lsp",
                "rust-analyzer",
                "prosemd-lsp",
                "tinymist",
            }
        }
    },
    -- lispconfig
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                tinymist = {
                    single_file_support = true,
                    root_dir = function()
                        return vim.fn.getcwd()
                    end,
                    settings = {}
                },
            },
        },
    },
    -- luasnips setting
    {
        "L3MON4D3/LuaSnip",
        lazy = false,
        opts = {
            history = true,
            delete_check_events = "TextChanged,TextChangedI",
            update_events = "TextChanged,TextChangedI",
            enable_autosnippets = true,
            store_selection_keys = "<tab>",
        },
        init = function()
            require("luasnip.loaders.from_lua").load({ paths = "./lua/config/luasnip/" })
        end
    },
    -- disable friendly-snippets
    { "rafamadriz/friendly-snippets", enabled = false },
    -- mini.pairs
    {
        "echasnovski/mini.pairs",
        opts={
            mappings = {
                ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\].' },
                ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\].' },
                ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\].' },
            
                [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
                [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
                ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },
            
                ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^\\].', register = { cr = false } },
                ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '%s.', register = { cr = false } },
                ['`'] = { action = 'closeopen', pair = '``', neigh_pattern = '[^\\].', register = { cr = false } },
              },
        }
    },
    {
        'chomosuke/typst-preview.nvim',
        ft = 'typst',
        version= '1.*',
        build = function() require 'typst-preview'.update() end,
    },
    {
        'dfendr/clipboard-image.nvim',
        opts={
            typst={
                img_dir = {"%:p:h", "img", "clipboard"},
                img_dir_txt = {"img", "clipboard"},
                img_name = function() return os.date('%Y-%m-%d-%H-%M-%S') end,
                affix = "#image(\"%s\")"
            },
            markdown={
                img_dir = {"%:p:h", "img", "clipboard"},
                img_dir_txt = {"img", "clipboard"},
                img_name = function() return os.date('%Y-%m-%d-%H-%M-%S') end,
                affix = "![](%s)"
            },
        }
    }
}

return mainConf