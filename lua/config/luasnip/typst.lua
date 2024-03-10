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

local function addSimpleSnip(alpha, defaultType, hide, con)
    if defaultType == nil or (defaultType ~= "a" and defaultType ~= "n") then
        defaultType = "n"
    end
    if hide == nil then
        hide = true
    end
    if con == nil then
        con = mathZone
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
        if isauto(v[3]) then
            addSnip = asnip
        else
            addSnip = snip
        end
        if type(v[2]) == "table" then
            addSnip(
                s({ trig = v[1], hidden = hide }, { t(v[2][1]) }, { condition = mathZone })
            )
            switchsnip(v[2])
        else
            addSnip(
                s({ trig = v[1], hidden = hide }, { t(v[2]) }, { condition = mathZone })
            )
        end
    end
end

-- --------------------------------测试--------------------------------
-- local test1 = s("t@hello", { t("hello world!") })
-- snip(test1)

--------------------------------环境--------------------------------
local function MathEnvironment()
    --数学环境
    asnip(
        s({ trig = ";;", wordTrig = false }, { t("$"), i(1), t(" $") }, { condition = plainText })
    )
    asnip(
        s({ trig = ";'", wordTrig = false }, { t("$  "), i(1), t("  $") }, { condition = plainText })
    )
    snip(
        s({ trig = "NoteTemplate" },{
            t{"#import(\"@local/NoteTemplate:0.1.0\"):*","",""},
            t{"#Note(",""},
            t("    headline:\""),i(1),t{"\",",""},
            t("    title:\""),i(2),t{"\",",""},
            t("    author:\""),i(3,"Entoryverkum"),t{"\",",""},
            t("    email:\""),i(4,"entoryvekum@outlook.com"),t{"\",",""},
            t("    time:\""),i(5,"2020"),t{"\",",""},
            t("    pagebreakBeforeOutline:false"),t{",",""},
            t(")["),i(6),t("]")
        })
    )
    snip(
        s({ trig = "template" },{
            t("#import(\"@local/"),i(1),t(":0.1.0\"):*")
        })
    )
    local alpha={"thrm","def","lemma","corol","example","caution","prop","idea"}
    for k, v in ipairs(alpha) do
        snip(
            s({trig="#"..v},{
                t("#"..v.."( name: ["),
                i(1),
                t("] )["),
                i(2),
                t("]")
            })
        )
    end
end
MathEnvironment()

--------------------------------符号--------------------------------
--普通符号
local function Symbols()
    local alpha = {
        { "oo", "∞" },
        { "qed", "∎" },
        { "rf", "∀" },
        { "cy", "∃" },
        { "∃n", "∄", "a" },
        { "alef", "א" },
        { "ks", "∅" },
        { "lap", "∆"},
        { "nab", "∇"},
        { "par","∂"},
        { "|m","mid(|)","a"}
    }
    addSimpleSnip(alpha, "n", false)
end
Symbols()

--积分
local function Integrals()
    local alpha = {
        { ";i", "∫" },
        { "∫i", "∬" },
        { "∬i", "∭" },
        { "∮i", "∯" },
        { "∯i", "∰" },
        { "∫o", "∮" },
        { "∬o", "∯" },
        { "∭o", "∰" },
    }
    addSimpleSnip(alpha, "a")
end
Integrals()

--希腊字母
local function GreekLetters()
    local alpha = {
        { "a", { "α", "Α" } },
        { "b", { "β", "Β" } },
        { "g", { "γ", "Γ" } },
        { "d", { "δ", "Δ" } },
        { "ep", { "ε", "Ε" } },
        { "z", { "ζ", "Ζ" } },
        { "et", { "η", "Η" } },
        { "th", { "θ", "Θ" } },
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
        { "ph", { "φ", "Φ" } },
        { "c", { "χ", "Χ" } },
        { "ps", { "ψ", "Ψ" } },
        { "og", { "ω", "Ω" } },
    }

    for k, v in ipairs(alpha) do
        asnip(s({ trig = "\\" .. v[1], hidden = true }, { t(v[2][1]) },
            { condition = mathZone }
        ))
        asnip(s(
            { trig = "\\" .. string.upper(string.sub(v[1], 1, 1)) .. string.sub(v[1], 2), hidden = true },
            { t(v[2][2]) }, { condition = mathZone }
        ))
        switchsnip({ v[2][1], v[2][2] })
    end
