# Lock screen standards

A lock screen runs on every monitor, for as long as the machine sits locked.
It should cost almost nothing. These are the limits a design has to meet, how
they were chosen, and how to build a design that stays under them.

`tests/standards.test.cjs` checks them. Run it with `node --test tests/*.test.cjs`.

## Budgets

Measured with `tests/bench-lock-load.sh` at 1920x1080: CPU as a percent of one
core (100 = a core fully busy), GPU as a percent of one GPU engine. One design
runs alone in a window, after a 3 s warm-up, sampled for 8 s.

| | CPU | GPU | Memory (RSS) |
|---|---|---|---|
| **Target** (aim here) | 10% or less | 6% or less | n/a |
| **Limit** (must not exceed) | 35% | 10% | 320 MB |

A new design must be under the limit before it is enabled in `Designs.js`, and
should be under the target. Designs with no animation should measure near zero.

Memory is about 225 MB for every design (the shell itself), so it only guards
against a leak or a huge image or video.

### Where the limits come from

61 designs measured on 2026-10-18 (full results in
`tests/bench-results/full-1080p.csv`):

```
CPU % of one core                      GPU % of one engine
   0-1   25 █████████████████████████     0-1   27 ███████████████████████████
   1-5    8 ████████                      1-2    6 ██████
  5-10    4 ████                          2-4    7 ███████
 10-20    3 ███                           4-6   11 ███████████
 20-35    6 ██████                        6-8    3 ███
 35-60    9 █████████                     8-10   4 ████
60-100    2 ██                           10-12   2 ██
  100+    4 ████                           12+   1 █
```

It is not a bell curve. CPU splits into two groups: designs that draw nothing
per frame (median 4.3%) and designs that repaint something every frame (30%
and up, four of them over a whole core). Mean 22% and standard deviation 36%
are not much use for that shape, so the limits come from where the groups
separate instead:

- **Target**: 10% CPU and 6% GPU. About 60% of designs already meet it, and
  everything that sits there is built from retained scene-graph items.
- **Limit**: 35% CPU is one standard deviation above the geometric mean on a
  log scale, and 10% GPU is the same for GPU. About 75% of designs are under it.

GPU is mostly a per-pixel cost of keeping the window redrawing (a design with
any running animation lands around 3 to 9%), so the GPU limit only catches
designs that add full-screen blending or blur on top.

## Rules for building a design

These are what separates the cheap designs from the expensive ones in the
measurements. Of the designs over 90% CPU, `proton`, `tracker` and `bullet`
repaint a Canvas from a timer, and `statusline` and `digital` stream frames
from the `ttfx` effect through `TtfxText`.

1. **Do not repaint a full-screen `Canvas` every frame.** A Canvas redraws all
   of its pixels and uploads them each time, and `fillText` with `shadowBlur`
   is the most expensive call of all. Terminator went from 100% to 6% CPU by
   moving off it. A Canvas is fine for something drawn once or on an event
   (scan lines, a ring that fills per key).
2. **Prefer retained scene-graph items that an animation moves.** `Rectangle`,
   `Text`, `Image`, and `NumberAnimation` on `x`, `y`, `opacity`, `rotation`
   or `scale` are drawn by the GPU with almost no CPU. Slide a row of `Text`
   instead of redrawing it.
3. **Gate every animation and timer on `animating`.** `DesignBase` exposes
   `animating` (true only while the screen is awake and visible). Use it for
   `running:` on every `Timer`, `Animation` and `FrameAnimation`, so a locked
   screen with the display off does no work.
4. **Update slowly changing values on a slow timer.** A readout that changes
   six times a second needs a 150 ms `Timer`, not a per-frame binding. Run a
   timer only while it has something to do (for example, only while a line is
   typing out).
5. **Do per-pixel effects in a shader, at half size.** Many moving things (a
   star field, rain, particles) are too many items for QML to update every
   frame and too slow for a Canvas. A `ShaderEffect` draws them on the GPU from
   a couple of numbers. Lightspeed went from 48% to under 4% CPU this way. Write
   the shader in `designs/shaders/<name>.frag`, compile it with
   `qsb --qt6 -o <name>.frag.qsb <name>.frag` (from `qt6-shadertools`) and
   commit both files. Render the effect into a half size layer
   (`layer.enabled`, `layer.textureSize`) so it shades a quarter of the pixels.
   Keep the per-pixel work small: a design that did three star lookups per
   pixel used 23% GPU, two lookups at half size used 7%.
6. **No `shadowBlur` or `MultiEffect` blur over the whole screen** on an
   animated design, and keep any full-screen shader cheap (rule 5). Fake a glow
   with one low-alpha duplicate.
7. **Keep the item count down.** A few dozen `Text` rows is fine. Hundreds of
   animated items, or a particle system with a `Repeater` of every particle, is
   not. Cap counts by the screen size.
