-- Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

--[[
========================================================================================================================
  Projekt     : Fahr-/Theorie-/Praxis-System (ESX/QBCore kompatibel)
  Datei       : config/config.lua
  Version     : 1.2.5
  Build       : 2025-10-19

  Zweck       : Vollständig kommentierte Owner-Konfig (jede Option deutsch erklärt – rechte Seite).
  Hinweis     : Nur bearbeiten wo nötig. Alle hier gesetzten Werte wirken direkt (sofern nicht ausdrücklich anders vermerkt).
  Hinweis 2  : Visuelles (Marker-Farben, Hint-Design, Ideallinie) steuerst du in Config.MarkerUI / Config.IdealLine – ohne Code!
========================================================================================================================
]]

Config = {}                                    -- Haupt-Konfig-Tabelle (NICHT umbenennen)

-------------------------------------------------------------------------------------------------
-- DEBUG (zentraler Schalter für Konsolen-/Log-Ausgaben)
-- Empfehlung: Nur temporär aktivieren – Debug erzeugt viel Output.
-------------------------------------------------------------------------------------------------
Config.Debug = {
    Enable    = false, -- Globaler Hauptschalter: true = alle definierten Debug-Kanäle aktiv (außer individuell auf false)
    UI        = false, -- UI-/NUI-Interaktionen
    Theory    = false, -- Theorieprüfung (Fragen / Auswertung)
    Practice  = false, -- Praxisablauf (Checkpoints, Landung)
    Markers   = false, -- Marker & Zeichnen (pro Frame – kann spammy sein)
    Payments  = false, -- Zahlung / Buchung / Kosten / Inventar
    Security  = true,  -- Anti-Exploit / Schutz-Checks (empfohlen true)
    DB        = false, -- Datenbank (SQL Insert/Select)
    Emergency = true   -- Server-Watchdog (Abbruch-Überwachung) – hilfreich zur Fehlersuche
}

-------------------------------------------------------------------------------------------------
-- BASIS / SPRACHE
-------------------------------------------------------------------------------------------------
Config.ResourceName = 'mtj_fahrschule' -- Technischer Name der Resource (für Events/Logs)
Config.Locale       = 'de'             -- Sprache

-------------------------------------------------------------------------------------------------
-- UI & BRANDING (Texte / Logos / Beschriftungen)
-------------------------------------------------------------------------------------------------
Config.UI = {
    Name         = 'Deine Fahrschule',              -- Titel im UI
    Schriftzug   = 'Deine Fahrschule',              -- Optionaler großer Schriftzug (leer = ausblenden)
    Slogan       = 'Dein Weg zum Führerschein',     -- Untertitel / Claim
    Logo         = 'img/logo.png',                  -- Pfad relativ zur HTML-NUI
    BookingTitle = 'Fahrschule-Buchen',             -- Titel des Buchungsfensters
    RightPane    = {                                -- Rechte Info-Spalte im Hauptmenü
        Title    = 'Informationen',                 -- Überschrift
        Subtitle = 'So funktioniert’s',             -- Untertitel
        Text     = 'Wähle Kategorie und Modus. Bezahle am Punkt 1. Danach Theorie (Punkt 2) und Praxis (Punkt 3).', -- Beschreibung
        Bullets  = { '1) Buchung bezahlen', '2) Theorie bestehen', '3) Praxis absolvieren', '4) Zertifikat abholen' }
    }
}
Config.UIName           = Config.UI.Name            -- Alias für Altstellen (beibehalten)
Config.UILogo           = Config.UI.Logo            -- Alias für Altstellen
Config.LogoURL          = Config.UI.Logo            -- Backward Compatibility
Config.SecondaryLogoURL = nil                       -- Zweites Logo (optional)

-------------------------------------------------------------------------------------------------
-- BENACHRICHTIGUNGEN & SICHERHEIT
-------------------------------------------------------------------------------------------------
Config.UseESXNotify         = true   -- true = ESX.ShowNotification
Config.UseEsxNotifyResource = false  -- true = zusätzliches esx_notify-Format
Config.NotifyDuration       = 5000   -- ms
Config.SafeModeAntiExploit  = true   -- Praxis nur mit Theorie-Zertifikat buchbar (Schutz)

-------------------------------------------------------------------------------------------------
-- INTERAKTION / MARKER STANDARDWERTE
-------------------------------------------------------------------------------------------------
Config.KeyInteract      = 38                 -- Taste E (Control-Code 38)
Config.DrawDistance     = 25.0               -- Sichtweite Interaktionsmarker
Config.InteractDistance = 2.0                -- Max. Abstand “Drücke E”
Config.CheckpointRadius = 4.0                -- Radius Erkennung (Boden)
Config.MarkerType       = 2                  -- Fallback DrawMarker-Typ
Config.MarkerScale      = vec3(1.8,1.8,1.8)  -- Fallback Skalierung
Config.MarkerColor      = { r=0,g=180,b=255,a=180 } -- Fallback Farbe

