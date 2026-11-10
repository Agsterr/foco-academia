// Monta as imagens da Play Store: capturas reais do app dentro de um celular, com fundo e frase.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const SHOTS = process.argv[2];
const OUT = process.argv[3];
const FONTS = process.argv[4];
fs.mkdirSync(OUT, { recursive: true });

const slides = [
  ['01_inicio', 'Seu treino do dia<br>num toque', 'Calorias, km e tudo que você precisa na tela inicial', 'linear-gradient(160deg,#7C5CFF 0%,#C04DFF 50%,#FF4D9D 100%)'],
  ['02_ficha', 'A ficha da semana<br>na palma da mão', 'Montada pelo seu instrutor, com cada dia colorido', 'linear-gradient(160deg,#FF4D5E 0%,#FF7A1A 55%,#FFB020 100%)'],
  ['03_treino', 'Marque cada série<br>e veja o progresso', 'Cronômetro, calorias e comemoração no final', 'linear-gradient(160deg,#FF7A1A 0%,#FF4D9D 100%)'],
  ['04_treinos_prontos', 'Treinos prontos<br>para todo nível', 'Musculação, corrida, spinning e bike', 'linear-gradient(160deg,#14D2C4 0%,#22D97A 55%,#B4F02B 100%)'],
  ['05_painel_academia', 'Sua academia<br>em números', 'Alunos ativos, notas, recados e gráficos', 'linear-gradient(160deg,#5B3DF5 0%,#3D8BFF 100%)'],
  ['06_alunos', 'Acompanhe cada<br>aluno de perto', 'Veja quem está treinando e quem sumiu', 'linear-gradient(160deg,#3D8BFF 0%,#22C7F5 100%)'],
  ['07_convite', 'Convide alunos<br>com um link', 'A conta já vem pronta e fica em um só aparelho', 'linear-gradient(160deg,#22D97A 0%,#14D2C4 100%)'],
  ['10_cadastro', 'Aluno, personal<br>ou academia', 'Um app só para treinar e para gerenciar', 'linear-gradient(160deg,#FF4D9D 0%,#8B5CF6 100%)'],
];

const fontFace = ['Regular:400', 'SemiBold:600', 'Bold:700', 'ExtraBold:800']
  .map((s) => {
    const [n, w] = s.split(':');
    return `@font-face{font-family:Poppins;font-weight:${w};src:url('file://${FONTS}/Poppins-${n}.ttf')}`;
  })
  .join('\n');

