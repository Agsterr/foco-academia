# Cloudflare — Foco Academia

Túnel: **gerenciamento-estoque** (`4fe3f6e0-d2ec-4bca-8459-e66f81d95494`)

## DNS no painel (como na foto dos outros apps)

Em **DNS → Records → Add record**:

| Nome | Tipo | Destino | Proxy |
|------|------|---------|-------|
| `academia` | Tunnel (ou CNAME) | `gerenciamento-estoque` / `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com` | Ativado |
| `instrutor.academia` | CNAME | `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com` | Ativado |

O ingress do túnel inclui:
- `academia.focodev.com.br` → `http://127.0.0.1:8088`
- `instrutor.academia.focodev.com.br` → `http://127.0.0.1:8088`

## URLs após DNS propagar

| App | URL |
|-----|-----|
| Aluno | https://academia.focodev.com.br/ |
| **Instrutor** | https://instrutor.academia.focodev.com.br/ |
| Instrutor (legado) | https://academia.focodev.com.br/instrutor/* → redirect 301 para o subdomínio |
| **Admin plataforma** | https://academia.focodev.com.br/admin/ |
| API | https://academia.focodev.com.br/api/health |

O painel do instrutor tem PWA próprio no subdomínio `instrutor.academia.focodev.com.br`, separado do app do aluno (`scope: /` em `academia.focodev.com.br`).

## Contas demo

Contas de demonstração são provisionadas pelo seed da API. Não documente credenciais neste repositório — use variáveis de ambiente ou documentação privada do time.

## Automação (opcional)

```bash
ssh hetzner "bash /opt/foco-academia/scripts/cloudflare-add-academia-hostname.sh"
ssh hetzner "bash /opt/foco-academia/scripts/cloudflare-add-instrutor-hostname.sh"
```

Se o token não tiver Zone Read, crie o DNS manualmente (passo acima).

Para DNS via API com zone_id:

```bash
export CLOUDFLARE_ZONE_ID=<id da URL do painel Cloudflare>
bash /opt/foco-academia/scripts/cloudflare-dns-academia.sh
bash /opt/foco-academia/scripts/cloudflare-dns-instrutor.sh
```

O **zone_id** aparece na URL quando você abre a zona `focodev.com.br`:
`https://dash.cloudflare.com/<account>/<ZONE_ID>/focodev.com.br/dns/records`

## CORS

Inclua o subdomínio do instrutor em `CORS_ORIGINS` no `.env` do servidor:

```
CORS_ORIGINS=https://academia.focodev.com.br,https://www.academia.focodev.com.br,https://instrutor.academia.focodev.com.br
```
