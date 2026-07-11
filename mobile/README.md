# Foco Academia — App Mobile (Flutter)

App do aluno para treinos outdoor com GPS, offline e sincronização.

## Requisitos

- Flutter 3.16+
- Android SDK / Xcode para build

## Configurar API

```bash
flutter run --dart-define=API_URL=https://academia.focodev.com.br
```

## Build

```bash
cd mobile
flutter pub get
flutter run
```

## Funcionalidades

- Login JWT (mesma API dos PWAs)
- Treino outdoor com GPS (`geolocator`)
- Fila offline SQLite + sync (`POST /api/student/sync`)
- Vibração nativa ao iniciar treino
- `appClient: MOBILE` no login para controle admin
