-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

-- shared/debug.lua
Debug = Debug or {
    Enable   = true,   -- <-- TEMPORÄR einschalten zum Debuggen (danach auf false setzen)
    UI       = true,   -- NUI / UI logs
    Theory   = false,
    Practice = true,   -- Praxis-Events loggen
    Markers  = false,
    Payments = false,
    Security = true
}

function DPrint(domain, ...)
    if not (Debug and Debug.Enable) then return end
    if not domain then domain = 'GEN' end
    if Debug[domain] ~= true then return end
    local out = {}
    for i=1, select('#', ...) do out[#out+1] = tostring(select(i, ...)) end
    print(('[DEBUG:%s] %s'):format(domain, table.concat(out, ' ')))
end

dbg = DPrint