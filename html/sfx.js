/*
========================================================================================================================
  MTJ2024 Scripts – html/sfx.js (enhanced WebAudio UI sounds, no external files)
========================================================================================================================
  Projekt     : MTJ2024 Scripts – Fahr-/Theorie-/Praxis-Systeme (ESX/QBCore kompatibel)
  Datei       : html/sfx.js
  Version     : v1.0.3
  Build       : 2025-10-12
  Autor       : MTJ2024
  Support     : Discord: <DEIN_DISCORD> • Mail: <DEIN_EMAIL>
  Lizenz      : Proprietär / Interne Nutzung
  Copyright : (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.
  Hinweise    : - Verbesserte SFX-Engine: mehrere Voices, filter + envelope, chainable sequences
                - Konfigurierbar über window.MTJ_SFX (volume, enabled)
                - Lauscht auf window.postMessage Aktionen sowie custom 'sfx_*' messages
                - Kein externes Audiofile nötig (alles generiert)
========================================================================================================================
*/
(function () {
  'use strict';

  // Public runtime config
  window.MTJ_SFX = window.MTJ_SFX || {
    enabled: true,
    volume: 0.12 // master volume (0..1)
  };

  const ctx = (window.AudioContext || window.webkitAudioContext) ? new (window.AudioContext || window.webkitAudioContext)() : null;
  if (!ctx) {
    console.warn('[MTJ-Fahrschule][SFX] AudioContext not available');
    return;
  }

  // Ensure context resumes on first user gesture
  function resumeCtx() {
    if (ctx.state === 'suspended' && typeof ctx.resume === 'function') {
      ctx.resume().catch(() => {/* noop */});
    }
  }
  document.addEventListener('click', resumeCtx, { once: true, passive: true });
  document.addEventListener('keydown', resumeCtx, { once: true, passive: true });

  // Master gain
  const master = ctx.createGain();
  master.gain.value = Math.max(0, Math.min(1, window.MTJ_SFX.volume || 0.12));
  master.connect(ctx.destination);

  // Helper: play a single oscillator tone with envelope + optional filter & detune
  function playTone({ freq = 440, dur = 0.12, gain = 0.12, type = 'sine', detune = 0, attack = 0.006, release = 0.06, filter = null, pan = 0 } = {}) {
    if (!window.MTJ_SFX.enabled || !ctx) return;
    try {
      const now = ctx.currentTime;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, now);
      g.gain.exponentialRampToValueAtTime(Math.max(0.0001, gain), now + attack);
      g.gain.exponentialRampToValueAtTime(0.0001, now + dur + release);

      // Oscillator
      const o = ctx.createOscillator();
      o.type = type;
      o.frequency.value = freq;
      if (o.detune) o.detune.value = detune;

      // Optional filter
      let outNode = o;
      if (filter && filter.type) {
        const f = ctx.createBiquadFilter();
        f.type = filter.type;
        f.frequency.value = filter.freq || 1200;
        f.Q.value = filter.q || 1;
        outNode.connect = outNode.connect || function () { };
        o.connect(f);
        outNode = f;
      }

      // Panner (optional)
      let finalNode = g;
      if (Math.abs(pan) > 0.001 && ctx.createStereoPanner) {
        const panNode = ctx.createStereoPanner();
        panNode.pan.value = Math.max(-1, Math.min(1, pan));
        finalNode = panNode;
        panNode.connect(master);
        g.connect(panNode);
      } else {
        g.connect(master);
      }

      o.connect(g);
      o.start(now);
      o.stop(now + dur + release + 0.02);
    } catch (e) {
      // fail silently - WebAudio can throw on some embedded contexts
      console.warn('[MTJ-Fahrschule][SFX] playTone error', e);
    }
  }

  // Helper: sequence of tones (array of {freq,dur,...})
  function playSequence(seq = [], tempo = 1.0) {
    if (!Array.isArray(seq) || seq.length === 0) return;
    let t = 0;
    seq.forEach(item => {
      setTimeout(() => playTone(item), Math.max(0, Math.floor(t * 1000 * tempo)));
      t += (item.dur || 0.08);
    });
  }

  // Prebuilt melodies / FX
  function openPulse() {
    playTone({ freq: 380, dur: 0.09, gain: 0.12, type: 'triangle', attack: 0.005, release: 0.05 });
    setTimeout(() => playTone({ freq: 560, dur: 0.06, gain: 0.08, type: 'triangle' }), 90);
  }

  function successMelody() {
    // simple arpeggio + shimmer
    playTone({ freq: 880, dur: 0.07, gain: 0.12, type: 'sine', detune: -5 });
    setTimeout(() => playTone({ freq: 1320, dur: 0.06, gain: 0.09, type: 'sine', detune: 6 }), 80);
    setTimeout(() => playTone({ freq: 1100, dur: 0.10, gain: 0.06, type: 'sine' }), 160);

    // gentle low sub for weight
    setTimeout(() => playTone({ freq: 140, dur: 0.26, gain: 0.04, type: 'sine', attack: 0.02, release: 0.2 }), 0);
  }

  function failMelody() {
    playTone({ freq: 220, dur: 0.12, gain: 0.12, type: 'sawtooth' });
    setTimeout(() => playTone({ freq: 150, dur: 0.18, gain: 0.06, type: 'sawtooth' }), 140);
  }

  function clickTick() {
    playTone({ freq: 1100, dur: 0.03, gain: 0.06, type: 'square' });
  }

  function licenseReveal() {
    // pleasant ascending sequence
    const seq = [
      { freq: 520, dur: 0.06, gain: 0.10, type: 'sine' },
      { freq: 640, dur: 0.06, gain: 0.10, type: 'sine' },
      { freq: 780, dur: 0.08, gain: 0.12, type: 'sine' },
      { freq: 1040, dur: 0.12, gain: 0.14, type: 'sine' }
    ];
    playSequence(seq, 1.0);
  }

  // Expose a simple API
  window.MTJ_SFX.play = function (name) {
    if (!window.MTJ_SFX.enabled) return;
    switch ((name || '').toString()) {
      case 'open':
        openPulse(); break;
      case 'success':
        successMelody(); break;
      case 'fail':
        failMelody(); break;
      case 'click':
        clickTick(); break;
      case 'license':
        licenseReveal(); break;
      default:
        // try play tone if name is an object with freq
        if (typeof name === 'object' && name.freq) playTone(name);
    }
  };

  // Message listener: standard actions + custom sfx_* signals
  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    try {
      // prefer explicit sfx_* messages
      if (d.action && typeof d.action === 'string') {
        const a = d.action;
        if (a === 'sfx_success') return successMelody();
        if (a === 'sfx_fail') return failMelody();
        if (a === 'sfx_open') return openPulse();
        if (a === 'sfx_click') return clickTick();
        if (a === 'sfx_license') return licenseReveal();
      }

      // legacy handling for the NUI events:
      if (d.action === 'openMenu' || d.action === 'openTheory') {
        if (ctx.state === 'suspended' && typeof ctx.resume === 'function') ctx.resume();
        openPulse();
      } else if (d.action === 'practiceEnd') {
        if (d.passed === true) successMelody();
        else if (d.passed === false) failMelody();
      } else if (d.action === 'notify') {
        // allow notify.type === 'success' or payload.sfx
        if (d.type === 'success') successMelody();
        else if (d.type === 'error') failMelody();
        else if (d.sfx === 'license') licenseReveal();
      }
    } catch (err) {
      // swallow errors in production
      console.warn('[MTJ-Fahrschule][SFX] message handler error', err);
    }
  });

  // allow runtime volume changes
  Object.defineProperty(window.MTJ_SFX, 'volume', {
    get() { return master.gain.value; },
    set(v) { master.gain.value = Math.max(0, Math.min(1, Number(v) || 0)); }
  });

  Object.defineProperty(window.MTJ_SFX, 'enabled', {
    get() { return !!window._mtj_sfx_enabled_internal; },
    set(v) { window._mtj_sfx_enabled_internal = !!v; }
  });
  // initialize internal enabled flag
  window._mtj_sfx_enabled_internal = !!window.MTJ_SFX.enabled;

  // small helper log
  console.log('[MTJ-Fahrschule][SFX] initialized (volume=' + master.gain.value + ', enabled=' + window._mtj_sfx_enabled_internal + ')');

})();