-------------------------------------------------------------------------------------------------
-- MARKER PROFILE (Stile für dynamische Praxis-Checkpoints)
-------------------------------------------------------------------------------------------------
Config.Markers = {
    Next      = { type=21, scale=vec3(2.4,2.4,1.2), color={ r=0,g=200,b=255,a=130 }, pulse={ r=120,g=0,b=255,a=190 } }, -- “Nächster” Punkt (Luft/Boden)
    Arrow     = { type=2,  scale=vec3(1.0,1.0,1.6), color={ r=255,g=255,b=255,a=150 } },                                -- Pfeil (nur Boden)
    Finish    = { type=38, scale=vec3(3.0,3.0,1.2), color={ r=0,g=255,b=120,a=190 } },                                  -- Ziel
    Use3DText = true -- true = 3D Text “X/Y” über Checkpoint
}

-------------------------------------------------------------------------------------------------
-- MARKER UI (Interact-Hints / World-Marker)
-- Alle visuellen Aspekte ohne Codeänderung konfigurierbar.
-------------------------------------------------------------------------------------------------
Config.MarkerUI = {
    -- Aktivierung
    enabled         = true,   -- Interact-Hints anzeigen
    pulseEnabled    = true,   -- Pulsierender Marker (Atem-Effekt)
    accentBar       = true,   -- Akzent-Leiste links der Hint-Box

    -- Farben (RGBA)
    bgColor         = { r=0,  g=0,  b=0,  a=210 },  -- äußeres Rechteck
    innerBgColor    = { r=20, g=20, b=20, a=220 },  -- inneres Rechteck
    accentColor     = { r=0,  g=200,b=255,a=210 },  -- Akzent-Leiste

    -- Speziell: Akzent für Luftfahrzeuge / Ideallinie
    airAccent       = { r=0, g=200, b=200, a=200 }, -- Farbe Heli/Plane & Luft-Ideallinie
    idealColor      = { r=0, g=200, b=200, a=120 }, -- Standardfarbe Ideallinie

    -- Text / Schrift
    textFont        = 4,      -- Gut lesbar
    fontScaleFactor = 1.0,    -- Globaler Text-Scale

    -- Skalierung / Größenverhalten
    baseScaleFactor = 1.0,    -- Multipliziert Config.MarkerScale
    minScale        = 0.65,   -- Mindestskalierung (Distanz-basiert)
    maxScale        = 1.05,   -- Höchstskalierung

    -- Key-Label & Template
    showKeyLabel    = true,   -- Zeigt Tasten-Label (z. B. “E”)
    hintTemplate    = 'Drücke ~INPUT_CONTEXT~', -- Template; ~INPUT_CONTEXT~ wird ersetzt
    keyLabelMap     = {},     -- Optional: Mapping eigener Key-Codes -> Label

    -- Sichtbarkeit / Fallback
    drawDistanceMin = nil     -- Optional: Mindest-DrawDistance (nil = Config.DrawDistance)
}

-------------------------------------------------------------------------------------------------
-- BLIP STANDARDS (Minimap-Icons)
-------------------------------------------------------------------------------------------------
Config.RouteBlipSprite     = 615  -- Standard Blip Sprite (Checkpoint)
Config.RouteBlipColor      = 3    -- Standard Farbe
Config.RouteBlipSpriteNext = 615  -- (Optional) eigener Sprite “Nächster”
Config.RouteBlipColorNext  = 3    -- Farbe “Nächster”
Config.RouteBlipSpriteEnd  = 434  -- Ziel-Sprite
Config.RouteBlipColorEnd   = 2    -- Ziel-Farbe
Config.ShowRoute           = true -- GTA GPS-Linie automatisch zeigen
Config.DeleteVehicleOnEnd  = true -- Prüfungsfahrzeug nach Abschluss löschen
Config.NPCModel            = 's_m_m_autoshop_01' -- Standard Beifahrer/NPC (false oder '' = kein NPC)

-------------------------------------------------------------------------------------------------
-- LUFTRING-ORIENTIERUNG
-------------------------------------------------------------------------------------------------
Config.RingForceVertical = true -- true = Luft-Checkpoints (Ringe) immer vertikal ausgerichtet

-------------------------------------------------------------------------------------------------
-- KATEGORIE MARKER (Größe/Farbe je Fahrzeugklasse)
-------------------------------------------------------------------------------------------------
Config.CategoryMarkers = {
    car   = { type=2, scale=vec3(2.4,2.4,1.6),  color={ r=255,g=40,b=40,a=200 } },  -- PKW
    bike  = { type=2, scale=vec3(2.2,2.2,1.4),  color={ r=255,g=40,b=40,a=200 } },  -- Motorrad
    truck = { type=2, scale=vec3(3.0,3.0,1.8),  color={ r=255,g=80,b=40,a=200 } },  -- LKW
    heli  = { type=1, scale=vec3(12.0,12.0,3.0), color=(Config and Config.MarkerUI and Config.MarkerUI.airAccent) or { r=0,g=200,b=200,a=220 } }, -- Helikopter-Ring
    plane = { type=1, scale=vec3(16.0,16.0,4.0), color=(Config and Config.MarkerUI and Config.MarkerUI.airAccent) or { r=0,g=200,b=200,a=220 } }  -- Flugzeug-Ring
}

-------------------------------------------------------------------------------------------------
-- KATEGORIE BLIPS (Minimap-Icons je Klasse)
-------------------------------------------------------------------------------------------------
Config.CategoryBlips = {
    car   = { sprite=1, color=1, scale=0.95 },
    bike  = { sprite=1, color=1, scale=0.95 },
    truck = { sprite=1, color=1, scale=1.05 },
    heli  = { sprite=1, color=1, scale=1.6  },
    plane = { sprite=1, color=1, scale=1.8  }
}

