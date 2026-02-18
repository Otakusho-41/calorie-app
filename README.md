
# Calorie App - Projeto Flutter pronto para compilar

Este projeto contém um aplicativo de contagem de calorias para smartphone. Ele já inclui:
- Adição de alimentos com quantidade e unidade
- Lista de unidades comuns (g, kg, ml, L, un, oz, lb, etc.)
- Cálculo de calorias usando um banco local `assets/foods.json` (amostra)
- Salvar itens e cardápio localmente com SharedPreferences
- Remoção de itens e cardápios
- Workflow GitHub Actions para compilar APK automaticamente (gera artifact `app-release.apk`)

## Como gerar o APK localmente (no seu computador)

Requisitos:
- Flutter SDK instalado e configurado
- Android SDK + Android Studio (ou command-line tools)
- Para gerar APK release, recomenda-se configurar assinatura (keystore)

### Build debug
```
flutter pub get
flutter run
```

### Build release APK
```
flutter build apk --release
```

O APK estará em `build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions (compilar na nuvem)
Um workflow `.github/workflows/android.yml` já está incluso. Basta empurrar para o branch `main` no GitHub e a ação irá construir um APK e disponibilizar como artifact.

## Assinatura do APK (opcional — para publicar na Play Store)
Se quiser assinar o APK automaticamente no GitHub Actions, você pode:
1. Gerar um keystore localmente:
```
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```
2. Adicionar o keystore no GitHub Secrets como variável base64 (se desejar embutir no workflow) e adaptar o workflow para criar `key.properties` e assinar.
(Forneço um exemplo se desejar.)

## Personalizações
- Substitua `assets/foods.json` por uma base de dados maior (TACO, USDA) se desejar precisão maior.
- Se quiser, eu posso integrar carregamento remoto (API) ou incluir a tabela TACO embutida no app.

---
