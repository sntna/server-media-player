# Which Jellyfin server versions provide the v1 feature set?

Research for [#43](https://github.com/sntna/server-media-player/issues/43). Gathered 2026-11-07 from Jellyfin release notes, the jellyfin.org blog and the `jellyfin/jellyfin` source at each release tag.

**Summary.** Media segments are the newest feature in the v1 set. They first appear in **10.10.0** (Oct 2024). Quick Connect dates from 10.7.0, server trickplay from 10.9.0, and the current DeviceProfile / PlaybackInfo shape from 10.9.0. The `Authorization: MediaBrowser … Token=…` header works on every version since at least 10.7.0. A client that sticks to the non-deprecated 12.x API (POST Quick Connect, `Authorization` header, `Sessions/Playing*`, `/UserItems/*`) runs unchanged from 10.10.0 through 12.4, provided it tolerates unknown enum values and extra fields. Upstream only supports the latest stable release (12.4 today) and stops releasing a branch once the next one ships.
**Recommendation:** set the hard minimum at **10.10.0**, test against 10.10.7, 10.11.11 and the latest 12.x, and refuse older servers at connect time with a clear message. If 10.10 adds testing cost and few users, the fallback is 10.11.0 (Dolby Vision enhancement-layer range types, the last pre-12 branch).

## Version × feature table

| Feature (v1 need) | 10.8 | 10.9 | 10.10 | 10.11 | 12.x | Introduced in |
|---|---|---|---|---|---|---|
| Quick Connect (`/QuickConnect/*`) | yes (GET Initiate) | yes (POST + GET Initiate) | yes | yes (GET marked obsolete) | yes (**POST only**) | 10.7.0 [1][2] |
| Server-generated trickplay (`/Videos/{id}/Trickplay/…`, `BaseItemDto.Trickplay`) | no | yes | yes | yes (`ItemId` dropped from the info object) | yes | 10.9.0 [3][4][5] |
| Media segments (`GET /MediaSegments/{itemId}`) | no | no | yes | yes | yes | 10.10.0 [6][7] |
| Current DeviceProfile shape (no DLNA fields) | no (DLNA-era fields) | yes | yes (`Id` string→Guid) | yes (+`NumStreams` condition) | yes (+`VideoRotation` condition) | 10.9.0 [8] |
| `POST /Items/{id}/PlaybackInfo` with `PlaybackInfoDto` body | yes | yes | yes | yes | yes (+`AlwaysBurnInSubtitleWhenTranscoding`) | ≤10.8 [9] |
| `Authorization: MediaBrowser Client=…, Device=…, DeviceId=…, Version=…, Token=…` | yes | yes | yes | yes (preferred) | yes (**only scheme by default**) | ≤10.7.0 [10][11] |
| `Sessions/Playing`, `/Progress`, `/Stopped` reporting | yes | yes | yes | yes | yes | ≤10.8 [12] |
| `/UserItems/…`, `/UserPlayedItems/…` (userId-free routes) | no | yes | yes | yes | yes | 10.9.0 [13] |
| Fine-grained Dolby Vision `VideoRangeType` (`DOVIWithEL`, `DOVIWithHDR10Plus`, …) | – | no | no | yes | yes | 10.11.0 [14] |

"yes" means the code is present at that release tag. Every row was checked against source at the tags listed in Sources.

## Feature details

### Quick Connect
- `QuickConnectController.cs` is absent at v10.6.4 and present at v10.7.0 [1]. 10.7.0 was released 2021-03-08 [15].
- `POST /QuickConnect/Initiate` was added in 10.9.0 alongside `GET` [2]. 10.11.0 marks GET `[Obsolete("Use POST request instead")]` [2]. 12.0 removes `GET /QuickConnect/Initiate` [16][17].
- **Implication:** always use POST. That works from 10.9.0 onwards, which is below the recommended floor anyway.

### Trickplay
- `TrickplayController.cs` first appears at v10.9.0. It exposes `Videos/{itemId}/Trickplay/{width}/tiles.m3u8` and `…/{index}.jpg`, and the routes are unchanged in 12.0 [3].
- The 10.9.0 blog post says trickplay "requires explicit client support" [4]. 10.10.0 added optional keyframe-only extraction, but it "must be explicitly enabled" [18]. Generation is a server admin setting, so a server can be new enough and still have no trickplay data. The client must handle an empty `Trickplay` map.
- `BaseItemDto.Trickplay` changed from `TrickplayInfo` (which includes `ItemId`) to `TrickplayInfoDto` (no `ItemId`) in 10.11.0. Width, Height, TileWidth, TileHeight, ThumbnailCount, Interval and Bandwidth are unchanged [5].

### Media segments (skip intro/credits)
- `MediaSegmentsController.cs` first appears at v10.10.0 with `GET /MediaSegments/{itemId}?includeSegmentTypes=…`. Route and parameters are the same in 12.0 [6].
- `MediaSegmentDto` has Id, ItemId, Type, StartTicks and EndTicks in both 10.10.0 and 12.0 [7]. The `MediaSegmentType` values are Unknown, Commercial, Preview, Recap, Outro and Intro, and they are identical in 10.10.0 and 12.0. The enum moved to `src/Jellyfin.Database/…` in 10.11, which changes nothing on the wire [7].
- 10.10.0 blog: "you will still require a plugin to create them" [18]. As with trickplay, a new-enough server may have no segments, and the UI must degrade gracefully.

### PlaybackInfo / DeviceProfile
- In 10.9.0, `DeviceProfile` lost all its DLNA-era fields (Identification, FriendlyName, Manufacturer, XmlRootAttributes, ResponseProfiles, …). It now has Name, Id, the four bitrate caps, and DirectPlay/Transcoding/Container/Codec/Subtitle profiles. This is the same shape as 12.0 [8]. 10.9.0 also moved DLNA out of core into a plugin [4].
- 10.10.0 changed `DeviceProfile.Id` from `string?` to `Guid?` and added `TranscodingProfile.EnableAudioVbrEncoding`. In 12.0, `TranscodingProfile.BreakOnNonKeyFrames` is `bool?` [8].
- `ProfileConditionValue` only grows: `NumStreams` appears in 10.11.0 and `VideoRotation` in 12.0 [8][16]. Do not send a condition the server does not know. Gate it on the detected version, or leave it out (the tvOS profile does not need `VideoRotation`).
- `PlaybackInfoDto` (the POST body) has the same fields from 10.8.13 through 12.0, apart from the new optional `AlwaysBurnInSubtitleWhenTranscoding` in 12.0. The query-string variants have been `[ParameterObsolete]` since at least 10.8.13 [9].
- `VideoRangeType` gained `DOVIWithEL`, `DOVIWithHDR10Plus`, `DOVIWithELHDR10Plus` and `DOVIInvalid` in 10.11.0 [14]. On 10.10, a Dolby Vision file with an enhancement layer is reported with a coarser type. The core's direct-play decision for DV on Apple TV is less precise there, but it still works.

### Authorization
- At v10.7.0 the server reads `X-Emby-Authorization` and then the standard `Authorization` header, and accepts the scheme names `MediaBrowser` or `Emby` [10].
- 10.11.0 added `EnableLegacyAuthorization` (default `true`). The `Authorization` header is read first. The following are accepted only while that flag is on: `X-Emby-Authorization`, the `Emby` scheme name, `X-Emby-Token` / `X-MediaBrowser-Token` headers, and the lowercase `api_key` query parameter [11]. `ApiKey` (PascalCase) query is **not** behind the flag [11].
- In 12.0 the default is `false` [11]. The 12.0 notes say "a migration disables it on existing installs as well" [16].
- **Implication:** send `Authorization: MediaBrowser Client="…", Device="…", DeviceId="…", Version="…", Token="…"` everywhere. For URLs handed to AVPlayer or image loaders, where setting headers is awkward, use the `ApiKey=` query parameter, never `api_key=`. This works on every version from 10.8 onward [11]. (10.8.0 already reads `ApiKey` [11]; not checked for 10.7.)

### Playback reporting and other routes
- `POST /Sessions/Playing`, `/Sessions/Playing/Progress`, `/Sessions/Playing/Ping` and `/Sessions/Playing/Stopped` exist unchanged from 10.8.13 to 12.0 [12].
- The `/PlayingItems/…` and `/Users/{userId}/PlayingItems/…` routes are obsolete. 10.11.0 says they "will be removed in a future version" [19]. They are still present in 12.0 [12]. Do not use them.
- 10.9.0 introduced userId-free routes (`/UserItems/Resume`, `/UserItems/{id}/UserData`, `/UserPlayedItems/{id}`). The old `/Users/{userId}/…` forms are kept "for backwards compatibility" [13]. Use the new forms; they exist on every version at or above the recommended floor.
- 12.0 removed `/emby/*` and `/mediabrowser/*` route prefixes. Don't use them [16].

## Breaking changes between 10.8, 10.9, 10.10, 10.11 and 12.x (client-relevant)

| Version | Date | Client-relevant changes |
|---|---|---|
| 10.9.0 | 2024-05-11 | Trickplay added. DLNA moved to a plugin, which shrank DeviceProfile. EasyPassword/PIN login removed (Quick Connect kept). POST Quick Connect Initiate and userId-free routes added. Endpoints "return proper status codes" [4][15] |
| 10.10.0 | 2024-10-26 | Media segments added. `DeviceProfile.Id` becomes a Guid. "Most clients should continue to work as-is" [18][15] |
| 10.11.0 | 2025-10-20 | EF Core database rewrite. `EnableLegacyAuthorization` flag added. Old auth methods and `/PlayingItems` reporting deprecated. Server may return `503` with `Retry-After` during startup/shutdown. Parental ratings move to `ratingScore`. Trickplay DTO drops `ItemId`. New DV range types. Upgrade only from 10.10.7 [19][14][5] |
| 12.0 | 2026-09-08 | Version scheme drops the leading `10.`, so the server reports `12.0.0`. Legacy auth disabled by default and on existing installs. `/emby` and `/mediabrowser` prefixes removed. `GET /QuickConnect/Initiate` removed. Image endpoints no longer upscale beyond source resolution. Swashbuckle v10, "SDKs need regeneration" [16][17][20] |
| 12.1–12.4 | 2026-09-15 to 2026-10-26 | Bug-fix releases. No API changes in the notes. 12.2 "Use hvc1 for Dolby Vision profile 8" (PR #18300) matters for AVPlayer when DV is remuxed/transcoded to HLS. The `hvc1` tag requirement is Apple-side and not verified here [21] |

## Release and support cadence

- Major releases: 10.7.0 (2021-03), 10.8.0 (2022-06), 10.9.0 (2024-05), 10.10.0 (2024-10), 10.11.0 (2025-10), 12.0 (2026-09). That is roughly 5–12 months apart [15].
- No branch has had a stable release after its successor shipped. The last releases were 10.9.11 on 2024-09-07, 10.10.7 on 2025-04-05 and 10.11.11 on 2026-06-06, each before the next major [15].
- Security policy: "Only the most recent stable release of Jellyfin server is guaranteed to have security patches applied." [22]
- Upgrade paths: 10.11.0 requires 10.10.7 [19]. 12.0 accepts 10.10.7+ or 10.11.x [16][17]. So 10.10.7 is the oldest version that can upgrade directly to current. That makes it a reasonable floor for users we would have to ask to upgrade.
- Planning: the 2026-05-24 "State of the Fin" mentions early planning for 13.0. It gives no date [23].

## Version detection at connect time

- `GET /System/Info/Public` needs no auth. It returns `PublicSystemInfo` with `Version`, `ProductName`, `Id`, `ServerName`, `LocalAddress` and `StartupWizardCompleted`. The fields are the same in 10.9.0 and 12.0 [24]. The route is `[HttpGet("Info/Public")]` in `SystemController` [25].
- `Version` is `Assembly.GetName().Version.ToString(3)`, giving `10.11.0` or `12.0.0`. `SharedVersion.cs` shows `12.4.0` for 12.4 [26].
- **Parse it as a three-part numeric version** and compare as a tuple: (10, 10, 0) < (10, 11, 0) < (12, 0, 0). Do not compare strings and do not assume the major is 10. The 12.0 notes warn that clients parsing version strings should be checked [17].
- Check `ProductName` for "Jellyfin Server" to tell Jellyfin apart from Emby. The exact string was not verified in source for every version (**unconfirmed**).

## Public data on deployed versions

- **Unconfirmed / none found.** Jellyfin has no telemetry that publishes version distribution. The jellyfin.org About page and the 2026-05-24 State of the Fin contain no install or version statistics [23][27]. I found no first-party source for how many servers run 10.10 or earlier versus 10.11 or 12.x. Third-party scans (e.g. Shodan) were not consulted, since they are not primary sources.

## Recommendation (input for the grilling ticket)

1. **Hard minimum: 10.10.0.** It is the first version with every v1 server feature (Quick Connect, trickplay, media segments), using the same DeviceProfile and PlaybackInfo shapes as 12.x. Supporting it costs almost nothing extra: the same request code works from 10.10 to 12.4, if the client (a) uses only the modern auth header and `ApiKey`, (b) uses POST Quick Connect and `/UserItems` routes, (c) ignores unknown enum values and JSON fields, and (d) only sends ProfileConditions the server knows.
2. **Test matrix:** 10.10.7, 10.11.11, latest 12.x. These are the last release of each branch plus current.
3. **Below 10.10.0:** refuse after `/System/Info/Public`, with "Jellyfin 10.10 or newer required". Do not add feature flags to degrade for 10.9; it is two branches past end of updates.
4. **Alternative to weigh in grilling:** a 10.11.0 floor. It gains the finer DV range types, `NumStreams` and `503`/`Retry-After` semantics, and drops one matrix entry. It loses 10.10 users, and how many there are is unknown (see above).
5. Feature presence ≠ data presence. Trickplay and segments depend on server config and plugins, so the UI must handle an empty map or list on any version.

## Sources

Tags refer to `jellyfin/jellyfin`. Checked 2026-11-07.

1. QuickConnectController presence: https://github.com/jellyfin/jellyfin/blob/v10.7.0/Jellyfin.Api/Controllers/QuickConnectController.cs (absent at https://github.com/jellyfin/jellyfin/tree/v10.6.4/Jellyfin.Api/Controllers)
2. Quick Connect Initiate verbs: https://github.com/jellyfin/jellyfin/blob/v10.8.13/Jellyfin.Api/Controllers/QuickConnectController.cs, https://github.com/jellyfin/jellyfin/blob/v10.9.0/Jellyfin.Api/Controllers/QuickConnectController.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/Jellyfin.Api/Controllers/QuickConnectController.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/QuickConnectController.cs
3. Trickplay controller: https://github.com/jellyfin/jellyfin/blob/v10.9.0/Jellyfin.Api/Controllers/TrickplayController.cs (absent at v10.8.13), https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/TrickplayController.cs
4. 10.9.0 release post: https://jellyfin.org/posts/jellyfin-release-10.9.0
5. Trickplay DTO: https://github.com/jellyfin/jellyfin/blob/v10.10.0/MediaBrowser.Model/Dto/BaseItemDto.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/MediaBrowser.Model/Dto/BaseItemDto.cs, https://github.com/jellyfin/jellyfin/blob/v10.9.0/Jellyfin.Data/Entities/TrickplayInfo.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/Dto/TrickplayInfoDto.cs
6. MediaSegments controller: https://github.com/jellyfin/jellyfin/blob/v10.10.0/Jellyfin.Api/Controllers/MediaSegmentsController.cs (absent at v10.9.0), https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/MediaSegmentsController.cs
7. Segment DTO and enum: https://github.com/jellyfin/jellyfin/blob/v10.10.0/MediaBrowser.Model/MediaSegments/MediaSegmentDto.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/MediaSegments/MediaSegmentDto.cs, https://github.com/jellyfin/jellyfin/blob/v10.10.0/Jellyfin.Data/Enums/MediaSegmentType.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/src/Jellyfin.Database/Jellyfin.Database.Implementations/Enums/MediaSegmentType.cs
8. DeviceProfile / TranscodingProfile / ProfileConditionValue: https://github.com/jellyfin/jellyfin/blob/v10.8.13/MediaBrowser.Model/Dlna/DeviceProfile.cs, https://github.com/jellyfin/jellyfin/blob/v10.9.0/MediaBrowser.Model/Dlna/DeviceProfile.cs, https://github.com/jellyfin/jellyfin/blob/v10.10.0/MediaBrowser.Model/Dlna/DeviceProfile.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/Dlna/DeviceProfile.cs, https://github.com/jellyfin/jellyfin/blob/v10.10.0/MediaBrowser.Model/Dlna/TranscodingProfile.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/Dlna/TranscodingProfile.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/MediaBrowser.Model/Dlna/ProfileConditionValue.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/Dlna/ProfileConditionValue.cs
9. PlaybackInfo: https://github.com/jellyfin/jellyfin/blob/v10.8.13/Jellyfin.Api/Models/MediaInfoDtos/PlaybackInfoDto.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Models/MediaInfoDtos/PlaybackInfoDto.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/MediaInfoController.cs
10. Auth parsing 10.7.0: https://github.com/jellyfin/jellyfin/blob/v10.7.0/Emby.Server.Implementations/HttpServer/Security/AuthorizationContext.cs
11. Auth parsing 10.8–12.0 and the flag: https://github.com/jellyfin/jellyfin/blob/v10.8.0/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/MediaBrowser.Model/Configuration/ServerConfiguration.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/Configuration/ServerConfiguration.cs
12. Playstate routes: https://github.com/jellyfin/jellyfin/blob/v10.8.13/Jellyfin.Api/Controllers/PlaystateController.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/PlaystateController.cs
13. userId-free routes: https://github.com/jellyfin/jellyfin/blob/v10.9.0/Jellyfin.Api/Controllers/ItemsController.cs, https://github.com/jellyfin/jellyfin/blob/v10.9.0/Jellyfin.Api/Controllers/PlaystateController.cs
14. VideoRangeType: https://github.com/jellyfin/jellyfin/blob/v10.10.0/Jellyfin.Data/Enums/VideoRangeType.cs, https://github.com/jellyfin/jellyfin/blob/v10.11.0/Jellyfin.Data/Enums/VideoRangeType.cs
15. Release list and dates: https://github.com/jellyfin/jellyfin/releases
16. 12.0 release notes: https://github.com/jellyfin/jellyfin/releases/tag/v12.0
17. 12.0 release post: https://jellyfin.org/posts/jellyfin-release-12.0/
18. 10.10.0 release post: https://jellyfin.org/posts/jellyfin-release-10.10.0
19. 10.11.0 release post: https://jellyfin.org/posts/jellyfin-release-10.11.0
20. Versioning note: https://github.com/jellyfin/jellyfin/releases/tag/v12.0-rc3 (points to the RC1 notes)
21. 12.1–12.4 notes: https://github.com/jellyfin/jellyfin/releases/tag/v12.1, https://github.com/jellyfin/jellyfin/releases/tag/v12.2, https://github.com/jellyfin/jellyfin/releases/tag/v12.3, https://github.com/jellyfin/jellyfin/releases/tag/v12.4 (12.1 and 12.2 read from the first ~30 changelog lines only)
22. Security policy: https://github.com/jellyfin/jellyfin/security
23. State of the Fin 2026-05-24: https://jellyfin.org/posts/state-of-the-fin-2026-05-24/
24. PublicSystemInfo: https://github.com/jellyfin/jellyfin/blob/v10.9.0/MediaBrowser.Model/System/PublicSystemInfo.cs, https://github.com/jellyfin/jellyfin/blob/v12.0/MediaBrowser.Model/System/PublicSystemInfo.cs
25. SystemController: https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/SystemController.cs
26. Version string: https://github.com/jellyfin/jellyfin/blob/v12.0/Emby.Server.Implementations/ApplicationHost.cs, https://github.com/jellyfin/jellyfin/blob/v12.4/SharedVersion.cs
27. About page: https://jellyfin.org/docs/general/about/

## Not confirmed from a primary source

- Any data on how many deployed servers run each version.
- That 12.1 and 12.2 contain no client-visible API changes (only the first ~30 changelog entries of each were read; 12.3 and 12.4 were read in full).
- `ProductName` string value across versions.
- Whether `ApiKey` (PascalCase) query auth works on 10.7.x (confirmed for 10.8.0+ only; irrelevant at a 10.10 floor).
- The exact PR numbers that introduced each feature. Versions were established by file presence at release tags, not by PR.
