-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- mtj_fahrschule/server/main.lua
-- ESX Legacy kompatibel. Kompakte JPEG-Fotos, kleine NUI-Events.
-- WICHTIG: Keine Nutzung von ox_inventory:RegisterUsableItem (dein ox hat den Export nicht).
-- Stattdessen: stabiler Fallback über Server-Events (ox_inventory:usedItem / ox_inventory:useItem).

-- ============================================================================
-- ESX INIT
-- ============================================================================
local ESX = nil

local function tryInitESX()
    if ESX then return ESX end
    local ok, obj = pcall(function()
        if type(GetResourceState) == 'function' and GetResourceState('es_extended') == 'started' then
            if exports and exports['es_extended'] and type(exports['es_extended'].getSharedObject) == 'function' then
                return exports['es_extended']:getSharedObject()
            end
        end
        return nil
    end)
    if ok and obj then ESX = obj; return ESX end
    pcall(function() TriggerEvent('esx:getSharedObject', function(o) ESX = o end) end)
    return ESX
end

tryInitESX()

-- ============================================================================
-- OXMYSQL / DB
-- ============================================================================
local hasOxmysql = (type(GetResourceState) == 'function' and GetResourceState('oxmysql') == 'started')
if hasOxmysql and type(MySQL) ~= 'table' then
    print('[mtj_fahrschule][server] WARN: oxmysql aktiv, aber MySQL global fehlt -> DB deaktiviert')
    hasOxmysql = false
end
local dbEnabled = hasOxmysql and not (Config and Config.DBDisabled)

local function ensureLicenseTable()
    if not hasOxmysql then return end
    pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mtj_fahrschule_licenses (
              identifier VARCHAR(64) NOT NULL,
              category   VARCHAR(16) NOT NULL,
              issued_at  DATE,
              expires_at DATE,
              photo_url  LONGTEXT NULL,
              PRIMARY KEY(identifier, category)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {})
    end)
end

local function ensureTheoryPracticeTables()
    if not hasOxmysql then return end
    pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mtj_fahrschule_theory (
              id INT AUTO_INCREMENT PRIMARY KEY,
              identifier VARCHAR(64) NOT NULL,
              category VARCHAR(16) NOT NULL,
              score_pct INT DEFAULT 0,
              created_at DATETIME NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {})
    end)
    pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mtj_fahrschule_practice (
              id INT AUTO_INCREMENT PRIMARY KEY,
              identifier VARCHAR(64) NOT NULL,
              category VARCHAR(16) NOT NULL,
              summary VARCHAR(255),
              passed TINYINT(1) DEFAULT 0,
              created_at DATETIME NOT NULL,
              errors_json LONGTEXT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {})
    end)
end

local function ensureBookingsTable()
    if not hasOxmysql then return end
    pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mtj_fahrschule_bookings (
              identifier VARCHAR(64) NOT NULL PRIMARY KEY,
              category   VARCHAR(16) NOT NULL,
              token      VARCHAR(64) NOT NULL,
              mode       VARCHAR(16) NOT NULL,
              expires    DATETIME NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {})
    end)
end

-- ============================================================================
-- CONVARS / LIMITS
-- ============================================================================
local RESOURCE = (Config and Config.ResourceName) or GetCurrentResourceName() or 'mtj_fahrschule'
local JPG_QUALITY      = tonumber(GetConvar('mtj_photo_jpeg_quality', '0.45')) or 0.45
local PHOTO_EVENT_CAP  = (tonumber(GetConvar('mtj_photo_max_event_kb', '256')) or 256) * 1024 -- max Eventgröße
local DB_PHOTO_CAP     = (tonumber(GetConvar('mtj_photo_db_cap_kb', '512')) or 512) * 1024    -- max DB-Größe
local PHOTO_STORE      = (GetConvar('mtj_photo_store', 'db') or 'db'):lower()                 -- 'url' oder 'db'
local WEBHOOK_URL      = (GetConvar('mtj_photo_webhook', '') or '')

-- ============================================================================
-- GLOBAL STATE / UTILS
-- ============================================================================
local bookings = {}
local lastTheoryById = {}
local lastPracticeById = {}
local pendingEnrollmentById = {}
local activePractice = {}
local pendingOutcomes = {}
local pendingAckReceived = {}
local uiSuppress = {}

-- RAM-Foto-Cache
local photos = {}
local function cacheSetPhoto(identifier, category, dataUrlOrUrl)
    if not identifier or not category then return end
    if type(dataUrlOrUrl) ~= 'string' or #dataUrlOrUrl < 8 then return end
    photos[identifier] = photos[identifier] or {}
    photos[identifier][category] = dataUrlOrUrl
end
local function cacheGetPhoto(identifier, category)
    return photos[identifier] and photos[identifier][category] or nil
end

local function log(...)
    local parts = {}
    for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    print(('[%s][server] %s'):format(RESOURCE, table.concat(parts, ' ')))
end

local function nowSecs() return os.time() end
local function nowMs() return (type(GetGameTimer) == 'function' and GetGameTimer()) or (os.time()*1000) end

local function genToken()
    math.randomseed((os.time() % 100000) + (nowMs() % 100000))
    local t = {}
    for i=1,16 do t[#t+1]=string.format('%02x', math.random(0,255)) end
    return table.concat(t)
end

local function normalizeCategoryKey(cat)
    if not cat then return 'car' end
    local s = tostring(cat):lower()
    if s == 'car' or s == 'auto' or s == 'pkw' then return 'car' end
    if s == 'bike' or s == 'moto' or s == 'motorrad' then return 'bike' end
    if s == 'truck' or s == 'lkw' then return 'truck' end
    if s == 'heli' or s == 'hubschrauber' or s == 'hubi' then return 'heli' end
    if s == 'plane' or s == 'flugzeug' then return 'plane' end
    return 'car'
end

local function normalizeMode(mode)
    local m = (mode or ''):lower()
    if m == 'theory' or m == 'theorie' then return 'theorie' end
    if m == 'practice' or m == 'praxis' then return 'praxis' end
    return 'theorie'
end

local function dateDisplay(ymd)
    local s = tostring(ymd or '')
    local y,m,d = s:match('^(%d+)%-(%d+)%-(%d+)$')
    if not y then return '' end
    return string.format('%02d.%02d.%04d', tonumber(d or 1), tonumber(m or 1), tonumber(y or 1970))
end

local function ymdAddDays(ymd, days)
    local y,m,d = tostring(ymd or ''):match('^(%d+)%-(%d+)%-(%d+)$')
    if not y then return os.date('%Y-%m-%d', os.time()+days*86400) end
    local t = os.time{year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=12}
    return os.date('%Y-%m-%d', t + days*86400)
end

local function getIdentifier(xPlayer)
    if not xPlayer then return nil end
    if xPlayer.identifier then return xPlayer.identifier end
    if xPlayer.getIdentifier then local ok,id=pcall(function() return xPlayer.getIdentifier() end) if ok and id then return id end end
    return nil
end

local function getIdentifierGeneric(src)
    tryInitESX()
    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
    return getIdentifier(xPlayer) or ('src:'..tostring(src))
end

-- ============================================================================
-- PLAYER IDENTITY
-- ============================================================================
function getIdentity(src)
    tryInitESX()
    local data = { firstname='', lastname='', birthdate='', height='' }
    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.get then
            data.firstname = xPlayer.get('firstName') or xPlayer.get('firstname') or ''
            data.lastname  = xPlayer.get('lastName')  or xPlayer.get('lastname')  or ''
            data.birthdate = xPlayer.get('dateofbirth') or xPlayer.get('dob') or ''
            data.height    = xPlayer.get('height') and tostring(xPlayer.get('height')) or ''
        else
            local name = xPlayer and xPlayer.getName and xPlayer.getName() or ''
            local f,l = tostring(name):match('^(%S+)%s+(.*)$')
            data.firstname, data.lastname = f or name, l or ''
        end
    end
    return data
end

-- ============================================================================
-- ITEMS / INVENTORY HELPERS
-- ============================================================================
local function getTheoryItemName(cat)
    local k = normalizeCategoryKey(cat)
    return Config and Config.Items and Config.Items.theory and Config.Items.theory[k] or nil
end
local function getPracticeItemName(cat)
    local k = normalizeCategoryKey(cat)
    return Config and Config.Items and Config.Items.practice and Config.Items.practice[k] or nil
end

local function invCount(src, itemName, xPlayer)
    if not itemName or itemName == '' then return 0 end
    if xPlayer and xPlayer.getInventoryItem then
        local it = xPlayer.getInventoryItem(itemName)
        local cnt = (it and (it.count or it.quantity or it.amount)) or 0
        if (cnt or 0) > 0 then return cnt end
    end
    if exports and exports.ox_inventory then
        local ok, cnt = pcall(function()
            return exports.ox_inventory:Search(src, 'count', itemName)
        end)
        if ok and tonumber(cnt or 0) > 0 then return tonumber(cnt) end
    end
    return 0
end

local function invAddOne(src, itemName, xPlayer)
    if not itemName or itemName == '' then return false end
    if xPlayer and xPlayer.addInventoryItem then
        local ok = pcall(function() xPlayer.addInventoryItem(itemName, 1) end)
        if ok then return true end
    end
    if exports and exports.ox_inventory then
        local ok, res = pcall(function() return exports.ox_inventory:AddItem(src, itemName, 1) end)
        if ok and res then return true end
    end
    return false
end

-- Entferne genau 1 Item (ESX + ox Fallback)
local function invRemoveOne(src, itemName, xPlayer)
    if not itemName or itemName == '' then return false end
    if xPlayer and xPlayer.removeInventoryItem then
        local ok = pcall(function() xPlayer.removeInventoryItem(itemName, 1) end)
        if ok then return true end
    end
    if exports and exports.ox_inventory then
        local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, itemName, 1) end)
        if ok and res then return true end
    end
    return false
