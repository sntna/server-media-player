# What App Store and platform rules require of v1

Research for [#46](https://github.com/sntna/server-media-player/issues/46). Sources were checked on 2026-11-07.
Context: the app is free on the public tvOS App Store, our code is MPL-2.0, and the app collects no analytics.

## Summary

- Nothing in the rules blocks v1. The closest precedent, Swiftfin, is MPL-2.0, free, runs on tvOS and is on the App Store. Its tvOS build ships with ATS fully disabled and declares "Data Not Collected".
- To pass review we need: a name that is not "Jellyfin", "Jelly…" or "…fin"; a reviewer server and account that we run and keep online; a privacy policy URL that is also readable inside the app; a `PrivacyInfo.xcprivacy` that declares our required-reason APIs; and a written justification for an ATS exception.
- The choice of TLS stack in the Rust core sets the export-compliance answer. OS-provided TLS needs no documentation. A bundled stack such as rustls or OpenSSL triggers a French encryption declaration if we sell in France.
- tvOS has no local network privacy prompt, so LAN discovery on tvOS needs no usage string and no multicast entitlement. iOS and macOS ports will need both.
- MPL-2.0 is compatible with App Store distribution. GPL code is not safe to ship. LGPL engines such as VLCKit and libmpv need care, which matters for the open player-engine decision.

## Rules and the obligations they create for v1

### 1. Reviewers must be able to sign in to a live backend (Guideline 2.1)

**Rule.** Submissions must "include demo account info (and turn on your back-end service!) if your app includes a login". A built-in demo mode is allowed instead only "with prior approval by Apple". The App Review "Sign-in required" field holds a demo account that "must not expire", and anything else needed for testing goes in Notes (up to 4000 bytes).
[Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness), [App Review information reference](https://developer.apple.com/help/app-store-connect/reference/app-review-information)

**Obligation for v1.**
- Run a reviewer Jellyfin server on a public HTTPS URL. Stock it with synthetic or public-domain media, including at least one item that direct-plays and one that needs a transcode, and keep it up for the whole review window.
- Put the server URL, username and password in App Review information, with step-by-step notes on how to add a server.
- Do not depend on Jellyfin's public demo server. It exists: `https://demo.jellyfin.org/stable/System/Info/Public` answered on 2026-11-07, and its user `demo` has a password. But we do not control its uptime or its credentials, and the password is **unconfirmed** because no Jellyfin page we found publishes it.

### 2. Minimum functionality: an empty app until you add a server (Guideline 4.2)

**Rule.** An app must offer "features, content, and UI that elevate it beyond a repackaged website" and provide "lasting entertainment value or adequate utility".
[Guidelines 4.2](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)

**Obligation for v1.** This is a low risk because the app is a native player with real playback, and Swiftfin and Infuse were both approved with the same "bring your own server" model ([Swiftfin listing](https://apps.apple.com/us/app/swiftfin/id1604098728), [Infuse listing](https://apps.apple.com/us/app/infuse-video-player/id1136220934)).
- The first-run screen must say plainly that a Jellyfin server is required.
- The App Store description must say so too. Swiftfin's listing does: it "can't be used without" a server.

### 3. Account sign-in and account deletion (Guideline 5.1.1(v))

**Rule.** "If your app supports account creation, you must also offer account deletion within the app."
[Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

**Obligation for v1.**
- Do not build account creation. Jellyfin accounts are created by the server admin, not by us, so in-app account deletion should not be triggered. That reading is ours, not Apple's text, so treat it as **unconfirmed**.
- Provide "sign out" and "remove server", and make them clear stored tokens from the Keychain.

### 4. Intellectual property, trademarks and naming (Guidelines 5.2.1, 4.1(c), 2.3.7; Jellyfin branding policy)

**Rule (Apple).**
- "Don't use protected third-party material such as trademarks … without permission" (5.2.1).
- "You cannot use another developer's icon, brand, or product name in your app's icon or name, without approval" (4.1(c)).
- Don't pack metadata with trademarked terms (2.3.7).
- App names are limited to 30 characters (2.3.7).

[Guidelines 5.2.1, 4.1, 2.3.7](https://developer.apple.com/app-store/review/guidelines/)

**Rule (Jellyfin).** Quoted from the branding policy:
- "The name 'Jellyfin' is reserved for the Jellyfin project itself and its official clients."
- "3rd party developers should not use the name Jellyfin directly."
- The project discourages "Jelly[word]" and "[word]fin" names.
- "You may reference Jellyfin in a subtitle, description, etc. as an indication of interoperability", with the example "Floostream, a Jellyfin client".
- "Do not use the Jellyfin logo as your logo". The colour gradient is allowed with a unique logo shape.
- "Do not use the Jellyfin name in the promotion of piracy".

[Jellyfin branding policy](https://jellyfin.org/docs/general/contributing/branding/)

**Obligation for v1.**
- Choose a unique name, at most 30 characters, that is not "Jellyfin", not "Jelly…" and not "…fin".
- Use "Jellyfin" only in the subtitle or description, as in "a Jellyfin client".
- Design our own icon. Do not use the Jellyfin logo.
- Swiftfin can be the exception because it is hosted under the `jellyfin` GitHub org and its listing calls it an official Jellyfin companion app ([repo](https://github.com/jellyfin/Swiftfin), [listing](https://apps.apple.com/us/app/swiftfin/id1604098728)). We are not an official client.
- Naming the app is a product decision. This document does not make it.

### 5. Third-party content and piracy (Guidelines 5.2.2, 5.2.3)

**Rule.**
- Apps that display content from a third-party service must be permitted to do so under its terms (5.2.2).
- Apps "should not facilitate illegal file sharing" or download media from third-party sources without authorization (5.2.3).

[Guidelines 5.2.2, 5.2.3](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)

**Obligation for v1.**
- Do not show screenshots of copyrighted films or shows: use public-domain or open movies (Blender open movies, for example) in screenshots and on the reviewer server.
- Describe the app as a player for the user's own media. Do not ship or link to content sources.
- Jellyfin is user-hosted GPL software with no terms of service that restrict clients, so 5.2.2 should not bite. This is **unconfirmed**: Apple has not said so explicitly.
- Infuse openly lists Plex, Emby and Jellyfin in its description, which is evidence that naming the server for interoperability is accepted ([Infuse listing](https://apps.apple.com/us/app/infuse-video-player/id1136220934)).

### 6. App Transport Security for plain-HTTP and self-signed LAN servers

**Rule.**
- ATS requires HTTPS for connections made through the URL Loading System, meaning `URLSession` ([NSAppTransportSecurity](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity)).
- ATS "doesn't apply to calls your app makes to lower-level networking interfaces like the Network framework" or CFNetwork ([Preventing insecure network connections](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)).
- `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia` and `NSExceptionAllowsInsecureHTTPLoads` "require justification" and "might trigger additional App Store review". One example justification Apple lists as eligible: "The app must connect to a server managed by another entity that doesn't support secure connections" ([same page](https://developer.apple.com/documentation/security/preventing-insecure-network-connections#Provide-Justification-for-Exceptions)).
- `NSAllowsLocalNetworking` covers `.local` names, unqualified names and IP addresses without needing a justification. Since iOS 17 and macOS 14, ATS blocks IP-address connections by default ([NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)).
- `NSAllowsArbitraryLoadsForMedia` covers AVFoundation media without affecting `URLSession` ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowsarbitraryloadsformedia)).
- With ATS enabled, an app cannot loosen server trust evaluation, for example to accept a self-signed certificate. It can only tighten it ([Preventing insecure network connections](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)).

**Precedent.** Swiftfin's tvOS `Info.plist` sets `NSAllowsArbitraryLoads = true` and has no other ATS keys, and the app is approved ([Swiftfin tvOS Info.plist @ 5789301](https://github.com/jellyfin/Swiftfin/blob/57893014a592ab2566a9027b0970d9e3f27d5856/Swiftfin%20tvOS/Resources/Info.plist)).

**Obligation for v1.**
- Self-hosted servers are often reached over plain HTTP or by LAN IP, and we cannot enumerate their hosts. So v1 needs a global exception: `NSAllowsArbitraryLoads`, or more narrowly `NSAllowsLocalNetworking` plus `NSAllowsArbitraryLoadsForMedia`.
- Write the justification in review notes: "the app connects to user-operated media servers whose address and TLS setup we do not control".
- Show a "connection is not encrypted" warning in the UI when the user enters an `http://` URL.
- The Rust core's own HTTP client is outside ATS, because it is not `URLSession`. AVPlayer and any Swift `URLSession` image loading are inside ATS. The exception must cover whichever of those we use.
- Accepting a self-signed certificate is not possible through `URLSession` or AVPlayer while ATS is on. It would need ATS off plus custom trust handling, and whether AVPlayer honours custom trust is **unconfirmed**. Recommendation: v1 supports valid HTTPS and plain HTTP, and self-signed certificates are a later issue.
- **Unconfirmed:** Apple's documentation pages for the ATS keys list iOS, iPadOS, macOS and visionOS but not tvOS. We have not found an Apple page that states the tvOS defaults, such as whether tvOS 17 and later also block IP addresses. Swiftfin's tvOS plist shows that the keys are accepted in a tvOS app. Verify on a device in the macOS CI or a manual test.

### 7. Local network privacy and LAN discovery

**Rule.**
- Apple's platform table says tvOS does **not** support local network privacy. iOS, iPadOS, visionOS and macOS 15 do ([TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)).
- On the platforms that have it, apps that use the LAN need `NSLocalNetworkUsageDescription`, list the Bonjour types they browse in `NSBonjourServices`, and on iOS need the Apple-approved `com.apple.developer.networking.multicast` entitlement to send broadcast or multicast traffic ([TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [multicast entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast)).
- The multicast entitlement's documentation lists only iOS, iPadOS and visionOS.

**How Jellyfin discovery works.** The server listens on UDP port 7359 for a "who is JellyfinServer?" broadcast ([AutoDiscoveryHost.cs](https://github.com/jellyfin/jellyfin/blob/master/src/Jellyfin.Networking/AutoDiscoveryHost.cs)).

**Precedent.** Swiftfin's tvOS plist has no local network usage string. Its iOS plist has one ([iOS Info.plist](https://github.com/jellyfin/Swiftfin/blob/main/Swiftfin/Resources/Info.plist)).

**Obligation for v1.**
- On tvOS, nothing extra: no prompt, no usage string and no entitlement.
- Still let users type a server URL by hand, because broadcast discovery fails on many networks.
- Keep discovery in `core`, and record in `docs/` that iOS and macOS ports will need the usage string. The iOS port will also need the multicast entitlement, which requires Apple's approval and takes lead time.
- Whether a UDP broadcast from a tvOS app works with no entitlement at all is **unconfirmed** beyond the absence of tvOS from the entitlement's platform list. Spike it on a device.

### 8. Privacy policy, privacy label and the "Data Not Collected" declaration (Guideline 5.1.1; App Privacy Details)

**Rule.**
- "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner" ([5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)).
- App Privacy Details lists the privacy policy URL as "Required".
- Apple defines "collect" as transmitting data off the device "in a way that allows you and/or your third-party partners to access it for longer than … necessary to service the transmitted request in real time". Data processed only on the device is not collected ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).

**Precedent.** Swiftfin's listing says "The developer does not collect any data from this app" ([listing](https://apps.apple.com/us/app/swiftfin/id1604098728)).

**Obligation for v1.**
- Answer "Data Not Collected" in App Store Connect.
- Publish a short privacy policy at a stable URL, for example a page in the repo or on GitHub Pages. It should say: no data is collected by the developer; credentials and playback reports go only to the server the user configures; and the policy covers retention and deletion, meaning that removing the server or the app removes local data.
- tvOS has no browser, so show the policy text inside the app, for example under Settings > Privacy, as well as linking it.
- Do not add any crash reporter or analytics SDK, because that would change the label. Apple's own crash reports are not ours to disclose: "You are not responsible for disclosing data collected by Apple" ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).
- Jellyfin playback reporting goes to the user's own server, not to us or a partner of ours, so it is not "collection" under Apple's definition. That is our reading; Apple's page does not address user-operated servers explicitly, so it is **unconfirmed**.

### 9. Privacy manifest and required-reason APIs

**Rule.**
- Apps and SDKs record the data they collect and the required-reason APIs they use in `PrivacyInfo.xcprivacy`. The required-reason part applies on tvOS ([Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)).
- Since May 1, 2024, App Store Connect rejects uploads that use required-reason APIs without declaring them. Each executable or dynamic library that uses them needs a manifest in its bundle ([Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)).
- The covered APIs include:
  - file timestamps: `fstat`, `fstatat`, `lstat`, `getattrlist` and related calls;
  - system boot time: `mach_absolute_time`, `systemUptime`;
  - disk space: `statfs`, `statvfs` and related calls;
  - `UserDefaults`.

  The reasons that fit us are `C617.1` (metadata of files in the app container), `35F9.1` (elapsed time between events in the app), `E174.1` (check disk space before writing files) and `CA92.1` (user defaults private to the app) ([NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)).

**Precedent.** Swiftfin's manifest declares only `UserDefaults` (`CA92.1`) and file timestamp (`C617.1`) ([PrivacyInfo.xcprivacy](https://github.com/jellyfin/Swiftfin/blob/main/Shared/Resources/PrivacyInfo.xcprivacy)).

**Obligation for v1.**
- Ship `PrivacyInfo.xcprivacy` in the app with `NSPrivacyTracking = false`, no collected data types, and the API reasons we actually use.
- The Rust core will very likely hit file-timestamp APIs: Rust std file metadata calls and SQLite's VFS. If it measures elapsed time with `std::time::Instant`, it hits boot-time APIs too, because that uses `mach_absolute_time` on Apple platforms. That last point is our expectation, not something we verified, so it is **unconfirmed**.
- Audit the linked binary symbols before submission, and add a manifest to any dynamic framework we ship, such as a UniFFI XCFramework built as dynamic.
- Recording a disk-space check (`E174.1`) for the bounded image cache, if we add one, is an engineering decision.

### 10. Export compliance (encryption)

**Rule.**
- Using HTTPS is an export of encryption. App Store Connect asks about it on every upload unless `ITSAppUsesNonExemptEncryption` is set in `Info.plist` ([Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)).
- Apple's documentation table has three cases:
  - "encryption limited to that within the Apple operating system": no documentation required;
  - "an industry standard algorithm, not provided within the Apple operating system": upload a French encryption declaration, required "only if you're distributing your app on the App Store in France";
  - proprietary algorithms: CCATS plus the French declaration.

  ([Export compliance documentation for encryption](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption))
- Apps using exempt encryption may need a US year-end self-classification report ([same Apple page](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)).

**Precedent.** Swiftfin's iOS plist sets `ITSAppUsesNonExemptEncryption = false` ([iOS Info.plist](https://github.com/jellyfin/Swiftfin/blob/main/Swiftfin/Resources/Info.plist)).

**Obligation for v1.** This is a constraint on the core's design.
- If the Rust core's HTTP client uses the OS TLS stack (Security.framework, through `native-tls` or by delegating HTTP to `URLSession`), we can set `ITSAppUsesNonExemptEncryption = false` and upload no documentation.
- If the core bundles rustls, ring or OpenSSL, the second case applies, and we must either file the French declaration or leave France out of the storefronts.
- Recommendation: use OS TLS on Apple platforms. Record the choice in the ADR for the HTTP client.
- Whether the year-end self-classification report applies to OS-only HTTPS use for a free app is **unconfirmed**. Apple's page says "might"; check the US BIS rules (EAR 740.17(b)(1)) before launch.

### 11. Open-source licences and App Store terms

**Rule.**
- App Store apps are licensed under Apple's Standard EULA unless the developer supplies a custom EULA. The Standard EULA defers "to the extent as may be permitted by the licensing terms governing use of any open-sourced components" ([Apple Media Services Terms](https://www.apple.com/legal/internet-services/itunes/us/terms.html)).
- The FSF's position (2010) is that the App Store Usage Rules impose "further restrictions" that GPLv2 section 6 forbids ([FSF](https://www.fsf.org/blogs/licensing/more-about-the-app-store-gpl-enforcement)).
- MPL-2.0 requires that executables tell recipients where to get the source, and allows extra terms that "must not restrict a recipient's rights under the MPL" ([MPL 2.0 FAQ Q7, Q8](https://www.mozilla.org/en-US/MPL/2.0/FAQ/)).

**Precedent.**
- Swiftfin is MPL-2.0 and on the App Store ([repo](https://github.com/jellyfin/Swiftfin)).
- VideoLAN dual-licensed VLC for iOS as GPLv2+ and MPL-2.0 ([vlc-ios COPYING](https://code.videolan.org/videolan/vlc-ios/-/raw/master/COPYING)).
- VLCKit is LGPL-2.1 ([COPYING](https://code.videolan.org/videolan/VLCKit/-/raw/master/COPYING)).
- mpv is GPLv2+ by default, and LGPLv2.1+ only when built without GPL files (`-Dgpl=false`) ([mpv Copyright](https://github.com/mpv-player/mpv/blob/master/Copyright)).

**Obligation for v1.**
- MPL-2.0 for our code is fine.
- Add an in-app "About / Licences" screen that links to the source repo, as MPL 3.2(a) requires, and lists third-party licences.
- Do not link GPL-only code.
- The second player engine is still an open decision (AGENTS.md). If it is VLCKit or LGPL libmpv, the spike/ADR must check that LGPL relinking obligations can be met on tvOS, where static linking is common. Whether that is acceptable is **unconfirmed** and needs a licence review in that ADR.
- Check every Rust crate's licence. `cargo-deny` is a candidate, but adding it is a separate decision under the dependency rule.

### 12. Other store-listing obligations

- **Age rating.** The rating questionnaire is mandatory, and "An Unrated app can't be published on the App Store" ([Age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)). We do not control the user's media and we have no web browser, so we should expect a low rating. Which answers Apple expects for a player of user-supplied media is **unconfirmed**.
- **Support contact.** The app and its Support URL need an easy way to contact the developer ([Guideline 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information)). The repo's Issues page can serve.
- **EU Digital Services Act trader status** must be declared even for free apps. A non-trader publishes no contact details, but EU users are told that consumer-protection rights do not apply ([DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)). Whether a free MPL-2.0 project is a "trader" is a legal judgement for the account holder.
- **Siri Remote.** The app must be usable with only the Siri Remote or a game controller ([Guideline 2.4.3](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)).
- **Reviewer streams.** If we stream over cellular (not relevant on tvOS), give a test stream URL in Notes ([App Review information](https://developer.apple.com/help/app-store-connect/reference/app-review-information)).

## v1 checklist (derived from the above)

1. Unique app name and icon, with "a Jellyfin client" used only in the subtitle or description.
2. A reviewer Jellyfin server on public HTTPS with synthetic or open media and a non-expiring account. Its details go in App Review information.
3. A first-run screen and listing text that state a Jellyfin server is required, plus manual URL entry as well as discovery.
4. An ATS exception (`NSAllowsArbitraryLoads`, or `NSAllowsLocalNetworking` + `NSAllowsArbitraryLoadsForMedia`) with a written justification, and a UI warning for `http://`.
5. Self-signed certificates are out of scope for v1.
6. A privacy policy URL, the same text inside the app, and "Data Not Collected". No third-party SDKs that collect data.
7. `PrivacyInfo.xcprivacy` declaring the required-reason APIs used by the Swift shell and the Rust core, checked against the linked symbols.
8. OS TLS in the core, so `ITSAppUsesNonExemptEncryption = false` holds. Otherwise file the French declaration or skip France.
9. A licences screen with a source link, no GPL-only code, and LGPL engine obligations settled in the engine ADR.
10. An age rating questionnaire, a support URL and a DSA trader declaration in App Store Connect.

## Not confirmed from a primary source

- How ATS behaves on tvOS. Apple's ATS key pages do not list tvOS, and we found no page with tvOS defaults for IP-address hosts.
- Whether UDP broadcast discovery works from a tvOS app with no entitlement. TN3179 says tvOS has no local network privacy, and the multicast entitlement page does not list tvOS.
- Whether AVPlayer can accept a self-signed server certificate with ATS disabled.
- The password for the `demo` user on demo.jellyfin.org.
- That Jellyfin accounts created by the server admin do not trigger the in-app account deletion rule (5.1.1(v)).
- That playback reporting to the user's own server is not "collection" for the privacy label.
- That `std::time::Instant` in the Rust core triggers the boot-time required-reason category.
- Whether the US year-end self-classification report applies to OS-only HTTPS in a free app.
- That LGPL engines (VLCKit, libmpv) can meet their relinking obligations in a tvOS App Store build.
- Which age-rating answers Apple expects for a player of user-supplied media.
