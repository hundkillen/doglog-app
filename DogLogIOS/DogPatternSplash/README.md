# Splashskärm för iOS – HundMönster AI

Det här paketet innehåller:
- **AppLogo.svg** (redigerbar logotyp i SVG – importera och exportera som PDF/PNG för Xcode)
- **LaunchScreen.storyboard** (statisk iOS Launch Screen)
- **SplashView.swift** (animerad SwiftUI-vy som visas direkt efter Launch Screen)
- **Assets.xcassets/AppLogo.imageset** (mapp med `Contents.json` och SVG för enkel import)

## Snabbsetup (Xcode 15+)
1. Dra in hela `Assets.xcassets`-mappen i ditt Xcode-projekt.
2. Öppna **Info** för target → **App Icons and Launch Images** → sätt **Launch Screen File** till `LaunchScreen` och lägg `LaunchScreen.storyboard` i projektet.
3. Lägg till `SplashView.swift`. Använd `SplashView()` som startvy i din `@main`-App eller presentera den innan du navigerar vidare till din Home-vy.

```swift
@main
struct HundMonsterAIApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView() // visa först, navigera sen
        }
    }
}
```

> **Obs:** iOS tillåter **endast statiskt** innehåll på den riktiga Launch Screen. Animeringen sker i **SplashView** efter att appen startat.

## Färg & typografi
- Bakgrund: `#1F2937 → #0F172A` (mörk, lugn, premium)
- Accent: `#A7F3D0 → #60A5FA` (positiv utveckling, “insikt”)
- Titel: tung sans-serif (SF Pro / Rounded fungerar bra)
- Kontrast AA/AAA säkerställs med vit text på mörk bg.

## Tagline-texter (för underslogan)
- *"AI som ser mönstren i din hunds vardag."*
- *"Träna smartare: se vad som ger bra dagar."*
- *"Data → insikt → bättre dagar."*

## Exempel på insikter i appen (copy)
- *“2 dagar efter Nosework har ni konsekvent bättre dagar.”*
- *“Vilodagar följda av för lite mental aktivering ger sämre fokus dagen därpå.”*
- *“Kombon ‘långpromenad + kort Nosework’ ger bäst kvällar.”*

## Tips
- Exportera `AppLogo.svg` till en **enkel vektor-PDF** och lägg den som **Single Scale** i din imageset (Xcode skalar själv).
- Behöver du annan färgsättning? Öppna SVG i Affinity/Illustrator och byt gradienterna.

Lycka till! 🐾
