# Assinatura Foco Premium (Google Play)

O código já está pronto no app e na API. Enquanto `BILLING_ENFORCE=false`, **ninguém é bloqueado**:
contas novas ganham 7 dias de teste, e o cartão "Foco Premium" aparece, mas tudo continua liberado.

## O que é premium

- **Aluno de academia:** tudo liberado (a academia paga). Não vê cobrança.
- **Aluno avulso (conta criada no app):**
  - grátis: treino outdoor livre, peso, histórico, a ficha que já estiver ativa;
  - premium: começar **treinos prontos** e **montar fichas novas**.

## Passo a passo (uma vez)

1. **Conta de desenvolvedor Google Play** — https://play.google.com/console (taxa única de US$ 25).
2. **Criar o app** com o pacote `com.focodev.academia.aluno` e enviar um build (AAB) para o
   teste interno. O Google só mostra produtos de assinatura para apps já enviados.
3. **Perfil de pagamentos** (Play Console → Configurações → Perfil de pagamentos), com conta bancária.
4. **Criar as assinaturas** (Monetizar → Produtos → Assinaturas):
   - `foco_premium_mensal` — plano base mensal, renovação automática (sugestão: R$ 24,90);
   - `foco_premium_anual` — plano base anual, renovação automática (sugestão: R$ 199,00).
   Os IDs precisam ser exatamente esses (ou mude `BILLING_PRODUCT_IDS` no servidor).
   O preço mostrado no app vem da Play Store, não do código.
5. **Conta de serviço para a API confirmar as compras:**
   - Google Cloud Console → criar projeto (ou usar um) → ativar **Google Play Android Developer API**;
   - IAM → Contas de serviço → criar → Chaves → **Adicionar chave JSON** (baixa um arquivo);
   - Play Console → Usuários e permissões → convidar o e-mail da conta de serviço com permissão
     **"Ver dados financeiros"** e **"Gerenciar pedidos e assinaturas"**.
6. **No servidor** (`.env` da Hetzner), colar o JSON **em uma linha** e ligar o bloqueio:
   ```
   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
   BILLING_ENFORCE=true
   ```
   e rodar o deploy. Antes de ligar o `BILLING_ENFORCE`, faça uma compra de teste com uma
   conta de testador de licença (Play Console → Configuração → Teste de licença).

## Como funciona

- O app compra pelo Google Play (`in_app_purchase`) e manda o token da compra para
  `POST /api/student/subscription/google-play`.
- A API consulta o Google (`purchases.subscriptionsv2`) com a conta de serviço — o app nunca
  é a fonte da verdade. Só depois disso o app confirma a compra ao Google; se a API não
  confirmar, a compra é reentregue na próxima abertura do app (o Google estorna compras não
  confirmadas em 3 dias).
- Renovação: quando o prazo salvo passa, a API reconsulta o Google ao abrir o status.
- Suporte/cortesia: `POST /api/admin/users/{id}/subscription/grant` com `{"days": 30}` (admin).

## App instalado por APK (fora da Play Store)

A compra só funciona no app baixado pela Play Store. No APK atual, a tela Foco Premium
explica isso; a conta é a mesma, então o aluno pode instalar pela loja e continuar.
