local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local extras = require("luasnip.extras")
local l = extras.lambda
local rep = extras.rep
local p = extras.partial
local m = extras.match
local n = extras.nonempty
local dl = extras.dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local conds = require("luasnip.extras.expand_conditions")
local postfix = require("luasnip.extras.postfix").postfix
local types = require("luasnip.util.types")
local parse = require("luasnip.util.parser").parse_snippet
local ms = ls.multi_snippet
local key = require("luasnip.nodes.key_indexer").new_key

local snippets, autosnippets = {}, {}

local function mathZone()
	if vim.treesitter.get_node():type() == "math" then
		return true
	else
		return false
	end
end

local function plainText()
	if vim.treesitter.get_node():type() ~= "math" then
		return true
	else
		return false
	end
end

local function snip(val)
	table.insert(snippets, val)
end

local function asnip(val)
	table.insert(autosnippets, val)
end

local function switchSnip(arr, opts)
	for j = 1, #arr do
		opts.trig = arr[j]
		if j == #arr then
			snip(s(opts, { t(arr[1]) }))
		else
			snip(s(opts, { t(arr[j + 1]) }))
		end
	end
end

local function transferSnip(arr, opts)
	for k1, v1 in ipairs(arr) do
		for k2, v2 in ipairs(arr) do
			if k1 ~= k2 then
				opts.trig = v2[1] .. v1[2]
				asnip(s(opts, { t(v1[1]) }))
			end
		end
	end
end

local function linkSnip(arr, opts)
	local prev
	for k, v in ipairs(arr) do
		if prev == nil then
			prev = v
		else
			local addSnip = v.auto and asnip or snip
			v.trig = prev .. v[1]
			for optName, optVal in ipairs(opts) do
				if v[optName] == nil then
					v[optName] = optVal
				end
			end
			addSnip(s(v, { t(v[2]) }))
		end
	end
end

local function simpleSnip(alpha, defaultType, opts)
	if defaultType == nil or (defaultType ~= "a" and defaultType ~= "n") then
		defaultType = "n"
	end

	local isauto = function(x)
		if defaultType == "n" then
			return x == "a"
		else
			return x ~= "n"
		end
	end

	local addSnip
	for k, v in ipairs(alpha) do
		if isauto(v[3].auto) then
			addSnip = asnip
		else
			addSnip = snip
		end
		local curOpts = v[3]
		for optName, optVal in ipairs(opts) do
			if curOpts[optName] == nil then
				curOpts[optName] = optVal
			end
		end
		curOpts.trig = v[1]
		if type(v[2]) == "table" then
			addSnip(s(curOpts, { t(v[2][1]) }))
			switchSnip(v[2])
		else
			addSnip(s(curOpts, { t(v[2]) }))
		end
	end
end

local mathOptShow = { hidden = true, wordTrig = false, condition = mathZone }
local mathOptHide = { hidden = false, wordTrig = false, condition = mathZone }

----------------------------------测试--------------------------------
local function tests()
	local test1 = s("test:text", { t("hello world!") })
	snip(test1)

	local test2 =
		s("test:insert", { i(2, ">>>insert 1<<<"), t(" "), sn(1, { i(1, ">>>insert 2<<<") }), i(3, ">>>insert 3<<<") })
	snip(test2)

	local function recursiveprint(x, n, m) --n: 最大层数
		if m == nil then
			m = 1
		end
		if type(x) == "string" then
			return '"' .. x .. '"'
		elseif type(x) == "table" then
			local ans = "{"
			local flag = false
			for k, v in pairs(x) do
				if flag then
					if m == n then
						ans = ans .. ", " .. tostring(k) .. ":" .. tostring(v)
					else
						ans = ans .. ", " .. tostring(k) .. ":" .. recursiveprint(v, n, m + 1)
					end
				else
					flag = true
					if m == n then
						ans = ans .. tostring(k) .. ":" .. tostring(v)
					else
						ans = ans .. tostring(k) .. ":" .. recursiveprint(v, n, m + 1)
					end
				end
			end
			return ans .. "}"
		elseif type(x) == "number" or type(x) == "boolean" then
			return tostring(x)
		else
			return "<" .. tostring(x) .. ">"
		end
	end

	local test3 = s("test:function", {
		t("<1: "),
		i(1),
		t(">"),
		f(function(arg, parent, userarg)
			return arg[1][1] .. arg[2][1]
		end, { 1, 2 }, {}),
		t("<2: "),
		i(2),
		t(">"),
	})
	snip(test3)

	local test4data = {
		t("<"),
		i(1),
		t(">"),
		f(function(arg, parent, userarg)
			return arg[1][1]
		end, { 1 }, {}),
	}
	local test4 =
		s("test:print", { test4data[1], test4data[2], test4data[3], test4data[4], t(recursiveprint(test4data)) })
	snip(test4)

	local test5 = s("test:printparent1", {
		f(function(arg, parent, userarg)
			return recursiveprint(parent, 3)
		end, {}, {}),
	})
	snip(test5)

	local test6 = s("test:printparent2", {
		sn(1, {
			f(function(arg, parent, userarg)
				return recursiveprint(parent, 3)
			end, {}, {}),
		}),
	})
	snip(test6)

	local test7 = s("test:argi", {
		i(1),
		t(": "),
		f(function(arg, parent, userarg)
			return recursiveprint(arg)
		end, { 1 }, {}),
	})
	snip(test7)

	local test8 = s("test:argsn", {
		sn(1, { i(1), t(","), i(2) }),
		t(": "),
		f(function(arg, parent, userarg)
			return recursiveprint(arg)
		end, { 1 }, {}),
	})
	snip(test8)

	local test9 = s("test:ts", {
		f(function()
			return tostring(vim.treesitter.get_node():type())
		end, {}, {}),
	})
	snip(test9)
end
tests()

--------------------------------环境--------------------------------
--数学环境
local function MathEnvironment()
	asnip(s({ trig = ";;", wordTrig = false, condition = plainText }, { t("$"), i(1), t(" $") }))
	snip(s({ trig = "template" }, {
		t('#import("@local/'),
		i(1),
		t(":0."),
		i(2, "1"),
		t('.0"):*'),
	}))
end
MathEnvironment()

--------------------------------符号--------------------------------

--普通符号
local function Symbols()
	local alpha = {
		{ "oo;", "∞" },
		{ "qed;", "∎" },
		{ "rf;", "∀" },
		{ "cy;", "∃" },
		{ "∃n", "∄" },
		{ "alef;", "א" },
		{ "ks;", "∅" },
		{ "lap;", "∆" },
		{ "nab;", "∇" },
		{ "par;", "∂" },
		{ "|m", "mid(|)" },
	}
	simpleSnip(alpha, "a", mathOptHide)
end
Symbols()

--积分
local function Integrals()
	local alpha = {
		{ "int;", "∫" },
		{ "∫i", "∬" },
		{ "∬i", "∭" },
		{ "∮i", "∯" },
		{ "∯i", "∰" },
		{ "∫o", "∮" },
		{ "∬o", "∯" },
		{ "∭o", "∰" },
	}
	simpleSnip(alpha, "a", mathOptHide)
end
Integrals()

