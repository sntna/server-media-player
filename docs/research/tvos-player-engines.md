# Second player engine on tvOS: what is viable

Research for [#45](https://github.com/sntna/server-media-player/issues/45). Gathered 2026-11-07. Not legal advice.

## Summary

- **GPL-only options are out** for a public App Store app: the FSF's position is that App Store terms conflict with the GPL ([FSF](https://www.fsf.org/news/2010-05-app-store-compliance)). That rules out KSPlayer's free build (GPL-3.0; the LGPL licence is paid and monthly) and MPVUI's prebuilt `Libmpv-GPL`.
- **AetherEngine** is the best fit on paper. It demuxes with FFmpeg, decodes with VideoToolbox and hands playback to AVPlayer where it can, so Dolby Vision, Atmos passthrough and Match Content keep working. The engine is LGPL-3.0 with an explicit App Store exception, and FFmpeg is linked dynamically under LGPL-2.1. The catches are that it is about seven months old, has one maintainer, is Apple-only and needs tvOS 18 or later.
- **VLCKit (TVVLCKit)** is the mature, institutionally maintained choice. It is LGPL-2.1, maintained by VideoLAN and ships in VLC for Apple TV and in Swiftfin 1.6.1. It renders its own frames, so it is the weaker choice for Dolby Vision and Atmos (claimed by a competitor, not confirmed).
- **libmpv** works on tvOS only through a self-maintained LGPL build. MPVKit's own README calls it "only suitable for learning", and MPVUI ships GPL builds only.
- **Server remux to HLS** is not a replacement on its own: tvOS HLS allows only WebVTT subtitles and no DTS or TrueHD audio, so those tracks force a transcode or burn-in. It stays the fallback.

**Shortlist for the spike:** (1) AetherEngine, (2) VLCKit 3.x as the conservative baseline. Keep libmpv (LGPL build) in reserve if the spike disqualifies both.

## Comparison matrix

Legend: **[P]** confirmed from a primary source (project repo, official docs or store listing). **[C]** a claim made by a competing project's README, not independently confirmed. **[U]** unconfirmed or not measured.

| | AetherEngine | VLCKit / TVVLCKit | libmpv (MPVKit / MPVUI) | KSPlayer | Server remux to HLS (no engine) |
|---|---|---|---|---|---|
| tvOS support | Yes, tvOS 18+ [P][ae-req] | Yes, tvOS 10.2+ [P][vk-readme] | Yes, builds for tvOS [P][mpvkit]; MPVUI tvOS 18+ [P][mpvui-pkg] | Yes, tvOS 13+ [P][ks-readme] | Yes (AVPlayer) |
| Maintenance health | Very active: v7.59.0 on 2026-11-06. Repo created 2026-04-12, 389 stars, single author [P][ae-repo] | VideoLAN. 3.7.5 tagged 2026-10-30; 4.0 still alpha (a21, 2026-07-13) [P][vk-repo] | MPVKit: "only suitable for learning ... will not be maintained too frequently" [P][mpvkit]. MPVUI: active, 0.10.0 on 2026-11-04 [P][mpvui-rel] | Active, pushed 2026-11-02; one maintainer, commercial model [P][ks-readme] | Jellyfin server feature |
| License as shipped | Engine LGPL-3.0 plus App Store/DRM exception; FFmpeg LGPL-2.1, dynamic frameworks [P][ae-license][ffb] | LGPL-2.1+ [P][vk-readme][vlc-lgpl] | mpv LGPL-2.1+ only when built `-Dgpl=false` [P][mpv-copy]. MPVKit offers LGPL and GPL builds [P][mpvkit]. MPVUI ships only `Libmpv-GPL` (FFmpeg `--enable-gpl`, libsmbclient) [P][mpvui-pkg][mpvui-recipe] | GPL-3.0 free; LGPL only through a paid licence (≥ US$15/month, private repo) [P][ks-731] | n/a |
| App Store with our MPL-2.0 app | Yes: the exception names the App Store and end-user relinking explicitly [P][ae-license] | Yes in practice: VLC for Apple TV (MPL-2.0/GPLv2 app) ships on it [P][vlc-store][vlc-ios-lic] | LGPL build: same position as VLCKit [U]. GPL build: conflicts with the FSF view [P][fsf] | GPL build: no. LGPL needs payment plus a "powered by KSPlayer" credit [P][ks-731] | Yes |
| VideoToolbox hardware decode | H.264, HEVC, HEVC Main10, AV1 where hardware exists; software dav1d/libavcodec otherwise [P][ae-readme] | H.264/HEVC via VideoToolbox (VLC 3.0) [P][vlc3] | `--hwdec` VideoToolbox [C][ae-readme]; MPVUI sample-buffer path through AVFoundation [P][mpvui-render] | VideoToolbox plus FFmpeg software [P][ks-readme] | Native |
| HDR10 / Dolby Vision / Match Content | HDR10, HDR10+, DV P5/P7→8.1/P8/P10, HLG; drives `AVDisplayManager` itself [P][ae-readme] | Tone-maps; no DV display, software tone mapping on tvOS [C][ae-readme] | MPVUI: native HDR on the sample-buffer path, DV with RPU, `AVDisplayCriteria` hints on tvOS [P][mpvui-render]. Swiftfin's doc still lists frame-rate matching as unsupported with MPV [P][sf-players] | HDR10/HDR10+/DV; DV dynamic metadata P5/7/8/10 is a **paid** feature [P][ks-readme] | Native, but HLS needs fMP4 for HEVC and the DV profile list is limited [P][hls-spec] |
| Subtitles ASS/SSA, PGS, VobSub | ASS, SSA, SRT, VTT as cues (raw ASS opt-in); PGS, DVB, DVD and VobSub as `CGImage`; **the host paints them** [P][ae-readme] | Rendered by libVLC (libass support [U]) | mpv renders styled ASS and bitmap subs; the app supplies fonts [P][mpvui-render] | Full ASS via libass; text and image subs [P][ks-readme] | tvOS HLS: **WebVTT only** [P][hls-spec]; Jellyfin: PGS and ASS not supported in TS/MP4 → burn-in, "the most intensive method" [P][jf-codec] |
| Audio: multichannel, Atmos | E-AC-3 JOC stream-copied through AVPlayer; TrueHD/DTS decoded to PCM; optional height-bed rendering [P][ae-readme] | Decodes to PCM, no object passthrough [C][ae-readme]; "HDMI passthrough for HD audio" is a VLC 3.0 feature, but its status on tvOS is [U][vlc3] | No Atmos passthrough on Apple [C][ae-readme] | Atmos (E-AC-3) native is **paid** [P][ks-readme] | AC-3, E-AC-3, E-AC-3 JOC yes; DTS and TrueHD absent from the spec, so they are transcoded [P][hls-spec] |
| Binary size | FFmpegBuild ≈ 10.5 MB per arm64 slice for tvOS [P][ffb]; engine itself [U] | VLC app on the store is 70.4 MB (universal listing, so not a tvOS-only figure) [P][vlc-store]; TVVLCKit alone [U] | MPVKit release zips: libmpv 18 MB plus libavcodec 53 MB (all slices, zipped) [P][mpvkit-rel]; per-device size [U] | [U] | 0 |
| Startup cost | Has a `prewarm` API to cut time to first byte [P][ae-readme]; not measured on tvOS [U] | [U] | [U] | [U] | Server remux spin-up [U] |
| Memory (A8 / A10X) | No tvOS data. Author-run M1 benchmark, 4K HDR MKV: RSS ≈ 336–342 MB at 38 Mbit/s [C][ae-readme] | Same bench: RSS ≈ 111–122 MB, but 3–4× the CPU [C][ae-readme] | Same bench: RSS ≈ 475–629 MB, highest power [C][ae-readme] | Same bench: RSS ≈ 333–357 MB [C][ae-readme] | AVPlayer baseline |
| Swift integration | Swift 6, `async` API, SwiftUI `AetherPlayerSurface`, no UI [P][ae-readme] | Objective-C API (`VLCMediaPlayer`), CocoaPods/Carthage [P][vk-readme] | C API; MPVUI gives a SwiftUI `MPVVideoPlayer` [P][mpvui-readme] | Swift; ships its own UI layer [P][ks-readme] | Nothing beyond the AVPlayer path |
| Precedent apps on tvOS | Sodalite (Jellyfin), Plozz, LillyPlayer, Snappier IPTV and others [P][ae-readme] | VLC for Apple TV [P][vlc-store]; Swiftfin 1.6.1 (via VLCUI) [P][sf-161] | Swiftfin `main` uses MPVUI (GPL build) as its default engine; not yet in an App Store release [P][sf-pr2274][sf-store] | TracyPlayer, SenPlayer and others under the paid licence [P][ks-readme] | Every Jellyfin client falls back to it |

## Details

### AetherEngine

- The architecture is the closest match to ours: "FFmpeg demuxes. VideoToolbox decodes. AVPlayer handles Dolby Atmos." It swaps between `AVPlayerLayer` (native path) and `AVSampleBufferDisplayLayer` (software path) behind one view ([README][ae-readme]). That keeps the OS handling Dolby Vision, Atmos and Match Content wherever it can, which fits our performance budget and AGENTS.md's AVPlayer default.
- License: LGPL-3.0 with an "Apple Store / DRM Exception" that covers signing, DRM, redistribution limits and "end-user re-linking". The README recommends linking the engine statically and requires FFmpeg to stay as dynamic frameworks in `YourApp.app/Frameworks/` ([LICENSE][ae-license], [README §License][ae-readme]). FFmpegBuild compiles without GPL components ([FFmpegBuild][ffb]).
- It also needs libdovi (MIT) and optionally LibTrueHD (MIT/Apache-2.0). Both are permissive, but the notices have to go in our acknowledgements screen ([README §License][ae-readme]).
- Risks: one author (Vincent Herbst, per the LICENSE copyright line). The project is about seven months old. The README is written by the author and benchmarks competitors with the author's own harness ([aetherengine-bench](https://github.com/superuser404notfound/aetherengine-bench)). It is Apple-only, which is acceptable because `PlayerEngine` is per-platform anyway. The tvOS 18 floor keeps Apple TV HD supported, since tvOS 26.x still lists it ([Apple](https://support.apple.com/en-us/106336)).
- Subtitles are emitted as cues or `CGImage`, and "your UI paints them". That means we write a subtitle overlay in SwiftUI, including ASS styling if we want it (the README lists raw ASS markup as opt-in).
- A tvOS 26.5 gotcha the engine already handles: `AVDisplayManager.preferredDisplayCriteria` has to be set synchronously before the item is assigned, or HDR HLS variants fail with -11868 ([README §Host setup on tvOS][ae-readme]).

### VLCKit / TVVLCKit

- It is the official libVLC wrapper for "macOS, iOS and tvOS" and is LGPL-2.1 ([GitHub mirror README][vk-readme]). libVLC moved to LGPL in December 2011 so that "applications ... based on the VLC engine [can] be built under non-GPL licenses" ([VideoLAN][vlc-lgpl]).
- The stable line is 3.7.x (3.7.5, 2026-10-30). 4.0 has been in alpha for years (a21 is dated 2026-07-13) ([tags][vk-repo]). The build script produces static libVLC archives for appletvos ([compileAndBuildVLCKit.sh](https://github.com/videolan/vlckit/blob/master/compileAndBuildVLCKit.sh)). Static linking under LGPL-2.1 §6 is satisfiable for us because our whole app is published as MPL-2.0 source; whether App Store terms still conflict is the same open question that VideoLAN's own app lives with [U].
- Precedent: VLC for Apple TV is free on the store and needs tvOS 13+ ([listing][vlc-store]). Swiftfin 1.6.1, the current App Store release, uses VLCUI, which wraps VLCKit ([Package.resolved @1.6.1][sf-161]). Swiftfin `main` has since moved off it, first to SwiftVLC and then to mpv as the default ([PR #2273](https://github.com/jellyfin/Swiftfin/pull/2273), [PR #2274][sf-pr2274]).
- Weaknesses: VLCKit renders its own output, so Dolby Vision, Atmos object passthrough and Match Content behaviour on tvOS are doubtful. The only source here is AetherEngine's comparison table [C]; the spike must check this on hardware.

### libmpv (MPVKit, MPVUI)

- mpv is GPLv2+ by default and LGPLv2.1+ only when built `-Dgpl=false`, which "does not in itself create a LGPLv2.1+ license grant" ([Copyright][mpv-copy]).
- MPVKit provides LGPL and `-GPL` xcframeworks for tvOS, but now says it is "only suitable for learning" and points to AetherEngine for production use ([README][mpvkit]).
- MPVUI (MIT wrapper, used by Swiftfin `main`) links a single `Libmpv-GPL` binary target built with `--enable-gpl` and libsmbclient ([Package.swift][mpvui-pkg], [NativeRecipe.swift][mpvui-recipe]). Using it unmodified would put GPL code in our App Store binary. An LGPL path means maintaining our own mpv and FFmpeg build.
- Plus side: a strong renderer (libplacebo through MoltenVK, or sample-buffer output), native ASS and bitmap subtitles, `AVDisplayCriteria` hints, and an Android story (MPVUI also targets Android Compose), which matters for later platforms ([RENDERING.md][mpvui-render]).

### KSPlayer

- The README says "KSPlayer defaults to the GPL license (requires open-sourcing your own project code)". The LGPL licence is personal or enterprise and paid: at least US$15/month, eight months up front, code under NDA, and an in-app credit ([README][ks-readme], [issue #731][ks-731]). Dolby Vision dynamic metadata, native Atmos and "AVPlayer supports MKV" are one-time **paid** features.
- A free public App Store app cannot use the GPL build (see [FSF][fsf]), and the paid terms conflict with an open-source MPL-2.0 project because licensed code may not be published. **Not viable.**

### No engine: always remux to HLS on the server

- Jellyfin: a container mismatch means "remuxing ... video and audio codec will remain intact" and is cheap; burning in subtitles is "the most intensive method of transcoding" ([Codec support][jf-codec], [Transcoding][jf-transcode]). The client can ask for fMP4 segments (`segmentContainer`) ([StreamingRequestDto.cs](https://github.com/jellyfin/jellyfin/blob/797999fc9bd49a9f0853916e2933e3ad06173503/MediaBrowser.Controller/Streaming/StreamingRequestDto.cs)).
- The Apple HLS spec for tvOS allows HEVC only in fMP4, Dolby Vision only as Profile 5 in the base spec, subtitles only as WebVTT, and multichannel audio only as AAC, AC-3, E-AC-3 or E-AC-3 JOC, with no DTS or TrueHD ([HLS authoring spec][hls-spec]). So any MKV with PGS, ASS or styled subs, DTS or TrueHD, or DV Profile 7/8 is no longer a cheap remux.
- Verdict: keep it as the fallback, which matches AGENTS.md's "Prefer direct play", but it does not remove the need for a second engine.

### Apple TV hardware notes

- Apple TV HD (A8): HEVC is SDR only, up to 1080p at 30 fps; H.264 up to 1080p at 60 fps; HDMI 1.4 ([Apple specs](https://support.apple.com/en-us/111928)). On this box HDR and DV are irrelevant and software decode cost dominates, so engine CPU (VLCKit high, libmpv highest in the AetherEngine bench [C]) matters more than features.
- RAM on A8 and A10X: Apple does not publish it [U]. No engine publishes tvOS memory figures [U]. Measure in the spike.

## What the spike must measure (not available from sources)

On an Apple TV HD and an Apple TV 4K (1st gen): IPA size delta, cold engine init time, play-press-to-first-frame on LAN direct play (budget < 1 s), peak footprint on a 4K HDR MKV, DV P8 and Atmos actually reaching the TV/AVR, Match Content switching, and ASS and PGS rendering.

## Unconfirmed

- Whether a static LGPL-2.1 libVLC or libmpv in an App Store binary is compliant. VideoLAN ships it, but no primary legal statement on the App Store was found.
- VLCKit on tvOS: Dolby Vision output, Atmos passthrough, Match Content, libass. Only AetherEngine's comparison covers these.
- Which engine Infuse uses: the App Store listing ([Infuse](https://apps.apple.com/us/app/infuse-video-player/id1136220934)) does not name one.
- Whether Swiftfin's mpv build has shipped to TestFlight or the App Store. The App Store has 1.6.1 (Aug 24), which predates the mpv merge on 2026-09-06 ([listing][sf-store]).
- Per-device binary size and startup time for every engine.
- Whether tvOS 27 drops Apple TV HD and 4K (1st gen). Only third-party reports say so; Apple's page lists tvOS 26.6.1 for them.

## Sources

[ae-repo]: https://github.com/superuser404notfound/AetherEngine
[ae-readme]: https://github.com/superuser404notfound/AetherEngine/blob/main/README.md
[ae-req]: https://github.com/superuser404notfound/AetherEngine/blob/main/README.md#requirements
[ae-license]: https://github.com/superuser404notfound/AetherEngine/blob/main/LICENSE
[ffb]: https://github.com/superuser404notfound/FFmpegBuild
[vk-repo]: https://github.com/videolan/vlckit/tags
[vk-readme]: https://github.com/videolan/vlckit/blob/master/README.md
[vlc-lgpl]: https://www.videolan.org/press/lgpl-libvlc.html
[vlc3]: https://www.videolan.org/vlc/releases/3.0.0.html
[vlc-store]: https://apps.apple.com/us/app/vlc-media-player/id650377962
[vlc-ios-lic]: https://github.com/videolan/vlc-ios/blob/master/COPYING
[mpv-copy]: https://github.com/mpv-player/mpv/blob/master/Copyright
[mpvkit]: https://github.com/mpvkit/MPVKit/blob/main/README.md
[mpvkit-rel]: https://github.com/mpvkit/MPVKit/releases/tag/1.0.0
[mpvui-readme]: https://github.com/LePips/MPVUI
[mpvui-rel]: https://github.com/LePips/MPVUI/releases/tag/0.10.0
[mpvui-pkg]: https://github.com/LePips/MPVUI/blob/main/Package.swift
[mpvui-recipe]: https://github.com/LePips/MPVUI/blob/9f15a49dfa04170729047587df81aa0f5ae39ce3/Build/Sources/MPVBuildCore/Recipes/NativeRecipe.swift
[mpvui-render]: https://github.com/LePips/MPVUI/blob/main/Build/RENDERING.md
[ks-readme]: https://github.com/kingslay/KSPlayer/blob/main/README.md
[ks-731]: https://github.com/kingslay/KSPlayer/issues/731
[fsf]: https://www.fsf.org/news/2010-05-app-store-compliance
[sf-players]: https://github.com/jellyfin/Swiftfin/blob/main/Documentation/players.md
[sf-pr2274]: https://github.com/jellyfin/Swiftfin/pull/2274
[sf-161]: https://github.com/jellyfin/Swiftfin/blob/1.6.1/Swiftfin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
[sf-store]: https://apps.apple.com/us/app/swiftfin/id1604098728
[hls-spec]: https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices
[jf-codec]: https://jellyfin.org/docs/general/clients/codec-support/
[jf-transcode]: https://jellyfin.org/docs/general/post-install/transcoding/

- AetherEngine: [repo][ae-repo], [README][ae-readme], [LICENSE][ae-license]; FFmpegBuild: [repo][ffb]
- VLCKit: [README][vk-readme], [tags][vk-repo]; VideoLAN: [libVLC LGPL press release][vlc-lgpl], [VLC 3.0 release notes][vlc3]; [VLC on the App Store][vlc-store]; [vlc-ios COPYING][vlc-ios-lic]
- mpv: [Copyright][mpv-copy]; MPVKit: [README][mpvkit], [release 1.0.0][mpvkit-rel]; MPVUI: [README][mpvui-readme], [Package.swift][mpvui-pkg], [NativeRecipe.swift][mpvui-recipe], [RENDERING.md][mpvui-render]
- KSPlayer: [README][ks-readme], [licensing issue #731][ks-731]
- FSF: [App Store compliance][fsf]
- Swiftfin: [players.md][sf-players], [PR #2274 (mpv)][sf-pr2274], [Package.resolved @1.6.1][sf-161], [App Store listing][sf-store]
- Apple: [HLS authoring spec][hls-spec], [Apple TV HD specs](https://support.apple.com/en-us/111928), [tvOS updates](https://support.apple.com/en-us/106336)
- Jellyfin: [codec support][jf-codec], [transcoding][jf-transcode]
