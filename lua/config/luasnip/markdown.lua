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
local opt = require("luasnip.nodes.optional_arg")
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
local k = require("luasnip.nodes.key_indexer").new_key

local snippets, autosnippets = {}, {}

local function mathZone()
	return true
end

local function plainText()
	return true
end

local function snip(val)
	table.insert(snippets, val)
end

local function asnip(val)
	table.insert(autosnippets, val)
end

local function switchsnip(arr, con)
	if con == nil then
		con = mathZone
	end
	for j = 1, #arr do
		if j == #arr then
			snip(s({ trig = arr[j], hidden = true }, { t(arr[1]) }, { condition = con }))
		else
			snip(s({ trig = arr[j], hidden = true }, { t(arr[j + 1]) }, { condition = con }))
		end
	end
end

----------------测试----------------
-- local test1=s("t@hello",{t("hello world!")})
-- snip(test1)
-- local test2=s("t@auto",{t("auto")})
-- asnip(test2)
-- local test3=s({trig="t@[r][e][g]",regTrig=true},{t("reg")})
-- snip(test3)
-- local test4=s({trig="t@[r][e][g](auto)",regTrig=true},{t("reg-auto")})
-- asnip(test4)
-- local test5=s("t@choice",{c(1,{t("choice1"),t("choice2")})})
-- snip(test5)
-- local test6=s("t@select",{
--     f(
--         function(arg,snip,userArg)
--             return snip.env.SELECT_RAW
--         end
--     )
-- })
-- snip(test6)

----------------希腊字母----------------
local function GreekLetters()
	local alpha1 = {
		"a",
		"b",
		"g",
		"d",
		"ep",
		"z",
		"et",
		"th",
		"i",
		"k",
		"l",
		"m",
		"n",
		"omc",
		"x",
		"pi",
		"r",
		"s",
		"ta",
		"u",
		"ph",
		"c",
		"ps",
		"omg",
	}
	local alpha2 = {
		"alpha",
		"beta",
		"gamma",
		"delta",
		"varepsilon",
		"zeta",
		"eta",
		"theta",
		"iota",
		"kappa",
		"lambda",
		"mu",
		"nu",
		"omicron",
		"xi",
		"pi",
		"rho",
		"sigma",
		"tau",
		"upsilon",
		"varphi",
		"chi",
		"psi",
		"omega",
	}
	local alpha3 = {
		"Alpha",
		"Beta",
		"Gamma",
		"Delta",
		"Epsilon",
		"Zeta",
		"Eta",
		"Theta",
		"Iota",
		"Kappa",
		"Lambda",
		"Mu",
		"Nu",
		"Omicron",
		"Xi",
		"Pi",
		"Rho",
		"Sigma",
		"Tau",
		"Upsilon",
		"Phi",
		"Chi",
		"Psi",
		"Omega",
	}

	for j = 1, 24 do
		asnip(s({ trig = "'" .. alpha1[j], hidden = true }, { t("\\" .. alpha2[j] .. " ") }, { condition = mathZone }))
	end

	for j = 1, 24 do
		asnip(
			s(
				{ trig = "'" .. string.upper(string.sub(alpha1[j], 1, 1)) .. string.sub(alpha1[j], 2), hidden = true },
				{ t("\\" .. alpha3[j] .. " ") },
				{ condition = mathZone }
			)
		)
	end

	for j = 1, 24 do
		if alpha1[j] == "ep" then
			switchsnip({ "\\varepsilon ", "\\epsilon ", "\\Epsilon " })
		elseif alpha1[j] == "ph" then
			switchsnip({ "\\varphi ", "\\phi ", "\\Phi " })
		else
			switchsnip({ "\\" .. alpha2[j] .. " ", "\\" .. alpha3[j] .. " " })
		end
	end
end
GreekLetters()

----------------环境----------------
local function MathEnvironment()
	--数学环境
	asnip(s({ trig = ";'", wordTrig = false }, { t("$\\displaystyle { "), i(1), t(" }$") }))

	asnip(s({ trig = ";;;", wordTrig = false }, { t({ "$$", "" }), i(1), t({ "", "$$" }) }))

	--latex环境
	asnip(s({ trig = "\\begin", hidden = false }, {
		t("\\begin{"),
		i(1),
		t({ "}", "" }),
		i(2),
		t({ "", "\\end{" }),
		rep(1),
		t("}"),
	}))