-------------------------------------------------------------------------------------------------
-- PREISE (Theorie / Praxis je Kategorie)
-------------------------------------------------------------------------------------------------
Config.Prices = {
    car   = { theorie=500,  praxis=1500 },
    bike  = { theorie=400,  praxis=1200 },
    truck = { theorie=600,  praxis=2000 },
    heli  = { theorie=1200, praxis=4000 },
    plane = { theorie=1500, praxis=5000 }
}

-------------------------------------------------------------------------------------------------
-- THEORIE EINSTELLUNGEN
-------------------------------------------------------------------------------------------------
Config.Theory = {
    QuestionsPerTest = 1,    -- Anzahl Fragen pro Versuch
    PassPercentage   = 80,   -- Mindestquote in %
    TimerSeconds     = 1200  -- Zeitlimit in Sekunden
}
Config.PassPercent = Config.Theory.PassPercentage -- Alias (Abwärtskompatibilität)

-------------------------------------------------------------------------------------------------
-- PRAXIS EINSTELLUNGEN (Fehler, Checks, Gnadenzeiten, Abbruch-Verhalten)
-- Serverseitige Emergency-Überwachung ist aktiv (Enabled=true): erkennt Ausstieg/Stillstand/Roof.
-------------------------------------------------------------------------------------------------
Config.Practice = {
    MaxErrors                  = 5,     -- Max. erlaubte Fehler
    SpeedCheckTolerance        = 8.0,   -- km/h über Limit, bevor “speeding”
    DamageFailThreshold        = 700.0, -- Health-Drop (VehicleHealth) für Schaden
    TimeBetweenChecksMs        = 100,   -- Prüf-Frequenz (ms)
    UseSeatbeltCheck           = true,  -- Gurtpflicht (nur Boden)
    SpawnFuelLevel             = 95.0,  -- Spawn-Treibstoff in %
    FreezeAtStartSeconds       = 2.0,   -- Kurzes Einfrieren am Start (stabilisiert Position)
    StartGraceSeconds          = 4.0,   -- Gnadenzeit: keine Speed/Collision-Fehler
    ShowLiveErrorNotify        = false, -- Fehler beim Auftreten direkt anzeigen
    ErrorNotifyCooldownSeconds = 4.0,   -- Cooldown für Live-Fehler-Anzeige
    CollisionCheck             = true,  -- Kollisionen detektieren
    CollisionCooldownSeconds   = 2.0,   -- Abstand zwischen Kollisionen
    CollisionMinSpeedKmh       = 10.0,  -- Mindesttempo für Kollisionserfassung
    CollisionMinBodyHealthDrop = 10.0,  -- Mindestverlust Karosserie-Health
    OffRouteDistance           = 120.0, -- Distanz (m) zum Ziel-Checkpoint ab der OffRoute zählt
    OffRouteSeconds            = 8.0,   -- Sekunden OffRoute bis Fehler erfolgt

    -- NEU: Abbruch-Respawn (wirkt live; kein Restart nötig)
    AbortRespawn = {
        enabled       = true,  -- true = nach Abbruch/Fehler automatisch zurück zu Punkt 1
        position      = nil,   -- nil => Config.Points.booking; sonst vec4(x,y,z,h) für eigene Rücksetzposition
        fade          = true,  -- Fade-Out/Fade-In beim Teleport
        freezeSeconds = 0.8    -- Kurzer Freeze nach Teleport (Sekunden)
    },

    -- NEU: UI-Timer (NUI) bei Abbruch stoppen (wirkt live)
    StopUITimersOnAbort = true, -- true = sendet an NUI ein globales “stopAllTimers” beim Abbruch

    Emergency = {                      -- Serverseitige Notfall-/Abbruchlogik (Watchdog)
        Enabled             = true,    -- aktiviert (Server-Loop nutzt Heartbeat-Daten)
        ExitGraceSeconds    = 6,       -- Zeit nach Ausstieg bis Abbruch
        MinSpeedActiveKmh   = 3.0,     -- Geschwindigkeit, die “Bewegung” definiert
        MaxStationarySeconds= 25,      -- Stillstandsdauer bis Abbruch
        LoopIntervalMs      = 3000,    -- Prüfintervall (ms)
        MaxSilentSeconds    = 90,      -- Kein Heartbeat so lange => Abbruch
        RoofGraceSeconds    = 5        -- “auf dem Dach” so lange => Abbruch
    }
}

-------------------------------------------------------------------------------------------------
-- ERGEBNIS-UI (Popup nach Praxis/Theorie)
-------------------------------------------------------------------------------------------------
Config.ResultUI = {
    enabled          = true,         -- Popup aktiv
    lockEnabled      = true,         -- Ergebnis bleibt sichtbar, bis Spieler schließt
    accentColor      = '#00C8FF',    -- Akzentfarbe
    successColor     = '#00D084',    -- Farbe “Bestanden”
    failColor        = '#FF3B30',    -- Farbe “Nicht bestanden”
    showErrorList    = true,         -- Fehlerliste anzeigen
    showStats        = true,         -- Statistiken anzeigen
    titles           = { success='Praxis – Bestanden', fail='Praxis – Nicht bestanden' },
    subtitles        = { success='Gut gemacht! Du hast die Anforderungen erfüllt.', fail='Bitte versuche es erneut. Unten siehst du deine Fehler.' },
    errorListTitle   = 'Deine Fehler',
    summaryLabel     = 'Zusammenfassung',
    autoCloseSeconds = 0             -- 0 = kein Auto-Close
}

