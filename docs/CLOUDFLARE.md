# Cloudflare — Foco Academia

Túnel compartilhado: **gerenciamento-estoque** (`4fe3f6e0-d2ec-4bca-8459-e66f81d95494`)

| Hostname | Origem nginx |
|----------|----------------|
| `https://academia.focodev.com.br/` | `http://127.0.0.1:8088` (aluno) |
| `https://academia.focodev.com.br/instrutor/` | painel instrutor |
| `https://academia.focodev.com.br/api/` | API Spring Boot |

## Automação no servidor

```bash
ssh hetzner "bash /opt/foco-academia/scripts/cloudflare-add-academia-hostname.sh"
```

O script:
1. Atualiza o ingress do túnel (preserva hostnames existentes)
2. Tenta criar o CNAME `academia` → `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com`

## DNS manual (se o token não tiver Zone Read)

No painel [Cloudflare DNS](https://dash.cloudflare.com):

| Campo | Valor |
|-------|--------|
| Tipo | CNAME |
| Nome | `academia` |
| Destino | `4fe3f6e0-d2ec-4bca-8459-e66f81d95494.cfargotunnel.com` |
| Proxy | Ativado (nuvem laranja) |

## Verificação

```bash
curl -s https://academia.focodev.com.br/api/health
curl -sI https://academia.focodev.com.br/
curl -sI https://academia.focodev.com.br/instrutor/
```

## Token API recomendado

Para automação completa (ingress + DNS), use token com:
- Cloudflare Tunnel Edit
- Zone DNS Edit (`focodev.com.br`)
- Zone Read (`focodev.com.br`)

Salvar em `/opt/app-rotas/.env` como `CLOUDFLARE_API_TOKEN=...`

Ou informar o zone_id manualmente:

```bash
export CLOUDFLARE_ZONE_ID=<id da zona>
bash /opt/foco-academia/scripts/cloudflare-dns-academia.sh
```

O zone_id aparece na URL do painel: `dash.cloudflare.com/<account>/<ZONE_ID>/focodev.com.br`
