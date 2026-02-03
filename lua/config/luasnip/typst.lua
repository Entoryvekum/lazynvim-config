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
	local cur = vim.treesitter.get_node()
	local root = cur:tree():root()
	local flag = false
	local arr = { content = true, string = true }
	while true do
		if cur:type() == "math" then
			flag = true
			break
		elseif arr[cur:type()] or cur == root then
			break
		else
			cur = cur:parent()
		end
	end
	return flag
end

local function plainText()
	return (not mathZone()) or vim.treesitter.get_node():tree():root():has_error()
end

local mathOptShow = { hidden = false, wordTrig = false, condition = mathZone }
local mathOptHide = { hidden = false, wordTrig = false, condition = mathZone }
local mathOptShowAuto = { hidden = false, wordTrig = false, condition = mathZone, auto = true }
local mathOptHideAuto = { hidden = false, wordTrig = false, condition = mathZone, auto = true }

local function snip(val)
	table.insert(snippets, val)
end

local function asnip(val)
	table.insert(autosnippets, val)
end

local function switchSnip(arr, opts)
	-- Example: { "θ", "ϑ", "Θ" }
	if opts == nil then
		opts = {}
	end
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
	-- Example:
	-- {
	--    { "⋯", "h" },
	-- 	  { "⋱", "d" },
	-- 	  { "⋰", "u" },
	-- }
	for k1, v1 in pairs(arr) do
		for k2, v2 in pairs(arr) do
			if k1 ~= k2 then
				opts.trig = v2[1] .. v1[2]
				asnip(s(opts, { t(v1[1]) }))
			end
		end
	end
end

local function orderSnip(relation, altClass, toggleList, opts)
	-- Example:
	-- relation={
	--     {"<",{","}},
	--     {">",{"."}},
	--     {"≮",{","}},
	--     {"≯",{"."}},
	--     {"≤",{",","e"}},
	--     {"≥",{".","e"}},
	--     {"≰",{",","e","n"}},
	--     {"≱",{".","e","n"}},
	-- }
	-- alt_class={{",","."}}
	-- toggle_list={"e","n"}
	opts = vim.deepcopy(opts)
	local addSnip = opts.auto and asnip or snip
	-- 预处理
	-- 将属性集转化为字典
	for _, node in pairs(relation) do
		local cnt = {}
		for _, attr in pairs(node[2]) do
			cnt[attr] = cnt[attr] and cnt[attr] + 1 or 1
		end
		node.symb = node[1]
		node.attr = cnt
		node.numAttr = #node[2]
	end
	-- 将toggleList处理为字典
	local toggleSet = {}
	for _, v in ipairs(toggleList or {}) do
		toggleSet[v] = true
	end
	-- 创建altClass索引
	local altClassIndex = {}
	for k, v in ipairs(altClass or {}) do
		for _, w in ipairs(v) do
			altClassIndex[w] = k
		end
	end
	-- 属性对称差(b-a)
	local function symDiff(a, b)
		local diff = {}
		local keys = {}
		for k in pairs(a) do
			keys[k] = true
		end
		for k in pairs(b) do
			keys[k] = true
		end
		local size = 0
		for k in pairs(keys) do
			local d = (b[k] or 0) - (a[k] or 0)
			if d ~= 0 then
				diff[k] = d
				size = size + math.abs(d)
			end
		end
		return diff, size
	end
	-- 增加属性
	for _, target in pairs(relation) do
		for _, source in pairs(relation) do
			if target.numAttr - source.numAttr ~= 1 then
				goto continue
			end
			for attr, count in pairs(target.attr) do
				local tryAttr = vim.deepcopy(target.attr)
				if count > 1 then
					tryAttr[attr] = count - 1
				else
					tryAttr[attr] = nil
				end
				local _, diffSize = symDiff(source.attr, tryAttr)
				if diffSize == 0 then
					-- 正向 <symbol><attr> -> <symbol>
					opts.trig = source.symb .. attr
					addSnip(s(vim.deepcopy(opts), { t(target.symb) }))

					-- 反向 <source>-<attr> -> <symbol>
					if toggleSet[attr] then
						opts.trig = target.symb .. attr
						addSnip(s(vim.deepcopy(opts), { t(source.symb) }))
					else
						opts.trig = target.symb .. "-" .. attr
						addSnip(s(vim.deepcopy(opts), { t(source.symb) }))
					end
				end
			end
			::continue::
		end
	end
	-- 替换属性
	for i = 1, #relation do
        for j = i + 1, #relation do
			local node1, node2 = relation[i], relation[j]
			if node1.numAttr ~= node2.numAttr then
				goto continue
			end
			local diff, size = symDiff(node1.attr, node2.attr)
			if size == 2 then
				local a, b = nil, nil
				for k, v in pairs(diff) do
					if v == -1 then
						a = k
					elseif v == 1 then
						b = k
					end
				end
				if a and b and altClassIndex[a] and altClassIndex[a] == altClassIndex[b] then
					opts.trig = node1.symb .. b
					addSnip(s(vim.deepcopy(opts), { t(node2.symb) }))
					opts.trig = node2.symb .. a
					addSnip(s(vim.deepcopy(opts), { t(node1.symb) }))
				end
			end
			::continue::
		end
	end
end

local function simpleSnip(arr, opts)
	-- Example:
	-- {
	--     { "and;", "∧" },
	--     { "or;", "∨" },
	--     { "cup;", { "∪", "⊔" } },
	--     { "cap;", { "∩", "⨅" } },
	--     { "<n", "≮", {auto=false} },
	--     { "≤n", "≰", {auto=false} },
	-- }
	for _, v in pairs(arr) do
		local curOpts = v[3] and v[3] or {}
		local addSnip
		for optName, optVal in pairs(opts) do
			if curOpts[optName] == nil then
				curOpts[optName] = optVal
			end
		end
		curOpts.trig = v[1]
		addSnip = curOpts.auto and asnip or snip
		if type(v[2]) == "table" then
			addSnip(s(curOpts, { t(v[2][1]) }))
			switchSnip(v[2], mathOptShow)
		else
			addSnip(s(curOpts, { t(v[2]) }))
		end
	end
end

