<script lang="ts">
  import { tick } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import { cubicOut, cubicInOut } from 'svelte/easing';

  const DEFAULT_BANNER = 'https://media.discordapp.net/attachments/1435378518056898642/1439403169493811221/b03d76a26e01b2a887f165bbfd9777f9.png?ex=691a642a&is=691912aa&hm=daa88888bd981706a34a4be2bea2aa23b78415446ef170ffcc611f604e632d98&=&format=webp&quality=lossless';
  // Owner-editable list of banners. Add/remove URLs here.
  const BANNERS: string[] = [
    DEFAULT_BANNER,
    'https://media.discordapp.net/attachments/1435378518056898642/1439401418258645144/download_2.gif?ex=691a6288&is=69191108&hm=a7a2ca7e6dcb3414e610b3eedd7ba8301131d6a05709ebb2dc61d44daed3f56a&=',
    'https://media.discordapp.net/attachments/1435378518056898642/1439399993650839714/download_1.gif?ex=691a6135&is=69190fb5&hm=a80e164f829aadc92e070f58ca365158d89887874f4823ba6c80e9d5cc574ae4&=&width=517&height=646',
    'https://media.discordapp.net/attachments/1435378518056898642/1439135774523002931/download.gif?ex=69196b22&is=691819a2&hm=3bf799535c9fc608d2b6ccbdf78c9333bb63935b3a6a54c991271b99feabefb5&=width=676&height=380'
  ];

  // Owner-editable themes. Update vars to tune look.
  type ThemeVars = { [k: string]: string };
  type Theme = { name: string, vars: ThemeVars };
  const THEMES: Theme[] = [
    {
      name: 'Black',
      vars: {
        '--bg-900': 'rgba(10,10,12,.94)',
        '--bg-850': 'rgba(8,8,10,.90)',
        '--bg-800': 'rgba(16,16,20,.82)',
        '--bg-750': 'rgba(22,22,26,.72)',
        '--text': '#f1f1f3',
        '--text-dim': 'rgba(241,241,243,.80)',
        '--accent': '#7a4dff',
        '--accent-600': '#5e3de6',
        '--accent-soft': 'rgba(122,77,255,.22)'
      }
    },
    {
      name: 'Dark Red',
      vars: {
        '--bg-900': 'rgba(18,6,8,.94)',
        '--bg-850': 'rgba(14,6,8,.90)',
        '--bg-800': 'rgba(26,10,12,.82)',
        '--bg-750': 'rgba(34,12,14,.72)',
        '--text': '#f7eaea',
        '--text-dim': 'rgba(247,234,234,.82)',
        '--accent': '#b02a2a',
        '--accent-600': '#8f1f1f',
        '--accent-soft': 'rgba(176,42,42,.22)'
      }
    },
    {
      name: 'Custom',
      vars: {
        // Tune your own palette here:
        '--bg-900': 'rgba(10,12,14,.94)',
        '--bg-850': 'rgba(8,10,12,.90)',
        '--bg-800': 'rgba(14,18,22,.82)',
        '--bg-750': 'rgba(20,26,30,.72)',
        '--text': '#eef7f9',
        '--text-dim': 'rgba(238,247,249,.80)',
        '--accent': '#2bbbad',
        '--accent-600': '#249e93',
        '--accent-soft': 'rgba(43,187,173,.22)'
      }
    }
  ];

  let current = 0;
  let activeMenu: any[] = [];
  let activeTabs = ['Main Menu'];
  let currentTab = 0;
  let showing = true;

  let itemRefs: HTMLElement[] = [];
  let textRefs: HTMLInputElement[] = [];
  let position: string = 'left';
  let offsetX = 0; // in vh
  let offsetY = 0; // in vh

  let banner: string = DEFAULT_BANNER;
  let bannerOk = true;

  // Theme state
  let themeIndex = 0;
  function applyThemeVars(vars: Record<string, string>) {
    const root = document.documentElement;
    for (const [k, v] of Object.entries(vars)) {
      root.style.setProperty(k, v);
    }
  }
  function applyThemeIndex(idx: number) {
    const clamped = Math.max(0, Math.min(idx | 0, THEMES.length - 1));
    themeIndex = clamped;
    applyThemeVars(THEMES[themeIndex]?.vars || {});
  }

  let wrapperEl: HTMLElement;
  let listEl: HTMLElement;
  let trackTop = 0, trackHeight = 0, thumbTop = 0, thumbHeight = 24;
  let hasOverflow = false;

  const MIN_THUMB = 18, NO_OVERFLOW_THUMB_MAX = 28;

  let capturingIndex: number | null = null;

  // Hover pop-out (Lua->NUI)
