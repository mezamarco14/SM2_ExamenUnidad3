# SM2_ExamenUnidad3

## 📚 Curso y Estudiante

- **Curso:** Móviles II  
- **Fecha:** 27/06/2025
- **Estudiante:** Jean Marco Meza Noalcca

---

## 🔗 Repositorio GitHub

[https://github.com/mezamarco14/SM2_ExamenUnidad3.git](https://github.com/tu-usuario/SM2_ExamenUnidad3)

---

## 📁 Estructura del Proyecto

A continuación, se muestra la estructura de carpetas donde se encuentra configurado el workflow de GitHub Actions:

## ✅ Contenido del archivo `quality-check.yml`

```yaml
name: Quality Check

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze_and_test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.5'

      - name: Install dependencies
        run: flutter pub get
        
      - name: Run unit tests
        run: flutter test

      - name: Analyze code
        run: flutter analyze