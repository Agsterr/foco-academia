// Ícone do Foco Academia: haltere branco sobre o gradiente da marca.
const { chromium } = require('playwright');
const OUT = process.argv[2];
const S = 1024;
const DUMBBELL = 'M20.57 14.86L22 13.43 20.57 12 17 15.57 8.43 7 12 3.43 10.57 2 9.14 3.43 7.71 2 5.57 4.14 4.14 2.71 2.71 4.14l1.43 1.43L2 7.71l1.43 1.43L2 10.57 3.43 12 7 8.43 15.57 17 12 20.57 13.43 22l1.43-1.43L16.29 22l2.14-2.14 1.43 1.43 1.43-1.43-1.43-1.43L22 16.29z';

const background = `
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7C5CFF"/>
      <stop offset="0.5" stop-color="#C04DFF"/>
      <stop offset="1" stop-color="#FF4D9D"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.78" cy="0.18" r="0.55">
      <stop offset="0" stop-color="#fff" stop-opacity="0.32"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="warm" cx="0.15" cy="0.95" r="0.6">
      <stop offset="0" stop-color="#FF7A1A" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#FF7A1A" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${S}" height="${S}" fill="url(#g)"/>
  <rect width="${S}" height="${S}" fill="url(#warm)"/>
  <rect width="${S}" height="${S}" fill="url(#glow)"/>`;

// Haltere desenhado à mão (barra + anilhas arredondadas), inclinado a -45°.
// scale = 1 ocupa ~0,72 do lado do ícone na diagonal.
function dumbbell(scale) {
  const c = S / 2;
  const u = S * scale; // unidade de desenho
  const r = (x, w, h) =>
    `<rect x="${c + x - w / 2}" y="${c - h / 2}" width="${w}" height="${h}" rx="${Math.min(w, h) * 0.38}"/>`;
  const parts = [
    r(0, u * 0.62, u * 0.075),                 // barra
    r(-u * 0.20, u * 0.10, u * 0.46), r(u * 0.20, u * 0.10, u * 0.46),   // anilhas grandes
    r(-u * 0.315, u * 0.085, u * 0.32), r(u * 0.315, u * 0.085, u * 0.32), // anilhas menores
    r(-u * 0.405, u * 0.05, u * 0.12), r(u * 0.405, u * 0.05, u * 0.12),   // pontas
  ].join('');
  return `
  <defs><filter id="sh" x="-30%" y="-30%" width="160%" height="160%" color-interpolation-filters="sRGB">
    <feDropShadow dx="0" dy="${S * 0.014}" stdDeviation="${S * 0.02}" flood-color="#3B0B7A" flood-opacity="0.45"/>
  </filter></defs>
  <g filter="url(#sh)" fill="#fff" transform="rotate(-45 ${c} ${c})">${parts}</g>`;
}

const svg = (body, rounded) => `<!doctype html><html><body style="margin:0;background:transparent">
<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
${rounded ? `<clipPath id="r"><rect width="${S}" height="${S}" rx="${S * 0.225}"/></clipPath><g clip-path="url(#r)">${body}</g>` : body}
</svg></body></html>`;

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: S, height: S } });
  const shots = [
    ['icone_play_store_full', svg(background + dumbbell(0.86), false)],   // Play Store (a loja arredonda sozinha)
    ['legacy_rounded', svg(background + dumbbell(0.92), true)],           // ícone antigo (Android < 8)
    ['adaptive_background', svg(background, false)],                       // camada de fundo
    ['adaptive_foreground', svg(dumbbell(0.66), false)],                   // camada da frente (zona segura 66/108)
  ];
  for (const [name, html] of shots) {
    await p.setContent(html);
    await p.screenshot({ path: `${OUT}/${name}.png`, omitBackground: true, clip: { x: 0, y: 0, width: S, height: S } });
  }
  await b.close();
})();
