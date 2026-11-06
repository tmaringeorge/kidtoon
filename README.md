# KidToon

Aplicație pentru copii, pentru **telefon** și **Android TV / Google TV**, în două variante, ca în
[ZapTV](https://github.com/tmaringeorge/androidtv):

- **`tv/`: KidToon TV**, aplicația nativă de televizor (Kotlin, Compose for TV, Media3), făcută pentru
  telecomandă. Pornește din `androidtv/tv` și păstrează același drum: meniul lateral care se deschide la
  focus, grila, playerul, radioul cu modul Copil, setările.
- **rădăcina repo-ului: KidToon** în Flutter, pentru telefon și tabletă (merge și pe TV).

În ambele, în față e copilul, nu radioul.

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

## Pe televizor: KidToon TV (`tv/`)

Aplicația nativă de TV (`ro.kidtoon.tv`) apare în lansatorul Android TV cu banner și se folosește doar cu
telecomanda. La prima pornire copilul își alege prietenul, apoi vede meniul lateral:

| Meniu | Ce face |
|---|---|
| 🏠 Acasă | prietenul face cu mâna („Bună! Eu sunt Bubu!”) și plăci mari: Continuă povestea, Povești, Atinge, Colorează, Desenează, Construiește, Desene TV, Radio |
| 🎬 Povești cu *numele ales* | toate poveștile, pe tot ecranul, cu voce; ◀ ▶ altă poveste, OK răspunde la întrebări. Fără radio |
| 👆 Atinge și învață | scenele cu lucruri pe care copilul le alege cu săgețile și le „atinge” cu OK |
| 🎨 Atelier | Colorează (10 planșe: săgețile aleg zona, OK o umple), Desenează (săgețile mută creionul, OK îl pune pe foaie, ștampile), Construiește (piese și abțibilduri: OK prinde piesa, săgețile o mută), Galeria mea |
| 📺 Desene TV | grila de posturi pentru copii, categorii, preferate (ține apăsat OK), Continuă |
| 🎵 Radio cu animații | exact radioul din ZapTV, cu modul Copil, poveștile și „Atinge” |
| 🔒 Părinți | o înmulțire sau PIN-ul, apoi setările: doar posturi pentru copii, posturi ascunse, PIN, liste M3U, ghid TV, ecran sănătos, prietenul, Studio |

Ecranul sănătos (pauza de clipit, odihna după limită, lumina caldă seara) merge și la povești, fără radio.
În Atelier, din marginea din dreapta a foii ajungi la culori și unelte; 💾 Salvează pune lucrarea în Galerie.

```bash
cd tv
./gradlew testDebugUnitTest
./gradlew assembleRelease   # app/build/outputs/apk/release/app-release.apk
```

Poveștile (`assets/ghi/episodes.json`) și lista inclusă sunt comune cu aplicația Flutter.
Detalii și instalare: [`docs/INSTALARE-TV.md`](docs/INSTALARE-TV.md).

## Build

APK-urile se construiesc pe GitHub Actions (`.github/workflows/build.yml`) la fiecare PR și se publică la
[Releases](../../releases/latest) la fiecare push pe `main`: **KidToon-tv.apk** (televizor) și
**KidToon.apk** (telefon).

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
| `tv/app/src/main/java/ro/kidtoon/tv/` | aplicația de TV: `MainActivity.kt` (ecranele), `ui/HomeScreen.kt` (meniul și secțiunile), `ui/WelcomeScreen.kt`, `ui/KidPlayScreens.kt`, `ui/AtelierScreens.kt`, `ui/ParentGate.kt`, `ui/SettingsScreen.kt`, `data/` |
| `lib/screens/main_screen.dart` | meniul lateral și secțiunile |
| `lib/screens/welcome_screen.dart` | alegerea prietenului (prima pornire) |
| `lib/screens/home_section.dart`, `stories_screen.dart`, `tv_section.dart` | Acasă, Povești / Atinge și învață, Desene TV |
| `lib/screens/atelier/` | Colorează, Desenează, Construiește, Galeria mea |
| `lib/screens/parent_gate.dart`, `settings_screen.dart` | poarta și setările pentru părinți |
| `lib/data/coloring_pages.dart` | planșele de colorat (ușor de adăugat altele) |
| `assets/ghi/episodes.json` | poveștile (același format ca în ZapTV) |
