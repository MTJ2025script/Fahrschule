// Copyright (c) 2024-2026 MTJ2024 – Alle Rechte vorbehalten / All rights reserved.

'use strict';

/* Copyright (c) 2024-2026 MTJ2024 – All rights reserved. */
console.log('%c mtj_fahrschule %c © 2024-2026 MTJ2024 ', 'background:#00d0ff;color:#001216;font-weight:900;padding:2px 6px;border-radius:3px 0 0 3px', 'background:#121826;color:#00d0ff;font-weight:700;padding:2px 6px;border-radius:0 3px 3px 0');

/* ========= DOM refs ========= */
const app = document.getElementById('app');
const menu = document.getElementById('menu');
const theory = document.getElementById('theory');
const result = document.getElementById('result');
const toast = document.getElementById('toast');
const banner = document.getElementById('banner');

let logo = document.getElementById('logo');
let logo2 = document.getElementById('logo2');
let panelLogo = document.getElementById('panel-logo');

const modeTheoryBtn = document.getElementById('mode-theory');
const modePracticeBtn = document.getElementById('mode-practice');
const bookBtn = document.getElementById('book-btn');
const closeMenuBtn = document.getElementById('close-menu');

const theoryTitle = document.getElementById('theory-title');
const categoryName = document.getElementById('category-name');
const cancelTheoryBtn = document.getElementById('cancel-theory');
const submitTheoryBtn = document.getElementById('submit-theory');
const closeResultBtn = document.getElementById('close-result');

/* ========= State / Config ========= */
const DEFAULT_QUESTIONS_PER_TEST = 25;
const DEFAULT_PASS_PCT = 80;
const DEFAULT_TIMER_SECONDS = 1200;

let labels = {};
let prices = {};
let selectedCat = null;
let selectedMode = 'theory';

let rawPool = [];
let questions = [];
let answers = {};
let currentIndex = 0;

let passPct = DEFAULT_PASS_PCT;
let questionsPerTest = DEFAULT_QUESTIONS_PER_TEST;
let timeLeft = 0;
let timerInterval = null;

let toastTimeout = null;
let bannerTimeout = null;
let isBooking = false;

let lastUiConfig = null;
let currentSection = null; // 'menu' | 'theory' | 'result'
let lastShownTheoryTs = 0;

/* ========= Branding ========= */
const CFG = (window.MTJ_CONFIG = window.MTJ_CONFIG || {});
const UI_DEFAULT_NAME = CFG.UI_SCHRIFTZUG || CFG.UI_NAME || 'Fahrschule';
const UI_DEFAULT_SLOGAN = CFG.UI_SLOGAN || '';
const LOGO_SRC_DEFAULT = CFG.LOGO_PATH || CFG.UILogo || 'img/logo.png';
const BOOKING_TITLE = CFG.BOOKING_TITLE || 'Fahrschule-Buchen';

let CURRENT_BRAND = { name: UI_DEFAULT_NAME, slogan: UI_DEFAULT_SLOGAN };

