# Agentidentifiering

[English](README.md) · [Suomi](README.fi.md) · [Svenska](README.sv.md)

Agentidentifiering är en nativ macOS-applikation för Suomi.fi-identifikation med [medborgarcertifikatet](https://dvv.fi/sv/medborgarcertifikat-pa-identitetskort) på ett finländskt identitetskort. Den stöder agentiska system baserade på stora språkmodeller (LLM) som utför uppgifter som kräver stark elektronisk identifiering. I detta dokument benämns dessa system agenter. Fastställande av den berörda personens identitet betraktas som en förutsättning för fortsatt handläggning av ärendet.

Applikationen förbinder ett fysiskt kort och en kortläsare med autentiseringsfunktionerna i macOS. En agent som använder webbläsaren kan därefter identifiera sig via Suomi.fi med kortinnehavarens identitet. Den e-tjänst som används efter Suomi.fi-identifikationen avgör vilka åtgärder som är tillgängliga för den berörda personen.

## 1. Arrangemang avseende identitet

Kortinnehavarens identitet förblir grunden för autentisering under hela agentens verksamhet. En agents deltagande tillför inte någon ytterligare identitet till förfarandet.

En agent som agerar för kortinnehavarens räkning utför åtgärder i kortinnehavarens namn. Kortinnehavaren ansvarar fortfarande för de promptar som ges, de åtgärder som vidtas och de uppgifter som lämnas in. Delegering av verksamheten omfattar inte delegering av dess konsekvenser.

Medborgarcertifikatet används inom den europeiska ramen för elektronisk identifiering som fastställs i [förordning (EU) nr 910/2014 (eIDAS)](https://eur-lex.europa.eu/eli/reg/2014/910), med ändringar. [Suomi.fi anger att identifieringscertifikat på identitetskort utfärdade av Myndigheten för digitalisering och befolkningsdata (MDB) motsvarar tillitsnivån hög](https://kehittajille.suomi.fi/services/e-identification/service-description/eidas-regulation-frequently-asked-questions-about-cross-border-identification), med hänvisning till ramen för tillitsnivåer i [kommissionens genomförandeförordning (EU) 2015/1502](https://eur-lex.europa.eu/eli/reg_impl/2015/1502/oj).

Förutsättningarna för verksamheten är ett finländskt identitetskort med ett aktiverat medborgarcertifikat, en kortläsare samt kortets fysiska närvaro i den anslutna kortläsaren. Dessa förutsättningar gäller båda autentiseringsmetoderna som beskrivs i avsnitt 3. Agentens deltagande förändrar inte de fysiska förutsättningarna.

Agentidentifierings gränssnitt i menyraden ger en fortlöpande indikation på kortets beredskap och visar kortinnehavarens namn. Beredskapen avser kortets tillgänglighet för autentisering. Identifieringen via Suomi.fi slutförs separat.

## 2. Autentiseringsförfarande

Anslut kortläsaren till datorn och sätt identitetskortet i kortläsaren. Agentidentifiering upptäcker kortet och förbereder det för autentisering. När kortet är klart, välj **Certifikatkort** i Suomi.fi och fortsätt enligt Suomi.fi:s inloggningsförfarande.

Autentiseringen använder webbläsarens befintliga certifikatfunktioner och Agentidentifierings nativa CryptoTokenKit-tillägg. Inget webbläsartillägg krävs. Agenten kan använda webbläsaren med sina befintliga verktyg; Agentidentifiering tillhandahåller den kortautentisering som behövs vid certifikatautentiseringen.

En lyckad autentisering avslutar identifieringsfasen. Den mottagande e-tjänsten kan därefter fortsätta med sitt eget administrativa förfarande. Slutförandet av det egentliga ärendet registreras där.

## 3. Arrangemang för PIN1

PIN1 är den [baskod](https://dvv.fi/sv/medborgarcertifikatet) som används för identifiering med medborgarcertifikatet.

Två autentiseringsmetoder finns tillgängliga i Agentidentifierings applikationsinställningar:

- **PIN-dialogrutan i macOS.** Operativsystemet begär PIN1 när autentisering behövs. Detta är standardmetoden och kräver mänsklig inmatning vid autentiseringstillfället.
- **Sparad PIN1.** Agentidentifiering hämtar PIN1 för det kort som används från nyckelringen i macOS. Detta möjliggör autentisering under agentens verksamhet utan en separat begäran om PIN-inmatning.

PIN1 kan sparas först efter en lyckad kontroll mot det anslutna identitetskortet med FINEID VERIFY-operationen (S1, §3.5). PIN1 knyts till det identifierade kortets verifierings- och krypteringscertifikat och förvaras i användarens macOS-nyckelring på den specifika Mac som användes vid konfigurationen. Detta arrangemang stöder kontinuiteten i agentens verksamhet samtidigt som kraven på kort och kortläsare kvarstår.

Agentidentifierings applikationsinställningar medger byte eller borttagning av sparad PIN1 samt val av autentiseringsmetod. Om PIN-dialogrutan i macOS väljs förblir sparad PIN1 i nyckelringen för eventuell senare användning. En misslyckad autentiseringsbegäran med sparad PIN1 avslutas utan ett automatiskt nytt PIN-försök. Ytterligare försök förutsätter att den bakomliggande orsaken åtgärdas.

## 4. Förvaring av autentiseringsuppgifter

Den privata autentiseringsnyckeln förblir på identitetskortet. Autentiseringssignaturer skapas med kortets kommando PERFORM SECURITY OPERATION: COMPUTE DIGITAL SIGNATURE (S1, §3.8). Med metoden Sparad PIN1 hämtas PIN1 av Agentidentifierings autentiseringstillägg i stället för att lämnas till agenten via webbläsaren.

Agentidentifiering registrerar offentliga mellanliggande certifikat i användarens macOS-nyckelring så att webbläsaren kan presentera kedjan för kortets verifierings- och krypteringscertifikat. Agentidentifiering ändrar inte certifikatens tillitsinställningar.

Agentidentifierings ansvar upphör vid autentisering. Styrning av agenten och övervakning av efterföljande verksamhet förblir hos den part som ordnar arbetet.

## 5. Teknisk grund

Kortgränssnittet har implementerats med utgångspunkt i de specifikationer som MDB har publicerat:

- [FINEID S1 — Electronic ID Application, v4.0](https://dvv.fi/documents/16079645/17324992/S1v40%2B%281%29.pdf/56a167fe-9f26-1fda-7d76-cfbbb29d184e): kommandogränssnitt, PIN-kontroll och operationer med den privata nyckeln.
- [FINEID S4-1 — Implementation profile 1 for Finnish Electronic ID Card, v4.0](https://dvv.fi/documents/16079645/17324992/S4-1v40.pdf/55bddc08-6893-b4b4-73fa-24dced600198): kortets applikationsprofil och struktur för kryptografisk information.

Den underliggande ramen omfattar ISO/IEC 7816-4 för branschoberoende kommandon, ISO/IEC 7816-8 för säkerhetsrelaterade kommandon och ISO/IEC 7816-15 för kryptografisk information. CryptoTokenKit tillhandahåller kortkommunikation och autentiseringsintegration i macOS. Implementationen omfattar de operationer som behövs inom det tillämpningsområde för autentisering som anges i avsnitt 6.

## 6. Verksamhetens tillämpningsområde

Agentidentifiering kräver macOS 15 eller senare samt ett finländskt identitetskort med ett aktiverat medborgarcertifikat och en autentiseringsnyckel av typen EC P-384. Agentidentifierings användargränssnitt finns på engelska, finska och svenska.

Aktivering av medborgarcertifikatet, byte av PIN-koder, upplåsning av låsta PIN-koder, elektronisk signering av dokument samt äldre kort som endast stöder RSA-autentisering faller utanför Agentidentifierings nuvarande tillämpningsområde.

### 6.1. Kompatibla kortläsare

Kortläsaren ska ta emot ett kontaktbaserat smartkort i full storlek (ISO/IEC 7816) och vara tillgänglig via CryptoTokenKit-gränssnittet i macOS. USB-läsare som följer enhetsklassen CCID utgör den normala grunden för detta arrangemang; [macOS har inbyggt stöd för denna enhetsklass](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/web). Agentidentifiering tillhandahåller inga drivrutiner för kortläsare och upprätthåller ingen modellspecifik förteckning över godkända läsare.

Vid val av kortläsare ska **USB CCID**, **stöd för kontaktbaserade smartkort** och **macOS-stöd** framgå av tillverkarens specifikationer. En SD-kortläsare eller en NFC-läsare som endast stöder kontaktlös kommunikation uppfyller inte dessa förutsättningar. Den anslutna läsaren ska visas i Agentidentifierings gränssnitt i menyraden; kortets beredskap fastställs efter att identitetskortet har satts in.

## 7. Redovisning av verifiering

Den operativa verifieringen har genomförts genom faktiska identifieringsförfaranden och MDB:s testtjänst för certifikat, med ett fysiskt identitetskort och en ansluten kortläsare. Verifieringen omfattade båda PIN1-arrangemangen som anges i avsnitt 3 och slutförandet av den mottagande e-tjänstens autentiseringsförfarande.

Resultaten fastställer operativ beredskap för det angivna ändamålet. Presentation av certifikat, PIN-kontroll och slutförande av identifiering har genomförts under de tillämpliga förutsättningarna för verksamheten. Inga kvarstående hinder för autentisering konstaterades i de genomförda förfarandena.

Verifieringen av identifieringsfasen omfattar inte avgörandet av det egentliga ärendet. Detta resultat förblir en del av den mottagande e-tjänstens administrativa förfarande.

Agentidentifiering är ett fristående projekt. Det är avsett att användas med Suomi.fi och är inte en officiell applikation från Suomi.fi eller MDB.

## 8. Tillgänglighet

Referensen för tillgänglighet är [EN 301 549 V3.2.1 (2021-03)](https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf), den standard som används i [Finlands tillgänglighetskrav för digitala tjänster](https://saavutettavuusvaatimukset.fi/sv/krav-aktorer-enligt-lagen-om-tillhandahallande-av-digitala-tjanster). Bedömningen avser de tillämpliga programvarukraven i avsnitt 11, inklusive kriterierna på nivå A och AA i WCAG 2.1, samt dokumentationskraven i avsnitt 12. Bedömningen omfattar Agentidentifierings gränssnitt; kortläsaren, webbläsaren, operativsystemets PIN-dialogruta och den mottagande e-tjänsten utgör separata delar av förfarandet.

## 9. Licens

Agentidentifiering tillhandahålls enligt [Licens till öppen källkod från Europeiska unionen, version 1.2 (EUPL)](LICENSE). Användning, ändring och spridning av programvaran sker enligt licensens villkor. De [officiella språkversionerna](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12) är likvärdiga.