8. **Use `Repeater` model sizes that cannot go negative.** Before the window has
   a size, `height` is 0. Clamp with `Math.max(0, ...)`.
9. **Treat `TtfxText` as expensive.** It reads a frame stream from an external
   `ttfx` process and re-parses it into text, which cost over a whole core in
   `statusline` and `digital`. Use it for a short effect that ends, not as a
   permanent animation, and stop it when `animating` is false.
10. **Keep images and videos small.** Memory should stay under the limit above.

## Measuring a design

```
tests/bench-lock-load.sh terminator             # one design
tests/bench-lock-load.sh                         # every enabled design
BENCH_SIZE=2560x1440 BENCH_SECONDS=15 tests/bench-lock-load.sh card
```

To just look at a design, `tests/run-in-window.sh <id>` opens it in one window
(`tests/run-in-window.sh list` prints the ids).

The script opens a window on your live screen for each design, so leave the
machine alone while it runs. It prints a table and writes a CSV (default in
`~/.cache/omarchy-lock-explorer/`). To record a result for the test, run
the full set with `BENCH_OUT=tests/bench-results/full-1080p.csv`.

A disabled design (commented out in `Designs.js`) is not benchmarked; enable it
locally first.

The benchmark runs without a wallpaper by default. A design that tints, blurs
or otherwise processes the wallpaper costs more with one, so measure it with
`BENCH_WALLPAPER=~/Pictures/some.jpg tests/bench-lock-load.sh <id>`. `terminator`
is recorded that way. A wallpaper adds memory (about 60 to 75 MB on a large image), so
it can come close to the memory limit.

## What the test checks

`tests/standards.test.cjs`:

- **Budgets.** Every enabled design in `tests/bench-results/full-1080p.csv` is
  under the limit. A design missing from the CSV fails, so add new designs to
  it. Designs listed in `LEGACY` in the test are over the limit today and are
  allowed to stay there, but may not get worse and must not be added to.
- **Static rules.** A design that repaints a Canvas from a `Timer` or
  `FrameAnimation` must reference `animating` (rule 3), and must not use
  `shadowBlur` (rule 1).

The test cannot run the benchmark itself, since that needs a Wayland session,
so refresh the CSV whenever a design changes.

## All designs, ranked

Rank 0 uses the least resources and rank 61 the most. Rank sorts by CPU % plus
GPU %, then memory, so the 0.0 / 0.0 designs are ordered by memory. The z-scores
say how far a design sits from the average of the 62, in standard deviations,
on a log scale: negative is cheaper than average, +1 is the limit's neighbourhood.
Status is against the limit above. `disabled` designs are not in `Designs.js`.

Regenerate with `python3 tests/bench-table.py` after refreshing the CSV.

