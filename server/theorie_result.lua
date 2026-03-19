-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- server/theorie_result.lua — Theory pass recognition + item grant (ESX/QBCore/ox_inventory)
-- Robust to payload shapes and event name variants. Grants theory cert item once on pass.

local RESNAME = (Config and Config.ResourceName) or (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'
local function ev(path) return RESNAME .. ':' .. path end

-- ESX/QBCore lazy init
local ESX, QBCore = nil, nil
local function getESX()
  if ESX then return ESX end
  pcall(function()
    if GetResourceState and GetResourceState('es_extended') == 'started' then
      if exports and exports['es_extended'] and exports['es_extended'].getSharedObject then
        ESX = exports['es_extended']:getSharedObject()
      end
    end
  end)
  if not ESX then pcall(function() TriggerEvent('esx:getSharedObject', function(o) ESX = o end) end) end
  return ESX
end
local function getQBCore()
  if QBCore then return QBCore end
  pcall(function()
    if GetResourceState and GetResourceState('qb-core') == 'started' then
      if exports and exports['qb-core'] and exports['qb-core'].GetCoreObject then
        QBCore = exports['qb-core']:GetCoreObject()
      end
    end
  end)
  return QBCore
end

local function sLog(level, msg)
  local pfx = string.format('[%s][server]%s ', RESNAME, level and ('['..tostring(level)..']') or '')
  print(pfx .. tostring(msg or ''))
end

-- Inventory helpers
local function safeHasItem_ESX(xPlayer, item)
  local inv = nil
  if xPlayer and xPlayer.getInventoryItem then inv = xPlayer:getInventoryItem(item) end
  if not inv and xPlayer and xPlayer.getInventoryItem then inv = xPlayer.getInventoryItem(item) end
  local count = (inv and inv.count) or 0
  return (count and count > 0) or false, count
end

local function safeAddItemToPlayer(src, item, amount)
    local added = false
    amount = tonumber(amount) or 1
    if amount <= 0 or not item or item == '' then return false end

    -- ESX: verify item count actually increased after the call
    pcall(function()
        local esx = getESX()
        if esx and esx.GetPlayerFromId then
            local xPlayer = esx.GetPlayerFromId(src)
            if xPlayer then
                local before = 0
                pcall(function()
                    local it = xPlayer.getInventoryItem and xPlayer.getInventoryItem(item)
                    before = (it and (it.count or it.quantity or it.amount)) or 0
                end)
                if type(xPlayer.addInventoryItem) == 'function' then
                    xPlayer.addInventoryItem(item, amount)
                elseif type(xPlayer.addItem) == 'function' then
                    xPlayer.addItem(item, amount)
                else
                    return
                end
                local after = 0
                pcall(function()
                    local it = xPlayer.getInventoryItem and xPlayer.getInventoryItem(item)
                    after = (it and (it.count or it.quantity or it.amount)) or 0
                end)
                if after > before then added = true end
            end
        end
    end)

    -- QBCore
    if not added then
        pcall(function()
            local qb = getQBCore()
            if qb and qb.Functions and qb.Functions.GetPlayer then
                local Player = qb.Functions.GetPlayer(src)
                if Player and Player.Functions and type(Player.Functions.AddItem) == 'function' then
                    Player.Functions.AddItem(item, amount); added = true; return
                end
            end
        end)
    end

    -- ox_inventory
    if not added and exports and exports.ox_inventory then
        pcall(function()
            if type(exports.ox_inventory.AddItem) == 'function' then
                exports.ox_inventory:AddItem(src, item, amount); added = true; return
            elseif type(exports.ox_inventory.addItem) == 'function' then
                exports.ox_inventory.addItem(src, item, amount); added = true; return
            end
        end)
    end

    return added
end

-- Duplicate guard per player
local lastGrant = {} -- [src] = { t = ms, key = 'pass:cat:total:correct:used' }

local function theoryItemForCategory(cat)
  return Config and Config.Items and Config.Items.theory and (Config.Items.theory[cat] or Config.Items.theory.default) or nil
end

local function parsePayload(args)
  -- Returns: cat, passedFlag, stats
  local cat, passedFlag, stats = 'car', false, {}
  local a,b,c,d,e = table.unpack(args)

  if type(a) == 'table' and b == nil then
    local p = a
    cat = tostring(p.category or p.cat or p.categoryKey or 'car'):lower()
    passedFlag = (p.passed == true) or (p.success == true) or (tostring(p.passed) == 'true')
    if type(p.stats) == 'table' then
      stats = p.stats
    else
      stats.totalQuestions = p.totalQuestions or p.total or p.t
      stats.correctAnswers = p.correctAnswers or p.correct or p.c
      stats.usedSeconds    = p.usedSeconds or p.used or p.u
      stats.scorePct       = p.score or p.scorePct or p.s
    end
  elseif type(a) == 'string' and type(b) == 'boolean' then
    cat = tostring(a):lower()
    passedFlag = b
    if type(c) == 'table' then
      stats = c
    else
      stats.totalQuestions = tonumber(c)
      stats.correctAnswers = tonumber(d)
      stats.usedSeconds    = tonumber(e)
    end
  elseif type(a) == 'boolean' and type(b) == 'string' then
    passedFlag = a
    cat = tostring(b):lower()
    stats.totalQuestions = tonumber(c)
    stats.correctAnswers = tonumber(d)
    stats.usedSeconds    = tonumber(e)
  elseif type(a) == 'string' and type(b) == 'table' then
    cat = tostring(a):lower()
    local p = b
    passedFlag = (p.passed == true) or (p.success == true) or (tostring(p.passed) == 'true')
    stats = p
  -- Standard format fired by client/ui.lua: (category, token, passed, scorePct)
  elseif type(a) == 'string' and type(b) == 'string' and type(c) == 'boolean' then
    cat = tostring(a):lower()
    passedFlag = (c == true)
    stats = stats or {}
    stats.scorePct = tonumber(d)
  end

  local total   = tonumber(stats.totalQuestions or stats.total or 0) or 0
  local correct = tonumber(stats.correctAnswers or stats.correct or 0) or 0
  local used    = tonumber(stats.usedSeconds or stats.used or 0) or 0
  local scorePct= tonumber(stats.scorePct or stats.score)
  if not scorePct then
    scorePct = (total > 0) and math.floor((correct / total) * 100 + 0.5) or 0
  else
    scorePct = math.floor(scorePct + 0.5)
  end

  return cat, (passedFlag == true), { total=total, correct=correct, used=used, scorePct=scorePct }
end

local function onTheoryResult(src, ...)
  if not src or src <= 0 then return end
  local cat, passedFlag, st = parsePayload({ ... })

  -- Duplicate guard (10s for identical key)
  local now = 0; pcall(function() now = GetGameTimer() end)
  local key = string.format('%s:%s:%d:%d:%d', tostring(passedFlag), tostring(cat), st.total or 0, st.correct or 0, st.used or 0)
  local guard = lastGrant[src]
  if guard and guard.key == key and (now - (guard.t or 0)) < 10000 then
    sLog('INFO', ('theory duplicate result ignored src=%s cat=%s key=%s'):format(tostring(src), tostring(cat), key))
    return
  end
  lastGrant[src] = { t = now, key = key }

  if passedFlag then
    local item = theoryItemForCategory(cat)
    if item and item ~= '' then
      local granted = false
      -- Avoid duplicate in ESX inventory (best-effort)
      pcall(function()
        local esx = getESX()
        if esx and esx.GetPlayerFromId then
          local xPlayer = esx.GetPlayerFromId(src)
          if xPlayer then
            local has = false; local cnt = 0
            has, cnt = safeHasItem_ESX(xPlayer, item)
            if has then
              granted = true -- already has it; treat as granted
            end
          end
        end
      end)
      if not granted then
        local ok = false; pcall(function() ok = safeAddItemToPlayer(src, item, 1) end)
        if ok then
          sLog(nil, ('theory passed src=%s cat=%s total=%d correct=%d used=%ds item=%s'):format(src, cat, st.total or 0, st.correct or 0, st.used or 0, item))
        else
          sLog('WARN', ('theory pass item grant not confirmed src=%s cat=%s item=%s'):format(src, cat, tostring(item)))
        end
      else
        sLog('INFO', ('theory passed (already had item) src=%s cat=%s item=%s'):format(src, cat, item))
      end
    else
      sLog(nil, ('theory passed src=%s cat=%s total=%d correct=%d used=%ds (no item configured)'):format(src, cat, st.total or 0, st.correct or 0, st.used or 0))
    end
  else
    sLog(nil, ('theory failed src=%s cat=%s total=%d correct=%d used=%ds'):format(src, cat, st.total or 0, st.correct or 0, st.used or 0))
  end

  -- Client UI events: new + legacy.
  -- Guard: skip if server/main.lua already fired theoryOutcome for this player
  -- (both scripts handle the same events; main.lua fires first due to load order).
  local mainTs = (_G._mtj_main_processed_theory and _G._mtj_main_processed_theory[src]) or 0
  local mainAlreadyHandled = mainTs > 0 and (now - mainTs) < 5000
  if not mainAlreadyHandled then
    pcall(function()
      TriggerClientEvent(ev('client:theoryOutcome'), src, passedFlag, st.scorePct or 0, { ts = now, category = cat, errors = {} })
    end)
    pcall(function()
      TriggerClientEvent(ev('client:theoryEnd'), src, {
        passed = passedFlag,
        stats = {
          totalQuestions = st.total or 0,
          correctAnswers = st.correct or 0,
          usedSeconds    = st.used or 0,
          scorePct       = st.scorePct or 0
        }
      })
    end)
  end
end

-- Accept multiple event name variants (camel/snake, de/en)
local names = {
  ev('server:theorieResult'),
  ev('server:theorie_result'),
  ev('server:theoryResult'),
  ev('server:theory_result'),
  ev('server:TheoryPassed'),
  ev('server:theoryPassed'),
}
for _,name in ipairs(names) do
  RegisterNetEvent(name, function(...) local src=source; onTheoryResult(src, ...) end)
end

-- Optional: admin/test command (grant theory cert)
RegisterCommand('mtj_give_theory', function(src, args)
  local cat = tostring(args[1] or 'car'):lower()
  onTheoryResult(src, cat, true, (Config and Config.Theory and Config.Theory.QuestionsPerTest) or 5, (Config and Config.Theory and math.ceil((Config.Theory.QuestionsPerTest or 5) * ((Config.Theory.PassPercentage or 80)/100))) or 4, 30)
end, false)