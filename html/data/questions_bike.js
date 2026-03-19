// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// Motorrad (bike) – deine Fragen lauffähig gemacht (ES5). Kann beliebig viele Fragen enthalten.
// Das UI nimmt pro Test automatisch 25 zufällige Fragen und mischt die Optionen.
(function () {
  'use strict';
  if (typeof window === 'undefined') return;
  window.MTJ_QUESTIONS = window.MTJ_QUESTIONS || {};

  window.MTJ_QUESTIONS.bike = [
    { text: "Welche Schutzkleidung ist auf dem Motorrad sinnvoll?", options: [
      { key: "correct", text: "Helm, Handschuhe, Jacke, Hose, Stiefel" },
      { key: "wrong", text: "Nur Helm" },
      { key: "wrong", text: "Flip-Flops reichen" }
    ]},
    { text: "Wie fährst du Kurven sicher?", options: [
      { key: "correct", text: "Blickführung, saubere Linie, passende Geschwindigkeit" },
      { key: "wrong", text: "Mit Vollgas in jede Kurve" },
      { key: "wrong", text: "Nur Vorderradbremse" }
    ]},
    { text: "Wie verhältst du dich beim Spurwechsel?", options: [
      { key: "correct", text: "Schulterblick, Blinken, Abstand" },
      { key: "wrong", text: "Nur blinken" },
      { key: "wrong", text: "Einfach rüberziehen" }
    ]},
    { text: "Warum ist der Tote Winkel besonders gefährlich?", options: [
      { key: "correct", text: "Motorräder sind klein und schwer zu sehen" },
      { key: "wrong", text: "Motorräder sind laut" },
      { key: "wrong", text: "Kein Problem" }
    ]},
    { text: "Wie dosierst du Bremsen optimal?", options: [
      { key: "correct", text: "Vorne stärker, hinten dosiert, nicht blockieren" },
      { key: "wrong", text: "Nur hinten bremsen" },
      { key: "wrong", text: "Immer blockieren lassen" }
    ]},
    { text: "Welche Reifenprofiltiefe ist sinnvoll?", options: [
      { key: "correct", text: "Mind. 1,6 mm (mehr ist besser)" },
      { key: "wrong", text: "0,5 mm" },
      { key: "wrong", text: "0 mm" }
    ]},
    { text: "Wie reagierst du auf Rollsplitt in Kurven?", options: [
      { key: "correct", text: "Geschwindigkeit reduzieren, sanft fahren" },
      { key: "wrong", text: "Schräglage erhöhen" },
      { key: "wrong", text: "Stark bremsen in Schräglage" }
    ]},
    { text: "Welche Beleuchtung tagsüber sinnvoll?", options: [
      { key: "correct", text: "Abblendlicht für bessere Sichtbarkeit" },
      { key: "wrong", text: "Kein Licht" },
      { key: "wrong", text: "Nur Fernlicht" }
    ]},
    { text: "Wie schützt du dich vor Müdigkeit?", options: [
      { key: "correct", text: "Pausen, Wasser, Bewegung" },
      { key: "wrong", text: "Mehr Gas" },
      { key: "wrong", text: "Kaffee reicht immer" }
    ]},
    { text: "Wie verhältst du dich bei Nässe?", options: [
      { key: "correct", text: "Sanfter fahren, mehr Abstand, früher bremsen" },
      { key: "wrong", text: "Schneller wegen Kühlung" },
      { key: "wrong", text: "Nur Hinterradbremse" }
    ]},
    { text: "Welche Fahrbahnmarkierungen sind rutschig?", options: [
      { key: "correct", text: "Farbliche Markierungen/Bitumen" },
      { key: "wrong", text: "Neue Asphaltdecken" },
      { key: "wrong", text: "Keine" }
    ]},
    { text: "Wie schützt du dich im Stadtverkehr?", options: [
      { key: "correct", text: "Vorausschauen, Abstand, Blickkontakt" },
      { key: "wrong", text: "Immer rechts vorbeidrücken" },
      { key: "wrong", text: "Zwischen LKW hindurch" }
    ]},
    { text: "Wann ist ein Schulterblick wichtig?", options: [
      { key: "correct", text: "Vor Spurwechsel/Abbiegen" },
      { key: "wrong", text: "Nie" },
      { key: "wrong", text: "Nur auf Autobahn" }
    ]},
    { text: "Wie verhältst du dich an Bahnübergängen?", options: [
      { key: "correct", text: "Abstand, nicht überholen, Schranken beachten" },
      { key: "wrong", text: "Zwischen Schranken durch" },
      { key: "wrong", text: "Nur hupen" }
    ]},
    { text: "Was tust du bei Aquaplaning?", options: [
      { key: "correct", text: "Gas weg, ruhig halten, nicht ruckartig" },
      { key: "wrong", text: "Voll bremsen" },
      { key: "wrong", text: "Noch mehr Gas" }
    ]},
    { text: "Wie transportierst du Gepäck sicher?", options: [
      { key: "correct", text: "Gleichmäßig verteilen, fest verzurren" },
      { key: "wrong", text: "Lose oben drauf" },
      { key: "wrong", text: "Nur am Lenker" }
    ]},
    { text: "Warum ist Blickführung wichtig?", options: [
      { key: "correct", text: "Wohin du schaust, dorthin lenkst du" },
      { key: "wrong", text: "Nur Optik" },
      { key: "wrong", text: "Unwichtig" }
    ]},
    { text: "Was ist beim Überholen von Kolonnen wichtig?", options: [
      { key: "correct", text: "Übersicht, Abstand, nicht zwischen LKW pressen" },
      { key: "wrong", text: "Egal, Hauptsache schnell" },
      { key: "wrong", text: "Immer rechts überholen" }
    ]},
    { text: "Welche Kleidung bei Hitze?", options: [
      { key: "correct", text: "Schutzkleidung bleiben, belüftet" },
      { key: "wrong", text: "T-Shirt/Shorts reichen" },
      { key: "wrong", text: "Flip-Flops ok" }
    ]},
    { text: "Wie verhältst du dich bei Wildwechsel?", options: [
      { key: "correct", text: "Geschwindigkeit reduzieren, bremsbereit" },
      { key: "wrong", text: "Mehr Gas" },
      { key: "wrong", text: "Ausweichen in Gegenverkehr" }
    ]},
    { text: "Welcher Reifendruck ist richtig?", options: [
      { key: "correct", text: "Herstellerangaben beachten (beladungsabhängig)" },
      { key: "wrong", text: "Immer maximal" },
      { key: "wrong", text: "Unwichtig" }
    ]},
    { text: "Wie fährst du über Straßenbahnschienen?", options: [
      { key: "correct", text: "Möglichst rechtwinklig, nicht in Schräglage" },
      { key: "wrong", text: "Flach drüber in Schräglage" },
      { key: "wrong", text: "Mit Vollgas drüber" }
    ]},
    { text: "Warum Abstand nach vorn wichtig?", options: [
      { key: "correct", text: "Reaktionszeit und Sicherheit" },
      { key: "wrong", text: "Zum Drängeln" },
      { key: "wrong", text: "Unwichtig" }
    ]},
    { text: "Wann darfst du Busspuren benutzen?", options: [
      { key: "correct", text: "Nur wenn freigegeben (Beschilderung)" },
      { key: "wrong", text: "Immer" },
      { key: "wrong", text: "Nie, auch wenn freigegeben" }
    ]},
    { text: "Wie verhältst du dich bei Seitenwind?", options: [
      { key: "correct", text: "Lenkkorrekturen, Geschwindigkeit anpassen" },
      { key: "wrong", text: "Vollgas" },
      { key: "wrong", text: "Lenker loslassen" }
    ]},
    { text: "Wie parkst du sicher?", options: [
      { key: "correct", text: "Ständer stabil, fester Untergrund" },
      { key: "wrong", text: "Auf weichem Sand" },
      { key: "wrong", text: "Auf Hang ohne Gang" }
    ]},
    { text: "Wann ist Fahren zwischen Kolonnen erlaubt?", options: [
      { key: "correct", text: "Nur wenn es erlaubt und sicher ist" },
      { key: "wrong", text: "Immer" },
      { key: "wrong", text: "Nie, auch wenn erlaubt" }
    ]},
    { text: "Wie fährst du mit Sozius sicher?", options: [
      { key: "correct", text: "Angepasst fahren, längerer Bremsweg" },
      { key: "wrong", text: "Wie allein, egal" },
      { key: "wrong", text: "Mit Wheelies" }
    ]},
    { text: "Was bedeutet ABS am Motorrad?", options: [
      { key: "correct", text: "Blockierverhinderung beim Bremsen" },
      { key: "wrong", text: "Mehr Leistung" },
      { key: "wrong", text: "Automatische Spurwahl" }
    ]}
  ];
})();