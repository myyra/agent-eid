# Agenttitunnistus

[English](README.md) · [Suomi](README.fi.md) · [Svenska](README.sv.md)

Agenttitunnistus on macOS:lle kehitetty sovellus, jolla voidaan tunnistautua Suomi.fi-palveluun suomalaisen henkilökortin [kansalaisvarmenteella](https://dvv.fi/kansalaisvarmenne-henkilokortilla). Se tukee suuriin kielimalleihin (LLM) perustuvia agenttisia järjestelmiä tehtävissä, jotka edellyttävät vahvaa sähköistä tunnistamista. Tässä asiakirjassa näistä järjestelmistä käytetään nimitystä agentti. Asianomaisen henkilöllisyyden toteamista pidetään edellytyksenä asian käsittelyn jatkamiselle.

Sovellus yhdistää fyysisen kortin ja kortinlukijan macOS:n tunnistautumistoimintoihin. Selainta käyttävä agentti voi tämän jälkeen tunnistautua Suomi.fi-palvelussa kortinhaltijan henkilöllisyydellä. Suomi.fi-tunnistautumisen jälkeen käytettävä asiointipalvelu määrittää, mitkä toiminnot ovat kyseisen henkilön käytettävissä.

## 1. Henkilöllisyyttä koskevat järjestelyt

Kortinhaltijan henkilöllisyys säilyy tunnistautumisen perusteena koko agentin toiminnan ajan. Agentin osallistuminen ei tuo menettelyyn uutta henkilöllisyyttä.

Kortinhaltijan puolesta toimiva agentti suorittaa toimenpiteitä kortinhaltijan nimissä. Kortinhaltija vastaa edelleen annetuista kehotteista, suoritetuista toimenpiteistä ja toimitetuista tiedoista. Tehtävien antaminen agentin hoidettavaksi ei siirrä vastuuta toiminnan seurauksista.

Kansalaisvarmenne toimii eurooppalaisessa sähköisen tunnistamisen kehyksessä, joka perustuu [asetukseen (EU) N:o 910/2014 (eIDAS)](https://eur-lex.europa.eu/eli/reg/2014/910) muutoksineen. [Suomi.fi katsoo Digi- ja väestötietoviraston (DVV) myöntämät henkilökortin tunnistusvarmenteet korkeaa varmuustasoa vastaaviksi](https://kehittajille.suomi.fi/palvelut/tunnistus/palvelukuvaus/eidas-saantely-ja-rajat-ylittava-tunnistaminen). Varmuustasoja koskeva kehys on määritelty [komission täytäntöönpanoasetuksessa (EU) 2015/1502](https://eur-lex.europa.eu/eli/reg_impl/2015/1502/oj).

Toiminnan edellytyksiä ovat suomalainen henkilökortti, jonka kansalaisvarmenne on aktivoitu, kortinlukija sekä kortin fyysinen läsnäolo liitetyssä lukijassa. Nämä edellytykset koskevat molempia kohdassa 3 kuvattuja tunnistautumismenetelmiä. Agentin osallistuminen ei muuta fyysisiä edellytyksiä.

Agenttitunnistuksen valikkorivikäyttöliittymä ilmoittaa jatkuvasti kortin käyttövalmiuden ja näyttää kortinhaltijan nimen. Käyttövalmiudella tarkoitetaan kortin saatavuutta tunnistautumista varten. Henkilöllisyyden todentaminen Suomi.fi-palvelussa suoritetaan erikseen.

## 2. Tunnistautumismenettely

Liitä kortinlukija Maciin ja aseta henkilökortti lukijaan. Agenttitunnistus havaitsee kortin ja valmistelee sen tunnistautumista varten. Kun kortti on käyttövalmis, valitse Suomi.fi-palvelussa **Varmennekortti** ja jatka Suomi.fi-palvelun kirjautumismenettelyä.

Tunnistautumisessa käytetään selaimen olemassa olevia varmennetoimintoja ja Agenttitunnistuksen CryptoTokenKit-laajennusta. Selainlaajennusta ei tarvita. Agentti voi käyttää selainta olemassa olevilla työkaluillaan; Agenttitunnistus huolehtii kortilla tunnistautumisesta varmennetunnistautumisen vaiheessa.

Onnistunut tunnistautuminen päättää henkilöllisyyden todentamisen vaiheen. Asiointipalvelu voi tämän jälkeen jatkaa omaa hallinnollista menettelyään. Varsinaisen asian valmistuminen kirjataan asiointipalvelussa.

## 3. PIN1-tunnuslukua koskevat järjestelyt

PIN1 on [perustunnusluku](https://dvv.fi/kansalaisvarmenne), jota käytetään kansalaisvarmenteella tunnistautumiseen.

Agenttitunnistuksen asetuksissa on käytettävissä kaksi tunnistautumismenetelmää:

- **macOS:n PIN-kysely.** Käyttöjärjestelmä pyytää PIN1-tunnusluvun, kun tunnistautumista tarvitaan. Tämä on oletusmenetelmä, ja se edellyttää, että käyttäjä syöttää tunnusluvun tunnistautumishetkellä.
- **Tallennettu PIN1.** Agenttitunnistus hakee käytettävän kortin PIN1-tunnusluvun macOS:n avainnipusta. Tämä mahdollistaa tunnistautumisen agentin toiminnan aikana ilman erillistä tunnusluvun syöttöpyyntöä.

PIN1 voidaan tallentaa vasta, kun tunnusluku on onnistuneesti tarkistettu lukijassa olevalla henkilökortilla FINEID VERIFY -toiminnolla (S1, §3.5). PIN1 liitetään yksilöidyn kortin tunnistus- ja salausvarmenteeseen ja säilytetään käyttäjän macOS-avainnipussa sillä nimenomaisella Macilla, jolla käyttöönotto suoritettiin. Järjestely tukee agentin toiminnan jatkuvuutta muuttamatta korttia ja lukijaa koskevia edellytyksiä.

Agenttitunnistuksen asetuksissa voidaan korvata tai poistaa tallennettu PIN1 ja valita tunnistautumismenetelmä. Kun tunnistautumismenetelmäksi valitaan macOS:n PIN-kysely, tallennettu PIN1-tunnusluku säilyy avainnipussa mahdollista myöhempää käyttöä varten. Epäonnistunut tunnistautumispyyntö tallennetulla PIN1-tunnusluvulla päättyy ilman tunnusluvun automaattista uudelleensyöttöä. Lisäyritykset edellyttävät epäonnistumisen syyn korjaamista.

## 4. Tunnistautumistietojen säilytys

Tunnistautumiseen käytettävä yksityinen avain säilyy henkilökortilla. Tunnistautumisessa käytettävät allekirjoitukset tuotetaan kortin PERFORM SECURITY OPERATION: COMPUTE DIGITAL SIGNATURE -komennolla (S1, §3.8). Tallennettu PIN1 -menetelmässä Agenttitunnistuksen tunnistautumislaajennus hakee PIN1-tunnusluvun sen sijaan, että se toimitettaisiin agentille selaimen kautta.

Agenttitunnistus rekisteröi julkiset välivarmenteet käyttäjän macOS-avainnippuun, jotta selain voi esittää kortin tunnistus- ja salausvarmenteen varmenneketjun. Agenttitunnistus ei muuta varmenteiden luottamusasetuksia.

Agenttitunnistuksen vastuu päättyy tunnistautumiseen. Agentin ohjaus ja myöhemmän toiminnan valvonta jäävät toiminnan järjestävän tahon vastuulle.

## 5. Tekninen perusta

Korttirajapinta on toteutettu DVV:n julkaisemien määritysten pohjalta:

- [FINEID S1 — Electronic ID Application, v4.0](https://dvv.fi/documents/16079645/17324992/S1v40%2B%281%29.pdf/56a167fe-9f26-1fda-7d76-cfbbb29d184e): komentorajapinta, tunnusluvun tarkistus ja yksityisen avaimen toiminnot.
- [FINEID S4-1 — Implementation profile 1 for Finnish Electronic ID Card, v4.0](https://dvv.fi/documents/16079645/17324992/S4-1v40.pdf/55bddc08-6893-b4b4-73fa-24dced600198): kortin sovellusprofiili ja salausteknisten tietojen rakenne.

Taustalla oleviin standardeihin kuuluvat toimialariippumattomia komentoja koskeva ISO/IEC 7816-4, turvallisuuteen liittyviä komentoja koskeva ISO/IEC 7816-8 ja salausteknisiä tietoja koskeva ISO/IEC 7816-15. CryptoTokenKit huolehtii macOS:n korttiviestinnästä ja tunnistautumisen integroinnista. Toteutus kattaa kohdassa 6 määritellyn tunnistautumisen soveltamisalan edellyttämät toiminnot.

## 6. Toiminnan soveltamisala

Agenttitunnistus edellyttää macOS 15:tä tai uudempaa sekä suomalaista henkilökorttia, jonka kansalaisvarmenne on aktivoitu ja jonka tunnistautumisavain on EC P-384. Agenttitunnistuksen käyttöliittymä on saatavilla englanniksi, suomeksi ja ruotsiksi.

Kansalaisvarmenteen aktivointi, tunnuslukujen vaihtaminen, lukkiutuneiden tunnuslukujen avaaminen, asiakirjojen sähköinen allekirjoittaminen ja vanhemmat, vain RSA-tunnistautumista tukevat kortit eivät kuulu Agenttitunnistuksen nykyiseen soveltamisalaan.

### 6.1. Yhteensopivat kortinlukijat

Lukijan on tuettava täysikokoisia kontaktillisia älykortteja (ISO/IEC 7816) ja oltava käytettävissä macOS:n CryptoTokenKit-rajapinnan kautta. CCID-laiteluokan mukaiset USB-lukijat muodostavat järjestelyn tavanomaisen perustan; [macOS sisältää tuen tälle laiteluokalle](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/web). Agenttitunnistus ei toimita lukija-ajureita eikä ylläpidä mallikohtaista hyväksymisluetteloa.

Lukijaa valittaessa valmistajan teknisistä tiedoista tulee käydä ilmi **USB CCID**, **kontaktillisten älykorttien tuki** ja **macOS-tuki**. SD-muistikortinlukija tai pelkästään kontaktiton NFC-lukija ei täytä näitä edellytyksiä. Liitetyn lukijan tulee näkyä Agenttitunnistuksen valikkorivikäyttöliittymässä; kortin käyttövalmius todetaan henkilökortin asettamisen jälkeen.

## 7. Todentamista koskevat tiedot

Toiminnan todentaminen on suoritettu varsinaisissa tunnistautumismenettelyissä ja DVV:n varmenteiden testipalvelussa fyysisellä henkilökortilla ja liitetyllä kortinlukijalla. Todentaminen kattoi molemmat kohdassa 3 määritellyt PIN1-järjestelyt ja asiointipalvelun tunnistautumismenettelyn loppuun saattamisen.

Tulokset osoittavat toimintavalmiuden ilmoitettuun käyttötarkoitukseen. Varmenteen esittäminen, tunnusluvun tarkistus ja henkilöllisyyden todentamisen loppuun saattaminen on toteutettu sovellettavien toimintaedellytysten mukaisesti. Suoritetuissa menettelyissä ei todettu ratkaisematta olevia esteitä tunnistautumiselle.

Henkilöllisyyden todentamisen vaiheen varmentaminen ei ulotu varsinaisen asian ratkaisemiseen. Tämä lopputulos kuuluu edelleen asiointipalvelun hallinnolliseen menettelyyn.

Agenttitunnistus on itsenäinen projekti. Se on tarkoitettu käytettäväksi Suomi.fi-palvelun kanssa, eikä se ole Suomi.fi-palvelun tai DVV:n virallinen sovellus.

## 8. Saavutettavuus

Saavutettavuuden viitekehyksenä käytetään [EN 301 549 V3.2.1 (2021-03) -standardia](https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf), johon [Suomen digitaalisten palvelujen saavutettavuusvaatimukset](https://www.saavutettavuusvaatimukset.fi/fi/digipalvelulain-vaatimukset-toimijoille) perustuvat. Arviointi koskee luvun 11 sovellettavia ohjelmistovaatimuksia, mukaan lukien WCAG 2.1 -ohjeistuksen A- ja AA-tason kriteerit, sekä luvun 12 dokumentaatiovaatimuksia. Arvioinnin kohteena on Agenttitunnistuksen käyttöliittymä; kortinlukija, selain, käyttöjärjestelmän PIN-kysely ja asiointipalvelu ovat menettelyn erillisiä osia.

## 9. Lisensointi

Agenttitunnistus on saatavilla [Euroopan unionin yleisen lisenssin version 1.2 (EUPL)](LICENSE) mukaisesti. Ohjelmiston käyttöön, muunteluun ja levittämiseen sovelletaan lisenssin ehtoja. [Virallisilla kieliversioilla](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12) on sama oikeudellinen arvo.
