-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- Zentraler Bridge (optional): Bietet eine einheitliche Capture-Funktion für andere Server-Dateien.
-- Nutzt screenshot-basic mit offizieller Signatur (err=false, data). JPEG bevorzugt.

local RESOURCE = GetCurrentResourceName()
local DEBUG = (GetConvar('mtj_photo_debug', '0') == '1')
local function dbg(...)
    if not DEBUG then return end
    local parts = {}
    for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    print(('[%s][shot] %s'):format(RESOURCE, table.concat(parts, ' ')))
end

local _shot_res = nil
local function detectScreenshotResource()
    if _shot_res then return _shot_res end
    local forced = (GetConvar and GetConvar('mtj_photo_res', '') or '')
    if forced ~= '' and type(GetResourceState) == 'function' and GetResourceState(forced) == 'started' then
        if exports and exports[forced] and type(exports[forced].requestClientScreenshot) == 'function' then
            _shot_res = forced; dbg('res=', _shot_res); return _shot_res
        end
    end
    local aliases = { 'screenshot-basic', 'screenshot_basic' }
    for _, name in ipairs(aliases) do
        if type(GetResourceState) == 'function' and GetResourceState(name) == 'started' then
            if exports and exports[name] and type(exports[name].requestClientScreenshot) == 'function' then
                _shot_res = name; dbg('res=', _shot_res); return _shot_res
            end
        end
    end
    for resName, ex in pairs(exports or {}) do
        if type(ex) == 'table' and type(ex.requestClientScreenshot) == 'function' then
            if type(GetResourceState) == 'function' and GetResourceState(resName) == 'started' then
                _shot_res = resName; dbg('res=', _shot_res); return _shot_res
            end
        end
    end
    return nil
end

local function unpackShot(a, b)
    if b ~= nil then
        if type(a) == 'boolean' or a == nil or type(a) == 'string' then
            local success = ((a == false) or (a == nil)) and type(b) == 'string' and #b > 0
            return success, success and b or nil, (success and nil or tostring(a or 'capture-failed'))
        elseif type(a) == 'string' then
            return true, a, nil
        end
        return false, nil, 'unknown-callback-format'
    else
        if type(a) == 'string' and #a > 0 then return true, a, nil end
        if type(a) == 'table' then
            local s = (type(a.data) == 'string' and a.data) or (type(a.image) == 'string' and a.image) or nil
            if s and #s > 0 then return true, s, nil end
            return false, nil, 'empty-data-table'
        end
        return false, nil, 'unknown-callback-format'
    end
end

local function tryOnce(res, src, opts, cb)
    local okCall, err = pcall(function()
        exports[res]:requestClientScreenshot(src, opts or {}, function(a, b)
            local ok, data, errStr = unpackShot(a, b)
            if ok and data then
                local mime = (opts and opts.encoding == 'png') and 'image/png' or 'image/jpeg'
                if data:sub(1,5) ~= 'data:' then
                    data = ('data:%s;base64,%s'):format(mime, data)
                end
                dbg('ok len=', #data)
                cb(true, data, nil)
            else
                dbg('fail err=', tostring(errStr))
                cb(false, nil, tostring(errStr or 'capture failed'))
            end
        end)
    end)
    if not okCall then
        dbg('exc ', tostring(err))
        cb(false, nil, 'exception:'..tostring(err))
    end
end

local function bridgeCapture(src, preferPng, cb)
    local res = detectScreenshotResource()
    if not res then cb(false, nil, 'screenshot export not found/started') return end

    local qualities = { 0.78, 0.65, 0.5 }
    local attempts = {}

    if preferPng then
        attempts[#attempts+1] = { encoding = 'png', quality = 0.85 }
        for _, q in ipairs(qualities) do attempts[#attempts+1] = { encoding = 'jpg', quality = q } end
    else
        for _, q in ipairs(qualities) do attempts[#attempts+1] = { encoding = 'jpg', quality = q } end
        attempts[#attempts+1] = { encoding = 'png', quality = 0.85 }
    end
    attempts[#attempts+1] = { }

    local maxB = 1.6 * 1024 * 1024
    local i = 1
    local function next()
        if i > #attempts then cb(false, nil, 'all attempts failed') return end
        local opts = attempts[i]; i = i + 1
        tryOnce(res, src, opts, function(ok, dataUrl, err)
            if not ok or not dataUrl then next() return end
            if #dataUrl > maxB then next() return end
            cb(true, dataUrl, nil)
        end)
    end
    next()
end

-- Exponieren
_G.ScreenshotBridge_Capture = bridgeCapture
_G.ScreenshotBridge_Detect = detectScreenshotResource

-- Falls main.lua keine eigene Funktion setzt, biete unseren Bridge-Wrapper als Fallback an
if type(serverTryCapturePhoto) ~= 'function' then
    serverTryCapturePhoto = function(src, cb, preferPng)
        bridgeCapture(src, preferPng, cb)
    end
end