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
5. **No `shadowBlur`, `MultiEffect` blur or large `ShaderEffect` over the whole
   screen** on an animated design. Fake a glow with one low-alpha duplicate.
6. **Keep the item count down.** A few dozen `Text` rows is fine. Hundreds of
   animated items, or a particle system with a `Repeater` of every particle, is
   not. Cap counts by the screen size.
7. **Use `Repeater` model sizes that cannot go negative.** Before the window has
   a size, `height` is 0. Clamp with `Math.max(0, ...)`.
8. **Treat `TtfxText` as expensive.** It reads a frame stream from an external
   `ttfx` process and re-parses it into text, which cost over a whole core in
   `statusline` and `digital`. Use it for a short effect that ends, not as a
   permanent animation, and stop it when `animating` is false.
9. **Keep images and videos small.** Memory should stay under the limit above.

## Measuring a design

```
tests/bench-lock-load.sh terminator             # one design
tests/bench-lock-load.sh                         # every enabled design
BENCH_SIZE=2560x1440 BENCH_SECONDS=15 tests/bench-lock-load.sh card
```

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

Rank 0 uses the least resources and rank 60 the most. Rank sorts by CPU % plus
GPU %, then memory, so the 0.0 / 0.0 designs are ordered by memory. The z-scores
say how far a design sits from the average of the 61, in standard deviations,
on a log scale: negative is cheaper than average, +1 is the limit's neighbourhood.
Status is against the limit above. `disabled` designs are not in `Designs.js`.

Regenerate with `python3 tests/bench-table.py` after refreshing the CSV.