-------------------------------------------------------------------------------------------------
-- DISTANZ-HUD (Weg bis nächster Checkpoint) – GTAV Top-Bar Style
-------------------------------------------------------------------------------------------------
Config.DistanceHUD = {
    enabled              = true,           -- HUD aktiv
    unit                 = 'auto',         -- 'auto' / 'm' / 'km'
    showAltitudeDelta    = true,           -- Δz (Höhenunterschied) für Luftfahrzeuge anzeigen

    -- Top-Bar Layout (oben zentriert)
    showAboveMinimap     = true,
    minimapX             = 0.50,
    minimapY             = 0.065,
    minimapScale         = 0.48,
    minimapFont          = 4,
    minimapBackgroundColor = { r=0, g=0, b=0, a=170 },
    minimapTextColor       = { r=0, g=200, b=255, a=255 },
    accentBarColor       = (Config and Config.MarkerUI and Config.MarkerUI.accentColor) or { r=0, g=200, b=255, a=230 },
    accentBarWidth       = 0.006,

    -- Legacy-Fallback (falls showAboveMinimap=false)
    position             = { x=0.50, y=0.12 },
    scale                = 0.42,
    color                = { r=255, g=255, b=255, a=220 },
    outline              = true,
    dropshadow           = { dist=2, r=0, g=0, b=0, a=220 }
}

-------------------------------------------------------------------------------------------------
-- IDEALLINIE (Visualisierung der Route)
-- Boden-Ideallinie standardmäßig aus; Luft aktiv. In der Landungsphase optional ausblendbar.
-------------------------------------------------------------------------------------------------
Config.IdealLine = {
    enabled            = true,        -- Hauptschalter
    drawInLandingPhase = false,       -- in Landung ausblenden
    cullDistance       = 220.0,       -- Render-Culling
    maxPoints          = 1200,        -- Performance-Limit
    ground = {
        enabled   = false,            -- Boden-Linie aus
        step      = 12.0,
        size      = vec3(1.20,1.20,0.40),
        color     = { r=0,g=200,b=200,a=90 },
        useGroundZ= true,
        zOffset   = 0.05
    },
    air = {
        step  = 24.0,
        size  = vec3(1.20,1.20,1.20),
        color = { r=0,g=200,b=200,a=110 }
    }
}

-------------------------------------------------------------------------------------------------
-- LANDUNG (GREEN-ZONES) – definierte Bereiche zum Abschluss für Luftfahrzeuge
-------------------------------------------------------------------------------------------------
Config.Landing = {
    enabledFor      = { plane=true, heli=true }, -- Kategorien mit Landungsphase
    center          = vec3(1112.4039, -2884.3386, 13.9460), -- Fallback-Mitte
    radius          = 35.0,                      -- Fallback-Radius
    minOnGroundSec  = 0.0,                       -- 0 = sofort erlaubt (wichtig für VTOL)
    maxTaxiSpeedKmh = 35.0,                      -- Taxi-Geschwindigkeit
    showMarker      = true,                      -- Marker zeichnen
    marker          = { type=1, scale=vec3(40.0,40.0,2.5), color={ r=0,g=255,b=120,a=140 } },
    hintText        = 'Lande im grünen Bereich und steige aus, um die Prüfung zu beenden.',
    zones = {
        heli  = { center = vec3(-723.4202, -1442.2152, 5.0005),   radius = 38.0 },  -- Helizone
        plane = { center = vec3(-1623.2596, -3095.2241, 13.5324), radius = 100.0 }  -- Plane-Zone (auf letztem Wegpunkt)
    }
}

-------------------------------------------------------------------------------------------------
-- STATIONSPUNKTE (Feste Prüfungsstationen)
-------------------------------------------------------------------------------------------------
Config.Points = {
    booking  = vec4(215.2383, -1398.7906, 30.5835, 335.6840), -- Punkt 1: Buchung/Bezahlung
    theory   = vec4(208.4166, -1383.4039, 30.5835, 132.6862), -- Punkt 2: Theorie starten
    practice = vec4(223.7665, -1395.7756, 30.5875, 268.7163)  -- Punkt 3: Praxis starten
}

-------------------------------------------------------------------------------------------------
-- HAUPT-BLIP (Fahrschule auf Karte)
-- Hinweis: Sub-Blips (Buchung/Theorie/Praxis) nur, wenn showSubPoints = true (siehe blip.lua)
-------------------------------------------------------------------------------------------------
Config.Blip = {
    enabled       = true,                           -- Hauptblip anzeigen
    name          = Config.UI.Name or 'Fahrschule', -- Anzeigename
    sprite        = 498,                            -- Icon-ID
    color         = 3,                              -- Farbe
    scale         = 0.9,                            -- Skalierung
    shortRange    = true,                           -- true = nur in Nähe sichtbar
    position      = vec4(215.2383, -1398.7906, 30.5835, 335.6840), -- Position des Hauptblips
    showSubPoints = false,                          -- true = Unterblips (Buchung/Theorie/Praxis) anzeigen
    -- subShortRange (optional): Wenn true, sind Unterblips nur in Nähe sichtbar. Falls nil, wird shortRange übernommen.
    subShortRange = nil,
    sub = {
        sprite       = 280,       -- Unterblip-Symbol
        scale        = 0.7,       -- Unterblip-Größe
        color        = 3,         -- Unterblip-Farbe
        theoryName   = 'Theorie', -- Name Theorie-Unterblip
        practiceName = 'Praxis'   -- Name Praxis-Unterblip
        -- optional: bookingName = 'Buchung'
    }
}

