# What tvOS can play natively through AVPlayer

Research for [#44](https://github.com/sntna/server-media-player/issues/44). Gathered 2026-11-07 from Apple and Dolby primary sources. Facts not confirmed from a primary source are marked **UNCONFIRMED**.

## Summary

- **Containers:** AVPlayer plays MP4, MOV and M4V files and HLS (fMP4 segments, or MPEG-2 TS for H.264 only). Apple lists no Matroska (MKV) or WebM type anywhere. MKV therefore has to be remuxed (server-side, or by our own demuxer) or played by a second engine.
- **Video:** H.264 and HEVC Main/Main 10 on every Apple TV that runs tvOS. 4K, HDR10 and Dolby Vision **Profile 5** start with the A10X (Apple TV 4K 1st gen). HLG starts with the A12 and HDR10+ with the A15. No Apple TV lists AV1 or VP9.
- **Dolby Vision beyond Profile 5:** Apple documents Profile 8.1 and 8.4 only as `SUPPLEMENTAL-CODECS` inside HLS. Profile 7 (dual layer, typical of Blu-ray remuxes) appears in no Apple document. DV-in-MKV has to be remuxed to `dvh1` fMP4/HLS (Profile 5 or 8.1), or degraded to its HDR10 base layer.
- **Audio:** AAC/HE-AAC, MP3, ALAC, FLAC, AC-3 and E-AC-3, plus Atmos as E-AC-3 JOC, are native. TrueHD and DTS appear in no Apple list, so the server must transcode them. Output is decoded PCM, not bitstream: Apple's only output choices are Auto (uncompressed), re-encode to DD 5.1, or Dolby MAT. No API is documented for passing an arbitrary bitstream through.
- **Subtitles:** On tvOS, HLS subtitles must be WebVTT (IMSC1 is excluded), plus CEA-608/708 captions. Custom overlay rendering is supported via `AVPlayerItemLegibleOutput` with `suppressesPlayerRendering`. Match Content (`AVDisplayManager.preferredDisplayCriteria`, tvOS 11.2+), Picture in Picture (tvOS 14+) and Now Playing (`MPNowPlayingInfoCenter`) are all first-party APIs.

## Capability matrix

Per-device rows come from Apple's tech-spec pages ([TV HD][spec-hd], [4K 1st gen][spec-4k1], [4K 2nd gen][spec-4k2], [4K 3rd gen][spec-4k3]). Apple's model list ([identify][identify]) shows no Apple TV newer than the 2022 4K (3rd gen).

| Capability | Apple TV HD (A8, 2015) | Apple TV 4K 1st gen (A10X, 2017) | Apple TV 4K 2nd gen (A12, 2021) | Apple TV 4K 3rd gen (A15, 2022) | Source |
|---|---|---|---|---|---|
| H.264 | up to 1080p60, High/Main ≤ L4.2 | SDR up to 2160p60 | SDR up to 2160p60 | SDR up to 2160p60 | tech specs |
| HEVC SDR (Main / Main 10) | up to 1080p**30** | up to 2160p60 | up to 2160p60 | up to 2160p60 | tech specs |
| HDR10 (HEVC Main 10) | no | yes, up to 2160p | yes, 2160p60 | yes, 2160p60 | tech specs |
| HLG | no | not listed | yes, 2160p60 | yes, 2160p60 | tech specs |
| HDR10+ | no | not listed | not listed | yes, 2160p60 | tech specs |
| Dolby Vision Profile 5 | no | yes, up to 2160p | yes, 2160p60 | yes, 2160p60 | tech specs |
| Dolby Vision 8.1 / 8.4 | — | HLS `SUPPLEMENTAL-CODECS` only (device support **UNCONFIRMED**) | same | same | [HLS spec][hls] |
| Dolby Vision Profile 7 (dual layer) | not supported (not in any Apple doc) | same | same | same | absence in [HLS spec][hls], [HDR metadata][hdrmeta] |
| AV1 | not listed | not listed | not listed | not listed | tech specs; first Apple HW AV1 decoder is A17 Pro ([newsroom][a17]) |
| VP9 | not listed | not listed | not listed | not listed | tech specs |
| AAC / HE-AAC v1 / MP3 | yes | yes | yes | yes | tech specs |
| ALAC / FLAC / AIFF / WAV | yes | yes | yes | not listed on 3rd-gen page (**UNCONFIRMED** whether dropped or just omitted) | tech specs |
| AC-3 (DD 5.1) / E-AC-3 (DD+ 7.1) | yes | yes | yes | yes | tech specs |
| Dolby Atmos (E-AC-3 JOC) | no | yes | yes | yes | tech specs, [HLS spec][hls] |
| TrueHD, DTS, DTS-HD | not listed on any model | | | | tech specs |
| Opus | not listed on any model; codec ID `kAudioFormatOpus` exists in Core Audio since tvOS 11 ([doc][opus]) | | | | **UNCONFIRMED** for AVPlayer |
| Containers (files) | `.m4v`, `.mp4`, `.mov` | same | same | same | tech specs, [`AVFileType`][avfiletype] |
| HLS fMP4 / MPEG-2 TS | fMP4 for all codecs; TS for H.264 only | | | | [HLS spec][hls] 1.2, 1.5, 1.39, 2.25 |
| MKV / WebM | not supported (no `AVFileType`, not in tech specs) | | | | [`AVFileType`][avfiletype] |
| Subtitles in HLS | WebVTT only on tvOS; CEA-608/708 in video segments | | | | [HLS spec][hls] 4.2, 5.2 |
| Match Content | `AVDisplayManager` tvOS 11.2+ | | | | [AVDisplayManager][adm] |
| Picture in Picture | tvOS 14+ | | | | [tvOS 14 notes][tvos14] |
| Now Playing | `MPNowPlayingInfoCenter` | | | | [MPNowPlayingInfoCenter][mpnp] |

The 4K 3rd-gen page also says HDMI "Audio Return Channel (ARC or eARC)" ([spec][spec-4k3]).

## Details

### Containers

- `AVFileType` on tvOS lists `mov`, `mp4`, `m4v`, `m4a`, `ac3`, `eac3`, `mp3`, `wav`, `aiff`, `caf` and others, but no Matroska or WebM type ([AVFileType][avfiletype]). The tech-spec pages list only ".m4v, .mp4, and .mov file formats" for video ([spec-4k2]).
- HLS ([HLS authoring spec][hls]):
  - 1.2: H.264 "MUST be fragmented MP4 (fMP4) files or MPEG transport streams".
  - 1.5: HEVC "MUST be fMP4".
  - 1.39: AV1 "MUST be fMP4".
  - 2.25: xHE-AAC, ALAC, FLAC and APAC "MUST be fMP4".
- **Implication:** When the source is HEVC, HDR or lossless audio, a server transcode or remux to HLS must emit **fMP4** segments, not TS.

### Video codecs and levels

- HLS on tvOS: H.264 "MUST be less than or equal to High Profile, Level 5.1" (tvOS amendment to 1.3b). HEVC must be "≤ Main 10 Profile, Level 5.1, High Tier" (1.6b) ([hls]).
- Sample entries: prefer `avc1`/`hvc1`/`dvh1` over `avc3`/`hev1`/`dvhe`, so that parameter sets live in the sample description (1.10) ([hls]). Many MKV-sourced HEVC streams are `hev1`-style (in-band parameter sets). A remux should rewrite them to `hvc1` (**UNCONFIRMED** that AVPlayer on tvOS rejects `hev1`; Apple only says SHOULD).
- AV1: The HLS spec permits AV1 in fMP4 (1.37, 1.39), but no Apple TV tech-spec page lists AV1. Apple's first hardware AV1 decoder was announced with the A17 Pro: "A17 Pro includes a dedicated AV1 decoder" ([a17]). That chip is newer than every Apple TV.
  - `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` is available on tvOS 11+ for a runtime check ([vthw]).
  - tvOS 26.2 added `VTRegisterSupplementalVideoDecoderIfAvailable(_:)`, "to find and register video decoders that aren't registered by default" ([vtsupp]). Which codecs it unlocks on tvOS (AV1 or VP9 software decode?) is **UNCONFIRMED**. A runtime probe on device is needed.
- VP9: The `kCMVideoCodecType_VP9` constant exists ([vp9]), but no Apple TV spec or the HLS spec lists VP9. Treat it as not supported (**UNCONFIRMED** at runtime).
- Runtime probe: `AVURLAsset.audiovisualTypes()` returns the supported file types ([avtypes]). `AVPlayer.availableHDRModes` returns `hlg` / `hdr10` / `dolbyVision` bits ([hdrmodes], [hdrmode]). `AVPlayer.eligibleForHDRPlayback` tells whether the current device can present to an HDR display (tvOS 13.4+) ([eligible]). Core should feed the device profile from these at runtime rather than from a hard-coded per-chip table.

### HDR and Dolby Vision

- HLS HDR HEVC "MUST be HDR10, HLG, or Dolby Vision" (1.7). HLS also requires SDR variants "for backward compatibility" (1.24) and `VIDEO-RANGE` on non-SDR variants (9.16) ([hls]).
- Dolby Vision in HLS, general rule: "MUST be Profile 5 (single layer 10-bit HEVC) and less than or equal to Level 7" (1.9). An iOS amendment adds Profile 10 (AV1) up to Level 9, and visionOS adds Profile 20 (MV-HEVC). tvOS gets no amendment, so Profile 5 ≤ L7 is the rule there ([hls]).
- Profiles 8.1 and 8.4: The spec's `SUPPLEMENTAL-CODECS` section says these codecs "include Dolby Vision 8.4 and 10.4 (compatible with HLG) and Dolby Vision 8.1 and 10.1 (compatible with HDR10)". Its example is an HDR10 `hvc1` variant carrying `SUPPLEMENTAL-CODECS="dvh1.08.01/db1p"` ([hls]). So Apple's documented route for 8.1 is an HDR10 stream with DV as a supplemental layer.
  - Whether tvOS AVPlayer actually switches the TV into Dolby Vision mode for 8.1, rather than playing the HDR10 base, is **UNCONFIRMED** from a primary source.
- HDR10+: Signalled in HLS by the `cdm4` brand ([hls]). Listed only on the A15 Apple TV ([spec-4k3]). `AVPlayerItem.appliesPerFrameHDRDisplayMetadata` (tvOS 14+) controls whether per-frame HDR metadata is applied ([perframe]).
- File-based (MP4/MOV) HDR: Apple's *High Dynamic Range Metadata for Apple Devices* (v0.9 preliminary, 2019-05-31) says "Only Dolby Vision™ Profile 5 is supported" ([hdrmeta]). Its requirements:
  - Dolby Vision files: codec type `dvh1`, HEVC Main10, single-track, a `dvcC` box present, and `colr` set to 2/2/2 (unspecified).
  - HDR10: `hvc1` Main10 with `mdcv`/`clli` (or SEI in `hvcC`) and `colr` 9/16/9.
  - HLG: `colr` 9/18/9, or 9/1/9 with an ATC SEI value of 18 in `hvcC`.
  - This document predates 8.1 support claims and may be stale.
- Profile 7 (dual-layer, base + enhancement layer, common in UHD Blu-ray remuxes) is not mentioned in any Apple source found. It is a single-track-only world on Apple ([hdrmeta]). Dolby's own profile definitions (professionalsupport.dolby.com, ott.dolby.com) returned 403 to automated fetch. The Dolby-side definitions of profiles 5, 7 and 8.x (layers, cross-compatibility IDs) are therefore **UNCONFIRMED** here beyond what Apple's HLS spec states.
- **DV-in-MKV handling options**, all of which need a spike:
  1. Server remuxes to HLS fMP4 with a `dvh1` sample entry:
     - Profile 5: as is.
     - Profile 8.1: as an HDR10 `hvc1` stream plus `SUPPLEMENTAL-CODECS`.
  2. Profile 7: drop the enhancement layer and play the HDR10 base layer. Conversion of Profile 7 to 8.1 is a third-party practice, **UNCONFIRMED** from a primary source.
  3. A custom demuxer feeds `CMSampleBuffer`s to `AVSampleBufferDisplayLayer` (tvOS 10.2+) ([asbdl]) with a `kCMVideoCodecType_DolbyVisionHEVC` format description ([dvhevc]). It then builds `AVDisplayCriteria(refreshRate:formatDescription:)` by hand ([adc]). Whether DV metadata survives that path on tvOS is **UNCONFIRMED**.

### Match Content (frame rate and dynamic range)

- `AVDisplayManager` (tvOS 11.2+) is "A tvOS management object that controls whether a TV switches modes to match the video's native mode". Get it from the key window's `avDisplayManager`; do not instantiate it ([adm]).
- `preferredDisplayCriteria` is "A hint … to best match the currently playing content's display criteria". It is used "only when user settings allow"; set it to `nil` when playback ends ([adm-pdc]).
- `isDisplayCriteriaMatchingEnabled` (tvOS 11.3+) reflects Settings > Video and Audio > Match Content ([adm-en]). `isDisplayModeSwitchInProgress` is also exposed ([adm]).
- `AVPlayerViewController` applies the criteria automatically. A custom player loads `AVAsset.preferredDisplayCriteria` and sets it on the window's display manager. A sample-buffer pipeline builds it with `init(refreshRate:formatDescription:)` ([adc], [asset-pdc]).

### Audio

- Native codecs per tech specs: "HE-AAC (V1), AAC (up to 320 Kbps), protected AAC …, MP3 (up to 320 Kbps), MP3 VBR, Apple Lossless, FLAC, AIFF, and WAV; AC-3 (Dolby Digital 5.1), E-AC-3 (Dolby Digital Plus 7.1 surround sound), and Dolby Atmos" (4K 2nd gen; Atmos is absent on HD) ([spec-4k2], [spec-hd]).
- HLS multichannel codecs (2.5) are APAC, AAC-LC, HE-AAC v1, ALAC, FLAC, AC-3, E-AC-3 and E-AC-3 JOC. Atmos is signalled as `ec-3` with `CHANNELS="16/JOC"`. If E-AC-3 is offered, AC-3 must also be offered for devices without it (2.6) ([hls]).
- **TrueHD, DTS and DTS-HD** appear in no Apple TV tech spec and not in the HLS spec. They must be transcoded server-side, for example to E-AC-3, multichannel AAC or FLAC in fMP4.
- **Output path** ([audio settings][audioset]):
  - "Auto … sends uncompressed audio to your speakers". "Convert to Dolby Digital 5.1 … re-encodes audio". "Stereo Only … sends uncompressed two-channel PCM".
  - "Continuous Audio Connection … uses a Dolby MAT connection".
  - The user controls this, not the app. No public API was found for an app to send a raw compressed bitstream (TrueHD/DTS passthrough) to HDMI. "Bitstream passthrough is impossible" is therefore an inference from absence: **UNCONFIRMED** as an explicit Apple statement.
- Multichannel PCM from the app:
  - `AVAudioSession.maximumOutputNumberOfChannels` and `setPreferredOutputNumberOfChannels(_:)` (tvOS 9+) ([maxch], [prefch]).
  - `setSupportsMultichannelContent(_:)` (tvOS 15+), which defaults to false ([multich]).
  - `AVSampleBufferAudioRenderer` (tvOS 11+) for a custom engine that decodes itself and enqueues PCM ([asbar]).

### Subtitles and captions

- HLS caption formats: "CEA-608 closed captions, CEA-708 closed captions, WebVTT subtitles, IMSC1 subtitles (text profile only)" (4.2). The tvOS amendment to 5.2 says "Subtitles MUST be WebVTT". WebVTT must be text files with `X-TIMESTAMP-MAP` (5.3) ([hls]).
- In files: QuickTime subtitle media (`sbtl`, sample = 16-bit length + UTF-8/16 text + extensions such as forced `frcd`) ([qt-sbtl]). It is commonly called tx3g, but Apple's page does not use that four-character code (**UNCONFIRMED** naming). Closed-caption media `AVMediaType.closedCaption` also exists ([cc]).
- AVPlayer renders selected legible options itself in `AVPlayerViewController` and `AVPlayerLayer`. Options are chosen through `AVMediaSelectionGroup`. Set `appliesMediaSelectionCriteriaAutomatically = false` to take control ([select]).
- **Custom overlay rendering is supported:**
  - `AVPlayerItemLegibleOutput` "vends attributed strings" (tvOS 9+) ([legible]).
  - With `suppressesPlayerRendering = true`, the player stops drawing them ([suppress]).
  - `AVPlayerViewController.contentOverlayView` hosts non-interactive views between video and controls ([overlay]).
- SRT, ASS/SSA and PGS are not in any Apple list. They have to be converted server-side to WebVTT, or rendered by our own overlay. Image subtitles such as PGS would need server burn-in or a custom renderer.

### Picture in Picture and Now Playing

- PiP arrived in tvOS 14. Use `AVPlayerViewController` (`allowsPictureInPicturePlayback`, default true) for the standard player, or `AVPictureInPictureController` for a custom player ([tvos14], [avpvc-pip], [pipc]).
  - The app needs background audio configured ([pipc]) and the PiP capability ([wwdc20-pip]).
  - In tvOS 14, the swipe-up gesture moved from `customOverlayViewController` to PiP ([wwdc20-pip], [custom-overlay]).
  - `AVPictureInPictureController.init(contentSource:)` also supports sample-buffer layers ([pipc]).
- Now Playing: `MPNowPlayingInfoCenter.default().nowPlayingInfo`, with elapsed time, rate, duration, artwork and language options ([mpnp]).

## Per-chip notes

- **A8 (Apple TV HD):** SDR only. HEVC is capped at 1080p30, H.264 at 1080p60 L4.2. No Atmos. Third-party reports say tvOS 27 dropped it, **UNCONFIRMED**: Apple's [update page][updates] does not list models.
- **A10X (4K 1st gen):** 4K60 SDR, HDR10 and DV P5. No HLG or HDR10+ listed. Same tvOS 27 caveat as the A8.
- **A12 (4K 2nd gen):** adds HLG at 2160p60.
- **A15 (4K 3rd gen):** adds HDR10+, eARC and QMS. The newest Apple TV per Apple's [model list][identify]. No AV1 hardware.

## Sources

- [hls]: https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices
- [hdrmeta]: https://developer.apple.com/av-foundation/High-Dynamic-Range-Metadata-for-Apple-Devices.pdf
- [spec-hd]: https://support.apple.com/en-us/111928
- [spec-4k1]: https://support.apple.com/en-us/111929
- [spec-4k2]: https://support.apple.com/kb/SP845
- [spec-4k3]: https://support.apple.com/en-us/111839
- [identify]: https://support.apple.com/en-us/101605
- [updates]: https://support.apple.com/en-us/106336
- [audioset]: https://support.apple.com/guide/tv/atvba773c3c9/tvos
- [a17]: https://www.apple.com/newsroom/2023/09/apple-unveils-iphone-15-pro-and-iphone-15-pro-max/
- [adm]: https://developer.apple.com/documentation/avkit/avdisplaymanager
- [adm-pdc]: https://developer.apple.com/documentation/avkit/avdisplaymanager/preferreddisplaycriteria
- [adm-en]: https://developer.apple.com/documentation/avkit/avdisplaymanager/isdisplaycriteriamatchingenabled
- [adc]: https://developer.apple.com/documentation/avfoundation/avdisplaycriteria
- [asset-pdc]: https://developer.apple.com/documentation/avfoundation/avasset/preferreddisplaycriteria
- [hdrmodes]: https://developer.apple.com/documentation/avfoundation/avplayer/availablehdrmodes
- [hdrmode]: https://developer.apple.com/documentation/avfoundation/avplayer/hdrmode
- [eligible]: https://developer.apple.com/documentation/avfoundation/avplayer/eligibleforhdrplayback
- [perframe]: https://developer.apple.com/documentation/avfoundation/avplayeritem/appliesperframehdrdisplaymetadata
- [avfiletype]: https://developer.apple.com/documentation/avfoundation/avfiletype
- [avtypes]: https://developer.apple.com/documentation/avfoundation/avurlasset/audiovisualtypes()
- [vthw]: https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported(_:)
- [vtsupp]: https://developer.apple.com/documentation/videotoolbox/vtregistersupplementalvideodecoderifavailable(_:)
- [vp9]: https://developer.apple.com/documentation/coremedia/kcmvideocodectype_vp9
- [dvhevc]: https://developer.apple.com/documentation/coremedia/kcmvideocodectype_dolbyvisionhevc
- [opus]: https://developer.apple.com/documentation/coreaudiotypes/kaudioformatopus
- [asbdl]: https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer
- [asbar]: https://developer.apple.com/documentation/avfoundation/avsamplebufferaudiorenderer
- [maxch]: https://developer.apple.com/documentation/avfaudio/avaudiosession/maximumoutputnumberofchannels
- [prefch]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredoutputnumberofchannels(_:)
- [multich]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setsupportsmultichannelcontent(_:)
- [legible]: https://developer.apple.com/documentation/avfoundation/avplayeritemlegibleoutput
- [suppress]: https://developer.apple.com/documentation/avfoundation/avplayeritemoutput/suppressesplayerrendering
- [select]: https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks
- [cc]: https://developer.apple.com/documentation/avfoundation/avmediatype/closedcaption
- [qt-sbtl]: https://developer.apple.com/documentation/quicktime-file-format/subtitle_sample_data
- [overlay]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/contentoverlayview
- [custom-overlay]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/customoverlayviewcontroller
- [avpvc-pip]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/allowspictureinpictureplayback
- [pipc]: https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller
- [tvos14]: https://developer.apple.com/documentation/tvos-release-notes/tvos-14-release-notes
- [wwdc20-pip]: https://developer.apple.com/videos/play/wwdc2020/10176/
- [mpnp]: https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter

[hls]: https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices
[hdrmeta]: https://developer.apple.com/av-foundation/High-Dynamic-Range-Metadata-for-Apple-Devices.pdf
[spec-hd]: https://support.apple.com/en-us/111928
[spec-4k1]: https://support.apple.com/en-us/111929
[spec-4k2]: https://support.apple.com/kb/SP845
[spec-4k3]: https://support.apple.com/en-us/111839
[identify]: https://support.apple.com/en-us/101605
[updates]: https://support.apple.com/en-us/106336
[audioset]: https://support.apple.com/guide/tv/atvba773c3c9/tvos
[a17]: https://www.apple.com/newsroom/2023/09/apple-unveils-iphone-15-pro-and-iphone-15-pro-max/
[adm]: https://developer.apple.com/documentation/avkit/avdisplaymanager
[adm-pdc]: https://developer.apple.com/documentation/avkit/avdisplaymanager/preferreddisplaycriteria
[adm-en]: https://developer.apple.com/documentation/avkit/avdisplaymanager/isdisplaycriteriamatchingenabled
[adc]: https://developer.apple.com/documentation/avfoundation/avdisplaycriteria
[asset-pdc]: https://developer.apple.com/documentation/avfoundation/avasset/preferreddisplaycriteria
[hdrmodes]: https://developer.apple.com/documentation/avfoundation/avplayer/availablehdrmodes
[hdrmode]: https://developer.apple.com/documentation/avfoundation/avplayer/hdrmode
[eligible]: https://developer.apple.com/documentation/avfoundation/avplayer/eligibleforhdrplayback
[perframe]: https://developer.apple.com/documentation/avfoundation/avplayeritem/appliesperframehdrdisplaymetadata
[avfiletype]: https://developer.apple.com/documentation/avfoundation/avfiletype
[avtypes]: https://developer.apple.com/documentation/avfoundation/avurlasset/audiovisualtypes()
[vthw]: https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported(_:)
[vtsupp]: https://developer.apple.com/documentation/videotoolbox/vtregistersupplementalvideodecoderifavailable(_:)
[vp9]: https://developer.apple.com/documentation/coremedia/kcmvideocodectype_vp9
[dvhevc]: https://developer.apple.com/documentation/coremedia/kcmvideocodectype_dolbyvisionhevc
[opus]: https://developer.apple.com/documentation/coreaudiotypes/kaudioformatopus
[asbdl]: https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer
[asbar]: https://developer.apple.com/documentation/avfoundation/avsamplebufferaudiorenderer
[maxch]: https://developer.apple.com/documentation/avfaudio/avaudiosession/maximumoutputnumberofchannels
[prefch]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setpreferredoutputnumberofchannels(_:)
[multich]: https://developer.apple.com/documentation/avfaudio/avaudiosession/setsupportsmultichannelcontent(_:)
[legible]: https://developer.apple.com/documentation/avfoundation/avplayeritemlegibleoutput
[suppress]: https://developer.apple.com/documentation/avfoundation/avplayeritemoutput/suppressesplayerrendering
[select]: https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks
[cc]: https://developer.apple.com/documentation/avfoundation/avmediatype/closedcaption
[qt-sbtl]: https://developer.apple.com/documentation/quicktime-file-format/subtitle_sample_data
[overlay]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/contentoverlayview
[custom-overlay]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/customoverlayviewcontroller
[avpvc-pip]: https://developer.apple.com/documentation/avkit/avplayerviewcontroller/allowspictureinpictureplayback
[pipc]: https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller
[tvos14]: https://developer.apple.com/documentation/tvos-release-notes/tvos-14-release-notes
[wwdc20-pip]: https://developer.apple.com/videos/play/wwdc2020/10176/
[mpnp]: https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter
