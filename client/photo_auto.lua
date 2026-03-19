-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- Auto-Foto + Debug für Führerschein-Karte
-- Blockiert NIE das UI/Item-Öffnen. Alles in pcall/Threads mit klaren Logs.

local RESOURCE = (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'

-- Flags (per Commands umschaltbar)
local PHOTO_DEBUG   = true   -- Debug standardmäßig AN
local PHOTO_DISABLE = false  -- Auto-Foto standardmäßig AN

local function printf(...)
    local parts = {}
    for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    print(('[%s][client/photo] %s'):format(RESOURCE, table.concat(parts, ' ')))
end
local function dbg(...) if PHOTO_DEBUG then printf(...) end end

local function notify(level, text, duration)
    duration = duration or 3500
    pcall(function() SendNUIMessage({ action='notify', level=level, text=text, duration=duration }) end)
end

local function resourceStarted(name)
    if type(GetResourceState) ~= 'function' or not name then return false end
    local ok, state = pcall(GetResourceState, name)
    return ok and state == 'started'
end

local function hasClientShot()
    return exports
       and exports['screenshot-basic']
       and type(exports['screenshot-basic'].requestScreenshot) == 'function'
end

local function tryClientCapture(category, opts)
    opts = opts or { encoding = 'jpg', quality = 0.92 }

    local function onData(tag, data)
        if type(data) ~= 'string' or #data < 32 then
            dbg('client capture '..tag..' -> invalid/empty')
            notify('error', 'Foto fehlgeschlagen (0 Bytes)', 3000)
            return false
        end
        dbg('client capture '..tag..' ok bytes='..tostring(#data))
        -- Sofort ins UI
        pcall(function() SendNUIMessage({ action='updateLicensePhoto', photo=data }) end)
        -- Server speichern
        if category and category ~= '' then
            TriggerServerEvent(RESOURCE..':server:licensePhotoSave', category, data)
        end
        notify('success', ('Foto erfasst: '..tostring(#data)..' Bytes (Client)'), 3500)
        return true
    end

    -- Kurz warten, damit die Karte sichtbar ist
    Wait(200)

    -- Offizielle Signatur (options-first)
    local ok1, err1 = pcall(function()
        exports['screenshot-basic']:requestScreenshot(
            { encoding = opts.encoding or 'jpg', quality = opts.quality or 0.92 },
            function(data) onData('opt-first', data) end
        )
    end)
    if ok1 then return true end
    dbg('client capture options-first threw -> '..tostring(err1))

    -- Fallback: alte Forks (cb-first)
    local ok2, err2 = pcall(function()
        exports['screenshot-basic']:requestScreenshot(
            function(data) onData('cb-first', data) end,
            { encoding = opts.encoding or 'jpg', quality = opts.quality or 0.92 }
        )
    end)
    if ok2 then return true end
    dbg('client capture cb-first threw -> '..tostring(err2))
    notify('error', 'Foto-Fehler (Client-Export nicht nutzbar)', 3000)
    return false
end

-- Ergebnis vom Server-Fallback (Bridge)
RegisterNetEvent(RESOURCE..':client:capturePhotoResult', function(ok, dataOrErr)
    if not ok then
        dbg('server capture error: '..tostring(dataOrErr))
        notify('error', 'Foto-Fehler (Server): '..tostring(dataOrErr), 3500)
        return
    end
    if type(dataOrErr) ~= 'string' or #dataOrErr < 32 then
        notify('error', 'Foto-Fehler (Server: leere Antwort)', 3000)
        return
    end
    dbg('server capture ok bytes='..tostring(#dataOrErr))
    pcall(function() SendNUIMessage({ action='updateLicensePhoto', photo=dataOrErr }) end)
    notify('success', ('Foto erfasst: '..tostring(#dataOrErr)..' Bytes (Server)'), 3500)
end)

-- Auto-Capture beim Öffnen der Karte
RegisterNetEvent(RESOURCE..':client:licenseOpen', function(payload)
    local lic = payload and (payload.license or payload) or {}
    local cat = lic.category or lic.cat or 'car'
    local initialPhoto = lic.photo
    dbg(('licenseOpen cat=%s initialPhotoBytes=%s'):format(tostring(cat), (type(initialPhoto)=='string' and #initialPhoto or 0)))

    if PHOTO_DISABLE then
        dbg('PHOTO_DISABLE=true -> skip auto capture')
        notify('warning', 'Auto-Foto deaktiviert (Debug)', 2000)
        return
    end

    CreateThread(function()
        -- 1) Client-Export bevorzugt
        if resourceStarted('screenshot-basic') and hasClientShot() then
            dbg('starting client capture...')
            local ok = tryClientCapture(cat, { encoding='jpg', quality=0.92 })
            if ok then return end
        else
            dbg('client export missing or screenshot-basic not started')
        end

        -- 2) Serverseitiger Fallback (Bridge)
        dbg('fallback -> server capture request')
        TriggerServerEvent(RESOURCE..':server:capturePhotoRequest', { filetype='jpeg', encoding='jpg', quality=0.92 })
    end)
end)

-- =========================
-- Debug-Commands
-- =========================
local function printStatus()
    local sbStarted = resourceStarted('screenshot-basic')
    local cliExport = hasClientShot()
    printf('STATUS: sbStarted=%s, clientExport=%s, debug=%s, disable=%s',
        tostring(sbStarted), tostring(cliExport), tostring(PHOTO_DEBUG), tostring(PHOTO_DISABLE))
end

RegisterCommand('mtj_photo_debug', function(_, args)
    local arg = tostring(args and args[1] or ''):lower()
    if arg == 'on' or arg == '1' or arg == 'true' then PHOTO_DEBUG = true
    elseif arg == 'off' or arg == '0' or arg == 'false' then PHOTO_DEBUG = false
    else PHOTO_DEBUG = not PHOTO_DEBUG end
    printf('PHOTO_DEBUG='..tostring(PHOTO_DEBUG))
    printStatus()
end, false)

RegisterCommand('mtj_photo_disable', function(_, args)
    local arg = tostring(args and args[1] or ''):lower()
    if arg == 'on' or arg == '1' or arg == 'true' then PHOTO_DISABLE = true
    elseif arg == 'off' or arg == '0' or arg == 'false' then PHOTO_DISABLE = false
    else PHOTO_DISABLE = not PHOTO_DISABLE end
    printf('PHOTO_DISABLE='..tostring(PHOTO_DISABLE)..' (Auto-Foto wird '..(PHOTO_DISABLE and 'NICHT ' or '')..'ausgeführt)')
    printStatus()
end, false)

RegisterCommand('mtj_photo_status', function()
    printStatus()
    notify('info', ('Foto-Status: debug='..tostring(PHOTO_DEBUG)..', disable='..tostring(PHOTO_DISABLE)), 2500)
end, false)

-- Test: Öffnet eine Testkarte und erzwingt Foto
RegisterCommand('mtj_photo_test', function()
    printf('mtj_photo_test -> open test license + capture')
    local payload = {
        action = 'openLicense',
        license = {
            firstname = 'Test',
            lastname  = 'Spieler',
            birthdate = '01/01/1990',
            height    = '180',
            category  = 'car',
            categoryLabel = 'PKW',
            issuedAt  = 'heute',
            expiresAt = 'in 10 Jahren',
            orgName   = 'Deine Fahrschule',
            logo      = 'img/logo.png',
            photo     = 'img/logo.png'
        },
        autoCloseMs = 15000
    }
    pcall(function() SendNUIMessage(payload) end)
    TriggerEvent(RESOURCE..':client:licenseOpen', payload)
end, false)

-- Test: Nur Client-Export
RegisterCommand('mtj_photo_cli', function()
    printf('mtj_photo_cli -> client export only')
    if not resourceStarted('screenshot-basic') or not hasClientShot() then
        printf('client export missing or sb not started')
        notify('error', 'Client-Export fehlt oder screenshot-basic nicht gestartet', 3000)
        return
    end
    CreateThread(function()
        tryClientCapture('car', { encoding='jpg', quality=0.92 })
    end)
end, false)

-- Test: Nur Server-Fallback
RegisterCommand('mtj_photo_srv', function()
    printf('mtj_photo_srv -> server fallback only')
    TriggerServerEvent(RESOURCE..':server:capturePhotoRequest', { filetype='jpeg', encoding='jpg', quality=0.92 })
end, false)

printf('client/photo_auto.lua loaded')