/* ========= Utils ========= */
function escapeHtml(s){ if (s == null) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
function shuffle(a){ for (let i=a.length-1;i>0;i--){ const j=Math.floor(Math.random()*(i+1)); [a[i],a[j]]=[a[j],a[i]]; } return a; }
function randPick(arr, n){ const src=arr.slice(); shuffle(src); return src.slice(0, Math.max(0, Math.min(n, src.length))); }

/* Robust: Data-URL/Blob/Path prüfen und ggf. normalisieren */
function isSafeImgSrc(src){
  if (!src || typeof src !== 'string') return false;
  if (src.indexOf('data:image/') === 0) return true;
  if (src.indexOf('blob:') === 0) return true;
  if (src.indexOf('https://') === 0 || src.indexOf('http://') === 0 || src.indexOf('/') === 0) return true;
  if (/^[a-z0-9_\-./]+$/i.test(src)) return true;
  return false;
}
function normalizeDataUrl(maybeBase64){
  if (typeof maybeBase64 !== 'string' || maybeBase64.length < 16) return null;
  if (maybeBase64.indexOf('data:image/') === 0) return maybeBase64;
  if (/^[A-Za-z0-9+/=]+$/.test(maybeBase64) && maybeBase64.length > 128) {
    return 'data:image/jpeg;base64,' + maybeBase64;
  }
  return null;
}

function safeToast(msg, dur=3500){
  try{
    if (!toast) return;
    toast.textContent = String(msg||'');
    toast.classList.remove('hidden');
    clearTimeout(toastTimeout);
    toastTimeout = setTimeout(()=> toast && toast.classList.add('hidden'), dur);
  }catch(e){}
}
function safeBanner(msg){
  try{
    if (!banner) return;
    if (msg && String(msg).trim()){
      banner.textContent = String(msg);
      banner.classList.remove('hidden');
    } else {
      banner.textContent = '';
      banner.classList.add('hidden');
    }
  }catch(e){}
}

/* ========= App/Section visibility ========= */
function showApp(){
  if (!app) return;
  app.classList.remove('hidden');
  app.setAttribute('aria-hidden','false');
  document.body.classList.add('ui-open');
}
function hideApp(){
  if (!app) return;
  app.classList.add('hidden');
  app.setAttribute('aria-hidden','true');
  document.body.classList.remove('ui-open');
}

/* STRICT: genau EIN Bereich sichtbar (Buchen ODER Theorie ODER Ergebnis) */
function setSection(id){
  const all = { menu, theory, result };
  Object.keys(all).forEach(function(key){
    const el = all[key];
    if (!el) return;
    const active = (key === id);
    el.classList.toggle('hidden', !active);
    el.setAttribute('aria-hidden', String(!active));
    try {
      el.style.display = active ? 'block' : 'none';
      el.style.visibility = active ? 'visible' : 'hidden';
      el.style.opacity = active ? '1' : '0';
      el.style.pointerEvents = active ? 'auto' : 'none';
    } catch(e){}
  });
  currentSection = id;
}

/* ========= LICENSE DOM ENSURE ========= */
function ensureLicenseDom(){
  let overlay = document.getElementById('license-overlay');
  if (overlay) return overlay;

  // Minimales Overlay erzeugen, falls im HTML nicht vorhanden
  overlay = document.createElement('div');
  overlay.id = 'license-overlay';
  overlay.setAttribute('aria-hidden','true');
  overlay.className = 'license-overlay';

  const wrap = document.createElement('div');
  wrap.className = 'license-wrap';

  // Close Button
  const closeBtn = document.createElement('button');
  closeBtn.id = 'license-close';
  closeBtn.className = 'license-close';
  closeBtn.type = 'button';
  closeBtn.textContent = '×';
  closeBtn.addEventListener('click', closeLicense);

  // Karte (minimal, IDs bereitstellen)
  const card = document.createElement('div');
  card.className = 'license-card compact';

  const header = document.createElement('div');
  header.className = 'license-header';
  header.innerHTML =
    '<img id="license-logo" alt="Logo" class="license-logo"/>' +
    '<div class="license-head-texts">' +
      '<div id="license-org" class="license-org"></div>' +
      '<div id="license-title" class="license-title"></div>' +
    '</div>' +
    '<span id="license-timer" class="license-timer"></span>';

  const grid = document.createElement('div');
  grid.className = 'license-grid';
  grid.innerHTML =
    '<div class="row photo-row">' +
      '<img id="license-photo" alt="Photo" class="license-photo"/>' +
    '</div>' +
    '<div id="license-category" class="license-category"></div>' +
    '<div id="license-idtext" class="license-idtext"></div>' +
    '<div id="license-watermark" class="license-watermark">ID Card</div>' +
    '<div id="license-signature" class="license-signature"></div>';

  // Optional-Felder (Labs/Values) – werden nur gesetzt, wenn vorhanden
  const details = document.createElement('div');
  details.className = 'license-details';
  details.innerHTML =
    '<div class="labval"><span id="lab-firstname" class="lab">Vorname</span>: <span id="val-firstname"></span></div>' +
    '<div class="labval"><span id="lab-lastname" class="lab">Nachname</span>: <span id="val-lastname"></span></div>' +
    '<div class="labval"><span id="lab-birthdate" class="lab">Geburtsdatum</span>: <span id="val-birthdate"></span></div>' +
    '<div class="labval"><span id="lab-height" class="lab">Größe</span>: <span id="val-height"></span></div>' +
    '<div class="labval"><span id="lab-issuedAt" class="lab">Ausgestellt</span>: <span id="val-issuedAt"></span></div>' +
    '<div class="labval"><span id="lab-expiresAt" class="lab">Gültig bis</span>: <span id="val-expiresAt"></span></div>';

  card.appendChild(header);
  card.appendChild(grid);
  card.appendChild(details);

  wrap.appendChild(closeBtn);
  wrap.appendChild(card);
  overlay.appendChild(wrap);
  document.body.appendChild(overlay);

  // Basales CSS-inject, falls Styles fehlen (nur Minimalwerte)
  try {
    if (!document.getElementById('mtj-license-inline-style')) {
      const st = document.createElement('style');
      st.id = 'mtj-license-inline-style';
      st.textContent =
        '.license-overlay{position:fixed;left:0;top:0;width:100%;height:100%;display:none;align-items:center;justify-content:center;background:rgba(0,0,0,.55);z-index:9999}' +
        '.license-overlay.show{display:flex}' +
        '.license-wrap{position:relative;max-width:720px;width:92%;padding:12px}' +
        '.license-close{position:absolute;right:8px;top:8px;font-size:22px;line-height:22px;background:#111;color:#fff;border:1px solid #333;border-radius:6px;width:34px;height:34px;cursor:pointer}' +
        '.license-card{background:#0b0f15;color:#fff;border:1px solid rgba(0,200,255,0.25);border-radius:12px;padding:12px;box-shadow:0 8px 32px rgba(0,0,0,.35)}' +
        '.license-header{display:flex;align-items:center;gap:12px;margin-bottom:8px}' +
        '.license-logo{height:40px;object-fit:contain}' +
        '.license-org{font-weight:600;opacity:.9}' +
        '.license-title{font-size:18px;font-weight:700}' +
        '.license-timer{margin-left:auto;opacity:.75}' +
        '.license-grid{display:flex;flex-direction:column;gap:6px}' +
        '.license-photo{width:160px;height:120px;object-fit:cover;border-radius:6px;border:1px solid rgba(255,255,255,.15);background:#000}' +
        '.license-category{font-weight:600;opacity:.9}' +
        '.license-idtext{opacity:.8}' +
        '.license-watermark{text-align:center;opacity:.08;user-select:none}' +
        '.license-signature{text-align:right;opacity:.8;margin-top:2px}' +
        '.license-details{margin-top:8px;display:grid;grid-template-columns:1fr 1fr;gap:4px 12px}' +
        '.lab{font-size:11px;text-transform:uppercase;letter-spacing:.06em;opacity:.7}';
      document.head.appendChild(st);
    }
  } catch(e){}

  return overlay;
}

/* ========= Logos ========= */
function ensureLogoFallback(){
  logo = document.getElementById('logo') || logo;
  logo2 = document.getElementById('logo2') || logo2;
  const wrap = document.getElementById('logo-wrap'); if (!wrap) return;
  let fallback = document.getElementById('logo-fallback');
  if (!fallback){
    fallback = document.createElement('div');
    fallback.id = 'logo-fallback'; fallback.className = 'logo-fallback';
    fallback.setAttribute('aria-hidden','true');
    fallback.style.display = 'none';
    fallback.style.alignItems = 'center';
    fallback.style.justifyContent = 'center';
    fallback.style.flexDirection = 'column';
    const text = escapeHtml(CURRENT_BRAND.name || 'Fahrschule');
    fallback.innerHTML = '<svg viewBox="0 0 240 60" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:100%;max-height:60px;"><rect width="100%" height="100%" rx="8" fill="#071018"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="Inter, Arial" font-size="18" fill="#00d0ff">'+text+'</text></svg>';
    wrap.appendChild(fallback);
  }
  if (logo){
    if (logo.complete && logo.naturalWidth > 0){
      try { fallback.setAttribute('aria-hidden','true'); fallback.style.display='none'; logo.style.display=''; } catch(e){}
    } else {
      logo.addEventListener('load', function(){ try { fallback.setAttribute('aria-hidden','true'); fallback.style.display='none'; logo.style.display=''; } catch(e){} }, { once:true });
      logo.addEventListener('error', function(){ try { fallback.setAttribute('aria-hidden','false'); fallback.style.display='flex'; logo.style.display='none'; } catch(e){} }, { once:true });
      setTimeout(function(){ try{ if (!logo.complete || logo.naturalWidth === 0){ fallback.setAttribute('aria-hidden','false'); fallback.style.display='flex'; if (logo) logo.style.display='none'; } }catch(e){} }, 700);
    }
  } else {
    try { fallback.setAttribute('aria-hidden','false'); fallback.style.display='flex'; } catch(e){}
  }
  window.MTJ_UI = window.MTJ_UI || {};
  window.MTJ_UI.showLogoFallback = function(){ try{ const f=document.getElementById('logo-fallback'); if (f){ f.setAttribute('aria-hidden','false'); f.style.display='flex'; } if (logo) logo.style.display='none'; } catch(e){} };
  window.MTJ_UI.hideLogoFallback = function(){ try{ const f=document.getElementById('logo-fallback'); if (f){ f.setAttribute('aria-hidden','true'); f.style.display='none'; } if (logo) logo.style.display=''; } catch(e){} };
}
ensureLogoFallback();

function setLogos(src1, src2){
  logo = document.getElementById('logo') || logo;
  logo2 = document.getElementById('logo2') || logo2;
  panelLogo = document.getElementById('panel-logo') || panelLogo;
  try {
    const useSrc = (typeof src1 === 'string' && src1.length) ? src1 : LOGO_SRC_DEFAULT;
    const alt = CURRENT_BRAND.name || 'Logo';
    if (logo){
      logo.onerror = function () { try{ window.MTJ_UI && window.MTJ_UI.showLogoFallback && window.MTJ_UI.showLogoFallback(); }catch(e){} };
      logo.onload  = function () { try{ window.MTJ_UI && window.MTJ_UI.hideLogoFallback && window.MTJ_UI.hideLogoFallback(); }catch(e){} };
      logo.src = useSrc; logo.alt = alt;
    }
    if (panelLogo){ panelLogo.src = useSrc; panelLogo.alt = alt; panelLogo.style.display = ''; }
    if (logo2){
      const useSrc2 = (typeof src2 === 'string' && src2.length) ? src2 : '';
      if (useSrc2){ logo2.src = useSrc2; logo2.style.display=''; } else { logo2.removeAttribute('src'); logo2.style.display='none'; }
      logo2.alt = alt;
    }
  } catch(e) {}
}

/* ========= LICENSE OVERLAY ========= */
let licUserPhotoSet = false;
let licLastPhoto = '';

function setLabelsFromMap(map){
  map = map || {};
  const t = document.getElementById('license-title'); if (t && map.Title) t.textContent = map.Title;
  const lf = document.getElementById('lab-firstname'); if (lf && map.Firstname) lf.textContent = map.Firstname;
  const ll = document.getElementById('lab-lastname'); if (ll && map.Lastname) ll.textContent = map.Lastname;
  const lb = document.getElementById('lab-birthdate'); if (lb && map.Birthdate) lb.textContent = map.Birthdate;
  const lh = document.getElementById('lab-height'); if (lh && map.Height) lh.textContent = map.Height;
  const lc = document.getElementById('lab-category'); if (lc && map.Category) lc.textContent = map.Category;
  const li = document.getElementById('lab-issuedAt'); if (li && map.IssuedAt) li.textContent = map.IssuedAt;
  const le = document.getElementById('lab-expiresAt'); if (le && map.ExpiresAt) le.textContent = map.ExpiresAt;
}
function setLicensePhoto(src){
  try{
    const normalized = normalizeDataUrl(src) || src;
    const img = document.getElementById('license-photo');
    if (!img) return;

    if (isSafeImgSrc(normalized)) {
      img.src = normalized;
      licLastPhoto = normalized;
      if (normalized.indexOf('data:image/') === 0 || normalized.indexOf('blob:') === 0 || /^[A-Za-z0-9+/=]{256,}$/.test(src)) {
        licUserPhotoSet = true;
      }
    }
  }catch(e){}
}
function applyLicenseStyle(S){
  try{
    S = S || {};
    const card = document.querySelector('.license-card');
    const labs = document.querySelectorAll('.license-grid .lab');
    const bg   = S.bg   || '#0b0f15';
    const text = S.text || '#ffffff';
    const brd  = S.border || 'rgba(0,200,255,0.25)';
    const uppercase = (S.uppercaseLabels !== false);

    if (card){ card.style.background = bg; card.style.color = text; card.style.borderColor = brd; }
    if (labs && labs.length){
      for (var i=0;i<labs.length;i++){
        labs[i].style.textTransform = uppercase ? 'uppercase' : 'none';
        labs[i].style.letterSpacing = uppercase ? '.06em' : '.03em';
      }
    }
    const wm = document.getElementById('license-watermark');
    if (wm){
      if ((S.theme||'').indexOf('american') !== -1){ wm.textContent = 'USA DRIVING LICENSE'; wm.style.opacity='.12'; }
      else { wm.textContent='ID Card'; wm.style.opacity='.08'; }
    }
  }catch(e){}
}

/* Accept both nested and flat payloads from server */
function readPersonFields(payload) {
  const P = (payload && payload.person) ? payload.person : payload || {};
  return {
    firstname: payload.firstname || P.firstname || '',
    lastname:  payload.lastname  || P.lastname  || '',
    birthdate: payload.birthdate || P.birthdate || '',
    height:    payload.height    || P.height    || ''
  };
}

function openLicense(L, autoCloseMs){
  ensureLicenseDom();
  L = L || {};
  const payload = L.license ? L.license : L;
  const labelsMap = payload.labels || {};

  // Reset User-Foto-Flag pro Öffnung
  licUserPhotoSet = false;
  licLastPhoto = '';

  // Logo, Titel, Org
  const logoEl = document.getElementById('license-logo');
  const orgEl = document.getElementById('license-org');
  const titleEl = document.getElementById('license-title');

  const logoSrc = normalizeDataUrl(payload.logo) || payload.logo || LOGO_SRC_DEFAULT;
  if (logoEl && isSafeImgSrc(logoSrc)) { logoEl.src = logoSrc; logoEl.alt = (CURRENT_BRAND.name || 'Logo'); }

  if (orgEl) orgEl.textContent = payload.orgName || payload.org || 'Fahrschule';
  if (titleEl) titleEl.textContent = (labelsMap.Title || 'Führerschein');

  setLabelsFromMap(labelsMap);

  const P = readPersonFields(payload);
  const setVal = function(id, value){ const el=document.getElementById(id); if (el) el.textContent = (value && String(value).length ? value : '—'); };
  setVal('val-firstname', P.firstname);
  setVal('val-lastname',  P.lastname);
  setVal('val-birthdate', P.birthdate);
  setVal('val-height',    P.height);
  setVal('val-category',  payload.categoryLabel || payload.category);
  setVal('val-issuedAt',  payload.issuedAt);
  setVal('val-expiresAt', payload.expiresAt);

  const catEl = document.getElementById('license-category');
  if (catEl){
    const catLab = (labelsMap.Category || 'Klasse');
    const catVal = (payload.categoryLabel || payload.category || '');
    catEl.textContent = (catLab + ': ' + catVal).trim();
  }

  // Foto: setze, wenn vorhanden – ansonsten auf Logo fallbacken
  (function(){
    const incoming = payload.photo || '';
    const normalized = normalizeDataUrl(incoming) || incoming;
    const fallback = logoSrc || LOGO_SRC_DEFAULT;
    const okPhoto = normalized && (
      normalized.indexOf('data:image/') === 0 ||
      normalized.indexOf('blob:') === 0 ||
      (/^[A-Za-z0-9+/=]{256,}$/.test(incoming)) ||
      (normalized.indexOf('http') === 0 && normalized.indexOf('logo') === -1)
    );
    if (okPhoto) {
      setLicensePhoto(normalized);
    } else {
      setLicensePhoto(fallback);
    }
  })();

  const sig = document.getElementById('license-signature');
  if (sig){
    const signedName = payload.signature || [P.firstname||'', P.lastname||''].filter(Boolean).join(' ');
    sig.textContent = signedName || '—';
  }

  const idText = document.getElementById('license-idtext');
  if (idText){
    const f=(P.firstname||'').trim().toUpperCase();
    const l=(P.lastname||'').trim().toUpperCase();
    const b=(P.birthdate||'').replace(/[^0-9]/g,'').slice(2,8);
    const dln=(f[0]||'X')+(l[0]||'X')+String(b).padEnd(6,'0');
    idText.textContent = 'DLN: ' + (dln || '—');
  }

  applyLicenseStyle(payload.style || { theme:'american_black', bg:'#0b0f15', text:'#ffffff', border:'rgba(0,200,255,0.25)', uppercaseLabels:true });

  const overlay = document.getElementById('license-overlay');
  const timerEl = document.getElementById('license-timer');
  if (overlay){
    overlay.classList.add('show');
    overlay.setAttribute('aria-hidden','false');
    const onBg = function(ev){ if (ev.target === overlay){ closeLicense(); } };
    overlay.addEventListener('click', onBg, { once:true });
  }

  const displayCfg = (payload.display || {});
  const fallbackMs = Number(displayCfg.AutoCloseSeconds ? (displayCfg.AutoCloseSeconds * 1000) : 0);
  const ms = Number(L.autoCloseMs || autoCloseMs || fallbackMs || 0);
  if (timerEl) timerEl.textContent = '';
  if (ms > 0){
    const end = Date.now() + ms;
    const iv = setInterval(function(){
      const left = Math.max(0, end - Date.now());
      if (timerEl) timerEl.textContent = Math.ceil(left/1000)+'s';
      if (left <= 0){ clearInterval(iv); closeLicense(); }
    }, 250);
  }
}
function closeLicense(){
  const overlay = document.getElementById('license-overlay');
  if (overlay){
    overlay.classList.remove('show');
    overlay.setAttribute('aria-hidden','true');
  }
  try{ fetch('https://'+GetParentResourceName()+'/licenseClose', { method:'POST', headers:{'Content-Type':'application/json'}, body: '{}' }).catch(()=>{}); }catch(e){}
}

/* ========= Ergebnis-Renderer ========= */
function setBadge(passed){
  const b = document.getElementById('result-badge');
  if (!b) return;
  if (b.classList){ b.classList.remove('success','fail'); b.classList.add(passed ? 'success' : 'fail'); }
  b.textContent = passed ? 'OK' : 'X';
}
function setTitles(passed){
  const rt = document.getElementById('result-title');
  const rh = document.getElementById('result-headline');
  const rs = document.getElementById('result-subtitle');
  if (rt) rt.textContent = 'Ergebnis';
  if (rh) rh.textContent = passed ? ((labels && labels.SuccessHeadline) || 'Praxis – Bestanden')
                                  : ((labels && labels.FailHeadline) || 'Praxis – Nicht bestanden');
  if (rs) rs.textContent = passed ? ((labels && labels.SuccessSub) || 'Gut gemacht! Du hast die Anforderungen erfüllt.')
                                  : ((labels && labels.FailSub) || 'Bitte versuche es erneut. Unten siehst du deine Fehler.');
  const el = document.getElementById('result-errors-title'); if (el) el.textContent = (labels && labels.errorListTitle) || 'Deine Fehler';
}
function renderStats(totalErrors, allowed, durationSec){
  const statsEl = document.getElementById('result-stats');
  if (!statsEl) return;
  const items = [
    { k: totalErrors, v: 'Fehler gesamt' },
    { k: (typeof allowed==='number'? allowed : '–'), v: 'Erlaubt' },
    { k: (typeof durationSec==='number'? (Math.max(0, Math.floor(durationSec))+' s') : '–'), v: 'Dauer' }
  ];
  statsEl.innerHTML = items.map(function(s){
    return '<div class="stat"><div class="k">'+s.k+'</div><div class="v">'+s.v+'</div></div>';
  }).join('');
}
function groupErrors(list){
  const map = {};
  (list||[]).forEach(function(msg){
    const k = String(msg||'');
    map[k] = (map[k]||0)+1;
  });
  return Object.keys(map).map(function(k){ return { msg:k, count:map[k] }; });
}
function renderErrors(list){
  const ul = document.getElementById('result-errors-list');
  if (!ul) return;
  const grp = groupErrors(Array.isArray(list)?list:[]);
  ul.innerHTML = grp.length
    ? grp.map(function(e){
        return '<li><span class="err-dot"></span><span class="err-msg">'+escapeHtml(e.msg)+'</span><span class="err-count">x'+e.count+'</span></li>';
      }).join('')
    : '<li><span class="err-msg">Keine Fehler aufgezeichnet.</span></li>';
}
function parseAllowedFromSummary(s){
  const m = String(s||'').match(/(\d+)\s*\/\s*(\d+)\s*$/);
  return m ? { total: parseInt(m[1],10), allowed: parseInt(m[2],10) } : null;
}
function openResult(payload){
  payload = payload || {};
  const passed = !!payload.passed;
  const errors = Array.isArray(payload.errors) ? payload.errors : [];
  const sum = String(payload.summary || '');
  setBadge(passed);
  setTitles(passed);

  let allowed = null, totalErrors = errors.length;
  const parsed = parseAllowedFromSummary(sum);
  if(parsed){ totalErrors = parsed.total; allowed = parsed.allowed; }

  const durationSec = payload.stats && typeof payload.stats.durationSec==='number' ? payload.stats.durationSec : null;

  renderStats(totalErrors, allowed, durationSec);
  renderErrors(errors);

  showApp();
  setSection('result');
}

/* ========= Fragen-Parsing & Theorie ========= */
const BUILTIN_FALLBACK_QUESTIONS = [
  { q: 'Was bedeutet dieses Verkehrsschild: „Vorfahrt gewähren“?', a: ['Anhalten und Vorfahrt achten', 'Immer fahren, egal wer kommt', 'Parken erlaubt'], c: 0 },
  { q: 'Wie verhalten Sie sich an einem Zebrastreifen?', a: ['Fußgängern Vorrang gewähren', 'Beschleunigen', 'Hupen'], c: 0 },
  { q: 'Was ist beim Abbiegen zu beachten?', a: ['Richtig blinken und Schulterblick', 'Nur hupen', 'Immer in der Mitte abbiegen'], c: 0 }
];
function qText(q){ try{ return String((q && (q.q || q.question || q.text || q.title)) || ''); }catch(e){ return ''; } }
function qOptions(q){ try{ let o = (q && (q.a || q.ans || q.answers || q.options)) || []; return Array.isArray(o) ? o.filter(function(x){return x!=null;}) : []; }catch(e){ return []; } }
function optText(opt){ try{ if (opt==null) return ''; if (['string','number','boolean'].includes(typeof opt)) return String(opt); return String(opt.text || opt.label || opt.title || opt.answer || opt.t || opt.value || ''); }catch(e){ return ''; } }
function correctIndicesFromQ(q, opts){
  try{
    const byFlag = [];
    for (let i=0;i<opts.length;i++){ const o=opts[i]; if (o && typeof o==='object' && (o.correct===true || o.isCorrect===true)) byFlag.push(i); }
    if (byFlag.length) return byFlag;
    const c = (q && (q.c || q.correct || q.correctIndex || q.correctAnswers || q.solution));
    if (typeof c==='number') return [c];
    if (typeof c==='string'){
      const s=c.trim(); if (/^[A-Za-z]$/.test(s)) return [s.toUpperCase().charCodeAt(0)-65];
      const idx=opts.findIndex(function(o){ return optText(o).trim()===s; }); if (idx>=0) return [idx];
    }
    if (Array.isArray(c)){
      const out=[]; c.forEach(function(v){
        if (typeof v==='number') out.push(v);
        else if (typeof v==='string'){
          const s=v.trim();
          if (/^[A-Za-z]$/.test(s)) out.push(s.toUpperCase().charCodeAt(0)-65);
          else { const idx=opts.findIndex(function(o){ return optText(o).trim()===s; }); if (idx>=0) out.push(idx); }
        }
      });
      if (out.length) return out;
    }
    return opts.length ? [0] : [];
  }catch(e){ return opts.length ? [0] : []; }
}
function buildChoicesForQuestion(q){
  try{
    let opts = qOptions(q);
    let texts = opts.map(optText);
    if (!texts.length){ texts=['Ja','Nein','Vielleicht']; opts=texts.map(function(t){return {text:t};}); }
    const corr = correctIndicesFromQ(q, opts);
    const cIndex = corr.length ? Math.max(0, Math.min(corr[0], texts.length-1)) : 0;

    const wrongIndices = []; for (let i=0;i<texts.length;i++){ if (i!==cIndex) wrongIndices.push(i); }
    const chosenWrongs = randPick(wrongIndices, 2); while (chosenWrongs.length<2) chosenWrongs.push(cIndex);

    const triple = [
      { text: texts[cIndex] || '—', correct: true },
      { text: texts[chosenWrongs[0]] || '—', correct: false },
      { text: texts[chosenWrongs[1]] || '—', correct: false }
    ];
    shuffle(triple);
    return triple;
  }catch(e){
    return [{text:'—',correct:true},{text:'—',correct:false},{text:'—',correct:false}];
  }
}

function ensureTheoryBasics(){
  if (!document.getElementById('question-box')){
    const qb = document.createElement('div'); qb.id='question-box'; qb.className='question-box';
    (theory || app || document.body).appendChild(qb);
  }
  if (!document.getElementById('timer')){
    const t = document.createElement('span'); t.id='timer';
    (theory || app || document.body).appendChild(t);
  }
  if (!document.getElementById('submit-theory')){
    const b = document.createElement('button'); b.id='submit-theory'; b.className='primary'; b.textContent='Abgeben';
    (theory || app || document.body).appendChild(b);
  }
}
function fetchPoolForCategory(cat){
  const POOL = window.MTJ_QUESTIONS || {};
  let pool = POOL[cat] || POOL[(cat && cat.toLowerCase())] || [];
  if (!pool || !pool.length) pool = POOL.fallback || POOL.default || [];
  return Array.isArray(pool) ? pool.slice() : [];
}
function sanitizePool(pool){
  if (!Array.isArray(pool)) return [];
  const out=[]; for (let i=0;i<pool.length;i++){ const q = pool[i]; if (!q || typeof q!=='object') continue; const t=qText(q); const has=qOptions(q).length>0; if (t || has) out.push(q); }
  return out;
}
function loadQuestions(cat, opts){
  opts = opts || {};
  ensureTheoryBasics();

  const raw = fetchPoolForCategory(cat);
  const cleaned = sanitizePool(raw);
  rawPool = cleaned.length ? cleaned : sanitizePool(BUILTIN_FALLBACK_QUESTIONS);

  if (!rawPool.length){
    safeBanner('Keine Fragen verfügbar.');
    const qb = document.getElementById('question-box');
    if (qb) qb.innerHTML = '<div class="q"><div class="qt">Keine Fragen gefunden. Bitte Admin informieren.</div></div>';
    const sb = document.getElementById('submit-theory'); if (sb) sb.classList.add('hidden');
    return false;
  }

  const count = Math.min(Number(opts.count || questionsPerTest || DEFAULT_QUESTIONS_PER_TEST), rawPool.length);
  const picked = rawPool.slice().sort(function(){return Math.random()-0.5;}).slice(0, count);

  questions = picked.map(function(q){ return { text: qText(q) || '—', choices: buildChoicesForQuestion(q) }; });
  answers = {};
  currentIndex = 0;
  renderCurrentQuestion();

  const btn = document.getElementById('submit-theory');
  if (btn){
    btn.classList.remove('hidden');
    btn.disabled = true;
    btn.textContent = questions.length > 1 ? 'Weiter' : 'Abgeben';
    btn.onclick = onSubmitOrNext;
  }
  return true;
}
function renderCurrentQuestion(){
  const qb = document.getElementById('question-box');
  if (!qb) return;
  const q = questions[currentIndex];
  if (!q){
    qb.innerHTML = '<div class="q"><div class="qt">Keine Frage geladen.</div></div>';
    if (submitTheoryBtn) submitTheoryBtn.disabled = true;
    return;
  }
  qb.innerHTML = '';
  const wrap = document.createElement('div'); wrap.className='q';
  const title = document.createElement('div'); title.className='qt'; title.textContent = (currentIndex+1)+'. '+(q.text || '—');
  const optWrap = document.createElement('div'); optWrap.className='opts';
  const selected = (typeof answers[currentIndex] === 'number') ? answers[currentIndex] : -1;

  q.choices.forEach(function(ch, idx){
    const btn = document.createElement('div');
    btn.className = 'opt';
    btn.setAttribute('role','button');
    btn.setAttribute('aria-pressed', selected === idx ? 'true' : 'false');
    btn.textContent = ch.text || '';
    if (selected === idx) btn.classList.add('sel');

    btn.addEventListener('click', function(){
      Array.prototype.forEach.call(optWrap.children, function(x){ x.classList.remove('sel'); x.setAttribute('aria-pressed','false'); });
      btn.classList.add('sel'); btn.setAttribute('aria-pressed','true');
      answers[currentIndex] = idx;
      const s = document.getElementById('submit-theory'); if (s) s.disabled = false;
    });
    optWrap.appendChild(btn);
  });

  wrap.appendChild(title);
  wrap.appendChild(optWrap);
  qb.appendChild(wrap);

  const s = document.getElementById('submit-theory');
  if (s){
    const last = currentIndex === (questions.length - 1);
    s.textContent = last ? 'Abgeben' : 'Weiter';
    s.disabled = !(typeof answers[currentIndex] === 'number');
  }
}
function onSubmitOrNext(){
  const last = currentIndex === (questions.length - 1);
  if (!last){ currentIndex++; renderCurrentQuestion(); return; }
  submitTheory(false);
}

/* ========= Timer / Scoring ========= */
function startTimer(totalSeconds){
  if (timerInterval){ clearInterval(timerInterval); timerInterval = null; }
  timeLeft = Math.max(0, Number(totalSeconds || 0));
  const tEl = document.getElementById('timer');
  const fmt = function(s){ const m=Math.floor(s/60), ss=s%60; return (String(m).padStart(2,'0')+':'+String(ss).padStart(2,'0')); };
  if (tEl) tEl.textContent = fmt(timeLeft);
  if (timeLeft <= 0) return;
  timerInterval = setInterval(function(){
    timeLeft = Math.max(0, timeLeft - 1);
    if (tEl) tEl.textContent = fmt(timeLeft);
    if (timeLeft <= 0){
      clearInterval(timerInterval); timerInterval = null;
      safeToast('Zeit abgelaufen!', 3000);
      submitTheory(true);
    }
  }, 1000);
}
function computeScore(){
  let correct = 0;
  questions.forEach(function(q, qi){
    const sel = answers[qi];
    if (typeof sel === 'number' && q.choices[sel] && q.choices[sel].correct === true) correct++;
  });
  const total = questions.length || 0;
  const pct   = total ? Math.round((correct/total)*100) : 0;
  const passed = pct >= (passPct || DEFAULT_PASS_PCT);
  return { correct, total, pct, passed };
}
async function submitTheory(auto){
  if (auto !== true) auto = false;
  const btn = document.getElementById('submit-theory');
  if (btn) btn.disabled = true;
  safeBanner(auto ? 'Zeit abgelaufen – wird ausgewertet …' : 'Wird ausgewertet …');

  const res = computeScore();
  try {
    await new Promise(function(resolve){
      let done=false; const t=setTimeout(function(){ if(!done){ done=true; resolve(); } }, 6000);
      post('theory_submit', {
        category: selectedCat,
        result: { correct: res.correct, total: res.total, percentage: res.pct, passed: res.passed }
      }, function(){ if(!done){ done=true; clearTimeout(t); resolve(); } });
    });
  } catch(e){}
  safeBanner('');
  if (btn) btn.disabled = false;
}

/* ========= Preise / Modus ========= */
function setModeButtons(){
  if (!modeTheoryBtn || !modePracticeBtn) return;
  const tOn = selectedMode === 'theory';
  modeTheoryBtn.classList.toggle('active', tOn);
  modeTheoryBtn.setAttribute('aria-selected', String(tOn));
  modePracticeBtn.classList.toggle('active', !tOn);
  modePracticeBtn.setAttribute('aria-selected', String(!tOn));
}
function setPrices(){
  try {
    const priceKey = selectedMode === 'theory' ? 'theorie' : 'praxis';
    const labelFor = selectedMode === 'theory' ? 'Theorie' : 'Praxis';
    document.querySelectorAll('.card').forEach(function(btn){
      const cat = btn.dataset.cat;
      const p = prices && prices[cat] && prices[cat][priceKey];
      const slot = btn.querySelector('.price');
      if (slot) slot.textContent = (typeof p === 'number') ? (labelFor+': $'+p.toLocaleString()) : (labelFor+': —');
    });
  } catch(e){}
}
function updateBookButton(){
  if (!bookBtn) return;
  bookBtn.disabled = !selectedCat || isBooking;
}

/* ========= UI Live-Update ========= */
function updateCategoryTitles(categoryMap){
  try{
    if (!categoryMap) return;
    document.querySelectorAll('.card[data-cat]').forEach(function(card){
      const cat = card.dataset.cat;
      const label = categoryMap[cat];
      if (!label) return;
      const nodes = Array.prototype.filter.call(card.childNodes, function(n){ return n.nodeType === Node.TEXT_NODE; });
      if (nodes.length) nodes[0].nodeValue = String(label);
    });
  }catch(e){}
}
function refreshVisibleTitles(){
  try {
    const mt = document.getElementById('menu-title');
    if (mt) {
      const ui = lastUiConfig && lastUiConfig.ui;
      const bt = (ui && ui.bookingTitle) || (labels && labels.BookingTitle) || BOOKING_TITLE;
      mt.textContent = bt;
    }
    if (theoryTitle) theoryTitle.textContent = (labels && labels.TheoryTitle) || 'Theorieprüfung';
    if (categoryName && selectedCat) categoryName.textContent = (labels && labels.Categories && labels.Categories[selectedCat]) || selectedCat || 'Kategorie';
  } catch(e) {}
}
function applyUiConfigMessage(data){
  try{
    lastUiConfig = data;
    const ui = data.ui || {};
    if (ui.name || ui.schriftzug) {
      const newName = String(ui.name || ui.schriftzug || '').trim();
      if (newName) {
        CURRENT_BRAND.name = newName;
        window.MTJ_CONFIG.UI_NAME = newName;
        window.MTJ_CONFIG.UI_SCHRIFTZUG = newName;
        try { document.title = newName; } catch(e){}
      }
    }
    if (typeof ui.slogan === 'string') {
      CURRENT_BRAND.slogan = ui.slogan;
      window.MTJ_CONFIG.UI_SLOGAN = ui.slogan;
    }
    if (ui.logo) {
      try { setLogos(ui.logo, ui.logo2 || undefined); } catch(e){}
    }
    if (data.labels && typeof data.labels === 'object') { labels = data.labels || labels || {}; }
    if (data.prices && typeof data.prices === 'object') { prices = data.prices || prices || {}; setPrices(); }
    if (data.categories && typeof data.categories === 'object') { updateCategoryTitles(data.categories); }
    else if (labels && labels.Categories) { updateCategoryTitles(labels.Categories); }

    const mt = document.getElementById('menu-title');
    if (mt && ui.bookingTitle) mt.textContent = ui.bookingTitle;

    refreshVisibleTitles();
  }catch(e){}
}

/* ========= NUI Message handler ========= */
function isNuiForciblyHidden() { return !!(window.__MTJ_UI_HIDDEN === true); }
function allowOpenCheck(kind) {
  // Lizenz-Overlay darf NICHT unterdrückt werden
  if (kind === 'license') return true;
  if (isNuiForciblyHidden()) {
    try { console.log('[mtj_fahrschule][NUI] open suppressed'); } catch(e){}
    return false;
  }
  return true;
}
function isLicenseAction(action){
  return action === 'openLicense' || action === 'showLicense' || action === 'showLicenseCard' || action === 'license:show';
}

function buildTheorySummary(passed, pct){
  const hdr = passed ? ((labels && labels.PassedHeader) || 'Bestanden') : ((labels && labels.FailedHeader) || 'Nicht bestanden');
  const n = (typeof pct === 'number' && isFinite(pct)) ? Math.max(0, Math.min(100, Math.round(pct))) : 0;
  return hdr + '\nProzent: ' + n + '%';
}

window.addEventListener('message', function(e){
  const data = e.data || {};
  const action = data.action || '';
  const isLic = isLicenseAction(action);

  if (!allowOpenCheck(isLic ? 'license' : 'ui')) return;

  if (data.action === 'uiConfig'){ applyUiConfigMessage(data); return; }

  // Copyright / Plagiatschutz: Wasserzeichen aktualisieren
  if (data.action === 'mtj_copyright'){
    try {
      const el = document.getElementById('mtj-copyright');
      if (el && data.author) {
        el.textContent = '\u00A9 ' + (data.year || '2024-2026') + ' ' + data.author;
      }
    } catch(e){}
    return;
  }

  // Führerschein-Overlay: IMMER öffnen, selbst mit Minimaldaten
  if (isLic){
    const lic = data.license || data.payload || data || {};
    const safePayload = {
      org: lic.orgName || lic.org || 'Fahrschule',
      logo: lic.logo || LOGO_SRC_DEFAULT,
      labels: lic.labels || labels || {},
      category: lic.category || lic.categoryLabel || '',
      categoryLabel: lic.categoryLabel || '',
      person: readPersonFields(lic),
      issuedAt: lic.issuedAt || '',
      expiresAt: lic.expiresAt || '',
      photo: lic.photo || '',
      style: lic.style || {},
      display: lic.display || {}
    };
    const autoCloseMs =
      (typeof data.autoCloseMs === 'number' ? data.autoCloseMs : 0) ||
      (safePayload.display && typeof safePayload.display.AutoCloseSeconds === 'number' ? safePayload.display.AutoCloseSeconds * 1000 : 0);
    openLicense(safePayload, autoCloseMs);
    return;
  }

  // Foto-Update: Falls Overlay noch nicht offen, sofort mit Fallback öffnen
  if (data.action === 'updateLicensePhoto'){
    const p = data.photo;
    const normalized = normalizeDataUrl(p) || p;
    if (typeof normalized === 'string' && normalized.length) {
      const overlay = document.getElementById('license-overlay');
      const isOpen = overlay && overlay.classList.contains('show');
      if (!isOpen){
        openLicense({ photo: normalized, logo: LOGO_SRC_DEFAULT, org: 'Fahrschule', labels: labels || {} }, 0);
      }
      setLicensePhoto(normalized);
    }
    return;
  }

  // Theorie-Outcome -> result rendern
  if (data.action === 'theoryOutcome'){
    const passed = !!(data.passed || data.ok);
    const pct = Number((data.scorePct != null ? data.scorePct : (data.percentage != null ? data.percentage : data.pct)) || 0);
    const ts = Number(data.detail && data.detail.ts) || Date.now();
    if (ts && ts === lastShownTheoryTs) return;
    lastShownTheoryTs = ts;

    const summary = buildTheorySummary(passed, pct);
    openResult({ passed: passed, summary: summary, errors: data.errors || [], stats: data.stats || {} });
    return;
  }

  // Praxis-/generisches Result
  if (data.action === 'result' || data.action === 'practiceEnd'){
    openResult(data);
    return;
  }

  // Robust: Reagiere auf stateSync mit lastTheory (wenn noch im Theorie-Panel)
  if (data.action === 'stateSync'){
    try {
      const st = data.state || {};
      if (st.lastTheory){
        const lt = st.lastTheory;
        const ts = Number(lt.ts) || Date.now();
        if (ts !== lastShownTheoryTs && currentSection === 'theory'){
          lastShownTheoryTs = ts;
          const passed = !!lt.passed;
          const pct = Number((lt.scorePct != null ? lt.scorePct : (lt.percentage != null ? lt.percentage : lt.pct)) || 0);
          const summary = buildTheorySummary(passed, pct);
          openResult({ passed: passed, summary: summary, errors: [], stats: {} });
        }
      }
    } catch(e){}
    refreshVisibleTitles();
    return;
  }

  // Branding/Labels beim Öffnen
  if (data.action === 'openMenu' || data.action === 'openTheory') {
    const newName = (data.brandName || data.name || data.title || data.schriftzug || '');
    if (newName && String(newName).trim()) {
      const trimmed = String(newName).trim();
      CURRENT_BRAND.name = trimmed;
      window.MTJ_CONFIG.UI_NAME = trimmed;
      window.MTJ_CONFIG.UI_SCHRIFTZUG = trimmed;
      try { document.title = trimmed; } catch(e){}
    }
    if (data.labels) labels = data.labels;
    if (data.prices) { prices = data.prices; setPrices(); }
    if (labels && labels.Categories) updateCategoryTitles(labels.Categories);
  }

  if (data.action === 'openMenu'){
    if (timerInterval){ clearInterval(timerInterval); timerInterval = null; }
    timeLeft = 0; questions = []; answers = {}; currentIndex = 0;

    labels = data.labels || labels || {};
    prices = data.prices || prices || {};

    const mt = document.getElementById('menu-title');
    if (mt) mt.textContent = data.bookingTitle || (labels && labels.BookingTitle) || BOOKING_TITLE;

    try { setLogos(data.logo, data.secondaryLogo); } catch(e){}

    selectedCat = null;
    selectedMode = 'theory';
    isBooking = false;
    setModeButtons();
    setPrices();
    updateBookButton();

    const firstCard = document.querySelector('.card');
    if (firstCard){
      document.querySelectorAll('.card').forEach(function(b){ b.classList.remove('active'); });
      firstCard.classList.add('active');
      selectedCat = firstCard.dataset.cat;
      updateBookButton();
    }

    showApp();
    setSection('menu');
    safeBanner('');
    return;
  }

  if (data.action === 'openTheory'){
    labels = data.labels || labels || {};
    passPct = Number(data.passPct || data.pass_percentage || DEFAULT_PASS_PCT);
    questionsPerTest = Number(data.questionsPerTest || data.qpt || DEFAULT_QUESTIONS_PER_TEST);
    const timerSec = Number(data.timerSeconds || data.timer || DEFAULT_TIMER_SECONDS);

    try { setLogos(data.logo, data.secondaryLogo); } catch(e){}
    selectedCat = data.category || selectedCat;

    if (categoryName) categoryName.textContent = (labels && labels.Categories && labels.Categories[selectedCat]) || selectedCat || 'Kategorie';
    if (theoryTitle) theoryTitle.textContent = (labels && labels.TheoryTitle) || 'Theorieprüfung';

    showApp();
    setSection('theory');

    const ok = loadQuestions(selectedCat, { count: questionsPerTest });
    startTimer(timerSec);

    const btn = document.getElementById('submit-theory');
    if (btn){
      btn.classList.toggle('hidden', !ok);
      btn.disabled = !ok || !(typeof answers[currentIndex] === 'number');
      btn.textContent = (questions.length <= 1) ? 'Abgeben' : 'Weiter';
      btn.onclick = onSubmitOrNext;
    }

    if (cancelTheoryBtn){
      cancelTheoryBtn.onclick = function(){
        post('close', {}, function(){});
        hideApp();
        cleanupSession();
        currentSection = null;
      };
    }
    return;
  }

  if (data.action === 'notify'){ const text = data.text || data.message || data.msg || ''; const duration = data.duration || data.time || 4000; if (text) safeToast(String(text), duration); return; }
  if (data.action === 'banner'){ const text = data.text || data.message || data.msg || ''; safeBanner(text); return; }

  if (data.action === 'camSwitch' || data.action === 'camClose' || data.action === 'forceClose' || data.action === 'resultForceClose' || data.action === 'resultClosed'){
    hideApp();
    cleanupSession();
    currentSection = null;
    return;
  }
});

/* ========= ESC / Outside Click / Buttons ========= */
window.addEventListener('keydown', function(e){
  if (e.key === 'Escape'){
    e.preventDefault();

    const overlay = document.getElementById('license-overlay');
    if (overlay && overlay.classList.contains('show')) { closeLicense(); return; }

    try {
      if (currentSection === 'result') post('resultClose', {}, function(){});
      else post('close', {}, function(){});
    } catch(_){}
    hideApp();
    cleanupSession();
    currentSection = null;
  }
});

// Menü schließen
if (closeMenuBtn){
  closeMenuBtn.addEventListener('click', function(){
    post('close', {}, function(){});
    hideApp();
    cleanupSession();
    currentSection = null;
  });
}

// Ergebnis schließen
if (closeResultBtn){
  closeResultBtn.addEventListener('click', function(){
    post('resultClose', {}, function(){});
    hideApp();
    cleanupSession();
    currentSection = null;
  });
}

// Outside-click
document.addEventListener('pointerdown', function(ev){
  try{
    if (!app || app.classList.contains('hidden')) return;
    if (app.contains(ev.target)) return;

    const overlay = document.getElementById('license-overlay');
    if (overlay && overlay.classList.contains('show')) { closeLicense(); return; }

    if (currentSection === 'result'){ post('resultClose', {}, function(){}); return; }
    post('close', {}, function(){});
    hideApp();
    cleanupSession();
    currentSection = null;
  }catch(e){}
}, true);

/* ========= Booking / Kategorien / Modus ========= */
document.querySelectorAll('.card').forEach(function(btn){
  btn.addEventListener('click', function(){
    document.querySelectorAll('.card').forEach(function(b){ b.classList.remove('active'); });
    btn.classList.add('active');
    selectedCat = btn.dataset.cat;
    updateBookButton();
  });
});
if (modeTheoryBtn) modeTheoryBtn.addEventListener('click', function(){ selectedMode='theory'; setModeButtons(); setPrices(); });
if (modePracticeBtn) modePracticeBtn.addEventListener('click', function(){ selectedMode='practice'; setModeButtons(); setPrices(); });

if (bookBtn) bookBtn.addEventListener('click', async function(){
  if (!selectedCat){ safeToast('Bitte zuerst eine Kategorie wählen.', 3000); return; }
  if (isBooking) return;
  isBooking = true; updateBookButton(); safeBanner('Bitte warten …');
  const safety = setTimeout(function(){ if (isBooking){ isBooking=false; updateBookButton(); safeBanner(''); } }, 2500);
  try {
    await new Promise(function(resolve){ post('book', { category: selectedCat, mode: selectedMode }, function(){ resolve(); }); });
  } catch(err) {
    safeToast('Keine Antwort vom Server. Bitte erneut versuchen.', 4000);
  } finally {
    isBooking = false; updateBookButton(); safeBanner(''); clearTimeout(safety);
  }
});

/* ========= POST wrapper ========= */
function post(name, data, cb){
  try{
    fetch('https://'+GetParentResourceName()+'/'+name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    })
    .then(function(r){ return r.text().then(function(t){ var parsed={}; try{ parsed = JSON.parse(t); }catch(e){} if (cb) cb(parsed); }); })
    .catch(function(){ if (cb) cb({ __error: true }); });
  }catch(err){ if (cb) cb({ __error: true }); }
}

