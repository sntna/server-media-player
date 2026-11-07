# Can a Rust core with UniFFI ship in a tvOS app?

Research for issue #48. Checked on 2026-11-07. Nothing here was compiled. The Linux research box has no Xcode and no Rust toolchain, so every claim comes from the cited source.

**Verdict: feasible today on stable Rust, with no hard blockers.** Since Rust 1.95.0 (2026-04-16), `aarch64-apple-tvos` and `aarch64-apple-tvos-sim` are Tier 2 targets, and rustup ships their prebuilt `std`, so neither nightly nor `-Zbuild-std` is needed. UniFFI's Swift bindings handle async functions and foreign-implemented traits. They do not handle streams, so model event streams as a listener trait. Package the core as a static-library XCFramework inside a local Swift package. The only nightly-only slice is the Intel-Mac tvOS simulator (`x86_64-apple-tvos`, Tier 3), and we can skip it. The main risks are maturity, not missing support: the tvOS targets are newly promoted, some C-backed crates do not list tvOS device CI, and tvOS can purge the on-disk cache.

## Recommended build pipeline

1. **Toolchain:** stable Rust ≥ 1.95 (pinned in `rust-toolchain.toml`). Run `rustup target add aarch64-apple-tvos aarch64-apple-tvos-sim` [R1][R3]. Build on Apple Silicon only and skip `x86_64-apple-tvos`, which is Tier 3 [R2].
2. **Crate:** `core` exposes a `crate-type = ["staticlib", "lib"]` FFI crate (Swift) and later `cdylib` (Android/JNA) [U6][M1]. Use UniFFI proc-macros (`#[uniffi::export]`) with no UDL.
3. **Compile:** `cargo build --release --target aarch64-apple-tvos` and `--target aarch64-apple-tvos-sim`, with `TVOS_DEPLOYMENT_TARGET` set to the app's minimum, because rustc reads that variable [R1].
4. **Bindings:** run `uniffi-bindgen-swift --swift-sources --headers --modulemap --xcframework` against the built library [U3]. It generates the `.swift` file, the C header and an XCFramework-compatible modulemap.
5. **Package:** `xcodebuild -create-xcframework -library <device .a> -headers <gen> -library <sim .a> -headers <gen>`, with one static library per platform/destination. Do not `lipo` device and simulator slices together [A1]. Wrap the XCFramework plus the generated Swift file in a local Swift package (`.binaryTarget(path:)`) that the tvOS app imports. This is the pattern liveview-native-core uses, tvOS slice included [P1].
6. **Script it:** a single `scripts/build-apple.sh` (macOS only) runs steps 3–5, and the macOS CI job calls it. We recommend a hand-written script over `cargo-swift` (see below).
7. **Release profile for size:** `lto = true`, `codegen-units = 1`, `strip = true`, `opt-level = "s"` or `3`, chosen by measurement [C1]. Measure the app's binary-size delta and launch time in the PR, as AGENTS.md requires.

### Why not cargo-swift (yet)

`cargo swift package` does produce a Swift package and knows the tvOS targets [T1][T2]. Two problems remain:

- It builds the tvOS simulator as a universal `aarch64-apple-tvos-sim` + `x86_64-apple-tvos` binary [T2]. It also switches every build to `cargo +nightly` (with `-Z build-std` for targets missing from rustup) when any requested target needs it [T3], and `x86_64-apple-tvos` is Tier 3 [R2]. Unconfirmed: whether cargo-swift can be told to drop the x86_64 simulator slice.
- It is pinned per UniFFI minor version and does not detect the project's UniFFI version. Its README tops out at UniFFI 0.31.1 ↔ cargo-swift 0.11.1 [T1], while UniFFI is at 0.32.2 [U1].

The steps it automates are three commands, so a short script avoids both problems.

## Blockers and risks

No hard blockers. Risks, roughly by importance:

