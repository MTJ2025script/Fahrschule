// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// PKW (car) – lauffähig (ES5). Dieses Skript befüllt window.MTJ_QUESTIONS.car mit deinen Fragen.
// In index.html unbedingt VOR dem Fallback (questions_fallback.js) laden.
(function () {
  'use strict';
  if (typeof window === 'undefined') return;
  window.MTJ_QUESTIONS = window.MTJ_QUESTIONS || {};

  window.MTJ_QUESTIONS.car = [
    { "text": "Wie schnell darfst du innerorts mit einem PKW in der Regel fahren?", "options": [
        {"key":"correct","text":"50 km/h"},
        {"key":"wrong","text":"60 km/h"},
        {"key":"wrong","text":"70 km/h"}
      ], "correct": 0 },
    { "text": "Was bedeutet ein rotes Ampelsignal?", "options": [
        {"key":"correct","text":"Halt vor der Haltelinie"},
        {"key":"wrong","text":"Langsam weiterfahren"},
        {"key":"wrong","text":"Nur bei Verkehr halten"}
      ], "correct": 0 },
    { "text": "Wann musst du den Blinker setzen?", "options": [
        {"key":"correct","text":"Beim Abbiegen und Spurwechsel"},
        {"key":"wrong","text":"Nur beim Abbiegen"},
        {"key":"wrong","text":"Nur in Einbahnstraßen"}
      ], "correct": 0 },
    { "text": "Was musst du an einem Zebrastreifen beachten?", "options": [
        {"key":"correct","text":"Fußgänger haben Vorrang"},
        {"key":"wrong","text":"Nur anhalten wenn Polizei in der Nähe ist"},
        {"key":"wrong","text":"Nur nachts anhalten"}
      ], "correct": 0 },
    { "text": "Wofür steht das Verkehrszeichen „Stop“?", "options": [
        {"key":"correct","text":"Vollständiger Halt, Vorfahrt gewähren"},
        {"key":"wrong","text":"Langsam rollen lassen"},
        {"key":"wrong","text":"Nur bei Gegenverkehr halten"}
      ], "correct": 0 },
    { "text": "Wie verhältst du dich bei Nebel?", "options": [
        {"key":"correct","text":"Langsamer fahren, Abstand vergrößern, Licht an"},
        {"key":"wrong","text":"Schneller fahren, um schnell durchzukommen"},
        {"key":"wrong","text":"Nur Warnblinker einschalten"}
      ], "correct": 0 },
    { "text": "Was ist der Anhalteweg?", "options": [
        {"key":"correct","text":"Reaktionsweg + Bremsweg"},
        {"key":"wrong","text":"Nur Bremsweg"},
        {"key":"wrong","text":"Nur Reaktionsweg"}
      ], "correct": 0 },
    { "text": "Wo gilt rechts vor links?", "options": [
        {"key":"correct","text":"An Kreuzungen ohne Beschilderung"},
        {"key":"wrong","text":"An Autobahnauffahrten"},
        {"key":"wrong","text":"An jeder Ampelkreuzung"}
      ], "correct": 0 },
    { "text": "Wann darfst du die Hupe nutzen?", "options": [
        {"key":"correct","text":"Zur Warnung bei Gefahr"},
        {"key":"wrong","text":"Zum Grüßen von Freunden"},
        {"key":"wrong","text":"An roten Ampeln zum Drängeln"}
      ], "correct": 0 },
    { "text": "Wie sicherst du ein Fahrzeug am Berg?", "options": [
        {"key":"correct","text":"Feststellbremse, Gang einlegen, Räder eindrehen"},
        {"key":"wrong","text":"Nur Motor aus"},
        {"key":"wrong","text":"Nur Warnblinker einsetzen"}
      ], "correct": 0 },
    { "text": "Was bedeutet eine durchgezogene Linie?", "options": [
        {"key":"correct","text":"Nicht überfahren, nicht überholen"},
        {"key":"wrong","text":"Nur vorsichtig überfahren"},
        {"key":"wrong","text":"Überholen erlaubt"}
      ], "correct": 0 },
    { "text": "Was ist ein toter Winkel?", "options": [
        {"key":"correct","text":"Bereich, der im Spiegel nicht sichtbar ist"},
        {"key":"wrong","text":"Bereich ohne Straßenbeleuchtung"},
        {"key":"wrong","text":"Bereich hinter parkenden Autos"}
      ], "correct": 0 },
    { "text": "Wie verhältst du dich bei Blaulicht und Martinshorn?", "options": [
        {"key":"correct","text":"Sofort freie Bahn schaffen"},
        {"key":"wrong","text":"Gleich bleiben, die finden schon vorbei"},
        {"key":"wrong","text":"Weiterfahren und ignorieren"}
      ], "correct": 0 },
    { "text": "Was machst du bei Aquaplaning?", "options": [
        {"key":"correct","text":"Gas wegnehmen, nicht stark lenken/bremsen"},
        {"key":"wrong","text":"Voll bremsen"},
        {"key":"wrong","text":"Voll beschleunigen"}
      ], "correct": 0 },
    { "text": "Was ist beim Überholen zu beachten?", "options": [
        {"key":"correct","text":"Genügend Abstand, zügig, ohne Gefährdung"},
        {"key":"wrong","text":"Immer links blinken ohne Abstand"},
        {"key":"wrong","text":"Nur im Gegenverkehr überholen"}
      ], "correct": 0 },
    { "text": "Welche Reifenprofiltiefe ist mindestens empfohlen?", "options": [
        {"key":"correct","text":"Mind. 1,6 mm (besser mehr)"},
        {"key":"wrong","text":"0,5 mm"},
        {"key":"wrong","text":"0 mm, Hauptsache Luft"}
      ], "correct": 0 },
    { "text": "Wann musst du Licht einschalten?", "options": [
        {"key":"correct","text":"Bei Dunkelheit, Dämmerung, schlechter Sicht"},
        {"key":"wrong","text":"Nur nachts auf Autobahnen"},
        {"key":"wrong","text":"Nur bei Regen"}
      ], "correct": 0 },
    { "text": "Wofür steht eine gelbe Ampel?", "options": [
        {"key":"correct","text":"Halt, wenn möglich sicher anhalten"},
        {"key":"wrong","text":"Gib Gas!"},
        {"key":"wrong","text":"Gilt nicht für PKW"}
      ], "correct": 0 },
    { "text": "Wie verhältst du dich an einer grünen Ampel?", "options": [
        {"key":"correct","text":"Vorsichtig einfahren, Kreuzung beobachten"},
        {"key":"wrong","text":"Blindlings losfahren"},
        {"key":"wrong","text":"Immer hupen"}
      ], "correct": 0 },
    { "text": "Was gilt in Spielstraßen?", "options": [
        {"key":"correct","text":"Schritttempo, besondere Rücksicht"},
        {"key":"wrong","text":"50 km/h"},
        {"key":"wrong","text":"Überholen erlaubt"}
      ], "correct": 0 },
    { "text": "Was bedeutet ein blaues Schild mit Pfeilen nach unten (Einbahnstraße)?", "options": [
        {"key":"correct","text":"Nur in Pfeilrichtung fahren"},
        {"key":"wrong","text":"In beide Richtungen fahren"},
        {"key":"wrong","text":"Parken verboten"}
      ], "correct": 0 },
    { "text": "Warum ist ausreichender Abstand wichtig?", "options": [
        {"key":"correct","text":"Mehr Reaktionszeit, Unfallvermeidung"},
        {"key":"wrong","text":"Damit andere einscheren müssen"},
        {"key":"wrong","text":"Kein Vorteil"}
      ], "correct": 0 },
    { "text": "Worauf achtest du beim Rückwärtsfahren?", "options": [
        {"key":"correct","text":"Rundumblick, Spiegel, ggf. aussteigen"},
        {"key":"wrong","text":"Nur Rückfahrkamera"},
        {"key":"wrong","text":"Augen zu und durch"}
      ], "correct": 0 },
    { "text": "Was sind Vorfahrtsregeln an Kreisverkehren?", "options": [
        {"key":"correct","text":"Fahrzeuge im Kreis haben Vorfahrt"},
        {"key":"wrong","text":"Einfahrende haben Vorfahrt"},
        {"key":"wrong","text":"Alle gleichzeitig"}
      ], "correct": 0 },
    { "text": "Was ist bei Bahnübergängen zu beachten?", "options": [
        {"key":"correct","text":"Anhalten bei Rot/Schranken, Sichtprüfung"},
        {"key":"wrong","text":"Ignorieren, Züge halten"},
        {"key":"wrong","text":"Nur hupen"}
      ], "correct": 0 },
    { "text": "Wie verhältst du dich bei Stau auf Autobahnen?", "options": [
        {"key":"correct","text":"Rettungsgasse bilden"},
        {"key":"wrong","text":"Linke Spur blockieren"},
        {"key":"wrong","text":"Standstreifen nutzen"}
      ], "correct": 0 },
    { "text": "Was ist defensives Fahren?", "options": [
        {"key":"correct","text":"Vorausschauend, rücksichtsvoll, gelassen"},
        {"key":"wrong","text":"Aggressiv, schnell, risikofreudig"},
        {"key":"wrong","text":"Immer Vorfahrt erzwingen"}
      ], "correct": 0 },
    { "text": "Wann ist Handybenutzung erlaubt?", "options": [
        {"key":"correct","text":"Nur mit Freisprecheinrichtung"},
        {"key":"wrong","text":"Immer, wenn langsam"},
        {"key":"wrong","text":"Nie verboten"}
      ], "correct": 0 },
    { "text": "Wie verhältst du dich bei Unfall am Unfallort?", "options": [
        {"key":"correct","text":"Absichern, Erste Hilfe, Notruf"},
        {"key":"wrong","text":"Schnell wegfahren"},
        {"key":"wrong","text":"Nur filmen"}
      ], "correct": 0 }
  ];
})();