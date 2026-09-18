import './style.css';
import './premium.css';
import { icon } from './art';
import { companion, type PetKind } from './components/companion';
import { mobileScreen } from './components/phone';
import { initProductMotion } from './motion';
import { mountDownloadCounter } from './downloads';
import { formatMoney, currencyLocales, walletAmounts } from './localization';
import { currencies, marketing } from './config';
import { demoFxProvider } from './fx.mjs';
import { renderLanding } from './render';

const app = document.querySelector<HTMLDivElement>('#app')!;
if (!app.hasChildNodes()) app.innerHTML = renderLanding();

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const menu = document.querySelector<HTMLButtonElement>('.menu-toggle')!;
const mobileNav = document.querySelector<HTMLElement>('#mobile-nav')!;
function closeMenu() {
  menu.setAttribute('aria-expanded', 'false');
  menu.setAttribute('aria-label', 'Open menu');
  mobileNav.hidden = true;
  menu.innerHTML = icon('menu');
}
menu.addEventListener('click', () => {
  const open = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(open));
  menu.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  mobileNav.hidden = !open;
  menu.innerHTML = icon(open ? 'close' : 'menu');
});
mobileNav.addEventListener('click', e => { if ((e.target as HTMLElement).closest('a')) closeMenu(); });
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !mobileNav.hidden) { closeMenu(); menu.focus(); } });
document.addEventListener('click', e => { if (!e.composedPath().includes(document.querySelector('.header')!)) closeMenu(); });
window.matchMedia('(min-width: 769px)').addEventListener('change', e => { if (e.matches) closeMenu(); });

const launchDialog = document.querySelector<HTMLDialogElement>('#launch-dialog')!;
document.querySelectorAll('[data-start]').forEach(button => button.addEventListener('click', () => {
  if (marketing.signupUrl) window.location.assign(marketing.signupUrl);
  else launchDialog.showModal();
}));
document.querySelectorAll<HTMLDialogElement>('dialog').forEach(dialog => {
  dialog.querySelectorAll('.dialog-close, .dialog-dismiss').forEach(button => button.addEventListener('click', () => dialog.close()));
  dialog.addEventListener('click', event => {
    const box = dialog.getBoundingClientRect();
    if (event.target === dialog && (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom)) dialog.close();
  });
});

initProductMotion();
void mountDownloadCounter();

const walletExamples: Record<string, [string, string]> = { JPY: ['Japan Wallet', '¥128,450'], USD: ['US Wallet', '$1,250'], INR: ['India Wallet', '₹48,000'], NPR: ['Nepal Wallet', 'रू 240,000'], VND: ['Vietnam Wallet', '₫8,500,000'], KRW: ['Korea Wallet', '₩1,450,000'], EUR: ['Europe Wallet', '€1,180'], SAR: ['Saudi Wallet', '﷼4,680'], LKR: ['Sri Lanka Wallet', 'Rs 125,000'] };
document.querySelectorAll<HTMLButtonElement>('[data-currency]').forEach(button => button.addEventListener('click', () => {
  const currency = currencies.find(c => c.code === button.dataset.currency)!;
  document.querySelector('#wallet-flag')!.textContent = currency.flag;
  document.querySelector('#wallet-code')!.textContent = currency.code;
  document.querySelector('#wallet-name')!.textContent = walletExamples[currency.code][0];
  document.querySelector('#wallet-amount')!.textContent = formatMoney(walletAmounts[currency.code], currency.code, currencyLocales[currency.code]);
  document.querySelectorAll<HTMLButtonElement>('[data-currency]').forEach(b => { b.classList.toggle('active', b === button); b.setAttribute('aria-pressed', String(b === button)); });
  if (!reducedMotion.matches) document.querySelector('.wallet-japan')!.animate([{ transform: 'translateY(0)' }, { transform: 'translateY(-8px)' }, { transform: 'translateY(0)' }], { duration: 320 });
}));

const amount = document.querySelector<HTMLInputElement>('#fx-amount')!;
const from = document.querySelector<HTMLSelectElement>('#fx-from')!;
const to = document.querySelector<HTMLSelectElement>('#fx-to')!;
const result = document.querySelector<HTMLOutputElement>('#fx-result')!;
let quoteSequence = 0;
async function updateFx() {
  const sequence = ++quoteSequence;
  const error = document.querySelector('#fx-error')!;
  document.querySelectorAll<HTMLButtonElement>('[data-pair]').forEach(b => {
    const active = b.dataset.pair === `${from.value},${to.value}`;
    b.classList.toggle('active', active);
    b.setAttribute('aria-pressed', String(active));
  });
  if (!amount.value || !amount.validity.valid || !Number.isFinite(amount.valueAsNumber)) {
    result.textContent = '—';
    error.textContent = 'Enter an amount from 0 to 1 trillion.';
    amount.setAttribute('aria-invalid', 'true');
    return;
  }
  error.textContent = '';
  amount.removeAttribute('aria-invalid');
  try {
    const quote = await demoFxProvider.quote(amount.valueAsNumber, from.value, to.value);
    if (sequence !== quoteSequence) return;
    result.textContent = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2, minimumFractionDigits: 2 }).format(quote.amount);
    document.querySelector('#fx-disclaimer')!.textContent = quote.source;
    if (!reducedMotion.matches) result.animate([{ opacity: .3 }, { opacity: 1 }], { duration: 250 });
  } catch {
    if (sequence !== quoteSequence) return;
    result.textContent = '—';
    error.textContent = 'Conversion is unavailable. Please try again.';
  }
}
amount.addEventListener('input', updateFx);
from.addEventListener('change', updateFx);
to.addEventListener('change', updateFx);
document.querySelector('#fx-swap')!.addEventListener('click', () => { [from.value, to.value] = [to.value, from.value]; void updateFx(); });
document.querySelectorAll<HTMLButtonElement>('[data-pair]').forEach(button => button.addEventListener('click', () => {
  [from.value, to.value] = button.dataset.pair!.split(',');
  void updateFx();
}));

