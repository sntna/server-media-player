# Troubleshooting

## Playback stutters

- **Network:** check that the connection between the client and the server is fast and stable. Prefer wired Ethernet or a strong 5 GHz Wi-Fi signal, and make sure the available bandwidth exceeds the bitrate of the file.
- **Server transcoding:** check whether the server is transcoding the stream instead of direct playing it. Transcoding can overload a weak server CPU; if it is happening, compare the file's codec and container with what the client supports.
- **Client hardware decoding:** check that the client device decodes the video in hardware. Software decoding of high-bitrate or high-resolution codecs (such as HEVC or AV1) can drop frames on lower-powered devices.
