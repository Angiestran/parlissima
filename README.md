# Tala

**Svensk diktering på din Mac med Klang Pianissimo. Klicka på cybergumman, prata och klicka igen, så hamnar texten där markören står.**

![Cybergumman i Talas olika lägen: vila, lyssnar, skriver, klar och problem](docs/cybergumman.png)

Tala är en liten menyradsapp. Den förstår svenska tack vare **Klang Pianissimo** och allt körs på din egen Mac. Inget ljud och ingen text skickas någonstans.

## Så fungerar det

- **Klicka på cybergumman** för att börja prata, klicka igen när du är klar. Hon tar aldrig fokus, så texten klistras in där du redan skriver: i mejlet, dokumentet eller chatten.
- **Eller håll in höger alt** (eller höger control), prata och släpp. **Dubbeltryck** för att prata länge utan att hålla in.
- **Esc** avbryter utan att något skrivs.
- En tydlig indikator högst upp på skärmen visar ljudvåg och tid medan du pratar.
- **Egen ordlista** för namn och ord som ska stavas på ett visst sätt (menyraden → Ordlista).
- **Senaste:** dina dikteringar sparas i två timmar på din Mac, så att du kan kopiera texten igen eller låta Pianissimo försöka på nytt. Sedan raderas de automatiskt.

## Installera

Kräver en Mac med Apple Silicon (M1 eller senare) och macOS 14 eller senare.

Öppna **Terminal** och klistra in:

```bash
curl -fsSL https://raw.githubusercontent.com/angiestran/tala/main/install.sh | zsh
```

Tala byggs på din egen dator och läggs i Program. Första gången tar det några minuter. Saknas Apples utvecklarverktyg öppnas en ruta där du väljer **Installera**. Kör sedan kommandot igen.

När Tala startar visar ett startfönster tre steg:

1. **Hämta Klangs modell**, cirka 690 MB och bara en gång. Varje fil kontrolleras mot en fast kontrollsumma.
2. **Tillåt mikrofonen.**
3. **Slå på Tala under Hjälpmedel** (Systeminställningar → Integritet och säkerhet). Det behövs för att höger alt ska fungera överallt och för att texten ska kunna klistras in.

> Installerar du om eller uppdaterar Tala kan du behöva ta bort Tala under Hjälpmedel med − och lägga till den igen med +.

## Integritet

- Taligenkänningen körs lokalt på Macens Neural Engine. Inget ljud lämnar datorn.
- Nätet används bara en gång: för att hämta språkmodellen från Hugging Face.
- Inga konton, ingen analys, ingen spårning.
- Tala klistrar aldrig in i lösenordsfält och det du hade i urklipp läggs tillbaka.
- Dikteringar (text och ljud) sparas i högst två timmar i `~/Library/Application Support/Tala/Senaste` och raderas sedan.

## Bygga själv

```bash
git clone https://github.com/angiestran/tala.git
cd tala
scripts/build-app.sh
```

Tala är ett Swift-paket och byggs med Apples utvecklarverktyg (Xcode behövs inte).

## Tack

- **[Klang Pianissimo](https://huggingface.co/KlangAI/pianissimo-sv)** av Klang AI AB: svensk taligenkänning, CC BY 4.0. Finjusterad från NVIDIA Parakeet TDT 0.6B v3 (CC BY 4.0).
- **[Core ML-konvertering](https://huggingface.co/markstrom/pianissimo-sv-coreml)** av markstrom, CC BY 4.0.
- **[FluidAudio](https://github.com/FluidInference/FluidAudio)** av FluidInference, Apache 2.0. Kör modellen på Neural Engine.
- **[Mindtalk](https://github.com/dragon6sic6/Mindtalk)** (MIT): förteckningen över modellfiler och kontrollsummor.

Tala är en fristående app och är inte gjord eller supportad av Klang AI AB.

## Licens

Talas källkod: [MIT](LICENSE). Språkmodellerna ingår inte i koden och har sina egna licenser (se [NOTICE](NOTICE)).

Gjord av Angelika Strandberg.