let popVisible = false;
let popName = '';
let popSid: number | null = null;
let popDist = 0;
let popHealth = 0;
let popArmour = 0;
let popVehicle = '';
let popInVeh = false;
let popAlive = true;
let popSpeedKmh = 0;
let popIsVisible = true;
let popWeaponName = '';

  // Spectator overlay (World -> Spectator Watch)
  let spectatorBox: { show: boolean; count: number } = { show: false, count: 0 };

  // Open-key prompt (host-controlled, hidden by default)
  let keyPrompt = { show: false, vk: null as number | null, label: 'None' };

  // Derived selectable list
  let selectableMenu: any[] = [];
  $: selectableMenu = activeMenu.filter(o => o?.type !== 'divider');
  let selectableIndices: number[] = [];
  $: selectableIndices = activeMenu.map((o, i) => (o?.type !== 'divider' ? i : -1)).filter(i => i !== -1);

  function counterCurrent(): number {
    const total = selectableIndices.length;
    if (total === 0) return 0;
    const pos = selectableIndices.indexOf(current);
    if (pos !== -1) return pos + 1;
    let nearest = -1, best = 1e9;
    for (let i = 0; i < total; i++) {
      const d = Math.abs(selectableIndices[i] - current);
      if (d < best) { best = d; nearest = i; }
    }
    return nearest !== -1 ? nearest + 1 : 0;
  }

  function syncThumb() {
    if (!listEl) return;
    const trackScrollable = Math.max(0, trackHeight - thumbHeight);
    if (hasOverflow) {
      const maxScroll = Math.max(0, listEl.scrollHeight - listEl.clientHeight);
      const ratio = maxScroll > 0 ? Math.min(1, Math.max(0, listEl.scrollTop / maxScroll)) : 0;
      thumbTop = Math.round(trackScrollable * ratio);
    } else {
      const count = Math.max(1, activeMenu.length);
      const idx = Math.min(Math.max(current, 0), count - 1);
      const last = Math.max(1, count - 1);
      const ratio = count > 1 ? (idx / last) : 0;
      thumbTop = Math.round(trackScrollable * ratio);
    }
  }

  function measureScrollbar() {
    if (!wrapperEl || !listEl) return;
    const wrapperRect = wrapperEl.getBoundingClientRect();
    const listRect = listEl.getBoundingClientRect();
    const clientH = listEl.clientHeight;
    const scrollH = listEl.scrollHeight;

    hasOverflow = scrollH > clientH + 1;

    // Track starts at the list's top inside the wrapper
    trackTop = Math.round(listRect.top - wrapperRect.top);
    // When overflowing, track is the visible client height; when not, shrink to content height
    const contentH = Math.min(clientH, scrollH || clientH);
    trackHeight = Math.round(hasOverflow ? clientH : contentH);

    thumbHeight = hasOverflow
      ? Math.max(MIN_THUMB, Math.round((clientH / scrollH) * trackHeight))
      : Math.max(MIN_THUMB, Math.min(NO_OVERFLOW_THUMB_MAX, trackHeight));

    syncThumb();
  }

  let measureReq = 0;
  function scheduleMeasure() {
    if (measureReq) return;
    measureReq = requestAnimationFrame(() => {
      measureReq = 0 as any;
      measureScrollbar();
    });
  }

  function animateScrollTo(el: HTMLElement, target: number, duration = 240) {
    const start = el.scrollTop;
    const distance = target - start;
    if (Math.abs(distance) < 1) { el.scrollTop = target; syncThumb(); return; }
    const startTime = performance.now();
    function step(now: number) {
      const t = Math.min(1, (now - startTime) / duration);
      const eased = cubicInOut(t);
      el.scrollTop = start + distance * eased;
      syncThumb();
      if (t < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function centerOnSelected(index: number) {
    if (!listEl) return;
    const maxScroll = Math.max(0, listEl.scrollHeight - listEl.clientHeight);
    if (!hasOverflow || maxScroll === 0) { animateScrollTo(listEl, 0); return; }
    const lastIdx = Math.max(0, activeMenu.length - 1);
    if (index <= 0) { animateScrollTo(listEl, 0); return; }
    if (index >= lastIdx) { animateScrollTo(listEl, maxScroll); return; }
    const item = itemRefs[index];
    if (!item) return;
    const itemTop = item.offsetTop;
    const itemCenter = itemTop + item.offsetHeight / 2;
    let target = itemCenter - listEl.clientHeight / 2;
    target = Math.max(0, Math.min(maxScroll, target));
    animateScrollTo(listEl, target);
  }

  let scrollRAF = 0 as any;
  function onListScroll() {
    if (scrollRAF) return;
    scrollRAF = requestAnimationFrame(() => { scrollRAF = 0; syncThumb(); });
  }
  $: if (showing) { centerOnSelected(current); }

  async function focusTextAt(idx: number) { await tick(); textRefs[idx]?.focus(); }

  // Host messaging
  function post(action: string, payload: any = {}) {
    const msg = JSON.stringify({ action, ...payload });
    try { window.postMessage(msg, '*'); } catch {}
    try { (window.parent ?? window).postMessage(msg, '*'); } catch {}
  }
  function commitText(index: number, value: string) { post('textCommit', { index, value }); }

  function handleTextKeydown(index: number, option: any, e: KeyboardEvent) {
    // Keep menu navigation from stealing keys while typing
    e.stopPropagation();
    if (e.key === 'Enter') {
      e.preventDefault();
      commitText(index, option.value ?? '');
      (e.currentTarget as HTMLInputElement)?.blur();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      (e.currentTarget as HTMLInputElement)?.blur();
    }
  }

  // VK mapping (for key prompt)
  function vkFromEvent(e: KeyboardEvent): number | null {
    const key = e.key, code = e.code;
    const map: Record<string, number> = {
      Escape: 0x1B, Esc: 0x1B, Tab: 0x09, CapsLock: 0x14,
      Shift: 0x10, ShiftLeft: 0x10, ShiftRight: 0x10,
      Control: 0x11, ControlLeft: 0x11, ControlRight: 0x11,
      Alt: 0x12, AltLeft: 0x12, AltRight: 0x12,
      Enter: 0x0D, NumpadEnter: 0x0D, Backspace: 0x08,
      Space: 0x20, ' ': 0x20, Insert: 0x2D, Delete: 0x2E,
      Home: 0x24, End: 0x23, PageUp: 0x21, PageDown: 0x22,
      ArrowLeft: 0x25, ArrowUp: 0x26, ArrowRight: 0x27, ArrowDown: 0x28,
      Meta: 0x5B, OS: 0x5B, MetaLeft: 0x5B, MetaRight: 0x5C,
      NumpadMultiply: 0x6A, NumpadAdd: 0x6B, NumpadSubtract: 0x6D,
      NumpadDecimal: 0x6E, NumpadDivide: 0x6F,
      Semicolon: 0xBA, ';': 0xBA, Equal: 0xBB, '=': 0xBB,
      Comma: 0xBC, ',': 0xBC, Minus: 0xBD, '-': 0xBD,
      Period: 0xBE, '.': 0xBE, Slash: 0xBF, '/': 0xBF,
      Backquote: 0xC0, '`': 0xC0, BracketLeft: 0xDB, '[': 0xDB,
      Backslash: 0xDC, '\\': 0xDC, BracketRight: 0xDD, ']': 0xDD,
      Quote: 0xDE, "'": 0xDE
    };
    if (/^F\d{1,2}$/.test(key)) { const n = parseInt(key.slice(1), 10); if (n >= 1 && n <= 24) return 0x70 + (n - 1); }
    if (key && key.length === 1 && /^[A-Za-z]$/.test(key)) return key.toUpperCase().charCodeAt(0);
    if (key && key.length === 1 && /^[0-9]$/.test(key)) return 0x30 + parseInt(key, 10);
    if (/^Numpad[0-9]$/.test(code)) return 0x60 + parseInt(code.replace('Numpad', ''), 10);
    return map[key] ?? map[code] ?? null;
  }
  function vkLabel(vk: number | null): string {
    if (vk == null) return 'None';
    return '0x' + vk.toString(16).toUpperCase().padStart(2, '0');
  }

  function onWindowKeydown(e: KeyboardEvent) {
    if (capturingIndex !== null) {
      if (e.key === 'Escape') {
        e.preventDefault();
        post('keyCaptured', { index: capturingIndex, vk: null });
        capturingIndex = null;
        return;
      }
      const vk = vkFromEvent(e);
      if (vk != null) {
        e.preventDefault();
        post('keyCaptured', { index: capturingIndex, vk });
        capturingIndex = null;
      }
      return;
    }

    // While the key-prompt is visible, capture a virtual-key and confirm with Enter
    if (keyPrompt.show) {
      if (e.key === 'Enter' && keyPrompt.vk != null) {
        e.preventDefault();
        const vk = keyPrompt.vk;
        post('setOpenKey', { vk });
        keyPrompt.show = false;
        return;
      }
      const vk = vkFromEvent(e);
      if (vk != null) {
        e.preventDefault();
        keyPrompt.vk = vk;
        keyPrompt.label = vkLabel(vk);
      }
      return;
    }
  }
  window.addEventListener('keydown', onWindowKeydown);
  window.addEventListener('resize', scheduleMeasure);

  // Keyboard-selection hover fallback
  let lastHoverSid: number | null = null;
  $: if (showing) {
    const it: any = activeMenu?.[current];
    const sid = it && it.sid != null ? Number(it.sid) : null;
    if (sid !== lastHoverSid) {
      if (sid != null && !Number.isNaN(sid)) post('playerHoverStart', { sid });
      else post('playerHoverEnd');
      lastHoverSid = sid;
    }
  }

  // ========= Notifications =========
  type Toast = { id: number, title: string, message: string, ntype: 'info' | 'success' | 'warning' | 'error', icon?: string, timeout: number };
  let toasts: Toast[] = [];
  let nextToastId = 1;
  const MAX_TOASTS = 4;

  const defaultsByType = {
    info:    { color: '#82b1ff', icon: 'ph-info' },
    success: { color: '#6bd36b', icon: 'ph-check-circle' },
    warning: { color: '#f6c654', icon: 'ph-warning' },
    error:   { color: '#ff6b6b', icon: 'ph-x-circle' },
  } as const;

  function pushToast(t: Partial<Toast>) {
    const ntype = (t.ntype ?? 'info') as Toast['ntype'];
    const def = defaultsByType[ntype];
    const toast: Toast = {
      id: nextToastId++,
      title: String(t.title ?? ''),
      message: String(t.message ?? ''),
      ntype,
      icon: String(t.icon ?? def.icon),
      timeout: Number(t.timeout ?? 3500),
    };
    // cap count to avoid layout thrash
    toasts = [...toasts, toast];
    if (toasts.length > MAX_TOASTS) toasts = toasts.slice(toasts.length - MAX_TOASTS);
    const myId = toast.id;
    setTimeout(() => { toasts = toasts.filter(x => x.id !== myId); }, toast.timeout);
  }
  function closeToast(id: number) { toasts = toasts.filter(t => t.id !== id); }

  window.addEventListener('message', (event) => {
    let payload: any = event.data ?? {};
    if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch { return; } }
    const { action, ...data } = payload;

    if (action === 'setCurrent') {
      current = (data.current || 1) - 1;
      activeMenu = data.menu || [];
      showing = true;
      scheduleMeasure();
      tick().then(() => centerOnSelected(current));
    } else if (action === 'setTabs') {
      activeTabs = Array.isArray(data.tabs) && data.tabs.length ? data.tabs : ['Main Menu']; currentTab = 0;
    } else if (action === 'setTabIndex') {
      currentTab = data.index || 0;
    } else if (action === 'setVisible') {
      showing = !!data.visible;
      if (showing) {
        scheduleMeasure();
        tick().then(() => centerOnSelected(current));
      } else {
        popVisible = false;
      }
    } else if (action === 'position') {
      position = data.position || 'left'; scheduleMeasure();
    } else if (action === 'menuOffsets') {
      offsetX = Number(data.x) || 0;
      offsetY = Number(data.y) || 0;
      scheduleMeasure();
    } else if (action === 'banner') {
      bannerOk = true; banner = data.banner || DEFAULT_BANNER;
    } else if (action === 'setBanner') {
      // Accept alias payloads: { url } or { banner }
      bannerOk = true; banner = data.url || data.banner || DEFAULT_BANNER;
    } else if (action === 'bannerIndex' || action === 'setBannerIndex') {
      const idx = Math.max(0, Math.min(Number(data.index) || 0, BANNERS.length - 1));
      bannerOk = true; banner = BANNERS[idx] || DEFAULT_BANNER;
    } else if (action === 'themeIndex' || action === 'setThemeIndex') {
      applyThemeIndex(Number(data.index) || 0);
    } else if (action === 'beginTextEdit') {
      focusTextAt(Number(data.index) || 0);
    } else if (action === 'beginKeyCapture') {
      capturingIndex = Number(data.index) || 0;
    } else if (action === 'RebuildPlayerPopOutFinderUI') {
  popVisible = !!data.visible;
  if (popVisible) {
    if (data.sid        !== undefined) popSid        = Number(data.sid);
    if (data.name       !== undefined) popName       = String(data.name ?? '');
    if (data.dist       !== undefined) popDist       = Number(data.dist ?? 0);
    if (data.health     !== undefined) popHealth     = Number(data.health ?? 0);
    if (data.armour     !== undefined) popArmour     = Number(data.armour ?? 0);
    if (data.vehicle    !== undefined) popVehicle    = String(data.vehicle ?? '');
    if (data.inVeh      !== undefined) popInVeh      = !!data.inVeh;
    if (data.alive      !== undefined) popAlive      = !!data.alive;
    if (data.speedKmh   !== undefined) popSpeedKmh   = Number(data.speedKmh ?? 0);
    if (data.isVisible  !== undefined) popIsVisible  = !!data.isVisible;
    if (data.weaponName !== undefined) popWeaponName = String(data.weaponName ?? '');
  }
    } else if (action === 'showKeyPrompt') {
      keyPrompt.show = !!data.show;
      if (keyPrompt.show) {
        keyPrompt.vk = null;
        keyPrompt.label = 'None';
      }
    } else if (action === 'keyPromptDone') {
      keyPrompt.show = false;
    } else if (action === 'setSpectatorOverlay') {
      spectatorBox.show = !!data.enabled;
      spectatorBox.count = Number(data.count ?? 0);
    } else if (action === 'notify') {
      pushToast(data);
    }
  });

  function onRowEnter(opt: any) { if (opt && opt.sid != null) post('playerHoverStart', { sid: opt.sid }); }
  function onRowLeave(opt: any) { if (opt && opt.sid != null) post('playerHoverEnd'); }
  // Apply default theme on load
  applyThemeIndex(themeIndex);
</script>

<svelte:head>
  <script src="https://unpkg.com/@phosphor-icons/web"></script>
</svelte:head>

<style>
  :root{
    --accent:#6b4eff; --accent-600:#6b4eff; --accent-soft:rgba(122,77,255,.16);
    --bg-900:rgba(26,19,38,.92); --bg-850:rgba(8,6,12,.88); --bg-800:rgba(0, 0, 0, 0.8); --bg-750:rgba(0, 0, 0, 0.7);
    --text:#ffffff; --text-dim:rgba(255,255,255,.80);
  }
  *{ background:none; }
  body{ margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif; }

  /* Notifications (top-center) */
  .noti-wrap{
    position:fixed;
    top:22px;
    left:50%;
    transform:translateX(-50%);
    display:flex; flex-direction:column; gap:8px;
    width:min(90vw, 380px);
    align-items:center;
    z-index:10000; pointer-events:none;
  }
  .noti{
    pointer-events:auto; display:flex; gap:10px; align-items:flex-start;
    width:100%; max-width:360px; padding:10px 12px; border-radius:4px;
    background:rgba(16,12,24,.98); border:1px solid rgba(120,80,160,.45);
    box-shadow:0 4px 16px rgba(0,0,0,.4);
  }
  .noti .icon{ font-size:18px; line-height:18px; }
  .noti .body{ flex:1; display:flex; flex-direction:column; gap:2px; }
  .noti .title{ font-weight:700; color:#e9dcff; font-size:14px; letter-spacing:.02em; }
  .noti .msg{ color:#d6c9ef; font-size:12px; line-height:1.25; }
  .noti .close{ color:#cbb7ff; opacity:.8; cursor:pointer; font-size:16px; }
  .noti .close:hover{ opacity:1; }

  .toggle{ appearance:none; -webkit-appearance:none; width:3.6vh; height:1.8vh; background-color:var(--bg-750); border-radius:1.2vh; position:relative; cursor:pointer; transition:background-color .25s cubic-bezier(.2,.8,.2,1); box-shadow: inset 0 0 0 .12vh rgba(0,0,0,.35); }
  .toggle::before{ content:''; position:absolute; width:1.3vh; height:1.3vh; border-radius:50%; background:#fff; top:.25vh; left:.25vh; transition:transform .22s cubic-bezier(.2,.8,.2,1); box-shadow:0 .1vh .25vh rgba(0,0,0,.35); }
  .toggle.on::before{ background:var(--accent); transform:translateX(1.8vh); }

  .range { width:9vh; height:1.2vh; background:transparent; margin:0; outline:none; border:0; }
  .range, .range::-webkit-slider-thumb { -webkit-appearance:none; }
  .range::-webkit-slider-runnable-track { height:.6vh; border-radius:1.2vh; background:linear-gradient(to right, rgba(255,255,255,.95) 0 var(--pct), rgb(60,45,86) var(--pct) 100%); transition:background .12s linear; }
  .range::-webkit-slider-thumb { width:1.2vh; height:1.2vh; margin-top:-.32vh; border-radius:50%; background:#fff; cursor:pointer; box-shadow:0 .1vh .25vh rgba(0,0,0,.35); transition:transform .15s cubic-bezier(.2,.8,.2,1); will-change: transform; }
  .range:active::-webkit-slider-thumb { transform:scale(1.06); }

  .hide-scrollbar { overflow-y:auto; scrollbar-width:none; -ms-overflow-style:none; }
  .hide-scrollbar::-webkit-scrollbar { display:none; width:0; height:0; }

  .scrollbar-container{ position:absolute; left:.5vh; width:.7vh; border-radius:.2vh; background:var(--bg-900); pointer-events:none; z-index:100; transition:height .2s ease, opacity .2s ease; overflow:hidden; }
  .scrollbar-thumb { position:absolute; left:0; right:0; top:0; height:1.2vh; border-radius:.2vh; background:var(--accent); transition: top 180ms cubic-bezier(.2,.8,.2,1), height 200ms ease; will-change: top, height; transform: translateZ(0); }

  .menu-divider{ position:relative; display:flex; align-items:center; justify-content:center; height:2.2vh; margin:.6vh 0; pointer-events:none; }
  .menu-divider span{ color:var(--text-dim); font-size:1.0vh; font-weight:600; letter-spacing:.02em; }
  .menu-divider::before, .menu-divider::after{ content:""; position:absolute; top:50%; transform:translateY(-50%); width:7vh; height:.4vh; background: var(--accent); border-radius:.3vh; opacity:.95; }
  .menu-divider::before{ left:1.2vh } .menu-divider::after{ right:1.2vh }

  .menu-item {
    transition: background-color .16s ease, border-color .16s ease;
    will-change: background-color, border-color;
    border-left:.18vh solid transparent;
  }
  .menu-item:hover {
    background-color: var(--accent-soft);
    border-left-color: var(--accent);
  }
  .menu-item.active {
    background-color: var(--accent-soft);
    border-left-color: var(--accent-600);
  }

  .text-input { width:14vh; padding:.5vh .8vh; border-radius:.3vh; outline:none; border:.12vh solid rgba(255,255,255,.18); background:var(--bg-800); color:var(--text); font-size:1.2vh; box-shadow: inset 0 0 .25vh rgba(0,0,0,.35); transition: border-color .15s ease, box-shadow .15s ease; }
  .text-input:focus { border-color: var(--accent); box-shadow: 0 0 0 .15vh rgba(122,77,255,.35); }

  .key-pill { padding:.35vh .7vh; border-radius:.3vh; background:var(--bg-800); color:var(--text); font-size:1.1vh; border:.12vh solid rgba(255,255,255,.24); }
  .capture-pill { background: var(--accent); color:#fff; }

  .player-popout{
  position:absolute;
  left: calc(1.75vh + 33.5vh + 2vh);
  top: 10.4vh;
  width: 18.5vh;
  color:#e9dcff;
  background: rgba(12,10,14,.98);
  border:1px solid rgba(120,80,160,.45);
  border-radius:.4vh;
  padding:1.1vh 1.2vh;
  box-shadow:0 .6vh 1.8vh rgba(0,0,0,.4);
}
.pop-title{ font-weight:700; margin-bottom:.8vh; letter-spacing:.02em; font-size:1.25vh; }
.kv{ display:flex; align-items:center; justify-content:space-between; margin:.4vh 0; font-size:1.0vh; }
.kv .health{ color:#ff5a66; }
.kv .label{ opacity:.85; }
.kv .value{ font-weight:600; }
.bar{ height:.6vh; background:rgba(255,255,255,.08); border-radius:.4vh; overflow:hidden; margin:.4vh 0 .2vh; }
.fill{ height:100%; background:linear-gradient(90deg,#9a5efc,#b47bff); }

  .openkey-pop{ position:fixed; right:18px; bottom:18px; width:260px; background:rgba(12,10,14,.98); color:#e9dcff; border:1px solid rgba(120,80,160,.45); border-radius:4px; padding:12px 14px; box-shadow:0 6px 18px rgba(0,0,0,.4); z-index:9999; }
  .openkey-pop .t{ font-weight:700; margin-bottom:6px; }
  .openkey-pop .v{ margin:4px 0; }
  .openkey-pop .h{ font-size:12px; opacity:.7; }
  /* 60fps-friendly enter animation */
  @keyframes menuPop { from { opacity:0; transform: translateY(8px) scale(.98); } to { opacity:1; transform: translateY(0) scale(1); } }
  .menu-root { will-change: transform, opacity; transform: translateZ(0); }

  .banner-title {
    text-shadow: 0 0.08vh 0.32vh rgba(0,0,0,.95);
  }

  /* --- UI smoothing + performance-friendly tweaks --- */

  /* Gradient accent strip on the left side of the menu */
  .menu-root {
    box-shadow: 0 .5vh 1.8vh rgba(0,0,0,.4);
    position: relative;
  }

  /* Banner card helper so we can share styling and shadow */
  .banner-card {
    box-shadow: 0 .4vh 1.6vh rgba(0,0,0,.35);
  }

  /* Glow reflection below active tab / banner */
  .list-shell::before {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    top: 0;
    height: .7vh;
    background: linear-gradient(to bottom, rgba(122,77,255,.35), transparent);
    pointer-events: none;
  }

  /* Zebra rows + smoother hover/active feedback */
  .menu-item {
    transition:
      background-color .16s ease,
      border-color .16s ease,
      transform .14s ease;
    will-change: background-color, border-color, transform;
  }
  .menu-item:nth-child(even) {
    background-color: rgba(255,255,255,.01);
  }
  .menu-item:hover {
    background-color: var(--accent-soft);
    border-left-color: var(--accent);
    transform: translateX(0.2vh);
  }
  .menu-item.active {
    background-color: var(--accent-soft);
    border-left-color: var(--accent-600);
    transform: translateX(0.3vh);
  }

  /* Labels: keep them on one line and avoid layout jitter */
  .menu-item > span:first-child {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }


  /* Footer bar refinements */
  .footer-bar {
    font-size: 1.05vh;
    letter-spacing: .03em;
  }
  .footer-bar span:first-child {
    text-transform: uppercase;
    opacity: .85;
  }
  .footer-bar span:last-child {
    padding: .1vh .5vh;
    border-radius: .2vh;
    background: rgba(255,255,255,.04);
    font-weight: 600;
  }

  /* Spectator overlay box (World -> Spectator Watch) */
  .spectator-box {
    position:fixed;
    top:3vh;
    right:3vh;
    min-width:14vh;
    max-width:24vh;
    background:rgba(0,0,0,.92);
    color:#fff;
    border-radius:.5vh;
    padding:.9vh .9vh .8vh;
    border:.12vh solid rgba(255,255,255,.2);
    box-shadow:0 .6vh 1.8vh rgba(0,0,0,.6);
    font-size:1.0vh;
    z-index:9999;
  }
  .spec-title {
    font-weight:700;
    letter-spacing:.16em;
    font-size:1.0vh;
    margin-bottom:.5vh;
  }
  .spec-list {
    list-style:none;
    padding:0;
    margin:0;
  }
  .spec-count {
    font-weight:600;
    font-size:1.3vh;
    margin-top:.1vh;
  }
  .spec-empty {
    opacity:.8;
  }

  /* Tiny press effect on toggles */
  .toggle:active::before {
    transform: scale(0.96) translateX(1.8vh);
  }
</style>


{#if showing}
  <div bind:this={wrapperEl}
       class="menu-root"
       style="position:absolute; top:calc(50% + {offsetY}vh); transform:translate({offsetX}vh, -50%); left:{position == 'left' ? '6.5vh' : 'calc(100% - 41vh)'};">

    <div class="scrollbar-container" style="top:{trackTop}px; height:{trackHeight}px;">
      <div class="scrollbar-thumb" style="top:{thumbTop}px; height:{thumbHeight}px;" />
    </div>

    <div style="transform: translateY(-0.6vh); margin-left:1.75vh; width:95%; border-radius:.4vh; overflow:hidden; line-height:0; box-shadow:0 .4vh 1.6vh rgba(0,0,0,.4);">
      {#if banner && bannerOk}
        <img src={banner} crossorigin="anonymous" on:error={() => bannerOk = false} alt="Banner"
             style="display:block; width:100%; height:9.5vh; object-fit:cover; margin:0; padding:0; border:0; will-change: opacity;"
             in:fade={{ duration: 240 }} />
      {:else}
        <div style="width:100%; height:9.5vh; background:linear-gradient(90deg, rgba(122,77,255,.35), rgba(122,77,255,.05));"></div>
      {/if}

      <div style="display:flex; align-items:center; justify-content:center; background:var(--bg-850); border-radius:0 0 .4vh .4vh;"
           in:fade={{ duration: 160 }}>
        {#if activeTabs.length === 1}
          <div class="banner-title" style="flex:1; text-align:center; padding:1.5vh 1.5vh; font-size:1.15vh; font-weight:600; letter-spacing:.03em; background:linear-gradient(0deg, var(--accent-600) 0%, transparent 100%); color:var(--text); white-space:nowrap;">
            {activeTabs[0]}
          </div>
        {:else}
          {#each activeTabs as tab, i (tab)}
            <div class="banner-title" style="flex:1; text-align:center; padding:1.5vh 1.5vh; font-size:1.15vh; font-weight:500; cursor:pointer; transition:all .15s ease; background:{i === currentTab ? 'linear-gradient(0deg, var(--accent-600) 0%, transparent 100%)' : 'transparent'}; color:var(--text);"
                 in:fade={{ duration: 140 }}>
              {tab}
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <div class="list-shell" style="position:absolute; margin-left:1.75vh; width:33.5vh; background:var(--bg-900); border-radius:.4vh; display:flex; flex-direction:column; overflow:hidden; position:relative; box-shadow:0 .5vh 1.8vh rgba(0,0,0,.4);">
      <div class="hide-scrollbar" bind:this={listEl} on:scroll={onListScroll} style="max-height:33.6vh; content-visibility:auto; contain-intrinsic-size: 300px 420px;">
        <div style="display:flex; flex-direction:column; gap:0; position:relative;">
          {#each activeMenu as option, index (option.label)}
            {#if option.type == 'divider'}
              <div class="menu-divider" in:fade={{ duration: 120 }}><span>{option.label}</span></div>
            {:else}
              <div bind:this={itemRefs[index]}
                   class="menu-item {index == current ? 'active' : ''}"
                   style="padding:.8vh 1.0vh; color:var(--text); border-radius:.3vh; justify-content:space-between; display:flex; align-items:center; font-size:1.4vh; gap:1vh; font-weight:400; cursor:pointer; z-index:1;"
                   on:mouseenter={() => onRowEnter(option)} on:mouseleave={() => onRowLeave(option)}>
                <span style="flex-grow:1; text-align:left; font-size:1.2vh; height:100%;">{option.label}</span>

                {#if option.type == 'text'}
                  <input bind:this={textRefs[index]} class="text-input" type="text" bind:value={option.value} placeholder={option.placeholder || 'Type...'} on:keydown={(e) => handleTextKeydown(index, option, e)} on:blur={() => commitText(index, option.value ?? '')} />

                {:else if option.type == 'keybind'}
                  <span class="key-pill {capturingIndex === index ? 'capture-pill' : ''}">{capturingIndex === index ? 'Press any key...' : (option.vk != null ? `VK ${option.vk}` : 'None')}</span>

                {:else if option.type == 'submenu'}
                  <i class="ph ph-caret-right" style="color:var(--text); font-size:1.2vh;"></i>

                {:else if option.type == 'checkbox'}
                  <div class="toggle {option.checked ? 'on' : ''}"></div>

                {:else if option.type == 'slider'}
                  <input type="range" class="range" bind:value={option.value} min={option.min} max={option.max} step={option.step} style="--pct:{(Number(option.value||0) / Number(option.max||1)) * 100}%;" />

                {:else if option.type == 'scroll'}
                  <div style="position:relative; display:flex; align-items:center; justify-content:center; width:auto; height:100%; gap:.4vh; color:var(--text);">
                    <span style="font-size:1.2vh; line-height:1;">-</span>
                    <span style="font-size:1.2vh; line-height:1;">{option.options?.[option.selected]?.label}</span>
                    <span style="font-size:1.2vh; line-height:1;">-</span>
                  </div>
                {/if}
              </div>
            {/if}
          {/each}
        </div>
      </div>
    </div>

    {#if popVisible}
      <div class="player-popout" in:fly={{ x: 16, duration: 160, easing: cubicOut }} out:fade={{ duration: 120 }}>
        <div class="pop-title">{popName} [{popSid}]</div>
        <div class="kv"><span class="label">Distance</span><strong class="value">{(Number(popDist) || 0).toFixed(1)} m</strong></div>
        <div class="kv"><span class="label">Server ID</span><strong class="value">{popSid}</strong></div>
        <div class="kv"><span class="label">Health</span><strong class="health value">{Math.round(Number(popHealth) || 0)}</strong></div>
        <div class="bar"><div class="fill" style={`width:${Math.max(0, Math.min(100, Number(popHealth) || 0))}%;`} /></div>
        <div class="kv"><span class="label">Armour</span><strong class="value">{Math.round(Number(popArmour) || 0)}</strong></div>
        <div class="kv"><span class="label">Weapon</span><strong class="value">{popWeaponName || 'Unknown'}</strong></div>
        <div class="kv"><span class="label">Vehicle</span><strong class="value">{popInVeh ? (popVehicle || 'In Vehicle') : 'On Foot'}</strong></div>
        <div class="kv"><span class="label">Alive</span><strong class="value">{popAlive ? 'Alive' : 'Dead'}</strong></div>
        <div class="kv"><span class="label">Speed</span><strong class="value">{Math.round(Number(popSpeedKmh) || 0)} km/h</strong></div>
        <div class="kv"><span class="label">Visible</span><strong class="value">{popIsVisible ? 'Yes' : 'No'}</strong></div>
        <div class="hint">Open a player entry to Spectate, Inventory, or Go To.</div>
      </div>
    {/if}

    <div class="footer-bar" style="margin-top:.5vh; margin-left:1.75vh; width:90%; background:var(--bg-800); border-radius:.3vh; padding:.8vh .9vh; font-size:1.1vh; color:var(--text); display:flex; justify-content:space-between; align-items:center; box-shadow:0 .3vh 1.2vh rgba(0,0,0,.35);"
         in:fly={{ y: 8, duration: 200, easing: cubicOut }}>
      <span style="color:var(--text); font-weight:500;">Beta | CapTcha @2025</span>
      <span style="color:var(--text); font-weight:500;">({selectableMenu.length ? counterCurrent() : 0}/{selectableMenu.length})</span>
    </div>
  </div>
{/if}

{#if keyPrompt.show}
  <div class="openkey-pop" in:fly={{ x: 12, duration: 140 }} out:fade={{ duration: 120 }}>
    <div class="t">Choose open key</div>
    <div class="v">Current: <strong>{keyPrompt.label}</strong></div>
    <div class="h">Press a key, then Enter to confirm</div>
  </div>
{/if}

{#if spectatorBox.show}
  <div class="spectator-box">
    <div class="spec-title">SPECTATOR</div>
    <div class="spec-count">{Math.max(0, Math.floor(spectatorBox.count || 0))} </div>
  </div>
{/if}

<!-- Notifications (top-center, fade-up on dismiss) -->
<div class="noti-wrap">
  {#each toasts as t (t.id)}
    <div class="noti"
         in:fly={{ y: -12, duration: 180, easing: cubicOut }}
         out:fly={{ y: -12, duration: 180, easing: cubicOut }}>
      <i class={"ph " + (t.icon || 'ph-info') + " icon"} style="color:#cbb7ff;"></i>
      <div class="body">
        <div class="title">{t.title}</div>
        {#if t.message}<div class="msg">{t.message}</div>{/if}
      </div>
      <i class="ph ph-x close" on:click={() => closeToast(t.id)}></i>
    </div>
  {/each}
</div>