let companionKind: PetKind = 'dog';
const message = document.querySelector('#pet-message')!;
const actions = document.querySelector('#pet-actions')!;
function setPetState(state: string) {
  document.dispatchEvent(new Event('companion-interaction'));
  document.querySelector('#main-pet')!.innerHTML = companion(companionKind, state);
  document.querySelectorAll<HTMLButtonElement>('[data-pet-state]').forEach(b => { b.classList.toggle('active', b.dataset.petState === state); b.setAttribute('aria-pressed', String(b.dataset.petState === state)); });
}
document.querySelectorAll<HTMLButtonElement>('[data-companion-kind]').forEach(button => button.addEventListener('click', () => {
  companionKind = button.dataset.companionKind as PetKind;
  document.querySelectorAll<HTMLButtonElement>('[data-companion-kind]').forEach(b => b.setAttribute('aria-pressed', String(b === button)));
  petReset();
}));
function petReset() {
  message.textContent = 'Did you buy anything today?';
  actions.innerHTML = `<button data-pet-action="yes">Yes, I did ${icon('arrow', 14)}</button><button data-pet-action="no">Not today</button>`;
  setPetState('idle');
}
const expenseDialog = document.querySelector<HTMLDialogElement>('#expense-dialog')!;
actions.addEventListener('click', e => {
  const action = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-pet-action]')?.dataset.petAction;
  if (!action) return;
  if (action === 'yes') {
    message.textContent = 'Want to record it? Every little moment counts.';
    actions.innerHTML = `<button data-pet-action="add">Add expense ${icon('plus', 14)}</button><button data-pet-action="later">Later</button>`;
    setPetState('happy');
  } else if (action === 'add') expenseDialog.showModal();
  else if (action === 'reset') petReset();
  else {
    message.textContent = action === 'no' ? 'Thanks for checking in. That’s a good habit, too!' : 'Whenever you’re ready. I’ll be right here.';
    actions.innerHTML = '<button data-pet-action="reset">Try again ↻</button>';
    setPetState(action === 'no' ? 'happy' : 'idle');
  }
  if (action !== 'add') actions.querySelector<HTMLButtonElement>('button')?.focus({ preventScroll: true });
});
const stateMessages: Record<string, string> = { idle: 'Did you buy anything today?', happy: 'You made time for your money. Nicely done!', celebrate: 'Another expense recorded. Your habit is growing!', warning: 'A little reminder: take a moment to review your budget.', sleeping: 'Time to rest. Your goals will be here tomorrow.' };
document.querySelectorAll<HTMLButtonElement>('[data-pet-state]').forEach(button => button.addEventListener('click', () => {
  const state = button.dataset.petState!;
  setPetState(state);
  message.textContent = stateMessages[state];
  actions.innerHTML = '<button data-pet-action="reset">Try the check-in ↻</button>';
}));
document.querySelector<HTMLFormElement>('#expense-form')!.addEventListener('submit', e => {
  e.preventDefault();
  const form = e.currentTarget as HTMLFormElement;
  if (!form.reportValidity()) return;
  const values = new FormData(form);
  message.textContent = `${values.get('name')} — ¥${Number(values.get('amount')).toLocaleString('en-US')} recorded in this demo. Small step, good habit!`;
  actions.innerHTML = '<button data-pet-action="reset">Try again ↻</button>';
  setPetState('celebrate');
  expenseDialog.close();
  actions.querySelector<HTMLButtonElement>('button')?.focus({ preventScroll: true });
  form.reset();
});

const tabs = [...document.querySelectorAll<HTMLButtonElement>('[data-feature]')];
function selectFeature(button: HTMLButtonElement) {
  tabs.forEach(b => { b.setAttribute('aria-selected', String(b === button)); b.tabIndex = b === button ? 0 : -1; });
  const panel = document.querySelector('#feature-panel')!;
  document.querySelector('#showcase-center')!.innerHTML = mobileScreen(button.dataset.feature!);
  panel.setAttribute('aria-labelledby', button.id);
}
tabs.forEach((button, index) => {
  button.addEventListener('click', () => selectFeature(button));
  button.addEventListener('keydown', e => {
    let target = index;
    if (e.key === 'ArrowRight') target = (index + 1) % tabs.length;
    else if (e.key === 'ArrowLeft') target = (index - 1 + tabs.length) % tabs.length;
    else if (e.key === 'Home') target = 0;
    else if (e.key === 'End') target = tabs.length - 1;
    else return;
    e.preventDefault();
    selectFeature(tabs[target]);
    tabs[target].focus();
  });
});

if ('IntersectionObserver' in window && !reducedMotion.matches) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('revealed'); observer.unobserve(entry.target); } });
  }, { threshold: .08 });
  document.querySelectorAll('.reveal').forEach(el => { el.classList.add('will-reveal'); observer.observe(el); });
}
document.documentElement.dataset.enhanced = 'true';