end
GreekLetters()

--大型运算符
local function BigOperators()
    local alpha1 = { "sum", "prod", "coprod", "plusc", "timec", "bcdot", "bcup", "bcupf", "bcupj", "bcap", "bcapf",
        "band", "bor" }
    local alpha2 = { "∑", "∏", "∐", "⨁", "⨂", "⨀", "⋃", "⨆", "⨄", "⋂", "⨅", "⋀", "⋁" }
    for j = 1, #alpha1 do
        snip(
            s({ trig = alpha1[j], hidden = true }, { t(alpha2[j] .. " _( "), i(1), t(" ) ^( "), i(2), t(" ) ") },
                { condition = mathZone })
        )
        snip(
            s({ trig = alpha1[j] .. " (%w+[^%s]*) (%w+[^%s]*) (%w+[^%s]*)", hidden = true, trigEngine = "pattern" }, {
                t(alpha2[j] .. " _( "),
                f(function(arg, snip, userArg) return snip.captures[1] end, {}, {}),
                t(" = "),
                f(function(arg, snip, userArg) return snip.captures[2] end, {}, {}),
                t(" ) ^( "),
                f(
                    function(args, snip, userArg)
                        if snip.captures[3] == 'inf' then
                            return "∞"
                        end
                        return snip.captures[3]
                    end
                    , {}, {}),
                t(" ) ")
            }, { condition = mathZone })
        )
        asnip(
            s({ trig = alpha1[j] .. ";(.)", hidden = true, trigEngine = "pattern" }, {
                t(alpha2[j] .. " _( "),
                f(function(arg, snip, userArg) return snip.captures[1] end, {}, {}),
                i(1),
                t(" ) ")
            }, { condition = mathZone })
        )
    end
end
BigOperators()

--运算符
local function Operators()
    local alpha = {
        { "aa", "+", "a" },
        { "tt", "×", "a" },
        { "×l", "⋉", "a" },
        { "×r", "⋊", "a" },
        { "+-", "±" },
        { "-+", "∓" },
        { "xx", "∗" },
        { "star", "⋆" },
        { "+o", "⊕", "a" },
        { "×o", "⊗", "a" },
        { "..", { "⋅", "•" } },
        { "⋅.", "⋯", "a" },
        { "cir", { "∘", "⚬" } },
        { "and", "∧" },
        { "or", "∨" },
        { "cup", { "∪", "⊔" } },
        { "cap", { "∩", "⨅" } },
        { "ni", "∖" },

        {"⋯v","⋮","a"},
        {"⋱v","⋮","a"},
        {"⋰v","⋮","a"},

        {"⋮h","⋯","a"},
        {"⋱h","⋯","a"},
        {"⋰h","⋯","a"},

        {"⋯d","⋱","a"},
        {"⋮d","⋱","a"},
        {"⋰d","⋱","a"},

        {"⋯u","⋰","a"},
        {"⋮u","⋰","a"},
        {"⋱u","⋰","a"},
    }
    addSimpleSnip(alpha, "n", false)
end
Operators()

