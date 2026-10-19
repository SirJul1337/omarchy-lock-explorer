#!/usr/bin/env python3
"""Draw the CPU and GPU bell curves for standards.md from a benchmark CSV.

    pip install plotly kaleido
    python3 tests/bench-curves.py [tests/bench-results/full-1080p.csv]

Same log scale as bench-table.py (log10 of percent + 0.1), where the data is
roughly bell shaped. Each enabled design is a dot on the fitted normal curve
(disabled work-in-progress designs are left out). Writes
tests/bench-results/curves.png and curves.html (hoverable).
"""
import csv, math, os, re, statistics as st, sys
import plotly.graph_objects as go
from plotly.subplots import make_subplots

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests/bench-results/full-1080p.csv")
enabled = set(re.findall(r'^\s*\{ id: "([^"]+)", file:', open(os.path.join(root, "Designs.js")).read(), re.M))
rows = [{"id": r["design"], "cpu": float(r["cpu_pct"]), "gpu": float(r["gpu_pct"])}
        for r in csv.DictReader(open(path)) if r["design"] in enabled]
NEW = {"waves", "clockwall", "wordclock", "ringwordclock", "solclock", "mazeclock", "predator", "terminator", "lightspeed"}
panels = [("cpu", "CPU, % of one core", 10, 35, [0.1, 1, 10, 100]),
          ("gpu", "GPU, % of one engine", 6, 10, [0.1, 1, 10])]
BLUE, ORANGE, RED, GREEN = "#4c78a8", "#f58518", "#d04a3a", "#2e9e5b"
f = lambda v: math.log10(v + 0.1)

fig = make_subplots(rows=2, cols=1, vertical_spacing=0.12,
                    subplot_titles=[p[1] for p in panels])
for i, (key, title, target, limit, ticks) in enumerate(panels, 1):
    xs = [f(r[key]) for r in rows]
    m, s = st.mean(xs), st.pstdev(xs)
    pdf = lambda x: math.exp(-0.5 * ((x - m) / s) ** 2) / (s * math.sqrt(2 * math.pi))
    lo, hi = min(xs) - 0.5, max(xs) + 0.5
    grid = [lo + (hi - lo) * k / 300 for k in range(301)]
    fig.add_trace(go.Scatter(x=grid, y=[pdf(x) for x in grid], mode="lines", fill="tozeroy",
                             line=dict(color=BLUE, width=2), fillcolor="rgba(76,120,168,0.12)",
                             hoverinfo="skip", showlegend=False), row=i, col=1)
    for v, c, lab in ((target, GREEN, "target"), (limit, RED, "limit")):
        fig.add_vline(x=f(v), line=dict(color=c, dash="dash", width=1.5), row=i, col=1,
                      annotation_text="%s %d%%" % (lab, v), annotation_font_color=c,
                      annotation_position="top right")
    # stack dots that share a spot so every design stays visible
    seen, pts = {}, []
    for r in sorted(rows, key=lambda r: r[key]):
        x = f(r[key]); k = round(x, 2)
        seen[k] = seen.get(k, 0) + 1
        pts.append((r, x, pdf(x) + (seen[k] - 1) * pdf(m) * 0.035))
    for r, x, y in pts:
        new, over = r["id"] in NEW, r[key] > limit
        fig.add_trace(go.Scatter(
            x=[x], y=[y], mode="markers", showlegend=False, hovertemplate="%s: %.1f%%<extra></extra>" % (r["id"], r[key]),
            marker=dict(size=11 if new else 7, color=ORANGE if new else (RED if over else BLUE),
                        line=dict(color="white", width=1))), row=i, col=1)
        if new or r[key] >= 90 or key == "gpu" and over:
            fig.add_annotation(x=x, y=y, text=r["id"], showarrow=False, xanchor="left", yanchor="bottom",
                               xshift=5, font=dict(size=10), row=i, col=1)
    zeros = sum(1 for r in rows if r[key] == 0)
    fig.add_annotation(x=f(0), y=pdf(f(0)) + (zeros - 1) * pdf(m) * 0.035, text="%d designs at 0%%" % zeros,
                       showarrow=False, xanchor="left", xshift=8, font=dict(size=10, color="#666"), row=i, col=1)
    fig.update_xaxes(tickvals=[f(t) for t in ticks], ticktext=["%g%%" % t for t in ticks], row=i, col=1)
    fig.update_yaxes(visible=False, row=i, col=1)
    fig.layout.annotations[i - 1].update(text="%s (mean %.1f%%, log scale)" % (title, 10 ** m - 0.1), x=0, xanchor="left")

fig.update_layout(width=1100, height=850, template="simple_white", margin=dict(t=60, b=50, l=30, r=30),
                  title=dict(text="orange = new designs, red = over the limit", x=1, xanchor="right",
                             font=dict(size=11, color="#666"), y=0.995))
out = os.path.join(root, "tests/bench-results/curves")
fig.write_image(out + ".png", scale=2)
fig.write_html(out + ".html", include_plotlyjs="cdn")
print(out + ".png")
