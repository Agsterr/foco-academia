// Ícone do Foco Academia: "F" neon (azul → violeta → rosa) com ponto verde-limão sobre fundo escuro.
// Gera o ícone da Play Store e as camadas do ícone adaptável do Android.
//   node make_icon.js <pasta de saída>
const { chromium } = require('playwright');
const OUT = process.argv[2];
const S = 1024;

const defs = `
  <radialGradient id="bg" cx="0.5" cy="0.42" r="0.75"><stop offset="0" stop-color="#2A1460"/><stop offset="1" stop-color="#0B0A1A"/></radialGradient>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%" color-interpolation-filters="sRGB">
    <feGaussianBlur in="SourceGraphic" stdDeviation="38" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>`;

// Desenho original (caixa x 300–822, y 215–815); k = escala em volta do centro do ícone.
function mark(k, { glow = true, mono = false } = {}) {
  const fill = mono ? '#fff' : 'url(#neonG)';
  const dot = mono ? '#fff' : '#B4F02B';
  return `
  <linearGradient id="neonG" gradientUnits="userSpaceOnUse" x1="300" y1="215" x2="760" y2="815">
    <stop offset="0" stop-color="#22D3EE"/><stop offset="0.5" stop-color="#8B5CF6"/><stop offset="1" stop-color="#FF4D9D"/>
  </linearGradient>
  <g transform="translate(512 512) scale(${k}) translate(-561 -515)">
    <g ${glow ? 'filter="url(#glow)"' : ''} fill="${fill}">
      <rect x="300" y="215" width="150" height="600" rx="75"/>
      <rect x="300" y="215" width="440" height="150" rx="75"/>
      <rect x="300" y="450" width="350" height="140" rx="70"/>
    </g>
    <circle cx="760" cy="740" r="62" fill="${dot}" ${glow ? 'filter="url(#glow)"' : ''}/>
  </g>`;
}

const bg = `<rect width="${S}" height="${S}" fill="url(#bg)"/>`;
const page = (body, rounded) => `<!doctype html><html><body style="margin:0;background:transparent">
<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}"><defs>${defs}</defs>
${rounded ? `<clipPath id="r"><rect width="${S}" height="${S}" rx="${S * 0.225}"/></clipPath><g clip-path="url(#r)">${body}</g>` : body}
</svg></body></html>`;

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: S, height: S } });
  const shots = [
    ['icone_play_store_full', page(bg + mark(1.0), false)], // a loja arredonda sozinha
    ['legacy_rounded', page(bg + mark(0.96), true)],         // Android < 8
    ['adaptive_background', page(bg, false)],
    ['adaptive_foreground', page(mark(0.66), false)],        // zona segura: 66 de 108 dp
    ['adaptive_monochrome', page(mark(0.66, { glow: false, mono: true }), false)],
  ];
  for (const [name, html] of shots) {
    await p.setContent(html);
    await p.screenshot({ path: `${OUT}/${name}.png`, omitBackground: true, clip: { x: 0, y: 0, width: S, height: S } });
  }
  await b.close();
})();