----------------------------------测试--------------------------------
local function tests()
	local test1 = s("test:text", { t("hello world!") })
	snip(test1)

	local test2 =
		s("test:insert", { i(2, ">>>insert 1<<<"), t(" "), sn(1, { i(1, ">>>insert 2<<<") }), i(3, ">>>insert 3<<<") })
	snip(test2)

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

	local test5 = s("test:printparent", {
		f(function(arg, parent, userarg)
			return recursiveprint(parent, 3)
		end, {}, {}),
	})
	snip(test5)

	local test6 = s("test:ts", {
		f(function()
			local str = ""
			local cur = vim.treesitter.get_node()
			local root = cur:tree():root()
			while true do
				str = str == "" and tostring(cur:type()) or str .. " " .. tostring(cur:type())
				if cur == root then
					str = str .. tostring(cur:has_error())
					break
				else
					cur = cur:parent()
				end
			end
			return str
		end, {}, {}),
	})
	asnip(test6)

	local test7 = s({ trig = "test:ecma([0-9])", trigEngine = "ecma" }, {
		f(function(arg, parent, userArg)
			return parent.captures
		end, {}, {}),
	})
	snip(test7)

	local globalCounter = 0
	local function counter()
		globalCounter = globalCounter + 1
		return tostring(globalCounter)
	end
	local test8 = s({ trig = "test:count" }, {
		f(counter),
	})
	snip(test8)

	local test9 = s({ trig = "test:update" }, {
		d(1, function(arg)
			return sn(nil, { i(1, { key = "child" }), t(": ") })
		end, { key("child") }, {}),
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
	local arr = {
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
		{ "int;", "∫" },
		{ "|m", "mid(|)" },
	}
	simpleSnip(arr, mathOptHideAuto)
	local relation={
		{ "∃",{}},
		{ "∄",{"n"} },
	}
	orderSnip(relation,{},{"n"},mathOptShowAuto)
end
Symbols()

--积分
local function Integrals()
	local arr = {
		{ "∫", { "i" } },
		{ "∬", { "i", "i" } },
		{ "∭", { "i", "i", "i" } },
		{ "∮", { "i", "o" } },
		{ "∯", { "i", "i", "o" } },
		{ "∰", { "i", "i", "i", "o" } },
	}
	local toggleList = { "o" }
	orderSnip(arr, {}, toggleList, mathOptShowAuto)
end
Integrals()

--希腊字母
local function GreekLetters()
	local arr = {
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

	for k, v in pairs(arr) do
		asnip(s({ trig = "\\" .. v[1], condition = mathZone }, { t(v[2][1]) }))
		asnip(s({
			trig = "\\" .. string.upper(string.sub(v[1], 1, 1)) .. string.sub(v[1], 2),
			condition = mathZone,
		}, { t(v[2][#v[2]]) }))
		switchSnip(v[2], mathOptShow)
	end
end
GreekLetters()

--大型运算符
local function BigOperators()
	local arr = {
		{ "sum", "∑" },
		{ "prod", "∏" },
		{ "coprod", "∐" },
		{ "plusc", "⨁" },
		{ "timec", "⨂" },
		{ "bdotc", "⨀" },
		{ "bcup", "⋃" },
		{ "bcups", "⨆" },
		{ "bcap", "⋂" },
		{ "bcaps", "⨅" },
		{ "band", "⋀" },
		{ "bor", "⋁" },
	}
	for _, v in pairs(arr) do
		snip(s({ trig = v[1], condition = mathZone }, { t(v[2] .. " _( "), i(1), t(" ) ^( "), i(2), t(" ) ") }))
		snip(s({
			trig = v[1] .. "%s+([^%s]+)%s+([^%s]*)%s+([^%s]*)%s*",
			hidden = true,
			trigEngine = "pattern",
			condition = mathZone,
		}, {
			t(v[2] .. " _( "),
			f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}, {}),
			t(" = "),
			f(function(arg, parent, userArg)
				return parent.captures[2]
			end, {}, {}),
			t(" ) ^( "),
			f(function(arg, parent, userArg)
				return parent.captures[3]
			end, {}, {}),
			t(" ) "),
		}))
		asnip(s({ trig = v[1] .. ";", hidden = true, condition = mathZone }, {
			t(v[2] .. " _( "),
			i(1),
			t(" ) "),
		}))
	end
end
BigOperators()

--运算符
local function Operators()
	local arr = {
		{ "aa", "+" },
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
	simpleSnip(arr, mathOptShowAuto)
end
Operators()

--关系符
local function Relations()
	simpleSnip({
			{ "in;", "∈" },
			{ "sub;", "⊂" },
			{ "sup;", "⊃" },
		},
		mathOptShowAuto
	)
	orderSnip({
			{ "∈", { "." }, { { ",", "." } } },
			{ "∋", { "," }, { { ",", "." } } },
			{ "∉", { ".", "n" }, { { ",", "." } } },
			{ "∌", { ",", "n" }, { { ",", "." } } }
		},
		{{",","."}},
		{"n"},
		mathOptShowAuto
	)
	orderSnip({
			{ "⊂", { "." }},
			{ "⊃", { "," }},
			{ "⊄", { ".", "n" }},
			{ "⊅", { ",", "n" }},
			{ "⊆", { ".", "e" }},
			{ "⊇", { ",", "e" }},
			{ "⊊", { ".", "e", "n" }},
			{ "⊋", { ",", "e", "n" }},
			{ "⊏", { ".", "s" }},
			{ "⊐", { ",", "s" }},
			{ "⊑", { ".", "s", "e" }},
			{ "⊒", { ",", "s", "e" }},
			{ "⋤", { ".", "s", "e", "n" }},
			{ "⋥", { ",", "s", "e", "n" }},
		},
		{{",","."}},
		{"e","s","n"},
	 	mathOptShowAuto
	)
	switchSnip({ "⊊", "⊈" }, mathOptShow)
	switchSnip({ "⊋", "⊉" }, mathOptShow)
	switchSnip({ "⋤", "⋢" }, mathOptShow)
	switchSnip({ "⋥", "⋣" }, mathOptShow)

	simpleSnip({
			{ "sim", "〜" },
			{ "es;", "⋍" },
			{ "ee;", "=" },
			{ "ne;", "≠" },
			{ "eee", "≡" },
			{ ":=", "≔" },
			{ "=def", "≝" },
			{ "=?", "≟" },
		},
		mathOptShow
	)
	orderSnip({
			{"=",{"l","l"}},
			{"≠",{"l","l","n"}},
			{"≡",{"l","l","l"}},
			{"≢",{"l","l","l","n"}},
			{"≣",{"l","l","l","l"}},
			{"≅",{"l","l","s"}},
			{"≇",{"l","l","s","n"}},
			{"⋍",{"l","s"}},
			{"≄",{"l","s","n"}},
		},
		{},
		{"s","n"},
		mathOptShowAuto
	)

	simpleSnip({
			{ ",e", "≤" },
			{ ".e", "≥" },
		},
		mathOptShow
	)
	orderSnip({
			{ "<", { "," } },
			{ ">", { "." } },
			{ "≮", { ",", "n" } },
			{ "≯", { ".", "n" } },
			{ "≤", { ",", "e" } },
			{ "≥", { ".", "e" } },
			{ "≰", { ",", "e", "n" } },
			{ "≱", { ".", "e", "n" } },

			{ "⊲", { ",", "t" } },
			{ "⊳", { ".", "t" } },
			{ "⋪", { ",", "e", "n" } },
			{ "⋫", { ".", "e", "n" } },
			{ "⊴", { ",", "t", "e" } },
			{ "⊵", { ".", "t", "e" } },
			{ "⋬", { ",", "t", "e", "n" } },
			{ "⋭", { ".", "t", "e", "n" } },

			{ "≺", { ",", "c" } },
			{ "≻", { ".", "c" }, },
			{ "⊀", { ",", "c", "n" } },
			{ "⊁", { ".", "c", "n" } },
			{ "≼", { ",", "c", "e" } },
			{ "≽", { ".", "c", "e" } },
			{ "⋠", { ",", "c", "e", "n" } },
			{ "⋡", { ".", "c", "e", "n" } },
		},
		{{",",""}},
		{"t","c","n"},
		mathOptShowAuto
	)

	-- other
	simpleSnip({
			{ "prop;", "∝" },

			{ "div;", "\\/"},
			{ "divs;", "∣" },

			{ "join", "⨝" },
		},
		mathOptShowAuto
	)
	orderSnip({
			{ "⨝", {} },
			{ "⟕", {","} },
			{ "⟖", {"."} },
			{ "⟗", {",","."}}
		},
		{},
		{",","."},
		mathOptShowAuto
	)
	orderSnip({
			{ "∣",{}},
			{ "∤",{"n"} }
		},
		{},
		{"n"},
		mathOptShowAuto
	)
end
Relations()

--箭头
local function Arrows()
	asnip(s({ trig = "ar."}, { t("→") }, { condition = mathZone }))
	asnip(s({ trig = "ar,"}, { t("←") }, { condition = mathZone }))
	asnip(s({ trig = "arr."}, { t("⇒") }, { condition = mathZone }))
	asnip(s({ trig = "arr,"}, { t("⇐") }, { condition = mathZone }))
	snip(s({ trig = "map"}, { t("↦") }, { condition = mathZone }))
	local arr = {
		-- 方向：, . u d 
		-- 左右：s
		-- 上下：v
		-- 增加线数量：l
		-- 增加尾部竖线：b
		-- 钩子hook: ho
		-- 加长：g
		-- 增加箭头数量：hh
		-- 半圆弧：hc
		-- stop/wall: w
		-- 点划线dashed: d

		{ "→", { ".", "l" } },
		{ "←", { ",", "l" } },
		{ "↑", { "u", "l" } },
		{ "↓", { "d", "l" } },
		{ "↔", { "s", "l" } },

		{ "↦", { ".", "l", "b" } },
		{ "↤", { ",", "l", "b" } },

		{ "⇢", { ".", "l","d" } },
		{ "⇠", { ",", "l","d" } },
		{ "⇣", { "u", "l","d" } },
		{ "⇡", { "d", "l","d" } },

		{ "↛", { ".", "l", "n" } },
		{ "↚", { ",", "l", "n" } },

		{ "⇥", { ".", "l", "w" } },
		{ "⇤", { ",", "l", "w" } },
		{ "⤒", { "u", "l", "w" } },
		{ "⤓", { "d", "l", "w" } },
		
		{ "↪︎", { ".", "l", "h" } },
		{ "↩︎", { ",", "l", "h" } },

		{ "⇒", { ".", "l", "l" } },
		{ "⇐", { ",", "l", "l" } },
		{ "⇏", { ".", "l", "l","n" } },
		{ "⇍", { ",", "l", "l","n" } },
		{ "⇔", { "s", "l", "l" } },
		{ "⇑", { "u", "l", "l" } },
		{ "⇓", { "d", "l", "l" } },
		{ "⤇", { ".", "l","l", "b" } },
		{ "⤆", { ",", "l","l", "b" } },
		{ "⤇", { ".", "l","l", "b" } },
		{ "⤆", { ",", "l","l", "b" } },
		{ "⟹", { ".", "l", "l", "g" } },
		{ "⟸", { ",", "l", "l", "g" } },
		{ "⟾", { ".", "l","l", "b", "g" } },
		{ "⟽", { ",", "l","l", "b", "g" } },

		{ "⇛", { ".", "l", "l", "l" } },
		{ "⇚", { ",", "l", "l", "l" } },
		{ "⤊", { "u", "l", "l", "l" } },
		{ "⤋", { "d", "l", "l", "l" } },

		{ "↷", { ".", "l", "hc" } },
		{ "↶", { ",", "l", "hc" } },
	}
	local altClass={{",",".","u","d","s"}}
	local toggleList={"b","ho","g","hh","hc","w","d"}
	orderSnip(arr, altClass, toggleList,mathOptShowAuto)
end
Arrows()

--------------------------------输入--------------------------------
--分数
local function Fraction()
	asnip(s({ trig = "//", hidden = true, condition = mathZone }, {
		d(1, function(arg, parent, oldState, userArg)
			if #parent.env.SELECT_RAW > 0 then
				return sn(nil, { t("( "), t(parent.env.SELECT_RAW), t(" ) / ( "), i(1), t(" ) ") })
			else
				return sn(nil, { t("//") })
			end
		end, {}, {}),
	}))
end
Fraction()

--二项式系数
local function Binomial()
	snip(s({ trig = "bin", hidden = false, condition = mathZone }, { t("binom( "), i(1), t(" ) ") }))

	snip(s({ trig = "bin%s+([^%s]+)%s+([^%s]+)%s*", trigEngine = "pattern", hidden = true, condition = mathZone }, {
		t("binom ( "),
		f(function(arg, parent, userArg)
			return parent.captures[1]
		end, {}),
		t(" , "),
		f(function(arg, parent, userArg)
			return parent.captures[2]
		end, {}),
		t(" ) "),
	}))
end
Binomial()

local function Brackets()
	local function bracketSnip(opts,left,right)
		local addSnip = opts.auto and asnip or snip
		addSnip(s(opts, {
			t(left),
			d(1, function(arg, parent, oldState, userArg)
				if #parent.env.SELECT_RAW > 0 then
					return sn(nil, { t(parent.env.SELECT_RAW) })
				else
					return sn(nil, { i(1) })
				end
			end, {}, {}),
			t(right),
		}))
	end
	bracketSnip({ trig = "jj", auto=true, wordTrig = false, hidden = true, condition = mathZone },"( "," ) ")
	bracketSnip({ trig = "kkb", auto=true, wordTrig = false, hidden = true, condition = mathZone },"[ "," ] ")
	bracketSnip({ trig = "llb", auto=true, wordTrig = false, hidden = true, condition = mathZone },"{ "," } ")
	bracketSnip({ trig = "bb", auto=false, wordTrig = true, hidden = true, condition = mathZone },"⟨ "," ⟩ ")
	bracketSnip({ trig = "kkc", auto=true, wordTrig = false, hidden = false, condition = mathZone },"⟦ "," ⟧ ")
	bracketSnip({ trig = "abs", auto=false, wordTrig = false, hidden = false, condition = mathZone },"abs( "," ) ")
	bracketSnip({ trig = "nrm", auto=false, wordTrig = false, hidden = false, condition = mathZone },"‖ "," ‖ ")
	bracketSnip({ trig = "floor", auto=false, wordTrig = false, hidden = false, condition = mathZone },"floor( "," ) ")
	bracketSnip({ trig = "ceil", auto=false, wordTrig = false, hidden = false, condition = mathZone },"ceil( "," ) ")
	bracketSnip({ trig = "sqr", auto=true, wordTrig = false, hidden = false, condition = mathZone },"sqrt( "," ) ")

end
Brackets()

--文字
local function Texts()
	asnip(s({ trig = "s.t.", hidden = true, condition = mathZone }, { t("stW") }))
	snip(s({ trig = "and", hidden = true, condition = mathZone }, { t("andW") }))
	snip(s({ trig = "or", hidden = true, condition = mathZone }, { t("orW") }))
	snip(s({ trig = "ksw", hidden = true, condition = mathZone }, { t("space.en ") }))
	snip(s({ trig = "iff", hidden = true, condition = mathZone }, { t("iffW ") }))
	snip(s({ trig = "if", hidden = true, condition = mathZone }, { t("ifW") }))
end
Texts()

--极限
local function Limits()
	asnip(
		s(
			{ trig = "lim;", hidden = false, condition = mathZone },
			{ t("lim _( "), i(1), i(2, " → "), i(3), t(" )") }
		)
	)
	asnip(
		s(
			{ trig = "liminf;", hidden = false, condition = mathZone },
			{ t("liminf _( "), i(1), i(2, " → "), i(3), t(" )") }
		)
	)
	asnip(
		s(
			{ trig = "limsup;", hidden = false , condition = mathZone},
			{ t("limsup _( "), i(1), i(2, " → "), i(3), t(" )") }
		)
	)
	asnip(s({ trig = "inf;", hidden = false, condition = mathZone }, { t("inf _( "), i(1), t(" )") }, { condition = mathZone }))
	asnip(s({ trig = "sup;", hidden = false, condition = mathZone }, { t("sup _( "), i(1), t(" )") }, { condition = mathZone }))
end
Limits()

--根式
local function Root()
	snip(s({ trig = "root", wordTrig = false, hidden = false, condition = mathZone }, {
		t("root( "),
		i(2),
		t(" , "),
		d(1, function(arg, parent, oldState, userArg)
			if #parent.env.SELECT_RAW > 0 then
				return sn(nil, { t(parent.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}))
	asnip(s({ trig = "root;([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern",condition = mathZone }, {
		t("root( "),
		i(2),
		t(" , "),
		f(function(arg, parent, userArg)
			return parent.captures[1]
		end, {}),
		i(1),
		t(" ) "),
	}))
end
Root()

--上下内容
local function UnderOverContent()
	local function addSnip(name, effect, key)
		if key == nil then
			key = ";"
		end
		snip(s({ trig = name, hidden = false, trigEngine = "pattern", condition = mathZone }, {
			t(effect .. "( "),
			d(1, function(arg, parent, oldState, userArg)
				if #parent.env.SELECT_RAW > 0 then
					return sn(nil, { t(parent.env.SELECT_RAW) })
				else
					return sn(nil, { i(1) })
				end
			end, {}, {}),
			t(" , "),
			i(2),
			t(" ) "),
		}))
		asnip(s({ trig = name .. key .. "([^%s])", hidden = true, trigEngine = "pattern", condition = mathZone }, {
			t(effect .. "( "),
			f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}),
			i(1),
			t(" , "),
			i(2),
			t(" ) "),
		}))
	end
	addSnip("ubc", "overbrace")
	addSnip("dbc", "underbrace")
	addSnip("ukc", "overbracket")
	addSnip("dkc", "underbracket")
end
UnderOverContent()

--序列
local function Sequence()
    local function nextIndex(val)
        local n = tonumber(val)
        if n then return tostring(n + 1) end
        -- 如果是字母或表达式，直接加1
        return val .. " +1 "
    end

    local function generateSeq(template, start, stop, op)
        local separator = op == "" and ", " or (" " .. op .. " ")
		if not template:find("%%") then
			template=template.."_( % )"
		end
        local first = template:gsub("%%", start)
        local second = template:gsub("%%", nextIndex(start))
        local last = ""
        if stop ~= "inf" then
            last = separator .. template:gsub("%%", stop)
        end
        
        return first .. separator .. second .. separator .. "⋯ " .. last
    end

    snip(s({ 
        trig = "seq%s+([^;]+);([^;]+);([^;]+);?([^;]*)",
        trigEngine = "pattern", 
        hidden = true, 
        condition = mathZone 
    }, {
        f(function(_, parent)
            local caps = parent.captures
            return generateSeq(caps[1], caps[2], caps[3], caps[4])
        end)
    }))

end

Sequence()

--求导
local function Differential()
	asnip(
		s(
			{ trig = ";d", hidden = true },
			{ t("( "), t("upright(d) "), i(1), t(" )/( "), t("upright(d) "), i(2), t(" )") },
			{ condition = mathZone }
		)
	)
	asnip(
		s(
			{ trig = ";p", hidden = true },
			{ t("( "), t("∂ "), i(1), t(" )/( "), t("∂ "), i(2), t(" )") },
			{ condition = mathZone }
		)
	)
	asnip(s({ trig = ".p", hidden = true }, { t("∂ _( "), i(1), t(" )") }, { condition = mathZone }))
	switchSnip({ "∂ _( ", "∂ /( ∂ " })
	asnip(s({ trig = ".d", hidden = true }, { t("upright(d) _( "), i(1), t(" )") }, { condition = mathZone }))
	switchSnip({ "upright(d) _( ", "upright(d) /( upright(d) " })
end
Differential()

--------------------------------装饰--------------------------------
--字体
local function Fonts()
	local function fontSnip(opts,name)
		asnip(s(opts, {
			t(name..'("'),
			f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}),
			i(1),
			t('") '),
		}))
	end
	fontSnip({ trig = ";b(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"mbb")
	fontSnip({ trig = ";f(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"frak")
	fontSnip({ trig = ";c(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"cal")
	fontSnip({ trig = ";s(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"scr")
	fontSnip({ trig = ";v(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"ubold")
	fontSnip({ trig = ";i(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"italic")
	fontSnip({ trig = ";up(%w)", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },"upright")
end
Fonts()

--上下标
local function Attach()
	snip(s({ trig = "uu", wordTrig = false, hidden = true, condition = mathZone }, {
		t("^( "),
		d(1, function(arg, parent, oldState, userArg)
			if #parent.env.SELECT_RAW > 0 then
				return sn(nil, { t(parent.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}))
	asnip(
		s(
			{ trig = "uu([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },
			{ t("^( "), f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}), t(" ) ") }
		)
	)
	asnip(
		s(
			{ trig = "uu ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },
			{ t("^( "), f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}), i(1), t(" ) ") }
		)
	)
	snip(s({ trig = "dd", wordTrig = false, hidden = true, condition = mathZone }, {
		t("_( "),
		d(1, function(arg, parent, oldState, userArg)
			if #parent.env.SELECT_RAW > 0 then
				return sn(nil, { t(parent.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}, {}),
		t(" ) "),
	}))
	asnip(
		s(
			{ trig = "dd([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },
			{ t("_( "), f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}), t(" ) ") }
		)
	)
	asnip(
		s(
			{ trig = "dd ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern", condition = mathZone },
			{ t("_( "), f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}), i(1), t(" ) ") }
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
	local function hatSnip(name, effect, key)
		if key == nil then
			key = ";"
		end
		snip(s({ trig = name, hidden = false, trigEngine = "pattern", condition = mathZone }, {
			t(effect .. "( "),
			d(1, function(arg, parent, oldState, userArg)
				if #parent.env.SELECT_RAW > 0 then
					return sn(nil, { t(parent.env.SELECT_RAW) })
				else
					return sn(nil, { i(1) })
				end
			end, {}, {}),
			t(" ) "),
		}))
		asnip(s({ trig = name .. key .. "(%w)", hidden = false, trigEngine = "pattern", condition = mathZone }, {
			t(effect .. "( "),
			f(function(arg, parent, userArg)
				return parent.captures[1]
			end, {}),
			i(1),
			t(" ) "),
		}))
	end
	local alpha = {
		{ "ua", "arrow", "%." },
		{ "ua", "arrow.l", "," },
		{ "uw", "tilde" },
		{ "uj", "hat" },
		{ "uk", "caron" },
		{ "ud", "dot" },
		{ "ul", "overline" },
		{ "dl", "underline" },
		{ "vv", "ubold" },
		{ "uc", "circle" },
	}
	for _, v in pairs(alpha) do
		hatSnip(v[1], v[2], v[3])
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
			d(3, function(arg, parent, oldState, ...)
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
	snip(s({ trig = "case", hidden = true, condition = mathZone }, {
		t({ "cases(" }),
		d(1, function(arg, parent, oldState, usaerArg)
			return sn(nil, { d(1, generateCases, {}) })
		end),
		t({ "", ")" }),
	}))
end
Cases()

local function Matrix1()
	--SimpleMatrix
	local generateElm
	generateElm = function(arg0, parent0, oldState0, firstElm)
		return sn(nil, {
			t(({ "    ", ",  " })[firstElm]),
			i(1),
			d(2, function(arg, parent, oldState, userArg)
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
	snip(s({ trig = "mat", hidden = true, condition = mathZone }, {
		t({ "mat(", "" }),
		d(1, function(arg, parent, oldState, userArg)
			return sn(nil, { d(1, generateElm, {}, { user_args = { 1 } }) })
		end),
		t({ "", ")" }),
	}))
end
Matrix1()

-- Unicode符号
local function UnicodeSymbols()
    -- 本表生成自https://typst.app/docs/reference/symbols/sym/
    local arr={
        {"AA","𝔸",{priority=-10}},
        {"Alpha","Α",{priority=-10}},
        {"BB","𝔹",{priority=-10}},
        {"Beta","Β",{priority=-10}},
        {"CC","ℂ",{priority=-10}},
        {"Chi","Χ",{priority=-10}},
        {"DD","𝔻",{priority=-10}},
        {"Delta","Δ",{priority=-10}},
        {"EE","𝔼",{priority=-10}},
        {"Epsilon","Ε",{priority=-10}},
        {"Eta","Η",{priority=-10}},
        {"FF","𝔽",{priority=-10}},
        {"GG","𝔾",{priority=-10}},
        {"Gamma","Γ",{priority=-10}},
        {"HH","ℍ",{priority=-10}},
        {"II","𝕀",{priority=-10}},
        {"Im","ℑ",{priority=-10}},
        {"Iota","Ι",{priority=-10}},
        {"JJ","𝕁",{priority=-10}},
        {"KK","𝕂",{priority=-10}},
        {"Kai","Ϗ",{priority=-10}},
        {"Kappa","Κ",{priority=-10}},
        {"LL","𝕃",{priority=-10}},
        {"Lambda","Λ",{priority=-10}},
        {"MM","𝕄",{priority=-10}},
        {"Mu","Μ",{priority=-10}},
        {"NN","ℕ",{priority=-10}},
        {"Nu","Ν",{priority=-10}},
        {"OO","𝕆",{priority=-10}},
        {"Omega","Ω",{priority=-10}},
        {"Omega.inv","℧",{priority=-9}},
        {"Omicron","Ο",{priority=-10}},
        {"PP","ℙ",{priority=-10}},
        {"Phi","Φ",{priority=-10}},
        {"Pi","Π",{priority=-10}},
        {"Psi","Ψ",{priority=-10}},
        {"QQ","ℚ",{priority=-10}},
        {"RR","ℝ",{priority=-10}},
        {"Re","ℜ",{priority=-10}},
        {"Rho","Ρ",{priority=-10}},
        {"SS","𝕊",{priority=-10}},
        {"Sigma","Σ",{priority=-10}},
        {"TT","𝕋",{priority=-10}},
        {"Tau","Τ",{priority=-10}},
        {"Theta","Θ",{priority=-10}},
        {"UU","𝕌",{priority=-10}},
        {"Upsilon","Υ",{priority=-10}},
        {"VV","𝕍",{priority=-10}},
        {"WW","𝕎",{priority=-10}},
        {"XX","𝕏",{priority=-10}},
        {"Xi","Ξ",{priority=-10}},
        {"YY","𝕐",{priority=-10}},
        {"ZZ","ℤ",{priority=-10}},
        {"Zeta","Ζ",{priority=-10}},
        {"acute","´",{priority=-10}},
        {"acute.double","˝",{priority=-9}},
        {"alef","א",{priority=-10}},
        {"aleph","א",{priority=-10}},
        {"alpha","α",{priority=-10}},
        {"amp","&",{priority=-10}},
        {"amp.inv","⅋",{priority=-9}},
        {"and","∧",{priority=-10}},
        {"and.big","⋀",{priority=-9}},
        {"and.curly","⋏",{priority=-9}},
        {"and.dot","⟑",{priority=-9}},
        {"and.double","⩓",{priority=-9}},
        {"angle","∠",{priority=-10}},
        {"angle.l","⟨",{priority=-9}},
        {"angle.l.curly","⧼",{priority=-8}},
        {"angle.l.dot","⦑",{priority=-8}},
        {"angle.l.double","⟪",{priority=-8}},
        {"angle.r","⟩",{priority=-9}},
        {"angle.r.curly","⧽",{priority=-8}},
        {"angle.r.dot","⦒",{priority=-8}},
        {"angle.r.double","⟫",{priority=-8}},
        {"angle.acute","⦟",{priority=-9}},
        {"angle.arc","∡",{priority=-9}},
        {"angle.arc.rev","⦛",{priority=-8}},
        {"angle.oblique","⦦",{priority=-9}},
        {"angle.rev","⦣",{priority=-9}},
        {"angle.right","∟",{priority=-9}},
        {"angle.right.rev","⯾",{priority=-8}},
        {"angle.right.arc","⊾",{priority=-8}},
        {"angle.right.dot","⦝",{priority=-8}},
        {"angle.right.sq","⦜",{priority=-8}},
        {"angle.s","⦞",{priority=-9}},
        {"angle.spatial","⟀",{priority=-9}},
        {"angle.spheric","∢",{priority=-9}},
        {"angle.spheric.rev","⦠",{priority=-8}},
        {"angle.spheric.top","⦡",{priority=-8}},
        {"angstrom","Å",{priority=-10}},
        {"approx","≈",{priority=-10}},
        {"approx.eq","≊",{priority=-9}},
        {"approx.not","≉",{priority=-9}},
        {"arrow.r","→",{priority=-9}},
        {"arrow.r.long.bar","⟼",{priority=-7}},
        {"arrow.r.bar","↦",{priority=-8}},
        {"arrow.r.curve","⤷",{priority=-8}},
        {"arrow.r.turn","⮎",{priority=-8}},
        {"arrow.r.dashed","⇢",{priority=-8}},
        {"arrow.r.dotted","⤑",{priority=-8}},
        {"arrow.r.double","⇒",{priority=-8}},
        {"arrow.r.double.bar","⤇",{priority=-7}},
        {"arrow.r.double.long","⟹",{priority=-7}},
        {"arrow.r.double.long.bar","⟾",{priority=-6}},
        {"arrow.r.double.not","⇏",{priority=-7}},
        {"arrow.r.filled","➡",{priority=-8}},
        {"arrow.r.hook","↪",{priority=-8}},
        {"arrow.r.long","⟶",{priority=-8}},
        {"arrow.r.long.squiggly","⟿",{priority=-7}},
        {"arrow.r.loop","↬",{priority=-8}},
        {"arrow.r.not","↛",{priority=-8}},
        {"arrow.r.quad","⭆",{priority=-8}},
        {"arrow.r.squiggly","⇝",{priority=-8}},
        {"arrow.r.stop","⇥",{priority=-8}},
        {"arrow.r.stroked","⇨",{priority=-8}},
        {"arrow.r.tail","↣",{priority=-8}},
        {"arrow.r.tilde","⥲",{priority=-8}},
        {"arrow.r.triple","⇛",{priority=-8}},
        {"arrow.r.twohead.bar","⤅",{priority=-7}},
        {"arrow.r.twohead","↠",{priority=-8}},
        {"arrow.r.wave","↝",{priority=-8}},
        {"arrow.l","←",{priority=-9}},
        {"arrow.l.bar","↤",{priority=-8}},
        {"arrow.l.curve","⤶",{priority=-8}},
        {"arrow.l.turn","⮌",{priority=-8}},
        {"arrow.l.dashed","⇠",{priority=-8}},
        {"arrow.l.dotted","⬸",{priority=-8}},
        {"arrow.l.double","⇐",{priority=-8}},
        {"arrow.l.double.bar","⤆",{priority=-7}},
        {"arrow.l.double.long","⟸",{priority=-7}},
        {"arrow.l.double.long.bar","⟽",{priority=-6}},
        {"arrow.l.double.not","⇍",{priority=-7}},
        {"arrow.l.filled","⬅",{priority=-8}},
        {"arrow.l.hook","↩",{priority=-8}},
        {"arrow.l.long","⟵",{priority=-8}},
        {"arrow.l.long.bar","⟻",{priority=-7}},
        {"arrow.l.long.squiggly","⬳",{priority=-7}},
        {"arrow.l.loop","↫",{priority=-8}},
        {"arrow.l.not","↚",{priority=-8}},
        {"arrow.l.quad","⭅",{priority=-8}},
        {"arrow.l.squiggly","⇜",{priority=-8}},
        {"arrow.l.stop","⇤",{priority=-8}},
        {"arrow.l.stroked","⇦",{priority=-8}},
        {"arrow.l.tail","↢",{priority=-8}},
        {"arrow.l.tilde","⭉",{priority=-8}},
        {"arrow.l.triple","⇚",{priority=-8}},
        {"arrow.l.twohead.bar","⬶",{priority=-7}},
        {"arrow.l.twohead","↞",{priority=-8}},
        {"arrow.l.wave","↜",{priority=-8}},
        {"arrow.t","↑",{priority=-9}},
        {"arrow.t.bar","↥",{priority=-8}},
        {"arrow.t.curve","⤴",{priority=-8}},
        {"arrow.t.turn","⮍",{priority=-8}},
        {"arrow.t.dashed","⇡",{priority=-8}},
        {"arrow.t.double","⇑",{priority=-8}},
        {"arrow.t.filled","⬆",{priority=-8}},
        {"arrow.t.quad","⟰",{priority=-8}},
        {"arrow.t.stop","⤒",{priority=-8}},
        {"arrow.t.stroked","⇧",{priority=-8}},
        {"arrow.t.triple","⤊",{priority=-8}},
        {"arrow.t.twohead","↟",{priority=-8}},
        {"arrow.b","↓",{priority=-9}},
        {"arrow.b.bar","↧",{priority=-8}},
        {"arrow.b.curve","⤵",{priority=-8}},
        {"arrow.b.turn","⮏",{priority=-8}},
        {"arrow.b.dashed","⇣",{priority=-8}},
        {"arrow.b.double","⇓",{priority=-8}},
        {"arrow.b.filled","⬇",{priority=-8}},
        {"arrow.b.quad","⟱",{priority=-8}},
        {"arrow.b.stop","⤓",{priority=-8}},
        {"arrow.b.stroked","⇩",{priority=-8}},
        {"arrow.b.triple","⤋",{priority=-8}},
        {"arrow.b.twohead","↡",{priority=-8}},
        {"arrow.l.r","↔",{priority=-8}},
        {"arrow.l.r.double","⇔",{priority=-7}},
        {"arrow.l.r.double.long","⟺",{priority=-6}},
        {"arrow.l.r.double.not","⇎",{priority=-6}},
        {"arrow.l.r.filled","⬌",{priority=-7}},
        {"arrow.l.r.long","⟷",{priority=-7}},
        {"arrow.l.r.not","↮",{priority=-7}},
        {"arrow.l.r.stroked","⬄",{priority=-7}},
        {"arrow.l.r.wave","↭",{priority=-7}},
        {"arrow.t.b","↕",{priority=-8}},
        {"arrow.t.b.double","⇕",{priority=-7}},
        {"arrow.t.b.filled","⬍",{priority=-7}},
        {"arrow.t.b.stroked","⇳",{priority=-7}},
        {"arrow.tr","↗",{priority=-9}},
        {"arrow.tr.double","⇗",{priority=-8}},
        {"arrow.tr.filled","⬈",{priority=-8}},
        {"arrow.tr.hook","⤤",{priority=-8}},
        {"arrow.tr.stroked","⬀",{priority=-8}},
        {"arrow.br","↘",{priority=-9}},
        {"arrow.br.double","⇘",{priority=-8}},
        {"arrow.br.filled","⬊",{priority=-8}},
        {"arrow.br.hook","⤥",{priority=-8}},
        {"arrow.br.stroked","⬂",{priority=-8}},
        {"arrow.tl","↖",{priority=-9}},
        {"arrow.tl.double","⇖",{priority=-8}},
        {"arrow.tl.filled","⬉",{priority=-8}},
        {"arrow.tl.hook","⤣",{priority=-8}},
        {"arrow.tl.stroked","⬁",{priority=-8}},
        {"arrow.bl","↙",{priority=-9}},
        {"arrow.bl.double","⇙",{priority=-8}},
        {"arrow.bl.filled","⬋",{priority=-8}},
        {"arrow.bl.hook","⤦",{priority=-8}},
        {"arrow.bl.stroked","⬃",{priority=-8}},
        {"arrow.tl.br","⤡",{priority=-8}},
        {"arrow.tr.bl","⤢",{priority=-8}},
        {"arrow.ccw","↺",{priority=-9}},
        {"arrow.ccw.half","↶",{priority=-8}},
        {"arrow.cw","↻",{priority=-9}},
        {"arrow.cw.half","↷",{priority=-8}},
        {"arrow.zigzag","↯",{priority=-9}},
        {"arrowhead.t","⌃",{priority=-9}},
        {"arrowhead.b","⌄",{priority=-9}},
        {"arrows.rr","⇉",{priority=-9}},
        {"arrows.ll","⇇",{priority=-9}},
        {"arrows.tt","⇈",{priority=-9}},
        {"arrows.bb","⇊",{priority=-9}},
        {"arrows.lr","⇆",{priority=-9}},
        {"arrows.lr.stop","↹",{priority=-8}},
        {"arrows.rl","⇄",{priority=-9}},
        {"arrows.tb","⇅",{priority=-9}},
        {"arrows.bt","⇵",{priority=-9}},
        {"arrows.rrr","⇶",{priority=-9}},
        {"arrows.lll","⬱",{priority=-9}},
        {"ast.op","∗",{priority=-9}},
        {"ast.basic","*",{priority=-9}},
        {"ast.low","⁎",{priority=-9}},
        {"ast.double","⁑",{priority=-9}},
        {"ast.triple","⁂",{priority=-9}},
        {"ast.small","﹡",{priority=-9}},
        {"ast.circle","⊛",{priority=-9}},
        {"ast.square","⧆",{priority=-9}},
        {"asymp","≍",{priority=-10}},
        {"asymp.not","≭",{priority=-9}},
        {"at","@",{priority=-10}},
        {"backslash","\\",{priority=-10}},
        {"backslash.circle","⦸",{priority=-9}},
        {"backslash.not","⧷",{priority=-9}},
        {"ballot","☐",{priority=-10}},
        {"ballot.cross","☒",{priority=-9}},
        {"ballot.check","☑",{priority=-9}},
        {"ballot.check.heavy","🗹",{priority=-8}},
        {"bar.v","|",{priority=-9}},
        {"bar.v.double","‖",{priority=-8}},
        {"bar.v.triple","⦀",{priority=-8}},
        {"bar.v.broken","¦",{priority=-8}},
        {"bar.v.circle","⦶",{priority=-8}},
        {"bar.h","―",{priority=-9}},
        {"because","∵",{priority=-10}},
        {"bet","ב",{priority=-10}},
        {"beta","β",{priority=-10}},
        {"beta.alt","ϐ",{priority=-9}},
        {"beth","ב",{priority=-10}},
        {"bitcoin","₿",{priority=-10}},
        {"bot","⊥",{priority=-10}},
        {"brace.l","{",{priority=-9}},
        {"brace.l.double","⦃",{priority=-8}},
        {"brace.r","}",{priority=-9}},
        {"brace.r.double","⦄",{priority=-8}},
        {"brace.t","⏞",{priority=-9}},
        {"brace.b","⏟",{priority=-9}},
        {"bracket.l","[",{priority=-9}},
        {"bracket.l.double","⟦",{priority=-8}},
        {"bracket.r","]",{priority=-9}},
        {"bracket.r.double","⟧",{priority=-8}},
        {"bracket.t","⎴",{priority=-9}},
        {"bracket.b","⎵",{priority=-9}},
        {"breve","˘",{priority=-10}},
        {"bullet","•",{priority=-10}},
        {"caret","‸",{priority=-10}},
        {"caron","ˇ",{priority=-10}},
        {"ceil.l","⌈",{priority=-9}},
        {"ceil.r","⌉",{priority=-9}},
        {"checkmark","✓",{priority=-10}},
        {"checkmark.light","🗸",{priority=-9}},
        {"checkmark.heavy","✔",{priority=-9}},
        {"chi","χ",{priority=-10}},
        {"circle.stroked","○",{priority=-9}},
        {"circle.stroked.tiny","∘",{priority=-8}},
        {"circle.stroked.small","⚬",{priority=-8}},
        {"circle.stroked.big","◯",{priority=-8}},
        {"circle.filled","●",{priority=-9}},
        {"circle.filled.tiny","⦁",{priority=-8}},
        {"circle.filled.small","∙",{priority=-8}},
        {"circle.filled.big","⬤",{priority=-8}},
        {"circle.dotted","◌",{priority=-9}},
        {"circle.nested","⊚",{priority=-9}},
        {"co","℅",{priority=-10}},
        {"colon",":",{priority=-10}},
        {"colon.double","∷",{priority=-9}},
        {"colon.tri","⁝",{priority=-9}},
        {"colon.tri.op","⫶",{priority=-8}},
        {"colon.eq","≔",{priority=-9}},
        {"colon.double.eq","⩴",{priority=-8}},
        {"comma",",",{priority=-10}},
        {"complement","∁",{priority=-10}},
        {"compose","∘",{priority=-10}},
        {"convolve","∗",{priority=-10}},
        {"copyleft","🄯",{priority=-10}},
        {"copyright","©",{priority=-10}},
        {"copyright.sound","℗",{priority=-9}},
        {"crossmark","✗",{priority=-10}},
        {"crossmark.heavy","✘",{priority=-9}},
        {"dagger","†",{priority=-10}},
        {"dagger.double","‡",{priority=-9}},
        {"dagger.triple","⹋",{priority=-9}},
        {"dagger.l","⸶",{priority=-9}},
        {"dagger.r","⸷",{priority=-9}},
        {"dagger.inv","⸸",{priority=-9}},
        {"dalet","ד",{priority=-10}},
        {"daleth","ד",{priority=-10}},
        {"dash.en","–",{priority=-9}},
        {"dash.em","—",{priority=-9}},
        {"dash.em.two","⸺",{priority=-8}},
        {"dash.em.three","⸻",{priority=-8}},
        {"dash.fig","‒",{priority=-9}},
        {"dash.wave","〜",{priority=-9}},
        {"dash.colon","∹",{priority=-9}},
        {"dash.circle","⊝",{priority=-9}},
        {"dash.wave.double","〰",{priority=-8}},
        {"degree","°",{priority=-10}},
        {"delta","δ",{priority=-10}},
        {"diaer","¨",{priority=-10}},
        {"diameter","⌀",{priority=-10}},
        {"diamond.stroked","◇",{priority=-9}},
        {"diamond.stroked.small","⋄",{priority=-8}},
        {"diamond.stroked.medium","⬦",{priority=-8}},
        {"diamond.stroked.dot","⟐",{priority=-8}},
        {"diamond.filled","◆",{priority=-9}},
        {"diamond.filled.medium","⬥",{priority=-8}},
        {"diamond.filled.small","⬩",{priority=-8}},
        {"die.six","⚅",{priority=-9}},
        {"die.five","⚄",{priority=-9}},
        {"die.four","⚃",{priority=-9}},
        {"die.three","⚂",{priority=-9}},
        {"die.two","⚁",{priority=-9}},
        {"die.one","⚀",{priority=-9}},
        {"diff","∂",{priority=-10}},
        {"div","÷",{priority=-10}},
        {"div.circle","⨸",{priority=-9}},
        {"divides","∣",{priority=-10}},
        {"divides.not","∤",{priority=-9}},
        {"divides.not.rev","⫮",{priority=-8}},
        {"divides.struck","⟊",{priority=-9}},
        {"dollar","$",{priority=-10}},
        {"dot.op","⋅",{priority=-9}},
        {"dot.basic",".",{priority=-9}},
        {"dot.c","·",{priority=-9}},
        {"dot.circle","⊙",{priority=-9}},
        {"dot.circle.big","⨀",{priority=-8}},
        {"dot.square","⊡",{priority=-9}},
        {"dot.double","¨",{priority=-9}},
        {"dot.triple","⃛",{priority=-9}},
        {"dot.quad","⃜",{priority=-9}},
        {"dotless.i","ı",{priority=-9}},
        {"dotless.j","ȷ",{priority=-9}},
        {"dots.h.c","⋯",{priority=-8}},
        {"dots.h","…",{priority=-9}},
        {"dots.v","⋮",{priority=-9}},
        {"dots.down","⋱",{priority=-9}},
        {"dots.up","⋰",{priority=-9}},
        {"ell","ℓ",{priority=-10}},
        {"ellipse.stroked.h","⬭",{priority=-8}},
        {"ellipse.stroked.v","⬯",{priority=-8}},
        {"ellipse.filled.h","⬬",{priority=-8}},
        {"ellipse.filled.v","⬮",{priority=-8}},
        {"emptyset","∅",{priority=-10}},
        {"emptyset.arrow.r","⦳",{priority=-8}},
        {"emptyset.arrow.l","⦴",{priority=-8}},
        {"emptyset.bar","⦱",{priority=-9}},
        {"emptyset.circle","⦲",{priority=-9}},
        {"emptyset.rev","⦰",{priority=-9}},
        {"epsilon","ε",{priority=-10}},
        {"epsilon.alt","ϵ",{priority=-9}},
        {"eq","=",{priority=-10}},
        {"eq.star","≛",{priority=-9}},
        {"eq.circle","⊜",{priority=-9}},
        {"eq.colon","≕",{priority=-9}},
        {"eq.dots","≑",{priority=-9}},
        {"eq.dots.down","≒",{priority=-8}},
        {"eq.dots.up","≓",{priority=-8}},
        {"eq.def","≝",{priority=-9}},
        {"eq.delta","≜",{priority=-9}},
        {"eq.equi","≚",{priority=-9}},
        {"eq.est","≙",{priority=-9}},
        {"eq.gt","⋝",{priority=-9}},
        {"eq.lt","⋜",{priority=-9}},
        {"eq.m","≞",{priority=-9}},
        {"eq.not","≠",{priority=-9}},
        {"eq.prec","⋞",{priority=-9}},
        {"eq.quest","≟",{priority=-9}},
        {"eq.small","﹦",{priority=-9}},
        {"eq.succ","⋟",{priority=-9}},
        {"eq.triple","≡",{priority=-9}},
        {"eq.triple.not","≢",{priority=-8}},
        {"eq.quad","≣",{priority=-9}},
        {"equiv","≡",{priority=-10}},
        {"equiv.not","≢",{priority=-9}},
        {"errorbar.square.stroked","⧮",{priority=-8}},
        {"errorbar.square.filled","⧯",{priority=-8}},
        {"errorbar.diamond.stroked","⧰",{priority=-8}},
        {"errorbar.diamond.filled","⧱",{priority=-8}},
        {"errorbar.circle.stroked","⧲",{priority=-8}},
        {"errorbar.circle.filled","⧳",{priority=-8}},
        {"eta","η",{priority=-10}},
        {"euro","€",{priority=-10}},
        {"excl","!",{priority=-10}},
        {"excl.double","‼",{priority=-9}},
        {"excl.inv","¡",{priority=-9}},
        {"excl.quest","⁉",{priority=-9}},
        {"exists","∃",{priority=-10}},
        {"exists.not","∄",{priority=-9}},
        {"fence.l","⧘",{priority=-9}},
        {"fence.l.double","⧚",{priority=-8}},
        {"fence.r","⧙",{priority=-9}},
        {"fence.r.double","⧛",{priority=-8}},
        {"fence.dotted","⦙",{priority=-9}},
        {"flat","♭",{priority=-10}},
        {"flat.t","𝄬",{priority=-9}},
        {"flat.b","𝄭",{priority=-9}},
        {"flat.double","𝄫",{priority=-9}},
        {"flat.quarter","𝄳",{priority=-9}},
        {"floor.l","⌊",{priority=-9}},
        {"floor.r","⌋",{priority=-9}},
        {"floral","❦",{priority=-10}},
        {"floral.l","☙",{priority=-9}},
        {"floral.r","❧",{priority=-9}},
        {"forall","∀",{priority=-10}},
        {"forces","⊩",{priority=-10}},
        {"forces.not","⊮",{priority=-9}},
        {"franc","₣",{priority=-10}},
        {"gamma","γ",{priority=-10}},
        {"gimel","ג",{priority=-10}},
        {"gimmel","ג",{priority=-10}},
        {"gradient","∇",{priority=-10}},
        {"grave","`",{priority=-10}},
        {"gt",">",{priority=-10}},
        {"gt.circle","⧁",{priority=-9}},
        {"gt.dot","⋗",{priority=-9}},
        {"gt.approx","⪆",{priority=-9}},
        {"gt.double","≫",{priority=-9}},
        {"gt.eq","≥",{priority=-9}},
        {"gt.eq.slant","⩾",{priority=-8}},
        {"gt.eq.lt","⋛",{priority=-8}},
        {"gt.eq.not","≱",{priority=-8}},
        {"gt.equiv","≧",{priority=-9}},
        {"gt.lt","≷",{priority=-9}},
        {"gt.lt.not","≹",{priority=-8}},
        {"gt.neq","⪈",{priority=-9}},
        {"gt.napprox","⪊",{priority=-9}},
        {"gt.nequiv","≩",{priority=-9}},
        {"gt.not","≯",{priority=-9}},
        {"gt.ntilde","⋧",{priority=-9}},
        {"gt.small","﹥",{priority=-9}},
        {"gt.tilde","≳",{priority=-9}},
        {"gt.tilde.not","≵",{priority=-8}},
        {"gt.tri","⊳",{priority=-9}},
        {"gt.tri.eq","⊵",{priority=-8}},
        {"gt.tri.eq.not","⋭",{priority=-7}},
        {"gt.tri.not","⋫",{priority=-8}},
        {"gt.triple","⋙",{priority=-9}},
        {"gt.triple.nested","⫸",{priority=-8}},
        {"harpoon.rt","⇀",{priority=-9}},
        {"harpoon.rt.bar","⥛",{priority=-8}},
        {"harpoon.rt.stop","⥓",{priority=-8}},
        {"harpoon.rb","⇁",{priority=-9}},
        {"harpoon.rb.bar","⥟",{priority=-8}},
        {"harpoon.rb.stop","⥗",{priority=-8}},
        {"harpoon.lt","↼",{priority=-9}},
        {"harpoon.lt.bar","⥚",{priority=-8}},
        {"harpoon.lt.stop","⥒",{priority=-8}},
        {"harpoon.lb","↽",{priority=-9}},
        {"harpoon.lb.bar","⥞",{priority=-8}},
        {"harpoon.lb.stop","⥖",{priority=-8}},
        {"harpoon.tl","↿",{priority=-9}},
        {"harpoon.tl.bar","⥠",{priority=-8}},
        {"harpoon.tl.stop","⥘",{priority=-8}},
        {"harpoon.tr","↾",{priority=-9}},
        {"harpoon.tr.bar","⥜",{priority=-8}},
        {"harpoon.tr.stop","⥔",{priority=-8}},
        {"harpoon.bl","⇃",{priority=-9}},
        {"harpoon.bl.bar","⥡",{priority=-8}},
        {"harpoon.bl.stop","⥙",{priority=-8}},
        {"harpoon.br","⇂",{priority=-9}},
        {"harpoon.br.bar","⥝",{priority=-8}},
        {"harpoon.br.stop","⥕",{priority=-8}},
        {"harpoon.lt.rt","⥎",{priority=-8}},
        {"harpoon.lb.rb","⥐",{priority=-8}},
        {"harpoon.lb.rt","⥋",{priority=-8}},
        {"harpoon.lt.rb","⥊",{priority=-8}},
        {"harpoon.tl.bl","⥑",{priority=-8}},
        {"harpoon.tr.br","⥏",{priority=-8}},
        {"harpoon.tl.br","⥍",{priority=-8}},
        {"harpoon.tr.bl","⥌",{priority=-8}},
        {"harpoons.rtrb","⥤",{priority=-9}},
        {"harpoons.blbr","⥥",{priority=-9}},
        {"harpoons.bltr","⥯",{priority=-9}},
        {"harpoons.lbrb","⥧",{priority=-9}},
        {"harpoons.ltlb","⥢",{priority=-9}},
        {"harpoons.ltrb","⇋",{priority=-9}},
        {"harpoons.ltrt","⥦",{priority=-9}},
        {"harpoons.rblb","⥩",{priority=-9}},
        {"harpoons.rtlb","⇌",{priority=-9}},
        {"harpoons.rtlt","⥨",{priority=-9}},
        {"harpoons.tlbr","⥮",{priority=-9}},
        {"harpoons.tltr","⥣",{priority=-9}},
        {"hash","#",{priority=-10}},
        {"hat","^",{priority=-10}},
        {"hexa.stroked","⬡",{priority=-9}},
        {"hexa.filled","⬢",{priority=-9}},
        {"hourglass.stroked","⧖",{priority=-9}},
        {"hourglass.filled","⧗",{priority=-9}},
        {"hyph","‐",{priority=-10}},
        {"hyph.minus","-",{priority=-9}},
        {"hyph.nobreak","‑",{priority=-9}},
        {"hyph.point","‧",{priority=-9}},
        {"hyph.soft","shy",{priority=-9}},
        {"image","⊷",{priority=-10}},
        {"in","∈",{priority=-10}},
        {"in.not","∉",{priority=-9}},
        {"in.rev","∋",{priority=-9}},
        {"in.rev.not","∌",{priority=-8}},
        {"in.rev.small","∍",{priority=-8}},
        {"in.small","∊",{priority=-9}},
        {"infinity","∞",{priority=-10}},
        {"infinity.bar","⧞",{priority=-9}},
        {"infinity.incomplete","⧜",{priority=-9}},
        {"infinity.tie","⧝",{priority=-9}},
        {"integral","∫",{priority=-10}},
        {"integral.arrow.hook","⨗",{priority=-8}},
        {"integral.ccw","⨑",{priority=-9}},
        {"integral.cont","∮",{priority=-9}},
        {"integral.cont.ccw","∳",{priority=-8}},
        {"integral.cont.cw","∲",{priority=-8}},
        {"integral.cw","∱",{priority=-9}},
        {"integral.dash","⨍",{priority=-9}},
        {"integral.dash.double","⨎",{priority=-8}},
        {"integral.double","∬",{priority=-9}},
        {"integral.quad","⨌",{priority=-9}},
        {"integral.inter","⨙",{priority=-9}},
        {"integral.sect","⨙",{priority=-9}},
        {"integral.slash","⨏",{priority=-9}},
        {"integral.square","⨖",{priority=-9}},
        {"integral.surf","∯",{priority=-9}},
        {"integral.times","⨘",{priority=-9}},
        {"integral.triple","∭",{priority=-9}},
        {"integral.union","⨚",{priority=-9}},
        {"integral.vol","∰",{priority=-9}},
        {"inter","∩",{priority=-10}},
        {"inter.and","⩄",{priority=-9}},
        {"inter.big","⋂",{priority=-9}},
        {"inter.dot","⩀",{priority=-9}},
        {"inter.double","⋒",{priority=-9}},
        {"inter.sq","⊓",{priority=-9}},
        {"inter.sq.big","⨅",{priority=-8}},
        {"inter.sq.double","⩎",{priority=-8}},
        {"interleave","⫴",{priority=-10}},
        {"interleave.big","⫼",{priority=-9}},
        {"interleave.struck","⫵",{priority=-9}},
        {"interrobang","‽",{priority=-10}},
        {"iota","ι",{priority=-10}},
        {"join","⨝",{priority=-10}},
        {"join.r","⟖",{priority=-9}},
        {"join.l","⟕",{priority=-9}},
        {"join.l.r","⟗",{priority=-8}},
        {"kai","ϗ",{priority=-10}},
        {"kappa","κ",{priority=-10}},
        {"kappa.alt","ϰ",{priority=-9}},
        {"lambda","λ",{priority=-10}},
        {"laplace","∆",{priority=-10}},
        {"lat","⪫",{priority=-10}},
        {"lat.eq","⪭",{priority=-9}},
        {"lira","₺",{priority=-10}},
        {"lozenge.stroked","◊",{priority=-9}},
        {"lozenge.stroked.small","⬫",{priority=-8}},
        {"lozenge.stroked.medium","⬨",{priority=-8}},
        {"lozenge.filled","⧫",{priority=-9}},
        {"lozenge.filled.small","⬪",{priority=-8}},
        {"lozenge.filled.medium","⬧",{priority=-8}},
        {"lrm","‎",{priority=-10}},
        {"lt","<",{priority=-10}},
        {"lt.circle","⧀",{priority=-9}},
        {"lt.dot","⋖",{priority=-9}},
        {"lt.approx","⪅",{priority=-9}},
        {"lt.double","≪",{priority=-9}},
        {"lt.eq","≤",{priority=-9}},
        {"lt.eq.slant","⩽",{priority=-8}},
        {"lt.eq.gt","⋚",{priority=-8}},
        {"lt.eq.not","≰",{priority=-8}},
        {"lt.equiv","≦",{priority=-9}},
        {"lt.gt","≶",{priority=-9}},
        {"lt.gt.not","≸",{priority=-8}},
        {"lt.neq","⪇",{priority=-9}},
        {"lt.napprox","⪉",{priority=-9}},
        {"lt.nequiv","≨",{priority=-9}},
        {"lt.not","≮",{priority=-9}},
        {"lt.ntilde","⋦",{priority=-9}},
        {"lt.small","﹤",{priority=-9}},
        {"lt.tilde","≲",{priority=-9}},
        {"lt.tilde.not","≴",{priority=-8}},
        {"lt.tri","⊲",{priority=-9}},
        {"lt.tri.eq","⊴",{priority=-8}},
        {"lt.tri.eq.not","⋬",{priority=-7}},
        {"lt.tri.not","⋪",{priority=-8}},
        {"lt.triple","⋘",{priority=-9}},
        {"lt.triple.nested","⫷",{priority=-8}},
        {"macron","¯",{priority=-10}},
        {"maltese","✠",{priority=-10}},
        {"mapsto","↦",{priority=-10}},
        {"mapsto.long","⟼",{priority=-9}},
        {"minus","−",{priority=-10}},
        {"minus.circle","⊖",{priority=-9}},
        {"minus.dot","∸",{priority=-9}},
        {"minus.plus","∓",{priority=-9}},
        {"minus.square","⊟",{priority=-9}},
        {"minus.tilde","≂",{priority=-9}},
        {"minus.triangle","⨺",{priority=-9}},
        {"miny","⧿",{priority=-10}},
        {"models","⊧",{priority=-10}},
        {"mu","μ",{priority=-10}},
        {"multimap","⊸",{priority=-10}},
        {"multimap.double","⧟",{priority=-9}},
        {"nabla","∇",{priority=-10}},
        {"natural","♮",{priority=-10}},
        {"natural.t","𝄮",{priority=-9}},
        {"natural.b","𝄯",{priority=-9}},
        {"not","¬",{priority=-10}},
        {"note.up","🎜",{priority=-9}},
        {"note.down","🎝",{priority=-9}},
        {"note.whole","𝅝",{priority=-9}},
        {"note.half","𝅗𝅥",{priority=-9}},
        {"note.quarter","𝅘𝅥",{priority=-9}},
        {"note.quarter.alt","♩",{priority=-8}},
        {"note.eighth","𝅘𝅥𝅮",{priority=-9}},
        {"note.eighth.alt","♪",{priority=-8}},
        {"note.eighth.beamed","♫",{priority=-8}},
        {"note.sixteenth","𝅘𝅥𝅯",{priority=-9}},
        {"note.sixteenth.beamed","♬",{priority=-8}},
        {"note.grace","𝆕",{priority=-9}},
        {"note.grace.slash","𝆔",{priority=-8}},
        {"nothing","∅",{priority=-10}},
        {"nothing.arrow.r","⦳",{priority=-8}},
        {"nothing.arrow.l","⦴",{priority=-8}},
        {"nothing.bar","⦱",{priority=-9}},
        {"nothing.circle","⦲",{priority=-9}},
        {"nothing.rev","⦰",{priority=-9}},
        {"nu","ν",{priority=-10}},
        {"numero","№",{priority=-10}},
        {"omega","ω",{priority=-10}},
        {"omicron","ο",{priority=-10}},
        {"oo","∞",{priority=-10}},
        {"or","∨",{priority=-10}},
        {"or.big","⋁",{priority=-9}},
        {"or.curly","⋎",{priority=-9}},
        {"or.dot","⟇",{priority=-9}},
        {"or.double","⩔",{priority=-9}},
        {"original","⊶",{priority=-10}},
        {"parallel","∥",{priority=-10}},
        {"parallel.struck","⫲",{priority=-9}},
        {"parallel.circle","⦷",{priority=-9}},
        {"parallel.eq","⋕",{priority=-9}},
        {"parallel.equiv","⩨",{priority=-9}},
        {"parallel.not","∦",{priority=-9}},
        {"parallel.slanted.eq","⧣",{priority=-8}},
        {"parallel.slanted.eq.tilde","⧤",{priority=-7}},
        {"parallel.slanted.equiv","⧥",{priority=-8}},
        {"parallel.tilde","⫳",{priority=-9}},
        {"parallelogram.stroked","▱",{priority=-9}},
        {"parallelogram.filled","▰",{priority=-9}},
        {"paren.l","(",{priority=-9}},
        {"paren.l.double","⦅",{priority=-8}},
        {"paren.r",")",{priority=-9}},
        {"paren.r.double","⦆",{priority=-8}},
        {"paren.t","⏜",{priority=-9}},
        {"paren.b","⏝",{priority=-9}},
        {"partial","∂",{priority=-10}},
        {"penta.stroked","⬠",{priority=-9}},
        {"penta.filled","⬟",{priority=-9}},
        {"percent","%",{priority=-10}},
        {"permille","‰",{priority=-10}},
        {"perp","⟂",{priority=-10}},
        {"perp.circle","⦹",{priority=-9}},
        {"peso","₱",{priority=-10}},
        {"phi","φ",{priority=-10}},
        {"phi.alt","ϕ",{priority=-9}},
        {"pi","π",{priority=-10}},
        {"pi.alt","ϖ",{priority=-9}},
        {"pilcrow","¶",{priority=-10}},
        {"pilcrow.rev","⁋",{priority=-9}},
        {"planck","ℎ",{priority=-10}},
        {"planck.reduce","ℏ",{priority=-9}},
        {"plus","+",{priority=-10}},
        {"plus.circle","⊕",{priority=-9}},
        {"plus.circle.arrow","⟴",{priority=-8}},
        {"plus.circle.big","⨁",{priority=-8}},
        {"plus.dot","∔",{priority=-9}},
        {"plus.double","⧺",{priority=-9}},
        {"plus.minus","±",{priority=-9}},
        {"plus.small","﹢",{priority=-9}},
        {"plus.square","⊞",{priority=-9}},
        {"plus.triangle","⨹",{priority=-9}},
        {"plus.triple","⧻",{priority=-9}},
        {"pound","£",{priority=-10}},
        {"prec","≺",{priority=-10}},
        {"prec.approx","⪷",{priority=-9}},
        {"prec.curly.eq","≼",{priority=-8}},
        {"prec.curly.eq.not","⋠",{priority=-7}},
        {"prec.double","⪻",{priority=-9}},
        {"prec.eq","⪯",{priority=-9}},
        {"prec.equiv","⪳",{priority=-9}},
        {"prec.napprox","⪹",{priority=-9}},
        {"prec.neq","⪱",{priority=-9}},
        {"prec.nequiv","⪵",{priority=-9}},
        {"prec.not","⊀",{priority=-9}},
        {"prec.ntilde","⋨",{priority=-9}},
        {"prec.tilde","≾",{priority=-9}},
        {"prime","′",{priority=-10}},
        {"prime.rev","‵",{priority=-9}},
        {"prime.double","″",{priority=-9}},
        {"prime.double.rev","‶",{priority=-8}},
        {"prime.triple","‴",{priority=-9}},
        {"prime.triple.rev","‷",{priority=-8}},
        {"prime.quad","⁗",{priority=-9}},
        {"product","∏",{priority=-10}},
        {"product.co","∐",{priority=-9}},
        {"prop","∝",{priority=-10}},
        {"psi","ψ",{priority=-10}},
        {"qed","∎",{priority=-10}},
        {"quest","?",{priority=-10}},
        {"quest.double","⁇",{priority=-9}},
        {"quest.excl","⁈",{priority=-9}},
        {"quest.inv","¿",{priority=-9}},
        {"quote.double","\"",{priority=-9}},
        {"quote.single","\'",{priority=-9}},
        {"quote.l.double","“",{priority=-8}},
        {"quote.l.single","‘",{priority=-8}},
        {"quote.r.double","”",{priority=-8}},
        {"quote.r.single","’",{priority=-8}},
        {"quote.angle.l.double","«",{priority=-7}},
        {"quote.angle.l.single","‹",{priority=-7}},
        {"quote.angle.r.double","»",{priority=-7}},
        {"quote.angle.r.single","›",{priority=-7}},
        {"quote.high.double","‟",{priority=-8}},
        {"quote.high.single","‛",{priority=-8}},
        {"quote.low.double","„",{priority=-8}},
        {"quote.low.single","‚",{priority=-8}},
        {"ratio","∶",{priority=-10}},
        {"rect.stroked.h","▭",{priority=-8}},
        {"rect.stroked.v","▯",{priority=-8}},
        {"rect.filled.h","▬",{priority=-8}},
        {"rect.filled.v","▮",{priority=-8}},
        {"refmark","※",{priority=-10}},
        {"rest.whole","𝄻",{priority=-9}},
        {"rest.multiple","𝄺",{priority=-9}},
        {"rest.multiple.measure","𝄩",{priority=-8}},
        {"rest.half","𝄼",{priority=-9}},
        {"rest.quarter","𝄽",{priority=-9}},
        {"rest.eighth","𝄾",{priority=-9}},
        {"rest.sixteenth","𝄿",{priority=-9}},
        {"rho","ρ",{priority=-10}},
        {"rho.alt","ϱ",{priority=-9}},
        {"rlm","‏",{priority=-10}},
        {"ruble","₽",{priority=-10}},
        {"rupee","₹",{priority=-10}},
        {"sect","∩",{priority=-10}},
        {"sect.and","⩄",{priority=-9}},
        {"sect.big","⋂",{priority=-9}},
        {"sect.dot","⩀",{priority=-9}},
        {"sect.double","⋒",{priority=-9}},
        {"sect.sq","⊓",{priority=-9}},
        {"sect.sq.big","⨅",{priority=-8}},
        {"sect.sq.double","⩎",{priority=-8}},
        {"section","§",{priority=-10}},
        {"semi",";",{priority=-10}},
        {"semi.rev","⁏",{priority=-9}},
        {"sharp","♯",{priority=-10}},
        {"sharp.t","𝄰",{priority=-9}},
        {"sharp.b","𝄱",{priority=-9}},
        {"sharp.double","𝄪",{priority=-9}},
        {"sharp.quarter","𝄲",{priority=-9}},
        {"shell.l","❲",{priority=-9}},
        {"shell.l.double","⟬",{priority=-8}},
        {"shell.r","❳",{priority=-9}},
        {"shell.r.double","⟭",{priority=-8}},
        {"shell.t","⏠",{priority=-9}},
        {"shell.b","⏡",{priority=-9}},
        {"shin","ש",{priority=-10}},
        {"sigma","σ",{priority=-10}},
        {"sigma.alt","ς",{priority=-9}},
        {"slash","/",{priority=-10}},
        {"slash.double","⫽",{priority=-9}},
        {"slash.triple","⫻",{priority=-9}},
        {"slash.big","⧸",{priority=-9}},
        {"smash","⨳",{priority=-10}},
        {"smt","⪪",{priority=-10}},
        {"smt.eq","⪬",{priority=-9}},
        {"space","␣",{priority=-10}},
        {"space.nobreak","nbsp",{priority=-9}},
        {"space.nobreak.narrow"," ",{priority=-8}},
        {"space.en","ensp",{priority=-9}},
        {"space.quad","emsp",{priority=-9}},
        {"space.third","⅓emsp",{priority=-9}},
        {"space.quarter","¼emsp",{priority=-9}},
        {"space.sixth","⅙emsp",{priority=-9}},
        {"space.med","mmsp",{priority=-9}},
        {"space.fig","numsp",{priority=-9}},
        {"space.punct","puncsp",{priority=-9}},
        {"space.thin","thinsp",{priority=-9}},
        {"space.hair","hairsp",{priority=-9}},
        {"square.stroked","□",{priority=-9}},
        {"square.stroked.tiny","▫",{priority=-8}},
        {"square.stroked.small","◽",{priority=-8}},
        {"square.stroked.medium","◻",{priority=-8}},
        {"square.stroked.big","⬜",{priority=-8}},
        {"square.stroked.dotted","⬚",{priority=-8}},
        {"square.stroked.rounded","▢",{priority=-8}},
        {"square.filled","■",{priority=-9}},
        {"square.filled.tiny","▪",{priority=-8}},
        {"square.filled.small","◾",{priority=-8}},
        {"square.filled.medium","◼",{priority=-8}},
        {"square.filled.big","⬛",{priority=-8}},
        {"star.op","⋆",{priority=-9}},
        {"star.stroked","☆",{priority=-9}},
        {"star.filled","★",{priority=-9}},
        {"subset","⊂",{priority=-10}},
        {"subset.dot","⪽",{priority=-9}},
        {"subset.double","⋐",{priority=-9}},
        {"subset.eq","⊆",{priority=-9}},
        {"subset.eq.not","⊈",{priority=-8}},
        {"subset.eq.sq","⊑",{priority=-8}},
        {"subset.eq.sq.not","⋢",{priority=-7}},
        {"subset.neq","⊊",{priority=-9}},
        {"subset.not","⊄",{priority=-9}},
        {"subset.sq","⊏",{priority=-9}},
        {"subset.sq.neq","⋤",{priority=-8}},
        {"succ","≻",{priority=-10}},
        {"succ.approx","⪸",{priority=-9}},
        {"succ.curly.eq","≽",{priority=-8}},
        {"succ.curly.eq.not","⋡",{priority=-7}},
        {"succ.double","⪼",{priority=-9}},
        {"succ.eq","⪰",{priority=-9}},
        {"succ.equiv","⪴",{priority=-9}},
        {"succ.napprox","⪺",{priority=-9}},
        {"succ.neq","⪲",{priority=-9}},
        {"succ.nequiv","⪶",{priority=-9}},
        {"succ.not","⊁",{priority=-9}},
        {"succ.ntilde","⋩",{priority=-9}},
        {"succ.tilde","≿",{priority=-9}},
        {"suit.club.filled","♣",{priority=-8}},
        {"suit.club.stroked","♧",{priority=-8}},
        {"suit.diamond.filled","♦",{priority=-8}},
        {"suit.diamond.stroked","♢",{priority=-8}},
        {"suit.heart.filled","♥",{priority=-8}},
        {"suit.heart.stroked","♡",{priority=-8}},
        {"suit.spade.filled","♠",{priority=-8}},
        {"suit.spade.stroked","♤",{priority=-8}},
        {"sum","∑",{priority=-10}},
        {"sum.integral","⨋",{priority=-9}},
        {"supset","⊃",{priority=-10}},
        {"supset.dot","⪾",{priority=-9}},
        {"supset.double","⋑",{priority=-9}},
        {"supset.eq","⊇",{priority=-9}},
        {"supset.eq.not","⊉",{priority=-8}},
        {"supset.eq.sq","⊒",{priority=-8}},
        {"supset.eq.sq.not","⋣",{priority=-7}},
        {"supset.neq","⊋",{priority=-9}},
        {"supset.not","⊅",{priority=-9}},
        {"supset.sq","⊐",{priority=-9}},
        {"supset.sq.neq","⋥",{priority=-8}},
        {"tack.r","⊢",{priority=-9}},
        {"tack.r.not","⊬",{priority=-8}},
        {"tack.r.long","⟝",{priority=-8}},
        {"tack.r.short","⊦",{priority=-8}},
        {"tack.r.double","⊨",{priority=-8}},
        {"tack.r.double.not","⊭",{priority=-7}},
        {"tack.l","⊣",{priority=-9}},
        {"tack.l.long","⟞",{priority=-8}},
        {"tack.l.short","⫞",{priority=-8}},
        {"tack.l.double","⫤",{priority=-8}},
        {"tack.t","⊥",{priority=-9}},
        {"tack.t.big","⟘",{priority=-8}},
        {"tack.t.double","⫫",{priority=-8}},
        {"tack.t.short","⫠",{priority=-8}},
        {"tack.b","⊤",{priority=-9}},
        {"tack.b.big","⟙",{priority=-8}},
        {"tack.b.double","⫪",{priority=-8}},
        {"tack.b.short","⫟",{priority=-8}},
        {"tack.l.r","⟛",{priority=-8}},
        {"tau","τ",{priority=-10}},
        {"therefore","∴",{priority=-10}},
        {"theta","θ",{priority=-10}},
        {"theta.alt","ϑ",{priority=-9}},
        {"tilde.op","∼",{priority=-9}},
        {"tilde.basic","~",{priority=-9}},
        {"tilde.dot","⩪",{priority=-9}},
        {"tilde.eq","≃",{priority=-9}},
        {"tilde.eq.not","≄",{priority=-8}},
        {"tilde.eq.rev","⋍",{priority=-8}},
        {"tilde.equiv","≅",{priority=-9}},
        {"tilde.equiv.not","≇",{priority=-8}},
        {"tilde.nequiv","≆",{priority=-9}},
        {"tilde.not","≁",{priority=-9}},
        {"tilde.rev","∽",{priority=-9}},
        {"tilde.rev.equiv","≌",{priority=-8}},
        {"tilde.triple","≋",{priority=-9}},
        {"times","×",{priority=-10}},
        {"times.big","⨉",{priority=-9}},
        {"times.circle","⊗",{priority=-9}},
        {"times.circle.big","⨂",{priority=-8}},
        {"times.div","⋇",{priority=-9}},
        {"times.three.l","⋋",{priority=-8}},
        {"times.three.r","⋌",{priority=-8}},
        {"times.l","⋉",{priority=-9}},
        {"times.r","⋊",{priority=-9}},
        {"times.square","⊠",{priority=-9}},
        {"times.triangle","⨻",{priority=-9}},
        {"tiny","⧾",{priority=-10}},
        {"top","⊤",{priority=-10}},
        {"trademark","™",{priority=-10}},
        {"trademark.registered","®",{priority=-9}},
        {"trademark.service","℠",{priority=-9}},
        {"triangle.stroked.t","△",{priority=-8}},
        {"triangle.stroked.b","▽",{priority=-8}},
        {"triangle.stroked.r","▷",{priority=-8}},
        {"triangle.stroked.l","◁",{priority=-8}},
        {"triangle.stroked.bl","◺",{priority=-8}},
        {"triangle.stroked.br","◿",{priority=-8}},
        {"triangle.stroked.tl","◸",{priority=-8}},
        {"triangle.stroked.tr","◹",{priority=-8}},
        {"triangle.stroked.small.t","▵",{priority=-7}},
        {"triangle.stroked.small.b","▿",{priority=-7}},
        {"triangle.stroked.small.r","▹",{priority=-7}},
        {"triangle.stroked.small.l","◃",{priority=-7}},
        {"triangle.stroked.rounded","🛆",{priority=-8}},
        {"triangle.stroked.nested","⟁",{priority=-8}},
        {"triangle.stroked.dot","◬",{priority=-8}},
        {"triangle.filled.t","▲",{priority=-8}},
        {"triangle.filled.b","▼",{priority=-8}},
        {"triangle.filled.r","▶",{priority=-8}},
        {"triangle.filled.l","◀",{priority=-8}},
        {"triangle.filled.bl","◣",{priority=-8}},
        {"triangle.filled.br","◢",{priority=-8}},
        {"triangle.filled.tl","◤",{priority=-8}},
        {"triangle.filled.tr","◥",{priority=-8}},
        {"triangle.filled.small.t","▴",{priority=-7}},
        {"triangle.filled.small.b","▾",{priority=-7}},
        {"triangle.filled.small.r","▸",{priority=-7}},
        {"triangle.filled.small.l","◂",{priority=-7}},
        {"union","∪",{priority=-10}},
        {"union.arrow","⊌",{priority=-9}},
        {"union.big","⋃",{priority=-9}},
        {"union.dot","⊍",{priority=-9}},
        {"union.dot.big","⨃",{priority=-8}},
        {"union.double","⋓",{priority=-9}},
        {"union.minus","⩁",{priority=-9}},
        {"union.or","⩅",{priority=-9}},
        {"union.plus","⊎",{priority=-9}},
        {"union.plus.big","⨄",{priority=-8}},
        {"union.sq","⊔",{priority=-9}},
        {"union.sq.big","⨆",{priority=-8}},
        {"union.sq.double","⩏",{priority=-8}},
        {"upsilon","υ",{priority=-10}},
        {"without","∖",{priority=-10}},
        {"wj","wjoin",{priority=-10}},
        {"won","₩",{priority=-10}},
        {"wreath","≀",{priority=-10}},
        {"xi","ξ",{priority=-10}},
        {"xor","⊕",{priority=-10}},
        {"xor.big","⨁",{priority=-9}},
        {"yen","¥",{priority=-10}},
        {"zeta","ζ",{priority=-10}},
        -- {"zwj","zwj",{priority=-10}},
        -- {"zwnj","zwnj",{priority=-10}},
        -- {"zws","zwsp",{priority=-10}}
    }
    simpleSnip(arr, { hidden = false, wordTrig = true, condition = mathZone })
end
UnicodeSymbols()

return snippets, autosnippets
