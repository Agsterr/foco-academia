# Foco Academia

Sistema completo para academias com **dois PWAs** (aluno + instrutor) e **API Spring Boot**.

## Estrutura

| Pasta | Descrição |
|-------|-----------|
| `api/` | API REST Spring Boot 3.5 + JWT + PostgreSQL |
| `aluno/` | PWA do aluno — treinos, avaliações, sugestões |
| `instrutor/` | PWA do instrutor — alunos, treinos, vídeos, respostas |
| `docker/` | Dockerfiles e nginx |

## Funcionalidades

### Aluno
- Ver treinos personalizados com exercícios e vídeos
- Avaliar treino (muito bom, bom, fácil, ruim, muito ruim)
- Marcar treino como concluído
- Enviar sugestões e ver respostas do instrutor

### Instrutor
- Dashboard com métricas
- Cadastrar alunos
- Criar treinos por aluno com exercícios
- Upload de vídeo/foto da galeria ou câmera do celular
- Ver avaliações dos alunos
- Responder sugestões

## Desenvolvimento local

### API
```bash
cd api
./mvnw spring-boot:run
```

### Frontends
```bash
cd aluno && npm run dev -- -p 3001
cd instrutor && npm run dev -- -p 3002
```

Configure `NEXT_PUBLIC_API_URL=http://localhost:8080` nos dois apps.

### Contas demo (criadas automaticamente)
- Instrutor: `instrutor@academia.com` / `instrutor123`
- Aluno: `aluno@academia.com` / `aluno123`

## Docker

```bash
cp .env.production.example .env
docker compose up -d --build
```

- Aluno: http://localhost:8088/
- Instrutor: http://localhost:8088/instrutor/
- API: http://localhost:8088/api/health

## Deploy Hetzner

Path no servidor: `/opt/foco-academia`

1. Copie `.env` para o servidor
2. `bash scripts/setup-git-hetzner.sh` (cadastre deploy key no GitHub)
3. Push em `main` dispara GitHub Actions

Domínio sugerido: `academia.focodev.com.br` via Cloudflare Tunnel.

## Tecnologias

- Spring Boot 3.5, JPA, Security, JWT
- Next.js 16, Tailwind, PWA
- PostgreSQL, Docker, nginx, Cloudflare Tunnel
