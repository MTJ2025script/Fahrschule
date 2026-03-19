-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- server/debug_ui.lua
-- TriggerClientEvent-Hook mit Event-Filter + Schalter (Performance-schonend)

local RESOURCE = GetCurrentResourceName()
local origTriggerClientEvent = TriggerClientEvent

-- Schalter: Convar "mtj_debug_events" = "true" ODER Config.Debug.Security = true
local ENABLED = (GetConvar('mtj_debug_events', 'false') == 'true')
if not ENABLED and Config and Config.Debug then
  ENABLED = (Config.Debug.Enable == true and Config.Debug.Security ~= false) or (Config.Debug.Security == true)
end

-- Nur relevante Events loggen (reduziert Spam)
local PATTERNS = {
  '^mtj_fahrschule:client:',     -- alle unsere Client-Events
  -- weitere Patterns optional hier eintragen
  -- '^esx:', '^qb%-core:' ...
}

local function shouldLog(ev)
  if not ENABLED then return false end
  ev = tostring(ev or '')
  for _,re in ipairs(PATTERNS) do
    if ev:find(re) then return true end
  end
  return false
end

local function shortStack()
  local info = {}
  -- kompakter Stack; 4..8 reicht, um Aufrufer zu sehen
  for i=4,8 do
    local d = debug.getinfo(i, 'Sl')
    if not d then break end
    info[#info+1] = string.format('%s:%s', d.short_src or '?', d.currentline or '?')
  end
  return table.concat(info, ' <- ')
end

local function logLine(ev, target, argc)
  local tgt
  if type(target) == 'number' then
    tgt = (target == -1) and 'broadcast' or tostring(target)
  else
    tgt = tostring(target)
  end
  local line = string.format('TriggerClientEvent -> %s target=%s args=%d', tostring(ev), tgt, tonumber(argc) or 0)
  if type(dbg) == 'function' then
    dbg('Security', line)
    dbg('Security', 'caller -> ' .. shortStack())
  else
    print(('[%s][server/debug] %s'):format(RESOURCE, line))
    print(('[%s][server/debug] caller -> %s'):format(RESOURCE, shortStack()))
  end
end

TriggerClientEvent = function(eventName, target, ...)
  if shouldLog(eventName) then
    logLine(eventName, target, select('#', ...))
  end
  return origTriggerClientEvent(eventName, target, ...)
end

print(('[%s][server/debug] debug loaded (ENABLED=%s, patterns=%d)'):format(RESOURCE, tostring(ENABLED), #PATTERNS))