end
MathEnvironment()

----------------运算----------------
--求和，求积
local function SumAndProduct()
	snip(
		s(
			{ trig = "sum", hidden = true },
			{ t("\\sum _{ "), i(1), t(" } ^{ "), i(2), t(" } ") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "prod", hidden = true },
			{ t("\\prod _{ "), i(1), t(" } ^{ "), i(2), t(" } ") },
			{ condition = mathZone }
		)
	)

	snip(s({ trig = "sum ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		t("\\sum _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" = "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" } ^{ "),
		f(function(args, snip, user_arg)
			if snip.captures[3] == "inf" then
				return "∞"
			end
			return snip.captures[3]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	snip(s({ trig = "prod ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		t("\\prod _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" = "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" } ^{ "),
		f(function(args, snip, userArg)
			if snip.captures[3] == "inf" then
				return "∞"
			end
			return snip.captures[3]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))

	snip(s({ trig = "sum ([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		t("\\sum _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	snip(s({ trig = "prod ([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		t("\\prod _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))

	asnip(s({ trig = "sum;([^%s])", regTrig = true, hidden = true }, {
		t("\\sum _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "prod;([^%s])", regTrig = true, hidden = true }, {
		t("\\prod _{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
end
SumAndProduct()

--二项式系数
local function Binomial()
	snip(
		s(
			{ trig = "bin", hidden = true },
			{ t("\\binom { "), i(1), t(" } { "), i(2), t(" } ") },
			{ condition = mathZone }
		)
	)

	snip(s({ trig = "bin ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*)%s*", regTrig = true, hidden = true }, {
		t("\\binom { "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" } { "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
end
Binomial()

--分数
local function Fraction()
	asnip(s({ trig = "//", hidden = true }, {
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t("\\frac { "), t(snip.env.SELECT_RAW), t(" } { "), i(1), t(" } ") })
			else
				return sn(nil, { t("//") })
			end
		end, {}),
	}, { condition = mathZone }))

	snip(
		s(
			{ trig = "//", hidden = true },
			{ t("\\frac { "), i(1), t(" } { "), i(2), t(" } ") },
			{ condition = mathZone }
		)
	)

	snip(s({ trig = "// ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*);", regTrig = true, hidden = true }, {
		t("\\frac { "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" } { "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))

	snip(s({ trig = "([^=%w]?%w+[^=%s]*)%s*/%s*([^%w]?%w+[^=%s]*);", regTrig = true, hidden = true }, {
		t("\\frac { "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		t(" } { "),
		f(function(arg, snip, userArg)
			return snip.captures[2]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
end
Fraction()

--求导
local function Differential()
	snip(s({ trig = "[dp];([^%w]?%w+[^%s]*) ([dp])%s*([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		t("\\frac{ "),
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
		t(" } { "),
		f(function(arg, snip, userArg)
			if snip.captures[2] == "d" then
				return "d "
			else
				return "∂ "
			end
		end, {}),
		f(function(arg, snip, userArg)
			return snip.captures[3]
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	snip(
		s(
			{ trig = "df", hidden = true },
			{ t("\\frac{ "), t("d "), i(1), t(" } { "), t("d "), i(2), t(" }") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "pf", hidden = true },
			{ t("\\frac{ "), t("∂ "), i(1), t(" } { "), t("∂ "), i(2), t(" }") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "po", hidden = true }, { t("∂ _{ "), i(1), t(" }") }, { condition = mathZone }))
	switchsnip({ "∂ _{ ", "\\frac{∂} { ∂ " })
	snip(s({ trig = "do", hidden = true }, { t("\\frac{d} { d "), i(1), t(" }") }, { condition = mathZone }))
end
Differential()

--极限
local function Limits()
	snip(
		s(
			{ trig = "lim", hidden = true },
			{ t("\\lim _{ "), i(1), i(2, " → "), i(3), t(" }") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "limd", hidden = true },
			{ t("\\varliminf _{ "), i(1), i(2, " → "), i(3), t(" }") },
			{ condition = mathZone }
		)
	)
	snip(
		s(
			{ trig = "limu", hidden = true },
			{ t("\\varlimsup _{ "), i(1), i(2, " → "), i(3), t(" }") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "inf", hidden = true }, { t("\\inf _{ "), i(1), t(" }") }, { condition = mathZone }))
	snip(s({ trig = "sup", hidden = true }, { t("\\sup _{ "), i(1), t(" }") }, { condition = mathZone }))
end
Limits()

--根式
local function Sqrt() end
Sqrt()

----------------对象----------------

--序列
local function Sequence()
	snip(s({ trig = "seq ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*)", regTrig = true, hidden = true }, {
		f(function(arg, snip, userArg)
			return snip.captures[1] .. "_{ " .. snip.captures[2] .. " } , " .. snip.captures[1] .. "_{ "
		end, {}),
		f(function(arg, snip, userArg)
			if tonumber(snip.captures[2], 10) == nil then
				return snip.captures[2] .. "+1"
			end
			return tostring(snip.captures[2] + 1)
		end, {}),
		t(" } , ⋯ "),
		f(function(arg, snip, userArg)
			if snip.captures[3] == "inf" then
				return ""
			end
			return ", " .. snip.captures[1] .. "_{ " .. snip.captures[3] .. " } "
		end, {}),
	}, { condition = mathZone }))
	snip(
		s(
			{
				trig = "seq ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*) ([^%w]?%w+[^%s]*) ([^%s]+)",
				regTrig = true,
				hidden = true,
			},
			{
				f(function(arg, snip, userArg)
					return snip.captures[1]
						.. "_{ "
						.. snip.captures[2]
						.. " } "
						.. snip.captures[4]
						.. " "
						.. snip.captures[1]
						.. "_{ "
				end, {}),
				f(function(arg, snip, userArg)
					if tonumber(snip.captures[2], 10) == nil then
						return snip.captures[2] .. "+1"
					end
					return tostring(snip.captures[2] + 1)
				end, {}),
				f(function(arg, snip, userArg)
					return " } " .. snip.captures[4] .. " ⋯ "
				end, {}),
				f(function(arg, snip, userArg)
					if snip.captures[3] == "inf" then
						return ""
					end
					return snip.captures[4] .. " " .. snip.captures[1] .. "_{ " .. snip.captures[3] .. " } "
				end, {}),
			},
			{ condition = mathZone }
		)
	)
end
Sequence()

--括号
local function Brackets()
	asnip(s({ trig = "jj", wordTrig = false, hidden = true }, {
		t("\\left( "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\right) "),
	}, { condition = mathZone }))
	asnip(s({ trig = "kk", wordTrig = false, hidden = true }, {
		t("\\left[ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\right] "),
	}, { condition = mathZone }))
	asnip(s({ trig = "lll", wordTrig = false, hidden = true }, {
		t("\\left\\{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\right\\} "),
	}, { condition = mathZone }))
	asnip(s({ trig = "bbb", hidden = true }, {
		t("\\braket{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	snip(s({ trig = "abs", hidden = true }, {
		t("\\left| "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\right| "),
	}, { condition = mathZone }))
	snip(s({ trig = "nrm", hidden = true }, {
		t("\\left\\| "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\right\\| "),
	}, { condition = mathZone }))
	snip(s({ trig = "floor", hidden = true }, {
		t("\\lfloor "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\rfloor "),
	}, { condition = mathZone }))
	snip(s({ trig = "ceil", hidden = true }, {
		t("\\lceil "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" \\rceil "),
	}, { condition = mathZone }))
end
Brackets()

--文字
local function Texts()
	asnip(s({ trig = "s.t.", hidden = true }, { t("\\enspace\\text{s.t.}\\enspace ") }, { condition = mathZone }))

	snip(s({ trig = "and", hidden = true }, { t("\\enspace\\text{and}\\enspace ") }, { condition = mathZone }))

	snip(s({ trig = "ks", hidden = true }, { t("\\enspace ") }, { condition = mathZone }))

	snip(s({ trig = "iff", hidden = true }, { t("\\enspace\\text{iff}\\enspace ") }, { condition = mathZone }))

	snip(s({ trig = "if", hidden = true }, { t("\\enspace\\text{if}\\enspace ") }, { condition = mathZone }))

	snip(s({ trig = "or", hidden = true }, { t("\\enspace\\text{or}\\enspace ") }, { condition = mathZone }))
end
Texts()

----------------修饰----------------

--字体
local function Fonts()
	asnip(s({ trig = ";b(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("\\mathbb{ "),
		f(function(arg, snip, userArg)
			return string.upper(snip.captures[1])
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "\\mathbb{%s*(%w*)", regTrig = true, hidden = true }, {
		t("\\mathbb{ "),
		f(function(arg, snip, userArg)
			return string.upper(snip.captures[1])
		end, {}),
	}, { condition = mathZone }))
	asnip(s({ trig = ";f(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("\\mathfrak{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";c(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("\\mathcal{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = ";s(%w)", wordTrig = false, regTrig = true, hidden = true }, {
		t("\\mathscr{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
end
Fonts()

--上下标
local function Footers()
	snip(s({ trig = "uu", wordTrig = false, hidden = true }, {
		t("^{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = "uu([^%s])", wordTrig = false, regTrig = true, hidden = true },
			{ t("^{ "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), t(" } ") },
			{ condition = mathZone }
		)
	)
	asnip(
		s(
			{ trig = "uu ([^%s])", wordTrig = false, regTrig = true, hidden = true },
			{ t("^{ "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), i(1), t(" } ") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "dd", wordTrig = false, hidden = true }, {
		t("_{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(
		s(
			{ trig = "dd([^%s])", wordTrig = false, regTrig = true, hidden = true },
			{ t("_{ "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), t(" } ") },
			{ condition = mathZone }
		)
	)
	asnip(
		s(
			{ trig = "dd ([^%s])", wordTrig = false, regTrig = true, hidden = true },
			{ t("_{ "), f(function(arg, snip, userArg)
				return snip.captures[1]
			end, {}), i(1), t(" } ") },
			{ condition = mathZone }
		)
	)
	snip(s({ trig = "txt", hidden = true }, {
		t("\\text{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s(
		{ trig = "txt ([^%s])", regTrig = true, hidden = true },
		{ t("\\text{ "), f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}), i(1), t(" } ") },
		{ condition = mathZone }
	))
end
Footers()

----------------符号----------------

--运算符
local function Operator()
	asnip(s({ trig = "aa", hidden = true }, { t("+ ") }, { condition = mathZone }))
	switchsnip({ "+ ", "⊕ " })

	snip(s({ trig = "a-", hidden = true }, { t("± ") }, { condition = mathZone }))
	switchsnip({ "± ", "∓ " })

	asnip(s({ trig = "tt", hidden = true }, { t("× ") }, { condition = mathZone }))
	switchsnip({ "× ", "⊗ " })

	snip(s({ trig = "cir", hidden = true }, { t("∘ ") }, { condition = mathZone }))
	switchsnip({ "∘ ", "∙ " })

	asnip(s({ trig = ";p", hidden = true }, { t("∂ ") }, { condition = mathZone }))

	snip(s({ trig = "ee", hidden = true }, { t("= ") }, { condition = mathZone }))
	snip(s({ trig = "se", hidden = true }, { t("≅ ") }, { condition = mathZone }))
	switchsnip({ "≅ ", "≆ " })
	snip(s({ trig = "me", hidden = true }, { t("≡ ") }, { condition = mathZone }))
	asnip(s({ trig = ",e", wordTrig = false, hidden = true }, { t("≤ ") }, { condition = mathZone }))
	asnip(s({ trig = ".e", wordTrig = false, hidden = true }, { t("≥ ") }, { condition = mathZone }))
	asnip(s({ trig = ";e", hidden = true }, { t("≠ ") }, { condition = mathZone }))
	snip(s({ trig = "sim", hidden = true }, { t("∼ ") }, { condition = mathZone }))
	snip(s({ trig = "~", hidden = true }, { t("∼ ") }, { condition = mathZone }))

	asnip(s({ trig = ";.", wordTrig = false, hidden = true }, { t("⋅ ") }, { condition = mathZone }))
	asnip(s({ trig = "⋅ .", wordTrig = false, hidden = true }, { t("⋯ ") }, { condition = mathZone }))
	switchsnip({ "⋅ ", "⊙ " })

	snip(s({ trig = "|", hidden = true }, { t("∣ ") }, { condition = mathZone }))
	switchsnip({ "∣ ", "∤ " })
end
Operator()

--符号
local function Symbol()
	asnip(s({ trig = "inft", hidden = true }, { t("∞ ") }, { condition = mathZone }))

	asnip(s({ trig = "alef", hidden = true }, { t("ℵ ") }, { condition = mathZone }))

	snip(s({ trig = "empty", hidden = true }, { t("\\varnothing ") }, { condition = mathZone }))

	snip(s({ trig = "rf", hidden = true }, { t("∀ ") }, { condition = mathZone }))

	snip(s({ trig = "cy", hidden = true }, { t("∃ ") }, { condition = mathZone }))
	switchsnip({ "∃ ", "\\nexists " })

	snip(s({ trig = "yb", hidden = true }, { t("∵ ") }, { condition = mathZone }))

	snip(s({ trig = "so", hidden = true }, { t("∴ ") }, { condition = mathZone }))

	snip(s({ trig = "box", hidden = true }, { t("\\square ") }, { condition = mathZone }))
	switchsnip({ "\\square ", "\\blacksquare " })

	snip(s({ trig = "trg", hidden = true }, { t("\\triangle ") }, { condition = mathZone }))
	snip(s({ trig = "trgd", hidden = true }, { t("\\triangledown ") }, { condition = mathZone }))

	asnip(s({ trig = "hd,", hidden = true }, { t("\\lhd ") }, { condition = mathZone }))
	switchsnip({ "\\lhd ", "\\ntriangleleft " })
	asnip(s({ trig = "hd.", hidden = true }, { t("\\rhd ") }, { condition = mathZone }))
	switchsnip({ "\\rhd ", "\\ntriangleright " })
	asnip(s({ trig = "\\lhd ,", hidden = true }, { t("\\unlhd ") }, { condition = mathZone }))
	switchsnip({ "\\unlhd ", "\\ntrianglelefteq " })
	asnip(s({ trig = "\\rhd .", hidden = true }, { t("\\unrhd ") }, { condition = mathZone }))
	switchsnip({ "\\unrhd ", "\\ntrianglerighteq " })
end
Symbol()

--集合
local function SetOperators()
	snip(s({ trig = "in", hidden = true }, { t("∈ ") }, { condition = mathZone }))
	switchsnip({ "∈ ", "∋ " })

	snip(s({ trig = "ni", hidden = true }, { t("∉ ") }, { condition = mathZone }))
	switchsnip({ "∉ ", "∌ " })

	snip(s({ trig = "st-", hidden = true }, { t("∖ ") }, { condition = mathZone }))

	snip(s({ trig = "stu", hidden = true }, { t("∪ ") }, { condition = mathZone }))
	switchsnip({ "∪ ", "⋃ " })

	snip(s({ trig = "stun", hidden = true }, { t("⊔ ") }, { condition = mathZone }))
	switchsnip({ "⊔ ", "⨆ " })

	snip(s({ trig = "stn", hidden = true }, { t("∩ ") }, { condition = mathZone }))
	switchsnip({ "∩ ", "⋂ ", "⊓ " })

	snip(s({ trig = "sub", hidden = true }, { t("⊂ ") }, { condition = mathZone }))
	switchsnip({ "⊂ ", "⊆ " })

	snip(s({ trig = "sup", hidden = true }, { t("⊃ ") }, { condition = mathZone }))
	switchsnip({ "⊃ ", "⊇ " })

	snip(s({ trig = "nsub", hidden = true }, { t("⊈ ") }, { condition = mathZone }))
	switchsnip({ "⊈ ", "⊊ " })

	snip(s({ trig = "nsup", hidden = true }, { t("⊉ ") }, { condition = mathZone }))
	switchsnip({ "⊉ ", "⊋ " })
end
SetOperators()

--箭头
local function Arrows()
	asnip(s({ trig = "a..", hidden = true }, { t("⇒ ") }, { condition = mathZone }))
	switchsnip({ "→ ", "⇒ " })

	asnip(s({ trig = "a,,", hidden = true }, { t("⇐ ") }, { condition = mathZone }))
	switchsnip({ "← ", "⇐ " })

	asnip(s({ trig = "a,.", hidden = true }, { t("⇔ ") }, { condition = mathZone }))
	switchsnip({ "⇔ ", "↔ " })

	snip(s({ trig = "map", hidden = true }, { t("\\mapsto ") }, { condition = mathZone }))

	asnip(s({ trig = "→ .c", hidden = true }, { t("↷ ") }, { condition = mathZone }))

	asnip(s({ trig = "← ,c", hidden = true }, { t("↶ ") }, { condition = mathZone }))
end
Arrows()

--Hat
-- uv 右箭头-快捷输入
-- vv 粗体向量-快捷输入
-- u. 右箭头 .快捷输入
-- u, 左箭头 ,快捷输入
-- uw dw 上下波浪线 ;快捷输入
-- uj uk 向上向下折线 ;快捷输入
-- ul dl 上下横线 ;快捷输入
-- ub db 上下大括号 ;快捷输入
-- ud 上点 ;快捷输入
local function Hats()
	--右箭头
	snip(
		s(
			{ trig = "uv %w", regTrig = true, hidden = true },
			{ t("\\overrightharpoon{ "), i(1), t(" }") },
			{ condition = mathZone }
		)
	)
	asnip(s({ trig = "vv (%w)", regTrig = true, hidden = true }, {
		t("\\boldsymbol{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } "),
	}, { condition = mathZone }))
	snip(s({ trig = "u.", hidden = true }, {
		t("\\overrightharpoon{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	switchsnip({ "\\overrightharpoon{ ", "\\overrightarrow{ " })
	asnip(s({ trig = "u%.%.(%w)", regTrig = true, hidden = true }, {
		t("\\overrightharpoon{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--左箭头
	snip(s({ trig = "u,", hidden = true }, {
		t("\\overleftarrow{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	switchsnip({ "\\overleftarrow{ ", "\\overleftharpoon{ " })
	asnip(s({ trig = "u,,(%w)", regTrig = true, hidden = true }, {
		t("\\overleftarrow{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--上波浪线
	snip(s({ trig = "uw", hidden = true }, {
		t("\\widetilde{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "uw;(%w)", regTrig = true, hidden = true }, {
		t("\\widetilde{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--下波浪线
	snip(s({ trig = "dw", hidden = true }, {
		t("\\utilde{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "dw;(%w)", regTrig = true, hidden = true }, {
		t("\\utilde{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--下折线
	snip(s({ trig = "uj", hidden = true }, {
		t("\\widecheck{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "uj;(%w)", regTrig = true, hidden = true }, {
		t("\\widecheck{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--上折线
	snip(s({ trig = "uk", hidden = true }, {
		t("\\widehat{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "uk;(%w)", regTrig = true, hidden = true }, {
		t("\\widehat{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--上下折线切换
	switchsnip({ "\\widecheck{ ", "\\widehat{ " })

	--上横线
	snip(s({ trig = "ul", hidden = true }, {
		t("\\overline{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "ul;(%w)", regTrig = true, hidden = true }, {
		t("\\overline{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--下横线
	snip(s({ trig = "dl", hidden = true }, {
		t("\\underline{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "dl;(%w)", regTrig = true, hidden = true }, {
		t("\\underline{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))

	--下大括号
	snip(s({ trig = "ub", hidden = true }, {
		t("\\overbrace{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } ^{ "),
		i(2),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "ub;(%w)", regTrig = true, hidden = true }, {
		t("\\overbrace{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } _{ "),
		i(2),
		t(" } "),
	}, { condition = mathZone }))

	--上大括号
	snip(s({ trig = "db", hidden = true }, {
		t("\\underbrace{ "),
		d(1, function(arg, snip, oldState, ...)
			if #snip.env.SELECT_RAW > 0 then
				return sn(nil, { t(snip.env.SELECT_RAW) })
			else
				return sn(nil, { i(1) })
			end
		end, {}),
		t(" } ^{ "),
		i(2),
		t(" } "),
	}, { condition = mathZone }))
	asnip(s({ trig = "db;(%w)", regTrig = true, hidden = true }, {
		t("\\underbrace{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" } ^{ "),
		i(2),
		t(" } "),
	}, { condition = mathZone }))

	--点
	snip(s({ trig = "ud", hidden = true }, { t("\\.{ "), i(1), t(" }") }, { condition = mathZone }))
	asnip(s({ trig = "ud;(%w)", regTrig = true, hidden = true }, {
		t("\\.{ "),
		f(function(arg, snip, userArg)
			return snip.captures[1]
		end, {}),
		i(1),
		t(" }"),
	}, { condition = mathZone }))
	asnip(s({ trig = "\\.{ .", hidden = true }, { t('\\"{ '), i(1) }, { condition = mathZone }))
	switchsnip({ "\\.{ ", "\\r{ " })
end
Hats()

--积分
local function Integral()
	asnip(s({ trig = ";i", hidden = true }, { t("∫") }, { condition = mathZone }))
	asnip(s({ trig = "∫i", hidden = true }, { t("∬") }, { condition = mathZone }))
	asnip(s({ trig = "∬i", hidden = true }, { t("∭") }, { condition = mathZone }))
	asnip(s({ trig = "∮i", hidden = true }, { t("∯") }, { condition = mathZone }))
	asnip(s({ trig = "∯i", hidden = true }, { t("∰") }, { condition = mathZone }))
	asnip(s({ trig = "∫o", hidden = true }, { t("∮") }, { condition = mathZone }))
	asnip(s({ trig = "∬o", hidden = true }, { t("∯") }, { condition = mathZone }))
	asnip(s({ trig = "∭o", hidden = true }, { t("∰") }, { condition = mathZone }))
end
Integral()

----------------表----------------
local function Cases()
	--Cases
	local generateCases
	generateCases = function()
		return sn(nil, {
			t({ "", "" }),
			i(1),
			t("    &    "),
			i(2),
			d(3, function(arg, snip, oldState, ...)
				local str = arg[1][1]
				local len = string.len(str)
				if string.sub(str, len - 1, len) == "\\\\" then
					return sn(nil, { d(1, generateCases, {}) })
				else
					return sn(nil, {})
				end
			end, { 2 }),
		})
	end
	snip(s({ trig = "case", hidden = true }, {
		t({ "\\begin{cases}" }),
		d(1, function(arg, snip, oldState, ...)
			return sn(nil, { d(1, generateCases, {}) })
		end),
		t({ "", "\\end{cases}" }),
	}, { condition = mathZone }))
end
Cases()

local function Matrix1()
	--SimpleMatrix
	local generateElm
	generateElm = function()
		return sn(nil, {
			t({ "  " }),
			i(1),
			d(2, function(arg, snip, oldState)
				local str = arg[1][1]
				local len = string.len(str)
				if string.sub(str, len, len) == "&" then
					return sn(nil, { d(1, generateElm, {}) })
				elseif string.sub(str, len - 1, len) == "\\\\" then
					return sn(nil, { t({ "", "" }), d(1, generateElm, {}) })
				else
					return sn(nil, {})
				end
			end, { 1 }),
		})
	end
	snip(s({ trig = "mat", hidden = true }, {
		t({ "\\begin{matrix}", "" }),
		d(1, function(arg, snip, oldState)
			return sn(nil, { d(1, generateElm, {}) })
		end),
		t({ "", "\\end{matrix}" }),
	}, { condition = mathZone }))
end
Matrix1()

return snippets, autosnippets

