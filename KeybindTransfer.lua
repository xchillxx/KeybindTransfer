-- KeybindTransfer: Oberflaeche und Anbindung an die WoW-API.
-- Kopiert NUR Tastenbelegungen (Befehl -> Taste), keine Zauber, Makros oder Leisten.
local _, KBT = ...
local Core = KBT.Core

local isDE = GetLocale() == "deDE"
local S
if isDE then
    S = {
        title = "KeybindTransfer",
        export = "Exportieren",
        preview = "Vorschau",
        apply = "Anwenden",
        undo = "Rückgängig",
        combat = "Im Kampf nicht möglich.",
        empty = "Das Textfeld ist leer. Füge zuerst einen Export-String ein.",
        format = "Das ist kein KeybindTransfer-String.",
        corrupt = "Der String ist beschädigt.",
        truncated = "Der String ist unvollständig kopiert worden.",
        exported = "Export fertig: %d Befehle mit Tasten. Mit Strg+C kopieren und im anderen Spiel einfügen.",
        previewText = "Quelle: %s\n%d Befehle übertragbar (%d Tasten).\n%d im Ziel unbekannt (werden übersprungen).\n%d Tasten überschreiben eine bestehende Belegung.",
        unknownList = "Übersprungen: %s",
        applied = "Fertig: %d Tasten gesetzt, %d fehlgeschlagen. Mit \"Rückgängig\" kannst du zurück.",
        noPlan = "Erst auf \"Vorschau\" klicken.",
        nothingToUndo = "Es gibt kein Backup.",
        undone = "Zurückgesetzt auf den Stand vor dem letzten Import.",
        hint = "Export: Button klicken, Text kopieren. Import: Text einfügen, Vorschau, Anwenden.",
    }
else
    S = {
        title = "KeybindTransfer",
        export = "Export",
        preview = "Preview",
        apply = "Apply",
        undo = "Undo",
        combat = "Not possible in combat.",
        empty = "The text box is empty. Paste an export string first.",
        format = "That is not a KeybindTransfer string.",
        corrupt = "The string is damaged.",
        truncated = "The string was copied incompletely.",
        exported = "Export done: %d commands with keys. Copy with Ctrl+C and paste it in the other game.",
        previewText = "Source: %s\n%d commands can be transferred (%d keys).\n%d unknown in this client (skipped).\n%d keys will overwrite an existing binding.",
        unknownList = "Skipped: %s",
        applied = "Done: %d keys set, %d failed. Use Undo to go back.",
        noPlan = "Click Preview first.",
        nothingToUndo = "There is no backup.",
        undone = "Restored the state before the last import.",
        hint = "Export: click the button, copy the text. Import: paste text, Preview, Apply.",
    }
end

local function say(msg)
    print("|cff33ccffKeybindTransfer:|r " .. msg)
end

local function ensureDB()
    KeybindTransferDB = KeybindTransferDB or {}
    KeybindTransferDB.backups = KeybindTransferDB.backups or {}
    return KeybindTransferDB
end

