# Jellyfin API flows for v1, and whether to generate the client

Research for [#47](https://github.com/sntna/server-media-player/issues/47). Checked on 2026-11-07 against
Jellyfin server **v12.4** (released 2026-10-26) and its published OpenAPI spec (`info.version` 12.4.0).

## Summary

- v1 needs about **30 of the 346 operations** in the stable spec (294 paths), plus two things outside the spec: UDP discovery on 7359 and the `/socket` WebSocket.
- Auth is one header, `Authorization: MediaBrowser Client="…", Device="…", DeviceId="…", Version="…", Token="…"`. Tokens have no expiry. Logging in again with the same `DeviceId` revokes the old token. Quick Connect is three unauthenticated calls with a 10-minute window.
- The server decides direct play, remux or transcode inside `POST /Items/{id}/PlaybackInfo`. It compares the media against the `DeviceProfile` we send. Direct play goes to `/Videos/{id}/stream?static=true`. Remux and transcode go to the `TranscodingUrl` the server returns. Those HLS endpoints were **removed from the OpenAPI spec in 12.0**.
- **Recommendation: write the client by hand in `core`, behind the `MediaServer` trait, and pin the spec as a test fixture.** We would only use a small slice of the spec, and generating from it has problems: 152 of the 155 fields on `BaseItemDto` are nullable, every response is listed under three JSON content types, auth is described as a plain API key, and the HLS endpoints are hidden. The only Rust crate generated from the spec gave up on methods and has not changed since 2024. Jellyfin's own Kotlin SDK needs a custom generator with hooks. Generating models only (no methods) is a possible later step and is not needed for v1.

## Endpoint map per v1 feature

All paths are relative to the server base URL. "Auth" means the `Authorization: MediaBrowser …` header with a `Token`. Source for every row: the stable spec [S1] unless noted.

| v1 feature | Call(s) | Auth | Notes |
|---|---|---|---|
| Server discovery | UDP broadcast `who is JellyfinServer?` to port **7359**. Reply is JSON `{Address, Id, Name, EndpointAddress}` | none | Not in OpenAPI. [J1][J2][K3]. Admins can turn it off (`AutoDiscovery` network setting) [J1] |
| Validate a typed/discovered URL | `GET /System/Info/Public` → `PublicSystemInfo {LocalAddress, ServerName, Version, ProductName, OperatingSystem, Id, StartupWizardCompleted}` | none | Use `Version` to gate features |
| Login screen user list | `GET /Users/Public` | none | Returns `UserDto[]` |
| Username/password | `POST /Users/AuthenticateByName` body `{Username, Pw}` → `AuthenticationResult {User, SessionInfo, AccessToken, ServerId}` | client fields only (no Token) | [J3][J4] |
| Quick Connect | `GET /QuickConnect/Enabled`; `POST /QuickConnect/Initiate` → `{Code, Secret, …}`; poll `GET /QuickConnect/Connect?secret=` until `Authenticated`; `POST /Users/AuthenticateWithQuickConnect` body `{Secret}` → `AuthenticationResult` | client fields only; Initiate **requires DeviceId** | 6-digit code, expires after 10 min [J5][J6][D2]. Another device approves with `POST /QuickConnect/Authorize?code=` (Auth) |
| Current user / profile image | `GET /Users/Me`; `GET /UserImage?userId=&tag=` (tag = `UserDto.PrimaryImageTag`) | Me: Auth; image: none | |
| Logout | `POST /Sessions/Logout` | Auth | Revokes the token |
| Register capabilities | `POST /Sessions/Capabilities/Full` body `ClientCapabilitiesDto {PlayableMediaTypes, SupportedCommands, SupportsMediaControl, DeviceProfile, …}` | Auth | If PlaybackInfo is sent without a profile, the server falls back to the one stored here [J7] |
| Libraries (home sections, browse roots) | `GET /UserViews` | Auth | |
| Continue Watching | `GET /UserItems/Resume?limit=&fields=&enableImageTypes=&mediaTypes=Video` | Auth | |
| Next Up | `GET /Shows/NextUp?limit=&fields=&enableResumable=&enableRewatching=&nextUpDateCutoff=` | Auth | |
| Latest per library | `GET /Items/Latest?parentId=<viewId>&limit=&fields=&groupItems=true` | Auth | Returns a bare array, not a `QueryResult` |
| Library browse (sort/filter/page) | `GET /Items?parentId=&recursive=true&includeItemTypes=Movie,Series&sortBy=&sortOrder=&filters=&genres=&years=&isPlayed=&isFavorite=&startIndex=&limit=&enableTotalRecordCount=&fields=` | Auth | `ItemSortBy` has 30 values and `ItemFilter` has 9. `GET /Items/Filters2` gives the genres/years available for filter UI. `nameStartsWith` supports A-Z jump |
| Search | `GET /Items?searchTerm=&recursive=true&includeItemTypes=…&limit=` or `GET /Search/Hints?searchTerm=` | Auth | Both exist. Which one official clients prefer is **unconfirmed** |
| Item details | `GET /Items/{itemId}` (optional `userId`) | Auth | Returns `BaseItemDto` with `UserData`, `MediaSources`, `Chapters`, `Trickplay` and image tags |
| Seasons / episodes | `GET /Shows/{seriesId}/Seasons`; `GET /Shows/{seriesId}/Episodes?seasonId=&fields=&startIndex=&limit=` | Auth | |
| Favourite toggle | `POST` / `DELETE /UserFavoriteItems/{itemId}` | Auth | Returns `UserItemDataDto` |
| Watched toggle | `POST` / `DELETE /UserPlayedItems/{itemId}` (optional `datePlayed`) | Auth | Returns `UserItemDataDto` |
| Images | `GET /Items/{itemId}/Images/{imageType}?tag=&maxWidth=&maxHeight=&fillWidth=&fillHeight=&quality=&format=` | none | Details below [J8] |
| Playback decision | `POST /Items/{itemId}/PlaybackInfo` body `PlaybackInfoDto {DeviceProfile, MaxStreamingBitrate, StartTimeTicks, AudioStreamIndex, SubtitleStreamIndex, MediaSourceId, EnableDirectPlay, EnableDirectStream, EnableTranscoding, …}` → `PlaybackInfoResponse {MediaSources[], PlaySessionId, ErrorCode}` | Auth | All 14 query parameters are marked deprecated, so send everything in the body [J7] |
| Direct-play stream | `GET /Videos/{itemId}/stream?static=true&mediaSourceId=&playSessionId=&tag=&ApiKey=` | none required by server (see below) | [J9][W2] |
| Remux / transcode stream | `MediaSourceInfo.TranscodingUrl` (server-built HLS `master.m3u8` URL), resolved against the base URL | Auth carried in URL | HLS controller is hidden from the spec [J10][J11] |
| External subtitles | `GET /Videos/{routeItemId}/{routeMediaSourceId}/Subtitles/{routeIndex}/Stream.{routeFormat}` (also exposed as `MediaStream.DeliveryUrl`, **unconfirmed** which one clients use) | none in spec | |
| Playback reporting | `POST /Sessions/Playing` (`PlaybackStartInfo`), `POST /Sessions/Playing/Progress` (`PlaybackProgressInfo`), `POST /Sessions/Playing/Stopped` (`PlaybackStopInfo`), `POST /Sessions/Playing/Ping?playSessionId=` | Auth | The server auto-stops playing sessions with no check-in for >5 min [J12] |
| Skip intro / credits | `GET /MediaSegments/{itemId}?includeSegmentTypes=Intro,Outro,…` → `MediaSegmentDto {Id, ItemId, Type, StartTicks, EndTicks}` | Auth | Types: Unknown, Commercial, Preview, Recap, Outro, Intro. `MediaSourceInfo.HasSegments` says whether to ask |
| Scrub thumbnails | `BaseItemDto.Trickplay` (map mediaSourceId → width → `TrickplayInfoDto {Width, Height, TileWidth, TileHeight, ThumbnailCount, Interval, Bandwidth}`; request `fields=Trickplay`), then `GET /Videos/{itemId}/Trickplay/{width}/{index}.jpg?mediaSourceId=` | Auth | `tiles.m3u8` also exists (an HLS image playlist) [J13] |
| Live updates | WebSocket `/socket` with the same auth | Auth | Details below [J14][K2] |

Everything we would otherwise need for v1 under `/Users/{userId}/…` (for example `/Users/{userId}/Items/{itemId}`, `/Users/{userId}/FavoriteItems/{itemId}`) is still routed but is the legacy form. The spec lists the user-less paths above [J15]. Use the user-less ones.

## Details

### Discovery

- The server binds UDP **7359** on `IPAddress.Any`. When a datagram contains `who is JellyfinServer?` (case-insensitive) it replies with `ServerDiscoveryInfo(localUrl, SystemId, FriendlyName)`. The background service only runs if `networkConfig.AutoDiscovery` is set. [J1] (lines 25, 55–60, 76, 100–107), [J2]
- The official Kotlin SDK sends the same string to port 7359, waits 500 ms per receive and stops after 15 servers. [K3]
- jellyfin.org lists 7359/UDP as the discovery port. [D1]
- tvOS needs the local-network permission and, for broadcast, possibly the multicast entitlement. That is platform work and **not checked here**.

### Authorization header, device id, token lifetime

- The server reads `DeviceId`, `Device`, `Client`, `Version` and `Token` from `Authorization: MediaBrowser k="v", …`. It URL-decodes the values and accepts the scheme name case-insensitively. [J3] (lines 86–90, 258, `GetParts`)
- Without the header, the server only falls back to the `ApiKey` query parameter. `X-Emby-Authorization`, `X-Emby-Token`, `X-MediaBrowser-Token`, `api_key` and the `Emby` scheme are accepted **only if `EnableLegacyAuthorization` is on** [J3] (lines 93–110, 233–235). That is a `bool` with no initialiser, so it defaults to off [J16] (line 290). **Use the `MediaBrowser` header, and `ApiKey=` for URLs handed to the player.**
- Kotlin SDK reference format: `MediaBrowser Client="…", Version="…", DeviceId="…", Device="…", Token="…"`. The SDK URL-encodes values, turns newlines into spaces and leaves out `Token` until we have one. [K1]
- **Device id:** authenticating creates a `Device` row keyed by `(UserId, DeviceId)`, and any existing row for that pair is logged out first [J4] (lines 1784–1812). So the device id must be **stable per install**. If two installs share one id they log each other out. Quick Connect also refuses an empty `DeviceId` [J6] (line 74).
- **Token lifetime:** the `Device` entity has `AccessToken`, `DateCreated`, `DateModified` and `DateLastActivity`, and no expiry field [J17]. Tokens last until `POST /Sessions/Logout`, re-auth from the same device id, or an admin deleting the device. Store the token in the Keychain. Treat `401` as "signed out", not as "refresh".
- The spec describes auth as `apiKey` in the `Authorization` header (`CustomAuthentication`) [S1]. That does not capture the `MediaBrowser` field format.

### Playback decision: direct play, remux, transcode

- `POST /Items/{id}/PlaybackInfo` takes the `DeviceProfile` from the body. If there is none, it uses the profile saved with `/Sessions/Capabilities/Full` for this device. The legacy query parameters are each overridden by the body field [J7] (lines 116–160). `EnableDirectPlay` and `EnableDirectStream` default to `true`.
- `StreamBuilder` checks each `MediaSource` against the profile's `DirectPlayProfiles` (container + codecs), `CodecProfiles` conditions (profile, level, bit depth, range type, …), `SubtitleProfiles` and the bitrate limit. It collects `TranscodeReason` flags. [J18]
  - **DirectPlay** if there are no failure reasons and the source supports direct play (line 1392).
  - **DirectStream** (remux, video copied) if the only remaining reasons are in `DirectStreamReasons` = audio reasons, `ContainerNotSupported` or `VideoCodecTagNotSupported` (lines 27, 1388–1398).
  - Otherwise **Transcode** using the first matching `TranscodingProfile`.
- The answer comes back on each `MediaSourceInfo`: `SupportsDirectPlay`, `SupportsDirectStream`, `SupportsTranscoding`, and `TranscodingUrl` / `TranscodingSubProtocol` / `TranscodingContainer` when the server will remux or transcode [S1].
- **What Swiftfin (official tvOS client) does with it** [W2]: POST PlaybackInfo, then if `transcodingURL` is set, play that path resolved against the server. Otherwise build `/Videos/{id}/stream` with `static=true`, `tag=eTag`, `playSessionId`, `mediaSourceId`, `liveStreamId` and the API key in the query.
- So the "direct-play vs transcode decision" that AGENTS.md puts in `core` is in practice: **build the `DeviceProfile` for this device and engine, then read the server's answer**. The server does the matching. `core` owns the profile (per engine: AVPlayer vs the MKV-capable engine) and the URL choice. Swiftfin keeps per-engine profiles in `DeviceProfile.swift` [W3].
- `TranscodeReason` has 28 values. Log them; they are the main way to debug "why is this transcoding".

### Stream URLs and HLS not being in the spec

- `GET /Videos/{itemId}/stream` has **no `[Authorize]` attribute** in v12.4 [J9] (line 314), and the spec has no security on it. Swiftfin still adds the API key [W2]. We should too, because it ties the stream to the session and is harmless.
- In PR #16715 (merged 2026-04-29, shipped in 12.0, which was called 10.12 at the time) `DynamicHlsController` and `HlsSegmentController` got `[ApiExplorerSettings(IgnoreApi = true)]`. That removed `master.m3u8`, `main.m3u8`, `live.m3u8` and `hls1/…` from the OpenAPI spec. The routes still exist and require auth. [J10][J11]
- Consequence: a client generated from the spec cannot build HLS URLs. Clients are expected to use `TranscodingUrl`.

### Images

- `GET /Items/{itemId}/Images/{imageType}` takes `maxWidth`, `maxHeight`, `width`, `height`, `fillWidth`, `fillHeight`, `quality` (0–100, default 90), `format` (`Bmp|Gif|Jpg|Png|Webp|Svg`), `tag`, `blur`, `percentPlayed`, `unplayedCount`, `backgroundColor`, `foregroundLayer` and `imageIndex`. [S1][J8]
- With a `tag`, the server sends `Cache-Control: public, max-age=…, immutable` and an `ETag` of the tag, and answers `If-None-Match`. A `no-cache` request header turns caching off [J8] (lines 2008–2050). **Always send `tag`** (from `ImageTags`, `BackdropImageTags`, `SeriesPrimaryImageTag`, etc.) and use `fillWidth`/`fillHeight` at the exact tile pixel size. That meets the AGENTS.md image budget.
- `ImageBlurHashes` on `BaseItemDto` can supply placeholders.
- Image endpoints have no security requirement in the spec [S1].

### Playback reporting

- Start, Progress and Stopped bodies share `ItemId`, `MediaSourceId`, `PlaySessionId` (from PlaybackInfo), `PositionTicks` (100 ns), `IsPaused`, `PlayMethod`, `AudioStreamIndex` and `SubtitleStreamIndex` [S1].
- The server checks every 5 minutes and synthesises a stop for any playing session with no check-in for **more than 5 minutes** [J12] (lines 609, 639–660). So progress, or `/Sessions/Playing/Ping`, must be sent more often than that while paused.
- Swiftfin reports on a timer and queues reports so they stay in order [W4]. Its exact interval is **unconfirmed**. Pick something like 10 s and measure.

### WebSocket

- Any WebSocket upgrade passes through the same authentication and is rejected without a token [J14]. Official SDKs connect to `/socket` [K2].
- The server sends `ForceKeepAlive` with a 60 s lost-timeout and expects `KeepAlive` from the client. It sends `ForceKeepAlive` at 75% of the timeout and drops the socket at 60 s [J19] (lines 26, 36, 207–233).
- Messages are typed in the spec: `OutboundWebSocketMessage` is a `oneOf` over `SessionMessageType` (34 values) [S1].
- Worth using in v1: **`UserDataChanged`** (watched, favourite and progress changes from other devices, to keep the SQLite cache fresh) and **`LibraryChanged`** (invalidate rows). `Play`, `Playstate` and `GeneralCommand` (remote control) can wait. v1 can work without the socket by refetching on focus. Treat it as a cache-freshness optimisation.

### OpenAPI spec quality

From the published stable spec [S1]:

- OpenAPI **3.0.4**, 294 paths and 346 operations, 357 schemas. Every operation has an `operationId`. Generated by Swashbuckle from controller attributes.
- 152 of 155 `BaseItemDto` properties are `nullable` and none are `required`. Generated types would be almost all `Option`, which is honest but not helpful.
- Nearly every JSON response is listed under three content types (`application/json`, `…; profile="CamelCase"`, `…; profile="PascalCase"`) plus `text/html` for 503. That is 366 responses with more than one content type.
- Request bodies are wrapped in `allOf: [$ref]` (530 `allOf` occurrences).
- Auth is modelled as a generic API key and does not capture the `MediaBrowser` format.
- HLS endpoints are hidden (see above). Image and stream endpoints return binary bodies (`image/*`, `video/*`).
- The spec is versioned with the server. api.jellyfin.org publishes `stable`, `stable_previous`, `unstable` and `unstable_previous` [S2].

### Existing clients and generators

| Project | What it is | Health (2026-11-07) |
|---|---|---|
| jellyfin-sdk-kotlin [K4] | Official. **Custom generator** from openapi.json with a hook system to rewrite types (for example `ImageBlurHashes`) [K5] | Active, v1.9.4 2026-10-26 |
| jellyfin-sdk-swift [W5] | Official, used by Swiftfin. README says it is generated with a fork of openapi-generator by LePips and also "CreateAPI" via `make update` (the README contradicts itself). It adds hand-written discovery, sign-in and WebSocket | Active, 3.3.0 2026-10-02 |
| `jellyfin_api` crate [R1] | Rust, generated with a **progenitor fork**. README: "only exposes models … the tool used to generate the client doesn't support generating a lot of the API methods" | Stale, last release 10.9.2-1 2024-05-23 |
| `jellyfin-sdk` crate [R2] | Rust, hand-written reqwest client, uses the spec for metadata only | 0.1.0 2026-01-03, single release, 2 stars |
| `jellyfin-client` crate [R3] | Rust, hand-written (Quick Connect, browse, PlaybackInfo, reporting) inside an unrelated XR repo | 0.1.2 2026-11-04, 60 downloads |
| `jellyfin` / `jellyfin-sdk-rust` crates [R4][R5] | Rust, user API only / early | Stale (2024 / 2021) |
| progenitor [G1] | Oxide's OpenAPI **3.0.x** Rust generator, reqwest-based | Active, 0.15.1 2026-10-09 |
| openapi-generator `rust` [G2] | Java-based generator | Active, v7.27.0 2026-11-02 |

No maintained, official or widely used Rust Jellyfin client exists.

### Recommendation: hand-written client, spec as a test fixture

1. **Hand-write** a `JellyfinClient` in `core` implementing `MediaServer`. It needs about 30 typed calls, serde models trimmed to the fields we request (with `#[serde(default)]` and `Option` where the server can actually omit them), one place that builds the `MediaBrowser` header, and `ApiKey` URL building for the player.
   - Why: we use about 9% of operations.
   - The two most important flows (HLS via `TranscodingUrl`, and the auth header) are outside what the spec describes.
   - A hand-written client lets us keep models small. That helps the 10k-item and memory budgets.
   - It avoids a generator toolchain dependency (AGENTS.md: dependencies are a cost).
2. **Pin the spec** (`jellyfin-openapi-stable.json` for the oldest server we support) under `core/tests/fixtures/`. Add a test that checks every path, method and query parameter we call exists in it. This catches drift when we bump the supported server version.
3. **Revisit generation for models only** if the hand-written models grow past what is comfortable. Spike progenitor (or `typify` on just the schemas) at that point. Whether stock progenitor handles the multi-content-type responses is **unconfirmed**. The `jellyfin_api` README suggests it does not handle most methods.

## Unconfirmed / open

- Whether stock progenitor or openapi-generator can generate a working client from the 12.4 spec. No Rust toolchain was run for this research. The evidence is indirect: [R1], and the Kotlin SDK needing hooks.
- Swiftfin's progress-report interval, and whether official clients prefer `/Search/Hints` or `/Items?searchTerm=` for search.
- Which subtitle URL clients use (`DeliveryUrl` vs building the `Stream.{format}` route).
- Why 10.12 was renumbered 12.0. The PR bot comment on #16715 says "v 10.12.0", while the releases are tagged `v12.x`. Also open: the **minimum server version** v1 supports. This is a product decision for the map. 10.9 added media segments, and 10.9 or later is the likely floor (**unconfirmed**).
- tvOS local-network and multicast entitlement needs for UDP broadcast.

## Sources

- [S1] Jellyfin stable OpenAPI spec (12.4.0): https://api.jellyfin.org/openapi/jellyfin-openapi-stable.json
- [S2] Spec index: https://api.jellyfin.org/openapi/
- [J1] AutoDiscoveryHost: https://github.com/jellyfin/jellyfin/blob/v12.4/src/Jellyfin.Networking/AutoDiscoveryHost.cs
- [J2] ServerDiscoveryInfo: https://github.com/jellyfin/jellyfin/blob/v12.4/MediaBrowser.Model/ApiClient/ServerDiscoveryInfo.cs
- [J3] AuthorizationContext: https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs
- [J4] SessionManager (token creation, logout, idle check): https://github.com/jellyfin/jellyfin/blob/v12.4/Emby.Server.Implementations/Session/SessionManager.cs
- [J5] QuickConnectController: https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/QuickConnectController.cs
- [J6] QuickConnectManager (CodeLength 6, Timeout 10 min): https://github.com/jellyfin/jellyfin/blob/v12.4/Emby.Server.Implementations/QuickConnect/QuickConnectManager.cs
- [J7] MediaInfoController (PlaybackInfo): https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/MediaInfoController.cs
- [J8] ImageController (params, caching headers): https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/ImageController.cs
- [J9] VideosController (`stream` has no `[Authorize]`): https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/VideosController.cs
- [J10] DynamicHlsController (`IgnoreApi = true`): https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/DynamicHlsController.cs
- [J11] PR #16715 "hide HLS controllers and deprecate unused endpoints": https://github.com/jellyfin/jellyfin/pull/16715 (commit https://github.com/jellyfin/jellyfin/commit/c59d3bb21a7a892a7e3c259843b001c57cfc18e0)
- [J12] SessionManager idle playback check (same file as J4, `CheckForIdlePlayback`)
- [J13] TrickplayController: https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/TrickplayController.cs
- [J14] WebSocketManager (auth on upgrade): https://github.com/jellyfin/jellyfin/blob/v12.4/Emby.Server.Implementations/HttpServer/WebSocketManager.cs
- [J15] UserLibraryController (legacy `/Users/{userId}/…` routes): https://github.com/jellyfin/jellyfin/blob/v12.4/Jellyfin.Api/Controllers/UserLibraryController.cs
- [J16] ServerConfiguration (`EnableLegacyAuthorization`): https://github.com/jellyfin/jellyfin/blob/v12.4/MediaBrowser.Model/Configuration/ServerConfiguration.cs
- [J17] Device entity (no expiry): https://github.com/jellyfin/jellyfin/blob/v12.4/src/Jellyfin.Database/Jellyfin.Database.Implementations/Entities/Security/Device.cs
- [J18] StreamBuilder: https://github.com/jellyfin/jellyfin/blob/v12.4/MediaBrowser.Model/Dlna/StreamBuilder.cs
- [J19] SessionWebSocketListener (keep-alive): https://github.com/jellyfin/jellyfin/blob/v12.4/Emby.Server.Implementations/Session/SessionWebSocketListener.cs
- [J20] Jellyfin releases (v12.4, 2026-10-26): https://github.com/jellyfin/jellyfin/releases/tag/v12.4
- [D1] jellyfin.org networking docs (7359/UDP): https://jellyfin.org/docs/general/post-install/networking/
- [D2] jellyfin.org Quick Connect docs: https://jellyfin.org/docs/general/server/quick-connect/
- [K1] Kotlin SDK AuthorizationHeaderBuilder: https://github.com/jellyfin/jellyfin-sdk-kotlin/blob/master/jellyfin-api/src/commonMain/kotlin/org/jellyfin/sdk/api/client/util/AuthorizationHeaderBuilder.kt
- [K2] Kotlin SDK DefaultSocketApi (`SOCKET_URL = "/socket"`): https://github.com/jellyfin/jellyfin-sdk-kotlin/blob/master/jellyfin-api/src/commonMain/kotlin/org/jellyfin/sdk/api/sockets/DefaultSocketApi.kt
- [K3] Kotlin SDK LocalServerDiscovery: https://github.com/jellyfin/jellyfin-sdk-kotlin/blob/master/jellyfin-core/src/jvmCommonMain/kotlin/org/jellyfin/sdk/discovery/LocalServerDiscovery.kt
- [K4] jellyfin-sdk-kotlin: https://github.com/jellyfin/jellyfin-sdk-kotlin
- [K5] Kotlin SDK generator README (hooks): https://github.com/jellyfin/jellyfin-sdk-kotlin/blob/master/openapi-generator/README.md
- [W2] Swiftfin MediaPlayerItemResolver (PlaybackInfo → TranscodingUrl or static stream): https://github.com/jellyfin/Swiftfin/blob/main/Shared/Objects/MediaPlayerManager/MediaPlayerItem/MediaPlayerItemResolver.swift
- [W3] Swiftfin DeviceProfile extension: https://github.com/jellyfin/Swiftfin/blob/main/Shared/Extensions/JellyfinAPI/DeviceProfile.swift
- [W4] Swiftfin MediaProgressReporter: https://github.com/jellyfin/Swiftfin/blob/main/Shared/Objects/MediaPlayerManager/MediaProgressReporter.swift
- [W5] jellyfin-sdk-swift: https://github.com/jellyfin/jellyfin-sdk-swift
- [R1] `jellyfin_api` crate: https://crates.io/crates/jellyfin_api (repo https://codeberg.org/avery42/jellyfin-api-rust)
- [R2] `jellyfin-sdk` crate: https://crates.io/crates/jellyfin-sdk (repo https://github.com/Latias94/jellyfin-sdk)
- [R3] `jellyfin-client` crate: https://crates.io/crates/jellyfin-client (repo https://github.com/Josh-Archer/questkit)
- [R4] `jellyfin` crate: https://crates.io/crates/jellyfin
- [R5] `jellyfin-sdk-rust` crate: https://crates.io/crates/jellyfin-sdk-rust (GitHub repo now 404)
- [G1] progenitor: https://github.com/oxidecomputer/progenitor
- [G2] openapi-generator: https://github.com/OpenAPITools/openapi-generator
