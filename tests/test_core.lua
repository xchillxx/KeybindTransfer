-- Aufruf aus dem Addon-Ordner: lua tests/test_core.lua
local KBT = {}
assert(loadfile("Core.lua"))("KeybindTransfer", KBT)
local Core = KBT.Core

local failures = 0
local function check(name, cond)
    if cond then
        print("ok   " .. name)
    else
        print("FAIL " .. name)
        failures = failures + 1
    end
end

-- 1. Rundreise mit Sonderzeichen in Tasten und Befehlen
local entries = {
    { command = "ACTIONBUTTON1", keys = { "Q", "SHIFT-Q" } },
    { command = "ACTIONBUTTON2", keys = { "CTRL--" } },
    { command = "MULTIACTIONBAR1BUTTON3", keys = { "ALT-;", "BUTTON4" } },
    { command = "CLICK My Button:LeftButton", keys = { "%" } },
    { command = "TOGGLEBACKPACK", keys = {} },
}
local text = Core.Encode(entries, "interface 16001")
check("String ist einzeilig", not text:find("[\r\n]"))
check("String enthaelt keine Leerzeichen", not text:find("%s"))
local data = Core.Decode(text)
check("Decode liefert Daten", data ~= nil)
check("Meta bleibt erhalten", data and data.meta == "interface 16001")
check("Anzahl stimmt", data and #data.entries == #entries)
local same = data ~= nil
if data then
    for i, e in ipairs(entries) do
        local d = data.entries[i]
        if d.command ~= e.command or #d.keys ~= #e.keys then same = false break end
        for j, k in ipairs(e.keys) do
            if d.keys[j] ~= k then same = false end
        end
    end
end
check("Rundreise identisch", same)

-- 2. Whitespace beim Einfuegen (Zeilenumbruch, Leerzeichen) schadet nicht
local mangled = text:sub(1, 20) .. "\n  " .. text:sub(21)
check("Zeilenumbruch im String wird toleriert", Core.Decode(mangled) ~= nil)

-- 3. Fehlerfaelle
local _, e1 = Core.Decode("")
check("leer", e1 == "empty")
local _, e2 = Core.Decode("hallo welt")
check("falsches Format", e2 == "format")
local _, e3 = Core.Decode(text:sub(1, #text - 8))
check("abgeschnitten", e3 == "truncated" or e3 == "corrupt")
local _, e4 = Core.Decode("KBT1;x;abc")
check("kaputter Zaehler", e4 == "corrupt")

-- 4. Plan: bekannte/unbekannte Befehle und Konflikte
local known = { ACTIONBUTTON1 = true, ACTIONBUTTON2 = true, TOGGLEBACKPACK = true, OTHERCMD = true }
local bound = { Q = "OTHERCMD", ["CTRL--"] = "ACTIONBUTTON1" }
local plan = Core.BuildPlan(data.entries, known, function(k) return bound[k] end)
check("ok gezaehlt", plan.ok == 3)
check("unbekannt gezaehlt", plan.unknown == 2)
check("Tasten gezaehlt", plan.keys == 3)
check("Konflikt auf fremdem Befehl", plan.conflicts == 1)
check("ACTIONBUTTON1 auf CTRL-- ist kein Konflikt (wird neu gesetzt)", #plan.items[2].conflicts == 0)
check("Unbekannte Liste enthaelt Click-Befehl", plan.unknownList[2] == "CLICK My Button:LeftButton")

print(failures == 0 and "\nAlle Tests bestanden." or ("\n" .. failures .. " Test(s) fehlgeschlagen."))
os.exit(failures == 0 and 0 or 1)
