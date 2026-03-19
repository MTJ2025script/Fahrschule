// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// Flugzeug (plane) – lauffähig (ES5). Befüllt window.MTJ_QUESTIONS.plane mit deinen Fragen.
// In index.html VOR dem Fallback (questions_fallback.js) laden.
(function () {
  'use strict';
  if (typeof window === 'undefined') return;
  window.MTJ_QUESTIONS = window.MTJ_QUESTIONS || {};

  window.MTJ_QUESTIONS.plane = [
    { "text": "Was gehört zu einer ordentlichen Vorflugkontrolle (Preflight)?", "options":[
        {"key":"correct","text":"Kraftstoff, Öl, Ruderfreiheit, Klappen, Reifen, Pitot/Statik"},
        {"key":"wrong","text":"Nur Außenlack prüfen"},
        {"key":"wrong","text":"Nur Sitzposition prüfen"}
      ], "correct":0 },
    { "text": "Wie steuerst du am Boden hauptsächlich die Richtung?", "options":[
        {"key":"correct","text":"Mit Seitenruder/Nasenradlenkung (Pedale)"},
        {"key":"wrong","text":"Mit dem Höhenruder"},
        {"key":"wrong","text":"Mit den Querrudern"}
      ], "correct":0 },
    { "text": "Was bedeutet 'Hold Short' einer Startbahn?", "options":[
        {"key":"correct","text":"Vor der Markierung anhalten, keine Bahn kreuzen"},
        {"key":"wrong","text":"Langsam weiterrollen"},
        {"key":"wrong","text":"Sofort auf die Bahn rollen"}
      ], "correct":0 },
    { "text": "Warum ist Starten gegen den Wind vorteilhaft?", "options":[
        {"key":"correct","text":"Kürzerer Startweg, bessere Kontrolle"},
        {"key":"wrong","text":"Längerer Startweg"},
        {"key":"wrong","text":"Keine Auswirkung"}
      ], "correct":0 },
    { "text": "Was ist Rotationsgeschwindigkeit (Vr)?", "options":[
        {"key":"correct","text":"Geschwindigkeit, bei der die Nase zum Abheben angezogen wird"},
        {"key":"wrong","text":"Maximale Reisegeschwindigkeit"},
        {"key":"wrong","text":"Geschwindigkeit für Steilkurven"}
      ], "correct":0 },
    { "text": "Wofür steht Vy?", "options":[
        {"key":"correct","text":"Beste Steiggeschwindigkeit (höchste Steigrate)"},
        {"key":"wrong","text":"Beste Gleitgeschwindigkeit"},
        {"key":"wrong","text":"Geschwindigkeit für Kunstflug"}
      ], "correct":0 },
    { "text": "Wofür nutzt du Landeklappen beim Anflug?", "options":[
        {"key":"correct","text":"Höherer Auftrieb/Widerstand, langsamere, steilere Anflüge"},
        {"key":"wrong","text":"Nur für schnelleres Fliegen"},
        {"key":"wrong","text":"Nie verwenden"}
      ], "correct":0 },
    { "text": "Wie erkennst du einen Strömungsabriss (Stall)?", "options":[
        {"key":"correct","text":"Vibrationen, nachlassende Ruderwirkung, Nase sinkt"},
        {"key":"wrong","text":"Plötzliches Beschleunigen"},
        {"key":"wrong","text":"Stärkerer Auftrieb"}
      ], "correct":0 },
    { "text": "Wie leitest du die Stall-Erholung ein?", "options":[
        {"key":"correct","text":"Nase senken, Überziehwarnung beenden, Leistung dosiert setzen"},
        {"key":"wrong","text":"Nase weiter hoch ziehen"},
        {"key":"wrong","text":"Nur Querruder voll setzen"}
      ], "correct":0 },
    { "text": "Wie fliegst du den Platzrunden-Anflug korrekt?", "options":[
        {"key":"correct","text":"Downwind – Base – Final mit korrekten Höhen und Geschwindigkeiten"},
        {"key":"wrong","text":"Direkt vom Downwind zur Landung"},
        {"key":"wrong","text":"Ohne Geschwindigkeitskontrolle"}
      ], "correct":0 },
    { "text": "Welche Technik nutzt du bei Seitenwindlandungen?", "options":[
        {"key":"correct","text":"Crab im Endanflug, vor Aufsetzen entcrabben/Flügel tief, Gegenruder"},
        {"key":"wrong","text":"Nur schneller anfliegen"},
        {"key":"wrong","text":"Ohne Korrektur aufsetzen"}
      ], "correct":0 },
    { "text": "Wann führst du ein Go-Around durch?", "options":[
        {"key":"correct","text":"Instabiler Anflug, Hindernis, Bahn blockiert"},
        {"key":"wrong","text":"Wenn du zu hoch bist, trotzdem landen"},
        {"key":"wrong","text":"Nie, immer landen"}
      ], "correct":0 },
    { "text": "Wie verhältst du dich nach dem Aufsetzen beim Bremsen?", "options":[
        {"key":"correct","text":"Sanft bremsen, Schwerpunkt entlasten, Spur halten"},
        {"key":"wrong","text":"Nur Vollbremsung"},
        {"key":"wrong","text":"Lenkung loslassen"}
      ], "correct":0 },
    { "text": "Wie wirkt sich hohe Dichtehöhe aus?", "options":[
        {"key":"correct","text":"Weniger Leistung, längerer Start- und Landestrecke"},
        {"key":"wrong","text":"Mehr Leistung"},
        {"key":"wrong","text":"Keine Wirkung"}
      ], "correct":0 },
    { "text": "Wie vermeidest du Wake Turbulence von vorausfliegenden Jets?", "options":[
        {"key":"correct","text":"Über deren Flugbahn bleiben, aufsetzen hinter deren Aufsetzpunkt"},
        {"key":"wrong","text":"Direkt hinterher landen"},
        {"key":"wrong","text":"Tiefer über ihre Spur fliegen"}
      ], "correct":0 },
    { "text": "Wer hat Vorfahrt in der Luft?", "options":[
        {"key":"correct","text":"Das Luftfahrzeug rechts, Anflug hat Vorrang, langsamere/Luftschiffe/Ballone bevorzugt"},
        {"key":"wrong","text":"Immer der Schnellere"},
        {"key":"wrong","text":"Wer lauter hupt"}
      ], "correct":0 },
    { "text": "Welche Mindestreserve für Treibstoff ist sinnvoll (VFR)?", "options":[
        {"key":"correct","text":"Eine angemessene Reserve (z. B. 30+ Minuten)"},
        {"key":"wrong","text":"Genau bis zum Ziel"},
        {"key":"wrong","text":"Reserve ist unnötig"}
      ], "correct":0 },
    { "text": "Wie nutzt du Trimmung richtig?", "options":[
        {"key":"correct","text":"Last auf dem Steuerknüppel reduzieren, Geschwindigkeit/Höhe stabilisieren"},
        {"key":"wrong","text":"Für scharfe Kurven"},
        {"key":"wrong","text":"Nur am Boden"}
      ], "correct":0 },
    { "text": "Wie planst du den Sinkflug?", "options":[
        {"key":"correct","text":"Rechtzeitig Leistung reduzieren, Geschwindigkeit/Rate steuern"},
        {"key":"wrong","text":"Spät Gas raus und steil runter"},
        {"key":"wrong","text":"Ohne Planung sinken"}
      ], "correct":0 },
    { "text": "Was ist bei Vereisungsgefahr zu beachten?", "options":[
        {"key":"correct","text":"Leistung halten, Kurs ändern/steigen/sinken, Enteisung falls vorhanden"},
        {"key":"wrong","text":"Einfach ignorieren"},
        {"key":"wrong","text":"Maximal abkühlen"}
      ], "correct":0 },
    { "text": "Wie reagierst du bei Gewitter in der Nähe?", "options":[
        {"key":"correct","text":"Weiträumig umfliegen, Abstand halten"},
        {"key":"wrong","text":"Direkt durchfliegen"},
        {"key":"wrong","text":"Tiefer fliegen in die Böen"}
      ], "correct":0 },
    { "text": "Wie gehst du mit einem Triebwerksausfall um?", "options":[
        {"key":"correct","text":"Best Glide halten, Landefeld auswählen, Notverfahren"},
        {"key":"wrong","text":"Nase hochziehen bis Stillstand"},
        {"key":"wrong","text":"Nur Funk rufen, nichts tun"}
      ], "correct":0 },
    { "text": "Warum ist 'See and Avoid' wichtig?", "options":[
        {"key":"correct","text":"Kollisionsvermeidung durch aktives Sichten"},
        {"key":"wrong","text":"Nur ATC ist zuständig"},
        {"key":"wrong","text":"Nicht nötig in der Platzrunde"}
      ], "correct":0 },
    { "text": "Was bedeutet QNH am Höhenmesser?", "options":[
        {"key":"correct","text":"Auf Meereshöhe bezogener Druck für Höhenangabe über MSL"},
        {"key":"wrong","text":"Temperaturanzeige"},
        {"key":"wrong","text":"Motorleistungseinstellung"}
      ], "correct":0 },
    { "text": "Welche Rolle hat ATIS/ATC-Info vor dem Start?", "options":[
        {"key":"correct","text":"Wetter, Bahn in Betrieb, QNH, Hinweise"},
        {"key":"wrong","text":"Nur Musik"},
        {"key":"wrong","text":"Nicht relevant"}
      ], "correct":0 },
    { "text": "Was passiert bei blockiertem Pitotrohr?", "options":[
        {"key":"correct","text":"Falsche/ausfallende Fahrtanzeige"},
        {"key":"wrong","text":"Motor geht aus"},
        {"key":"wrong","text":"Fahrwerk fährt ein"}
      ], "correct":0 },
    { "text": "Was tust du bei unstabilem Anflug unter 200 ft?", "options":[
        {"key":"correct","text":"Go-Around durchführen"},
        {"key":"wrong","text":"Weiterlanden erzwingen"},
        {"key":"wrong","text":"Nur härter bremsen"}
      ], "correct":0 },
    { "text": "Wie hältst du den Kurs im Seitenwind nach dem Start?", "options":[
        {"key":"correct","text":"Mit Seitenruder ausrichten und leicht gegen den Wind neigen"},
        {"key":"wrong","text":"Querruder voll ins Lee, kein Seitenruder"},
        {"key":"wrong","text":"Ignorieren, wegdriften lassen"}
      ], "correct":0 },
    { "text": "Was bedeutet die gelb-schwarze Haltelinie vor der Bahn (Runway Holding Position)?", "options":[
        {"key":"correct","text":"Hier stoppen, ATC/Freigabe abwarten, Bahn nicht kreuzen"},
        {"key":"wrong","text":"Nur langsam rollen, kreuzen erlaubt"},
        {"key":"wrong","text":"Nur für Fahrzeuge gültig"}
      ], "correct":0 },
    { "text": "Warum nach der Landung Klappen einfahren und Checkliste nutzen?", "options":[
        {"key":"correct","text":"Für sichere Bodenlage und geordnetes Nachverfahren"},
        {"key":"wrong","text":"Nur um schneller zu parken"},
        {"key":"wrong","text":"Unnötig nach dem Aufsetzen"}
      ], "correct":0 }
  ];
})();