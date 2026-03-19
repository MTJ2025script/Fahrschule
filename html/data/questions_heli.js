// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// Hubschrauber (heli) – lauffähig (ES5). Befüllt window.MTJ_QUESTIONS.heli mit deinen Fragen.
// In index.html UNBEDINGT VOR dem Fallback (questions_fallback.js) laden.
(function () {
  'use strict';
  if (typeof window === 'undefined') return;
  window.MTJ_QUESTIONS = window.MTJ_QUESTIONS || {};

  window.MTJ_QUESTIONS.heli = [
    { "text": "Worauf musst du vor dem Start mit dem Hubschrauber besonders achten?", "options":[
        {"key":"correct","text":"Freier Rotorkreis, Hindernisse und Personen sichern"},
        {"key":"wrong","text":"Nur auf den Treibstoffstand"},
        {"key":"wrong","text":"Nur auf die Sitzposition"}
      ], "correct":0 },
    { "text": "Wie landest du idealerweise in Bezug auf den Wind?", "options":[
        {"key":"correct","text":"Gegen den Wind anfliegen und landen"},
        {"key":"wrong","text":"Mit Rückenwind anfliegen"},
        {"key":"wrong","text":"Windrichtung ist egal"}
      ], "correct":0 },
    { "text": "Was ist der Wirbelringzustand (Vortex Ring State)?", "options":[
        {"key":"correct","text":"Abstiegszustand, bei dem der Rotor in seine eigenen Wirbel sinkt"},
        {"key":"wrong","text":"Ein Zustand maximaler Auftriebserzeugung"},
        {"key":"wrong","text":"Eine Fehlfunktion des Triebwerks"}
      ], "correct":0 },
    { "text": "Wie beendest du den Wirbelringzustand am sichersten?", "options":[
        {"key":"correct","text":"Vorwärtsfahrt erhöhen und Kollektiv zunächst reduziert halten"},
        {"key":"wrong","text":"Voll kollektiv ziehen"},
        {"key":"wrong","text":"Nur mehr Heckrotor geben"}
      ], "correct":0 },
    { "text": "Was bedeutet LTE (Loss of Tail Rotor Effectiveness)?", "options":[
        {"key":"correct","text":"Verlust der Heckrotor-Wirksamkeit, ungewolltes Gieren"},
        {"key":"wrong","text":"Motorüberdrehzahl"},
        {"key":"wrong","text":"Hydraulikausfall"}
      ], "correct":0 },
    { "text": "Wie reagierst du bei LTE?", "options":[
        {"key":"correct","text":"Gegensteuern mit Pedal, Vorwärtsfahrt erhöhen, Leistung anpassen"},
        {"key":"wrong","text":"Motor aus und autorotieren"},
        {"key":"wrong","text":"Nur tiefer ziehen bis es aufhört"}
      ], "correct":0 },
    { "text": "Was ist Autorotation?", "options":[
        {"key":"correct","text":"Sinkflug mit angetriebenem Rotor durch Luftstrom, Motorleistung nicht erforderlich"},
        {"key":"wrong","text":"Steigflug mit maximaler Leistung"},
        {"key":"wrong","text":"Seitwärts-Schweben im Wind"}
      ], "correct":0 },
    { "text": "Welche Geschwindigkeit unterstützt die Autorotation typischerweise?", "options":[
        {"key":"correct","text":"Eine gemäß Flughandbuch empfohlene bestmögliche Gleitgeschwindigkeit"},
        {"key":"wrong","text":"Maximale Vorwärtsgeschwindigkeit"},
        {"key":"wrong","text":"Stillstand in Bodennähe"}
      ], "correct":0 },
    { "text": "Was ist ETL (Effective Translational Lift)?", "options":[
        {"key":"correct","text":"Zusätzlicher Auftrieb durch ungestörte Anströmung ab ca. 15–25 Knoten"},
        {"key":"wrong","text":"Verlust an Auftrieb bei Rückenwind"},
        {"key":"wrong","text":"Reiner Heckrotoreffekt"}
      ], "correct":0 },
    { "text": "Was ist bei der Landung am Hang zu beachten?", "options":[
        {"key":"correct","text":"Zuerst hangaufwärtiges Fahrwerk aufsetzen, Rotorscheibe zur Hangseite neigen"},
        {"key":"wrong","text":"Mit Rücken zum Hang landen"},
        {"key":"wrong","text":"Mit maximaler Geschwindigkeit aufsetzen"}
      ], "correct":0 },
    { "text": "Warum ist Rückenwind bei Start/Landung problematisch?", "options":[
        {"key":"correct","text":"Erhöht den Leistungsbedarf und verringert Steuerreserven"},
        {"key":"wrong","text":"Keine Auswirkung"},
        {"key":"wrong","text":"Erhöht immer die Stabilität"}
      ], "correct":0 },
    { "text": "Was ist Bodenschwingung (Ground Resonance)?", "options":[
        {"key":"correct","text":"Gefährliche Schwingung bei Bodenkontakt und unsymmetrischer Rotormasse"},
        {"key":"wrong","text":"Turbulenzen in großer Höhe"},
        {"key":"wrong","text":"Hydraulische Schwingung im Steuerkreis"}
      ], "correct":0 },
    { "text": "Wie vermeidest du Bodenschwingung?", "options":[
        {"key":"correct","text":"Sanfte Landung, korrektes Fahrwerk, keine abrupten Kollektivbewegungen"},
        {"key":"wrong","text":"Nur mehr Heckrotor geben"},
        {"key":"wrong","text":"Immer hart aufsetzen"}
      ], "correct":0 },
    { "text": "Was bedeutet 'Mast Bumping' bei gelenkigen Rotorsystemen?", "options":[
        {"key":"correct","text":"Anschlagen der Rotornabe am Mast durch zu große Schlagwinkel"},
        {"key":"wrong","text":"Ein normaler Wartungsvorgang"},
        {"key":"wrong","text":"Nur ein optisches Phänomen"}
      ], "correct":0 },
    { "text": "Wie beeinflusst die Dichtehöhe die Leistung?", "options":[
        {"key":"correct","text":"Höhere Dichtehöhe = weniger Leistung, längerer Start/Landeweg"},
        {"key":"wrong","text":"Keine Auswirkung"},
        {"key":"wrong","text":"Mehr Leistung bei großer Höhe"}
      ], "correct":0 },
    { "text": "Warum ist Gewichts- und Schwerpunktberechnung wichtig?", "options":[
        {"key":"correct","text":"Für ausreichende Steuerbarkeit und Leistungsreserven"},
        {"key":"wrong","text":"Nur für die Optik"},
        {"key":"wrong","text":"Nicht relevant beim Schweben"}
      ], "correct":0 },
    { "text": "Welche Gefahr besteht in Landezonen mit Hindernissen?", "options":[
        {"key":"correct","text":"Rotorkontakt mit Hindernissen, Heckrotorgefahr"},
        {"key":"wrong","text":"Keine, Hindernisse sind egal"},
        {"key":"wrong","text":"Nur kosmetischer Schaden"}
      ], "correct":0 },
    { "text": "Was tust du bei 'Low RPM' Warnung (Rotor RPM zu niedrig)?", "options":[
        {"key":"correct","text":"Kollektiv reduzieren, Rotor RPM stabilisieren"},
        {"key":"wrong","text":"Mehr Kollektiv ziehen"},
        {"key":"wrong","text":"Warnung ignorieren"}
      ], "correct":0 },
    { "text": "Wofür ist der Governor zuständig?", "options":[
        {"key":"correct","text":"Hält die Rotordrehzahl automatisch innerhalb des Bereichs"},
        {"key":"wrong","text":"Steuert nur den Heckrotor"},
        {"key":"wrong","text":"Ist eine Landebeleuchtung"}
      ], "correct":0 },
    { "text": "Warum Checklisten konsequent nutzen?", "options":[
        {"key":"correct","text":"Verhindert Vergessen kritischer Schritte"},
        {"key":"wrong","text":"Nur für Prüfungen wichtig"},
        {"key":"wrong","text":"Hält nur auf"}
      ], "correct":0 },
    { "text": "Welche LZ (Landezone) ist geeignet?", "options":[
        {"key":"correct","text":"Ausreichend groß, frei von Hindernissen, Bodenfestigkeit geprüft"},
        {"key":"wrong","text":"Beliebig, Hauptsache nah"},
        {"key":"wrong","text":"Mit Personen nah am Rotor"}
      ], "correct":0 },
    { "text": "Wie verhältst du dich bei Hydraulikausfall?", "options":[
        {"key":"correct","text":"Höhere Steuerkräfte, sanfte Bewegungen, Landeplatz ansteuern"},
        {"key":"wrong","text":"Abrupt voll ausschlagen"},
        {"key":"wrong","text":"Weiterflug wie gewohnt"}
      ], "correct":0 },
    { "text": "Wann nutzt du die Schwebehöhe in Bodennähe (IGE)?", "options":[
        {"key":"correct","text":"Zum Leistungscheck und stabilen Abheben/Landen"},
        {"key":"wrong","text":"Nie, immer OGE"},
        {"key":"wrong","text":"Nur bei Rückenwind"}
      ], "correct":0 },
    { "text": "Worin unterscheidet sich Hover IGE vs OGE?", "options":[
        {"key":"correct","text":"IGE benötigt weniger Leistung als OGE"},
        {"key":"wrong","text":"IGE braucht mehr Leistung"},
        {"key":"wrong","text":"Kein Unterschied"}
      ], "correct":0 },
    { "text": "Wie minimierst du Lärm in Besiedelung?", "options":[
        {"key":"correct","text":"Höhen einhalten, sensible Bereiche meiden, ruhige Profile"},
        {"key":"wrong","text":"Extra tief fliegen"},
        {"key":"wrong","text":"Ständig Vollgas geben"}
      ], "correct":0 },
    { "text": "Was ist beim Nachtflug zu beachten?", "options":[
        {"key":"correct","text":"LZ ausleuchten, Hindernisse markieren, langsam anfliegen"},
        {"key":"wrong","text":"Schneller fliegen wegen Dunkelheit"},
        {"key":"wrong","text":"Nur auf GPS schauen"}
      ], "correct":0 },
    { "text": "Wie reagierst du bei plötzlich starkem Seitenwind im Endanflug?", "options":[
        {"key":"correct","text":"Anflug abbrechen, neu ausrichten, Leistung managen"},
        {"key":"wrong","text":"Augen zu und durch"},
        {"key":"wrong","text":"Nur mehr Heckrotor geben"}
      ], "correct":0 },
    { "text": "Welche Gefahr besteht nahe Gebäuden im Schwebeflug?", "options":[
        {"key":"correct","text":"Rotorwirbel und Rückströmungen können Leistung erfordern"},
        {"key":"wrong","text":"Keine, Gebäude stabilisieren Luft"},
        {"key":"wrong","text":"Nur optische Täuschung"}
      ], "correct":0 },
    { "text": "Worauf achtest du beim Start von einer Dach-LZ?", "options":[
        {"key":"correct","text":"Abwind- und Aufwindfelder, Hindernisse, ausreichende Leistung"},
        {"key":"wrong","text":"Nur auf die Farbe des Dachs"},
        {"key":"wrong","text":"Nichts Besonderes"}
      ], "correct":0 },
    { "text": "Warum sind Personen in Heckrotornähe besonders gefährdet?", "options":[
        {"key":"correct","text":"Schlecht sichtbar, hohe Drehzahl, geringe Bodenfreiheit"},
        {"key":"wrong","text":"Der Heckrotor steht meistens"},
        {"key":"wrong","text":"Nur lauter Lärm, keine Gefahr"}
      ], "correct":0 }
  ];
})();