| # | Risk | Mitigation |
|---|------|-----------|
| 1 | tvOS targets became Tier 2 only in Rust 1.95 [R3]. The target page says they are "not yet well-tested, and it is possible that there are various bugs" [R1]. | Pin the toolchain and run the core's tests on the tvOS simulator in macOS CI. |
| 2 | **TLS crypto backend on tvOS devices.** `aws-lc-rs` (reqwest 0.13's default rustls provider [Q1]) lists `aarch64-apple-tvos-sim` as built and tested, but its table predates Tier 2 ("requires nightly"). It does not list `aarch64-apple-tvos` device at all [Q3]. *ring* supports tvOS from 0.17.8 (or slightly earlier) per its maintainer [Q4]. | Spike: build `reqwest` with rustls for the device target. If aws-lc-rs fails, use `rustls-no-provider` + *ring* [Q1]. |
| 3 | UniFFI has **no native stream / AsyncSequence type** [U7] and **no built-in future cancellation** [U2]. | Use a listener trait implemented in Swift and returned as a handle. Cancel through an explicit `cancel()`/drop-handle method, as matrix-sdk-ffi does with `TaskHandle` [M2]. Wrap it in a Swift `AsyncStream` on the Swift side. |
| 4 | Swift 6 strict concurrency: generated async code is not yet `Sendable` [U4] (tracked in uniffi-rs#2448, still open [U8]). | Use the Swift 5 language mode for the bindings module, or accept warnings, until #2448 lands. |
| 5 | **tvOS storage is purgeable.** Only 500 KB of persistent local storage is available (NSUserDefaults). Everything else must live in the cache directory, which the OS may delete when space is low and the app is not running [A2]. | Put the SQLite cache in the Caches directory. `core` must treat a missing or empty DB as a cold start, never as corruption. Keep the auth token in the Keychain via a Swift-implemented trait. |
| 6 | Newer UniFFI versions break the checksum/ABI between minors [U1]. | Pin `uniffi` and `uniffi-bindgen-swift` to the same version in one workspace. |

## Details

### Rust targets

- `aarch64-apple-tvos` and `aarch64-apple-tvos-sim` are "Tier 2 (without Host Tools)" and are "distributed through `rustup`". `x86_64-apple-tvos` (Intel simulator) is Tier 3 [R1]. The platform-support table marks all three ✓ for std [R2]. `arm64e-apple-tvos` is also Tier 3 [R2].
- Promoted by rust-lang/rust#152021 ("Bump tvOS, visionOS and watchOS Aarch64 targets to tier 2", merged 2026-02-12, milestone 1.95.0) [R4]. Listed in the Rust 1.95.0 release notes (2026-04-16) [R3]. Proposed in compiler-team MCP #918 [R5].
- Before that, tvOS needed `cargo +nightly -Z build-std`. liveview-native-core's build still does this for its tvOS targets [P1], and much older blog-style guidance assumes it.
- Requirements: the AppleTVOS / AppleTVSimulator SDK from Xcode (12+ for ARM64), passed via `SDKROOT` or inferred on macOS. The minimum is tvOS 10.0, and it can be raised via `TVOS_DEPLOYMENT_TARGET` [R1].
- std caveat: `std::process::Command` only works when it maps to `posix_spawn`, and spawning processes would likely get the app rejected anyway [R1]. This is irrelevant for us.
- Simulator vs device code can be split with `cfg(all(target_vendor = "apple", target_env = "sim"))` (Rust ≥ 1.91) [R6].
- `cc` (used by C-backed `-sys` crates) knows the `appletvos` SDK [Q6].

### UniFFI Swift support (UniFFI 0.32.2, 2026-09-22 [U1])

- **Async:** Rust `async fn` becomes Swift `async`/`await`. The foreign side drives the future and no Rust event loop is required [U2]. `#[uniffi::export(async_runtime = "tokio")]` wraps futures for tokio-dependent code such as reqwest, and since 0.32.0 it also applies to trait exports [U1].
- **Callbacks / foreign traits:** traits exported with `#[uniffi::export(foreign)]` or `#[uniffi::export(rust, foreign)]` (0.32.0 syntax, replacing `with_foreign`) can be implemented in Swift [U1][U5]. Trait methods can be async for both Rust and foreign implementations (changelog: "Trait interfaces can now have async functions, both Rust and foreign-implemented") [U1]. Swift protocols are generated as `Sendable`, so Swift implementations must be `Sendable` too [U4][U1].
- **Streams of events:** no first-class support. The maintainer's answer to "How to provide Stream and Sink implementations from foreign code?" is that hand-written plumbing over async trait methods is "about as good as you can get right now" [U7]. Real-world pattern: Rust calls a Swift-implemented listener trait, and the subscription returns a `TaskHandle` object whose drop or `cancel()` stops the task [M2].
- **Packaging:** `uniffi-bindgen-swift` generates Swift sources, headers and modulemaps, including "XCFramework-compatible modulemaps" [U3]. UniFFI's own Xcode page treats building the staticlib as out of scope and does not cover XCFrameworks or tvOS [U6].
- **Init overhead:** the Swift config `omit_checksums` skips library checksum checks at initialization, which "might speed up initialization" at the cost of safety [U9]. Unconfirmed: any measured cost of those checks.

### SQLite (rusqlite `bundled`)

- `bundled` compiles an up-to-date SQLite into the binary instead of linking the system one [Q5]. Build-wise, `libsqlite3-sys` treats Apple targets generically, with no tvOS-specific code path [Q5]. Its C build goes through `cc`, which supports the tvOS SDK [Q6].
- Unconfirmed: an explicit rusqlite statement or CI job for tvOS. Indirect evidence: matrix-sdk-ffi defaults to `bundled-sqlite` and ships on iOS via UniFFI [M1][P2]. Same Apple toolchain, different OS.
- The DB file location must follow the tvOS storage rules in risk #5 [A2].

### HTTP / TLS: reqwest + rustls vs URLSession

- reqwest 0.13 defaults to rustls with the aws-lc-rs provider, and uses `rustls-platform-verifier` for roots [Q1]. On Apple targets, the verifier uses `Security.framework` (selected by `cfg(target_vendor = "apple")`, which includes tvOS) [Q2]. Its README lists only macOS and iOS by name, so tvOS is unconfirmed as a tested platform.
- Crypto provider on tvOS device: see risk #2 [Q3][Q4].
- Apple's position on BSD sockets (which reqwest/hyper use): acceptable "when writing cross-platform code". Without connect-by-name you must implement Happy Eyeballs yourself, it is "incompatible with VPN On Demand", and you must bring your own TLS [A3]. Unconfirmed: whether hyper's connector implements Happy Eyeballs to Apple's satisfaction.
- **Local network privacy does not apply to tvOS** (Apple's platform table: tvOS "no"). A Rust socket stack talking to a LAN Jellyfin server will not trigger a permission prompt on Apple TV, though it will on iOS 14+ [A4].
- The watchOS reqwest failure (getaddrinfo returning nothing on device) comes from watchOS's low-level networking restrictions [Q7]. Unconfirmed from a primary Apple source that the restriction is watchOS-only: TN3135 is titled for watchOS, but its body was not retrievable. No equivalent tvOS report was found.
- Unconfirmed: whether App Transport Security applies to traffic that does not go through URLSession. This matters for plain-HTTP LAN servers either way.
- **Recommendation:** keep HTTP behind an `HttpTransport` trait in `core`. Default to reqwest + rustls so Android TV gets the identical stack. The trait stays exportable as a UniFFI foreign trait, so a URLSession implementation could be swapped in on Apple if the spike in risk #2 fails or VPN-on-demand matters. Media bytes do not go through Rust: AVPlayer loads the stream URL itself.

### Binary size and launch time

- No primary-source measurement exists for a UniFFI+tvOS app. Treat all numbers as **unconfirmed** until we measure.
- Reference point only: the matrix-rust-components-swift release `MatrixSDKFFI.xcframework.zip` (26.10.27) is ~132 MB [P2]. That is a multi-platform, multi-slice archive of a much larger SDK, not shipped app size.
- Levers: Cargo release profile (`lto`, `codegen-units`, `strip`, `opt-level`) [C1], and static linking so the app linker can dead-strip unused code (standard behaviour, unconfirmed for our build). Create the tokio runtime lazily off the main thread.

### What the same core needs for Kotlin / Android TV later

- Android targets (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`) are Tier 2 with std [R2].
- UniFFI Kotlin needs JNA ≥ 5.12.0, loads a `cdylib` via `System.loadLibrary`, and needs `kotlinx-coroutines-core` ≥ 1.6 for async [U10]. Recommended: attach Rust worker threads to the JVM permanently to avoid per-call attach cost [U10]. An experimental JNI-based Kotlin bindgen is in UniFFI's unreleased changes [U1].
- `rustls-platform-verifier` on Android needs a small Kotlin/Gradle component and JNI init [Q2]. Budget for it in the Android shell.
- Keep the crate's `crate-type` including `cdylib` [M1], and keep platform-specific code (Keychain, storage paths) behind foreign traits so `core` stays OS-free.

### Real projects

- **Firefox for iOS** consumes mozilla/application-services, whose components use UniFFI to generate Swift bindings [P3].
- **Element X iOS** uses the Matrix Rust SDK through an FFI layer exposed as a Swift package [P4]. matrix-sdk-ffi is UniFFI-based and defaults to bundled SQLite + rustls/aws-lc-rs [M1], so it is the closest analogue to our stack on iOS.
- **liveview-native-core** builds a UniFFI XCFramework with an `aarch64-apple-tvos` slice and an `aarch64-apple-tvos-sim` + `x86_64-apple-tvos` simulator slice. Its Package.swift declares `.tvOS("16.0")` [P1]. It is a library, not a shipped app.
- Unconfirmed: any App Store tvOS app publicly documented as shipping a Rust+UniFFI core. None was found.

## Sources

- [R1] Rust: apple-tvos target page. https://doc.rust-lang.org/rustc/platform-support/apple-tvos.html
- [R2] Rust: platform support tables. https://doc.rust-lang.org/rustc/platform-support.html
- [R3] Rust RELEASES.md, 1.95.0 "Promote `aarch64-apple-tvos` to Tier 2". https://github.com/rust-lang/rust/blob/master/RELEASES.md
- [R4] rust-lang/rust#152021. https://github.com/rust-lang/rust/pull/152021
- [R5] rust-lang/compiler-team#918. https://github.com/rust-lang/compiler-team/issues/918
- [R6] Rust: apple-ios target page (build/testing, `target_env = "sim"`). https://doc.rust-lang.org/rustc/platform-support/apple-ios.html
- [U1] UniFFI CHANGELOG. https://github.com/mozilla/uniffi-rs/blob/main/CHANGELOG.md
- [U2] UniFFI manual: async/futures. https://mozilla.github.io/uniffi-rs/latest/futures.html
- [U3] UniFFI manual: uniffi-bindgen-swift. https://mozilla.github.io/uniffi-rs/latest/swift/uniffi-bindgen-swift.html
- [U4] UniFFI manual: Swift overview (Swift 6 / Sendable). https://mozilla.github.io/uniffi-rs/latest/swift/overview.html
- [U5] UniFFI manual: foreign traits. https://mozilla.github.io/uniffi-rs/latest/foreign_traits.html
- [U6] UniFFI manual: integrating with Xcode. https://mozilla.github.io/uniffi-rs/latest/swift/xcode.html
- [U7] uniffi-rs#2755 (Stream/Sink from foreign code). https://github.com/mozilla/uniffi-rs/issues/2755
- [U8] uniffi-rs#2448 (Swift 6 issues). https://github.com/mozilla/uniffi-rs/issues/2448
- [U9] UniFFI manual: Swift configuration (`omit_checksums`). https://mozilla.github.io/uniffi-rs/latest/swift/configuration.html
- [U10] UniFFI manual: Kotlin/Gradle integration. https://mozilla.github.io/uniffi-rs/latest/kotlin/gradle.html
- [T1] cargo-swift README. https://github.com/antoniusnaumann/cargo-swift
- [T2] cargo-swift `src/targets.rs` (tvOS targets, universal simulator). https://github.com/antoniusnaumann/cargo-swift/blob/main/src/targets.rs
- [T3] Same file, nightly / `-Z build-std` selection. https://github.com/antoniusnaumann/cargo-swift/blob/main/src/targets.rs
- [Q1] reqwest CHANGELOG (v0.13.0 TLS defaults). https://github.com/seanmonstar/reqwest/blob/master/CHANGELOG.md
- [Q2] rustls-platform-verifier README and Cargo.toml. https://github.com/rustls/rustls-platform-verifier
- [Q3] aws-lc-rs platform support. https://aws.github.io/aws-lc-rs/platform_support.html
- [Q4] briansmith/ring#2227 ("ring 0.17.8 (maybe slightly earlier) does [support tvOS]"). https://github.com/briansmith/ring/issues/2227
- [Q5] rusqlite README and `libsqlite3-sys/build.rs`. https://github.com/rusqlite/rusqlite
- [Q6] cc-rs `src/target/apple.rs`. https://github.com/rust-lang/cc-rs/blob/main/src/target/apple.rs
- [Q7] seanmonstar/reqwest#2831 (watchOS DNS failure). https://github.com/seanmonstar/reqwest/issues/2831
- [C1] Cargo profiles. https://doc.rust-lang.org/cargo/reference/profiles.html
- [A1] Apple: Creating a multiplatform binary framework bundle. https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
- [A2] Apple: App Programming Guide for tvOS, "Local Storage for Your App Is Limited". https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/index.html
- [A3] Apple TN3151: Choosing the right networking API. https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api
- [A4] Apple TN3179: Understanding local network privacy. https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- [M1] matrix-sdk-ffi Cargo.toml. https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-ffi/Cargo.toml
- [M2] matrix-sdk-ffi `TaskHandle`. https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-ffi/src/task_handle.rs
- [P1] liveview-native-core `Makefile.toml` and `Package.swift`. https://github.com/liveview-native/liveview-native-core
- [P2] matrix-rust-components-swift releases. https://github.com/matrix-org/matrix-rust-components-swift/releases
- [P3] mozilla/application-services README. https://github.com/mozilla/application-services
- [P4] element-hq/element-x-ios README. https://github.com/element-hq/element-x-ios
