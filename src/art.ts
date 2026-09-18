export function icon(name: string, size = 20): string {
  const paths: Record<string, string> = {
    arrow: '<path d="M4 12h15m-6-6 6 6-6 6"/>',
    chevron: '<path d="m9 5 7 7-7 7"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    globe: '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
    wallet: '<rect x="3" y="6" width="18" height="15" rx="3"/><path d="M17 6V3L5 6m16 5h-6v5h6"/><path d="M17 13.5h.01"/>',
    exchange: '<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
    sprout: '<path d="M12 21v-9m0 2C5 14 3 10 3 5c6 0 9 4 9 9Zm0-4c0-5 4-8 9-8 0 5-3 9-9 8Z"/>',
    chart: '<path d="M4 3v17h17M8 15l4-5 4 2 5-7"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    coffee: '<path d="M4 8h13v8a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4Zm13 1h2a3 3 0 0 1 0 6h-2M7 3v2m5-2v2"/>',
    bag: '<path d="M4 8h16l1 13H3L4 8Zm4 0V6a4 4 0 0 1 8 0v2"/>',
    train: '<rect x="5" y="3" width="14" height="16" rx="4"/><path d="M5 11h14M9 7h6M8 19l-2 3m10-3 2 3M8 15h1m6 0h1"/>',
    shield: '<path d="m12 2 8 4v6c0 5-8 10-8 10S4 17 4 12V6l8-4Z"/><path d="m8 12 3 3 5-6"/>',
    heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
    star: '<path d="m12 2 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1 3-6Z"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
    close: '<path d="m6 6 12 12M6 18 18 6"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m3 6 9 7 9-7"/>',
  };
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.star}</svg>`;
}

export const brand = (light = false) => `<a class="brand ${light ? 'brand-light' : ''}" href="#" aria-label="KakeiboPlus home"><img src="/icon.svg" alt="" width="35" height="35"/><span>Kakeibo<span class="brand-plus">Plus</span></span></a>`;

/** Original, replaceable SVG companion. No third-party or Rive artwork. */
export function pet(state = 'idle', className = ''): string {
  return `<svg class="pet pet-${state} ${className}" viewBox="0 0 200 200" role="img" aria-label="Sprout companion, ${state}">
    <ellipse cx="100" cy="179" rx="49" ry="8" fill="#164E3B" opacity=".09"/>
    <path class="pet-leaf" d="M101 66C70 67 58 43 65 25c25-1 40 17 36 41Z" fill="#4BA86D"/>
    <path class="pet-leaf" d="M101 67c-3-30 17-46 39-43 3 23-13 41-39 43Z" fill="#88D344"/>
    <path d="M101 74V46" stroke="#357E46" stroke-width="5" stroke-linecap="round"/>
    <path d="M57 122c-18-4-23 8-13 14l15 3m86-17c18-4 23 8 13 14l-15 3" fill="#85BFA4"/>
    <path d="M74 161c-4 12-3 19 6 19 8 0 11-8 12-14m21-5c4 12 3 19-6 19-8 0-11-8-12-14" fill="#6BAA8D"/>
    <path d="M51 111c0-37 19-53 49-53s50 16 50 53v23c0 29-21 40-50 40s-49-11-49-40Z" fill="#ADD5BE"/>
    <path d="M58 105c0-29 20-43 42-43 21 0 40 12 43 36-22-11-58-9-85 7Z" fill="#C8E5D4" opacity=".65"/>
    ${state === 'sleeping' ? '<path d="m75 116 9 2m32 0 9-2" stroke="#204C3B" stroke-width="3" stroke-linecap="round"/><text x="150" y="74" fill="#47725D" font-family="sans-serif" font-size="18">z z</text>' : state === 'happy' || state === 'celebrate' ? '<path d="M75 116q5-8 10 0m30 0q5-8 10 0" fill="none" stroke="#204C3B" stroke-width="3" stroke-linecap="round"/>' : '<ellipse cx="81" cy="114" rx="3.5" ry="5" fill="#204C3B"/><ellipse cx="119" cy="114" rx="3.5" ry="5" fill="#204C3B"/>'}
    <ellipse cx="69" cy="126" rx="8" ry="4" fill="#EAAD8D" opacity=".7"/><ellipse cx="131" cy="126" rx="8" ry="4" fill="#EAAD8D" opacity=".7"/>
    <path d="M94 127q6 7 12 0" fill="none" stroke="#204C3B" stroke-width="2.5" stroke-linecap="round"/>
    <path d="M90 149h20" stroke="#6BAA8D" stroke-width="3" stroke-linecap="round"/>
    ${state === 'celebrate' ? '<path d="m33 67 3 7 7 2-7 3-3 7-3-7-7-3 7-2Zm126 31 3 7 7 2-7 3-3 7-3-7-7-3 7-2Z" fill="#FFC83D"/>' : ''}
    ${state === 'warning' ? '<circle cx="159" cy="85" r="13" fill="#FFE2A0"/><path d="M159 77v8m0 5v1" stroke="#80591B" stroke-width="3" stroke-linecap="round"/>' : ''}
  </svg>`;
}

export function bars(): string {
  return `<div class="bar-chart" role="img" aria-label="Illustrative weekly spending chart, highest on Thursday">${[40, 64, 48, 88, 56, 73, 43].map((v, i) => `<div><span style="--bar-height:${v}%;--i:${i}" class="${i === 3 ? 'active' : ''}"></span><small>${['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]}</small></div>`).join('')}</div>`;
}
