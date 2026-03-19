-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- Persistenz für Foto-Einschreibung (pending enrollment) über Reconnects
-- Voraussetzung: Config.License.Enrollment.Enabled = true
-- Optional: Config.License.Enrollment.PersistPending = true (sonst nur In-Memory)
-- Diese Datei:
--  - legt eine kleine DB-Tabelle für ausstehende Foto-Termine an
--  - merkt sich pending-Einschreibungen bei Praxis-Bestanden
--  - setzt pending nach Reconnect automatisch fort und startet den Client-Flow
--  - entfernt pending nach erfolgreichem Foto-Abschluss

local RESOURCE = (Config and Config.ResourceName) or 'mtj_fahrschule'
local ESX, QBCore = nil, nil

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

local function tryInitQBCore()
    if QBCore then return QBCore end
    local ok, obj = pcall(function()
        if type(GetResourceState) == 'function' and GetResourceState('qb-core') == 'started' then
            if exports and exports['qb-core'] and type(exports['qb-core'].GetCoreObject) == 'function' then
                return exports['qb-core']:GetCoreObject()
            end
        end
        return nil
    end)
    if ok and obj then QBCore = obj; return QBCore end
    return QBCore
end

tryInitESX()
tryInitQBCore()

-- DB enable
local hasOxmysql = (type(GetResourceState) == 'function' and GetResourceState('oxmysql') == 'started')
if hasOxmysql and type(MySQL) ~= 'table' then
    print(('[%s][server/enroll_persist] WARN: oxmysql aktiv aber MySQL global fehlt -> Persistenz deaktiviert'):format(RESOURCE))
    hasOxmysql = false
end
local dbEnabled = hasOxmysql and not (Config and Config.DBDisabled)

local function log(...)
    local parts = {}
    for i=1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end
    print(('[%s][server/enroll_persist] %s'):format(RESOURCE, table.concat(parts, ' ')))
end

-- Identifier helper (unabhängig von server/main.lua)
local function getIdentifierGeneric(src)
    tryInitESX(); tryInitQBCore()
    local id = nil
    if ESX and ESX.GetPlayerFromId then
        local ok, xP = pcall(function() return ESX.GetPlayerFromId(src) end)
        if ok and xP then
            if xP.identifier then id = xP.identifier end
            if (not id) and xP.getIdentifier then
                local ok2, id2 = pcall(function() return xP.getIdentifier() end)
                if ok2 and id2 then id = id2 end
            end
        end
    end
    if not id and QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local ok, qbP = pcall(function() return QBCore.Functions.GetPlayer(src) end)
        if ok and qbP and qbP.PlayerData and qbP.PlayerData.citizenid then
            id = qbP.PlayerData.citizenid
        end
    end
    return id or ('src:'..tostring(src))
end

-- Tabelle für Pending-Einschreibung
local function ensureEnrollTable()
    if not dbEnabled then return end
    pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mtj_fahrschule_enroll_pending (
              identifier VARCHAR(64) PRIMARY KEY,
              category   VARCHAR(16) NOT NULL,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {})
    end)
end

local function persistPending(identifier, category)
    if not dbEnabled or not identifier or identifier == '' then return end
    ensureEnrollTable()
    pcall(function()
        MySQL.update([[
            INSERT INTO mtj_fahrschule_enroll_pending (identifier, category)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE category=VALUES(category), created_at=CURRENT_TIMESTAMP
        ]], { identifier, tostring(category or 'car') })
    end)
end

local function clearPending(identifier)
    if not dbEnabled or not identifier or identifier == '' then return end
    pcall(function()
        MySQL.update('DELETE FROM mtj_fahrschule_enroll_pending WHERE identifier=?', { identifier })
    end)
end

local function fetchPending(identifier)
    if not dbEnabled or not identifier or identifier == '' then return nil end
    local rows = nil
    local ok = pcall(function()
        rows = MySQL.query.await('SELECT category FROM mtj_fahrschule_enroll_pending WHERE identifier=? LIMIT 1', { identifier })
    end)
    if ok and rows and rows[1] and rows[1].category then
        return tostring(rows[1].category)
    end
    return nil
end

local function notify(src, level, text, dur)
    local duration = dur or (Config and Config.NotifyDuration) or 5000
    pcall(function() TriggerClientEvent(RESOURCE..':client:notify', src, level or 'info', tostring(text or ''), duration) end)
