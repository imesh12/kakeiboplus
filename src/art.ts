import { companion } from "./components/companion";
export function icon(name: string, size = 20): string {
  const paths: Record<string, string> = {
    arrow: '<path d="M4 12h15m-6-6 6 6-6 6"/>',
    chevron: '<path d="m9 5 7 7-7 7"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    globe:
      '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
    wallet:
      '<rect x="3" y="6" width="18" height="15" rx="3"/><path d="M17 6V3L5 6m16 5h-6v5h6"/><path d="M17 13.5h.01"/>',
    exchange: '<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
    sprout:
      '<path d="M12 21v-9m0 2C5 14 3 10 3 5c6 0 9 4 9 9Zm0-4c0-5 4-8 9-8 0 5-3 9-9 8Z"/>',
    chart: '<path d="M4 3v17h17M8 15l4-5 4 2 5-7"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    coffee:
      '<path d="M4 8h13v8a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4Zm13 1h2a3 3 0 0 1 0 6h-2M7 3v2m5-2v2"/>',
    bag: '<path d="M4 8h16l1 13H3L4 8Zm4 0V6a4 4 0 0 1 8 0v2"/>',
    train:
      '<rect x="5" y="3" width="14" height="16" rx="4"/><path d="M5 11h14M9 7h6M8 19l-2 3m10-3 2 3M8 15h1m6 0h1"/>',
    shield:
      '<path d="m12 2 8 4v6c0 5-8 10-8 10S4 17 4 12V6l8-4Z"/><path d="m8 12 3 3 5-6"/>',
    heart:
      '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
    star: '<path d="m12 2 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1 3-6Z"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
    close: '<path d="m6 6 12 12M6 18 18 6"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m3 6 9 7 9-7"/>',
  };
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.star}</svg>`;
}

export const brand = (light = false) =>
  `<a class="brand ${light ? "brand-light" : ""}" href="#" aria-label="KakeiboPlus home"><img src="/icon.svg" alt="" width="35" height="35"/><span>Kakeibo<span class="brand-plus">Plus</span></span></a>`;

export function pet(state = "idle"): string {
  return companion("dog", state);
}

export function bars(): string {
  return `<div class="bar-chart" role="img" aria-label="Illustrative weekly spending chart, highest on Thursday">${[40, 64, 48, 88, 56, 73, 43].map((v, i) => `<div><span style="--bar-height:${v}%;--i:${i}" class="${i === 3 ? "active" : ""}"></span><small>${["M", "T", "W", "T", "F", "S", "S"][i]}</small></div>`).join("")}</div>`;
}