/* ========= Cleanup/Init ========= */
function cleanupSession(){
  if (timerInterval){ clearInterval(timerInterval); timerInterval = null; }
  timeLeft = 0;
  rawPool = [];
  questions = [];
  answers = {};
  currentIndex = 0;
  isBooking = false;
}
document.addEventListener('DOMContentLoaded', function(){
  try{
    const style = document.createElement('style');
    style.textContent = '' +
      '.panel-body.hidden{display:none!important;visibility:hidden!important;pointer-events:none!important;opacity:0!important}' +
      '#menu.hidden,#theory.hidden,#result.hidden{display:none!important;visibility:hidden!important;pointer-events:none!important;opacity:0!important}';
    document.head.appendChild(style);
  }catch(e){}

  const name = CFG.UI_SCHRIFTZUG || CFG.UI_NAME || 'Fahrschule';
  const hl = document.getElementById('headline'); if (hl) hl.textContent = name;
  const sl = document.getElementById('slogan'); if (sl) sl.textContent = CFG.UI_SLOGAN || 'Dein Weg zum Führerschein';
  setLogos(CFG.LOGO_PATH || 'img/logo.png', '');

  // License-Overlay sicherstellen + Close-Button verbinden
  ensureLicenseDom();

  hideApp();
  currentSection = null;
  setModeButtons();
  setPrices();
});