import { languageProfile, type PhoneLabel } from './localization';
import { canAdvanceLocale, createPetScheduler } from './motion-policy.mjs';
import { languageProfiles } from './localization';

/** Progressive enhancement only: all screens and labels exist in static HTML. */
export function initProductMotion() {
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const hero = document.querySelector<HTMLElement>('.hero')!;
  const selector = document.querySelector<HTMLSelectElement>('#hero-language')!;
  const toggle = document.querySelector<HTMLButtonElement>('#motion-toggle')!;
  const phone = document.querySelector<HTMLElement>('[data-phone="hero"]')!;
  const gallery = document.querySelector<HTMLElement>('.phone-gallery')!;
  const scenes = [...document.querySelectorAll<HTMLElement>('[data-scene]')];
  const visible = new Set<Element>();
  const scheduler = createPetScheduler();
  const started = performance.now();
  let manuallyPausedUntil = 0;
  let lastChange = performance.now();
  let paused = false;
  let activeScene: HTMLElement | null = null;
  let motionTimer: number | undefined;
  let frame = 0;
  let sceneAnimations: Animation[] = [];

  function animateText(el: Element, index: number) {
    if (reduced.matches || paused || document.hidden) return;
    el.getAnimations().forEach(a => a.cancel());
    el.animate([{ opacity: .35, transform: 'translateY(4px)', filter: 'blur(1px)' }, { opacity: 1, transform: 'translateY(0)', filter: 'blur(0)' }], { duration: 340, delay: Math.min(index * 12, 160), easing: 'cubic-bezier(.2,.7,.2,1)' });
  }
  function updatePhone(root: HTMLElement, code: string, animate = true) {
    const profile = languageProfile(code);
    root.lang = profile.code;
    root.dir = profile.dir;
    root.querySelectorAll<HTMLElement>('[data-phone-label]').forEach((el, index) => {
      el.textContent = profile.labels[el.dataset.phoneLabel as PhoneLabel];
      if (animate) animateText(el, index);
    });
    root.querySelectorAll<HTMLElement>('[data-phone-money]').forEach((el, index) => {
      const currency = el.dataset.moneyCurrency!;
      el.textContent = new Intl.NumberFormat(profile.locale, { style: 'currency', currency, currencyDisplay: 'narrowSymbol', maximumFractionDigits: currency === 'USD' ? 2 : 0 }).format(Number(el.dataset.phoneMoney));
      if (animate) animateText(el, index + 1);
    });
  }
  function selectLanguage(code: string, manual: boolean, updateSection = true) {
    const profile = languageProfile(code);
    selector.value = profile.code;
    updatePhone(phone, profile.code, visible.has(hero));
    document.querySelector('.locale-readiness')!.textContent = `${profile.readiness[0].toUpperCase() + profile.readiness.slice(1)} language preview`;
    lastChange = performance.now();
    if (manual) manuallyPausedUntil = lastChange + 30000;
    if (updateSection) {
      const preview = document.querySelector<HTMLElement>('#language-preview')!;
      preview.dir = profile.dir;
      preview.lang = profile.code;
      updatePhone(preview.querySelector<HTMLElement>('[data-phone]')!, code, visible.has(preview.closest('section')!));
      document.querySelector('#language-current')!.textContent = profile.name;
      document.querySelector('.preview-lang')!.textContent = profile.code.toUpperCase();
      document.querySelectorAll<HTMLButtonElement>('[data-language]').forEach(b => { b.classList.toggle('active', b.dataset.language === code); b.setAttribute('aria-pressed', String(b.dataset.language === code)); });
      document.querySelector<HTMLSelectElement>('#footer-language')!.value = code;
    }
    updateAutoState();
  }
  function updateAutoState() {
    const state = reduced.matches ? 'reduced' : paused ? 'paused' : document.hidden || !visible.has(hero) ? 'offscreen' : performance.now() < manuallyPausedUntil ? 'manual' : 'playing';
    hero.dataset.autoState = state;
    document.documentElement.dataset.motion = reduced.matches || paused || document.hidden ? 'paused' : 'active';
    toggle.disabled = reduced.matches;
    toggle.setAttribute('aria-pressed', String(paused));
    toggle.setAttribute('aria-label', paused ? 'Resume automatic motion' : 'Pause automatic motion');
    toggle.querySelector('span')!.textContent = reduced.matches ? 'Reduced motion' : paused ? 'Resume motion' : 'Pause motion';
  }
  function stopScene() {
    sceneAnimations.forEach(a => a.cancel());
    sceneAnimations = [];
    if (activeScene) activeScene.dataset.action = 'rest';
    activeScene = null;
  }
  function playScene(scene: HTMLElement) {
    stopScene();
    activeScene = scene;
    const story = scene.dataset.story;
    scene.dataset.action = story || 'point';
    const actor = scene.querySelector('.story-animal')!;
    const money = scene.querySelector('.story-money')!;
    const short = matchMedia('(max-width: 768px)').matches;
    const distance = short ? 28 : 72;
    const path = story === 'peek'
      ? [{ transform: 'translateY(28px)', opacity: 0 }, { transform: 'translateY(0)', opacity: 1, offset: .25 }, { transform: 'translateY(0) rotate(-5deg)', opacity: 1, offset: .65 }, { transform: 'translateY(28px)', opacity: 0 }]
      : [{ transform: 'translateX(0)', opacity: 0 }, { transform: 'translateX(0)', opacity: 1, offset: .15 }, { transform: `translateX(${distance}px) translateY(-3px)`, opacity: 1, offset: .48 }, { transform: `translateX(${distance}px) translateY(-9px)`, opacity: 1, offset: .58 }, { transform: `translateX(${distance}px) translateY(0)`, opacity: 1, offset: .68 }, { transform: `translateX(${distance}px)`, opacity: 0 }];
    sceneAnimations.push(actor.animate(path, { duration: 7000, easing: 'ease-in-out', fill: 'both' }));
    if (story === 'catch' || story === 'push') sceneAnimations.push(money.animate([{ opacity: 0, transform: 'translateX(25px) rotate(-8deg)' }, { opacity: 1, transform: 'translateX(40px) rotate(6deg)', offset: .2 }, { opacity: 1, transform: `translateX(${distance + 15}px) rotate(-8deg)`, offset: .5 }, { opacity: 0, transform: `translateX(${distance}px) scale(.6)`, offset: .65 }, { opacity: 0 }], { duration: 7000, easing: 'ease-in-out', fill: 'both' }));
  }
  function tick() {
    const now = performance.now();
    const focused = hero.contains(document.activeElement) || !!document.querySelector('dialog[open]');
    if (canAdvanceLocale({ now, lastChange, pausedUntil: manuallyPausedUntil, visible: visible.has(hero), hidden: document.hidden, reduced: reduced.matches, paused, focused })) {
      const index = languageProfiles.findIndex(l => l.code === selector.value);
      selectLanguage(languageProfiles[(index + 1) % languageProfiles.length].code, false, false);
    }
    const eligible = scenes.filter(scene => visible.has(scene.closest('section')!)).map(scene => scene.dataset.scene!);
    const action = scheduler.tick(now - started, eligible, paused || reduced.matches || document.hidden || !!document.querySelector('dialog[open]'));
    if (action && activeScene?.dataset.scene !== action.id) playScene(scenes.find(s => s.dataset.scene === action.id)!);
    else if (!action && activeScene) stopScene();
    updateAutoState();
    if (!document.hidden) motionTimer = window.setTimeout(tick, 1000);
  }
  function updateGallery() {
    frame = 0;
    if (!visible.has(gallery.closest('section')!) || reduced.matches || paused || document.hidden) return;
    const rect = gallery.getBoundingClientRect();
    const progress = Math.max(0, Math.min(1, (innerHeight - rect.top) / (innerHeight * .75)));
    gallery.style.setProperty('--fan', String(progress));
  }
  function requestGallery() { if (!frame && !document.hidden) frame = requestAnimationFrame(updateGallery); }
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) visible.add(entry.target); else visible.delete(entry.target);
      (entry.target as HTMLElement).dataset.inview = String(entry.isIntersecting);
      if (!entry.isIntersecting) entry.target.getAnimations({ subtree: true }).filter(a => !('animationName' in a)).forEach(a => a.cancel());
    }
    if (activeScene && !visible.has(activeScene.closest('section')!)) { stopScene(); scheduler.defer(performance.now() - started); }
    updateAutoState();
    requestGallery();
  }, { threshold: .08 });
  document.querySelectorAll('main > section').forEach(section => observer.observe(section));
  selector.addEventListener('change', () => selectLanguage(selector.value, true));
  document.querySelectorAll<HTMLButtonElement>('[data-language]').forEach(b => b.addEventListener('click', () => selectLanguage(b.dataset.language!, true)));
  document.querySelector<HTMLSelectElement>('#footer-language')!.addEventListener('change', e => {
    selectLanguage((e.target as HTMLSelectElement).value, true);
    document.querySelector('#languages')!.scrollIntoView({ behavior: reduced.matches || paused ? 'instant' : 'smooth' });
  });
  const suspend = () => {
    window.clearTimeout(motionTimer);
    stopScene();
    scheduler.defer(performance.now() - started);
    document.getAnimations().filter(a => !('animationName' in a)).forEach(a => a.cancel());
    updateAutoState();
    if (!document.hidden) tick();
  };
  toggle.addEventListener('click', () => { paused = !paused; suspend(); });
  reduced.addEventListener('change', suspend);
  document.addEventListener('visibilitychange', suspend);
  document.addEventListener('companion-interaction', () => { stopScene(); scheduler.defer(performance.now() - started); });
  window.addEventListener('scroll', requestGallery, { passive: true });
  window.addEventListener('resize', requestGallery, { passive: true });
  updateAutoState();
  tick();
}
