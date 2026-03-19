-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- client/debug_ui.lua
-- Loggt alle SendNUIMessage / SetNuiFocus Aufrufe mit Stacktrace

local function RES() return (Config and Config.ResourceName) or GetCurrentResourceName() or 'mtj_fahrschule' end

local origSendNUIMessage = SendNUIMessage
local origSetNuiFocus = SetNuiFocus

local function shortStack()
  local info = {}
  for i=3,8 do
    local d = debug.getinfo(i, "Slf")
    if not d then break end
    info[#info+1] = string.format("%s:%s@%s", d.short_src or "?", d.currentline or "?", d.name or "anon")
  end
  return table.concat(info, " <- ")
end

local function encodeSafe(o)
  if type(o)=='table' and json and json.encode then
    local ok,s = pcall(json.encode, o)
    if ok then return s end
  end
  return tostring(o)
end

SendNUIMessage = function(msg)
  if dbg then dbg('UI', 'SendNUIMessage ->', encodeSafe(msg)) else print(('[%s][client/debug] SendNUIMessage -> %s'):format(RES(), encodeSafe(msg))) end
  if dbg then dbg('UI', 'caller ->', shortStack()) end
  return origSendNUIMessage(msg)
end

SetNuiFocus = function(hasFocus, hasCursor)
  if dbg then dbg('UI', 'SetNuiFocus', hasFocus, hasCursor) else print(('[%s][client/debug] SetNuiFocus(%s,%s)'):format(RES(), tostring(hasFocus), tostring(hasCursor))) end
  if dbg then dbg('UI', 'caller ->', shortStack()) end
  return origSetNuiFocus(hasFocus, hasCursor)
end

print(('[%s][client/debug] debug loaded'):format(RES()))