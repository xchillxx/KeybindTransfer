-- KeybindTransfer: reine Logik (Kodierung, Parsing, Plan). Kein WoW-API-Aufruf hier,
-- damit sich alles ausserhalb des Spiels testen laesst.
local _, KBT = ...
KBT = KBT or {}
local Core = {}
KBT.Core = Core

Core.FORMAT = "KBT1"

local function esc(s)
    return (tostring(s):gsub("[^%w_%-]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function unesc(s)
    return (s:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

local function split(s, sep)
    local out, i = {}, 1
    while true do
        local j = string.find(s, sep, i, true)
        if not j then
            out[#out + 1] = string.sub(s, i)
            break
        end
        out[#out + 1] = string.sub(s, i, j - 1)
        i = j + #sep
    end
    return out
end

-- entries: { {command = "ACTIONBUTTON1", keys = {"Q", "SHIFT-Q"}}, ... }
-- Format: KBT1;<meta>;<anzahl>;<befehl>:<taste>:<taste>;...;END
-- Alle Sonderzeichen werden als %XX kodiert, der String ist also einzeilig und
-- ueberlebt Chat, Discord und Notepad.
function Core.Encode(entries, meta)
    local parts = { Core.FORMAT, esc(meta or ""), tostring(#entries) }
    for _, e in ipairs(entries) do
        local p = { esc(e.command) }
        for _, k in ipairs(e.keys) do
            p[#p + 1] = esc(k)
        end
        parts[#parts + 1] = table.concat(p, ":")
    end
    parts[#parts + 1] = "END"
    return table.concat(parts, ";")
end

-- Gibt { meta = ..., entries = ... } zurueck oder nil, fehlercode
-- Fehlercodes: "empty", "format", "corrupt", "truncated"
function Core.Decode(text)
    if type(text) ~= "string" then return nil, "empty" end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "empty" end

    local parts = split(text, ";")
    if parts[1] ~= Core.FORMAT then return nil, "format" end
    local count = tonumber(parts[3])
    if not count then return nil, "corrupt" end

    if parts[#parts] ~= "END" then return nil, "truncated" end

    local entries = {}
    for i = 4, #parts - 1 do
        if parts[i] ~= "" then
            local f = split(parts[i], ":")
            local command = unesc(f[1])
            if command == "" then return nil, "corrupt" end
            local keys = {}
            for j = 2, #f do
                if f[j] ~= "" then keys[#keys + 1] = unesc(f[j]) end
            end
            entries[#entries + 1] = { command = command, keys = keys }
        end
    end
    if #entries ~= count then return nil, "truncated" end
    return { meta = unesc(parts[2] or ""), entries = entries }
end

-- known:    Set { [befehl] = true } aller Befehle, die das Ziel kennt
-- actionOf: function(taste) -> befehl, der aktuell auf der Taste liegt (oder nil)
function Core.BuildPlan(entries, known, actionOf)
    local imported = {}
    for _, e in ipairs(entries) do imported[e.command] = true end

    local plan = { items = {}, ok = 0, unknown = 0, conflicts = 0, keys = 0, unknownList = {} }
    for _, e in ipairs(entries) do
        local item = { command = e.command, keys = e.keys, conflicts = {} }
        if known[e.command] then
            item.status = "ok"
            plan.ok = plan.ok + 1
            plan.keys = plan.keys + #e.keys
            for _, k in ipairs(e.keys) do
                local cur = actionOf(k)
                -- Konflikt nur, wenn die Taste einem Befehl gehoert, der NICHT ebenfalls
                -- im Import steckt (sonst wird er ohnehin neu gesetzt).
                if cur and cur ~= "" and cur ~= e.command and not imported[cur] then
                    item.conflicts[#item.conflicts + 1] = { key = k, command = cur }
                    plan.conflicts = plan.conflicts + 1
                end
            end
        else
            item.status = "unknown"
            plan.unknown = plan.unknown + 1
            plan.unknownList[#plan.unknownList + 1] = e.command
        end
        plan.items[#plan.items + 1] = item
    end
    return plan
end
