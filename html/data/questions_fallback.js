// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// LKW (truck) – 25 Fragen. Dieses Skript muss NACH dem Boot-Snippet geladen werden, das window.MTJ_QUESTIONS initialisiert.
(function () {
  'use strict';
  if (typeof window === 'undefined') return;
  window.MTJ_QUESTIONS = window.MTJ_QUESTIONS || {};

  window.MTJ_QUESTIONS.truck = [
    { text: "Welche Höchstgeschwindigkeit gilt für LKW außerorts in der Regel?", options: [
      { key: "correct", text: "80 km/h" },
      { key: "wrong", text: "100 km/h" },
      { key: "wrong", text: "120 km/h" }
    ]},
    { text: "Wie groß sollte der Sicherheitsabstand mit LKW sein?", options: [
      { key: "correct", text: "Ausreichend, größer als mit PKW (Gewicht/Bremsweg)" },
      { key: "wrong", text: "Sehr gering" },
      { key: "wrong", text: "Unwichtig" }
    ]},
    { text: "Wie beeinflusst Beladung das Fahrverhalten?", options: [
      { key: "correct", text: "Längerer Bremsweg, instabileres Kurvenverhalten" },
      { key: "wrong", text: "Gar nicht" },
      { key: "wrong", text: "Verbessert Bremsweg" }
    ]},
    { text: "Was ist vor Fahrtantritt zu prüfen?", options: [
      { key: "correct", text: "Ladungssicherung, Reifen, Beleuchtung, Bremsen" },
      { key: "wrong", text: "Nur Radio" },
      { key: "wrong", text: "Nur Hupe" }
    ]},
    { text: "Wie groß ist der tote Winkel beim LKW?", options: [
      { key: "correct", text: "Groß, v. a. rechts und direkt vor dem Fahrzeug" },
      { key: "wrong", text: "Nur hinten minimal" },
      { key: "wrong", text: "Keiner" }
    ]},
    { text: "Wie fährst du Kreisverkehre mit LKW?", options: [
      { key: "correct", text: "Langsam, weit ausholen, auf Ausschwenken achten" },
      { key: "wrong", text: "Wie PKW mit Vollgas" },
      { key: "wrong", text: "Immer innere Spur" }
    ]},
    { text: "Wie verhältst du dich beim Überholen mit LKW?", options: [
      { key: "correct", text: "Nur wenn genügend Strecke frei und ohne Gefährdung" },
      { key: "wrong", text: "Immer, auch bergauf" },
      { key: "wrong", text: "Zwischen zwei LKW pressen" }
    ]},
    { text: "Warum ist richtiger Reifendruck beim LKW wichtig?", options: [
      { key: "correct", text: "Sicherheit, Verschleiß, Bremsweg" },
      { key: "wrong", text: "Nur Optik" },
      { key: "wrong", text: "Unbedeutend" }
    ]},
    { text: "Wie fährst du längere Gefälle sicher?", options: [
      { key: "correct", text: "Motor-/Retarderbremse nutzen, nicht Dauerbremsen" },
      { key: "wrong", text: "Im Leerlauf rollen lassen" },
      { key: "wrong", text: "Nur Vollbremsung" }
    ]},
    { text: "Was ist bei starkem Seitenwind zu beachten?", options: [
      { key: "correct", text: "Aufbauten bieten Angriffsfläche, mitlenken" },
      { key: "wrong", text: "Egal" },
      { key: "wrong", text: "Mehr Gas geben" }
    ]},
    { text: "Wie sicherst du Ladung richtig?", options: [
      { key: "correct", text: "Form-/Kraftschluss, Zurrgurte, Antirutschmatten" },
      { key: "wrong", text: "Gar nicht" },
      { key: "wrong", text: "Nur Folie" }
    ]},
    { text: "Wann ist Überholverbot für LKW besonders zu beachten?", options: [
      { key: "correct", text: "Beschilderung, Wetter, Gefahrenstellen" },
      { key: "wrong", text: "Nie" },
      { key: "wrong", text: "Nur innerorts" }
    ]},
    { text: "Wie viel Platz brauchst du beim Rechtsabbiegen mit LKW?", options: [
      { key: "correct", text: "Mehr, da Anhänger/Heck ausschwenkt" },
      { key: "wrong", text: "Wie PKW" },
      { key: "wrong", text: "Weniger" }
    ]},
    { text: "Warum sind längere Anhaltewege beim LKW kritisch?", options: [
      { key: "correct", text: "Hohes Gewicht = deutlich längerer Bremsweg" },
      { key: "wrong", text: "Weil sie lauter sind" },
      { key: "wrong", text: "Weil sie kleiner sind" }
    ]},
    { text: "Wie verhältst du dich an Bahnübergängen?", options: [
      { key: "correct", text: "Nicht überholen, rechtzeitig anhalten" },
      { key: "wrong", text: "Zwischen Schranken durchfahren" },
      { key: "wrong", text: "Immer hupen" }
    ]},
    { text: "Wie fährst du in Wohngebieten mit LKW?", options: [
      { key: "correct", text: "Langsam, vorausschauend, enge Kurven beachten" },
      { key: "wrong", text: "Schnell und breit" },
      { key: "wrong", text: "Immer Lichthupe" }
    ]},
    { text: "Lenk- und Ruhezeiten sind …", options: [
      { key: "correct", text: "Einzuhalten, Verstöße gefährden Sicherheit" },
      { key: "wrong", text: "Unwichtig, nur Empfehlung" },
      { key: "wrong", text: "Nur bei Fernverkehr" }
    ]},
    { text: "Achslasten und Gesamtgewicht …", options: [
      { key: "correct", text: "Dürfen nicht überschritten werden" },
      { key: "wrong", text: "Sind egal, wenn beladen" },
      { key: "wrong", text: "Gelten nur für Anhänger" }
    ]},
    { text: "Gefahrgut (ADR) erfordert …", options: [
      { key: "correct", text: "Ausrüstung, Kennzeichnung, Schulung" },
      { key: "wrong", text: "Keine besonderen Maßnahmen" },
      { key: "wrong", text: "Nur Warnblinker" }
    ]},
    { text: "Rückwärtsfahren mit LKW …", options: [
      { key: "correct", text: "Wenn möglich mit Einweiser/Spiegeln/Kamera" },
      { key: "wrong", text: "Immer schnell, ohne Sicherung" },
      { key: "wrong", text: "Nur nach Gefühl" }
    ]},
    { text: "Abfahrtskontrolle beinhaltet …", options: [
      { key: "correct", text: "Bremsen, Licht, Reifen, Ladung, Papiere/Tacho" },
      { key: "wrong", text: "Nur Tankanzeige" },
      { key: "wrong", text: "Nur Radio" }
    ]},
    { text: "Im Tunnel gilt …", options: [
      { key: "correct", text: "Licht an, Abstand, nicht wenden/überholen" },
      { key: "wrong", text: "Schneller fahren für kürzere Tunnelzeit" },
      { key: "wrong", text: "Warnblinker dauerhaft" }
    ]},
    { text: "Bei Regen/Nässe …", options: [
      { key: "correct", text: "Geschwindigkeit reduzieren, Abstand erhöhen" },
      { key: "wrong", text: "Geschwindigkeit erhöhen" },
      { key: "wrong", text: "Unverändert weiterfahren" }
    ]},
    { text: "Berganfahren mit LKW …", options: [
      { key: "correct", text: "Roll-back vermeiden, ggf. Feststellbremse nutzen" },
      { key: "wrong", text: "Im Leerlauf rollen" },
      { key: "wrong", text: "Mit Vollgas ohne Kupplung" }
    ]},
    { text: "Warnleuchten im Armaturenbrett bedeuten …", options: [
      { key: "correct", text: "Störung prüfen, sicher anhalten/Werkstatt" },
      { key: "wrong", text: "Ignorieren bis zum Ziel" },
      { key: "wrong", text: "Abkleben" }
    ]}
  ];
})();