--希腊字母
local function GreekLetters()
	local alpha = {
		{ "a", { "α", "Α" } },
		{ "b", { "β", "Β" } },
		{ "g", { "γ", "Γ" } },
		{ "d", { "δ", "Δ" } },
		{ "ep", { "ε", "ϵ", "Ε" } },
		{ "z", { "ζ", "Ζ" } },
		{ "et", { "η", "Η" } },
		{ "th", { "θ", "ϑ", "Θ" } },
		{ "i", { "ι", "Ι" } },
		{ "k", { "κ", "Κ" } },
		{ "l", { "λ", "Λ" } },
		{ "m", { "μ", "Μ" } },
		{ "n", { "ν", "Ν" } },
		{ "oc", { "ο", "Ο" } },
		{ "x", { "ξ", "Ξ" } },
		{ "pi", { "π", "Π" } },
		{ "r", { "ρ", "Ρ" } },
		{ "s", { "σ", "Σ" } },
		{ "ta", { "τ", "Τ" } },
		{ "u", { "υ", "Υ" } },
		{ "ph", { "φ", "ϕ", "Φ" } },
		{ "c", { "χ", "Χ" } },
		{ "ps", { "ψ", "Ψ" } },
		{ "og", { "ω", "Ω" } },
	}

	for k, v in ipairs(alpha) do
		asnip(s({ trig = "'" .. v[1], condition = mathZone }, { t(v[2][1]) }))
		asnip(s({
			trig = "'" .. string.upper(string.sub(v[1], 1, 1)) .. string.sub(v[1], 2),
			condition = mathZone,
		}, { t(v[2][#v[2]]) }))
		switchSnip(v[2])
	end
end
GreekLetters()

--大型运算符
local function BigOperators()
	local alpha1 =
		{ "sum", "prod", "coprod", "plusc", "timec", "bcdot", "bcup", "bcupf", "bcupj", "bcap", "bcapf", "band", "bor" }
	local alpha2 = { "∑", "∏", "∐", "⨁", "⨂", "⨀", "⋃", "⨆", "⨄", "⋂", "⨅", "⋀", "⋁" }
	for j = 1, #alpha1 do
		snip(
			s({ trig = alpha1[j], condition = mathZone }, { t(alpha2[j] .. " _( "), i(1), t(" ) ^( "), i(2), t(" ) ") })
		)
		snip(s({
			trig = alpha1[j] .. " (%w|[^!-`][^%s]*) (%w|[^!-`][^%s]*) (%w|[^!-`][^%s]*)",
			hidden = true,
			trigEngine = "pattern",
			condition = mathZone,
		}, {
			t(alpha2[j] .. " _( "),
			f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}, {}),
			t(" = "),
			f(function(arg, snip, userArg)
				return snip.captures[2]
			end, {}, {}),
			t(" ) ^( "),
			f(function(arg, snip, userArg)
				return snip.captures[3]
			end, {}, {}),
			t(" ) "),
		}))
		asnip(s({ trig = alpha1[j] .. ";(.)", hidden = true, trigEngine = "pattern", condition = mathZone }, {
			t(alpha2[j] .. " _( "),
			f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}, {}),
			i(1),
			t(" ) "),
		}))
	end
end
BigOperators()

--运算符
local function Operators()
	local arr = {
		{ "aa;", "+" },
		{ "tt;", "×" },
		{ "×l", "⋉" },
		{ "×r", "⋊" },
		{ "+-", "±" },
		{ "-+", "∓" },
		{ "xx;", "∗" },
		{ "star;", "⋆" },
		{ "+o", "⊕" },
		{ "×o", "⊗" },
		{ "..", { "⋅", "•" } },
		{ "⋅.", "⋯" },
		{ "cir;", { "∘", "⚬" } },
		{ "and;", "∧" },
		{ "or;", "∨" },
		{ "cup;", { "∪", "⊔" } },
		{ "cap;", { "∩", "⨅" } },
		{ "ni;", "∖" },
	}
	local trans = {
		{ "⋯", "h" },
		{ "⋱", "d" },
		{ "⋰", "u" },
	}
	transferSnip(trans, mathOptHide)
	simpleSnip(arr, "a", mathOptShow)
end
Operators()

--关系符
local function Relations()
	local arr1 = {
		{ "ee;", "=" },
		{ "ne;", "≠" },
		{ "eee", "≡" },
		{ "≡n", "≢" },
		{ "≢n", "≡" },
		{ "eeee", "≣" },
		{ ".e", "≥" },
	}
	simpleSnip(arr1, "a", mathOptShow)
	local arr2 = {

		{ ".e", "≥" },
		{ ">n", "≯" },
		{ "≥n", "≱" },
		{ ">t", "⊳" },
		{ "⊳e", "⊵" },
		{ "⊳n", "⋫" },
		{ "⋫,", "⋪" },
		{ "⋫e", "⋭" },
		{ "⋭,", "⋬" },
		{ "⊵n", "⋭" },
	}
	switchSnip({ { "<", "," }, { ">", "." } }, mathOptHide)
	switchSnip({ { "≮", "," }, { "≯", "." } }, mathOptHide)
	switchSnip({ { "≤", "," }, { "≥", "." } }, mathOptHide)
	switchSnip({ { "≰", "," }, { "≱", "." } }, mathOptHide)
	switchSnip({ { "≰", "," }, { "≱", "." } }, mathOptHide)
	switchSnip({ { "≰", "," }, { "≱", "." } }, mathOptHide)
	switchSnip({ { "⊲", "," }, { "⊳", "." } }, mathOptHide)
	switchSnip({ { "⊴", "," }, { "⊵", "." } }, mathOptHide)
	switchSnip({ { "⊴", "," }, { "⊵", "." } }, mathOptHide)
	local arr3 = {
		{ ">c", "≻" },
		{ "≻,", "≺" },
		{ "≻e", "≽" },
		{ "≽,", "≼" },
		{ "≻n", "⊁" },
		{ "⊁,", "⊀" },
		{ "⊁n", "⋡" },
		{ "⋡,", "⋠" },
		{ "≽n", "⋡" },

		{ "<.", ">" },
		{ ",e", "≤" },
		{ "≤.", "≥" },
		{ "<n", "≮", "n" },
		{ "≮.", "≯" },
		{ "≤n", "≰", "n" },
		{ "≰.", "≱" },

		{ "<t", "⊲" },
		{ "⊲.", "⊳" },
		{ "⊲e", "⊴" },
		{ "⊴.", "⊵" },
		{ "⊲n", "⋪" },
		{ "⋪.", "⋫" },
		{ "⋪e", "⋬" },
		{ "⋬.", "⋭" },
		{ "⊴n", "⋬" },

		{ "<c", "≺" },
		{ "≺.", "≻" },
		{ "≺e", "≼" },
		{ "≼.", "≽" },
		{ "≺n", "⊀" },
		{ "⊀.", "⊁" },
		{ "⊀c", "⋠" },
		{ "⋠.", "⋡" },
		{ "≼n", "⋠" },

		{ "sim", "〜" },

		{ "prop", "∝" },

		{ "vgiu", "∣" },
		{ "∣n", "∤" },

		{ "in;", "∈" },
		{ "∈n", "∉" },
		{ "∉n", "∈" },
		{ "∋n", "∌" },
		{ "∌n", "∋" },
		{ "∈,", "∋" },
		{ "∉,", "∌" },
		{ "∋.", "∈" },
		{ "∌.", "∉" },

		{ "join", "⨝", "n" },
		{ "⨝,", "⟕" },
		{ "⨝.", "⟖" },
		{ "⟕r", "⟗" },
		{ "⟖l", "⟗" },

		{ "sub;", "⊂" },
		{ "⊂,", "⊃" },
		{ "⊂n", "⊄" },
		{ "⊄n", "⊂" },
		{ "⊄,", "⊅" },
		{ "⊂e", "⊆" },
		{ "⊆,", "⊇" },
		{ "⊆n", { "⊊", "⊈" } },
		{ "⊊n", "⊆" },
		{ "⊈n", "⊆" },
		{ "⊊,", "⊋" },
		{ "⊈,", "⊉" },
		{ "sup;", "⊃" },
		{ "⊃.", "⊂" },
		{ "⊃n", "⊅" },
		{ "⊅.", "⊄" },
		{ "⊃e", "⊇" },
		{ "⊇.", "⊆" },
		{ "⊇n", { "⊋", "⊉" } },
		{ "⊋n", "⊇" },
		{ "⊉n", "⊇" },
		{ "⊋.", "⊊" },
		{ "⊉.", "⊈" },

		{ ":=", "≔" },
		{ "=def", "≝" },
		{ "=?", "≟" },
		{ "se;", "⋍" },
		{ "⋍n", "≄" },
		{ "≄n", "⋍" },
		{ "see;", "≅" },
		{ "≅n", "≇" },
		{ "≇n", "≅" },
	}
	simpleSnip(alpha, "a", { hidden = true, wordTrig = false, condition = mathZone })
	switchSnip({})
end
Relations()

--箭头
local function Arrows()
	local alpha = {
		-- l r u d lr ud
		-- e: 双线箭头 s: 三/四线箭头
		-- b: 左侧竖线 t: 右侧竖线
		-- et: 双头 st:三头
		-- eg: 两重 sg: 三重
		-- w: 波浪
		-- c: 圆弧
		-- v: 半圆弧
		-- l: 长
		{ "→", "r", {} },
		{ "←", "l", {} },
		{ "↔", "lr", {} },
		{ "⇒", "r", { "e" } },
		{ "⇐", "l", { "e" } },
		{ "⇔", "lr", { "e" } },
		{ "↦", "r", { "b" } },
		{ "↤", "l", { "b" } },
		{ "↷", "r", { "v" } },
		{ "↶", "l", { "v" } },
	}

	asnip(s({ trig = "arr.", hidden = true }, { t("→") }, { condition = mathZone }))
	asnip(s({ trig = "arr,", hidden = true }, { t("←") }, { condition = mathZone }))
	asnip(s({ trig = "a..", hidden = true }, { t("⇒") }, { condition = mathZone }))
	asnip(s({ trig = "a,,", hidden = true }, { t("⇐") }, { condition = mathZone }))
	asnip(s({ trig = "a,.", hidden = true }, { t("⇔") }, { condition = mathZone }))
	snip(s({ trig = "map", hidden = false }, { t("↦") }, { condition = mathZone }))

	for j = 1, #alpha do
		for k = 1, #alpha do
			if j == k or #alpha[k][3] <= #alpha[j][3] or #alpha[k][3] - #alpha[j][3] > 1 then
				goto continue
			end

			if #alpha[k][3] - #alpha[j][3] == 1 and alpha[j][2] == alpha[k][2] then
				local miss = 0
				for k1, v1 in ipairs(alpha[k][3]) do
					local flag = true
					for k2, v2 in ipairs(alpha[j][3]) do
						if v1 == v2 then
							flag = false
							break
						end
					end
					if flag then
						if miss == 0 then
							miss = v1
						else
							goto continue
						end
					end
				end
				asnip(s({ trig = alpha[j][1] .. miss, hidden = true }, { t(alpha[k][1]) }, { condition = mathZone }))
			end

			::continue::
		end
	end
end
Arrows()

--------------------------------输入--------------------------------
--分数
local function Fraction()
	asnip(s({ trig = "//", hidden = true }, {
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t("( "), t(snip.env.SELECT_RAW), t(" ) / ( "), i(1), t(" ) ") })
			else
				return sn(nil, { t("//") })
			end
		end, {}, {}),
	}, { condition = mathZone }))
	snip(s({ trig = "/d", hidden = true }, { t("\\/  ") }, { condition = mathZone }))
