# README GIFs

Screen recordings embedded near the top of the package `README.md`. Not part
of the published package (see `.pubignore`) — referenced from the README by
absolute `raw.githubusercontent.com` URL so they render on both GitHub and
pub.dev regardless of what ships in the archive.

Record from the [live demo](https://shrey-17bhardwaj.github.io/keyspot/) or
`cd example && flutter run -d chrome`. Keep each clip 4–8s, looping cleanly,
window sized around 900×650 so the recording stays small. Convert with:

```sh
brew install ffmpeg gifski
ffmpeg -i clip.mov -vf "fps=12,scale=720:-1" -f yuv4mpegpipe - \
  | gifski -o clip.gif --fps 12 --quality 80 -
```

Aim for well under 3MB each.

| File | Page | Action |
|---|---|---|
| `scroll_tracking.gif` | `scrolling_list` | "Track it while you scroll" — scroll up/down, cut-out stays glued |
| `pointer_sweep.gif` | `pointer_playground` | Arc toggle on, "Sweep A → C" |
| `tour.gif` | `full_tour` | "Start tour" → Next through 3–4 steps |
| `shapes.gif` | `shapes_gallery` | Trigger 2–3 shapes back to back |

Drop the finished GIFs in this folder with those exact filenames — the README
already references them.
