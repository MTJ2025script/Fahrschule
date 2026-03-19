--[[
========================================================================================================================
  
  ####     #####     ######     ######     #    #     ######     ####       #    #     ######
 #    #    #   #     #          #          ##   #         ##     #    #     ##   #     #
 #  ###    #####     #####      #####      # #  #        ##      #    #     # #  #     #####
 #    #    #  #      #          #          #  # #       ##       #    #     #  # #     #
  ####     #   #     ######     ######     #   ##     ######      ####      #   ##     ######

                                                   M T J 2 0 2 4   S C R I P T S
========================================================================================================================
  Projekt     : MTJ2024 Scripts – Fahrschule (ESX Legacy)
  Datei       : server/compat_theory.lua
  Version     : v1.0.2
  Build       : 2025-10-15
  Autor       : MTJ2024
  Lizenz      : Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten.
  Zweck       : Kompatibilität – akzeptiert sowohl table-Payloads als auch
                klassische Mehrfach-Argument-Aufrufe für Theorie-Ergebnisse und
                leitet sie sicher an mtj_fahrschule:server:theoryResult weiter.
  Änderungen  : - Unterstützung beider Aufrufstile (table OR args)
                - Robuste Feld-Validierung / Sanitisierung
                - Klarere Logs inkl. Quell-Player (src) und Debug-Info
                - Vermeidet implizite Abhängigkeit auf 'source' beim TriggerEvent
========================================================================================================================
]]--

-- Handler akzeptiert entweder:
-- 1) TriggerServerEvent('mtj_fahrschule:theoryResult', { category='car', token='...', passed=true, score=88 })
-- 2) TriggerServerEvent('mtj_fahrschule:theoryResult', 'car', 'token', true, 88)

local function safeToString(v)
  if v == nil then return '' end
  return tostring(v)
end

local function clampScore(n)
  n = tonumber(n) or 0
  if n < 0 then return 0 end
  if n > 100 then return 100 end
  return n
end

RegisterNetEvent('mtj_fahrschule:theoryResult')
AddEventHandler('mtj_fahrschule:theoryResult', function(...)
  local src = source
  local args = {...}

  local payload = nil
  -- detect table-style single-argument payload
  if #args == 1 and type(args[1]) == 'table' then
    payload = args[1]
  else
    -- legacy multi-arg form: category, token, passed, score
    local category = args[1]
    local token = args[2]
    local passed = args[3]
    local score = args[4]
    payload = {
      category = category,
      token = token,
      passed = passed,
      score = score
    }
  end

  if type(payload) ~= 'table' then
    print(('[%s][compat] Ignoring theoryResult from src=%s: payload invalid (type=%s)'):format(
      GetCurrentResourceName(), tostring(src), type(payload)))
    return
  end

  -- sanitize & normalize fields
  local rawCategory = payload.category or payload.cat or ''
  local category = tostring(rawCategory):lower():gsub('%s+', '') or ''
  if category == '' then
    print(('[%s][compat][warn] Empty/invalid category from src=%s, treating as empty string'):format(GetCurrentResourceName(), tostring(src)))
  end

  local token = payload.token or payload.t or ''
  if token ~= nil then token = safeToString(token) else token = '' end

  local passed = (payload.passed == true) or (payload.passed == 1) or (tostring(payload.passed) == 'true')

  -- score can come as "score", "scorePct" or numeric
  local rawScore = payload.score or payload.scorePct or payload.s or 0
  local scorePct = clampScore(rawScore)

  -- Debug / info log
  print(('[%s][compat] Received theoryResult from src=%s | category=%s passed=%s score=%s token=%s'):format(
    GetCurrentResourceName(), tostring(src), tostring(category), tostring(passed), tostring(scorePct), token ~= '' and '[present]' or '[empty]'))

  -- Forward to canonical server handler.
  -- Prefer to pass the original source explicitly to avoid any ambiguity in the receiver.
  -- Many existing handlers expect (source, category, token, passed, score) or (category, token, passed, score)
  -- We attempt to support both by trying TriggerEvent with source first; the server-side handler can accept it.
  local ok, err = pcall(function()
    -- Primary: include source as first argument (recommended)
    TriggerEvent('mtj_fahrschule:server:theoryResult', src, category, token, passed, scorePct)
  end)
  if not ok then
    -- Fallback: try without source (for older server handlers)
    local ok2, err2 = pcall(function()
      TriggerEvent('mtj_fahrschule:server:theoryResult', category, token, passed, scorePct)
    end)
    if not ok2 then
      print(('[%s][compat][error] Failed to forward theoryResult from src=%s: %s / %s'):format(
        GetCurrentResourceName(), tostring(src), tostring(err), tostring(err2)))
    else
      print(('[%s][compat] Forwarded theoryResult (fallback without src) for src=%s'):format(GetCurrentResourceName(), tostring(src)))
    end
  else
    -- success
    -- Provide a trace log so server admins can see forwarded mapping
    print(('[%s][compat] Forwarded theoryResult (with src) for src=%s to mtj_fahrschule:server:theoryResult'):format(GetCurrentResourceName(), tostring(src)))
  end
end)