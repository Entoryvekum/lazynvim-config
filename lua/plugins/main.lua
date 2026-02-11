local mainConf = {
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
			timeout = 7500,
		},
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
				"rust",
				"typst",
			},
			compilers = {
				"clang",
				"gcc",
				"zig",
			},
		},
	},
	-- mason
	{
		"mason-org/mason.nvim",
		lazy = false,
		opts = {
			ensure_installed = {
				"stylua", -- lua
				"shfmt", -- bash
				"flake8", -- python
				"clangd", -- cpp
				"julia-lsp", -- julia
				"rust-analyzer", -- rust
				"prosemd-lsp", -- markdown
				"tinymist", -- typst
			},
		},
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
					settings = {},
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
		build = "make install_jsregexp",
		init = function()
			require("luasnip.loaders.from_lua").load({ paths = "./lua/config/luasnip/" })
		end,
	},
	-- blink.cmp
	{
		"saghen/blink.cmp",
		lazy = false,
		opts = {
			snippets = { preset = "luasnip" },
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
			keymap = {
				preset = "none",
				["<CR>"] = { "accept", "fallback" },
				["<Tab>"] = {
					function(cmp)
						if require("luasnip").expandable() then
							cmp.hide()
							vim.schedule(function()
								require("luasnip").expand()
							end)
							return true
						end
						return cmp.select_next()
					end,
					"fallback",
				},
			},
			completion = {
				list = {
					selection = {
						preselect = false,
						auto_insert = false,
					},
				},
				ghost_text = { enabled = true },
			},
		},
	},
	-- disable friendly-snippets
	{ "rafamadriz/friendly-snippets", enabled = false },
	-- mini.pairs
	{
		"nvim-mini/mini.pairs",
		opts = {
			mappings = {
				["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]." },
				["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]." },
				["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]." },

				[")"] = { action = "close", pair = "()", neigh_pattern = "[^\\]." },
				["]"] = { action = "close", pair = "[]", neigh_pattern = "[^\\]." },
				["}"] = { action = "close", pair = "{}", neigh_pattern = "[^\\]." },

				['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^\\].", register = { cr = false } },
				["'"] = { action = "closeopen", pair = "''", neigh_pattern = "%s.", register = { cr = false } },
				["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].", register = { cr = false } },
			},
		},
	},
	-- typst preview
	{
		"chomosuke/typst-preview.nvim",
		ft = "typst",
		version = "1.*",
		build = function()
			require("typst-preview").update()
		end,
	},
	-- image insertion
	{
		"dfendr/clipboard-image.nvim",
		opts = {
			typst = {
				img_dir = { "%:p:h", "img", "clipboard" },
				img_dir_txt = { "img", "clipboard" },
				img_name = function()
					return os.date("%Y-%m-%d-%H-%M-%S")
				end,
				affix = '#image("%s")',
			},
			markdown = {
				img_dir = { "%:p:h", "img", "clipboard" },
				img_dir_txt = { "img", "clipboard" },
				img_name = function()
					return os.date("%Y-%m-%d-%H-%M-%S")
				end,
				affix = "![](%s)",
			},
		},
	},
	-- smear-cursor setting
	{
		"sphamba/smear-cursor.nvim",
		opts = {
			stiffness = 0.8,
			trailing_stiffness = 0.7,
			distance_stop_animating = 0.5,
		},
	},
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		vscode = true,
		opts = {},
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					local dict = require("utils.tiger").tigerDict
					require("flash").jump({
						search = {
							mode = function(str)
								local tiger_pattern = dict[str:lower()]
								local literal_pattern = vim.pesc(str)
								if tiger_pattern then
									return string.format([[\(%s\|%s\)]], literal_pattern, tiger_pattern)
								else
									return literal_pattern
								end
							end,
						},
					})
				end,
				desc = "Flash",
			},
			{
				"S",
				mode = { "n", "o", "x" },
				function()
					require("flash").treesitter()
				end,
				desc = "Flash Treesitter",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
			{
				"R",
				mode = { "o", "x" },
				function()
					require("flash").treesitter_search()
				end,
				desc = "Treesitter Search",
			},
			{
				"<c-s>",
				mode = { "c" },
				function()
					require("flash").toggle()
				end,
				desc = "Toggle Flash Search",
			},
			-- Simulate nvim-treesitter incremental selection
			{
				"<c-space>",
				mode = { "n", "o", "x" },
				function()
					require("flash").treesitter({
						actions = {
							["<c-space>"] = "next",
							["<BS>"] = "prev",
						},
					})
				end,
				desc = "Treesitter Incremental Selection",
			},
		},
	},
	{
		"yetone/avante.nvim",
		opts = {
			provider = "openrouter",
			providers = {
				openrouter = {
					__inherited_from = "openai",
					endpoint = "https://openrouter.ai/api/v1",
					api_key_name = "OPENROUTER_API_KEY",
					model = "stepfun/step-3.5-flash:free",
				},
			},
			selection = {
				enabled = true,
				hint_display = "delayed",
			},
			behaviour = {
				auto_set_keymaps = false,
			},
		},
	},
}

return mainConf