-------------------------------------------------------------------------------------------------
-- GESCHWINDIGKEITS-LIMITS (Stadt/Land) – Referenzwerte
-------------------------------------------------------------------------------------------------
Config.SpeedLimits = {
    car   = { city=150,  rural=150 },
    bike  = { city=150,  rural=100 },
    truck = { city=150,  rural=180  },
    heli  = { city=250,  rural=300 },
    plane = { city=300,  rural=500 }
}

-------------------------------------------------------------------------------------------------
-- FAHRZEUG-MODELLE (Spawn-Modelle – anpassbar an Server-Flotte)
-------------------------------------------------------------------------------------------------
Config.Vehicles = {
    car   = 'stalion2',  -- PKW
    bike  = 'bf400',     -- Motorrad
    truck = 'pounder2',  -- LKW
    heli  = 'frogger',   -- Helikopter
    plane = 'seabreeze'  -- Flugzeug (VTOL/JET)
}

-------------------------------------------------------------------------------------------------
-- ROUTEN (Waypoints; erstes Element = Spawn)
-------------------------------------------------------------------------------------------------
Config.Routes = {
  car = {
    { pos = vec4(233.8022, -1396.1990, 29.8514, 143.8579), city = true }, -- start
    { pos = vec4(178.6795, -1407.0109, 28.8735, 61.4596),  city = true },
    { pos = vec4(58.8703, -1491.4950, 28.7417, 137.6534),  city = true },
    { pos = vec4(-121.9249, -1716.9825, 29.4419, 136.1842), city = true },
    { pos = vec4(-7.8756, -1849.2321, 24.2254, 229.7200),  city = true },
    { pos = vec4(86.2803, -1876.5609, 23.0869, 318.9128),  city = true },
    { pos = vec4(198.9037, -1749.8730, 28.3936, 298.5306), city = true },
    { pos = vec4(296.3284, -1689.5096, 28.9051, 229.8645), city = true },
    { pos = vec4(454.2076, -1821.1277, 27.5001, 228.3611), city = true },
    { pos = vec4(507.2191, -1731.5630, 28.6956, 341.9987), city = true },
    { pos = vec4(772.9297, -1749.9227, 29.0854, 265.6104), city = true },
    { pos = vec4(849.1417, -1630.3477, 30.5233, 354.2639), city = true },
    { pos = vec4(799.6315, -1455.2347, 26.8172, 356.2090), city = true },
    { pos = vec4(736.9374, -1428.4572, 30.2030, 83.4911),  city = true },
    { pos = vec4(475.2716, -1427.5427, 28.9279, 77.3432),  city = true },
    { pos = vec4(324.3448, -1495.6440, 28.7772, 94.2708),  city = true },
    { pos = vec4(231.6548, -1394.0303, 30.0917, 44.4845),  city = true }  -- ziel
  },

  bike = {
    { pos = vec4(496.3191, 5589.6816, 794.2169, 160.7660), city = false },
    { pos = vec4(499.6772, 5537.5107, 777.6215, 144.2797), city = false },
    { pos = vec4(361.6984, 5465.6279, 690.8176, 146.0361), city = false },
    { pos = vec4(224.8417, 5290.4692, 618.0370, 192.0849), city = false },
    { pos = vec4(137.8836, 5182.9702, 551.7239, 5.8110),   city = false },
    { pos = vec4(84.7061, 5054.2598, 482.9079, 198.7295),  city = false },
    { pos = vec4(-2.9360, 5007.8687, 440.3364, 94.8996),   city = false },
    { pos = vec4(-162.6173, 4905.0859, 339.2081, 109.2638),city = false },
    { pos = vec4(-305.3552, 4952.7969, 262.6003, 49.8658), city = false },
    { pos = vec4(-378.8842, 4906.1743, 193.8137, 121.2581),city = false },
    { pos = vec4(-528.3179, 4878.1748, 169.5806, 106.8144),city = false },
    { pos = vec4(-590.8265, 4962.2476, 157.8295, 61.9002), city = false },
    { pos = vec4(-631.3813, 5048.6177, 143.5233, 27.4001), city = false },
    { pos = vec4(-842.7711, 5132.6958, 149.4874, 67.5889), city = false },
    { pos = vec4(-980.4819, 4981.0503, 187.9226, 129.0192),city = false },
    { pos = vec4(-1024.3168, 4953.9951, 198.2866, 28.4460),city = false },
    { pos = vec4(-1033.0494, 5096.3774, 149.3536, 326.7224),city = false },
    { pos = vec4(-874.1425, 5199.2051, 113.8214, 250.4417), city = false },
    { pos = vec4(-810.0582, 5260.5947, 87.5285, 92.4487),  city = false },
    { pos = vec4(-680.5134, 5255.5288, 76.1867, 243.6228), city = false },
    { pos = vec4(-573.3566, 5333.9077, 69.6944, 343.4152), city = false },
    { pos = vec4(-764.8240, 5436.0425, 37.2909, 101.2074), city = false },
    { pos = vec4(-804.9738, 5389.3003, 33.9981, 177.0182), city = false }
  },

  truck = {
    { pos = vec4(210.8604, -3328.5657, 5.9020, 266.8785),  city = false }, -- start (LSIA)
    { pos = vec4(179.1682, -2960.5332, 6.1047, 4.7888),    city = false },
    { pos = vec4(194.5685, -2644.9690, 6.0882, 4.5987),    city = false },
    { pos = vec4(285.1841, -2529.8809, 5.9604, 293.1677),  city = false },
    { pos = vec4(358.2722, -2298.6470, 10.2750, 0.1330),   city = false },
    { pos = vec4(454.8820, -2021.4218, 23.9160, 39.1309),  city = false },
    { pos = vec4(477.6169, -1921.2620, 25.2438, 293.0293), city = false },
    { pos = vec4(571.5579, -1554.6428, 29.1345, 43.1415),  city = false },
    { pos = vec4(502.0820, -911.7426, 26.2350, 2.0057),    city = false },
    { pos = vec4(406.9473, -781.0117, 29.3831, 4.7422),    city = false },
    { pos = vec4(504.1397, -450.7917, 30.0262, 323.0962),  city = false },
    { pos = vec4(1274.5361, 556.6722, 80.7869, 323.6469),  city = false },
    { pos = vec4(2314.2119, 2796.5393, 42.0428, 299.9959), city = false },
    { pos = vec4(2394.2659, 2928.0259, 49.3869, 35.3030),  city = false },
    { pos = vec4(2238.4172, 3257.6743, 48.1193, 12.4693),  city = false },
    { pos = vec4(2108.6147, 3748.6118, 33.1232, 297.9119), city = false },
    { pos = vec4(2481.6021, 4157.4697, 37.7625, 19.2874),  city = false },
    { pos = vec4(2411.7830, 4637.1855, 37.0091, 39.5443),  city = false },
    { pos = vec4(2028.7092, 4655.0679, 41.2654, 136.2345), city = false },
    { pos = vec4(1740.0444, 4593.8086, 40.6785, 41.5235),  city = false },
    { pos = vec4(1704.5562, 4802.4473, 41.8983, 93.4542),  city = false }  -- ziel
  },

  -- Heli
  heli = {
    { pos=vec4(-723.4202,-1442.2152,  5.0005,141.0090), city=false },
    { pos=vec4(-790.0000,-1520.0000, 60.0,  140.0),     city=false },
    { pos=vec4(-870.0000,-1650.0000, 90.0,  155.0),     city=false },
    { pos=vec4(-960.0000,-1800.0000,120.0,  180.0),     city=false },
    { pos=vec4(-1080.0000,-1950.0000,150.0, 200.0),     city=false },
    { pos=vec4(-1150.0000,-1700.0000,170.0, 320.0),     city=false },
    { pos=vec4(-1250.0000,-1450.0000,190.0, 340.0),     city=false },
    { pos=vec4(-1380.0000,-1180.0000,210.0,   0.0),     city=false },
    { pos=vec4(-1500.0000, -900.0000,230.0, 350.0),     city=false },
    { pos=vec4(-1585.0000, -650.0000,245.0, 350.0),     city=false },
    { pos=vec4(-1670.0000, -350.0000,260.0, 350.0),     city=false },
    { pos=vec4(-1750.0000,   50.0000,275.0, 350.0),     city=false },
    { pos=vec4(-1820.0000,  420.0000,290.0, 350.0),     city=false },
    { pos=vec4(-1875.0000,  780.0000,300.0,   0.0),     city=false },
    { pos=vec4(-1800.0000, 1050.0000,310.0,  25.0),     city=false },
    { pos=vec4(-1650.0000, 1300.0000,320.0,  30.0),     city=false },
    { pos=vec4(-1400.0000, 1500.0000,355.0,  50.0),     city=false },
    { pos=vec4(-1100.0000, 1600.0000,365.0,  70.0),     city=false },
    { pos=vec4( -800.0000, 1650.0000,375.0,  80.0),     city=false },
    { pos=vec4( -500.0000, 1620.0000,385.0, 100.0),     city=false },
    { pos=vec4( -200.0000, 1500.0000,395.0, 115.0),     city=false },
    { pos=vec4(  150.0000, 1400.0000,350.0, 120.0),     city=false },
    { pos=vec4(  480.0000, 1300.0000,325.0, 130.0),     city=false },
    { pos=vec4(  750.0000, 1150.0000,370.0, 150.0),     city=false },
    { pos=vec4(  980.0000,  950.0000,350.0, 160.0),     city=false },
    { pos=vec4( 1100.0000,  700.0000,325.0, 175.0),     city=false },
    { pos=vec4( 1150.0000,  400.0000,300.0, 185.0),     city=false },
    { pos=vec4( 1120.0000,   80.0000,275.0, 195.0),     city=false },
    { pos=vec4( 1000.0000, -250.0000,250.0, 210.0),     city=false },
    { pos=vec4(  820.0000, -550.0000,120.0, 220.0),     city=false },
    { pos=vec4(  600.0000, -850.0000,105.0, 230.0),     city=false },
    { pos=vec4(  250.0000,-1100.0000, 90.0, 250.0),     city=false },
    { pos=vec4( -150.0000,-1250.0000, 75.0, 250.0),     city=false },
    { pos=vec4( -420.0000,-1320.0000, 60.0, 255.0),     city=false },
    { pos=vec4( -650.0000,-1400.0000, 40.0, 300.0),     city=false }
  },

  -- Plane (erstes Element = Spawn)
  plane = {
    { pos=vec4(1731.2072, 3303.9492, 41.7639, 202.7309), city=false },
    { pos=vec4(1745.9871, 3259.2646, 41.9023, 105.6036), city=false },
    { pos=vec4(1578.3080, 3213.9912, 40.9318, 105.0430), city=false },
    { pos=vec4(1301.6362, 3138.0425, 103.4398, 104.7429), city=false },
    { pos=vec4(322.5877, 3482.6904, 162.4015, 39.7736), city=false },
    { pos=vec4(-364.4108, 4390.7744, 107.1691, 65.0592), city=false },
    { pos=vec4(-1529.3318, 4379.9170, 64.8706, 55.4117), city=false },
    { pos=vec4(-1841.4496, 4629.2793, 28.8752, 39.4669), city=false },
    { pos=vec4(-3378.6892, 3544.4797, 51.3934, 142.3803), city=false },
    { pos=vec4(-1892.0219, 2111.9458, 194.0812, 221.2779), city=false },
    { pos=vec4(1263.1082, 1897.8116, 366.6990, 250.0583), city=false },
    { pos=vec4(2562.9961, 1433.0730, 98.6538, 196.2792), city=false },
    { pos=vec4(2051.8464, -599.0001, 152.6066, 116.2007), city=false },
    { pos=vec4(-161.7829, 604.4610, 237.2563, 110.9644), city=false },
    { pos=vec4(-1892.5563, -61.1834, 137.9982, 124.7046), city=false },
    { pos=vec4(-1729.6465, -1168.0977, 36.6746, 206.1612), city=false },
    { pos=vec4(-26.8584, -1158.5771, 90.7884, 261.7910), city=false },
    { pos=vec4(-330.0636, -2332.2839, 37.3813, 119.9799), city=false },
    { pos=vec4(-498.6270, -3648.2380, 113.3594, 60.7673), city=false },
    { pos=vec4(-903.7595, -3399.1250, 32.5556, 59.3894), city=false },
    { pos=vec4(-1148.6887, -3251.0713, 16.5916, 60.7673), city=false },
    { pos=vec4(-1468.6669, -3066.1023, 13.5125, 59.2224), city=false },
    { pos=vec4(-1576.6393, -3018.5444, 13.5315, 146.3701), city=false },
    { pos=vec4(-1623.2596, -3095.2241, 13.5324, 149.9884), city=false }
  }
}

