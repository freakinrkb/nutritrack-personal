<p align="center">
  <img alt="NutriTrack Personal" src="assets/icon/ont_banner_top.png" width="420" />
</p>

<h1 align="center">NutriTrack Personal</h1>

<p align="center">
  <b>Personalized, offline-first nutrition tracker (GPL-3.0 fork of OpenNutriTracker)</b><br />
  Android-focused build with bundled INDB catalogue, routines, durable nutrient goals, named portions, and fiber scaling to your calorie goal.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-GPLv3-22de5f?style=flat-square" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android-lightgrey?style=flat-square" />
  <img alt="Offline" src="https://img.shields.io/badge/offline-first-22de5f?style=flat-square" />
</p>

## What's different from upstream

- **Offline-friendly catalogue** — bundled INDB recipe/food catalogue (`assets/food/indb_recipes.json`) with JSON import support
- **Routines / daily habits** — track daily habits on the home screen
- **Durable nutrient goals + daily panel** — per-nutrient goals persist and appear on the diary panel
- **Named household portions** — easier portion selection for common items
- **Fiber follows calories** — fiber target auto-calculates at **14 g / 1,000 kcal** of your shown calorie goal (exercise credits included). Manual overrides still work.
- **App identity** — `com.freakinrkb.nutritrack` (Android)

## Build it yourself (works fully offline)

1. Install [FVM](https://fvm.app/) and run `fvm install` in this repo (uses `.fvmrc`).
2. Copy env template: `cp .env.example .env` (placeholders are fine for local builds; see [docs/supabase-self-hosting.md](docs/supabase-self-hosting.md) if you want online food search via your own Supabase backend).
3. `fvm flutter pub get`
4. Generate files: `fvm dart run build_runner build --delete-conflicting-outputs` and `fvm flutter gen-l10n`
5. Run debug: `fvm flutter run --flavor develop` (separate app id from release)
6. Build signed release (optional): create `android/key.properties` + keystore (gitignored). Without signing keys, use debug builds.

**Notes**
- The bundled INDB catalogue works fully offline with custom foods and local recipes.
- Global search requires Supabase keys; without them online search will fail gracefully.
- This is an unofficial personal fork, not affiliated with the upstream project.

## Upstream

This is a fork of [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker). See [LICENSE](LICENSE) and upstream docs for attribution and original functionality. All user data stays local and encrypted; there are no built-in analytics.

## License
GPL-3.0 — see [LICENSE](LICENSE).
