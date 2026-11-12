# Regras para agentes neste repositório

## Sempre veja as telas (regra do dono, vale para todos os agentes)

Qualquer mudança que afete o que o usuário vê (app Flutter, PWAs `aluno`/`instrutor`/`admin`,
imagens e textos da loja ou do site) só está pronta depois que você **olhou a tela renderizada**.
Teste passando e `flutter analyze` limpo não bastam: já houve estouro de layout, figura cortada e
título sobreposto que só apareceram na imagem.

- Renderize e abra a imagem (ferramenta de leitura de imagens) antes de dizer que terminou.
- Confira: texto cortado ou sobreposto, `overflow`, elementos fora da tela, contraste, tema escuro,
  telas estreitas (360 dp) e a tela vazia e a cheia.
- **App Flutter:** use o teste de capturas, que renderiza as telas reais com as fontes de verdade:
  ```bash
  cd mobile
  flutter test test/play_store_screenshots_test.dart \
    --dart-define=FONT_DIR=$(dirname $(which flutter))/cache/artifacts/material_fonts \
    --dart-define=SHOTS_DIR=<pasta fora do repositório> --dart-define=PLAY_SCREENSHOTS=true
  ```
  Tela nova? Acrescente uma captura nesse teste e olhe o PNG gerado.
- **Web (PWAs e site):** suba o app local e tire captura com Playwright (Chromium já instalado).
- Mudou algo visual que também aparece na loja ou no site? Refaça as imagens (`docs/play-store/README.md`).
- No relatório final, diga o que você viu e, se não conseguiu ver a tela, diga isso em vez de
  afirmar que está certo.
