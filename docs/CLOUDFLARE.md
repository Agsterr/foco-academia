# Cloudflare — Foco Academia

Túnel: **gerenciamento-estoque** (`4fe3f6e0-d2ec-4bca-8459-e66f81d95494`)

## DNS no painel (como na foto dos outros apps)

Em **DNS → Records → Add record**:

| Nome | Tipo | Destino | Proxy |
|------|------|---------|-------|
| `academia` | Tunnel (ou CNAME) | `gerenciamento-estoque` / `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com` | Ativado |

O ingress do túnel já inclui `academia.focodev.com.br → http://127.0.0.1:8088`.

## URLs após DNS propagar

| App | URL |
|-----|-----|
| Aluno | https://academia.focodev.com.br/ |
| Instrutor | https://academia.focodev.com.br/instrutor/ |
| **Admin plataforma** | https://academia.focodev.com.br/admin/ |
| API | https://academia.focodev.com.br/api/health |

## Contas demo

Contas de demonstração são provisionadas pelo seed da API. Não documente credenciais neste repositório — use variáveis de ambiente ou documentação privada do time.

## Automação (opcional)

```bash
ssh hetzner "bash /opt/foco-academia/scripts/cloudflare-add-academia-hostname.sh"
```

Se o token não tiver Zone Read, crie o DNS manualmente (passo acima).

Para DNS via API com zone_id:

```bash
export CLOUDFLARE_ZONE_ID=<id da URL do painel Cloudflare>
bash /opt/foco-academia/scripts/cloudflare-dns-academia.sh
```

O **zone_id** aparece na URL quando você abre a zona `focodev.com.br`:
`https://dash.cloudflare.com/<account>/<ZONE_ID>/focodev.com.br/dns/records`
