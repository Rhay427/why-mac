# Why? video ad

15 seconds at 30 fps, H.264 MP4 with one AAC narration track. Exports:

- `Why-15s-vertical.mp4`: 1080 × 1920 for vertical social placements.
- `Why-15s-landscape.mp4`: 1920 × 1080 for the website and landscape placements.
- `Why-15s.srt`: timed English captions.
- `preview.html`: local video player for both exports.

Uses the existing project icon and catalog artwork, animated titles, a gentle
product zoom, and the built-in macOS Samantha synthetic English voice. No music
or external voice service is included. Product examples are labeled illustrative;
the closing frame says the open-source release is coming soon.

To regenerate, run from the repository root on a Mac with Xcode command-line tools:

```sh
mkdir -p .build/video-ad
say -v Samantha -r 185 -o .build/video-ad/voice-0.aiff 'Mac feeling slow?'
say -v Samantha -r 185 -o .build/video-ad/voice-1.aiff 'Meet Why. One check, a plain English answer.'
say -v Samantha -r 185 -o .build/video-ad/voice-2.aiff "Find what's keeping your processor busy."
say -v Samantha -r 185 -o .build/video-ad/voice-3.aiff 'Your Mac, explained. Open source release coming soon.'
swiftc -swift-version 5 -module-cache-path .build/video-ad/module-cache Marketing/Video/render.swift -o .build/video-ad/render
.build/video-ad/render
```

The renderer replaces only its named MP4 outputs when rerun. It validates that
each voice clip fits its scene and extracts four frames per format into
`.build/video-ad/` for inspection. Rendering uses macOS media and speech services;
restricted environments may need access to those local services.