--关系符
local function Relations()
    local alpha = {
        { "ee", { "=", "≡" }, "n" },
        { "ne", { "≠", "≢" }, "n" },

        { ".e", "≥" },
        { ">n", "≯" },
        { "≥n", "≱" },

        { ">t", "⊳" },
        { "⊳e", "⊵" },
        { "⊳n", "⋫" },
        { "⋫e", "⋭" },
        { "⊵n", "⋭" },

        { ">c", "≻" },
        { "≻e", "≽" },
        { "≻n", "⊁" },
        { "⊁n", "⋡" },
        { "≽n", "⋡" },

        { ",e", "≤" },
        { "<n", "≮" },
        { "≤n", "≰" },

        { "<t", "⊲" },
        { "⊲e", "⊴" },
        { "⊲n", "⋪" },
        { "⋪e", "⋬" },
        { "⊴n", "⋬" },

        { "<c", "≺" },
        { "≺e", "≼" },
        { "≺n", "⊀" },
        { "⊀c", "⋠" },
        { "≼n", "⋠" },

        { ">,", "<" },
        { "≥,", "≤" },
        { "≯,", "≮" },
        { "≱,", "≰" },
        { "⊳,", "⊲" },
        { "⊵,", "⊴" },
        { "⋫,", "⋪" },
        { "⋭,", "⋬" },
        { "≻,", "≺" },
        { "≽,", "≼" },
        { "⊁,", "⊀" },
        { "⋡,", "⋠" },

        { "<.", ">" },
        { "≤.", "≥" },
        { "≮.", "≯" },
        { "≰.", "≱" },
        { "⊲.", "⊳" },
        { "⊴.", "⊵" },
        { "⋪.", "⋫" },
        { "⋬.", "⋭" },
        { "≺.", "≻" },
        { "≼.", "≽" },
        { "⊀.", "⊁" },
        { "⋠.", "⋡" },

        { "sim", "〜", "n" },

        { "prop", "∝", "n" },

        { "vgiu", "∣", "n" },
        { "∣n", "∤" },

        { "in", "∈", "n" },
        { "∈n", "∉" },

        { "∋n", "∌" },

        { "∈,", "∋" },
        { "∉,", "∌" },
        { "∋.", "∈" },
        { "∌.", "∉" },

        { "join", "⨝", "n" },
        { "⨝,", "⟕" },
        { "⨝.", "⟖" },
        { "⟕r", "⟗" },
        { "⟖l", "⟗" },

        { "sub", "⊂", "n" },
        { "⊂n", "⊄" },
        { "⊂e", "⊆" },
        { "⊆n", { "⊊", "⊈" } },

        { "sup", "⊃", "n" },
        { "⊃n", "⊅" },
        { "⊃e", "⊇" },
        { "⊇n", { "⊋", "⊉" } },

        { "⊂,", "⊃" },
        { "⊄,", "⊅" },
        { "⊆,", "⊇" },
        { "⊊,", "⊋" },
        { "⊈,", "⊉" },

        { "⊃.", "⊂" },
        { "⊅.", "⊄" },
        { "⊇.", "⊆" },
        { "⊋.", "⊊" },
        { "⊉.", "⊈" },

        { ":=", "≔" },
        { "=def", "≝" },

    }
    addSimpleSnip(alpha, "a", false)
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

    asnip(
        s({ trig = "a;.", hidden = true }, { t("→") }, { condition = mathZone })
    )
    asnip(
        s({ trig = "a;,", hidden = true }, { t("←") }, { condition = mathZone })
    )
    asnip(
        s({ trig = "a..", hidden = true }, { t("⇒") }, { condition = mathZone })
    )
    asnip(
        s({ trig = "a,,", hidden = true }, { t("⇐") }, { condition = mathZone })
    )
    asnip(
        s({ trig = "a,.", hidden = true }, { t("⇔") }, { condition = mathZone })
    )
    snip(
        s({ trig = "map", hidden = false }, { t("↦") }, { condition = mathZone })
    )

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
                asnip(
                    s({ trig = alpha[j][1] .. miss, hidden = true }, { t(alpha[k][1]) }, { condition = mathZone })
                )
            end

            ::continue::
        end
    end
end
Arrows()

--------------------------------输入--------------------------------
--分数
local function Fraction()
    asnip(
        s({ trig = "//", hidden = true }, {
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t "( ", t(snip.env.SELECT_RAW), t " ) / ( ", i(1), t " ) " })
                    else
                        return sn(nil, { t "//" })
                    end
                end,
                {}, {}
            ),
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "/d", hidden = true }, { t("\\/  ") }, { condition = mathZone })
    )
end
Fraction()