-------------------------------------------------------------------------------------------------
-- ZERTIFIKAT ITEMS (Inventar-Belohnungen Theorie/Praxis je Kategorie)
-------------------------------------------------------------------------------------------------
Config.Items = {
    theory = {
        car='cert_theory_pkw', bike='cert_theory_bike', truck='cert_theory_truck',
        heli='cert_theory_heli', plane='cert_theory_plane'
    },
    practice = {
        car='cert_practice_pkw', bike='cert_practice_bike', truck='cert_practice_truck',
        heli='cert_practice_heli', plane='cert_practice_plane'
    }
}

-------------------------------------------------------------------------------------------------
-- FÜHRERSCHEIN / AUSWEIS (benutzbare Items + /ausweis Anzeige – vollständig konfigurierbar)
-- Hinweise:
--  - UsePracticeItems=true nutzt die Praxis-Items als Ausweis (cert_practice_*).
--  - Anzeige-Optionen wirken live (Logo, AutoClose, Distanz, Labels).
--  - Eigene Items? -> UsePracticeItems=false und Items unten füllen, dann mtj_license_reload (oder Resource neu starten).
-------------------------------------------------------------------------------------------------
Config.License = {
    Enabled = true,

    UsePracticeItems = true, -- vorhandene Praxis-Zertifikats-Items als Ausweis verwenden

    ValidDays = {            -- Gültigkeit in Tagen je Klasse
        car = 3650, bike = 3650, truck = 3650, heli = 1825, plane = 1825
    },

    -- Branding
    OrganizationName = (Config.UI and (Config.UI.Schriftzug or Config.UI.Name)) or 'Fahrschule',
    LogoPath         = Config.UILogo or (Config.UI and Config.UI.Logo) or 'img/logo.png',
    DefaultPhotoURL  = 'img/logo.png',  -- Fallback-Foto

    -- Anzeigeverhalten
    Display = { AutoCloseSeconds = 8, FocusOnOpen = false },

    -- Zeigen an Dritte
    Show = {
        CommandName     = 'ausweis',          -- /ausweis [klasse] [id]
        Alias           = { 'showid', 'id' }, -- zusätzliche Befehle
        MaxDistance     = 4.5,                -- Distanz “nächster Spieler”
        ShowToSelfOnUse = true                -- beim Zeigen auch selbst sehen
    },

    -- Feldbeschriftungen
    Labels = {
        Title='Führerschein', Category='Klasse', Firstname='Vorname', Lastname='Nachname',
        Birthdate='Geburtsdatum', Height='Größe', IssuedAt='Ausgestellt am', ExpiresAt='Gültig bis'
    },

    -- Design-Style (American Black Theme)
    Style = {
        theme             = 'american_black', dark = true, american = true, uppercaseLabels = true,
        bg = '#0b0b0f', text = '#ffffff', border = '#1c1c22',
        headerAccentLeft  = '#0a3d91', headerAccentRight = '#e41e26',
        badgeBg           = '#0d1520',  badgeBorder       = 'rgba(0,200,255,0.25)',
        watermark         = 'flag_us'
    },

    -- Foto-Optionen (kein Auto-Foto beim Öffnen)
    Photo = { Mode='static', UseScreenshotBasic=false, Jpeg=true, Width=512, Height=512 },

    -- Optional: Eigene Item-Namen (statt Config.Items.practice)
    Items = { },

    -- FOTO-EINSCHREIBUNG (Führerschein erst nach Foto im Büro)
    Enrollment = {
        Enabled          = true,                                              -- aktiv
        PersistPending   = false,                                             -- “ausstehend” persistent (Server/SQL optional)
        Location         = vec4(203.8296, -1393.8674, 30.5835, 325.8693),     -- Fotopunkt (Wand)
        FreezeSeconds    = 2,                                                 -- Freeze beim Foto
        Use3DText        = true,                                              -- “E drücken” 3D-Text
        Key              = Config.KeyInteract or 38,                          -- Interaktionstaste (E)
        DrawDistance     = Config.DrawDistance or 25.0,                       -- Sichtweite
        InteractDistance = Config.InteractDistance or 2.0                     -- Abstand
    }
}