-- Liest alle Bindings des aktuellen Clients.
-- Rueckgabe: entries (nur Befehle MIT Tasten oder alle, je nach includeEmpty), known (Set aller Befehle)
local function snapshot(includeEmpty)
    local entries, known = {}, {}
    for i = 1, GetNumBindings() do
        local t = { GetBinding(i) }
        local command = t[1]
        if type(command) == "string" and command ~= "" and not command:find("^HEADER") then
            known[command] = true
            local keys = {}
            for j = 3, 12 do
                if type(t[j]) == "string" and t[j] ~= "" then
                    keys[#keys + 1] = t[j]
                else
                    break
                end
            end
            if includeEmpty or #keys > 0 then
                entries[#entries + 1] = { command = command, keys = keys }
            end
        end
    end
    return entries, known
end

local function meta()
    local _, _, _, iface = GetBuildInfo()
    return "interface " .. tostring(iface)
end

-- Zwei Phasen: erst alle Tasten der betroffenen Befehle loesen, dann neu setzen.
-- Sonst loest das Aufraeumen eines spaeteren Befehls eine gerade gesetzte Taste wieder.
local function applyEntries(entries, known)
    local current = snapshot(true)
    local currentKeys = {}
    for _, e in ipairs(current) do currentKeys[e.command] = e.keys end

    for _, e in ipairs(entries) do
        if known[e.command] then
            for _, k in ipairs(currentKeys[e.command] or {}) do
                SetBinding(k, nil)
            end
        end
    end

    local ok, failed = 0, 0
    for _, e in ipairs(entries) do
        if known[e.command] then
            for _, k in ipairs(e.keys) do
                if SetBinding(k, e.command) then
                    ok = ok + 1
                else
                    failed = failed + 1
                end
            end
        end
    end

    local set = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    if not set or set < 1 then set = 1 end
    SaveBindings(set)
    return ok, failed
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local frame, scroll, info, btnApply
local currentPlan

local function buildFrame()
    frame = CreateFrame("Frame", "KeybindTransferFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(540, 400)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "KeybindTransferFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -6)
    title:SetText(S.title)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -30)
    hint:SetWidth(508)
    hint:SetJustifyH("LEFT")
    hint:SetText(S.hint)

    scroll = CreateFrame("ScrollFrame", "KeybindTransferScroll", frame, "InputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -52)
    scroll:SetSize(508, 170)
    scroll.EditBox:SetWidth(488)
    scroll.EditBox:SetFontObject(ChatFontNormal)
    scroll.EditBox:SetMaxLetters(0)
    if scroll.CharCount then scroll.CharCount:Hide() end
    scroll.EditBox:SetScript("OnTextChanged", function()
        currentPlan = nil
        if btnApply then btnApply:Disable() end
    end)

    info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 16, -232)
    info:SetWidth(508)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")

    local function button(text, x)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(120, 24)
        b:SetText(text)
        b:SetPoint("BOTTOMLEFT", x, 14)
        return b
    end

    local btnExport = button(S.export, 14)
    local btnPreview = button(S.preview, 144)
    btnApply = button(S.apply, 274)
    local btnUndo = button(S.undo, 404)
    btnApply:Disable()

    btnExport:SetScript("OnClick", function() KBT:DoExport() end)
    btnPreview:SetScript("OnClick", function() KBT:DoPreview() end)
    btnApply:SetScript("OnClick", function() KBT:DoApply() end)
    btnUndo:SetScript("OnClick", function() KBT:DoUndo() end)
end

local function show()
    if not frame then buildFrame() end
    frame:Show()
end

function KBT:DoExport()
    show()
    local entries = snapshot(false)
    scroll.EditBox:SetText(Core.Encode(entries, meta()))
    currentPlan = nil
    btnApply:Disable()
    scroll.EditBox:SetFocus()
    scroll.EditBox:HighlightText()
    info:SetText(string.format(S.exported, #entries))
end

function KBT:DoPreview()
    show()
    local data, err = Core.Decode(scroll.EditBox:GetText())
    if not data then
        info:SetText(S[err] or S.corrupt)
        currentPlan = nil
        btnApply:Disable()
        return
    end
    local _, known = snapshot(true)
    local plan = Core.BuildPlan(data.entries, known, function(key)
        local action = GetBindingAction(key, true)
        if action == "" then return nil end
        return action
    end)
    plan.entries = data.entries
    plan.known = known
    currentPlan = plan
    local text = string.format(S.previewText, data.meta ~= "" and data.meta or "?", plan.ok, plan.keys, plan.unknown, plan.conflicts)
    if plan.unknown > 0 then
        local list = {}
        for i = 1, math.min(10, #plan.unknownList) do list[#list + 1] = plan.unknownList[i] end
        text = text .. "\n" .. string.format(S.unknownList, table.concat(list, ", ") .. (plan.unknown > 10 and ", ..." or ""))
    end
    info:SetText(text)
    if plan.ok > 0 then btnApply:Enable() else btnApply:Disable() end
end

function KBT:DoApply()
    if not currentPlan then info:SetText(S.noPlan) return end
    if InCombatLockdown() then info:SetText(S.combat) return end
    local db = ensureDB()
    local backup = snapshot(true)
    table.insert(db.backups, 1, { time = time(), entries = backup })
    while #db.backups > 5 do table.remove(db.backups) end

    local ok, failed = applyEntries(currentPlan.entries, currentPlan.known)
    info:SetText(string.format(S.applied, ok, failed))
    say(string.format(S.applied, ok, failed))
    currentPlan = nil
    btnApply:Disable()
end

function KBT:DoUndo()
    show()
    if InCombatLockdown() then info:SetText(S.combat) return end
    local db = ensureDB()
    local backup = table.remove(db.backups, 1)
    if not backup then info:SetText(S.nothingToUndo) return end
    local _, known = snapshot(true)
    applyEntries(backup.entries, known)
    info:SetText(S.undone)
    say(S.undone)
end

---------------------------------------------------------------------------
-- Slash-Befehle und Start
---------------------------------------------------------------------------
SLASH_KEYBINDTRANSFER1 = "/kbt"
SLASH_KEYBINDTRANSFER2 = "/keybindtransfer"
SlashCmdList["KEYBINDTRANSFER"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "export" then
        KBT:DoExport()
    elseif msg == "undo" then
        KBT:DoUndo()
    elseif msg == "import" then
        show()
        scroll.EditBox:SetText("")
        scroll.EditBox:SetFocus()
    else
        if frame and frame:IsShown() then frame:Hide() else show() end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name == "KeybindTransfer" then
        ensureDB()
        loader:UnregisterEvent("ADDON_LOADED")
    end
end)