| Rank | Design | CPU % | GPU % | MB | CPU z | GPU z | Status |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | classic | 0.0 | 0.0 | 190 | -1.21 | -1.24 | ok |
| 1 | cinema | 0.0 | 0.0 | 195 | -1.21 | -1.24 | ok |
| 2 | weather | 0.0 | 0.0 | 198 | -1.21 | -1.24 | ok |
| 3 | flip | 0.0 | 0.0 | 202 | -1.21 | -1.24 | ok |
| 4 | sheet | 0.0 | 0.0 | 204 | -1.21 | -1.24 | ok |
| 5 | system | 0.0 | 0.0 | 205 | -1.21 | -1.24 | ok |
| 6 | music | 0.0 | 0.0 | 208 | -1.21 | -1.24 | ok |
| 7 | profile | 0.0 | 0.0 | 208 | -1.21 | -1.24 | ok |
| 8 | motion | 0.0 | 0.0 | 211 | -1.21 | -1.24 | ok |
| 9 | editorial | 0.0 | 0.0 | 212 | -1.21 | -1.24 | ok |
| 10 | island | 0.0 | 0.0 | 212 | -1.21 | -1.24 | ok |
| 11 | poster | 0.0 | 0.0 | 212 | -1.21 | -1.24 | ok |
| 12 | split | 0.0 | 0.0 | 212 | -1.21 | -1.24 | ok |
| 13 | card | 0.0 | 0.0 | 217 | -1.21 | -1.24 | ok |
| 14 | neon | 0.0 | 0.0 | 240 | -1.21 | -1.24 | ok |
| 15 | river | 0.0 | 0.0 | 240 | -1.21 | -1.24 | ok |
| 16 | storm | 0.0 | 0.0 | 243 | -1.21 | -1.24 | ok |
| 17 | calendar | 0.1 | 0.0 | 195 | -0.95 | -1.24 | ok |
| 18 | frame | 0.1 | 0.0 | 201 | -0.95 | -1.24 | ok |
| 19 | dock | 0.1 | 0.0 | 202 | -0.95 | -1.24 | ok |
| 20 | eyes | 0.1 | 0.1 | 241 | -0.95 | -0.85 | ok |
| 21 | companion | 0.2 | 0.3 | 193 | -0.79 | -0.46 | ok |
| 22 | dayline | 0.1 | 0.4 | 198 | -0.95 | -0.34 | ok |
| 23 | ring | 0.2 | 0.4 | 216 | -0.79 | -0.34 | ok |
| 24 | analog | 0.6 | 0.2 | 215 | -0.47 | -0.62 | ok |
| 25 | etch | 1.2 | 0.2 | 236 | -0.24 | -0.62 | ok |
| 26 | terminator | 1.2 | 1.8 | 301 | -0.24 | +0.42 | ok |
| 27 | pond | 1.4 | 2.0 | 198 | -0.19 | +0.47 | ok |
| 28 | cipher | 4.3 | 0.8 | 227 | +0.22 | -0.01 | ok |
| 29 | ember | 4.9 | 1.2 | 223 | +0.27 | +0.20 | ok |
| 30 | bounce | 6.3 | 1.1 | 243 | +0.36 | +0.16 | ok |
| 31 | terminal | 3.0 | 5.0 | 233 | +0.09 | +0.97 | ok |
| 32 | zen | 3.4 | 5.1 | 204 | +0.13 | +0.98 | ok |
| 33 | sparks | 3.7 | 5.0 | 198 | +0.17 | +0.97 | ok |
| 34 | spotlight | 8.9 | 1.3 | 243 | +0.49 | +0.24 | ok |
| 35 | constellation | 6.6 | 5.0 | 208 | +0.38 | +0.97 | ok |
| 36 | orbit | 10.8 | 2.2 | 242 | +0.56 | +0.52 | ok |
| 37 | core | 12.1 | 1.2 | 237 | +0.61 | +0.20 | ok |
| 38 | aurora | 4.3 | 13.9 | 203 | +0.22 | +1.54 | over limit |
| 39 | horizon | 20.1 | 2.3 | 233 | +0.80 | +0.55 | ok |
| 40 | vhs | 15.4 | 7.3 | 266 | +0.70 | +1.18 | ok |
| 41 | mainframe | 24.4 | 1.9 | 239 | +0.87 | +0.44 | ok |
| 42 | forge | 25.0 | 2.2 | 239 | +0.88 | +0.52 | ok |
| 43 | tracking | 29.6 | 1.8 | 235 | +0.94 | +0.42 | ok |
| 44 | login | 28.1 | 4.0 | 228 | +0.92 | +0.85 | ok |
| 45 | keycode | 32.9 | 4.1 | 227 | +0.98 | +0.86 | ok |
| 46 | beacon | 35.1 | 2.5 | 240 | +1.01 | +0.59 | over limit |
| 47 | panel | 37.6 | 4.7 | 233 | +1.03 | +0.94 | over limit |
| 48 | supernova | 40.6 | 4.1 | 247 | +1.06 | +0.86 | over limit |
| 49 | synthwave | 43.4 | 3.6 | 248 | +1.09 | +0.79 | over limit |
| 50 | binary | 45.5 | 2.7 | 248 | +1.10 | +0.63 | over limit |
| 51 | screensaver | 46.0 | 4.0 | 249 | +1.11 | +0.85 | over limit |
| 52 | rain | 44.7 | 10.1 | 250 | +1.10 | +1.36 | over limit |
| 53 | lightspeed | 48.0 | 9.4 | 233 | +1.12 | +1.32 | over limit |
| 54 | circuits | 52.0 | 9.5 | 245 | +1.16 | +1.33 | over limit, disabled |
| 55 | fireworks | 64.2 | 8.3 | 237 | +1.23 | +1.25 | over limit |
| 56 | bullet | 92.7 | 10.1 | 234 | +1.37 | +1.36 | over limit, disabled |
| 57 | digital | 118.7 | 6.7 | 250 | +1.47 | +1.13 | over limit |
| 58 | statusline | 128.7 | 5.2 | 258 | +1.50 | +0.99 | over limit |
| 59 | tracker | 129.3 | 7.1 | 243 | +1.50 | +1.17 | over limit, disabled |
| 60 | proton | 162.9 | 5.7 | 244 | +1.59 | +1.05 | over limit, disabled |

## Known offenders

These measured over the limit when the standards were written. They are
legacy and should be brought under it (rules 1 to 3 usually do it).

`statusline`, `digital`, `fireworks`, `binary`, `screensaver`, `synthwave`,
`supernova`, `panel`, `beacon`, `rain` (CPU) and `aurora` (GPU), plus the new
`lightspeed`. The disabled work-in-progress designs `proton`, `tracker`,
`bullet` and `circuits` are over too and stay disabled until they are not.