function slideHtml(img, title, sub, bg) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${fontFace}
*{margin:0;padding:0;box-sizing:border-box}
body{width:1080px;height:1920px;overflow:hidden;font-family:Poppins;background:${bg};position:relative;color:#fff}
.blob{position:absolute;border-radius:50%;background:rgba(255,255,255,.14)}
.title{position:absolute;top:110px;left:0;right:0;text-align:center;font-size:84px;font-weight:800;line-height:1.08;letter-spacing:-2px;text-shadow:0 6px 30px rgba(0,0,0,.18)}
.sub{position:absolute;top:330px;left:90px;right:90px;text-align:center;font-size:38px;font-weight:600;opacity:.95;line-height:1.3}
.phone{position:absolute;left:50%;top:500px;transform:translateX(-50%);width:760px;height:1352px;border-radius:84px;background:#0B0A1A;padding:22px;box-shadow:0 40px 90px rgba(0,0,0,.45),0 0 0 6px rgba(255,255,255,.25)}
.screen{width:100%;height:100%;border-radius:64px;overflow:hidden;background:#0B0A1A}
.screen img{width:100%;display:block}
.status{height:64px;display:flex;align-items:center;justify-content:space-between;padding:6px 46px 0;font-size:24px;font-weight:600;background:#0B0A1A}
.status .icons{display:flex;gap:10px;align-items:center}
.status .bat{width:38px;height:18px;border:2.5px solid #fff;border-radius:5px;padding:2px}
.status .bat i{display:block;width:75%;height:100%;background:#fff;border-radius:2px}
.notch{position:absolute;top:40px;left:50%;transform:translateX(-50%);width:34px;height:34px;border-radius:50%;background:#000;box-shadow:0 0 0 4px #15142B}
</style></head><body>
<div class="blob" style="width:520px;height:520px;top:-180px;right:-160px"></div>
<div class="blob" style="width:420px;height:420px;bottom:180px;left:-220px;opacity:.6"></div>
<div class="title">${title}</div>
<div class="sub">${sub}</div>
<div class="phone"><div class="screen"><div class="status"><span>9:41</span><span class="icons"><svg width="26" height="20" viewBox="0 0 24 18" fill="#fff"><path d="M12 3C7.8 3 4 4.6 1 7.3L12 18 23 7.3C20 4.6 16.2 3 12 3z"/></svg><svg width="22" height="20" viewBox="0 0 22 20" fill="#fff"><rect x="0" y="14" width="4" height="6" rx="1"/><rect x="6" y="10" width="4" height="10" rx="1"/><rect x="12" y="5" width="4" height="15" rx="1"/><rect x="18" y="0" width="4" height="20" rx="1"/></svg><span class="bat"><i></i></span></span></div><img src="file://${img}"></div><div class="notch"></div></div>
</body></html>`;
}

function featureHtml(left, right) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${fontFace}
*{margin:0;padding:0;box-sizing:border-box}
body{width:1024px;height:500px;overflow:hidden;font-family:Poppins;color:#fff;position:relative;
background:linear-gradient(120deg,#5B3DF5 0%,#C04DFF 45%,#FF4D9D 75%,#FF7A1A 100%)}
.blob{position:absolute;border-radius:50%;background:rgba(255,255,255,.14)}
.logo{position:absolute;left:64px;top:92px;width:96px;height:96px;border-radius:30px;background:rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center}
.logo svg{width:60px;height:60px}
.name{position:absolute;left:64px;top:216px;font-size:54px;font-weight:800;letter-spacing:-1.5px;line-height:1}
.tag{position:absolute;left:66px;top:296px;width:470px;font-size:25px;font-weight:600;line-height:1.35;opacity:.97}
.phone{position:absolute;width:250px;height:445px;border-radius:36px;background:#0B0A1A;padding:9px;box-shadow:0 24px 50px rgba(0,0,0,.45),0 0 0 3px rgba(255,255,255,.3)}
.phone div{width:100%;height:100%;border-radius:28px;overflow:hidden}
.phone img{width:100%;display:block}
</style></head><body>
<div class="blob" style="width:420px;height:420px;top:-200px;left:300px"></div>
<div class="blob" style="width:300px;height:300px;bottom:-160px;left:-80px;opacity:.6"></div>
<div class="logo"><svg viewBox="0 0 24 24" fill="#fff"><path d="M20.57 14.86L22 13.43 20.57 12 17 15.57 8.43 7 12 3.43 10.57 2 9.14 3.43 7.71 2 5.57 4.14 4.14 2.71 2.71 4.14l1.43 1.43L2 7.71l1.43 1.43L2 10.57 3.43 12 7 8.43 15.57 17 12 20.57 13.43 22l1.43-1.43L16.29 22l2.14-2.14 1.43 1.43 1.43-1.43-1.43-1.43L22 16.29z"/></svg></div>
<div class="name">Foco Academia</div>
<div class="tag">Treinos, corrida e evolução para alunos. Painel completo para academias e personais.</div>
<div class="phone" style="left:580px;top:70px;transform:rotate(-6deg)"><div><img src="file://${left}"></div></div>
<div class="phone" style="left:770px;top:40px;transform:rotate(5deg)"><div><img src="file://${right}"></div></div>
</body></html>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  for (const [i, [name, title, sub, bg]] of slides.entries()) {
    const html = path.join(OUT, `_slide.html`);
    fs.writeFileSync(html, slideHtml(path.join(SHOTS, `${name}.png`), title, sub, bg));
    await page.goto('file://' + html);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(OUT, `celular_${String(i + 1).padStart(2, '0')}_${name.replace(/^\d+_/, '')}.png`) });
  }
  await page.setViewportSize({ width: 1024, height: 500 });
  const html = path.join(OUT, `_feature.html`);
  fs.writeFileSync(html, featureHtml(path.join(SHOTS, '01_inicio.png'), path.join(SHOTS, '05_painel_academia.png')));
  await page.goto('file://' + html);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(150);
  await page.screenshot({ path: path.join(OUT, 'banner_1024x500.png') });
  fs.rmSync(path.join(OUT, '_slide.html'));
  fs.rmSync(path.join(OUT, '_feature.html'));
  await browser.close();
})();