--二项式系数
local function Binomial()
    snip(
        s({ trig = "bin", hidden = true }, { t("binom( "), i(1), t(" ) ") }, { condition = mathZone })
    )

    snip(
        s({ trig = "bin (%w+[^%s]*) ([^%s]*)%s*", regTrig = true, hidden = true }, {
            t("binom ( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            t(" , "),
            f(function(arg, snip, userArg) return snip.captures[2] end, {}),
            t(" ) ")
        }, { condition = mathZone })
    )
end
Binomial()

--括号
local function Brackets()
    asnip(
        s({ trig = "jj", wordTrig = false, hidden = true }, {
            t "( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "kk", wordTrig = false, hidden = true }, {
            t "[ ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ] "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "ll", wordTrig = false, hidden = true }, {
            t "{ ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " } "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "bb", hidden = true }, {
            t "⟨ ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ⟩ "
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = "kk;", hidden = true }, {
            t "⟦ ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ⟧ "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "abs", hidden = true }, {
            t "| ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " | "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "nrm", hidden = true }, {
            t "‖ ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ‖ "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "floor", hidden = true }, {
            t "floor( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    snip(
        s({ trig = "ceil", hidden = true }, {
            t "ceil( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
end
Brackets()

--文字
local function Texts()
    asnip(
        s({ trig = "s.t.", hidden = true }, { t("space.en \"s.t.\" space.en ") }, { condition = mathZone })
    )
    snip(
        s({ trig = "and", hidden = true }, { t("space.en \"and\" space.en ") }, { condition = mathZone })
    )
    snip(
        s({ trig = "ks", hidden = true }, { t("space.en ") }, { condition = mathZone })
    )
    snip(
        s({ trig = "iff", hidden = true }, { t("space.en \"iff\" space.en ") }, { condition = mathZone })
    )
    snip(
        s({ trig = "if", hidden = true }, { t("space.en \"if\" space.en ") }, { condition = mathZone })
    )
    snip(
        s({ trig = "or", hidden = true }, { t("space.en \"or\" space.en ") }, { condition = mathZone })
    )
end
Texts()

--极限
local function Limits()
    snip(
        s({ trig = "lim", hidden = true }, { t("lim _( "), i(1), i(2, " → "), i(3), t " )" },
            { condition = mathZone })
    )
    snip(
        s({ trig = "liminf", hidden = true }, { t("liminf _( "), i(1), i(2, " → "), i(3), t " )" },
            { condition = mathZone })
    )
    snip(
        s({ trig = "limsup", hidden = true }, { t("limsup _( "), i(1), i(2, " → "), i(3), t " )" },
            { condition = mathZone })
    )
    snip(
        s({ trig = "inf", hidden = true }, { t("inf _( "), i(1), t " )" }, { condition = mathZone })
    )
    snip(
        s({ trig = "sup", hidden = true }, { t("sup _( "), i(1), t " )" }, { condition = mathZone })
    )
end
Limits()

--根式
local function Root()
    snip(
        s({ trig = "sqrt", wordTrig = false, hidden = true }, {
            t "sqrt( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = "sqrt;([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("sqrt( "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), i(1), t(" ) ") },
            { condition = mathZone })
    )
    snip(
        s({ trig = "root", wordTrig = false, hidden = true }, {
            t "root( ",
            i(2),
            t " , ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = "root;([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("root( "), i(2), t(" , "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), i(1),
                t(" ) ") }, { condition = mathZone })
    )
end
Root()

--上下内容
local function UnderOverContent()
    local function addSnip(name, effect, key)
        if key == nil then
            key = ";"
        end
        snip(
            s({ trig = name, hidden = true, trigEngine = "pattern" }, {
                t(effect .. "( "),
                d(
                    1,
                    function(arg, snip, oldState, userArg)
                        if #snip.env.SELECT_RAW > 0 then
                            return sn(nil, { t(snip.env.SELECT_RAW) })
                        else
                            return sn(nil, { i(1) })
                        end
                    end,
                    {},{}
                ),
                t(" , "),
                i(2),
                t " ) "
            }, { condition = mathZone })
        )
        asnip(
            s({ trig = name .. key .. "(%w)", hidden = true, trigEngine = "pattern" }, {
                t(effect .. "( "),
                f(function(arg, snip, userArg) return snip.captures[1] end, {}),
                i(1),
                t(" , "),
                i(2),
                t " ) "
            }, { condition = mathZone })
        )
    end
    addSnip("ubc","overbrace",";")
    addSnip("dbc","underbrace",";")
    addSnip("ukc","overbracket",";")
    addSnip("dkc","underbracket",";")
end
UnderOverContent()

--序列
local function Sequence()
    snip(
        s({trig="seq (%w[^%s]*)%s+(%w[^%s]*)%s+(%w[^%s]*)",hidden=true,trigEngine="pattern"},{
            f(function(arg,snip,userArg) return snip.captures[1].."_( "..snip.captures[2].." ) , "..snip.captures[1].."_( " end,{}),
            f(
                function(arg,snip,userArg) 
                    if tonumber(snip.captures[2],10)==nil then
                        return snip.captures[2].."+1"
                    end
                    return tostring(snip.captures[2]+1)
                end
            ,{}),
            t(" ) , ⋯ "),
            f(
                function(arg,snip,userArg) 
                    if snip.captures[3]=="inf" then
                        return ""
                    end
                    return ", "..snip.captures[1].."_( "..snip.captures[3].." ) "
                end
            ,{}),
        },{condition=mathZone})
    )
    snip(
        s({trig="seq (%w[^%s]*)%s+(%w[^%s]*)%s+(%w[^%s]*)%s+([^%s]+)",hidden=true,trigEngine="pattern"},{
            f(function(arg,snip,userArg) return snip.captures[1].."_( "..snip.captures[2].." ) "..snip.captures[4].." "..snip.captures[1].."_( " end,{}),
            f(
                function(arg,snip,userArg) 
                    if tonumber(snip.captures[2],10)==nil then
                        return snip.captures[2].."+1"
                    end
                    return tostring(snip.captures[2]+1)
                end
            ,{}),
            f(function(arg,snip,userArg) return " ) "..snip.captures[4].." ⋯ " end,{}),
            f(
                function(arg,snip,userArg) 
                    if snip.captures[3]=="inf" then
                        return ""
                    end
                    return snip.captures[4].." "..snip.captures[1].."_( "..snip.captures[3].." ) "
                end
            ,{}),
        },{condition=mathZone})
    )
end
Sequence()

--求导
local function Differential()
    asnip(
        s({trig="[dp];(%w[^/%s]*)/",hidden=true,trigEngine="pattern"},{
            t"( ",
            f(
                function(arg,snip,userArg) 
                    if snip.captures[2]=="d" then
                        return "d "
                    else
                        return "∂ "
                    end
                end
            ,{}),
            f(function(arg,snip,userArg) return snip.captures[1] end,{}),
            t" )/( ",
            f(
                function(arg,snip,userArg) 
                    if snip.captures[2]=="d" then
                        return "d "
                    else
                        return "∂ "
                    end
                end
            ,{}),
            i(1),
            t" ) "
        },{condition=mathZone})
    )
    asnip(
        s({trig=";d",hidden=true},{t"( ",t"d ",i(1),t" )/( ",t"d ",i(2),t" )"},{condition=mathZone})
    )
    asnip(
        s({trig="/p",hidden=true},{t"( ",t"∂ ",i(1),t" )/( ",t"∂ ",i(2),t" )"},{condition=mathZone})
    )
    asnip(
        s({trig=".p",hidden=true},{t"∂ _( ",i(1),t" )"},{condition=mathZone})
    )
    switchsnip({"∂ _( ","∂ /( ∂ "})
end
Differential()

--------------------------------装饰--------------------------------
--字体
local function Fonts()
    asnip(
        s({ trig = ";b(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
            t("mbb(\""),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t("\") ")
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = ";f(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
            t("frak( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t(" ) ")
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = ";c(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
            t("cal( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t(" ) ")
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = ";s(%w)", wordTrig = false, hidden = true, trigEngine = "pattern" }, {
            t("scr( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t(" ) ")
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = ";v(%w)", wordTrig = false, regTrig = true, hidden = true }, {
            t("ubold( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t(" ) ")
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = ";i(%w)", wordTrig = false, regTrig = true, hidden = true }, {
            t("italic( "),
            f(function(arg, snip, userArg) return snip.captures[1] end, {}),
            i(1),
            t(" ) ")
        }, { condition = mathZone })
    )
end
Fonts()

--上下标
local function Attach()
    snip(
        s({ trig = "uu", wordTrig = false, hidden = true }, {
            t "^( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = "uu([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("^( "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), t(" ) ") }, {
                condition =
                    mathZone
            })
    )
    asnip(
        s({ trig = "uu ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("^( "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), i(1), t(" ) ") },
            { condition = mathZone })
    )
    snip(
        s({ trig = "dd", wordTrig = false, hidden = true }, {
            t "_( ",
            d(
                1,
                function(arg, snip, oldState, userArg)
                    if #snip.env.SELECT_RAW > 0 then
                        return sn(nil, { t(snip.env.SELECT_RAW) })
                    else
                        return sn(nil, { i(1) })
                    end
                end,
                {}, {}
            ),
            t " ) "
        }, { condition = mathZone })
    )
    asnip(
        s({ trig = "dd([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("_( "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), t(" ) ") }, {
                condition =
                    mathZone
            })
    )
    asnip(
        s({ trig = "dd ([^%s])", wordTrig = false, hidden = true, trigEngine = "pattern" },
            { t("_( "), f(function(arg, snip, userArg) return snip.captures[1] end, {}), i(1), t(" ) ") },
            { condition = mathZone })
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
        snip(
            s({ trig = name, hidden = true, trigEngine = "pattern" }, {
                t(effect .. "( "),
                d(
                    1,
                    function(arg, snip, oldState, userArg)
                        if #snip.env.SELECT_RAW > 0 then
                            return sn(nil, { t(snip.env.SELECT_RAW) })
                        else
                            return sn(nil, { i(1) })
                        end
                    end,
                    {},{}
                ),
                t " ) "
            }, { condition = mathZone })
        )
        asnip(
            s({ trig = name .. key .. "(%w)", hidden = true, trigEngine = "pattern" }, {
                t(effect .. "( "),
                f(function(arg, snip, userArg) return snip.captures[1] end, {}),
                i(1),
                t " ) "
            }, { condition = mathZone })
        )
    end
    local alpha = {
        { "u%.", "arrow",    "%." },
        { "u,",  "arrow.l",  "," },
        { "uw",  "tilde" },
        { "uj",  "hat" },
        { "uk",  "caron" },
        { "ud",  "dot" },
        { "ul",  "overline" },
        { "dl",  "underline" },
        { "vv",  "ubold" },
        { "uc", "circle" }
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
    generateCases=function()
        return sn(
            nil,{
                t{"",""},
                i(1),
                t"    #h(2em)&    ",
                i(2),
                d(3,
                    function (arg,snip,oldState,...)
                        local str=arg[1][1]
                        local len=string.len(str)
                        if string.sub(str,len,len)=="," then
                            return sn(nil,{d(1,generateCases,{})})
                        else
                            return sn(nil,{})
                        end
                    end,
                    {2}
                )
            }
        )
    end
    snip(
        s({trig="case",hidden=true},{
            t{"cases("},
            d(1,
                function (arg,snip,oldState,usaerArg)
                    return sn(nil,{d(1,generateCases,{})})
                end
            ),
            t{"",")"}
        },{condition=mathZone})
    )
end
Cases()

local function Matrix1()
    --SimpleMatrix
    local generateElm
    generateElm=function(arg0,snip0,oldState0,firstElm)
        return sn(
            nil,{
                t(({"    ",",  "})[firstElm]),
                i(1),
                d(2,
                    function (arg,snip,oldState,userArg)
                        local str=arg[1][1]
                        local len=string.len(str)
                        if len==0 or string.sub(str,len-2,len)==";//" then
                            return sn(nil,{})
                        elseif string.sub(str,len,len)==";" then
                            return sn(nil,{t{"",""},d(1,generateElm,{},{user_args={1}})})
                        else
                            return sn(nil,{d(1,generateElm,{},{user_args={2}})})
                        end
                    end,
                    {1}
                )
            }
        )
    end
    snip(
        s({trig="mat",hidden=true},{
            t{"mat(",""},
            d(1,
                function (arg,snip,oldState,userArg)
                    return sn(nil,{d(1,generateElm,{},{user_args={1}})})
                end
            ),
            t{"",")"}
        },{condition=mathZone})
    )
end
Matrix1()

return snippets, autosnippets