| Rank | Design | CPU % | GPU % | MB | CPU z | GPU z | Status |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | classic | 0.0 | 0.0 | 190 | -1.22 | -1.26 | ok |
| 1 | cinema | 0.0 | 0.0 | 195 | -1.22 | -1.26 | ok |
| 2 | weather | 0.0 | 0.0 | 198 | -1.22 | -1.26 | ok |
| 3 | flip | 0.0 | 0.0 | 202 | -1.22 | -1.26 | ok |
| 4 | sheet | 0.0 | 0.0 | 204 | -1.22 | -1.26 | ok |
| 5 | system | 0.0 | 0.0 | 205 | -1.22 | -1.26 | ok |
| 6 | music | 0.0 | 0.0 | 208 | -1.22 | -1.26 | ok |
| 7 | profile | 0.0 | 0.0 | 208 | -1.22 | -1.26 | ok |
| 8 | motion | 0.0 | 0.0 | 211 | -1.22 | -1.26 | ok |
| 9 | editorial | 0.0 | 0.0 | 212 | -1.22 | -1.26 | ok |
| 10 | island | 0.0 | 0.0 | 212 | -1.22 | -1.26 | ok |
| 11 | poster | 0.0 | 0.0 | 212 | -1.22 | -1.26 | ok |
| 12 | split | 0.0 | 0.0 | 212 | -1.22 | -1.26 | ok |
| 13 | card | 0.0 | 0.0 | 217 | -1.22 | -1.26 | ok |
| 14 | neon | 0.0 | 0.0 | 240 | -1.22 | -1.26 | ok |
| 15 | river | 0.0 | 0.0 | 240 | -1.22 | -1.26 | ok |
| 16 | storm | 0.0 | 0.0 | 243 | -1.22 | -1.26 | ok |
| 17 | calendar | 0.1 | 0.0 | 195 | -0.95 | -1.26 | ok |
| 18 | frame | 0.1 | 0.0 | 201 | -0.95 | -1.26 | ok |
| 19 | dock | 0.1 | 0.0 | 202 | -0.95 | -1.26 | ok |
| 20 | eyes | 0.1 | 0.1 | 241 | -0.95 | -0.87 | ok |
| 21 | companion | 0.2 | 0.3 | 193 | -0.79 | -0.48 | ok |
| 22 | dayline | 0.1 | 0.4 | 198 | -0.95 | -0.35 | ok |
| 23 | ring | 0.2 | 0.4 | 216 | -0.79 | -0.35 | ok |
| 24 | analog | 0.6 | 0.2 | 215 | -0.47 | -0.64 | ok |
| 25 | etch | 1.2 | 0.2 | 236 | -0.23 | -0.64 | ok |
| 26 | terminator | 1.2 | 1.8 | 301 | -0.23 | +0.40 | ok |
| 27 | pond | 1.4 | 2.0 | 198 | -0.18 | +0.46 | ok |
| 28 | cipher | 4.3 | 0.8 | 227 | +0.24 | -0.02 | ok |
| 29 | ember | 4.9 | 1.2 | 223 | +0.29 | +0.19 | ok |
| 30 | bounce | 6.3 | 1.1 | 243 | +0.38 | +0.14 | ok |
| 31 | terminal | 3.0 | 5.0 | 233 | +0.10 | +0.96 | ok |
| 32 | zen | 3.4 | 5.1 | 204 | +0.15 | +0.97 | ok |
| 33 | waves | 3.0 | 5.5 | 208 | +0.10 | +1.01 | ok |
| 34 | sparks | 3.7 | 5.0 | 198 | +0.18 | +0.96 | ok |
| 35 | spotlight | 8.9 | 1.3 | 243 | +0.51 | +0.23 | ok |
| 36 | lightspeed | 3.8 | 7.0 | 214 | +0.19 | +1.15 | ok |
| 37 | constellation | 6.6 | 5.0 | 208 | +0.40 | +0.96 | ok |
| 38 | orbit | 10.8 | 2.2 | 242 | +0.59 | +0.51 | ok |
| 39 | core | 12.1 | 1.2 | 237 | +0.63 | +0.19 | ok |
| 40 | aurora | 4.3 | 13.9 | 203 | +0.24 | +1.53 | over limit |
| 41 | horizon | 20.1 | 2.3 | 233 | +0.83 | +0.54 | ok |
| 42 | vhs | 15.4 | 7.3 | 266 | +0.72 | +1.17 | ok |
| 43 | mainframe | 24.4 | 1.9 | 239 | +0.90 | +0.43 | ok |
| 44 | forge | 25.0 | 2.2 | 239 | +0.91 | +0.51 | ok |
| 45 | tracking | 29.6 | 1.8 | 235 | +0.97 | +0.40 | ok |
| 46 | login | 28.1 | 4.0 | 228 | +0.95 | +0.84 | ok |
| 47 | keycode | 32.9 | 4.1 | 227 | +1.01 | +0.85 | ok |
| 48 | beacon | 35.1 | 2.5 | 240 | +1.04 | +0.58 | over limit |
| 49 | panel | 37.6 | 4.7 | 233 | +1.07 | +0.93 | over limit |
| 50 | supernova | 40.6 | 4.1 | 247 | +1.10 | +0.85 | over limit |
| 51 | synthwave | 43.4 | 3.6 | 248 | +1.12 | +0.78 | over limit |
| 52 | binary | 45.5 | 2.7 | 248 | +1.14 | +0.62 | over limit |
| 53 | screensaver | 46.0 | 4.0 | 249 | +1.14 | +0.84 | over limit |
| 54 | rain | 44.7 | 10.1 | 250 | +1.13 | +1.35 | over limit |
| 55 | circuits | 52.0 | 9.5 | 245 | +1.19 | +1.32 | over limit, disabled |
| 56 | fireworks | 64.2 | 8.3 | 237 | +1.27 | +1.24 | over limit |
| 57 | bullet | 92.7 | 10.1 | 234 | +1.41 | +1.35 | over limit, disabled |
| 58 | digital | 118.7 | 6.7 | 250 | +1.51 | +1.12 | over limit |
| 59 | statusline | 128.7 | 5.2 | 258 | +1.54 | +0.98 | over limit |
| 60 | tracker | 129.3 | 7.1 | 243 | +1.54 | +1.16 | over limit, disabled |
| 61 | proton | 162.9 | 5.7 | 244 | +1.63 | +1.03 | over limit, disabled |

## Known offenders

These measured over the limit when the standards were written. They are
legacy and should be brought under it (rules 1 to 3 usually do it).

`statusline`, `digital`, `fireworks`, `binary`, `screensaver`, `synthwave`,
`supernova`, `panel`, `beacon`, `rain` (CPU) and `aurora` (GPU). The disabled work-in-progress designs `proton`, `tracker`,
`bullet` and `circuits` are over too and stay disabled until they are not.
