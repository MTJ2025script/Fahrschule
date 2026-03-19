// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

// debug_nui.js — robuster NUI-Handler für forceClose / resultForceClose
// Fügt ein Fail‑Safe hinzu: versteckt das Haupt-UI sofort und schickt ein Ack an den Client.

(function(){
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mtj_fahrschule';
  function log() {
    try { console.log.apply(console, arguments); } catch(e) {}
  }

  function ack(name, data) {
    try {
      fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .catch(()=>{ /* ignore */ });
    } catch(e){}
  }

  window.addEventListener('message', function(ev){
    try {
      const d = ev.data || {};
      log(`[${RES}][NUI/debug] recv`, d);

      // Fail-safe: wenn UI soll geschlossen werden, verstecke alles sofort
      if (d.action === 'forceClose' || d.action === 'resultForceClose' || d.action === 'result') {
        // Ziel-Elemente (sicher ausprobieren: unterschiedliche UIs benutzen #app / #root / .app)
        const rootIds = ['app', 'root', 'ui', 'main'];
        let el = null;
        for (let id of rootIds) {
          el = document.getElementById(id);
          if (el) break;
        }
        // Wenn kein root gefunden, apply to body
        const target = el || document.body;
        try {
          target.style.setProperty('display', 'none', 'important');
          target.style.setProperty('visibility', 'hidden', 'important');
          target.style.setProperty('opacity', '0', 'important');
          target.style.setProperty('pointer-events', 'none', 'important');
        } catch(e){}

        // Entferne Klassen, die UI offen halten könnten
        try { document.documentElement.classList.remove('ui-open'); } catch(e){}
        try { document.body.classList.remove('ui-open'); } catch(e){}

        // Sende Ack an Client (RegisterNUICallback 'resultForceClosedAck' erwartet)
        ack('resultForceClosedAck', { reason: d.reason || 'nui-hotfix' });
        log(`[${RES}][NUI/debug] forceClose handled, ack sent`);
        return;
      }

      // Optional: log opens so we can see what's arriving
      if (d.action && (d.action === 'openMenu' || d.action === 'openTheory' || d.action === 'openPractice')) {
        log(`[${RES}][NUI/debug] open action received:`, d.action, d);
      }
    } catch(e) {
      try { console.error(`[${RES}][NUI/debug] handler error`, e); } catch(_) {}
    }
  });

  log(`[${RES}][NUI/debug] loaded`);
})();