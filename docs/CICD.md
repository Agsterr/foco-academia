# CI/CD — Foco Academia

## Fluxo

```
push main
  → Deploy to Hetzner (API + aluno + instrutor + admin)
  → Build Mobile Release (se mobile/** mudou) → publica APK na API
```

## Deploy local (recomendado)

```powershell
.\scripts\deploy-all.ps1 -Message "sua mensagem"
.\scripts\deploy-all.ps1 -SkipCommit          # ja commitado
.\scripts\deploy-all.ps1 -SkipCommit -WebOnly # so web
```

```bash
bash scripts/deploy-all.sh -m "sua mensagem"
```

## Servidor

| Item | Valor |
|------|--------|
| Path | `/opt/foco-academia` |
| Manual | `ssh hetzner "bash /opt/foco-academia/scripts/deploy-hetzner.sh"` |
| API version | https://academia.focodev.com.br/api/app/version |

## Secrets GitHub

`HETZNER_HOST`, `HETZNER_USER`, `HETZNER_SSH_KEY`, `APP_RELEASE_DEPLOY_TOKEN`, `ANDROID_KEYSTORE_*`

Skills Cursor: `focodev-deploy-web-mobile`, `focodev-pipeline-web-mobile`.