end

-- ============================================================================
-- PREISE / CHARGE
-- ============================================================================
local function priceFor(category, mode)
    local cat = normalizeCategoryKey(category)
    mode = normalizeMode(mode)
    if not (Config and Config.Prices and Config.Prices[cat]) then return 0 end
    local p = Config.Prices[cat]
    if type(p) == 'table' then return tonumber(p[mode]) or 0 end
    return tonumber(p) or 0
end

local function chargePlayer(playerOrSrc, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    local xPlayer, src = nil, nil
    if type(playerOrSrc) == 'number' then src = playerOrSrc
    else xPlayer = playerOrSrc; src = (xPlayer and xPlayer.source) or src end
    tryInitESX()
    if not xPlayer and ESX and type(src)=='number' then pcall(function() xPlayer = ESX.GetPlayerFromId(src) end) end
    if xPlayer then
        local ok, res = pcall(function()
            if xPlayer.getMoney and xPlayer.removeMoney then
                local bal = tonumber(xPlayer.getMoney()) or 0
                if bal >= amount then xPlayer.removeMoney(amount); return true end
                return false, 'Nicht genug Geld.'
            end
            if xPlayer.getAccount and xPlayer.removeAccountMoney then
                local acc = xPlayer.getAccount and xPlayer.getAccount('money') or nil
                local bal = (acc and (acc.money or 0)) or 0
                if bal >= amount and acc and acc.name then xPlayer.removeAccountMoney(acc.name, amount); return true end
                return false, 'Nicht genug Geld.'
            end
            return false, 'Zahlung nicht möglich.'
        end)
        if ok and res == true then return true end
        if ok and type(res)=='string' then return false, res end
    end
    return false, 'Zahlung fehlgeschlagen.'
end

-- ============================================================================
-- LICENSE FINALIZATION
-- ============================================================================
local function upsertLicense(identifier, category, issuedYmd, expiresYmd, photoUrl)
    if not dbEnabled or not identifier or not category then return end
    ensureLicenseTable()
    pcall(function()
        MySQL.update([[
            INSERT INTO mtj_fahrschule_licenses (identifier, category, issued_at, expires_at, photo_url)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE issued_at=VALUES(issued_at), expires_at=VALUES(expires_at),
                                    photo_url=COALESCE(VALUES(photo_url), photo_url)
        ]], { identifier, normalizeCategoryKey(category), issuedYmd, expiresYmd, photoUrl })
    end)
end

local function finalizeLicenseAndItem(identifier, src, category, photoUrlOrNil)
    local cat = normalizeCategoryKey(category)
    local validDays = (Config and Config.License and Config.License.ValidDays and Config.License.ValidDays[cat]) or 3650
    local issuedYmd  = os.date('%Y-%m-%d')
    local expiresYmd = ymdAddDays(issuedYmd, validDays)
    upsertLicense(identifier, cat, issuedYmd, expiresYmd, photoUrlOrNil)

    local item = getPracticeItemName(cat)
    tryInitESX()
    local xP = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
    if item then invAddOne(src, item, xP) end
end

-- ============================================================================
-- SCREENSHOT / UPLOAD
-- ============================================================================
local _mtj_screenshot_res = nil
local function detectScreenshotResource()
    if _mtj_screenshot_res then return _mtj_screenshot_res end
    local forced = (GetConvar and GetConvar('mtj_photo_res', '') or '')
    if forced ~= '' and type(GetResourceState) == 'function' and GetResourceState(forced) == 'started' then
        if exports and exports[forced] and type(exports[forced].requestClientScreenshot) == 'function' then
            _mtj_screenshot_res = forced
            return _mtj_screenshot_res
        end
    end
    local aliases = { 'screenshot-basic', 'screenshot_basic' }
    for _, name in ipairs(aliases) do
        if type(GetResourceState) == 'function' and GetResourceState(name) == 'started' then
            if exports and exports[name] and type(exports[name].requestClientScreenshot) == 'function' then
                _mtj_screenshot_res = name
                return _mtj_screenshot_res
            end
        end
    end
    for resName, ex in pairs(exports or {}) do
        if type(ex) == 'table' and type(ex.requestClientScreenshot) == 'function' then
            if type(GetResourceState) == 'function' and GetResourceState(resName) == 'started' then
                _mtj_screenshot_res = resName
                return _mtj_screenshot_res
            end
        end
    end
    return nil
end

local function _unpack_shot(a, b)
    if b ~= nil then
        if (a == false or a == nil) and type(b) == 'string' and #b > 0 then
            return true, b
        elseif type(a) == 'string' and #a > 0 then
            return true, a
        else
            return false, nil
        end
    else
        if type(a) == 'string' and #a > 0 then
            return true, a
        elseif type(a) == 'table' then
            local d = (type(a.data)=='string' and a.data) or (type(a.image)=='string' and a.image) or nil
            if d and #d > 0 then return true, d end
        end
        return false, nil
    end
end

local function _try_once(res, src, opts, cb)
    local okCall = pcall(function()
        exports[res]:requestClientScreenshot(src, opts or {}, function(a, b)
            local ok, data = _unpack_shot(a, b)
            if ok and data then
                if type(data) == 'string' and data:sub(1,5) ~= 'data:' then
                    data = ('data:%s;base64,%s'):format('image/jpeg', data)
                end
                cb(true, data)
            else
                cb(false, nil)
            end
        end)
    end)
    if not okCall then cb(false, nil) end
end

-- Nur JPEG, kompakt
local function serverTryCapturePhoto(src, cb)
    local res = detectScreenshotResource()
    if not res then cb(false, nil, 'screenshot export not found/started'); return end
    local attempts = {
        { encoding = 'jpg', quality = JPG_QUALITY },
        { encoding = 'jpg', quality = 0.38 },
        { encoding = 'jpg', quality = 0.30 },
        { }
    }
    local i = 1
    local function nextAttempt()
        if i > #attempts then cb(false, nil, 'all attempts failed'); return end
        local opts = attempts[i]; i = i + 1
        _try_once(res, src, opts, function(ok, data)
            if ok and data then cb(true, data) else nextAttempt() end
        end)
    end
    nextAttempt()
end

-- Upload (Discord Webhook) -> URL speichern
local function tryUploadClientPhotoURL(src, cb)
    if WEBHOOK_URL == '' then cb(false, nil, 'no_webhook'); return end
    local ok = pcall(function()
        exports['screenshot-basic']:requestClientScreenshotUpload(
            src, WEBHOOK_URL, "files[]",
            { encoding = "jpg", quality = JPG_QUALITY },
            function(body)
                local okJ, resp = pcall(function() return json.decode(body or '{}') end)
                if okJ and resp and resp.attachments and resp.attachments[1] and resp.attachments[1].url then
                    cb(true, resp.attachments[1].url)
                else
                    cb(false, nil, 'upload_failed')
                end
            end
        )
    end)
    if not ok then cb(false, nil, 'upload_exception') end
end

-- Foto erfassen + speichern (URL bevorzugt; sonst Base64 mit Cap)
function MTJ_CaptureAndStoreLicensePhoto(src, identifier, category)
    local cat = normalizeCategoryKey(category or 'car')
    if PHOTO_STORE == 'url' and WEBHOOK_URL ~= '' then
        local done, ok, out, err = false, false, nil, nil
        tryUploadClientPhotoURL(src, function(ok1, url, er1)
            ok = ok1
            if ok1 and url then
                cacheSetPhoto(identifier, cat, url)
                if dbEnabled then
                    ensureLicenseTable()
                    pcall(function()
                        MySQL.update([[
                            INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                            VALUES (?, ?, ?)
                            ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                        ]], { identifier, cat, url })
                    end)
                end
                out = { url = url, store = 'url' }
            else
                err = er1 or 'upload_failed'
            end
            done = true
        end)
        local t0 = GetGameTimer()
        while not done and (GetGameTimer() - t0) < 15000 do Wait(50) end
        return ok, out, err or (done and 'timeout' or 'unknown')
    end

    -- Fallback: Base64 klein
    local done, ok, out, err = false, false, nil, nil
    serverTryCapturePhoto(src, function(ok1, data, er1)
        ok = ok1
        if ok1 and data then
            cacheSetPhoto(identifier, cat, data)
            if dbEnabled and #data <= DB_PHOTO_CAP then
                ensureLicenseTable()
                pcall(function()
                    MySQL.update([[
                        INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                        VALUES (?, ?, ?)
                        ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                    ]], { identifier, cat, data })
                end)
            end
            out = { base64 = data, store = 'db' }
        else
            err = er1 or 'capture_failed'
        end
        done = true
    end)
    local t0 = GetGameTimer()
    while not done and (GetGameTimer() - t0) < 10000 do Wait(50) end
    return ok, out, err or (done and 'timeout' or 'unknown')
end

-- ============================================================================
-- AUSWEIS SENDEN (klein) + Foto nachreichen
-- ============================================================================
function sendLicenseCard(ownerSrc, targetSrc, category)
    local cat = normalizeCategoryKey(category)
    local identifier = getIdentifierGeneric(ownerSrc)

    local photo = cacheGetPhoto(identifier, cat)
    if (not photo or #tostring(photo) < 8) and dbEnabled then
        pcall(function()
            local rows = MySQL.query.await('SELECT photo_url FROM mtj_fahrschule_licenses WHERE identifier=? AND category=? LIMIT 1', { identifier, cat })
            if rows and rows[1] and type(rows[1].photo_url) == 'string' then photo = rows[1].photo_url end
        end)
    end

    local person = getIdentity(ownerSrc)
    local validDays = (Config and Config.License and Config.License.ValidDays and Config.License.ValidDays[cat]) or 3650
    local issuedYmd  = os.date('%Y-%m-%d')
    local expiresYmd = ymdAddDays(issuedYmd, validDays)
    local labels = (Config and Config.License and Config.License.Labels) or (Config and Config.Labels) or {}
    local catLabel = (Config and Config.Labels and Config.Labels.Categories and Config.Labels.Categories[cat]) or cat
    local placeholder = (Config and Config.License and Config.License.DefaultPhotoURL) or (Config and (Config.UILogo or Config.LogoURL)) or 'img/logo.png'

    local payload = {
        org       = (Config and Config.License and Config.License.OrganizationName) or 'Fahrschule',
        logo      = (Config and Config.License and Config.License.LogoPath) or (Config and (Config.UILogo or Config.LogoURL)) or 'img/logo.png',
        labels    = labels,
        category  = cat,
        categoryLabel = catLabel,
        person    = { firstname = person.firstname or '', lastname = person.lastname or '', birthdate = person.birthdate or '', height = person.height or '' },
        issuedAt  = dateDisplay(issuedYmd),
        expiresAt = dateDisplay(expiresYmd),
        photo     = placeholder,
        style     = (Config and Config.License and Config.License.Style) or {},
        display   = (Config and Config.License and Config.License.Display) or {},
    }
    TriggerClientEvent(RESOURCE..':client:showLicenseCard', targetSrc, payload)
    TriggerClientEvent(RESOURCE..':client:showLicense',     targetSrc, payload)
    TriggerClientEvent(RESOURCE..':client:license:show',    targetSrc, payload)

    if type(photo) == 'string' and #photo > 8 then
        if photo:sub(1,4) == 'http' then
            TriggerClientEvent(RESOURCE..':client:updateLicensePhoto', targetSrc, photo)
        else
            if #photo <= PHOTO_EVENT_CAP then
                TriggerClientEvent(RESOURCE..':client:updateLicensePhoto', targetSrc, photo)
            else
                TriggerClientEvent(RESOURCE..':client:notify', targetSrc, 'warning', 'Dein Ausweis-Foto ist zu groß. Bitte am Fotopunkt erneut aufnehmen (JPEG).')
            end
        end
    end
end

-- ============================================================================
-- BUCHUNG / THEORIE / PRAXIS
-- ============================================================================
local DEFAULT_BOOKING_EXPIRY = 600

local function saveBookingToDB(identifier, data)
    if not dbEnabled or not identifier then return end
    ensureBookingsTable()
    pcall(function()
        local expiresAt = os.date('%Y-%m-%d %H:%M:%S', data.expires or nowSecs())
        local sql = [[
            INSERT INTO mtj_fahrschule_bookings (identifier, category, token, mode, expires)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE category=VALUES(category), token=VALUES(token), mode=VALUES(mode), expires=VALUES(expires)
        ]]
        MySQL.update(sql, { identifier, data.category, data.token, data.mode, expiresAt })
    end)
end

RegisterNetEvent(RESOURCE..':server:book', function(category, mode)
    local src = source
    if not category or tostring(category) == '' then
        TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'Kategorie fehlt.')
        return
    end
    local cat = normalizeCategoryKey(category)
    mode = normalizeMode(mode)
    tryInitESX()

    if mode == 'praxis' and (Config and Config.SafeModeAntiExploit == true) then
        local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
        local itemName = getTheoryItemName(cat)
        local count = invCount(src, itemName, xPlayer)
        if not (itemName and (count or 0) > 0) then
            local msg = (Config and Config.Labels and Config.Labels.MustPassTheoryFirst) or 'Praxis ist erst nach bestandener Theorie buchbar.'
            TriggerClientEvent(RESOURCE..':client:notify', src, 'error', msg)
            return
        end
    end

    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
    local price = priceFor(cat, mode)
    local okPay, payErr = chargePlayer(xPlayer or src, price)
    if not okPay then
        TriggerClientEvent(RESOURCE..':client:notify', src, 'error', tostring(payErr or 'Bezahlung fehlgeschlagen.'))
        return
    end

    local token = genToken()
    local expiry = nowSecs() + (Config and Config.BookingExpirySeconds or DEFAULT_BOOKING_EXPIRY)
    bookings[src] = { category = cat, token = token, mode = mode, expires = expiry }
    local identifier = getIdentifier(xPlayer) or ('src:'..tostring(src))
    saveBookingToDB(identifier, bookings[src])

    TriggerClientEvent(RESOURCE..':client:booked', src, cat, token)
    TriggerClientEvent(RESOURCE..':client:stateSync', src, { category = cat, token = token })
    local paidMsg = (mode == 'praxis') and (Config and Config.Labels and Config.Labels.PaidPracticeSuccess) or (Config and Config.Labels and Config.Labels.PaidSuccess)
    TriggerClientEvent(RESOURCE..':client:notify', src, 'success', paidMsg or 'Buchung bezahlt.')
    log(('Booked src=%s cat=%s mode=%s price=%s'):format(src, tostring(cat), tostring(mode), tostring(price)))
end)

local function validateBooking(src, category, token)
    local b = bookings[src]
    if not b then return false, 'no_booking' end
    if category and b.category ~= normalizeCategoryKey(category) then return false, 'category_mismatch' end
    if token and b.token ~= token then return false, 'token_mismatch' end
    if b.expires and nowSecs() > b.expires then bookings[src] = nil; return false, 'expired' end
    return true
end

local function canStartPracticeCore(source, category)
    local b = bookings[source]
    if not b then
        return false, (Config and Config.Labels and Config.Labels.MustBookFirst) or 'Bitte zuerst buchen.'
    end
    local cat = normalizeCategoryKey(category or b.category)

    local allowWithPaid = false
    if Config and Config.Practice and type(Config.Practice.AllowStartWithPaidBooking) ~= 'nil' then
        allowWithPaid = (Config.Practice.AllowStartWithPaidBooking == true)
    end

    local safeMode = (Config and Config.SafeModeAntiExploit == true)
    if safeMode and not (b.mode == 'praxis' and allowWithPaid) then
        tryInitESX()
        local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(source) or nil
        local needItem = getTheoryItemName(cat)
        local hasItem = invCount(source, needItem, xPlayer) > 0
        if not hasItem then
            return false, (Config and Config.Labels and Config.Labels.MustPassTheoryFirst) or 'Praxis erst nach Theorie.'
        end
    end

    local vehModel = (Config and Config.Vehicles and Config.Vehicles[cat]) or nil
    local npcModel = (Config and Config.NPCModel) or 's_m_m_autoshop_01'
    return true, nil, (vehModel or true), npcModel, cat
end

-- ESX Callbacks
local function registerESXCallbacks()
    if not ESX or not ESX.RegisterServerCallback then return false end
    if _mtj_esx_callbacks_registered then return true end
    _mtj_esx_callbacks_registered = true

    ESX.RegisterServerCallback(RESOURCE..':server:canStartTheory', function(source, cb, category, token)
        local ok, reason = validateBooking(source, category, token)
        if not ok then cb(false, reason) return end
        cb(true)
    end)

    ESX.RegisterServerCallback(RESOURCE..':server:canStartPractice', function(source, cb, category)
        local ok, reason, vehModel, npcModel = canStartPracticeCore(source, category)
        cb(ok, vehModel, npcModel, reason)
    end)

    log('ESX.RegisterServerCallback handlers registered.')
    return true
end

CreateThread(function()
    Wait(0)
    tryInitESX()
    ensureLicenseTable()
    ensureTheoryPracticeTables()
    ensureBookingsTable()
    if not registerESXCallbacks() then
        local attempts = 0
        while attempts < 20 do
            Wait(500)
            tryInitESX()
            if registerESXCallbacks() then break end
            attempts = attempts + 1
        end
        if not _mtj_esx_callbacks_registered then
            log('WARN: ESX callbacks not registered after startup polling.')
        end
    end
end)

RegisterNetEvent(RESOURCE..':server:canStartPracticeRaw', function(category)
    local src = source
    local ok, reason, vehModel, npcModel = canStartPracticeCore(src, category)
    TriggerClientEvent(RESOURCE..':client:canStartPracticeRawResult', src, ok, reason, vehModel, npcModel)
end)

-- NEU: Praxis-Start (Theorie-Item konsumieren + Watchdog initialisieren)
RegisterNetEvent(RESOURCE..':server:practiceStart', function(category)
    local src = source
    local cat = normalizeCategoryKey(category or 'car')
    tryInitESX()
    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil

    -- Theorie-Item genau 1x entfernen (dein Wunsch)
    local theoryItem = getTheoryItemName(cat)
    if theoryItem then invRemoveOne(src, theoryItem, xPlayer) end

    -- Watchdog-Status initialisieren
    activePractice[src] = {
        category = cat,
        lastSeenMs = nowMs(),
        lastMovingAgeMs = 0,
        lastVehicleAgeMs = 0,
        inVehicle = true,
        exitSinceMs = nil,
        onRoof = false,
        onRoofSinceMs = nil,
        isOnFire = false,
        bodyHealth = nil,
    }
end)

-- Theorie-Result
local function handleTheoryResultCore(src, category, token, passed, pct)
    tryInitESX()
    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
    local identifier = getIdentifier(xPlayer) or ('src:'..tostring(src))
    local cat = normalizeCategoryKey(category)
    local score = tonumber(pct) or 0
    local passedBool = (passed == true)
    local tsStr = os.date('%Y-%m-%d %H:%M:%S')

    local okBooking = validateBooking(src, cat, token)
    if not okBooking then
        local allowNoBooking = not (Config and Config.AllowTheoryGrantWithoutBooking == false)
        if allowNoBooking and passedBool then
            local item = getTheoryItemName(cat)
            if item then invAddOne(src, item, xPlayer) end
        end
    else
        if passedBool then
            local item = getTheoryItemName(cat)
            if item then invAddOne(src, item, xPlayer) end
        end
        bookings[src] = nil
    end

    if dbEnabled and identifier then
        ensureTheoryPracticeTables()
        pcall(function()
            MySQL.update('INSERT INTO mtj_fahrschule_theory (identifier, category, score_pct, created_at) VALUES (?, ?, ?, ?)', { identifier, cat, score, tsStr })
        end)
    end

    lastTheoryById[identifier] = { ts = nowSecs(), category = cat, scorePct = score, passed = passedBool }
    TriggerClientEvent(RESOURCE..':client:theoryOutcome', src, passedBool, score, { ts = nowSecs(), category = cat, scorePct = score })
    TriggerClientEvent(RESOURCE..':client:stateSync', src, { category = nil, token = nil, lastTheory = lastTheoryById[identifier] })
    log('theory '..(passedBool and 'passed' or 'failed')..' src='..src..' cat='..tostring(cat)..' score='..score)
end

RegisterNetEvent(RESOURCE..':server:theoryResult', function(category, token, passed, pct)
    handleTheoryResultCore(source, category, token, passed, pct)
end)
RegisterNetEvent(RESOURCE..':server:theorieResult', function(category, token, passed, pct)
    handleTheoryResultCore(source, category, token, passed, pct)
end)
RegisterNetEvent(RESOURCE..':server:theory_result', function(category, token, passed, pct)
    handleTheoryResultCore(source, category, token, passed, pct)
end)
RegisterNetEvent(RESOURCE..':server:theorie_result', function(category, token, passed, pct)
    handleTheoryResultCore(source, category, token, passed, pct)
end)
RegisterNetEvent(RESOURCE..':server:theoryPassed', function(payloadOrCat, maybeTable)
    local cat, pct = nil, 100
    if type(payloadOrCat) == 'table' then
        local p = payloadOrCat
        cat = tostring(p.category or p.cat or 'car')
        pct = tonumber(p.score or p.scorePct or p.pct) or 100
    else
        cat = tostring(payloadOrCat or 'car')
        if type(maybeTable)=='table' then pct = tonumber(maybeTable.score or maybeTable.scorePct or maybeTable.pct) or 100 end
    end
    handleTheoryResultCore(source, cat, nil, true, pct or 100)
end)

-- Practice outcome scheduling + ACK
local function sendPracticeOutcomeNow(src, passed, errors, summary, detail)
    pcall(function() TriggerClientEvent(RESOURCE..':client:practiceOutcome', src, passed, errors or {}, summary or '', detail or {}) end)
end
local function scheduleOutcomeSend(src, passed, errors, summary, detail)
    local untilTs = uiSuppress[src]
    local now = nowMs()
    if untilTs and now < untilTs then
        local waitMs = untilTs - now + 50
        CreateThread(function() Wait(waitMs); pcall(function() sendPracticeOutcomeNow(src, passed, errors, summary, detail) end) end)
    else
        sendPracticeOutcomeNow(src, passed, errors or {}, summary or '', detail or {})
    end
end

RegisterNetEvent(RESOURCE..':server:resultCloseAck', function()
    local src = source
    local p = pendingOutcomes[src]
    if p then
        scheduleOutcomeSend(src, p.passed, p.errors or {}, p.summary or '', p.detail or {})
        pendingOutcomes[src] = nil
        pendingAckReceived[src] = nil
        return
    end
    pendingAckReceived[src] = true
end)

RegisterNetEvent(RESOURCE..':server:practiceResult', function(category, passed, errorsTbl, summary)
    local src = source
    if bookings[src] then bookings[src] = nil end
    activePractice[src] = nil
    local identifier = getIdentifierGeneric(src)
    local passedBool = (passed == true)
    local cat = normalizeCategoryKey(category)

    if dbEnabled and identifier then
        ensureTheoryPracticeTables()
        local tsStr = os.date('%Y-%m-%d %H:%M:%S')
        local ok = pcall(function()
            MySQL.update('INSERT INTO mtj_fahrschule_practice (identifier, category, summary, passed, created_at, errors_json) VALUES (?, ?, ?, ?, ?, ?)',
                { identifier, cat, tostring(summary or ''), passedBool and 1 or 0, tsStr, (json and json.encode and json.encode(errorsTbl or {})) or nil })
        end)
        if not ok then
            pcall(function()
                MySQL.update('INSERT INTO mtj_fahrschule_practice (identifier, category, summary, passed, created_at) VALUES (?, ?, ?, ?, ?)',
                    { identifier, cat, tostring(summary or ''), passedBool and 1 or 0, tsStr })
            end)
        end
    end

    if passedBool then
        local enrollCfg = (Config and Config.License and Config.License.Enrollment) or {}
        if enrollCfg.Enabled == true then
            pendingEnrollmentById[identifier] = cat
            TriggerClientEvent(RESOURCE..':client:enrollStart', src, cat)
            local msg = (Config and Config.Labels and Config.Labels.EnrollGoToOffice) or 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.'
            TriggerClientEvent(RESOURCE..':client:notify', src, 'info', msg)
            log(('practice passed -> enrollment pending src=%s cat=%s'):format(src, tostring(cat)))
        else
            finalizeLicenseAndItem(identifier, src, cat, nil)
        end
    end

    lastPracticeById[identifier] = { ts = nowSecs(), category = cat, passed = passedBool, summary = tostring(summary or ''), errors = errorsTbl or {} }
    TriggerClientEvent(RESOURCE..':client:stateSync', src, { category = nil, token = nil, lastPractice = lastPracticeById[identifier] })

    pendingOutcomes[src] = { passed = passedBool, errors = errorsTbl or {}, summary = tostring(summary or ''), detail = { ts = nowSecs(), category = cat }, ts = nowMs() }

    if pendingAckReceived[src] then
        scheduleOutcomeSend(src, pendingOutcomes[src].passed, pendingOutcomes[src].errors or {}, pendingOutcomes[src].summary or '', pendingOutcomes[src].detail or {})
        pendingOutcomes[src] = nil
        pendingAckReceived[src] = nil
    else
        CreateThread(function()
            Wait(2000)
            local p = pendingOutcomes[src]
            if p then
                scheduleOutcomeSend(src, p.passed, p.errors or {}, p.summary or '', p.detail or {})
                pendingOutcomes[src] = nil
                pendingAckReceived[src] = nil
            end
        end)
    end

    log('practice scheduled (awaiting ack or fallback) src='..src..' cat='..tostring(cat)..' passed='..tostring(passedBool))
end)

-- ============================================================================
-- HEARTBEAT (Watchdog-Input vom Client)
-- ============================================================================
RegisterNetEvent(RESOURCE..':server:practiceHeartbeat', function(payload)
    local src = source
    local p = activePractice[src]
    if not p then return end
    local nowm = nowMs()
    p.lastSeenMs = nowm
    if type(payload) == 'table' then
        p.lastMovingAgeMs  = tonumber(payload.lastMovingAgeMs or p.lastMovingAgeMs or 0)
        p.lastVehicleAgeMs = tonumber(payload.lastVehicleAgeMs or p.lastVehicleAgeMs or 0)
        local inVeh = (payload.inVehicle == true)
        if p.inVehicle ~= inVeh then
            if not inVeh then
                p.exitSinceMs = p.exitSinceMs or nowm
            else
                p.exitSinceMs = nil
            end
        end
        p.inVehicle = inVeh

        if payload.onRoof ~= nil then
            if payload.onRoof == true then
                p.onRoofSinceMs = p.onRoofSinceMs or nowm
            else
                p.onRoofSinceMs = nil
            end
            p.onRoof = (payload.onRoof == true)
        end
        if payload.isOnFire ~= nil then p.isOnFire = (payload.isOnFire == true) end
        if payload.bodyHealth ~= nil then p.bodyHealth = tonumber(payload.bodyHealth) end
    end
end)

-- ============================================================================
-- EMERGENCY / VEHICLE / UI CONTROL
-- ============================================================================
local function forceAbort(src, reasonKey)
    if not activePractice[src] then return end
    local label = (Config and Config.ErrorNames and Config.ErrorNames[reasonKey]) or 'Abbruch'
    TriggerClientEvent(RESOURCE..':client:practiceForceAbort', src, reasonKey, label)
    activePractice[src] = nil
end

CreateThread(function()
    while true do
        local em = Config and Config.Practice and Config.Practice.Emergency or {}
        local interval = tonumber(em.LoopIntervalMs or 1200)
        if em.Enabled then
            local nowm = nowMs()
            local maxSilentMs      = (tonumber(em.MaxSilentSeconds or 90) * 1000)
            local exitGraceMs      = (tonumber(em.ExitGraceSeconds or 6) * 1000)
            local maxStationaryMs  = (tonumber(em.MaxStationarySeconds or 25) * 1000)
            local roofGraceMs      = (tonumber(em.RoofGraceSeconds or 5) * 1000)

            for src, data in pairs(activePractice) do
                if not data then goto cont end

                -- Feuer / starker Schaden
                if data.isOnFire then forceAbort(src, 'damage'); goto cont end
                if data.bodyHealth and data.bodyHealth <= 20 then forceAbort(src, 'damage'); goto cont end

                -- Auf dem Dach (mit kurzer Gnadenzeit)
                if data.onRoof and data.onRoofSinceMs and (nowm - data.onRoofSinceMs) >= roofGraceMs then
                    forceAbort(src, 'collision'); goto cont
                end

                -- Ausstieg (Gnadenzeit)
                if data.exitSinceMs and ((nowm - data.exitSinceMs) >= exitGraceMs) then
                    forceAbort(src, 'notaustieg'); goto cont
                end

                -- Zu lange Stillstand (basierend auf lastMovingAgeMs vom Heartbeat)
                if data.lastMovingAgeMs and data.lastMovingAgeMs >= maxStationaryMs then
                    forceAbort(src, 'notaustieg'); goto cont
                end

                -- Kein Heartbeat seit zu lange
                local lastSeenAgo = data.lastSeenMs and (nowm - data.lastSeenMs) or math.huge
                if lastSeenAgo >= maxSilentMs then
                    forceAbort(src, 'notaustieg'); goto cont
                end

                ::cont::
            end
        end
        Wait(interval)
    end
end)

RegisterNetEvent(RESOURCE..':server:practiceVehicleSpawned', function(netId)
    local src = source
    if not activePractice[src] then return end
    activePractice[src].vehicleNetId = netId
end)
RegisterNetEvent(RESOURCE..':server:practiceVehicleDestroyed', function(netId)
    local src = source
    if activePractice[src] and activePractice[src].vehicleNetId == netId then activePractice[src].vehicleNetId = nil end
end)

-- Admin close UI
RegisterCommand('mtj_forceclose', function(src, args)
    local target = tonumber(args and args[1])
    local suppressMs = 1500
    if target and target > 0 then
        uiSuppress[target] = nowMs() + suppressMs
        TriggerClientEvent(RESOURCE..':client:closeUI', target, 'server-forceclose')
        log(('Admin forced UI close for src=%s (suppress %dms)'):format(tostring(target), suppressMs))
    else
        for _, pid in ipairs(GetPlayers()) do
            local p = tonumber(pid)
            if p then
                uiSuppress[p]=nowMs()+suppressMs
                TriggerClientEvent(RESOURCE..':client:closeUI', p, 'server-forceclose')
            end
        end
        log(('Admin forced UI close for all players (suppress %dms)'):format(suppressMs))
    end
end, true)

RegisterNetEvent(RESOURCE..':server:forceCloseClientUI', function(targetSrc)
    local src = source
    local t = tonumber(targetSrc)
    local suppressMs = 1500
    if t and t > 0 then
        uiSuppress[t] = nowMs() + suppressMs
        TriggerClientEvent(RESOURCE..':client:closeUI', t, 'server-event-forceclose')
        log(('server:forceCloseClientUI by src=%s -> closing for src=%s'):format(tostring(src), tostring(t)))
    end
end)

-- Bookings cleanup
CreateThread(function()
    while true do
        Wait(60000)
        local t = nowSecs()
        for s, b in pairs(bookings) do
            if b.expires and t > b.expires then
                log('booking expired -> cleanup src='..tostring(s))
                bookings[s] = nil
            end
        end
    end
end)

-- Cleanup on drop
AddEventHandler('playerDropped', function()
    local src = source
    activePractice[src] = nil
    pendingOutcomes[src] = nil
    pendingAckReceived[src] = nil
end)

-- ============================================================================
-- LICENSE / PHOTO SAVE / ENROLLMENT
-- ============================================================================
RegisterNetEvent(RESOURCE..':server:licensePhotoSave', function(category, dataUrl)
    local src = source
    local cat = normalizeCategoryKey(category or '')
    if cat == '' then return end
    if type(dataUrl) ~= 'string' or #dataUrl < 32 then return end
    local identifier = getIdentifierGeneric(src)

    cacheSetPhoto(identifier, cat, dataUrl)
    if dbEnabled and #dataUrl <= DB_PHOTO_CAP then
        ensureLicenseTable()
        pcall(function()
            MySQL.update([[
                INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
            ]], { identifier, cat, dataUrl })
        end)
    end
    log(('license photo saved id=%s cat=%s bytes=%d (db=%s)'):format(identifier, cat, #dataUrl, (dbEnabled and (#dataUrl<=DB_PHOTO_CAP)) and 'yes' or 'no'))
end)

RegisterNetEvent(RESOURCE..':server:enrollComplete', function(category, dataUrlOrUrl)
    local src = source
    local identifier = getIdentifierGeneric(src)
    local pendingCat = pendingEnrollmentById[identifier]
    if not pendingCat then
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Kein ausstehender Einschreibungsvorgang.')
        return
    end
    local cat = normalizeCategoryKey(pendingCat)
    local v = tostring(dataUrlOrUrl or '')

    if v == '' then
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Foto erforderlich.')
        return
    end

    if v:sub(1,4) == 'http' then
        cacheSetPhoto(identifier, cat, v)
        if dbEnabled then
            ensureLicenseTable()
            pcall(function()
                MySQL.update([[
                    INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                ]], { identifier, cat, v })
            end)
        end
        finalizeLicenseAndItem(identifier, src, cat, v)
    else
        if #v > DB_PHOTO_CAP then
            TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Foto zu groß. Bitte JPEG erneut aufnehmen.')
            return
        end
        cacheSetPhoto(identifier, cat, v)
        if dbEnabled then
            ensureLicenseTable()
            pcall(function()
                MySQL.update([[
                    INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                ]], { identifier, cat, v })
            end)
        end
        finalizeLicenseAndItem(identifier, src, cat, v)
    end

    pendingEnrollmentById[identifier] = nil
    TriggerClientEvent(RESOURCE..':client:enrollDone', src, true, 'Foto gespeichert. Führerschein ausgestellt!')
    if Config and Config.License and Config.License.Enabled then
        sendLicenseCard(src, src, cat)
    end
end)

RegisterNetEvent(RESOURCE..':server:enrollCaptureNow', function(_ignored)
    local src = source
    local identifier = getIdentifierGeneric(src)
    local pendingCat = pendingEnrollmentById[identifier]
    if not pendingCat then
        TriggerClientEvent(RESOURCE..':client:enrollDenied', src, 'Kein ausstehender Einschreibungsvorgang.')
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Kein ausstehender Einschreibungsvorgang.')
        TriggerClientEvent(RESOURCE..':client:photoCleanup', src)
        return
    end
    TriggerClientEvent(RESOURCE..':client:photoPrepare', src)
end)

RegisterNetEvent(RESOURCE..':server:photoPrepared', function()
    local src = source
    local identifier = getIdentifierGeneric(src)
    local pendingCat = pendingEnrollmentById[identifier]
    if not pendingCat then
        TriggerClientEvent(RESOURCE..':client:photoCleanup', src)
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Kein ausstehender Einschreibungsvorgang.')
        return
    end
    local cat = normalizeCategoryKey(pendingCat)

    local ok, out, err = MTJ_CaptureAndStoreLicensePhoto(src, identifier, cat)
    TriggerClientEvent(RESOURCE..':client:photoCleanup', src)

    if not ok then
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, false, 'Fotoaufnahme fehlgeschlagen. Bitte erneut versuchen.')
        return
    end

    local savedRef = (out and (out.url or out.base64)) or nil
    finalizeLicenseAndItem(identifier, src, cat, savedRef)
    pendingEnrollmentById[identifier] = nil

    TriggerClientEvent(RESOURCE..':client:enrollDone', src, true, 'Foto gespeichert. Führerschein ausgestellt!')
    if Config and Config.License and Config.License.Enabled then
        sendLicenseCard(src, src, cat)
    end
end)

-- ============================================================================
-- ENROLL VIA URL (kleine Bilder als Data-URL speichern)
-- ============================================================================
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_encode(data)
    if not data or #data == 0 then return '' end
    local out = {}
    local len = #data
    local i = 1
    while i <= len - 2 do
        local a, c, d = data:byte(i, i+2)
        local triple = a * 65536 + c * 256 + d
        local c1 = math.floor(triple / 262144)
        local c2 = math.floor(triple / 4096) % 64
        local c3 = math.floor(triple / 64) % 64
        local c4 = triple % 64
        out[#out+1] = b64chars:sub(c1+1,c1+1) .. b64chars:sub(c2+1,c2+1) .. b64chars:sub(c3+1,c3+1) .. b64chars:sub(c4+1,c4+1)
        i = i + 3
    end
    local rem = len - (i - 1)
    if rem == 1 then
        local a = data:byte(i)
        local triple = a * 65536
        local c1 = math.floor(triple / 262144)
        local c2 = math.floor(triple / 4096) % 64
        out[#out+1] = b64chars:sub(c1+1,c1+1) .. b64chars:sub(c2+1,c2+1) .. '=='
    elseif rem == 2 then
        local a,b = data:byte(i,i+1)
        local triple = a * 65536 + b * 256
        local c1 = math.floor(triple / 262144)
        local c2 = math.floor(triple / 4096) % 64
        local c3 = math.floor(triple / 64) % 64
        out[#out+1] = b64chars:sub(c1+1,c1+1) .. b64chars:sub(c2+1,c2+1) .. b64chars:sub(c3+1,c3+1) .. '='
    end
    return table.concat(out)
end

local function guess_mime(url, headers)
    if headers and type(headers) == 'table' then
        for k,v in pairs(headers) do
            if type(k) == 'string' and k:lower() == 'content-type' and type(v) == 'string' then
                return v
            end
        end
    end
    local ext = tostring(url):match('%.([a-zA-Z0-9]+)$') or ''
    ext = ext:lower()
    if ext == 'png' then return 'image/png' end
    if ext == 'jpg' or ext == 'jpeg' then return 'image/jpeg' end
    if ext == 'gif' then return 'image/gif' end
    return 'application/octet-stream'
end

RegisterCommand('mtj_enroll_url', function(src, args)
    local caller = src
    if caller <= 0 then
        print('usage (ingame): /mtj_enroll_url <image_url> [category]')
        return
    end
    local url = tostring(args[1] or '')
    if url == '' then
        TriggerClientEvent(RESOURCE..':client:notify', caller, 'error', 'Usage: /mtj_enroll_url <image_url> [category]')
        return
    end
    local category = normalizeCategoryKey(args[2] or 'car')
    local ENROLL_ALLOW_ALL_LOCAL = (GetConvar('mtj_enroll_allow_all', '0') == '1')
    local hasAce = IsPlayerAceAllowed and IsPlayerAceAllowed(caller, 'mtj.fahrschule.enroll')
    if not hasAce and not ENROLL_ALLOW_ALL_LOCAL then
        TriggerClientEvent(RESOURCE..':client:notify', caller, 'error', 'Keine Berechtigung.')
        return
    end

    PerformHttpRequest(url, function(code, body, headers)
        if code ~= 200 or type(body) ~= 'string' or #body == 0 then
            TriggerClientEvent(RESOURCE..':client:notify', caller, 'error', 'Bild konnte nicht geladen werden (HTTP '..tostring(code)..').')
            return
        end
        if #body > (DB_PHOTO_CAP - 1024) then
            TriggerClientEvent(RESOURCE..':client:notify', caller, 'error', 'Bild zu groß. Max ~'..math.floor(DB_PHOTO_CAP/1024)..'KB.')
            return
        end
        local mime = guess_mime(url, headers)
        local ok, b64 = pcall(function() return base64_encode(body) end)
        if not ok or not b64 or #b64 == 0 then
            TriggerClientEvent(RESOURCE..':client:notify', caller, 'error', 'Base64-Konvertierung fehlgeschlagen.')
            return
        end
        local dataUrl = ('data:%s;base64,%s'):format(mime, b64)
        local identifier = getIdentifierGeneric(caller)
        cacheSetPhoto(identifier, category, dataUrl)
        if dbEnabled then
            ensureLicenseTable()
            pcall(function()
                MySQL.update([[
                    INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                ]], { identifier, category, dataUrl })
            end)
        end
        finalizeLicenseAndItem(identifier, caller, category, dataUrl)
        pendingEnrollmentById[identifier] = nil
        TriggerClientEvent(RESOURCE..':client:enrollDone', caller, true, (Config and Config.Labels and Config.Labels.EnrollDone) or 'Foto gespeichert. Führerschein ausgestellt!')
        if Config and Config.License and Config.License.Enabled then
            sendLicenseCard(caller, caller, category)
        end
        log(('enroll_url ok src=%s id=%s cat=%s bytes=%d'):format(tostring(caller), identifier, category, #dataUrl))
    end, 'GET', '', { ['User-Agent'] = RESOURCE..'/1.0' })
end, false)

RegisterNetEvent(RESOURCE..':server:enrollUrl', function(url, category)
    local src = source
    local urlS = tostring(url or '')
    if urlS == '' then
        TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'URL fehlt.')
        return
    end
    local cat = normalizeCategoryKey(category or 'car')
    local ENROLL_ALLOW_ALL_LOCAL = (GetConvar('mtj_enroll_allow_all', '0') == '1')
    local hasAce = IsPlayerAceAllowed and IsPlayerAceAllowed(src, 'mtj.fahrschule.enroll')
    if not hasAce and not ENROLL_ALLOW_ALL_LOCAL then
        TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'Keine Berechtigung.')
        return
    end

    PerformHttpRequest(urlS, function(code, body, headers)
        if code ~= 200 or type(body) ~= 'string' or #body == 0 then
            TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'Bild konnte nicht geladen werden (HTTP '..tostring(code)..').')
            return
        end
        if #body > (DB_PHOTO_CAP - 1024) then
            TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'Bild zu groß. Max ~'..math.floor(DB_PHOTO_CAP/1024)..'KB.')
            return
        end
        local mime = guess_mime(urlS, headers)
        local ok, b64 = pcall(function() return base64_encode(body) end)
        if not ok or not b64 or #b64 == 0 then
            TriggerClientEvent(RESOURCE..':client:notify', src, 'error', 'Base64-Konvertierung fehlgeschlagen.')
            return
        end
        local dataUrl = ('data:%s;base64,%s'):format(mime, b64)
        local identifier = getIdentifierGeneric(src)
        cacheSetPhoto(identifier, cat, dataUrl)
        if dbEnabled then
            ensureLicenseTable()
            pcall(function()
                MySQL.update([[
                    INSERT INTO mtj_fahrschule_licenses (identifier, category, photo_url)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE photo_url=VALUES(photo_url)
                ]], { identifier, cat, dataUrl })
            end)
        end
        finalizeLicenseAndItem(identifier, src, cat, dataUrl)
        pendingEnrollmentById[identifier] = nil
        TriggerClientEvent(RESOURCE..':client:enrollDone', src, true, (Config and Config.Labels and Config.Labels.EnrollDone) or 'Foto gespeichert. Führerschein ausgestellt!')
        if Config and Config.License and Config.License.Enabled then
            sendLicenseCard(src, src, cat)
        end
        log(('enroll_url ok src=%s id=%s cat=%s bytes=%d'):format(tostring(src), identifier, cat, #dataUrl))
    end, 'GET', '', { ['User-Agent'] = RESOURCE..'/1.0' })
end)

-- ============================================================================
-- USEABLE LICENSE-ITEMS / KOMMANDOS (ESX + ox_inventory Fallback ohne Export)
-- ============================================================================
local OX_ITEM_MAP = {}
local OX_USED_HANDLER_READY = false

local function buildItemCategoryMap()
    local map = {}
    if Config and Config.License and Config.License.UsePracticeItems and Config.Items and Config.Items.practice then
        for cat, itm in pairs(Config.Items.practice) do map[itm] = cat end
    elseif Config and Config.License and Config.License.Items then
        for cat, itm in pairs(Config.License.Items) do map[itm] = cat end
    elseif Config and Config.Items and Config.Items.practice then
        for cat, itm in pairs(Config.Items.practice) do map[itm] = cat end
    end
    return map
end

local function getNearestPlayer(src, maxDist)
    maxDist = tonumber(maxDist) or 4.5
    local srcPed = GetPlayerPed(src); if not srcPed or srcPed == 0 then return nil end
    local sx,sy,sz = table.unpack(GetEntityCoords(srcPed))
    local nearest, best = nil, maxDist + 0.001
    for _, pid in ipairs(GetPlayers()) do
        local p = tonumber(pid)
        if p and p ~= src then
            local ped = GetPlayerPed(p)
            if ped and ped ~= 0 then
                local x,y,z = table.unpack(GetEntityCoords(ped))
                local dx,dy,dz = x-sx, y-sy, z-sz
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                if dist < best then nearest, best = p, dist end
            end
        end
    end
    return nearest
end

-- Nur Event-basierter Fallback, kein RegisterUsableItem-Aufruf!
local function ensureOxUsedHandler()
    if OX_USED_HANDLER_READY then return end
    if not (exports and exports.ox_inventory) then return end

    local function handler(...)
        local args = { ... }
        local src = tonumber(args[1]) or source
        local itemName = args[2]

        if type(itemName) == 'table' then
            if itemName.name then
                itemName = tostring(itemName.name)
            elseif itemName[1] and itemName[1].name then
                itemName = tostring(itemName[1].name)
            else
                itemName = nil
            end
        end
        if type(itemName) ~= 'string' then return end

        local cat = OX_ITEM_MAP[itemName]
        if not cat then return end

        local showCfg = (Config and Config.License and Config.License.Show) or {}
        local toSelf  = (showCfg.ShowToSelfOnUse ~= false)
        local nearest = getNearestPlayer(src, showCfg.MaxDistance or 4.5)
        if toSelf then sendLicenseCard(src, src, normalizeCategoryKey(cat)) end
        if nearest then sendLicenseCard(src, nearest, normalizeCategoryKey(cat)) end
    end

    -- Beide Varianten hooken (verschiedene ox_inventory Versionen)
    AddEventHandler('ox_inventory:usedItem', handler)
    AddEventHandler('ox_inventory:useItem',  handler)

    OX_USED_HANDLER_READY = true
    log('ox_inventory fallback usedItem handlers registered')
end

local function registerUseableLicenseItems()
    local itemMap = buildItemCategoryMap()
    if not itemMap or next(itemMap) == nil then
        log('registerUseableLicenseItems: keine Items in Config gefunden')
        return
    end
    OX_ITEM_MAP = itemMap

    tryInitESX()

    -- ESX usable
    if ESX and ESX.RegisterUsableItem then
        for item, cat in pairs(itemMap) do
            ESX.RegisterUsableItem(item, function(source)
                local showCfg = (Config and Config.License and Config.License.Show) or {}
                local toSelf  = (showCfg.ShowToSelfOnUse ~= false)
                local nearest = getNearestPlayer(source, showCfg.MaxDistance or 4.5)
                if toSelf then sendLicenseCard(source, source, normalizeCategoryKey(cat)) end
                if nearest then sendLicenseCard(source, nearest, normalizeCategoryKey(cat)) end
            end)
        end
        if json and json.encode then log('Usable-Items (ESX) registriert: '..json.encode(itemMap)) end
    end

    -- ox_inventory: immer nur Event-Fallback (kein Export-Aufruf, um deinen Fehler zu vermeiden)
    ensureOxUsedHandler()
end

local function parseCategory(arg)
    if not arg then return nil end
    arg = tostring(arg):lower()
    local map = { car={'car','auto','pkw'}, bike={'bike','moto','motorrad'}, truck={'truck','lkw'}, heli={'heli','hubschrauber','hubi'}, plane={'plane','flugzeug'} }
    for cat, list in pairs(map) do for _, key in ipairs(list) do if arg == key then return cat end end end
    return nil
end

local function registerLicenseCommands()
    if not (Config and Config.License and Config.License.Show and Config.License.Show.CommandName) then return end
    local base = Config.License.Show.CommandName
    local function addCmd(name)
        RegisterCommand(name, function(src, args)
            if src <= 0 then return end
            local catArg = parseCategory(args[1])
            local tgtArg = tonumber(args[2])
            local showCfg = (Config and Config.License and Config.License.Show) or {}
            local cat = normalizeCategoryKey(catArg or 'car')
            local target = tgtArg or getNearestPlayer(src, showCfg.MaxDistance or 4.5)
            if target then sendLicenseCard(src, target, cat) end
            if showCfg.ShowToSelfOnUse ~= false then sendLicenseCard(src, src, cat) end
        end, false)
    end
    addCmd(base)
    local aliases = (Config and Config.License and Config.License.Show and Config.License.Show.Alias) or {}
    for _, a in ipairs(aliases) do addCmd(a) end
end

CreateThread(function()
    Wait(500)
    ensureLicenseTable()
    ensureTheoryPracticeTables()
    ensureBookingsTable()
    if Config and Config.License and Config.License.Enabled then
        registerUseableLicenseItems()
        registerLicenseCommands()
        log('License module initialisiert (Useable Items + Command)')
    end
    log(('server/main geladen. ESX=%s oxmysql=%s DBEnabled=%s'):format(tostring(ESX~=nil), tostring(hasOxmysql), tostring(dbEnabled)))
end)

RegisterCommand('mtj_license_reload', function(src)
    if src ~= 0 then return end
    registerUseableLicenseItems()
    registerLicenseCommands()
    print('[mtj_fahrschule] License reloaded')
end, true)