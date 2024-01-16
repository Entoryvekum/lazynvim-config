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
    -- mason-lspconfig
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
                "typst-lsp",
            }
        }
    },
    -- luasnips setting
    {
        "L3MON4D3/LuaSnip",
        lazy = false,
        opts = {
            history = true,
            delete_check_events = "TextChanged,TextChangedI",
            enable_autosnippets = true,
            store_selection_keys = "<tab>",
            ext_opts = {
                [require("luasnip.util.types").choiceNode] = {
                    active = {
                        virt_text = { { "choiceNode", "Comment" } },
                    },
                },
            },
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
        'kaarmu/typst.vim',
        ft = 'typst',
    },
    {
        'chomosuke/typst-preview.nvim',
        ft= 'typst',
        version= '0.1.*',
        build = function() require 'typst-preview'.update() end,
    },
}

local vscodeConf={
    -- load color scheme
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "default",
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
    -- mason-lspconfig
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
                "typst-lsp",
            }
        }
    },
    -- luasnips setting
    {
        "L3MON4D3/LuaSnip",
        enabled = false
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
        'kaarmu/typst.vim',
        ft = 'typst',
    },
}

if vim.g.vscode then
    return vscodeConf
else
    return mainConf
end