-------------------------------------------------------------------------------------------------
-- FEHLERNAMEN (Interne Keys -> Anzeige im Fehlerpanel)
-------------------------------------------------------------------------------------------------
Config.ErrorNames = {
    speeding   = 'Überschreitung der Höchstgeschwindigkeit',
    seatbelt   = 'Kein Sicherheitsgurt angelegt',
    route      = 'Route verlassen / Checkpoint verpasst',
    damage     = 'Fahrzeug stark beschädigt',
    collision  = 'Kollision / Rammen',
    notaustieg = 'Notausstieg / Fahrzeug ausgefallen'
}

-------------------------------------------------------------------------------------------------
-- UI LABELS (Alle verwendeten Textbausteine)
-------------------------------------------------------------------------------------------------
Config.Labels = {
    EToInteract           = '~INPUT_CONTEXT~ Drücke E',
    BookingTitle          = Config.UI.BookingTitle,
    TheoryTitle           = 'Theorieprüfung',
    PracticeTitle         = 'Praxisprüfung',
    SelectCategory        = 'Kategorie wählen',
    Categories            = { car='PKW', bike='Motorrad', truck='LKW', heli='Hubschrauber', plane='Flugzeug' },
    PayNow                = 'Jetzt buchen & bezahlen',
    StartTheory           = 'Theorieprüfung starten',
    StartPractice         = 'Praxisprüfung starten',
    NotEnoughMoney        = 'Nicht genug Geld.',
    PaidSuccess           = 'Buchung erfolgreich bezahlt. Gehe zu Punkt 2 für die Theorieprüfung!',
    PaidPracticeSuccess   = 'Praxis-Buchung bezahlt. Gehe zu Punkt 3 für die Praxisprüfung!',
    AlreadyBooked         = 'Du hast bereits gebucht. Gehe zu Punkt 2!',
    AlreadyBookedPractice = 'Praxis bereits gebucht. Gehe zu Punkt 3!',
    MustBookFirst         = 'Buche zuerst am Punkt 1.',
    MustPassTheoryFirst   = 'Praxis ist erst nach bestandener Theorie buchbar.',
    TheoryAlreadyPassed   = 'Theorie bereits bestanden. Gehe zu Punkt 3!',
    TheoryStartInfo       = 'Theorie gestartet. Viel Erfolg!',
    TheoryTimeOver        = 'Zeit abgelaufen! Leider nicht bestanden.',
    TheoryPassed          = 'Theorie bestanden! Hole die Urkunde ab und gehe zu Punkt 3.',
    TheoryFailed          = 'Theorie nicht bestanden. Bitte am Punkt 1 neu buchen.',
    PracticeStartInfo     = 'Praxis gestartet. Folge den Markierungen!',
    PracticeTooManyErrors = 'Zu viele Fehler. Praxis nicht bestanden.',
    PracticeDone          = 'Praxis bestanden! Glückwunsch!',
    PracticeSummary       = 'Zusammenfassung',
    ErrorsHeader          = 'Deine Fehler',
    PassedHeader          = 'Bestanden',
    FailedHeader          = 'Nicht bestanden',
    Speeding              = 'Überschreitung der Höchstgeschwindigkeit',
    VehicleDamage         = 'Fahrzeug stark beschädigt',
    LeftRoute             = 'Route verlassen / Checkpoint verpasst',
    Seatbelt              = 'Kein Sicherheitsgurt angelegt',
    ItemGiven             = 'Du hast ein Zertifikat erhalten: ',
    SpawnInfo             = 'Fahrzeug gespawnt. NPC sitzt als Beifahrer.',
    EndInfo               = 'Prüfung beendet.',
    Collision             = 'Kollision / Rammen',

    -- Einschreibung (Foto)
    EnrollGoToOffice      = 'Bitte gehe zum Fotopunkt in der Fahrschule, um deinen Führerschein zu erhalten.',
    EnrollPressE          = 'Drücke E für das Foto',
    EnrollDone            = 'Foto gespeichert. Führerschein ausgestellt!'
}

return Config -- Ende der Konfiguration (muss bestehen bleiben)