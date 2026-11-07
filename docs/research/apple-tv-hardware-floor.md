# Research: Apple TV hardware and tvOS floor for v1

Answers [#42](https://github.com/sntna/server-media-player/issues/42). Researched 2026-11-07. Facts only; the decision is made in a later grilling ticket.

**Summary.** tvOS 27 (released 14 Sep 2026) supports only Apple TV 4K (2nd generation, A12) and later. Both candidates, Apple TV HD (A8) and Apple TV 4K 1st gen (A10X), stop at tvOS 26. Their last update so far is tvOS 26.6.1 (26 Oct 2026), with no published CVEs. Every tvOS API v1 is likely to want is available by tvOS 17, and current Xcode can deploy back to tvOS 15. So a **tvOS 26 deployment target** costs nothing in APIs and covers every Apple TV that can run this app.

**Recommendation:**
- Set the deployment target to **tvOS 26**.
- Make **Apple TV 4K (1st gen, A10X)** the supported hardware floor and the reference device for the performance budgets in `AGENTS.md`.
- Drop **Apple TV HD**. It has no HDR, decodes HEVC at only 1080p30 SDR and has a 10/100 Ethernet port.
- Plan to move the floor to Apple TV 4K (2nd gen) and tvOS 27 once v1 needs a tvOS 27 API or Apple stops shipping tvOS 26.x fixes.

## 1. Latest tvOS per model and Apple's support status

| Model (model no., year) | Chip | Latest tvOS | Status (as of 2026-11-07) |
|---|---|---|---|
| Apple TV HD (A1625, 2015) | A8 | tvOS 26.x (26.6.1) | Not eligible for tvOS 27. Got 26.6.1 on 26 Oct 2026 |
| Apple TV 4K 1st gen (A1842, 2017) | A10X Fusion | tvOS 26.x (26.6.1) | Same as Apple TV HD |
| Apple TV 4K 2nd gen (A2169, 2021) | A12 Bionic | tvOS 27.2 | Current |
| Apple TV 4K 3rd gen (A2737/A2843, 2022) | A15 Bionic | tvOS 27.2 | Current |
| New Apple TV 4K (announced 13 Oct 2026, in stores 13 Nov 2026) | A19 | tvOS 27.x | Current. Its model name and number are not on Apple's identification page yet |

Evidence:
- **tvOS 27 hardware.** Apple's tvOS 27 security notes say "Available for: Apple TV 4K 2nd generation and later", released September 14, 2026: https://support.apple.com/en-us/149036
- **tvOS 26 hardware.** Apple's security releases index lists tvOS 26 through 26.6 (15 Sep 2025 to 27 Jul 2026) as "Apple TV HD and Apple TV 4K (all models)": https://support.apple.com/en-us/100100
- **tvOS 26.6.1.** The same index lists tvOS 26.6.1 for "Apple TV HD and Apple TV 4K 1st generation", 26 Oct 2026, with no published CVE entries: https://support.apple.com/en-us/100100. Apple's update notes say 26.6.1 "adds support for the Siri Remote (4th generation) on Apple TV HD and Apple TV 4K (1st generation)": https://support.apple.com/en-us/106336
- **Model numbers, years, ports.** Apple's "Identify your Apple TV model" page: https://support.apple.com/en-us/101605
- **New A19 Apple TV 4K.** Announced 13 Oct 2026, in stores 13 Nov 2026, $299 in the US, with a new dedicated AV1 decoder: https://www.apple.com/newsroom/2026/10/apple-unveils-the-new-apple-tv-4k/
- **Unconfirmed.** Apple publishes no end-of-support policy, so I could not confirm how long tvOS 26.x security fixes will continue for these models. 26.6.1 shipped with no CVE fixes.

## 2. Video decode, HDR and frame-rate/range switching per model

All of this comes from Apple's tech specs pages.

| | Apple TV HD | Apple TV 4K 1st gen | Apple TV 4K 2nd gen | Apple TV 4K 3rd gen |
|---|---|---|---|---|
| HDMI | 1.4 | 2.0a | 2.1 | 2.1 |
| Max output | 1080p | 2160p | 2160p | 2160p |
| H.264 | up to 1080p60 | up to 2160p60 | up to 2160p60 | up to 2160p60 |
| HEVC SDR | 1080p, **30 fps**, SDR only | 2160p60, Main/Main 10 | 2160p60, Main/Main 10 | 2160p60, Main/Main 10 |
| HDR10 | no | yes, up to 2160p (no frame rate stated) | yes, 2160p60 | yes, 2160p60 |
| HDR10+ | no | not listed | not listed | yes |
| HLG | no | not listed | yes | yes |
| Dolby Vision | no | Profile 5, up to 2160p | Profile 5, 2160p60 | Profile 5, 2160p60 |
| Ethernet | 10/100 | Gigabit | Gigabit | Gigabit (128 GB model only) |
| Match Frame Rate | yes | yes | yes | yes |
| Match Dynamic Range | no | yes | yes | yes |

Sources:
- Apple TV HD specs: https://support.apple.com/en-us/111928
- Apple TV 4K (1st generation) specs: https://support.apple.com/en-us/111929
- Apple TV 4K (2nd generation) specs: https://support.apple.com/en-la/111922
- Apple TV 4K (3rd generation) specs: https://support.apple.com/kb/SP886?locale=en_US
- Ethernet: https://support.apple.com/en-us/101605
- **Match Content.** "Match Frame Rate" covers "Apple TV 4K or Apple TV HD". "Match Dynamic Range" covers "Apple TV 4K" only: https://support.apple.com/en-us/102277
- **Display criteria API.** Apps opt in to frame-rate and range switching through `AVDisplayCriteria` / `AVDisplayManager.preferredDisplayCriteria`, and `AVPlayerViewController.appliesPreferredDisplayCriteriaAutomatically` does it automatically. All of these are tvOS 11.2+:
  - https://developer.apple.com/documentation/avfoundation/avdisplaycriteria
  - https://developer.apple.com/documentation/avkit/avplayerviewcontroller/appliespreferreddisplaycriteriaautomatically

Implications:
- **Direct play on Apple TV HD.** HEVC above 1080p30 has to be transcoded, and so does anything HDR. That works against the "prefer direct play" rule. 10/100 Ethernet (about 94 Mbit/s usable) is also below the bitrate of many 4K remuxes. This only matters for 4K sources, which Apple TV HD cannot output anyway.
- **Dolby Vision profiles.** Apple's spec pages list only Dolby Vision **Profile 5** for every model. Whether AVPlayer plays Profile 8.x (common in Jellyfin libraries), and on which models, is **unconfirmed** from primary sources. It needs a device test or Apple HLS authoring docs, and belongs with the player-engine spike.
- **HLG on Apple TV 4K 1st gen.** Not listed on its spec page. Whether a later tvOS update added it is **unconfirmed**.

## 3. RAM and CPU headroom against the performance budgets

- **RAM.** Apple does not publish RAM for any Apple TV; none of the tech specs pages above mention it. Third-party teardowns commonly report 2 GB for A8, 3 GB for A10X and A12, and 4 GB for A15. These figures are **unconfirmed** from primary sources.
- **CPU and GPU.** Apple's spec pages give only chip names. Apple's only relative performance claim found is for the A19 model: "up to 50 percent faster CPU" and "up to 2x faster GPU" than the previous generation. https://www.apple.com/newsroom/2026/10/apple-unveils-the-new-apple-tv-4k/
- **Headroom against the budgets.** I found no primary source that measures launch time, scrolling or decode headroom for the 1.5 s cold-launch, 1 s first-frame and 60 fps / 10k-item budgets. Those have to come from our own measurements on the floor device. That is a reason to own one floor device for testing, whichever model it is.

## 4. tvOS APIs v1 wants, and the tvOS they need

Availability below comes from Apple's documentation data, e.g. `https://developer.apple.com/tutorials/data/documentation/swiftui/navigationstack.json`; the human-readable page is at the same path without `/tutorials/data` and `.json`.

| API | Minimum tvOS |
|---|---|
| Swift Concurrency (`async`/`await`, `Task`) back-deployed | 13 ([Xcode 13.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-13_2-release-notes), [Task](https://developer.apple.com/documentation/swift/task)) |
| SwiftUI `ScrollView`, `TabView` | 13 |
| Top Shelf: `TVTopShelfContentProvider`, `TVTopShelfCarouselContent` | 13 ([doc](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)) |
| SwiftUI `LazyVGrid` (virtualised grid) | 14 ([doc](https://developer.apple.com/documentation/swiftui/lazyvgrid)) |
| SwiftUI `focusSection()`, `focused(_:equals:)`, `AsyncImage` | 15 ([doc](https://developer.apple.com/documentation/swiftui/view/focussection())) |
| AVKit `transportBarCustomMenuItems`, `contextualActions`, `infoViewActions` | 15 ([doc](https://developer.apple.com/documentation/avkit/avplayerviewcontroller/transportbarcustommenuitems)) |
| SwiftUI `NavigationStack`, `defaultFocus(_:_:priority:)` | 16 ([doc](https://developer.apple.com/documentation/swiftui/navigationstack)) |
| Observation `@Observable`, SwiftUI `scrollPosition(id:anchor:)` | 17 ([doc](https://developer.apple.com/documentation/observation/observable())) |
| `AVDisplayCriteria`, automatic display criteria | 11.2 |

Toolchain and App Store constraints:
- **Deployment range.** Xcode 26.x and 27.x both deploy to "tvOS 15" and later; Xcode 27 builds with the tvOS 27 SDK and needs macOS Tahoe 26.6 to run. https://developer.apple.com/support/xcode/
- **SDK requirement.** Since 28 Apr 2026, App Store uploads "must be built with Xcode 26 or later using an SDK for ... tvOS 26": https://developer.apple.com/news/upcoming-requirements/. The SDK version and the deployment target are separate settings; building with the newest SDK does not stop the app from running on tvOS 26 devices.
- **Unconfirmed.** I could not confirm from Apple's requirements page whether or when a tvOS 27 SDK requirement will apply. Past pattern is roughly each April.

Conclusion for this section: nothing v1 plausibly needs requires anything newer than tvOS 17. Any tvOS 27-only API would cut off both candidates. I did not survey tvOS 27-only APIs here.

## 5. Install base and adoption data

- **tvOS.** Apple publishes OS adoption only for iOS and iPadOS (measured 7 Jun 2026), not for tvOS: https://developer.apple.com/support/app-store/
- **Per model.** I found no primary-source install-base or sales data per Apple TV model. Whether Apple TV HD and 4K 1st gen are still in "meaningful use" is **unconfirmed**.
- **Other ways to get the number.** Jellyfin server telemetry is not public. App Store Connect analytics would give device and OS mix only after launch.

## 6. Candidate floors: what each costs and buys

| Floor | Buys | Costs |
|---|---|---|
| **Apple TV HD + tvOS 26** | Every Apple TV that can install a tvOS 26 app | 1080p only and no HDR, so many Jellyfin sources fall back to transcode. Weakest chip (2015). Performance budgets would be set by the A8. Frozen at tvOS 26 |
| **Apple TV 4K 1st gen + tvOS 26** (recommended) | 4K, HDR10 and Dolby Vision (P5) direct play, Gigabit Ethernet, Match Dynamic Range. Costs nothing in APIs (everything needed is ≤ tvOS 17) | Excludes Apple TV HD. A10X is frozen at tvOS 26, so we cannot use tvOS 27 APIs without raising the floor. Security update window unknown |
| **Apple TV 4K 2nd gen + tvOS 27** | Matches Apple's currently supported set. HLG at 2160p60 and tvOS 27 APIs | Excludes both 2015/2017 boxes, possibly a meaningful share of users (unquantified) |

## Unconfirmed items

- How long Apple will keep shipping tvOS 26.x security fixes for Apple TV HD and Apple TV 4K 1st gen.
- RAM per model. Apple does not publish it.
- AVPlayer support for Dolby Vision Profile 8.x, by model.
- HLG on Apple TV 4K 1st gen.
- Install base or adoption share per model or per tvOS version.
- Timing of a tvOS 27 SDK requirement for App Store uploads.
- Model name and number of the October 2026 A19 Apple TV 4K on Apple's identification page.
