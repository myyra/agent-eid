# AgentEID

[English](README.md) · [Suomi](README.fi.md) · [Svenska](README.sv.md)

AgentEID is a native macOS application for Suomi.fi e-Identification using the [Citizen Certificate](https://dvv.fi/en/citizen-certificate-on-id-card) on a Finnish identity card. It supports agentic systems based on large language models (LLMs) undertaking activities that require strong electronic identification. For the purposes of this document, these systems are referred to as agents. Establishing the identity of the person concerned is treated as a prerequisite to proceeding with the matter.

The application connects a physical card and reader to macOS authentication facilities. An agent operating the browser can then proceed through Suomi.fi using the cardholder’s identity. The receiving service, accessed following Suomi.fi authentication, determines which activities are available to that identity.

## 1. Identity arrangements

The cardholder’s identity remains the basis of authentication throughout agent operation. Participation by an agent introduces no additional identity into the procedure.

An agent acting on the cardholder’s behalf carries out activities in the cardholder’s name. The cardholder remains responsible for the prompts given, the actions taken, and the submissions made. Delegation of the activity does not include delegation of its consequences.

The Citizen Certificate operates within the European electronic identification framework established by [Regulation (EU) No 910/2014 (eIDAS)](https://eur-lex.europa.eu/eli/reg/2014/910), as amended. [Suomi.fi identifies identity-card identification certificates issued by the Digital and Population Data Services Agency (DVV) as corresponding to assurance level high](https://kehittajille.suomi.fi/services/e-identification/service-description/eidas-regulation-frequently-asked-questions-about-cross-border-identification), with reference to the assurance framework specified in [Commission Implementing Regulation (EU) 2015/1502](https://eur-lex.europa.eu/eli/reg_impl/2015/1502/oj).

The conditions of operation are a Finnish identity card with an activated Citizen Certificate, a card reader, and the physical presence of the card in the connected reader. These conditions apply to both authentication methods described in Section 3. Agent participation does not vary the physical requirements.

AgentEID’s menu-bar interface provides a standing indication of card readiness and displays the cardholder’s name. Readiness concerns the availability of the card for authentication. Identification through Suomi.fi is completed separately.

## 2. Authentication procedure

Connect the reader to the Mac and insert the identity card into the reader. AgentEID detects the card and prepares it for authentication. Once the card is ready, select **Varmennekortti** in Suomi.fi and continue through the Suomi.fi login procedure.

Authentication uses the browser’s existing certificate facilities and AgentEID’s native CryptoTokenKit extension. No browser extension is required. The agent can operate the browser using its existing tools; AgentEID supplies the card authentication needed at the certificate authentication stage.

Successful authentication concludes the identification stage. The receiving service may then proceed with its own administrative process. Completion of the substantive matter is recorded there.

## 3. Provision for PIN1

PIN1 is the [basic PIN code](https://dvv.fi/en/activation-of-the-citizen-certificate) used for identification with the Citizen Certificate.

Two authentication methods are available in AgentEID’s application settings:

- **macOS PIN prompt.** The operating system requests PIN1 when authentication is needed. This is the default and requires human input at the time of authentication.
- **Saved PIN1.** AgentEID retrieves PIN1 from the macOS Keychain for the card being used. This permits authentication during agent operation without a separate request for PIN entry.

Provision for saved PIN1 is made only after successful verification against the connected identity card using the FINEID VERIFY operation (S1, §3.5). PIN1 is associated with the Authentication and Encryption Certificate of the identified card and retained in the user’s macOS Keychain on the specific Mac used for setup. This arrangement supports continuity of agent operation while retaining the existing card and reader requirements.

AgentEID’s application settings provide for replacement or removal of saved PIN1 and selection of the authentication method. Selecting the macOS PIN prompt leaves saved PIN1 in the Keychain for possible subsequent use. A failed authentication request using saved PIN1 concludes without an automatic PIN retry. Further attempts remain subject to resolution of the underlying cause.

## 4. Credential custody

The authentication private key remains on the identity card. Authentication signatures are produced through the card’s PERFORM SECURITY OPERATION: COMPUTE DIGITAL SIGNATURE command (S1, §3.8). With the Saved PIN1 method, PIN1 is retrieved by AgentEID’s authentication extension rather than supplied to the agent through the browser.

AgentEID registers public intermediate certificates in the user’s macOS Keychain so the browser can present the chain for the card’s Authentication and Encryption Certificate. AgentEID does not change certificate trust settings.

AgentEID’s responsibility concludes with authentication. Direction of the agent and supervision of subsequent activity remain with the party arranging the work.

## 5. Technical basis

The card interface is implemented with reference to the specifications published by DVV:

- [FINEID S1 — Electronic ID Application, v4.0](https://dvv.fi/documents/16079645/17324992/S1v40%2B%281%29.pdf/56a167fe-9f26-1fda-7d76-cfbbb29d184e): command interface, PIN verification, and private-key operations.
- [FINEID S4-1 — Implementation profile 1 for Finnish Electronic ID Card, v4.0](https://dvv.fi/documents/16079645/17324992/S4-1v40.pdf/55bddc08-6893-b4b4-73fa-24dced600198): the card’s application profile and cryptographic information layout.

The underlying framework includes ISO/IEC 7816-4 for interindustry commands, ISO/IEC 7816-8 for security-related commands, and ISO/IEC 7816-15 for cryptographic information. CryptoTokenKit provides the macOS transport and authentication integration. The implementation covers the operations necessary for the authentication scope stated in Section 6.

## 6. Operational scope

AgentEID requires macOS 15 or later and a Finnish identity card with an activated Citizen Certificate and an EC P-384 authentication key. AgentEID’s user interface is available in English, Finnish, and Swedish.

Citizen Certificate activation, PIN changes, unlocking locked PIN codes, electronic signing of documents, and older RSA-only authentication cards are outside AgentEID’s current scope.

### 6.1. Compatible readers

The reader must accept a full-size contact smart card (ISO/IEC 7816) and be available through macOS’s CryptoTokenKit interface. USB readers conforming to the CCID device class are the normal basis for this arrangement; [macOS provides native support for this class](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/web). AgentEID does not supply reader drivers or maintain a model-specific admission list.

For reader selection, look for **USB CCID**, **contact smart card**, and **macOS support** in the manufacturer’s specifications. An SD-card reader or a contactless-only NFC reader does not meet these requirements. The connected reader should appear in AgentEID’s menu-bar interface; card readiness is established after insertion of the identity card.

## 7. Verification record

Operational verification has been completed through live identification procedures and DVV’s certificate test service, using a physical identity card and a connected reader. Verification covered both PIN1 arrangements specified in Section 3 and included completion of the receiving service’s authentication procedure.

The results establish operational readiness for the stated purpose. Credential presentation, PIN verification, and completion of identification have been exercised under the applicable conditions of operation. No outstanding impediment to authentication was identified in the procedures conducted.

Verification of the identification stage does not extend to the disposition of the substantive matter. That outcome remains within the receiving service’s administrative process.

AgentEID is an independent project. It is intended for use with Suomi.fi and is not an official application of Suomi.fi or DVV.

## 8. Accessibility

The accessibility reference is [EN 301 549 V3.2.1 (2021-03)](https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf), the standard used in [Finland’s digital-service accessibility requirements](https://www.saavutettavuusvaatimukset.fi/en/requirements-act-provision-digital-services-0). Assessment concerns the applicable software provisions of Clause 11, including WCAG 2.1 Level A and AA criteria, and the documentation provisions of Clause 12. The scope is the AgentEID interface; the reader, browser, operating-system PIN prompt, and receiving service remain separate components of the procedure.

## 9. Licensing

AgentEID is made available under the [European Union Public Licence, Version 1.2 (EUPL)](LICENSE). Use, modification, and redistribution proceed under the terms of that licence. The [official language versions](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12) have equal legal value.
