import { icon } from '../art';
import { marketing } from '../config';
export const cta = (text = 'Start Free', extra = '') => `<button class="button button-primary ${extra}" data-start>${text}${icon('arrow', 18)}</button>`;
export function storeLinks(): string {
  return `<div class="store-links">${[['apple', 'App Store'], ['google', 'Google Play']].map(([key, label]) => {
    const url = marketing.stores[key as keyof typeof marketing.stores];
    return url ? `<a class="store-link" href="${url}" target="_blank" rel="noopener noreferrer">${label}${icon('arrow', 16)}</a>` : `<span class="store-link"><span>${label}</span><small>Coming soon</small></span>`;
  }).join('')}</div>`;
}
