# Foco Academia

Monorepo de gestão de academias: API Spring Boot + PostgreSQL, três PWAs Next.js (`aluno`, `instrutor`, `admin`) e um app Flutter (`mobile`). Comandos de dev/setup estão no `README.md` e nos `scripts` de cada `package.json`/`pom.xml`.

## Cursor Cloud specific instructions

Escopo configurado no ambiente cloud: os produtos web (API + PostgreSQL + os 3 PWAs). O app Flutter (`mobile/`) está fora do escopo (requer SDK Flutter + toolchain Android, não instalado).

### Serviços e como rodar (dev)

- **PostgreSQL 16** (instalado via apt, dados persistem no snapshot). Não inicia sozinho no boot da VM — inicie com `sudo pg_ctlcluster 16 main start`. Banco/usuário/senha: `academia`/`academia`/`academia` (já criados). A API usa `ddl-auto=update`, então o schema é criado automaticamente; avisos "constraint ... does not exist, skipping" no primeiro start são inofensivos.
- **API (Spring Boot, porta 8080)**: `cd api && sh mvnw -DskipTests spring-boot:run`. O wrapper `mvnw` não tem bit de execução — use `sh mvnw`, não `./mvnw`. Roda em Java 21 (o `pom` mira release 17). Health: `curl http://localhost:8080/api/health`.
- **PWAs Next.js 16**: `cd <app> && NEXT_PUBLIC_API_URL=http://localhost:8080 npm run dev -- -p <porta>`. Portas usadas: `aluno` 3001, `instrutor` 3002, `admin` 3000. Sem `NEXT_PUBLIC_API_URL` os apps não conseguem falar com a API.

### Contas demo (seed)

As contas demo só são criadas se as variáveis `SEED_ADMIN_PASSWORD`, `SEED_INSTRUTOR_PASSWORD`, `SEED_ALUNO_PASSWORD` estiverem definidas ao iniciar a API (senão o seed pula a criação). Ao rodar a API para testar, defina-as, ex.:

```
SEED_ADMIN_PASSWORD=admin123 SEED_INSTRUTOR_PASSWORD=instrutor123 SEED_ALUNO_PASSWORD=aluno123 \
CORS_ORIGINS="http://localhost:3000,http://localhost:3001,http://localhost:3002" \
sh mvnw -DskipTests spring-boot:run
```

Contas resultantes: admin `admin@focodev.com.br`, instrutor `instrutor@academia.com`, aluno `aluno@academia.com`. O **CORS** padrão só libera 3001/3002 — inclua a porta do admin (3000) via `CORS_ORIGINS` se for testá-lo.

### Login (tenant)

Instrutor e aluno exigem o **código da academia** (`academySlug`) no login — o valor semeado é `academia-demo` — além de um `deviceId` (o frontend gera automaticamente). Admin loga sem código de academia. Ex. de erro esperado se faltar: "Código da academia é obrigatório".

### Lint / testes / build

- API: `sh mvnw test` (usa H2, não precisa do Postgres). Build: `sh mvnw -DskipTests package`.
- PWAs: `npm run lint` e `npm run build` em cada app. O `npm run lint` atual já reporta erros/avisos pré-existentes no código — não são do ambiente.

### Mídia (R2)

As variáveis `R2_*` podem ficar vazias em dev — `MediaStorageService` cai para disco local (`uploads/`, servido em `/api/media/...`).
