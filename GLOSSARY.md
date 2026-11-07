# Server Media Player

A performance-first player app for self-hosted media servers (Jellyfin first) that browses a user's
libraries and plays their video, preferring the original file over a server re-encode.

## Language

### Server and account

**Server**:
A self-hosted media server (Jellyfin in v1) that the player has been pointed at and remembers. A player can hold several.
_Avoid_: Host, backend, instance

**User**:
An account on a server. Several users can share one player, picked from a profile picker.
_Avoid_: Profile, account (alone), member

**Quick Connect**:
Signing a user in by approving a short code from another already-signed-in device instead of typing a password on the TV.
_Avoid_: Pairing, code login

**Library**:
A named collection of media on the server, such as Movies or TV Shows, that the player browses and searches.
_Avoid_: Collection, folder

**Session**:
A single authenticated connection between the player and the server, identifying the signed-in user and device and carrying playback progress reports.
_Avoid_: Login, connection

### Browsing

**Continue Watching**:
Items a user started but did not finish, ordered by when they were last played.
_Avoid_: Resume list, in progress

**Next Up**:
For each series a user is watching, the first episode after the last one they finished.
_Avoid_: Up next, queue

### Playback

**Direct play**:
Streaming a media file to the player exactly as stored on the server, with no re-encoding, so the device decodes the original video and audio itself.
_Avoid_: Native play, passthrough

**Transcode**:
The server converting media into a different container, codec or bitrate (for example HLS) when the device cannot play the original file or the network cannot carry it. It costs server CPU and can lower quality, which is why direct play is preferred.
_Avoid_: Transcoding (as a separate term), conversion

**Remux**:
The server repackaging media into a different container without re-encoding the video or audio. Cheaper than a transcode and lossless.
_Avoid_: Direct stream (Jellyfin's term), repackage

**Player engine**:
The component that actually decodes and renders a stream on a device. A platform may have more than one and picks per item.
_Avoid_: Player (alone), backend, renderer

**Media segment**:
A server-marked span of an item, such as an intro, recap or credits, that the user can skip.
_Avoid_: Chapter, marker

**Trickplay**:
Thumbnail images the server pre-generates across an item so that scrubbing shows where the user will land.
_Avoid_: Scrub preview, BIF

**Match Content**:
The device switching its output frame rate and dynamic range (SDR, HDR10, Dolby Vision) to match the item being played.
_Avoid_: Mode switching, refresh-rate matching