end

-- Praxis-Result abhören, um Pending zu persistieren
RegisterNetEvent(RESOURCE..':server:practiceResult', function(category, passed, errorsTbl, summary)
    local src = source
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Enabled) then return end
    if not (Config.License.Enrollment.PersistPending == true) then return end
    if passed ~= true then return end
    local identifier = getIdentifierGeneric(src)
    persistPending(identifier, tostring(category or 'car'))
    log(('persisted pending after pass id=%s cat=%s'):format(identifier, tostring(category)))
end)

-- Foto-Abschluss: Pending löschen
RegisterNetEvent(RESOURCE..':server:enrollComplete', function(category, dataUrl)
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Enabled) then return end
    local src = source
    local identifier = getIdentifierGeneric(src)
    clearPending(identifier)
    log(('cleared pending on enrollComplete id=%s'):format(identifier))
end)

-- Reconnect-Resume (ESX/QB Events)
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Enabled) then return end
    if not (Config.License.Enrollment.PersistPending == true) then return end
    local src = tonumber(playerId)
    if not src or src <= 0 then return end
    local identifier = getIdentifierGeneric(src)
    local cat = fetchPending(identifier)
    if cat then
        -- In-Memory Pending im main setzen (wenn Handler existiert), dann Client starten
        TriggerEvent(RESOURCE..':server:_enrollMarkPending', identifier, cat)
        TriggerClientEvent(RESOURCE..':client:enrollStart', src, cat)
        notify(src, 'info', (Config and Config.Labels and Config.Labels.EnrollGoToOffice) or 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.', 8000)
        log(('resume pending (ESX) src=%s id=%s cat=%s'):format(src, identifier, cat))
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Enabled) then return end
    if not (Config.License.Enrollment.PersistPending == true) then return end
    local src = Player and Player.PlayerData and Player.PlayerData.source or nil
    if not src or src <= 0 then return end
    local identifier = getIdentifierGeneric(src)
    local cat = fetchPending(identifier)
    if cat then
        TriggerEvent(RESOURCE..':server:_enrollMarkPending', identifier, cat)
        TriggerClientEvent(RESOURCE..':client:enrollStart', src, cat)
        notify(src, 'info', (Config and Config.Labels and Config.Labels.EnrollGoToOffice) or 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.', 8000)
        log(('resume pending (QB) src=%s id=%s cat=%s'):format(src, identifier, cat))
    end
end)

-- Fallback: Beim Resource-Start bereits verbundene Spieler prüfen
CreateThread(function()
    Wait(1500)
    if not (Config and Config.License and Config.License.Enrollment and Config.License.Enrollment.Enabled) then return end
    if not (Config.License.Enrollment.PersistPending == true) then return end
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src and src > 0 then
            local identifier = getIdentifierGeneric(src)
            local cat = fetchPending(identifier)
            if cat then
                TriggerEvent(RESOURCE..':server:_enrollMarkPending', identifier, cat)
                TriggerClientEvent(RESOURCE..':client:enrollStart', src, cat)
                notify(src, 'info', (Config and Config.Labels and Config.Labels.EnrollGoToOffice) or 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.', 8000)
                log(('resume pending (startup) src=%s id=%s cat=%s'):format(src, identifier, cat))
            end
        end
    end
end)

-- Optional: Admin-Befehle
RegisterCommand('mtj_enroll_list', function(src)
    if src ~= 0 then return end
    if not dbEnabled then print('[mtj_fahrschule][enroll_persist] DB disabled') return end
    ensureEnrollTable()
    local rows = MySQL.query.await('SELECT identifier, category, created_at FROM mtj_fahrschule_enroll_pending ORDER BY created_at DESC')
    print('[mtj_fahrschule][enroll_persist] Pending rows:')
    if rows then
        for _, r in ipairs(rows) do
            print(string.format(' - %s | %s | %s', tostring(r.identifier), tostring(r.category), tostring(r.created_at)))
        end
    end
end, true)

RegisterCommand('mtj_enroll_clear', function(src, args)
    if src ~= 0 then return end
    local id = args and args[1]
    if not id or id == '' then
        print('usage: mtj_enroll_clear <identifier>')
        return
    end
    clearPending(id)
    print('[mtj_fahrschule][enroll_persist] cleared for '..id)
end, true)