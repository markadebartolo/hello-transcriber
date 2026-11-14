# The sound of hello

This mark is a measured waveform envelope, not an invented equalizer. On November
14, 2026, macOS Samantha (en-US) spoke “hello” locally at 160 words per minute. The
0.519-second active phrase was divided into 25 equal-duration bins; each bar is its
RMS amplitude normalized to the loudest bin. Minimal heights retain quiet portions.
Small icons group bins to remain readable at menu bar sizes.

`waveform.json` records the measurements, trim interval, source audio checksum and
sampling rate. Audio is not shipped; only derived geometry is included. To render
all app icons, the vector template menu mark, SVG and PNG preview from this data:

```sh
swift hello/brand/render.swift "$PWD"
```

The input was produced with `say -v Samantha -r 160 -o hello.aiff hello` and converted
to mono 16-bit PCM at 44.1 kHz before measurement. Voice/system updates may produce a
different utterance, so the checked-in measurements are the canonical logo source.
