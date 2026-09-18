import { createServer } from 'vite';
import { readFile, writeFile } from 'node:fs/promises';

const server = await createServer({ server: { middlewareMode: true }, appType: 'custom' });
try {
  const { renderLanding } = await server.ssrLoadModule('/src/render.ts');
  const path = new URL('../dist/index.html', import.meta.url);
  let html = await readFile(path, 'utf8');
  html = html.replace('<div id="app"></div>', `<div id="app">${renderLanding()}</div>`);
  if (process.env.SITE_URL) {
    const origin = new URL(process.env.SITE_URL).origin;
    html = html.replaceAll('content="/social-card.svg"', `content="${origin}/social-card.svg"`);
    html = html.replace('</head>', `<link rel="canonical" href="${origin}/" /><meta property="og:url" content="${origin}/" /></head>`);
  }
  await writeFile(path, html);
  console.log('Pre-rendered landing HTML for SEO and immediate first paint.');
} finally {
  await server.close();
}

