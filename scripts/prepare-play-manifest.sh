#!/usr/bin/env bash
# Prepara o AndroidManifest para o build da Google Play (AAB).
# Remove permissoes que a loja nao aceita neste app:
#  - REQUEST_INSTALL_PACKAGES: a Play atualiza o app; instalar APK externo e proibido.
#  - ACCESS_BACKGROUND_LOCATION: exige formulario/video; o servico em primeiro
#    plano (foregroundServiceType=location) ja grava o GPS durante o treino.
# Use somente no CI, logo antes de `flutter build appbundle`.
set -euo pipefail
M="${1:-mobile/android/app/src/main/AndroidManifest.xml}"

grep -q 'xmlns:tools=' "$M" || sed -i '0,/<manifest xmlns:android="http:\/\/schemas.android.com\/apk\/res\/android"/s##<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"#' "$M"

sed -i '/android.permission.REQUEST_INSTALL_PACKAGES/d;/android.permission.ACCESS_BACKGROUND_LOCATION/d' "$M"
# garante a remocao mesmo se algum plugin tentar adicionar de volta
sed -i '0,/<uses-permission /s##<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove"/>\n    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" tools:node="remove"/>\n    <uses-permission #' "$M"
echo "Manifest da Play preparado: $M"
