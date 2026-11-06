# KidToon

Aplicație pentru copii, în Flutter, pentru **telefon** și **Android TV / Google TV** (același APK).
Pornește de la [ZapTV](https://github.com/tmaringeorge/androidtv) și păstrează structura de acolo
(meniul lateral cu secțiuni, grila, playerul, radioul cu modul Copil, setările), dar în față e copilul,
nu radioul.

## Ce găsește copilul

- **Prima pornire: prietenul meu** 🐉. Copilul alege numele (Bubu, Tita, Dino… sau scrie altul), costumașul
  (dinozaur, balaur, leu, ursuleț) și băiat sau fată. Numele ales apare peste tot: „Bună! Eu sunt Bubu!”,
  „Povești cu Bubu”, iar poveștile spun „Bubu e fericit”, „Mami o îmbrățișează pe Tita”.
- **Acasă**: prietenul salută și arată plăci mari, colorate: Continuă povestea, Povești, Atinge și învață,
  Colorează, Desenează, Construiește, Desene TV, Radio cu animații.
- **Povești** 🎬: cele 49 de episoade din ZapTV (și cele din Studio), pe tot ecranul, cu vocea care
  povestește și întrebări la care copilul răspunde atingând (pe TV: ◀ ▶ și OK). Nu trebuie ales niciun radio.
- **Atinge și învață** 👆: 8 scene; copilul atinge un lucru și vocea spune ce este.
- **Atelier** 🎨:
  - **Colorează**: 10 planșe (căsuța, peștișorul, floarea, mașinuța, fluturele, pisicuța, racheta,
    dinozaurul, curcubeul, forme). Atingi o zonă și se umple; vocea spune „Soarele, galben!”.
    Butoane mari: Înapoi, Surpriză (culori la întâmplare), Șterge, Salvează.
  - **Desenează**: creion, pensulă curcubeu, radieră, 24 de ștampile, 3 grosimi, 14 culori.
  - **Construiește**: forme (pătrat, dreptunghi, cerc, triunghi, stea, inimă, semicerc, hexagon) și
    abțibilduri; le muți cu degetul, le mărești și rotești cu două degete sau din butoane. Idei de început:
    căsuța, robotul, trenulețul, racheta; 4 fundaluri.
  - **Galeria mea**: tot ce a salvat copilul.
- **Desene TV** 📺: grila de posturi pentru copii (implicit lista publică iptv-org „Copii”), cu Favorite ❤️
  și Recente, player cu ▲▼ / CH±, listă rapidă și număr din cifre.
- **Radio cu animații** 🎵: exact fluxul din ZapTV (lista de posturi, modul Copil cu animații, povești și
  Atinge și învață peste radio, temporizator de somn, radio în fundal).

## Pentru părinți 🔒

Setările sunt după o **poartă pentru părinți**: o înmulțire cu 4 variante sau un **PIN** de 4 cifre.

- **Doar posturi pentru copii** (pornit implicit): la Desene TV apar doar categoriile Copii, Educație, Familie.
- **Ascunde posturi** pe care nu le vrei.
- **Ecran sănătos**: pauză de clipit la 5 minute, odihnă după 15 / 20 / 30 de minute sau după 3 povești la rând
  (doar părintele continuă, ținând apăsat 3 secunde), culori mai calde seara.
- **Modul Adult** al radioului și **Studioul de povești** cer și ele poarta.
- Surse M3U și ghid TV (XMLTV), ca în ZapTV.

## Pe televizor

Aplicația apare în lansatorul Android TV (are banner) și se folosește doar cu telecomanda: săgețile mută
rama albă, OK apasă. Pe foile din Atelier săgețile aleg zona / mută pensula sau piesa, iar din marginea
foii ajung la culori și unelte. Detalii și instalare: [`docs/INSTALARE-TV.md`](docs/INSTALARE-TV.md).

## Build

APK-ul se construiește pe GitHub Actions (`.github/workflows/build.yml`) la fiecare PR și se publică la
[Releases](../../releases/latest) la fiecare push pe `main`.

```bash
flutter pub get
flutter test
flutter build apk      # build/app/outputs/flutter-apk/app-release.apk
```

APK-ul e semnat cu o cheie comitată în repo (`android/app/kidtoon.keystore`), ca actualizările să se
instaleze peste versiunea veche. E potrivit pentru uz personal; pentru Google Play folosește o cheie privată.

## Structura

| Folder | Ce conține |
|---|---|
| `lib/screens/main_screen.dart` | meniul lateral și secțiunile |
| `lib/screens/welcome_screen.dart` | alegerea prietenului (prima pornire) |
| `lib/screens/home_section.dart`, `stories_screen.dart`, `tv_section.dart` | Acasă, Povești / Atinge și învață, Desene TV |
| `lib/screens/atelier/` | Colorează, Desenează, Construiește, Galeria mea |
| `lib/screens/parent_gate.dart`, `settings_screen.dart` | poarta și setările pentru părinți |
| `lib/data/coloring_pages.dart` | planșele de colorat (ușor de adăugat altele) |
| `assets/ghi/episodes.json` | poveștile (același format ca în ZapTV) |
