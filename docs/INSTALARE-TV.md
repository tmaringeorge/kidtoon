# Cum instalezi KidToon pe televizorul TCL (Android TV / Google TV)

Durează cam 10 minute, o singură dată. Actualizările ulterioare se instalează la fel,
peste versiunea veche (prietenul ales, favoritele, sursele și galeria rămân).

## 1. Ia fișierul APK

APK-ul se construiește automat pe GitHub la fiecare modificare în `main`.

1. Deschide pe telefon sau calculator: <https://github.com/tmaringeorge/kidtoon/releases/latest>
2. Descarcă **KidToon.apk** (același fișier merge și pe telefon, și pe televizor).

> Dacă repo-ul e privat, linkul merge doar cât ești logat pe GitHub, deci televizorul
> nu îl poate descărca direct. Folosește una din variantele de la pasul 3.

## 2. Pregătește televizorul (o singură dată)

**Activează modul dezvoltator**

1. **Setări** → **Sistem** → **Despre** (pe unele TCL: **Setări** → **Preferințe dispozitiv** → **Despre**).
2. Mergi pe **Versiune Android TV OS** (sau **Build**) și apasă **OK de 7 ori**,
   până apare „Acum ești dezvoltator”.

**Permite instalarea din surse necunoscute**

- Google TV (TCL mai noi): **Setări** → **Sistem** → **Opțiuni dezvoltator** / **Confidențialitate**
  → **Securitate și restricții** → **Surse necunoscute** → activează pentru aplicația
  cu care instalezi (de ex. **Downloader** sau **File Commander**).
- Android TV (TCL mai vechi): **Setări** → **Preferințe dispozitiv** → **Securitate și restricții**
  → **Surse necunoscute** → activează.

## 3. Copiază și instalează APK-ul (alege o variantă)

### Varianta A: cu aplicația Downloader (cea mai simplă, dacă repo-ul e public)

1. Pe televizor, din **Google Play**, instalează **Downloader** (de la AFTVnews).
2. Deschide Downloader, permite accesul la fișiere.
3. În câmpul de adresă scrie:
   `https://github.com/tmaringeorge/kidtoon/releases/latest/download/KidToon.apk`
4. Apasă **Go**. După descărcare apare ecranul de instalare → **Instalează** → **Deschide**.

### Varianta B: de pe telefon, fără cablu (merge și cu repo privat)

1. Descarcă **KidToon.apk** pe telefon (pasul 1).
2. Instalează aplicația **Send Files to TV** (SFTTV) și pe telefon, și pe televizor, din Google Play.
3. Pe televizor deschide SFTTV → **Receive**. Pe telefon → **Send** → alege APK-ul → alege televizorul.
4. Pe televizor deschide fișierul primit (din SFTTV sau dintr-un manager de fișiere, de ex. **File Commander**)
   → **Instalează**.

### Varianta C: cu stick USB

1. Copiază **KidToon.apk** pe un stick USB de pe calculator.
2. Bagă stick-ul în televizor, deschide **File Commander** (sau managerul de fișiere TCL), găsește APK-ul → **Instalează**.

### Varianta D: din calculator, prin ADB (pentru avansați)

1. Pe televizor: **Opțiuni dezvoltator** → activează **Depanare USB / ADB prin rețea**.
2. Află IP-ul televizorului: **Setări** → **Rețea** → rețeaua ta.
3. Pe calculator (cu [platform-tools](https://developer.android.com/tools/releases/platform-tools)):
   ```bash
   adb connect 192.168.1.50:5555   # IP-ul televizorului
   adb install -r KidToon.apk
   ```
   Acceptă pe televizor fereastra „Permite depanarea”.

## 4. Pornește KidToon

Aplicația apare pe ecranul principal în rândul de aplicații (dacă nu o vezi:
**Aplicații** → **Vezi toate aplicațiile** → KidToon; o poți muta la favorite cu OK lung).

La prima pornire copilul își alege prietenul: numele, costumașul și băiat sau fată.
Numele ales apare apoi peste tot, inclusiv în povești.

### Telecomanda

| Unde | Tastă | Ce face |
|---|---|---|
| Peste tot | săgeți | mută rama albă pe butonul următor |
| Peste tot | OK | apasă butonul ales |
| Peste tot | Înapoi | revine |
| Meniul din stânga | ▲ ▼ | Acasă, Povești, Atinge, Atelier, Desene, Radio, Părinți |
| Povești | ◀ ▶ | povestea anterioară / următoare |
| Povești (la o întrebare) | ◀ ▶ și OK | alegi răspunsul |
| Atinge și învață | săgeți / OK | alegi un lucru / vocea spune ce este; la capete trece la altă scenă |
| Colorează | săgeți / OK | alegi zona (rama galbenă) / o colorezi; din marginea foii ajungi la culori și unelte |
| Desenează | săgeți / OK | muți pensula / o pui pe foaie sau o ridici (cu ștampila: pune ștampila) |
| Construiește | săgeți / OK | muți piesa aleasă / treci la piesa următoare |
| Desene TV (player) | ▲ ▼ sau CH+ / CH− | postul anterior / următor |
| Desene TV (player) | OK | arată informațiile, apoi lista de posturi |
| Desene TV (player) | cifre 0-9 | sari direct la postul cu acel număr |
| Desene TV (grilă) | OK ținut apăsat | pune / scoate postul la ❤️ |
| Radio (mod Copil) | ◀ ▶ | animația, povestea sau scena anterioară / următoare |
| Radio | CH+ / CH− | postul de radio anterior / următor |
| Radio | OK | arată / ascunde panoul cu postul |
| Pauza lungă (prietenul doarme) | OK ținut apăsat 3 secunde | părintele continuă |

## 5. Pentru părinți

**Meniul din stânga** → **🔒 Părinți**. Se intră cu o înmulțire (sau cu PIN-ul, dacă ai pus unul).

- **Doar posturi pentru copii** (pornit): la Desene TV apar doar categoriile Copii, Educație și Familie.
- **Ascunde posturi**: alegi posturile pe care copilul nu le vede.
- **PIN pentru părinți**: 4 cifre; dacă îl uiți, „Am uitat PIN-ul” cere o înmulțire și îl șterge.
- **Ecran sănătos**: pauză de clipit la 5 minute, odihnă după 15 / 20 / 30 de minute sau după 3 povești la rând.
- **Adaugă listă M3U** și **ghid TV**: liste de posturi (de exemplu de la un furnizor IPTV legal) și programul „Acum / Urmează”. Tastatura de pe ecran apare când apeși OK pe câmpul de text.
  Tip: e mai ușor să scrii linkul cu aplicația **Google TV** de pe telefon.
- **Studio de povești**: faci povești și personaje noi pe telefon și le trimiți pe TV.

## Probleme frecvente

- **„Aplicația nu a fost instalată”**: dezinstalează o versiune veche semnată diferit, apoi reinstalează.
- **Un post nu pornește**: unele posturi sunt temporar oprite sau au restricție geografică.
  Treci la următorul cu ▼.
- **Desene TV e gol**: lista implicită de desene se descarcă de pe internet; verifică conexiunea sau adaugă o listă din 🔒 Părinți.
- **Nu apare în lista de aplicații**: caută în **Aplicații** → **Vezi toate aplicațiile**.
