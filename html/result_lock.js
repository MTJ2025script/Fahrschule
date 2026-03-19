// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

/* result_lock.js — stronger hide: inject CSS hide-rule, full innerHTML teardown, ack to client
   - Injects an aggressive CSS rule (#mtj-hide-all) to force-hide the entire UI and children (display:none !important).
   - Empties innerHTML to avoid "empty header" shells.
   - Sets window.__MTJ_UI_HIDDEN and sends resultForceClosedAck to client.
   - On open messages, respects suppression and refuses to reopen while hidden.
*/
(function(){
  'use strict';
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mtj_fahrschule';
  const $ = s => document.querySelector(s);

  let RESULT_OPEN = false;
  let lastForceClosedAt = 0;
  const FORCE_CLOSE_GRACE_MS = 1200; // short grace window after force close
  let hideStyleEl = null;

  function dbg(...args){ try { console.log(`[${RES}][NUI]`, ...args); } catch(e){} }

  function post(name, data){
    try {
      fetch(`https://${RES}/${name}`, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(data||{}) })
        .catch(()=>{});
    } catch(e){}
  }

  function injectHideStyle(){
    try {
      if (hideStyleEl) return;
      hideStyleEl = document.createElement('style');
      hideStyleEl.id = 'mtj-hide-all';
      hideStyleEl.type = 'text/css';
      // forcefully hide the UI wrapper and everything under it
      hideStyleEl.textContent = `
        /* aggressive hide to defeat inline !important styles or JS re-show attempts */
        #app, #app * {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          pointer-events: none !important;
        }
        body.ui-open { /* also remove ui-open visual if any */
          overflow: auto !important;
        }
      `;
      document.head && document.head.appendChild(hideStyleEl);
      dbg('injectHideStyle: injected');
    } catch(e){ dbg('injectHideStyle failed', e); }
  }

  function removeHideStyle(){
    try {
      if (!hideStyleEl) return;
      hideStyleEl.remove();
      hideStyleEl = null;
      dbg('removeHideStyle: removed');
    } catch(e){ dbg('removeHideStyle failed', e); }
  }

  function fullyHideUI(){
    try {
      dbg('fullyHideUI: start');
      const app = document.getElementById('app');
      // inject hide style first to prevent flash / immediate re-show
      injectHideStyle();

      // remove ui-open class and any overlay class
      try { document.body.classList.remove('ui-open'); } catch(e){}
      if (app){
        try {
          // clear classes/attributes
          app.classList.remove('visible','open');
          app.classList.add('hidden');
          app.setAttribute('aria-hidden','true');
          // remove any inline styles that could force visible state
          app.style.removeProperty('display');
          app.style.removeProperty('visibility');
          app.style.removeProperty('opacity');
          // ensure hidden via style as well
          app.style.display = 'none';
          app.style.visibility = 'hidden';
          app.style.opacity = '0';
          // remove content to avoid empty header shell showing up
          try { app.innerHTML = ''; } catch(e){}
        } catch(e){ dbg('app teardown error', e); }
      }

      // also try hiding common extra DOM nodes if present
      ['toast','banner','logo-wrap','panel-logo','logo','logo2','menu','theory','result'].forEach(id=>{
        try {
          const el = document.getElementById(id);
          if (!el) return;
          el.classList.remove('visible','open');
          el.classList.add('hidden');
          el.setAttribute('aria-hidden','true');
          el.style.removeProperty('display'); el.style.removeProperty('visibility'); el.style.removeProperty('opacity');
          el.style.display = 'none'; el.style.visibility = 'hidden'; el.style.opacity = '0';
          try { el.innerHTML = ''; } catch(e){}
        } catch(e){}
      });

      // mark state
      RESULT_OPEN = false;
      lastForceClosedAt = Date.now();
      // expose flag for other scripts in NUI if needed
      window.__MTJ_UI_HIDDEN = true;

      // ack to client so client can suppress reopen attempts
      post('resultForceClosedAck', { reason: 'fullyHideUI', ts: lastForceClosedAt });

      dbg('fullyHideUI: done, ack sent, lastForceClosedAt=' + lastForceClosedAt);
    } catch(err){
      dbg('fullyHideUI error', err);
    }
  }

  function tryOpenUIIfAllowed(){
    // If we are currently hidden forcibly, ignore open attempts that come too early
    const now = Date.now();
    if (now - lastForceClosedAt < FORCE_CLOSE_GRACE_MS) {
      dbg('tryOpenUIIfAllowed: suppressed due to recent force-close');
      return false;
    }
    // If hide-style exists, remove it and allow restoration
    if (hideStyleEl) removeHideStyle();
    window.__MTJ_UI_HIDDEN = false;
    return true;
  }

  window.addEventListener('message', function(ev){
    const d = ev && ev.data || {};
    if (!d) return;
    dbg('recv action=' + d.action, d);

    if (d.action === 'forceClose' || d.action === 'resultForceClose'){
      dbg('received forceClose -> fullyHideUI');
      fullyHideUI();
      return;
    }

    if (d.action === 'resultClosed'){
      // normal close: hide but keep DOM available for next open
      dbg('resultClosed -> performing graceful hide');
      try {
        const app = document.getElementById('app');
        if (app){
          app.classList.add('hidden');
          app.setAttribute('aria-hidden','true');
          app.style.display = 'none';
          app.style.opacity = '0';
        }
      } catch(e){}
      RESULT_OPEN = false;
      return;
    }

    if (d.action === 'close'){
      // normal close -> if we are in the forced-hidden state ignore or do graceful hide
      if (window.__MTJ_UI_HIDDEN) {
        dbg('close received but UI forcibly hidden -> ignore');
        return;
      }
      dbg('close received -> graceful hide');
      try {
        const app = document.getElementById('app');
        if (app){
          app.classList.add('hidden'); app.setAttribute('aria-hidden','true'); app.style.display='none'; app.style.opacity='0';
        }
      } catch(e){}
      RESULT_OPEN = false;
      return;
    }

    // Open actions: openMenu / openTheory / result / practiceEnd / etc.
    if (d.action === 'openMenu' || d.action === 'openTheory' || d.action === 'result' || d.action === 'practiceEnd' || d.action === 'theoryEnd' || d.action === 'theoryOutcome') {
      // if we were forced-hidden and still within grace window, ignore open (client should be suppressing too)
      const now = Date.now();
      if (now - lastForceClosedAt < FORCE_CLOSE_GRACE_MS) {
        dbg('open ignored due to recent forceclose', d.action);
        return;
      }
      // If we previously fully removed DOM content, try to rebuild (reload) to restore expected UI (safe fallback)
      const app = document.getElementById('app');
      if (!app) {
        dbg('app missing on open -> attempting location.reload to rebuild UI');
        try { location.reload(); } catch(e){}
        return;
      }
      // ensure hide style removed (if present)
      if (hideStyleEl) removeHideStyle();
      window.__MTJ_UI_HIDDEN = false;
      // show wrapper and section
      try {
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden','false');
        document.body.classList.add('ui-open');
      } catch(e){}
      RESULT_OPEN = true;
      // If it's a result/praxis end, render will be handled by existing app code (app.onMessage etc.)
      // Let fallback handlers deal with data
      return;
    }

    // fallback pass-through to app's message handler
    try { if (window.app && typeof window.app.onMessage === 'function') { window.app.onMessage(d); } } catch(e){ dbg('app.onMessage error', e); }
  });

  // ESC immediate hide (NUI side) — also send resultClose to client if possible
  window.addEventListener('keydown', function(e){
    if ((e.key === 'Escape' || e.keyCode === 27) && RESULT_OPEN) {
      dbg('ESC pressed: fullyHideUI and post resultClose');
      try { post('resultClose', {}); } catch(e){}
      fullyHideUI();
    }
  }, true);

  // expose debug helpers
  window.MTJ_RESULT_LOCK = {
    fullyHideUI: fullyHideUI,
    tryOpenUIIfAllowed: tryOpenUIIfAllowed,
    isHidden: () => !!window.__MTJ_UI_HIDDEN,
    getState: () => ({ RESULT_OPEN, lastForceClosedAt, hideStyleInjected: !!hideStyleEl })
  };

  dbg(`[${RES}][NUI] result_lock.js loaded (strong-hide)`);
})();