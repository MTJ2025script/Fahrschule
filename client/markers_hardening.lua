-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- markers_hardening.lua
-- Zweck:
-- - Pro Frame ClearDrawOrigin(), damit Marker nicht "verschoben" werden, falls andere Ressourcen DrawOrigin setzen.
-- - Force-Zeichnen von Stations-Markern über /mtj_markers_force on|off|toggle (nur visuell; Interaktion bleibt in main.lua).
-- - Robuste Native-Draws (InvokeNative), Boden-Z-Anhebung.

local RES = (GetCurrentResourceName and GetCurrentResourceName()) or 'mtj_fahrschule'
local FORCE = false

-- Native-Wrapper für DrawMarker (umgeht überschriebenes DrawMarker)
local function DrawMarkerNative(t, x, y, z, dirx, diry, dirz, rotx, roty, rotz, sx, sy, sz, r, g, b, a, bob, face, p19, rotate, txd, txn, drawEnts)
  return Citizen.InvokeNative(0x28477EC23D892089,
    tonumber(t) or 1,
    x + 0.0, y + 0.0, z + 0.0,
    dirx or 0.0, diry or 0.0, dirz or 0.0,
    rotx or 0.0, roty or 0.0, rotz or 0.0,
    sx or 1.0, sy or 1.0, sz or 1.0,
    r or 255, g or 255, b or 255, a or 200,
    bob or false, face or true, p19 or 2, rotate or false,
    txd or nil, txn or nil, drawEnts or false
  )
end

local function v3(v)
  if not v then return nil end
  if type(v) == 'vector3' or type(v) == 'vector4' or (type(v) == 'userdata' and v.x) then
    return v.x, v.y, v.z
  end
  if type(v) == 'table' then
    if v.x then return v.x, v.y, v.z end
    if tonumber(v[1]) and tonumber(v[2]) and tonumber(v[3]) then return v[1], v[2], v[3] end
  end
  local s = tostring(v or '')
  local a,b,c = s:match('([-+]?%d+%.?%d*)%D+([-+]?%d+%.?%d*)%D+([-+]?%d+%.?%d*)')
  if a and b and c then return tonumber(a), tonumber(b), tonumber(c) end
  return nil
end

local function groundZ(x, y, z)
  local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 0.0, false)
  if ok and gz and gz > -100.0 then return math.max(z, gz + 0.20) end
  return z
end

local function drawForcedMarker(x,y,z, col, sc)
  local dz = groundZ(x,y,z)
  local c = col or { r=0,g=200,b=255,a=220 }
  local s = sc or { x=2.0,y=2.0,z=1.2 }
  -- Solider Marker (1) + gelber Ring (27) als Sicht-Fallback
  DrawMarkerNative(1,  x, y, dz - 0.10, 0,0,0, 0,0,0, s.x, s.y, s.z, c.r, c.g, c.b, c.a, false, true, 2, false, nil, nil, false)
  DrawMarkerNative(27, x, y, dz + 0.05, 0,0,0, 0,0,0, 0.35, 0.35, 0.35, 255, 255, 0, 200, false, true, 2, false, nil, nil, false)
end

RegisterCommand('mtj_markers_force', function(_, args)
  local a = tostring(args and args[1] or ''):lower()
  if a == 'on' or a == '1' or a == 'true' or a == '' then
    FORCE = true
  elseif a == 'off' or a == '0' or a == 'false' then
    FORCE = false
  else
    FORCE = not FORCE
  end
  print(('[%s][markers_hardening] FORCE=%s'):format(RES, tostring(FORCE)))
end, false)

CreateThread(function()
  while true do
    Wait(0)
    -- Immer DrawOrigin zurücksetzen (andere Ressourcen lassen es manchmal gesetzt)
    pcall(ClearDrawOrigin)

    if FORCE and Config and Config.Points then
      local col = (Config.MarkerColor) or { r=0,g=200,b=255,a=210 }
      local sca = (Config.MarkerScale) or vector3(2.0,2.0,1.2)
      local sx = sca.x or sca[1] or 2.0
      local sy = sca.y or sca[2] or 2.0
      local sz = sca.z or sca[3] or 1.2

      if Config.Points.booking  then local x,y,z=v3(Config.Points.booking);  if x then drawForcedMarker(x,y,z,col,{x=sx,y=sy,z=sz}) end end
      if Config.Points.theory   then local x,y,z=v3(Config.Points.theory);   if x then drawForcedMarker(x,y,z,col,{x=sx,y=sy,z=sz}) end end
      if Config.Points.practice then local x,y,z=v3(Config.Points.practice); if x then drawForcedMarker(x,y,z,col,{x=sx,y=sy,z=sz}) end end
    end
  end
end)