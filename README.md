# Parlissima

**Svensk diktering på din Mac med Klang Pianissimo. Klicka på pingvinen, prata och klicka igen, så hamnar texten där markören står.**

![Pingvinen i Parlissimas olika lägen: vila, lyssnar, skriver, klar och problem](docs/pingvinen.png)

Parlissima är en liten menyradsapp. Namnet är en blinkning till Klang Pianissimo, modellen som gör att appen förstår svenska. Den förstår svenska tack vare **Klang Pianissimo** och allt körs på din egen Mac. Inget ljud och ingen text skickas någonstans.

## Så fungerar det

- **Klicka på pingvinen** för att börja prata, klicka igen när du är klar. Den tar aldrig fokus, så texten klistras in där du redan skriver: i mejlet, dokumentet eller chatten.
- **Eller håll in höger option (⌥) eller höger control (⌃)**, prata och släpp. **Dubbeltryck** för att prata länge utan att hålla in.
- **Esc** avbryter utan att något skrivs.
- **Högerklicka på pingvinen** för menyn med Senaste, Ordlista och Inställningar.
- **Hittar du inte texten?** Om Parlissima inte kan se att markören står i en textruta ligger texten också kvar i urklipp, och indikatorn säger det. Klicka där du vill ha den och tryck ⌘V. Alla dikteringar finns dessutom under Senaste i två timmar.
- Pingvinen visar tydligt vad den gör: hörlurarna lyser korall och en röd prick pulserar när den lyssnar, en tankebubbla visas när den skriver och en bock när texten är inklistrad. En indikator högst upp visar ljudvåg och tid.
- **Egen ordlista** för namn och ord som ska stavas på ett visst sätt (menyraden → Ordlista).
- **Senaste:** dina dikteringar sparas i två timmar på din Mac, så att du kan kopiera texten igen eller låta Pianissimo försöka på nytt. Sedan raderas de automatiskt.

## Installera

Kräver en Mac med Apple Silicon (M1 eller senare) och macOS 14 eller senare.

### Det enklaste sättet: ladda ner appen

1. **[Ladda ner Parlissima](https://github.com/angiestran/parlissima/raw/main/download/Parlissima.dmg)** och öppna filen Parlissima.dmg i Hämtade filer.
2. **Dra Parlissima till mappen Appar** i fönstret som öppnas.
3. **Öppna Parlissima** från Appar. Första gången visar Macen rutan *"Parlissima" öppnades inte*, eftersom appen inte är granskad av Apple. Klicka **Klar** (inte Flytta till papperskorgen).
4. **Öppna Systeminställningar → Integritet och säkerhet**, scrolla ner till meddelandet om Parlissima och klicka **Öppna ändå**. Bekräfta med ditt lösenord. Det behövs bara första gången.

### Alternativ: Terminal eller Claude Code

Vill du hellre att Parlissima byggs på din egen dator, öppna Terminal och klistra in:

```bash
curl -fsSL https://raw.githubusercontent.com/angiestran/parlissima/main/install.sh | zsh
```

Använder du Claude Code kan du i stället skriva: *Installera Parlissima från https://github.com/angiestran/parlissima*

### Har du inte Mac?

Parlissima finns bara för Mac. Det här fungerar på andra enheter:

| Har du | Tips | Klang Pianissimo? |
|---|---|---|
| iPhone | [SnickSnack](https://snicksnack.applicerad.ai/) i App Store. Allt sker i telefonen. | Ja |
| Windows | [Pianissimo Meet](https://github.com/Olleman82/PianissimoMeet-public/releases/tag/v0.1.0-beta.1), öppen källkod. Transkriberar Teams- och Zoom-möten lokalt. | Ja |
| Windows, vardagsdiktering | Inbyggd röstinmatning: Windows-tangenten + H i valfri textruta | Nej |
| Android | Mikrofonen i Googles tangentbord Gboard | Nej |
| En ljudfil, vilken dator som helst | [Klangs demo](https://klang.ai/pianissimo/): ladda upp filen och få texten. Ljudet skickas till Klang. | Ja |

Fler appar byggda med Pianissimo finns på [klang.ai/pianissimo](https://klang.ai/pianissimo/).

### Första starten

Ett startfönster visar tre steg:

1. **Hämta Klangs modell**, cirka 690 MB och bara en gång. Varje fil kontrolleras mot en fast kontrollsumma.
2. **Tillåt mikrofonen.**
3. **Slå på Parlissima under Hjälpmedel** (Systeminställningar → Integritet och säkerhet). Det behövs för att texten ska kunna klistras in och för att kortkommandot ska fungera överallt.

Sedan klickar du på pingvinen och pratar.

> Installerar du om eller uppdaterar Parlissima kan du behöva ta bort Parlissima under Hjälpmedel med − och lägga till den igen med +.

## Integritet

- Taligenkänningen körs lokalt på Macens Neural Engine. Inget ljud lämnar datorn.
- Nätet används bara en gång: för att hämta språkmodellen från Hugging Face.
- Inga konton, ingen analys, ingen spårning.
- Parlissima klistrar aldrig in i lösenordsfält. Det du hade i urklipp läggs tillbaka när inklistringen säkert har landat.
- Dikteringar (text och ljud) sparas i högst två timmar i `~/Library/Application Support/Parlissima/Senaste` och raderas sedan.

## Bygga själv

```bash
git clone https://github.com/angiestran/parlissima.git
cd parlissima
scripts/build-app.sh
```

Bygger du Parlissima själv behöver du Apples gratis Command Line Tools (installeras med `xcode-select --install`). Hela Xcode behövs inte. Laddar du ner den färdiga appen behövs inget av detta.

## Tack

- **[Klang Pianissimo](https://huggingface.co/KlangAI/pianissimo-sv)** av Klang AI AB: svensk taligenkänning, CC BY 4.0. Finjusterad från NVIDIA Parakeet TDT 0.6B v3 (CC BY 4.0).
- **[Core ML-konvertering](https://huggingface.co/markstrom/pianissimo-sv-coreml)** av markstrom, CC BY 4.0.
- **[FluidAudio](https://github.com/FluidInference/FluidAudio)** av FluidInference, Apache 2.0. Kör modellen på Neural Engine.
- **[Mindtalk](https://github.com/dragon6sic6/Mindtalk)** (MIT): förteckningen över modellfiler och kontrollsummor.

Parlissima är en fristående app och är inte gjord eller supportad av Klang AI AB.

## Licens

Parlissimas källkod: [MIT](LICENSE). Språkmodellerna ingår inte i koden och har sina egna licenser (se [NOTICE](NOTICE)).

Appen delas gratis och i befintligt skick, utan utlovad support.

Gjord av Angelika Strandberg · GrowingSmart.