end
Fraction()

--二项式系数
local function Binomial()
	snip(s({ trig = "bin", hidden = true }, { t("binom( "), i(1), t(" ) ") }, { condition = mathZone }))

	snip(s({ trig = "bin (%w+[^%s]*) ([^%s]*)%s*", regTrig = true, hidden = true }, {
		t("binom ( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" , "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" ) "),
	}, { condition = mathZone }))
end
Binomial()

--括号
local function Brackets()
	asnip(s({ trig = "jj", wordTrig = false, hidden = true }, {
		t("( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	snip(s({ trig = "kk", wordTrig = false, hidden = true }, {
		t("[ "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ] "),
	}, { condition = mathZone }))
	snip(s({ trig = "ll", wordTrig = false, hidden = true }, {
		t("{ "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" } "),
	}, { condition = mathZone }))
	snip(s({ trig = "bb", hidden = true }, {
		t("⟨ "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ⟩ "),
	}, { condition = mathZone }))
	asnip(s({ trig = "kk;", hidden = true }, {
		t("⟦ "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ⟧ "),
	}, { condition = mathZone }))
	snip(s({ trig = "abs", hidden = true }, {
		t("| "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" | "),
	}, { condition = mathZone }))
	snip(s({ trig = "nrm", hidden = true }, {
		t("‖ "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ‖ "),
	}, { condition = mathZone }))
	snip(s({ trig = "floor", hidden = true }, {
		t("floor( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	snip(s({ trig = "ceil", hidden = true }, {
		t("ceil( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
end
Brackets()

--文字
local function Texts()
	asnip(s({ trig = "s.t.", hidden = true }, { t("stW") }, { condition = mathZone }))
	snip(s({ trig = "and", hidden = true }, { t("andW") }, { condition = mathZone }))
	snip(s({ trig = "ksw", hidden = true }, { t("space.en ") }, { condition = mathZone }))
	snip(s({ trig = "iff", hidden = true }, { t("iffW ") }, { condition = mathZone }))
	snip(s({ trig = "if", hidden = true }, { t("ifW") }, { condition = mathZone }))
	snip(s({ trig = "or", hidden = true }, { t("orW") }, { condition = mathZone }))
end
Texts()

--极限
local function Limits()
	snip(
		s(
			{ trig = "lim", hidden = true },
			{ t("lim _( "), i(1), i(2, " → "), i(3), t(" )") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "liminf", hidden = true },
			{ t("liminf _( "), i(1), i(2, " → "), i(3), t(" )") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "limsup", hidden = true },
			{ t("limsup _( "), i(1), i(2, " → "), i(3), t(" )") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "inf", hidden = true }, { t("inf _( "), i(1), t(" )") }, { condition = mathZone }))
	snip(s({ trig = "sup", hidden = true }, { t("sup _( "), i(1), t(" )") }, { condition = mathZone }))
end
Limits()

--根式
local function Root()
	snip(s({ trig = "sqrt", wordTrig = false, hidden = true }, {
		t("sqrt( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = "sqrt;([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
			{ t("sqrt( "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), i(1), t(" ) ") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "root", wordTrig = false, hidden = true }, {
		t("root( "),
		i(2),
		t(" , "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(s({ trig = "root;([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
		t("root( "),
		i(1),
		t(" , "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(2),
		t(" ) "),
	}, { condition = mathZone }))
end
Root()

--上下内容
local function UnderOverContent()
	local function addSnip(name, effect, key)
		if key == nil then
			key = ";"
		end
		snip(s({ trig = name, hidden = true, trigEngine = "pattern" }, {
			t(effect .. "( "),
			d(1, function(arg, snip, oldState, userArg)
				if #snip.env.SELECT_RAW > 0 then
					return sn(nil, { t(snip.env.SELECT_RAW) })
				else
					return sn(nil, { i(1) })
				end
			end, {}, {}),
			t(" , "),
			i(2),
			t(" ) "),
		}, { condition = mathZone }))
		asnip(s({ trig = name .. key .. "(%w)", hidden = true, trigEngine = "pattern" }, {
			t(effect .. "( "),
			f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}),
			i(1),
			t(" , "),
			i(2),
			t(" ) "),
		}, { condition = mathZone }))
	end
	addSnip("ubc", "overbrace", ";")
	addSnip("dbc", "underbrace", ";")
	addSnip("ukc", "overbracket", ";")
	addSnip("dkc", "underbracket", ";")
end
UnderOverContent()

--序列
local function Sequence()
	snip(s({ trig = "seq (%w[^%s]*)%s+(%w[^%s]*)%s+(%w[^%s]*)", hidden = true, trigEngine = "pattern" }, {
		f(function(arg, snip, userArg)
			return snip.captures[1] .. "_( " .. snip.captures[2] .. " ) , " .. snip.captures[1] .. "_( "
		end, {}),
		f(function(arg, snip, userArg)
			if tonumber(snip.captures[2], 10) == nil then
				return snip.captures[2] .. "+1"
			end
			return tostring(snip.captures[2] + 1)
		end, {}),
		t(" ) , ⋯ "),
		f(function(arg, snip, userArg)
			if snip.captures[3] == "inf" then
				return ""
			end
			return ", " .. snip.captures[1] .. "_( " .. snip.captures[3] .. " ) "
		end, {}),
	}, { condition = mathZone }))
	snip(s({ trig = "seq (%w[^%s]*)%s+(%w[^%s]*)%s+(%w[^%s]*)%s+([^%s]+)", hidden = true, trigEngine = "pattern" }, {
		f(function(arg, snip, userArg)
			return snip.captures[1]
				.. "_( "
				.. snip.captures[2]
				.. " ) "
				.. snip.captures[4]
				.. " "
				.. snip.captures[1]
				.. "_( "
		end, {}),
		f(function(arg, snip, userArg)
			if tonumber(snip.captures[2], 10) == nil then
				return snip.captures[2] .. "+1"
			end
			return tostring(snip.captures[2] + 1)
		end, {}),
		f(function(arg, snip, userArg)
			return " ) " .. snip.captures[4] .. " ⋯ "
		end, {}),
		f(function(arg, snip, userArg)
			if snip.captures[3] == "inf" then
				return ""
			end
			return snip.captures[4] .. " " .. snip.captures[1] .. "_( " .. snip.captures[3] .. " ) "
		end, {}),
	}, { condition = mathZone }))
end
Sequence()

--求导
local function Differential()
	asnip(s({ trig = "[dp];(%w[^/%s]*)/", hidden = true, trigEngine = "pattern" }, {
		t("( "),
		f(function(arg, snip, userArg)
			if snip.captures[2] == "d" then
				return "d "
			else
				return "∂ "
			end
		end, {}),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" )/( "),
		f(function(arg, snip, userArg)
			if snip.captures[2] == "d" then
				return "d "
			else
				return "∂ "
			end
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = ";d", hidden = true },
			{ t("( "), t("d "), i(1), t(" )/( "), t("d "), i(2), t(" )") },
			{ condition = mathZone }
		)
	)
	asnip(
		s(
			{ trig = "/p", hidden = true },
			{ t("( "), t("∂ "), i(1), t(" )/( "), t("∂ "), i(2), t(" )") },
			{ condition = mathZone }
		)
	)
	asnip(s({ trig = ".p", hidden = true }, { t("∂ _( "), i(1), t(" )") }, { condition = mathZone }))
	switchSnip({ "∂ _( ", "∂ /( ∂ " })
end
Differential()

--------------------------------装饰--------------------------------
--字体
local function Fonts()
	asnip(s({ trig = ";b(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
		t('mbb("'),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t('") '),
	}, { condition = mathZone }))
	asnip(s({ trig = ";f(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
		t("frak( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";c(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
		t("cal( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";s(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
		t("scr( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";v(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("ubold( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";i(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("italic( "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}, { condition = mathZone }))
end
Fonts()

--上下标
local function Attach()
	snip(s({ trig = "uu", wordTrig = false, hidden = true }, {
		t("^( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = "uu([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
			{ t("^( "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), t(" ) ") },
			{
				condition = mathZone,
			}
		)
	)
	asnip(
		s(
			{ trig = "uu ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
			{ t("^( "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), i(1), t(" ) ") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "dd", wordTrig = false, hidden = true }, {
		t("_( "),
		d(1, function(arg, snip, oldState, userArg)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = "dd([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
			{ t("_( "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), t(" ) ") },
			{
				condition = mathZone,
			}
		)
	)
	asnip(
		s(
			{ trig = "dd ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
			{ t("_( "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), i(1), t(" ) ") },
			{ condition = mathZone }
		)
	)
end
Attach()

--Hat
local function Hats()
	-- 默认输入分号+内容
	-- vv 粗体向量
	-- u. 右箭头
	-- u, 左箭头
	-- uw 上波浪线
	-- uj uk 向上向下折线
	-- ul dl 上下横线
	-- ub db 上下大括号
	-- ud 上点
	-- uc 上空心圆圈
	local function addSnip(name, effect, key)
		if key == nil then
			key = ";"
		end
		snip(s({ trig = name, hidden = true, trigEngine = "pattern" }, {
			t(effect .. "( "),
			d(1, function(arg, snip, oldState, userArg)
				if #snip.env.SELECT_RAW > 0 then
					return sn(nil, { t(snip.env.SELECT_RAW) })
				else
					return sn(nil, { i(1) })
				end
			end, {}, {}),
			t(" ) "),
		}, { condition = mathZone }))
		asnip(s({ trig = name .. key .. "(%w)", hidden = true, trigEngine = "pattern" }, {
			t(effect .. "( "),
			f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}),
			i(1),
			t(" ) "),
		}, { condition = mathZone }))
	end
	local alpha = {
		{ "u%.", "arrow", "%." },
		{ "u,", "arrow.l", "," },
		{ "uw", "tilde" },
		{ "uj", "hat" },
		{ "uk", "caron" },
		{ "ud", "dot" },
		{ "ul", "overline" },
		{ "dl", "underline" },
		{ "vv", "ubold" },
		{ "uc", "circle" },
	}
	for k, v in ipairs(alpha) do
		addSnip(v[1], v[2], v[3])
	end
end
Hats()

--------------------------------表--------------------------------
local function Cases()
	--Cases
	local generateCases
	generateCases = function()
		return sn(nil, {
			t({ "", "" }),
			i(1),
			t("    #h(2em)&    "),
			i(2),
			d(3, function(arg, snip, oldState, ...)
				local str = arg[1][1]
				local len = string.len(str)
				if string.sub(str, len, len) == "," then
					return sn(nil, { d(1, generateCases, {}) })
				else
					return sn(nil, {})
				end
			end, { 2 }),
		})
	end
	snip(s({ trig = "case", hidden = true }, {
		t({ "cases(" }),
		d(1, function(arg, snip, oldState, usaerArg)
			return sn(nil, { d(1, generateCases, {}) })
		end),
		t({ "", ")" }),
	}, { condition = mathZone }))
end
Cases()

local function Matrix1()
	--SimpleMatrix
	local generateElm
	generateElm = function(arg0, snip0, oldState0, firstElm)
		return sn(nil, {
			t(({ "    ", ",  " })[firstElm]),
			i(1),
			d(2, function(arg, snip, oldState, userArg)
				local str = arg[1][1]
				local len = string.len(str)
				if len == 0 or string.sub(str, len - 2, len) == ";//" then
					return sn(nil, {})
				elseif string.sub(str, len, len) == ";" then
					return sn(nil, { t({ "", "" }), d(1, generateElm, {}, { user_args = { 1 } }) })
				else
					return sn(nil, { d(1, generateElm, {}, { user_args = { 2 } }) })
				end
			end, { 1 }),
		})
	end
	snip(s({ trig = "mat", hidden = true }, {
		t({ "mat(", "" }),
		d(1, function(arg, snip, oldState, userArg)
			return sn(nil, { d(1, generateElm, {}, { user_args = { 1 } }) })
		end),
		t({ "", ")" }),
	}, { condition = mathZone }))
end
Matrix1()

return snippets, autosnippets
