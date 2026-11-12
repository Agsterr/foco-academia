# Imagens da Play Store

Prontas para enviar em **Play Console → Presença na loja → Página principal da loja**.

| Arquivo | Onde vai |
|---|---|
| `celular_01_inicio.png` … `celular_08_cadastro.png` | Capturas de tela do **telefone** (1080 × 1920, 9:16). A loja aceita de 2 a 8; a ordem do nome é a ordem sugerida. |
| `banner_1024x500.png` | **Gráfico de recursos** (obrigatório, 1024 × 500). |
| `icone_512.png` | **Ícone do app** (obrigatório, 512 × 512, PNG). Vai quadrado: a loja arredonda os cantos sozinha. |

As telas são do app de verdade (tema novo), com dados de demonstração.

## Gerar de novo (depois de mudar o visual)

1. Capturas das telas reais, renderizadas pelo Flutter com as fontes de verdade:
   ```bash
   cd mobile
   flutter test test/play_store_screenshots_test.dart \
     --dart-define=FONT_DIR=$(dirname $(which flutter))/cache/artifacts/material_fonts \
     --dart-define=SHOTS_DIR=/tmp/telas --dart-define=PLAY_SCREENSHOTS=true
   ```
   (No CI esse teste fica pulado, porque não recebe `FONT_DIR`.) Para as imagens do site, rode também com
   `--dart-define=SHOT_HEIGHT=2340`.
2. Celular, fundo e frase (precisa do Playwright com Chromium):
   ```bash
   node scripts/play-store/make_store_images.js /tmp/telas docs/play-store mobile/assets/fonts
   ```

## Sugestão de textos da loja

**Nome:** Foco Academia

**Descrição curta (até 80 caracteres):**
Treino em casa, corrida e evolução. Painel para academias e personais.

**Descrição completa:**

> Treine com foco, do seu jeito ou com a sua academia.
>
> **Para quem treina**
> • Ficha da semana com cada exercício, séries e cronômetro
> • **Treino em casa**, sem equipamento: 12 treinos do leve ao extremo, com cada exercício desenhado, cronômetro, descanso e Tabata
> • Calorias, nível, sequência de dias, meta da semana e conquistas a cada treino
> • Treinos prontos de musculação, corrida, spinning e bike, do iniciante ao avançado
> • Monte os seus próprios treinos
> • Treino outdoor com GPS, ritmo, voz e mapa da rota
> • Calorias, quilômetros, histórico e evolução do peso
>
> **Para academias e personais**
> • Painel com alunos ativos, treinos do mês, notas e gráficos
> • Ranking dos instrutores e recados dos alunos para responder
> • Convide alunos e instrutores com um link: a conta já vem pronta
> • Segurança: cada conta funciona em um aparelho por vez
>
> Alunos que treinam sozinhos têm 15 dias grátis do Foco Premium.
