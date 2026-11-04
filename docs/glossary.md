# Glossary

- **Direct play**: Streaming a media file to the player exactly as stored on the server, with no re-encoding, so the device decodes the original video and audio itself.
- **Transcode**: Converting media on the server into a different container, codec or bitrate (for example HLS) when the device cannot play the original file or the network cannot carry it.
- **Library**: A named collection of media on the server, such as Movies or TV Shows, that the player browses and searches.
- **Session**: A single authenticated connection between the player and the server, identifying the signed-in user and device and carrying playback progress reports.
- **Transcoding**: The server re-encodes the media into a format the client can play. It costs server CPU and can lower quality, which is why direct play is preferred.
