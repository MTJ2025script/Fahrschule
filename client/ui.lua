-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- NUI bridge for mtj_fahrschule (handles NUI callbacks, SendNUIMessage wrappers, server<->NUI handshake)
-- Exports: OpenPracticeUI, ShowPracticeResultDirect, cleanupPracticeVehicle

local RESOURCE = (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'

local nuiOpen = false
local uiSuppressUntil = 0
local queuedPayload = nil
local lastLicenseCategory = nil -- für Foto-Save
local lastBookingState = { token = nil, category = nil } -- für Theorie-Submit

local function nowMs()
    if type(GetGameTimer) == 'function' then
        local ok, t = pcall(GetGameTimer)
        if ok and type(t) == 'number' then return math.floor(t) end
    end
    if type(os) == 'table' and type(os.time) == 'function' then return os.time() * 1000 end
    return 0
end

local function dbg(...)
    local t = {}
    for i = 1, select('#', ...) do t[#t+1] = tostring(select(i, ...)) end
    print(('[%s][client/ui] %s'):format(RESOURCE, table.concat(t, ' ')))
end

local function safeSetNuiFocus(focus, cursor)
    pcall(function() SetNuiFocus( (focus == true), (cursor == true) ) end)
    dbg('SetNuiFocus', tostring(focus), tostring(cursor))
end

local function safeSendNui(msg)
    if type(msg) ~= 'table' then return end
    pcall(function() SendNUIMessage(msg) end)
    local ok, s = pcall(function() return json and json.encode and json.encode(msg) or tostring(msg) end)
    dbg('SendNUIMessage ->', ok and s or tostring(msg))
end

-- helpers: resources
local function resourceStarted(name)
    if type(GetResourceState) ~= 'function' or not name then return false end
    local ok, state = pcall(GetResourceState, name)
    return ok and state == 'started'
end

-- screenshot-basic integration (optional)
local function canAutoPhoto()
    local photoCfg = Config and Config.License and Config.License.Photo or {}
    if photoCfg.Mode ~= 'pedshot' then return false end
    if photoCfg.UseScreenshotBasic ~= true then return false end
    if not resourceStarted('screenshot-basic') then return false end
    return true
end

-- Hilfsfunktion: Server-Result verarbeiten
local function onServerPhoto(data)
    if not data or type(data) ~= 'string' or #data == 0 then
        safeSendNui({ action = 'notify', level = 'error', text = 'Foto-Fehler: leere Antwort', duration = 3000 })
        return
    end
    dbg('server photo length = '..tostring(#data))
    safeSendNui({ action = 'notify', level = 'info', text = ('Foto erfasst: '..tostring(#data)..' Bytes (Server)'), duration = 3500 })
    safeSendNui({ action = 'updateLicensePhoto', photo = data })
    if lastLicenseCategory and lastLicenseCategory ~= '' then
        TriggerServerEvent(RESOURCE..':server:licensePhotoSave', lastLicenseCategory, data)
    end
end

-- Robust: Versuche Client-Export (beide Signaturen), sonst Server-Fallback
local function captureAndSendLicensePhoto()
    local photoCfg = Config and Config.License and Config.License.Photo or {}
    local opts = {}
    if photoCfg.Jpeg == true then
        opts.encoding = 'jpg'
        opts.filetype = 'jpeg' -- für server fallback
        opts.quality  = 0.9
    else
        opts.encoding = 'png'
        opts.filetype = 'png'  -- für server fallback
        opts.quality  = 0.9
    end

    local function onGotData(from, data)
        if not data or type(data) ~= 'string' or #data == 0 then
            dbg('screenshot-basic returned empty data ('..from..')')
            safeSendNui({ action = 'notify', level = 'error', text = 'Foto fehlgeschlagen (0 Bytes)', duration = 3000 })
            return
        end
        dbg('screenshot-basic photo length ('..from..') = '..tostring(#data))
        safeSendNui({ action = 'notify', level = 'info', text = ('Foto erfasst: '..tostring(#data)..' Bytes ('..from..')'), duration = 3500 })
        safeSendNui({ action = 'updateLicensePhoto', photo = data })
        if lastLicenseCategory and lastLicenseCategory ~= '' then
            TriggerServerEvent(RESOURCE..':server:licensePhotoSave', lastLicenseCategory, data)
        end
    end

    -- 1) Client-Export: requestScreenshot – Signatur A: (cb, opts)
    local triedClient = false
    local okA = false
    local okTryA, errA = pcall(function()
        if exports and exports['screenshot-basic'] and exports['screenshot-basic'].requestScreenshot then
            triedClient = true
            exports['screenshot-basic']:requestScreenshot(function(data)
                onGotData('client-A', data)
            end, { encoding = opts.encoding, quality = opts.quality })
            okA = true
        else
            error('client export not available')
        end
    end)
    if triedClient and okA and okTryA then return end

    -- 1b) Client-Export: requestScreenshot – Signatur B: (opts, cb)
    local okB = false
    if not okA then
        local okTryB = pcall(function()
            if exports and exports['screenshot-basic'] and exports['screenshot-basic'].requestScreenshot then
                triedClient = true
                exports['screenshot-basic']:requestScreenshot({ encoding = opts.encoding, quality = opts.quality }, function(data)
                    onGotData('client-B', data)
                end)
                okB = true
            end
        end)
        if triedClient and okB and okTryB then return end
    end

    -- 2) Server-Fallback: requestClientScreenshot
    dbg('client export not available/failed, fallback -> server requestClientScreenshot')
    local okStart, errStart = pcall(function()
        -- Übergib filetype explizit (png/jpeg), plus encoding/quality für maximale Kompatibilität
        TriggerServerEvent(RESOURCE..':server:capturePhotoRequest', { filetype = opts.filetype, encoding = opts.encoding, quality = opts.quality })
    end)
    if not okStart then
        dbg('fallback trigger failed: '..tostring(errStart))
        safeSendNui({ action = 'notify', level = 'error', text = 'Foto-Start fehlgeschlagen: '..tostring(errStart), duration = 3500 })
    else
        safeSendNui({ action = 'notify', level = 'info', text = 'Foto: Server-Fallback angefordert …', duration = 2000 })
    end
end

-- Ergebnis vom Server-Fallback empfangen
RegisterNetEvent(RESOURCE..':client:capturePhotoResult', function(ok, dataOrErr)
    if not ok then
        dbg('server capture error: '..tostring(dataOrErr))
        safeSendNui({ action = 'notify', level = 'error', text = 'Foto-Fehler (Server): '..tostring(dataOrErr), duration = 3500 })
        return
    end
    onServerPhoto(dataOrErr)
end)

-- Send server ACK that client closed result NUI
local function sendResultCloseAckToServer(retries)
    retries = tonumber(retries) or 2
    local ok = pcall(function() TriggerServerEvent(RESOURCE..':server:resultCloseAck') end)
    if ok then
        dbg('sent server resultCloseAck')
        return
    end
    CreateThread(function()
        local attempts = retries
        while attempts > 0 do
            Wait(200)
            local succ = pcall(function() TriggerServerEvent(RESOURCE..':server:resultCloseAck') end)
            if succ then
                dbg('sent server resultCloseAck (retry ok)')
                return
            end
            attempts = attempts - 1
        end
        dbg('failed to send server resultCloseAck after retries')
    end)
end

-- DEBUG: NUI callback for booking
RegisterNUICallback('book', function(data, cb)
    local okEnc, s = pcall(function() return json and json.encode and json.encode(data) or tostring(data) end)
    dbg('NUI callback "book" triggered, data =', okEnc and s or tostring(data))
    local eventName = RESOURCE .. ':server:book'
    dbg('TriggerServerEvent ->', eventName, 'category=' .. tostring(data and data.category), 'mode=' .. tostring(data and data.mode))
    pcall(function() TriggerServerEvent(eventName, data and data.category, data and data.mode) end)
    if cb then cb({ ok = true }) end
end)

-- NEW: Theorie submit -> server
RegisterNUICallback('theory_submit', function(data, cb)
    local category = (data and data.category) or lastBookingState.category
    local result   = (data and data.result) or {}
    local passed   = result.passed == true
    local pct      = tonumber(result.percentage) or 0
    local token    = lastBookingState.token
    dbg('NUI callback "theory_submit"', 'cat='..tostring(category), 'passed='..tostring(passed), 'pct='..tostring(pct), 'token='..tostring(token))
    if category == nil then
        dbg('WARN: theory_submit without category; trying anyway')
    end
    pcall(function()
        TriggerServerEvent(RESOURCE..':server:theoryResult', category, token, passed, pct)
    end)
    if cb then cb({ ok = true }) end
end)

-- Exports
function OpenPracticeUI(payload)
    payload = payload or {}
    payload.action = payload.action or 'openMenu'
    if nowMs() < uiSuppressUntil then
        dbg('OpenPracticeUI suppressed until', uiSuppressUntil)
        return false
    end
    safeSendNui(payload)
    safeSetNuiFocus(true, true)
    nuiOpen = true
    return true
end
exports('OpenPracticeUI', OpenPracticeUI)

function ShowPracticeResultDirect(passed, errors, summary, detail)
    local payload = { action = 'result', passed = (passed == true), errors = errors or {}, summary = summary or '', detail = detail or {} }
    if nowMs() < uiSuppressUntil then
        queuedPayload = payload
        dbg('ShowPracticeResultDirect queued due to suppress')
        return
    end
    safeSendNui(payload)
    safeSetNuiFocus(true, true)
    nuiOpen = true
end
exports('ShowPracticeResultDirect', ShowPracticeResultDirect)

function cleanupPracticeVehicle()
    dbg('cleanupPracticeVehicle called (no-op)')
end
exports('cleanupPracticeVehicle', cleanupPracticeVehicle)

-- NUI callbacks
RegisterNUICallback('resultClose', function(data, cb)
    dbg('NUICallback resultClose (user closed result NUI)')
    sendResultCloseAckToServer(2)
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 1200
    queuedPayload = nil
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('resultForceClosedAck', function(data, cb)
    dbg('NUICallback resultForceClosedAck (NUI fully hid and posted ack)')
    pcall(function() TriggerServerEvent(RESOURCE..':server:resultCloseAck') end)
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('clientClickedOutside', function(data, cb)
    dbg('NUICallback clientClickedOutside (user clicked outside the UI)')
    sendResultCloseAckToServer(2)
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 300
    queuedPayload = nil
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('close', function(data, cb)
    dbg('NUICallback close (generic close)')
    sendResultCloseAckToServer(1)
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 300
    queuedPayload = nil
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('licenseClose', function(_, cb)
    dbg('NUICallback licenseClose')
    safeSetNuiFocus(false, false)
    if cb then cb({ ok = true }) end
end)

-- Server -> client events
RegisterNetEvent(RESOURCE..':client:openMenu', function(payload)
    dbg('server -> openMenu')
    OpenPracticeUI(payload)
end)

RegisterNetEvent(RESOURCE..':client:openTheory', function(payload)
    dbg('server -> openTheory')
    payload = payload or {}
    payload.action = 'openTheory'
    if nowMs() < uiSuppressUntil then
        dbg('openTheory suppressed due to uiSuppress')
        return
    end
    safeSendNui(payload)
    safeSetNuiFocus(true, true)
    nuiOpen = true
end)

RegisterNetEvent(RESOURCE..':client:practiceOutcome', function(passed, errors, summary, detail)
    dbg('server -> practiceOutcome', tostring(passed))
    ShowPracticeResultDirect(passed, errors or {}, summary or '', detail or {})
end)

RegisterNetEvent(RESOURCE..':client:practiceForceAbort', function(reasonKey, label)
    dbg('server -> practiceForceAbort', tostring(reasonKey), tostring(label))
    sendResultCloseAckToServer(3)
    safeSendNui({ action = 'forceClose', reason = ('server-abort:'..tostring(reasonKey)), label = label })
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 1500
end)

RegisterNetEvent(RESOURCE..':client:stateSync', function(state)
    dbg('server -> stateSync')
    state = state or {}
    if state.token ~= nil then lastBookingState.token = state.token end
    if state.category ~= nil then lastBookingState.category = state.category end
    safeSendNui({ action = 'stateSync', state = state })
end)

RegisterNetEvent(RESOURCE..':client:notify', function(level, text, duration)
    dbg('server -> notify', tostring(level), tostring(text), 'dur='..tostring(duration))
    safeSendNui({
        action   = 'notify',
        level    = level,
        text     = tostring(text or ''),
        duration = duration or (Config and Config.NotifyDuration) or 4000
    })
end)

RegisterNetEvent(RESOURCE..':client:booked', function(category, token)
    dbg('server -> booked', tostring(category), tostring(token))
    lastBookingState.category = category
    lastBookingState.token = token
    safeSendNui({ action = 'notify', text = ('Buchung erhalten: '..tostring(category)) })
end)

RegisterNetEvent(RESOURCE..':client:licenseOpen', function(data)
    dbg('server -> licenseOpen')
    local disp = (Config and Config.License and Config.License.Display) or {}
    local autoMs = (tonumber(disp.AutoCloseSeconds) or 0) * 1000

    lastLicenseCategory = data and data.category or nil

    safeSendNui({ action = 'openLicense', license = data or {}, autoCloseMs = autoMs })

    if disp.FocusOnOpen == true then
        safeSetNuiFocus(true, true)
    end

    if canAutoPhoto() then
        CreateThread(function()
            Wait(150)
            captureAndSendLicensePhoto()
        end)
    else
        dbg('autoPhoto disabled or screenshot-basic not started, trying server fallback anyway')
        TriggerServerEvent(RESOURCE..':server:capturePhotoRequest', { filetype = 'jpeg', encoding = 'jpg', quality = 0.9 })
    end
end)

RegisterNetEvent(RESOURCE..':client:closeUI', function(reason)
    dbg('server -> closeUI reason='..tostring(reason))
    safeSendNui({ action = 'forceClose', reason = reason or 'server-close' })
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 1500
    pcall(function() TriggerServerEvent(RESOURCE..':server:resultCloseAck') end)
end)

CreateThread(function()
    while true do
        Wait(250)
        if queuedPayload and nowMs() >= uiSuppressUntil then
            dbg('flushing queuedPayload after suppress')
            local q = queuedPayload; queuedPayload = nil
            safeSendNui(q)
            safeSetNuiFocus(true, true)
            nuiOpen = true
        end
    end
end)

RegisterCommand('mtj_ui_forceclose', function()
    dbg('cmd mtj_ui_forceclose executed')
    safeSendNui({ action = 'forceClose', reason = 'cmd-forceclose' })
    safeSetNuiFocus(false, false)
    nuiOpen = false
    uiSuppressUntil = nowMs() + 1500
    pcall(function() TriggerServerEvent(RESOURCE..':server:resultCloseAck') end)
end, false)

-- DEBUG: Foto (Auto-Pfad, inkl. Fallback)
RegisterCommand('mtj_test_photo', function()
    dbg('cmd mtj_test_photo -> captureAndSendLicensePhoto()')
    captureAndSendLicensePhoto()
end, false)

-- DEBUG: Nur Client-Export testen
RegisterCommand('mtj_test_photo_cli', function()
    dbg('cmd mtj_test_photo_cli -> client export only')
    captureAndSendLicensePhoto()
end, false)

-- DEBUG: Nur Server-Fallback testen
RegisterCommand('mtj_test_photo_srv', function()
    dbg('cmd mtj_test_photo_srv -> server fallback only')
    TriggerServerEvent(RESOURCE..':server:capturePhotoRequest', { filetype = 'jpeg', encoding = 'jpg', quality = 0.9 })
end, false)

-- DEBUG: Server-/Exportstatus von screenshot-basic prüfen
RegisterCommand('mtj_dbg_sbasic', function()
    TriggerServerEvent(RESOURCE..':server:dbg_sbasic')
end, false)

dbg('client/ui.lua loaded for resource='..tostring(RESOURCE))

-- ==== PATCH: Ausweis-Bridge für Server-Events -> NUI (minimal, kompatibel) ====

local function _mtj_handleLicenseOpenFromServer(data)
    dbg('server -> (license bridge) open license')
    local disp = (Config and Config.License and Config.License.Display) or {}
    local autoMs = (tonumber(disp.AutoCloseSeconds) or 0) * 1000

    -- Kategorie merken für Foto-Speicherung
    lastLicenseCategory = data and (data.category or data.categoryLabel) or lastLicenseCategory

    -- NUI öffnen (Nutzung openLicense, da von deiner NUI bereits unterstützt)
    safeSendNui({ action = 'openLicense', license = data or {}, autoCloseMs = autoMs })

    if disp.FocusOnOpen == true then
        safeSetNuiFocus(true, true)
    end
end

RegisterNetEvent(RESOURCE..':client:showLicenseCard', function(payload)
    _mtj_handleLicenseOpenFromServer(payload)
end)

RegisterNetEvent(RESOURCE..':client:showLicense', function(payload)
    _mtj_handleLicenseOpenFromServer(payload)
end)

RegisterNetEvent(RESOURCE..':client:license:show', function(payload)
    _mtj_handleLicenseOpenFromServer(payload)
end)

RegisterNetEvent(RESOURCE..':client:updateLicensePhoto', function(photo)
    if type(photo) ~= 'string' or #photo < 8 then
        dbg('server -> updateLicensePhoto ignored (invalid)')
        return
    end
    dbg('server -> updateLicensePhoto ('..tostring(#photo)..' bytes)')
    safeSendNui({ action = 'updateLicensePhoto', photo = photo })
end)

-- Fix: Forward theoryOutcome to NUI so the result panel is shown after theory submission.
-- Triggered by server/main.lua (handleTheoryResultCore) after processing a theory submission.
-- Parameters: passed (bool), scorePct (0-100), detail (table with ts/category)
RegisterNetEvent(RESOURCE..':client:theoryOutcome', function(passed, scorePct, detail)
    dbg('server -> theoryOutcome passed='..tostring(passed)..' pct='..tostring(scorePct))
    safeSendNui({
        action   = 'theoryOutcome',
        passed   = (passed == true),
        scorePct = tonumber(scorePct) or 0,
        detail   = type(detail) == 'table' and detail or {}
    })
end)

-- Fix: Also forward theoryEnd (fired by server/theorie_result.lua) to NUI.
-- This is the alternate event path from the duplicate handler in theorie_result.lua.
-- Contains stats in a nested table: { passed, stats = { scorePct, totalQuestions, ... } }
RegisterNetEvent(RESOURCE..':client:theoryEnd', function(payload)
    if type(payload) ~= 'table' then return end
    local passed   = (payload.passed == true)
    local st       = type(payload.stats) == 'table' and payload.stats or {}
    local scorePct = tonumber(st.scorePct or 0)
    dbg('server -> theoryEnd passed='..tostring(passed)..' pct='..tostring(scorePct))
    safeSendNui({
        action   = 'theoryOutcome',
        passed   = passed,
        scorePct = scorePct,
        detail   = { ts = os.time and os.time() or 0 }
    })
end)