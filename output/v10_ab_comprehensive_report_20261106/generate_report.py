"""
Generate the comprehensive Vietnamese A4 PDF report for V10A and V10B covering:
1. Differences between V10A and V10B
2. What V10A and V10B inherit from the Drones paper (and what is adapted/extended)
3. EE results across L and q levels for JointPSO, Full PSO, IPSO, and Baseline
4. UAV trajectories and BS coordinates across seeds at L = 3 Mbit/user
5. Detailed listing of BS coordinates and waypoint clusters at L = 3 Mbit/user
   to explain and quantify the "1m corridor" phenomenon.
"""
from pathlib import Path
import json
import math
import os
import statistics as st
import numpy as np

os.environ.setdefault("MPLCONFIGDIR", "/tmp/mpl_cache_v10report")
Path(os.environ["MPLCONFIGDIR"]).mkdir(parents=True, exist_ok=True)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from PIL import Image as PILImage

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Table, TableStyle, Image, Spacer,
    PageBreak, KeepTogether, HRFlowable
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FIG_DIR = HERE / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)
OUT_PDF = ROOT / "output/pdf/Bao_cao_V10A_V10B_EE_Quy_dao_BS_1mCorridor.pdf"
OUT_PDF.parent.mkdir(parents=True, exist_ok=True)

DATA_PATH = ROOT / "output/v10_ab_results_report_20261105/data/extracted_results.json"
raw_rows = json.loads(DATA_PATH.read_text())

unique_map = {}
for r in raw_rows:
    key = (r["variant"], r["seed"], r["L"], r["slot"], r["hover"], r["algorithm"])
    unique_map.setdefault(key, r)
rows = list(unique_map.values())
assert len(raw_rows) == 216 and len(rows) == 168

SEEDS = [2026, 608060, 3486784401]
ALGOS = ["Baseline", "Joint PSO", "Full PSO", "Full IPSO"]
OPT_ALGOS = ["Joint PSO", "Full PSO", "Full IPSO"]

def pick(v=None, a=None, L=None, q=None, h=None, seed=None):
    params = dict(variant=v, algorithm=a, L=L, slot=q, hover=h, seed=seed)
    return [r for r in rows if all(val is None or r[k] == val for k, val in params.items())]

def fmt(n, d=1):
    if n is None or (isinstance(n, float) and math.isnan(n)):
        return "—"
    return f"{n:,.{d}f}".replace(",", " ").replace(".", ",")

# ---------------------------------------------------------------------------
# 1. GENERATE FIGURES
# ---------------------------------------------------------------------------
plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.labelcolor": "#1E2D38",
    "text.color": "#1E2D38",
    "pdf.fonttype": 42,
    "savefig.facecolor": "white",
})

ALGO_COLORS = {
    "Joint PSO": "#7B4F9D",
    "Full PSO": "#0072B2",
    "Full IPSO": "#D55E00",
}

def make_ee_sweep_figure():
    """Combined 2x2 figure: top row = EE vs L (A & B), bottom row = EE vs q (A & B)."""
    fig, axes = plt.subplots(2, 2, figsize=(11.2, 5.7), sharey="row", layout="constrained")
    sweeps = [
        ("L", [1e6, 2e6, 3e6], {"q": 5000, "h": 1}, "Mức yêu cầu dữ liệu L (Mbit/user)", [1, 2, 3]),
        ("q", [0, 5000, 10000], {"L": 3e6, "h": 1}, "Ngưỡng QoS từng slot q (kbit/user/slot)", [0, 5, 10]),
    ]
    for row_idx, (sw_name, vals, fixed, xlabel, xticks) in enumerate(sweeps):
        ymax = 11.8
        for col_idx, v in enumerate(["A", "B"]):
            ax = axes[row_idx, col_idx]
            for ia, a in enumerate(OPT_ALGOS):
                ys = []
                for ix, val in enumerate(vals):
                    p = dict(fixed)
                    p["L" if sw_name == "L" else "q"] = val
                    rr = pick(v, a, **p)
                    good = [r["ee"] / 1000.0 for r in rr if r["feasible"]]
                    mean_v = st.mean(good) if good else np.nan
                    ys.append(mean_v)
                    for r in rr:
                        if r["feasible"]:
                            ax.scatter(ix + (ia - 1) * 0.07, r["ee"] / 1000.0,
                                       s=22, color=ALGO_COLORS[a], alpha=0.45, zorder=3)
                    if good:
                        offset_y = 6 if ia != 1 else -13
                        ax.annotate(f"{len(good)}/3", (ix, mean_v),
                                    xytext=(0, offset_y), textcoords="offset points",
                                    ha="center", fontsize=8, color=ALGO_COLORS[a], fontweight="bold")
                label = a.replace("Full IPSO", "IPSO").replace("Joint PSO", "JointPSO")
                ax.plot(range(3), ys, marker=["s", "o", "D"][ia], color=ALGO_COLORS[a],
                        lw=2.0, ms=5.5, label=label, zorder=4)
            ax.set_title(f"V10{v} — Sweep theo {sw_name} (giữ {'q=5 kbit, h=1 s' if sw_name=='L' else 'L=3 Mbit, h=1 s'})",
                         fontsize=10.5, fontweight="bold")
            ax.set_xticks(range(3), [str(x) for x in xticks])
            ax.set_xlabel(xlabel, fontsize=9.2)
            ax.set_ylim(0, ymax)
            ax.grid(axis="y", alpha=0.22, linestyle="--")
            if col_idx == 0:
                ax.set_ylabel("EE khả thi (kbit/J)", fontsize=9.2)
            if row_idx == 0 and col_idx == 0:
                ax.legend(loc="upper left", frameon=True, facecolor="#F8FAFC", edgecolor="#CBD5E1")
    fig.savefig(FIG_DIR / "ee_L_q_combined.png", dpi=240, bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)

def make_trajectory_comparison_figures():
    """For each seed at L=3 Mbit, q=5 kbit, h=1s: plot 2x3 grid (Row 1: V10A, Row 2: V10B; Cols: JointPSO, Full PSO, IPSO)."""
    for seed in SEEDS:
        fig, axes = plt.subplots(2, 3, figsize=(11.8, 6.55), sharex=True, sharey=True, layout="constrained")
        for r_idx, v in enumerate(["A", "B"]):
            for c_idx, a in enumerate(OPT_ALGOS):
                ax = axes[r_idx, c_idx]
                r = pick(v, a, L=3e6, q=5000, h=1, seed=seed)[0]
                # BS search boxes
                for j in range(3):
                    ax.add_patch(Rectangle(
                        (r["xBS_min"][j], r["yBS_min"][j]),
                        r["xBS_max"][j] - r["xBS_min"][j],
                        r["yBS_max"][j] - r["yBS_min"][j],
                        facecolor="#E2EEF6", edgecolor="#8FAAC0", lw=0.8, zorder=0
                    ))
                # UAV corridor X in [75, 225]
                ax.axvspan(75, 225, color="#E9F5EE", alpha=0.55, zorder=-1)
                ax.axvline(75, color="#86B89B", ls="--", lw=0.7, zorder=0)
                ax.axvline(225, color="#86B89B", ls="--", lw=0.7, zorder=0)
                # Baseline straight trajectory
                ax.plot([150, 150], [300, 0], color="#94A3B8", ls=":", lw=1.0, zorder=1)
                # UAV trajectory
                x_t = np.array(r["xTraj"])
                y_t = np.array(r["yTraj"])
                ls = "-" if r["feasible"] else "--"
                ax.plot(x_t, y_t, color=ALGO_COLORS[a], marker="o", ms=3.4, lw=1.6, ls=ls, zorder=4)

                # Highlight true 1m corridor crawl segments in V10B (both ΔY <= 1.05m and 2D length <= 2.0m)
                dy = -np.diff(y_t)
                ds = np.hypot(np.diff(x_t), np.diff(y_t))
                if v == "B":
                    for seg_i in range(len(dy)):
                        if dy[seg_i] <= 1.05 and ds[seg_i] <= 2.0:
                            ax.plot(x_t[seg_i:seg_i+2], y_t[seg_i:seg_i+2],
                                    color="#E11D48", lw=3.4, zorder=5)

                # Ground users
                ax.scatter(r["xUser"], r["yUser"], marker="*", s=100, c="#DC2626",
                           edgecolors="white", linewidths=0.5, zorder=6)
                for j, (ux, uy) in enumerate(zip(r["xUser"], r["yUser"])):
                    dx_off, dy_off, align = 4, 4, "left"
                    if seed == 3486784401 and j == 0:
                        dx_off, dy_off, align = -5, 4, "right"
                    if seed == 608060 and j == 3:
                        dx_off, dy_off, align = -5, 4, "right"
                    ax.annotate(f"U{j+1}", (ux, uy), xytext=(dx_off, dy_off),
                                textcoords="offset points", fontsize=7.8, color="#991B1B", fontweight="bold")

                # Base stations with clean non-overlapping label offset
                ax.scatter(r["xBS"], r["yBS"], marker="^", s=85, c="#1E3A5F",
                           edgecolors="white", linewidths=0.6, zorder=7)
                for j, (bx, by) in enumerate(zip(r["xBS"], r["yBS"])):
                    y_off = -19 if j != 0 else -19
                    ax.annotate(f"BS{j+1}({bx:.0f},{by:.0f})", (bx, by),
                                xytext=(0, -14), textcoords="offset points",
                                fontsize=7.0, ha="center", va="top", color="#0F172A", fontweight="bold",
                                bbox=dict(boxstyle="round,pad=0.12", facecolor="white", alpha=0.78, edgecolor="none"))

                # Start and End
                ax.scatter([150], [300], marker="s", s=36, c="#0D9488", zorder=8)
                ax.scatter([150], [0], marker="X", s=45, c="#111827", zorder=8)
                ax.annotate("S", (150, 300), xytext=(5, 1), textcoords="offset points", fontsize=7.8, fontweight="bold")
                ax.annotate("E", (150, 0), xytext=(5, 1), textcoords="offset points", fontsize=7.8, fontweight="bold")

                n_1m = int(np.sum(dy <= 1.05))
                status = "ĐẠT QoS" if r["feasible"] else "VI PHẠM QoS"
                short_a = a.replace("Full IPSO", "IPSO").replace("Joint PSO", "JointPSO")
                extra = f" | ΔY≈1m: {n_1m}/20" if v == "B" else " | ΔY=15m cố định"
                ax.set_title(
                    f"V10{v} · {short_a} ({status})\nEE = {r['ee']:,.1f} bit/J | D = {r['distance']:.1f} m{extra}",
                    fontsize=8.9, fontweight="bold",
                    color="#1E2D38" if r["feasible"] else "#B91C1C"
                )
                ax.set_aspect("equal")
                ax.set_xlim(-22, 324)
                ax.set_ylim(-26, 320)
                ax.set_xticks([0, 75, 150, 225, 300])
                ax.set_yticks([0, 75, 150, 225, 300])
                ax.tick_params(labelsize=7.8)
                ax.grid(alpha=0.18)
                if r_idx == 1:
                    ax.set_xlabel("Tọa độ X (m)", fontsize=8.5)
                if c_idx == 0:
                    ax.set_ylabel(f"V10{v} — Tọa độ Y (m)", fontsize=8.8, fontweight="bold")
        fig.savefig(FIG_DIR / f"traj_grid_seed_{seed}.png", dpi=230, bbox_inches="tight", pad_inches=0.04)
        plt.close(fig)

def make_1m_corridor_diagnostic_figure():
    """
    Dedicated figure showing the 1m corridor phenomenon across all 3 seeds at L=3 Mbit, q=5 kbit, h=1s.
    """
    fig, axes = plt.subplots(2, 3, figsize=(11.8, 5.9), sharex="col", layout="constrained")
    for idx, seed in enumerate(SEEDS):
        ax_top = axes[0, idx]
        ax_bot = axes[1, idx]
        r_a = pick("A", "Full IPSO", L=3e6, q=5000, h=1, seed=seed)[0]
        r_bpso = pick("B", "Full PSO", L=3e6, q=5000, h=1, seed=seed)[0]
        r_bipso = pick("B", "Full IPSO", L=3e6, q=5000, h=1, seed=seed)[0]

        wps = np.arange(1, 22)
        segs = np.arange(1, 21)

        # Plot BS Y-positions of IPSO up to x=21 so labels on the right are completely clear
        bs_colors = ["#0F766E", "#B45309", "#4338CA"]
        for j in range(3):
            y_bs = r_bipso["yBS"][j]
            x_bs = r_bipso["xBS"][j]
            ax_top.plot([1, 21], [y_bs, y_bs], color=bs_colors[j], ls="--", lw=1.1, alpha=0.85)
            ax_top.text(21.3, y_bs, f"BS{j+1}: Y={y_bs:.1f}m\n(X={x_bs:.0f}m)",
                        fontsize=7.2, va="center", color=bs_colors[j], fontweight="bold")

        ax_top.plot(wps, r_a["yTraj"], ls=":", color="#64748B", lw=1.6, label="V10A (chia đều 15m)")
        ax_top.plot(wps, r_bpso["yTraj"], marker="o", ms=3.5, color="#0072B2", lw=1.6, label="V10B Full PSO")
        ax_top.plot(wps, r_bipso["yTraj"], marker="D", ms=3.6, color="#D55E00", lw=1.8, label="V10B Full IPSO")

        ax_top.set_title(f"Seed {seed} (L=3 Mbit, q=5 kbit, h=1 s)", fontsize=10.2, fontweight="bold")
        ax_top.set_ylim(-10, 315)
        ax_top.set_xlim(0.5, 26.2)
        ax_top.grid(alpha=0.2)
        if idx == 0:
            ax_top.set_ylabel("Tung độ Waypoint Y_n (m)", fontsize=9.0)
            ax_top.legend(loc="lower left", fontsize=7.5, frameon=True, facecolor="white")

        # Bottom: ΔY_n per segment
        dy_bpso = -np.diff(r_bpso["yTraj"])
        dy_bipso = -np.diff(r_bipso["yTraj"])
        ax_bot.axhline(15.0, color="#64748B", ls=":", lw=1.2, label="V10A (ΔY = 15 m)")
        ax_bot.axhline(1.0, color="#E11D48", ls="-", lw=1.0, alpha=0.75, label="Cận dưới minYProgress = 1 m")
        ax_bot.bar(segs - 0.18, dy_bpso, width=0.35, color="#0072B2", alpha=0.82, label="V10B Full PSO")
        ax_bot.bar(segs + 0.18, dy_bipso, width=0.35, color="#D55E00", alpha=0.88, label="V10B Full IPSO")

        n1_pso = int(np.sum(dy_bpso <= 1.05))
        n1_ipso = int(np.sum(dy_bipso <= 1.05))
        box_x = 0.46 if idx == 2 else (0.14 if idx == 0 else 0.16)
        ax_bot.text(box_x, 0.93,
                    f"Số đoạn bò ΔY ≈ 1 m:\n• Full PSO: {n1_pso}/20 đoạn\n• Full IPSO: {n1_ipso}/20 đoạn",
                    transform=ax_bot.transAxes, fontsize=7.6, va="top",
                    bbox=dict(boxstyle="round,pad=0.28", facecolor="#FFF1F2", edgecolor="#FECDD3", alpha=0.95))
        ax_bot.set_xlabel("Chỉ số đoạn bay n (waypoint n → n+1)", fontsize=8.8)
        ax_bot.set_xticks([1, 5, 10, 15, 20])
        ax_bot.set_ylim(0, 185)
        ax_bot.grid(axis="y", alpha=0.2)
        if idx == 0:
            ax_bot.set_ylabel("Bước tiến ΔY_n = Y_n - Y_{n+1} (m)", fontsize=9.0)
        if idx == 2:
            ax_bot.legend(loc="lower left", bbox_to_anchor=(0.44, 0.18), fontsize=7.0, frameon=True, facecolor="white")

    fig.savefig(FIG_DIR / "corridor_1m_analysis.png", dpi=240, bbox_inches="tight", pad_inches=0.05)
    plt.close(fig)

def make_bs_distribution_figure():
    """Plot BS1, BS2, BS3 positions across all 60 L=3 Mbit Full PSO/IPSO runs."""
    opts = [r for r in rows if r["L"] == 3e6 and r["algorithm"] in ("Full PSO", "Full IPSO")]
    fig, axes = plt.subplots(1, 3, figsize=(11.4, 3.2), layout="constrained")
    bounds_list = [(250, 300, 250, 300), (0, 50, 100, 200), (250, 300, 0, 50)]
    init_list = [(300, 300, 20), (0, 150, 30), (300, 0, 25)]
    corridor_wall = [225, 75, 225]
    for j, ax in enumerate(axes):
        b = bounds_list[j]
        ax.add_patch(Rectangle((b[0], b[2]), b[1] - b[0], b[3] - b[2],
                               facecolor="#EFF6FF", edgecolor="#64748B", lw=1.1))
        for v, c in [("A", "#0072B2"), ("B", "#D55E00")]:
            for a, m in [("Full PSO", "o"), ("Full IPSO", "X")]:
                rr = [r for r in opts if r["variant"] == v and r["algorithm"] == a]
                ax.scatter([r["xBS"][j] for r in rr], [r["yBS"][j] for r in rr],
                           c=c, marker=m, s=36, alpha=0.68,
                           label=f"V10{v} {a.replace('Full ', '')}", zorder=4)
        ix, iy, iz = init_list[j]
        ax.scatter([ix], [iy], marker="s", s=50, c="#111827", zorder=6, label="BS gốc (Joint)" if j == 0 else None)
        ax.set_xlim(b[0] - 5, b[1] + 5)
        ax.set_ylim(b[2] - 6, b[3] + 6)
        ax.set_xlabel("X (m)", fontsize=8.8)
        ax.set_ylabel("Y (m)", fontsize=8.8)
        inner_x = b[0] if j != 1 else b[1]
        ax.set_title(f"BS{j+1} (Z={iz} m cố định)\nBiên X={inner_x} m (cách X={corridor_wall[j]} m đúng 25 m)",
                     fontsize=9.0, fontweight="bold")
        ax.grid(alpha=0.2)
    axes[0].legend(fontsize=7.5, frameon=True, loc="lower right")
    fig.savefig(FIG_DIR / "bs_distribution_L3.png", dpi=240, bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)

make_ee_sweep_figure()
make_trajectory_comparison_figures()
make_1m_corridor_diagnostic_figure()
make_bs_distribution_figure()

# ---------------------------------------------------------------------------
# 2. BUILD PDF REPORT WITH REPORTLAB
# ---------------------------------------------------------------------------
fontdir = Path("/System/Library/Fonts/Supplemental")
for name, file in [
    ("Body", "Arial.ttf"),
    ("Body-Bold", "Arial Bold.ttf"),
    ("Body-Italic", "Arial Italic.ttf"),
    ("Body-BoldItalic", "Arial Bold Italic.ttf"),
]:
    pdfmetrics.registerFont(TTFont(name, str(fontdir / file)))
pdfmetrics.registerFontFamily(
    "Body", normal="Body", bold="Body-Bold", italic="Body-Italic", boldItalic="Body-BoldItalic"
)

NAVY = colors.HexColor("#14364D")
TEAL = colors.HexColor("#0B6E69")
INK = colors.HexColor("#1E293B")
MUTED = colors.HexColor("#475569")
BORDER_COL = colors.HexColor("#CBD5E1")

PAGE_W, PAGE_H = A4
MARGIN_X = 40
WIDTH = PAGE_W - 2 * MARGIN_X

styles = {
    "title": ParagraphStyle("Title", fontName="Body-Bold", fontSize=18.5, leading=23, textColor=NAVY, spaceAfter=5),
    "subtitle": ParagraphStyle("Subtitle", fontName="Body-Bold", fontSize=10.8, leading=14.8, textColor=TEAL, spaceAfter=7),
    "h1": ParagraphStyle("H1", fontName="Body-Bold", fontSize=13.5, leading=17.5, textColor=NAVY, spaceBefore=4, spaceAfter=5),
    "h2": ParagraphStyle("H2", fontName="Body-Bold", fontSize=10.5, leading=14.0, textColor=TEAL, spaceBefore=5, spaceAfter=3),
    "body": ParagraphStyle("Body", fontName="Body", fontSize=9.2, leading=13.0, textColor=INK, spaceAfter=4, alignment=TA_JUSTIFY),
    "bullet": ParagraphStyle("Bullet", fontName="Body", fontSize=9.0, leading=12.6, textColor=INK, leftIndent=11, spaceAfter=3.5, alignment=TA_JUSTIFY),
    "small": ParagraphStyle("Small", fontName="Body", fontSize=8.4, leading=11.6, textColor=INK, spaceAfter=3.5, alignment=TA_JUSTIFY),
    "caption": ParagraphStyle("Caption", fontName="Body-Italic", fontSize=8.0, leading=11.0, textColor=MUTED, spaceBefore=2.5, spaceAfter=5),
    "table": ParagraphStyle("Table", fontName="Body", fontSize=8.2, leading=10.6, textColor=INK),
    "tiny": ParagraphStyle("Tiny", fontName="Body", fontSize=7.3, leading=9.4, textColor=INK),
    "thead": ParagraphStyle("THead", fontName="Body-Bold", fontSize=8.0, leading=10.2, textColor=colors.white),
    "eq": ParagraphStyle("Eq", fontName="Body-Bold", fontSize=9.3, leading=13.5, textColor=NAVY, alignment=TA_CENTER, spaceBefore=3, spaceAfter=4),
}

story = []

def clean_text(text):
    replacements = [
        ("x₁", "x<sub>1</sub>"), ("x₂", "x<sub>2</sub>"), ("x₃", "x<sub>3</sub>"),
        ("y₁", "y<sub>1</sub>"), ("y₂", "y<sub>2</sub>"), ("y₃", "y<sub>3</sub>"),
        ("z₁", "z<sub>1</sub>"), ("z₂", "z<sub>2</sub>"), ("z₃", "z<sub>3</sub>"),
        ("10⁻³", "10<super>-3</super>"), ("10⁻⁸", "10<super>-8</super>"),
        ("–", "-"), ("—", "-"), ("‑", "-"), ("≈", "~"), ("∈", "thuộc"),
        ("≥", "&gt;="), ("≤", "&lt;="),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    return text

def p(text, style="body"):
    return Paragraph(clean_text(str(text)), styles[style])

def add(text, style="body"):
    story.append(p(text, style))

def bullet(text):
    story.append(p("• " + text, "bullet"))

def h1(text):
    story.append(Spacer(1, 2))
    add(text, "h1")
    story.append(HRFlowable(width="100%", thickness=0.8, color=NAVY, spaceBefore=0, spaceAfter=4))

def h2(text):
    add(text, "h2")

def caption(text):
    add(text, "caption")

def add_fig(filename, width=WIDTH):
    path = FIG_DIR / filename
    with PILImage.open(path) as im:
        w, h = im.size
    story.append(Image(str(path), width=width, height=width * h / w, hAlign="CENTER"))

def add_table(headers, body, widths, small=False, pad=3.5, split=(), notes=None):
    st_name = "tiny" if small else "table"
    data = [[p(x, "thead") for x in headers]]
    for row in body:
        data.append([p(cell, st_name) for cell in row])
    t = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4.0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4.0),
        ("TOPPADDING", (0, 0), (-1, -1), pad),
        ("BOTTOMPADDING", (0, 0), (-1, -1), pad),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, NAVY),
        ("LINEBELOW", (0, -1), (-1, -1), 0.8, NAVY),
        ("INNERGRID", (0, 1), (-1, -1), 0.25, colors.HexColor("#E2E8F0")),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            cmds.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#F8FAFC")))
    for i in split:
        cmds.append(("LINEABOVE", (0, i), (-1, i), 0.7, colors.HexColor("#94A3B8")))
    t.setStyle(TableStyle(cmds))
    story.append(t)
    if notes:
        caption(notes)

# ===========================================================================
# PAGE 1: TITLE + SECTION 1 (V10A vs V10B) + PART OF SECTION 2
# ===========================================================================
add("BÁO CÁO KỸ THUẬT VÀ PHÂN TÍCH KẾT QUẢ MÔ PHỎNG V10A & V10B", "title")
add("Đối chiếu kiến trúc V10A/V10B, mô hình năng lượng kế thừa từ bài báo Drones, hiệu suất năng lượng (EE) theo L/q, quỹ đạo UAV và giải mã hiện tượng '1 m Corridor' qua tọa độ BS tại L = 3 Mbit/user", "subtitle")
add("<b>Nguồn dữ liệu:</b> Campaign chuẩn hóa 54 lượt chạy (216 kết quả phương pháp; 42 tổ hợp tham số độc nhất tương ứng 168 kết quả sau loại trùng) trên 3 scenario seeds (<b>2026</b>, <b>608060</b>, <b>3486784401</b>), ngân sách 120 particles × 1.000 iterations.", "small")

h1("1. Sự khác biệt giữa V10A và V10B")
add("Trong hệ thống UAV-SWIPT-NOMA, cả <b>V10A</b> (<i>maincodeV10A_EE.m</i>) và <b>V10B</b> (<i>maincodeV10B_EE.m</i>) đều dùng chung cấu hình <i>v10Config.m</i>, bộ đánh giá vật lý <i>evaluateTrajectoryV10.m</i>, 21 waypoints (20 slot bay treo phục vụ + 1 điểm đích kết thúc hành trình) ở độ cao cố định <b>Z = 30 m</b> từ điểm xuất phát <b>S(150; 300; 30) m</b> về điểm đích <b>E(150; 0; 30) m</b>. Điểm khác biệt cốt lõi nằm ở <b>bậc tự do hình học theo trục Y</b>:")

add_table(
    ["Tiêu chí đối chiếu", "Phiên bản V10A (Quỹ đạo 1D theo X)", "Phiên bản V10B (Quỹ đạo 2D theo X và Y)"],
    [
        ["<b>Tọa độ trục Y của UAV</b>",
         "Cố định trên lưới chia đều: Y<sub>n</sub> = 300, 285, 270, ..., 0 m (bước tiến cố định <b>ΔY = 15 m/đoạn</b>).",
         "Là biến tối ưu tự do, thỏa điều kiện giảm đơn điệu với bước tiến tối thiểu <b>minYProgress = 1 m/đoạn</b> (Y<sub>n</sub> - Y<sub>n+1</sub> &gt;= 1 m)."],
        ["<b>Tọa độ trục X và Z</b>",
         "Tối ưu 19 điểm X nội bộ trong hành lang <b>[75; 225] m</b>; Z = 30 m cố định.",
         "Giống V10A: tối ưu 19 điểm X nội bộ trong <b>[75; 225] m</b>; Z = 30 m cố định."],
        ["<b>Phân bổ công suất NOMA (α)</b>",
         "21 × 5 = 105 trọng số trong particle (hàng thứ 21 tại điểm đích được khóa về 1/5 = 0,2; 20 slot đầu xếp theo kênh yếu → mạnh).",
         "Giống hệt V10A (105 trọng số trong particle; 20 slot phục vụ thực tế)."],
        ["<b>Tọa độ trạm gốc (3 BS)</b>",
         "<b>JointPSO:</b> cố định tại vị trí gốc. <b>Full PSO / IPSO:</b> tối ưu thêm 6 biến (x<sub>BS</sub>, y<sub>BS</sub>) trong hộp ±50 m.",
         "Giống hệt V10A: JointPSO cố định BS; Full PSO và IPSO tối ưu 6 biến (x<sub>BS</sub>, y<sub>BS</sub>)."],
        ["<b>Số chiều vector Particle</b>",
         "<b>124 chiều</b> (JointPSO) / <b>130 chiều</b> (Full PSO &amp; IPSO).",
         "<b>143 chiều</b> (JointPSO) / <b>149 chiều</b> (Full PSO &amp; IPSO) — tăng thêm 19 biến Y nội bộ."],
        ["<b>Cơ chế sửa hạt (Repair)</b>",
         "Kẹp biên X trong [75; 225] m, trọng số α trong [10<sup>-3</sup>; 1] và (x<sub>BS</sub>, y<sub>BS</sub>) trong hộp cho phép (<i>repairV10Particle.m</i>).",
         "Ngoài kẹp biên như V10A, thực hiện sắp xếp đơn điệu 19 điểm Y nội bộ và ép khoảng cách tối thiểu 1 m giữa hai waypoint liên tiếp."],
        ["<b>Hành vi quỹ đạo &amp; Hệ quả</b>",
         "UAV buộc phải rải đều điểm dừng dọc toàn bộ hành lang 300 m → đường bay dài hơn (TB <b>544,87 m</b>), EE thấp hơn (TB <b>6.452,96 bit/J</b>), nhưng công bằng hơn giữa các user (<b>Jain = 0,749</b>).",
         "UAV gom các điểm phục vụ vào vùng kênh thuận lợi gần BS &amp; cụm user → đường bay ngắn hơn (TB <b>445,54 m</b>, -16,84%), tổng bit tăng +42,40%, EE tăng vọt (TB <b>9.956,75 bit/J</b>, <b>+55,79%</b>), nhưng sinh ra hiện tượng <b>'1 m corridor'</b> và giảm độ công bằng (<b>Jain = 0,569</b>)."]
    ],
    [102, 202, WIDTH - 304],
    small=True, pad=3.5,
    notes="Bảng 1. Tổng hợp sự khác biệt thiết kế, số chiều bài toán và đặc tính nghiệm giữa V10A và V10B (số liệu trung bình tính trên 21 cặp cấu hình Full IPSO)."
)

h2("Đối chiếu định lượng V10A và V10B trên 21 cặp cấu hình chuẩn (Full IPSO)")
add_table(
    ["Chỉ số đánh giá (trung bình trên 21 cấu hình độc nhất)", "V10A + Full IPSO", "V10B + Full IPSO", "Mức thay đổi (V10B so với V10A)"],
    [
        ["<b>Hiệu suất năng lượng UAV — EE<sub>UAV</sub> (bit/J)</b>", "6 452,96", "<b>9 956,75</b>", "<b>+55,79%</b> (trung bình từng cặp) / +54,30% (tỷ số 2 TB)"],
        ["<b>Tổng dữ liệu truyền toàn nhiệm vụ (Mbit)</b>", "59,58", "<b>84,51</b>", "<b>+42,40%</b> (nhờ gom điểm phục vụ gần BS/User)"],
        ["<b>Tổng năng lượng UAV tiêu thụ E<sub>total</sub> (J)</b>", "8 749,74", "<b>8 052,59</b>", "<b>-7,79%</b> (tiết kiệm năng lượng bay hành trình)"],
        ["<b>Tổng chiều dài quỹ đạo bay D (m)</b>", "544,87", "<b>445,54</b>", "<b>-16,84%</b> (giảm các chặng bay zíc-zắc ngang)"],
        ["<b>Chỉ số công bằng dữ liệu Jain Fairness Index</b>", "<b>0,749</b>", "0,569", "<b>-24,03%</b> (dữ liệu tập trung hơn vào user kênh tốt)"]
    ],
    [195, 95, 95, WIDTH - 385],
    small=True, pad=3.2,
    notes="Bảng 2. So sánh ghép cặp trực tiếp giữa V10A và V10B với thuật toán Full IPSO (cả hai đều khả thi ở 21/21 cấu hình)."
)

# ===========================================================================
# PAGE 2: SECTION 2 (DRONES PAPER INHERITANCE) + SECTION 3.1 (FEASIBILITY)
# ===========================================================================
story.append(PageBreak())
h1("2. Những gì V10A và V10B kế thừa từ bài báo Drones và phần điều chỉnh")
add("Mô hình năng lượng của V10A/V10B được xây dựng dựa trên bài báo: Tianyi Zhang et al., <i>\"Trajectory and Power Control for Sustainable UAV-Assisted NOMA-Enabled Backscattering IoT\"</i>, <b>Drones 2026, 10(4), 238</b>. Tuy nhiên, V10 không sao chép nguyên xi toàn bộ bài toán của bài báo mà <b>kế thừa có chọn lọc mô hình cơ học bay quad-rotor</b> và <b>bổ sung tường minh năng lượng bay treo (hover)</b> để ghép vào hệ thống SWIPT-NOMA:")

add("T<sub>r</sub>(v) = (1 / n<sub>r</sub>) · sqrt( (m·g)<sup>2</sup> + (0,5 · ρ · S<sub>FP</sub> · v<sup>2</sup>)<sup>2</sup> ),    P<sub>f</sub>(v) = P<sub>profile</sub>(v) + P<sub>induced</sub>(v) + P<sub>parasite</sub>(v)", "eq")
add("EE<sub>UAV</sub> = ( ∑<sub>u=1..5</sub> ∑<sub>n=1..20</sub> D<sub>u,n</sub> ) / ( E<sub>fly</sub> + E<sub>hover</sub> + E<sub>RF</sub> ) = D<sub>tổng</sub> / ( P<sub>f</sub>(v)·∑(d<sub>n</sub>/v) + P<sub>f</sub>(0)·∑h<sub>n</sub> + ∑P<sub>RF,n</sub>·T<sub>RF,n</sub> )", "eq")

add_table(
    ["Hạng mục", "Trong bài báo Drones 2026, 10(4), 238", "Kế thừa &amp; điều chỉnh trong V10A / V10B"],
    [
        ["<b>Cơ học bay &amp; Lực đẩy</b>",
         "UAV 4 rotor (n<sub>r</sub>=4, m=2 kg) bay ngang độ cao cố định với vận tốc không đổi v = 15,521 m/s; cân bằng lực vector Eq. (10).",
         "<b>Kế thừa hoàn toàn:</b> Bay ngang ở Z = 30 m (bài báo dùng Z = 50 m), v = 15,521 m/s; lấy chuẩn độ lớn lực đẩy mỗi rotor T<sub>r</sub>(v) trong <i>dronePropulsionPower.m</i>."],
        ["<b>Công thức công suất P<sub>f</sub>(v) &amp; Tham số</b>",
         "Eq. (11) gồm 3 thành phần (Profile + Induced + Parasite) và bộ 12 tham số vật lý tại Table 2. Bài báo ghi P<sub>f</sub> = 108,9118 W.",
         "<b>Kế thừa nguyên văn Eq. (11) &amp; Table 2:</b> ρ=1,293 kg/m<sup>3</sup>, S<sub>FP</sub>=0,01 m<sup>2</sup>, c<sub>s</sub>=0,0955, δ=0,012, c<sub>T</sub>=0,302, c<sub>f</sub>=0,131, d<sub>0</sub>=0,8333, A=0,0314 m<sup>2</sup>. Tính chính xác từ công thức cho <b>P<sub>cruise</sub> = 108,940787 W</b> (lệch 0,0266% so với số in trong bài; giữ nguyên giá trị tính từ công thức)."],
        ["<b>Năng lượng bay hành trình (E<sub>fly</sub>)</b>",
         "E<sub>f</sub> = P<sub>f</sub>(v) · ∑ (||q<sub>n+1</sub> - q<sub>n</sub>|| / v), bỏ qua chi phí tăng/giảm tốc và đổi hướng.",
         "<b>Kế thừa trực tiếp:</b> Tính tổng thời gian bay trên đủ 20 chặng (kể cả chặng 20 về điểm đích E). Chi phí bay ngang tương đương <b>7,0189 J/m</b>."],
        ["<b>Năng lượng động cơ khi Hover (E<sub>hover</sub>)</b>",
         "Giao thức thu dữ liệu khi hover (t<sub>hov</sub> = 0,1 s), nhưng biểu thức năng lượng in trong bài (E<sub>f</sub> + E<sub>t</sub> &lt;= E<sub>max</sub>) <b>không tách hạng công suất động cơ khi bay treo</b>.",
         "<b>Bổ sung tường minh trong V10:</b> Tính công suất động cơ tại v = 0 m/s từ cùng hàm Eq. (11): <b>P<sub>hover</sub> = P<sub>f</sub>(0) = 172,387633 W</b> (gồm 0,1859 W profile + 172,2018 W induced) và cộng <b>E<sub>hover</sub> = P<sub>f</sub>(0) · 20 · h</b> vào mẫu số EE. Khảo sát h = 1, 2, 3 s."],
        ["<b>Ngân sách năng lượng</b>",
         "Eq. (12): Tổng năng lượng tiêu thụ không vượt E<sub>max</sub> = 17.000 J.",
         "<b>Kế thừa ngưỡng E<sub>budget</sub> = 17.000 J</b> áp cho tổng tải E<sub>total</sub> = E<sub>fly</sub> + E<sub>hover</sub> + E<sub>RF</sub>."],
        ["<b>Hệ thống vô tuyến &amp; Nguồn RF</b>",
         "Backscatter IoT (BackCom); UAV phát sóng mang liên tục kích hoạt tag phản xạ; tối đa hóa tổng thông lượng (Sum-Throughput).",
         "<b>Giữ mô hình SWIPT-NOMA của dự án:</b> Mỗi slot hover h chia thành h/2 thu hoạch năng lượng (EH/UL) từ 3 BS (46 dBm/BS, η=φ=0,9) và h/2 phát NOMA downlink. Năng lượng thu hoạch cấp lý tưởng cho RF (E<sub>RF</sub> ~ µJ, chỉ chiếm &lt;= 2,43×10<sup>-8</sup> tổng năng lượng)."],
        ["<b>Hàm mục tiêu, Ràng buộc QoS &amp; Bộ giải</b>",
         "Tối đa hóa Sum-Throughput bằng KKT / Golden Section Search kết hợp quy hoạch lộ trình TSP/GA.",
         "<b>Tối đa hóa EE<sub>UAV</sub> (bit/J)</b> dưới ràng buộc QoS kép: tổng dữ liệu mỗi user <b>D<sub>u</sub> &gt;= L</b> (1, 2, 3 Mbit) và dữ liệu mỗi user-slot <b>D<sub>u,n</sub> &gt;= q</b> (0, 5, 10 kbit), giải bằng <b>JointPSO, Full PSO, Full IPSO + Alpha Polishing</b>."]
    ],
    [95, 195, WIDTH - 290],
    small=True, pad=3.5,
    notes="Bảng 3. Đối chiếu chi tiết các phần kế thừa từ bài báo Drones [1] và những điều chỉnh/mở rộng trong V10A/V10B."
)

h1("3. Kết quả EE theo các mức L và q của từng thuật toán")
h2("3.1. Vai trò của Baseline và tỷ lệ tìm được nghiệm khả thi (Feasibility Rate)")
add("Campaign thực nghiệm gồm 54 lượt chạy (216 kết quả), sau khi loại bỏ 12 lượt trùng bộ tham số (L = 3 Mbit, q = 5 kbit, hover = 1 s xuất hiện ở cả 3 nhánh sweep với cùng RNG seed) còn lại <b>42 tổ hợp cấu hình độc nhất (168 kết quả phương pháp)</b>. Chỉ những nghiệm thỏa mãn đồng thời mọi ràng buộc (hình học, năng lượng &lt;= 17 kJ, D<sub>u</sub> &gt;= L và D<sub>u,n</sub> &gt;= q) mới được công nhận là <b>khả thi (feasible)</b> để tính trung bình EE:")

bullet("<b>Baseline (quỹ đạo bay thẳng X = 150 m, BS cố định, phân bổ α theo kênh):</b> Chỉ được nhắc tới như mốc tham chiếu hình học vì chỉ đạt QoS ở đúng <b>2/42 tổ hợp</b> (cả 2 đều ở mức <b>hover = 3 s</b>, L = 3 Mbit, q = 5 kbit tại seed 608060 khi tổng thời gian bay treo lên tới 60 s, đạt EE = 3.034,0 bit/J). Ở toàn bộ các lượt chạy có <b>hover = 1 s hoặc 2 s</b> (bao gồm toàn bộ sweep L và sweep q), Baseline đạt <b>0/3 nghiệm khả thi</b> do đường bay thẳng ở giữa vùng cách xa các BS biên, không thu đủ năng lượng RF để đạt ngưỡng L và q.")
bullet("<b>JointPSO (tối ưu quỹ đạo + α, giữ BS cố định tại vị trí gốc):</b> Đạt khả thi ở <b>10/21</b> tổ hợp V10A và <b>14/21</b> tổ hợp V10B (tổng <b>24/42</b>). Khi L tăng từ 1 → 2 → 3 Mbit ở V10A, số seed khả thi giảm từ 3/3 → 1/3 → 0/3.")
bullet("<b>Full PSO (tối ưu đồng thời quỹ đạo + α + vị trí 3 BS, kèm 25.000 mẫu Alpha Polishing):</b> Đạt khả thi ở <b>20/21</b> tổ hợp V10A và <b>21/21</b> tổ hợp V10B (tổng <b>41/42</b>); chỉ trượt duy nhất 1 trường hợp tại V10A, seed 2026, L = 3 Mbit, q = 10 kbit (thiếu bit ở 2/100 user-slot).")
bullet("<b>Full IPSO (cùng không gian biến với Full PSO, bổ sung quán tính giảm tuyến tính 0,9 → 0,4, đột biến thích nghi khi trì trệ và lưu trữ elite, kèm Alpha Polishing):</b> Đạt khả thi tuyệt đối ở <b>21/21</b> tổ hợp V10A và <b>21/21</b> tổ hợp V10B (tổng <b>42/42</b>).")

# ===========================================================================
# PAGE 3: FIGURE 1 + TABLE 4 (SWEEP L) + TABLE 5 (SWEEP q)
# ===========================================================================
story.append(PageBreak())
add_fig("ee_L_q_combined.png", width=WIDTH)
caption("Hình 1. Biểu đồ EE khả thi (kbit/J) theo mức dữ liệu nhiệm vụ L (hàng trên, giữ q = 5 kbit/slot, hover = 1 s) và theo ngưỡng dữ liệu từng slot q (hàng dưới, giữ L = 3 Mbit/user, hover = 1 s). Đường liền nối trung bình các seed khả thi; chấm mờ biểu diễn từng seed; nhãn n/3 chỉ số seed khả thi.")

h2("3.2. Kết quả EE khi thay đổi L (L = 1, 2, 3 Mbit/user; giữ q = 5 kbit/slot, hover = 1 s)")
l_summary_rows = []
for v in ["A", "B"]:
    for L_val in [1e6, 2e6, 3e6]:
        rr = pick(v, L=L_val, q=5000, h=1)
        row_cells = [f"<b>V10{v}</b>", f"<b>{int(L_val/1e6)} Mbit</b>"]
        for a in ALGOS:
            sub = [r for r in rr if r["algorithm"] == a]
            good = [r["ee"] for r in sub if r["feasible"]]
            all_ee = [r["ee"] for r in sub]
            if a == "Baseline":
                row_cells.append(f"0/3 <i>({fmt(st.mean(all_ee))}*)</i>")
            else:
                if good:
                    row_cells.append(f"<b>{fmt(st.mean(good))}</b> ({len(good)}/3)")
                else:
                    row_cells.append(f"— (0/3) <i>[{fmt(st.mean(all_ee))}*]</i>")
        ipso_seeds = [pick(v, "Full IPSO", L=L_val, q=5000, h=1, seed=s)[0]["ee"] for s in SEEDS]
        row_cells.append(" / ".join(fmt(x, 0) for x in ipso_seeds))
        l_summary_rows.append(row_cells)

add_table(
    ["Bản", "Mức L", "Baseline (tham chiếu)", "JointPSO (BS cố định)", "Full PSO (tối ưu BS)", "IPSO (tối ưu BS)", "IPSO từng seed (2026 / 608060 / 3486784401)"],
    l_summary_rows,
    [34, 42, 82, 88, 82, 82, WIDTH - 410],
    small=True, pad=3.2, split=[4],
    notes="Bảng 4. EE trung bình (bit/J) trên các seed khả thi theo L (giữ q = 5 kbit/user/slot, hover = 1 s). Số trong ngoặc (n/3) là số seed đạt QoS; giá trị có dấu * là EE chẩn đoán khi vi phạm QoS."
)

h2("3.3. Kết quả EE khi thay đổi q (q = 0, 5, 10 kbit/user/slot; giữ L = 3 Mbit/user, hover = 1 s)")
q_summary_rows = []
for v in ["A", "B"]:
    for q_val in [0, 5000, 10000]:
        rr = pick(v, L=3e6, q=q_val, h=1)
        row_cells = [f"<b>V10{v}</b>", f"<b>{int(q_val/1000)} kbit</b>"]
        for a in ALGOS:
            sub = [r for r in rr if r["algorithm"] == a]
            good = [r["ee"] for r in sub if r["feasible"]]
            all_ee = [r["ee"] for r in sub]
            if a == "Baseline":
                row_cells.append(f"0/3 <i>({fmt(st.mean(all_ee))}*)</i>")
            else:
                if good:
                    row_cells.append(f"<b>{fmt(st.mean(good))}</b> ({len(good)}/3)")
                else:
                    row_cells.append(f"— (0/3) <i>[{fmt(st.mean(all_ee))}*]</i>")
        ipso_seeds = [pick(v, "Full IPSO", L=3e6, q=q_val, h=1, seed=s)[0]["ee"] for s in SEEDS]
        row_cells.append(" / ".join(fmt(x, 0) for x in ipso_seeds))
        q_summary_rows.append(row_cells)

add_table(
    ["Bản", "Mức q", "Baseline (tham chiếu)", "JointPSO (BS cố định)", "Full PSO (tối ưu BS)", "IPSO (tối ưu BS)", "IPSO từng seed (2026 / 608060 / 3486784401)"],
    q_summary_rows,
    [34, 42, 82, 88, 82, 82, WIDTH - 410],
    small=True, pad=3.2, split=[4],
    notes="Bảng 5. EE trung bình (bit/J) trên các seed khả thi theo q (giữ L = 3 Mbit/user, hover = 1 s). Khi tăng q từ 5 lên 10 kbit/slot, EE của IPSO giảm 9,78% ở V10A và 14,02% ở V10B do phải phân bổ thêm công suất cho user kênh yếu ở mọi slot."
)

# ===========================================================================
# PAGE 4: DETAILED PER-SEED TABLE FOR L & q + HOVER SWEEP SUMMARY
# ===========================================================================
story.append(PageBreak())
h2("3.4. Bảng chi tiết EE từng Scenario Seed theo L và q (cho cả 4 phương pháp)")
add("Để tránh sai lệch khi so sánh các trung bình có số mẫu khả thi (n/3) khác nhau, Bảng 6 liệt kê toàn bộ giá trị EE tính được trên từng scenario seed cho cả sweep L và sweep q:")

detail_rows = []
for sw_label, param_list, is_L in [
    ("Sweep L (q=5k, h=1s)", [1e6, 2e6, 3e6], True),
    ("Sweep q (L=3M, h=1s)", [0, 5000, 10000], False),
]:
    for val in param_list:
        L_v = val if is_L else 3e6
        q_v = 5000 if is_L else val
        p_str = f"L={int(L_v/1e6)}M, q={int(q_v/1000)}k"
        for seed in SEEDS:
            row_cells = [p_str, str(seed)]
            for v in ["A", "B"]:
                for a in ALGOS:
                    r = pick(v, a, L=L_v, q=q_v, h=1, seed=seed)[0]
                    val_str = fmt(r["ee"], 1)
                    if not r["feasible"]:
                        row_cells.append(f"<i>{val_str}*</i>")
                    else:
                        row_cells.append(f"<b>{val_str}</b>" if a in ("Full PSO", "Full IPSO") else val_str)
            detail_rows.append(row_cells)

add_table(
    ["Cấu hình (h=1s)", "Seed", "A:Base", "A:Joint", "A:FullPSO", "A:IPSO", "B:Base", "B:Joint", "B:FullPSO", "B:IPSO"],
    detail_rows,
    [68, 52, 46, 48, 52, 52, 46, 48, 52, WIDTH - 464],
    small=True, pad=2.8, split=[4, 7, 10, 13, 16],
    notes="Bảng 6. Toàn bộ kết quả EE (bit/J) theo từng seed cho Sweep L và Sweep q tại hover = 1 s (hàng L=3M, q=5k là điểm giao của hai sweep). Giá trị in nghiêng có dấu * là nghiệm vi phạm QoS (chỉ mang ý nghĩa chẩn đoán)."
)

h2("3.5. Kết quả bổ sung khi thay đổi thời gian Hover (h = 1, 2, 3 s tại L = 3 Mbit, q = 5 kbit)")
hover_rows = []
for v in ["A", "B"]:
    for h_val in [1, 2, 3]:
        rr = pick(v, L=3e6, q=5000, h=h_val)
        row_cells = [f"<b>V10{v}</b>", f"<b>{h_val} s</b> ({20*h_val} s tổng)"]
        for a in ALGOS:
            sub = [r for r in rr if r["algorithm"] == a]
            good = [r["ee"] for r in sub if r["feasible"]]
            all_ee = [r["ee"] for r in sub]
            if good:
                row_cells.append(f"<b>{fmt(st.mean(good))}</b> ({len(good)}/3)" if a != "Baseline" else f"{fmt(st.mean(good))} ({len(good)}/3)")
            else:
                row_cells.append(f"0/3 <i>({fmt(st.mean(all_ee))}*)</i>")
        ipso_seeds = [pick(v, "Full IPSO", L=3e6, q=5000, h=h_val, seed=s)[0]["ee"] for s in SEEDS]
        row_cells.append(" / ".join(fmt(x, 0) for x in ipso_seeds))
        hover_rows.append(row_cells)

add_table(
    ["Bản", "Hover / slot", "Baseline (tham chiếu)", "JointPSO (BS cố định)", "Full PSO (tối ưu BS)", "IPSO (tối ưu BS)", "IPSO từng seed (2026 / 608060 / 3486784401)"],
    hover_rows,
    [34, 62, 78, 84, 80, 80, WIDTH - 418],
    small=True, pad=3.0, split=[4],
    notes="Bảng 7. EE trung bình (bit/J) theo thời gian bay treo mỗi điểm phục vụ h = 1, 2, 3 s (giữ L = 3 Mbit/user, q = 5 kbit/user/slot)."
)

h2("3.6. Nhận xét tổng hợp về thuật toán và độ nhạy tham số")
bullet("<b>So sánh IPSO và Full PSO:</b> Trên 20 cặp cấu hình khả thi của V10A, IPSO thắng 19/20 cặp (gain trung bình <b>+6,33%</b>, trung vị +2,93%). Trên 21 cặp của V10B, IPSO thắng 16/21 cặp (gain trung bình <b>+17,61%</b>, trung vị +6,10%). Tuy nhiên IPSO không thắng mọi trường hợp riêng lẻ (ví dụ tại V10B, seed 2026, hover 3 s, Full PSO đạt kỷ lục <b>16.901,9 bit/J</b> so với 16.392,5 bit/J của IPSO).")
bullet("<b>Hiện tượng EE tìm được tăng nhẹ khi tăng L ở V10B (8.343,6 → 9.390,4 bit/J):</b> Về mặt toán học, khi siết chặt ràng buộc L (miền khả thi thu hẹp), giá trị tối ưu toàn cục thật sự không thể tăng. Hiện tượng tăng này là đặc trưng của tìm kiếm heuristic (PSO/IPSO) với ngân sách vòng lặp hữu hạn: ràng buộc L = 3 Mbit loại bỏ sớm các hố cực trị cục bộ có đường bay ngắn nhưng ít dữ liệu, đẩy bầy hạt sang vùng hình học gần BS hơn và tìm được nghiệm có tổng bit vượt trội.")

# ===========================================================================
# PAGES 5 & 6: SECTION 4 — UAV TRAJECTORIES AT L = 3 MBIT
# ===========================================================================
story.append(PageBreak())
h1("4. Quỹ đạo của UAV và tọa độ BS tại mức L = 3 Mbit/user")
add("Các Hình 2, 3 và 4 biểu diễn mặt phẳng ngang XY (ở độ cao UAV Z = 30 m) dưới cả 3 thuật toán <b>JointPSO</b>, <b>Full PSO</b> và <b>IPSO</b> tại cấu hình chuẩn <b>L = 3 Mbit/user, q = 5 kbit/user/slot, hover = 1 s</b> trên 3 scenario seeds. Các đoạn màu đỏ đậm trên quỹ đạo V10B đánh dấu trực tiếp các chặng mà UAV <b>bò từng bước ΔY ~ 1,0 m dọc biên hành lang (hành vi 1 m corridor)</b>.")

add_fig("traj_grid_seed_2026.png", width=WIDTH * 0.96)
caption("Hình 2. Quỹ đạo UAV và vị trí BS tại Seed 2026 (L = 3 Mbit/user, q = 5 kbit/user/slot, hover = 1 s). Hàng trên: V10A (ΔY = 15 m cố định); Hàng dưới: V10B (tự do chọn Y với ΔY >= 1 m). Các đoạn tô đỏ đậm trên V10B là các cụm bước tiến tối thiểu ΔY ~ 1 m dọc biên hành lang X = 75 m và X = 225 m.")

add_fig("traj_grid_seed_608060.png", width=WIDTH * 0.96)
caption("Hình 3. Quỹ đạo UAV và vị trí BS tại Seed 608060 (L = 3 Mbit/user, q = 5 kbit/user/slot, hover = 1 s). Ở V10B, cả Full PSO (11/20 đoạn) và IPSO (15/20 đoạn) đều ghim UAV vào biên trái X = 75 m đối diện BS2(50; ~150) m rồi nhảy chéo sang biên phải X = 225 m đối diện BS3(250; 50) m.")

story.append(PageBreak())
add_fig("traj_grid_seed_3486784401.png", width=WIDTH * 0.88)
caption("Hình 4. Quỹ đạo UAV và vị trí BS tại Seed 3486784401 (L = 3 Mbit/user, q = 5 kbit/user/slot, hover = 1 s). Do các User U1-U4 tập trung bên phải hành lang, V10B ghim UAV dọc biên phải X = 225 m để bò 1 m/bước ngang qua BS1(250; 250) m và BS3(250; 50) m.")

# ===========================================================================
# SECTION 5 — BS COORDINATES & THE 1m CORRIDOR PHENOMENON
# ===========================================================================
h1("5. Liệt kê tọa độ BS ở các seed L = 3 Mbit và giải mã hiện tượng '1 m Corridor'")
h2("5.1. Bảng tọa độ 3 BS và đặc trưng cụm '1 m Corridor' ở cấu hình chuẩn (L = 3 Mbit, q = 5 kbit, h = 1 s)")
add("Trong V10A/V10B, mỗi BS được phép dịch chuyển ngang ±50 m quanh vị trí gốc (cắt theo biên vùng 300 × 300 m), tạo thành 3 hộp tìm kiếm: <b>BS1</b> trong [250; 300] × [250; 300] m (Z = 20 m), <b>BS2</b> trong [0; 50] × [100; 200] m (Z = 30 m), và <b>BS3</b> trong [250; 300] × [0; 50] m (Z = 25 m). Bảng 8 liệt kê đầy đủ tọa độ BS của cả 3 thuật toán tại 3 seed, đặt cạnh các thông số cụm <b>1 m corridor</b> của UAV:")

bs_corridor_rows = []
for v in ["A", "B"]:
    for seed in SEEDS:
        for a, a_short in [("Joint PSO", "JointPSO"), ("Full PSO", "Full PSO"), ("Full IPSO", "IPSO")]:
            r = pick(v, a, L=3e6, q=5000, h=1, seed=seed)[0]
            bs_strs = [f"({fmt(r['xBS'][j], 2)}; {fmt(r['yBS'][j], 2)}; {int(r['zBS'][j])})" for j in range(3)]
            x_t = np.array(r["xTraj"])
            y_t = np.array(r["yTraj"])
            dy = -np.diff(y_t)
            ds = np.hypot(np.diff(x_t), np.diff(y_t))
            n_1m = int(np.sum(dy <= 1.05))
            n_x75 = int(np.sum(np.abs(x_t[1:-1] - 75.0) <= 0.5))
            n_x225 = int(np.sum(np.abs(x_t[1:-1] - 225.0) <= 0.5))
            bs_corridor_rows.append([
                f"<b>V10{v}</b>", str(seed), a_short + ("" if r["feasible"] else "*"),
                bs_strs[0], bs_strs[1], bs_strs[2],
                f"<b>{n_1m}/20</b>" if v == "B" else "0/20",
                f"{n_x75}T / {n_x225}P",
                fmt(ds.max(), 1),
                f"<b>{fmt(r['ee'], 1)}</b>" if r["feasible"] else f"<i>{fmt(r['ee'], 1)}*</i>"
            ])

add_table(
    ["Bản", "Seed", "T.Toán", "BS1 (x; y; z) m", "BS2 (x; y; z) m", "BS3 (x; y; z) m", "Đoạn 1m", "Biên 75T/225P", "Nhảy max", "EE (bit/J)"],
    bs_corridor_rows,
    [30, 54, 42, 74, 74, 70, 38, 48, 39, WIDTH - 469],
    small=True, pad=2.0, split=[4, 7, 10, 13, 16],
    notes="Bảng 8. Tọa độ BS1, BS2, BS3 và thống kê hành vi '1 m corridor' tại L = 3 Mbit, q = 5 kbit, hover = 1 s (ở V10A mọi bước đều cố định ΔY = 15 m). Cột 'Biên 75T/225P' đếm số waypoint nội bộ chạm biên trái X = 75 m (T) và biên phải X = 225 m (P)."
)

# ===========================================================================
# PAGE 7: MECHANISM + FIGURE 5 + TABLE 9 (CLUSTER BREAKDOWN)
# ===========================================================================
story.append(PageBreak())
h2("5.2. Cơ chế vật lý: Vì sao tọa độ BS lại sinh ra hiện tượng '1 m Corridor' ở V10B?")
add("Nhìn vào Bảng 8 và Hình 5 bên dưới, có thể thấy mối liên hệ nhân quả trực tiếp giữa <b>vị trí BS tối ưu</b> và <b>hiện tượng 1 m corridor</b> của UAV:")
bullet("<b>1) Các BS kéo sát về mép hành lang bay của UAV:</b> Hành lang cho phép của UAV là <b>X thuộc [75; 225] m</b>. Khi được tối ưu (Full PSO / IPSO), BS1 và BS3 luôn ép chặt về biên trái của hộp tìm kiếm tại <b>x<sub>BS1</sub> = 250 m</b> và <b>x<sub>BS3</sub> = 250 m</b> (cách mép phải hành lang UAV X = 225 m đúng <b>25 m</b>), còn BS2 ép chặt về biên phải của hộp tìm kiếm tại <b>x<sub>BS2</sub> = 50 m</b> (cách mép trái hành lang UAV X = 75 m đúng <b>25 m</b>; ngoại trừ duy nhất 1 nghiệm IPSO ở seed 3486784401 khi toàn bộ quỹ đạo UAV nằm bên phải X = 225 m nên BS2 ở bên trái trở nên rất xa và ít ảnh hưởng).")
bullet("<b>2) Điểm ngọt thu hoạch năng lượng (Sweet-spot EH):</b> Vì suy hao đường truyền tỉ lệ với d<sup>-2,5</sup>, công suất thu hoạch năng lượng RF của UAV đạt cực đại khi UAV áp sát mép hành lang <b>X = 75 m</b> (ngay đối diện BS2, khoảng cách 3D chỉ <b>25,0 m</b> vì Z<sub>UAV</sub> = Z<sub>BS2</sub> = 30 m) hoặc áp sát mép <b>X = 225 m</b> (ngay đối diện BS3 với khoảng cách 3D <b>25,5 m</b> hoặc BS1 với khoảng cách 3D <b>26,9 m</b>).")
bullet("<b>3) Ràng buộc ΔY &gt;= 1 m biến 'mong muốn đứng yên' thành 'bò 1 m/bước' (1 m Corridor Crawl):</b> Để tối đa hóa tổng bit chia tổng năng lượng, UAV muốn <b>đứng yên nhiều slot liên tiếp</b> tại đúng tung độ Y ~ y<sub>BS2</sub> (trên biên X = 75 m) và Y ~ y<sub>BS3</sub> hoặc y<sub>BS1</sub> (trên biên X = 225 m), vừa giảm quãng đường bay E<sub>fly</sub> vừa hưởng kênh EH/DL mạnh nhất. Nhưng vì V10B cấm đứng yên bởi ràng buộc cứng <b>Y<sub>n</sub> - Y<sub>n+1</sub> &gt;= minYProgress = 1 m</b>, bộ tối ưu lách ràng buộc bằng cách <b>ghim cứng X<sub>n</sub> = 75 m hoặc 225 m và nhích Y<sub>n</sub> từng bước đúng 1,00 m qua 11 đến 17 chặng liên tiếp ngay ngang tọa độ y<sub>BS</sub></b>, sau đó dùng 2-3 chặng nhảy vọt dài (95-196 m) để nối giữa các cụm và về đích!")

add_fig("corridor_1m_analysis.png", width=WIDTH * 0.89)
caption("Hình 5. Chẩn đoán trực tiếp hiện tượng '1 m Corridor' ở cả 3 seed (L = 3 Mbit, q = 5 kbit, h = 1 s). Hàng trên: Tung độ Y_n của 21 waypoints so với tung độ y_BS1, y_BS2, y_BS3 (đường ngang nét đứt) — các đoạn phẳng của V10B nằm ngay tại tung độ của BS2 và BS1/BS3. Hàng dưới: Bước tiến ΔY_n từng chặng — 15 đến 17/20 chặng bị ghim đúng bằng ngưỡng tối thiểu 1,0 m.")

h2("5.3. Đối chiếu từng cụm '1 m Corridor' với tọa độ BS tại 3 Seed")
cluster_rows = [
    ["<b>2026</b><br/>(16/20 đoạn ΔY=1m)",
     "<b>Cụm 1 (WP 2→15, 13 đoạn):</b> Ghim tại biên trái <b>X = 75,0 m</b>, Y bò đúng 1,0 m/đoạn từ <b>199,4 → 186,4 m</b>.<br/>"
     "<b>Cụm 2 (WP 16→19, 3 đoạn):</b> Ghim tại biên phải <b>X = 225,0 m</b>, Y bò đúng 1,0 m/đoạn từ <b>60,3 → 57,3 m</b>.",
     "• Cụm 1 bao quanh chính giữa <b>BS2 (50,00; 192,90; 30) m</b> (cách ngang 25 m) và gần U4(104;212), U5(159;193).<br/>"
     "• Cụm 2 nằm sát <b>BS3 (250,00; 50,00; 25) m</b> và phục vụ U2(222;88).",
     "3 cú nhảy: WP 1→2 (125,6 m), WP 15→16 (<b>196,0 m</b> vắt ngang từ X=75 sang X=225), WP 19→20 (91,0 m)."],
    ["<b>608060</b><br/>(15/20 đoạn ΔY=1m)",
     "<b>Cụm 1 (WP 2→14, 12 đoạn):</b> Ghim tại biên trái <b>X = 75,0 m</b>, Y bò đúng 1,0 m/đoạn từ <b>156,5 → 144,5 m</b>.<br/>"
     "<b>Cụm 2 (WP 15→19, 4 đoạn):</b> Ghim tại biên phải <b>X = 225,0 m</b>, Y bò 1,0 m/đoạn từ <b>57,2 → 53,1 m</b>.",
     "• Cụm 1 có tâm tại Y = 150,5 m, trùng khít tung độ <b>BS2 (50,00; 150,48; 30) m</b> (khoảng cách 3D chỉ 25,0 m) và gần U2, U3, U5.<br/>"
     "• Cụm 2 áp sát <b>BS3 (250,00; 50,00; 25) m</b>.",
     "3 cú nhảy: WP 1→2 (162,0 m), WP 14→15 (<b>173,5 m</b> vắt từ X=75 sang X=225), WP 19→20 (90,0 m)."],
    ["<b>3486784401</b><br/>(15/20 đoạn ΔY=1m)",
     "<b>Cụm 1 (WP 2→7, 5 đoạn):</b> Ghim tại biên phải <b>X = 225,0 m</b>, Y bò ~1,0 m/đoạn từ <b>245,2 → 240,0 m</b>.<br/>"
     "<b>Cụm 2 (WP 9→20, 11 đoạn):</b> Ghim tại biên phải <b>X = 225,0 m</b>, Y bò đúng 1,0 m/đoạn từ <b>61,7 → 50,6 m</b>.",
     "• Cụm 1 áp sát góc <b>BS1 (250,00; 250,00; 20) m</b> để thu năng lượng phục vụ cụm U1, U2, U4 bên phải.<br/>"
     "• Cụm 2 dừng kết thúc ngay tại Y = 50,6 m, đối diện trực tiếp <b>BS3 (250,00; 50,00; 25) m</b>.",
     "4 cú nhảy dọc biên phải: WP 1→2 (93,0 m), WP 7→8 (84,3 m), WP 8→9 (<b>94,8 m</b>), WP 20→21 (90,5 m)."]
]

add_table(
    ["Seed (V10B IPSO)", "Cấu trúc các cụm bò 1 m (1 m Corridor Clusters)", "Mối liên hệ trực tiếp với tọa độ BS &amp; User", "Các bước nhảy chuyển tiếp (Long Jumps)"],
    cluster_rows,
    [68, 155, 165, WIDTH - 388],
    small=True, pad=2.2,
    notes="Bảng 9. Giải mã chi tiết vị trí các cụm '1 m corridor' trên quỹ đạo V10B + IPSO (L = 3 Mbit, q = 5 kbit, h = 1 s) và sự tương ứng với tọa độ BS."
)

# ===========================================================================
# PAGE 8: FULL 21 WAYPOINTS TABLE ON ONE SINGLE PAGE
# ===========================================================================
story.append(PageBreak())
h2("5.4. Bảng liệt kê đầy đủ 21 tọa độ Waypoints (X_n; Y_n) và bước tiến ΔY_n của V10B tại 3 Seed")
add("Bảng 10 liệt kê tường minh tọa độ 21 waypoints <b>(X<sub>n</sub>; Y<sub>n</sub>)</b> và bước tiến <b>ΔY<sub>n</sub> = Y<sub>n</sub> - Y<sub>n+1</sub></b> của V10B (Full PSO và IPSO) trên cả 3 seed tại L = 3 Mbit/user, q = 5 kbit/user/slot, hover = 1 s để kiểm chứng trực tiếp từng đoạn bò 1,0 m:")

wp_rows = []
for w_idx in range(21):
    row_c = [f"<b>WP {w_idx+1}</b>" + (" (Đích)" if w_idx == 20 else f" (Slot {w_idx+1})")]
    for seed in SEEDS:
        for a in ["Full PSO", "Full IPSO"]:
            r = pick("B", a, L=3e6, q=5000, h=1, seed=seed)[0]
            xx = r["xTraj"][w_idx]
            yy = r["yTraj"][w_idx]
            if w_idx < 20:
                dy = r["yTraj"][w_idx] - r["yTraj"][w_idx + 1]
                dy_str = f"<b>{fmt(dy,1)}</b>" if dy <= 1.05 else fmt(dy, 1)
                cell_str = f"({fmt(xx,1)}; {fmt(yy,1)}) | ΔY={dy_str}"
            else:
                cell_str = f"({fmt(xx,1)}; {fmt(yy,1)}) | —"
            row_c.append(cell_str)
    wp_rows.append(row_c)

add_table(
    ["Waypoint / Slot",
     "Seed 2026 · Full PSO\n(X; Y) | ΔY (m)", "Seed 2026 · IPSO\n(X; Y) | ΔY (m)",
     "Seed 608060 · Full PSO\n(X; Y) | ΔY (m)", "Seed 608060 · IPSO\n(X; Y) | ΔY (m)",
     "Seed 3486784401 · PSO\n(X; Y) | ΔY (m)", "Seed 3486784401 · IPSO\n(X; Y) | ΔY (m)"],
    wp_rows,
    [60, (WIDTH-60)/6, (WIDTH-60)/6, (WIDTH-60)/6, (WIDTH-60)/6, (WIDTH-60)/6, (WIDTH-60)/6],
    small=True, pad=3.0,
    notes="Bảng 10. Toàn bộ 21 tọa độ waypoint (X_n; Y_n) và bước tiến ΔY_n (m) của V10B tại L = 3 Mbit, q = 5 kbit, hover = 1 s. Các giá trị ΔY in đậm (1,0 m) đánh dấu những chặng bị chạm cận dưới minYProgress = 1 m (hiện tượng 1 m corridor)."
)

# ===========================================================================
# PAGE 9: ALL 60 BS COORDINATES AT L=3 MBIT + CONCLUSIONS ON ONE SINGLE PAGE
# ===========================================================================
story.append(PageBreak())
h2("5.5. Liệt kê toàn bộ tọa độ BS trên mọi cấu hình (q, hover) tại L = 3 Mbit/user")
add("Mở rộng ra toàn bộ 5 tổ hợp (q, hover) đã chạy tại L = 3 Mbit/user (gồm 2 biến thể A/B × 3 seed × 5 tổ hợp × 2 thuật toán Full = <b>60 nghiệm tối ưu BS</b>, trong đó có 59 nghiệm khả thi), Hình 6 và Bảng 11 tổng hợp phân bố không gian và tọa độ chi tiết của 3 BS:")

add_fig("bs_distribution_L3.png", width=WIDTH * 0.88)
caption("Hình 6. Phân bố tọa độ 3 BS trên toàn bộ 60 nghiệm Full PSO / IPSO tại L = 3 Mbit/user. BS1 và BS3 hội tụ sát mép trái hộp tìm kiếm (X = 250 m, đạt 59/60 và 60/60 nghiệm), còn BS2 hội tụ sát mép phải hộp tìm kiếm (X = 50 m, đạt 51/60 nghiệm) để tiến gần hành lang UAV nhất.")

all_bs_rows = []
for seed in SEEDS:
    for q_v, h_v in [(0, 1), (5000, 1), (10000, 1), (5000, 2), (5000, 3)]:
        for a, a_short in [("Full PSO", "PSO"), ("Full IPSO", "IPSO")]:
            ra = pick("A", a, L=3e6, q=q_v, h=h_v, seed=seed)[0]
            rb = pick("B", a, L=3e6, q=q_v, h=h_v, seed=seed)[0]
            bs_a = [f"({fmt(ra['xBS'][j],1)}; {fmt(ra['yBS'][j],1)})" for j in range(3)]
            bs_b = [f"({fmt(rb['xBS'][j],1)}; {fmt(rb['yBS'][j],1)})" for j in range(3)]
            dy_b = -np.diff(rb["yTraj"])
            n1_b = int(np.sum(dy_b <= 1.05))
            all_bs_rows.append([
                str(seed), f"q={int(q_v/1000)}k, h={h_v}s", a_short,
                bs_a[0], bs_a[1], bs_a[2] + ("" if ra["feasible"] else "*"),
                bs_b[0], bs_b[1], bs_b[2],
                f"<b>{n1_b}/20</b>"
            ])

add_table(
    ["Seed", "Bộ (q, h)", "Giải",
     "V10A: BS1 (x;y)", "V10A: BS2 (x;y)", "V10A: BS3 (x;y)",
     "V10B: BS1 (x;y)", "V10B: BS2 (x;y)", "V10B: BS3 (x;y)",
     "B: Đoạn 1m"],
    all_bs_rows,
    [52, 52, 30, 55, 55, 55, 55, 55, 55, WIDTH - 464],
    small=True, pad=1.15, split=[11, 21],
    notes="Bảng 11. Toàn bộ 60 bộ tọa độ ngang (x; y) của BS1 (Z=20m), BS2 (Z=30m), BS3 (Z=25m) ở mọi cấu hình L = 3 Mbit/user, kèm số đoạn bò ΔY ~ 1 m trên quỹ đạo V10B tương ứng. Ở 49/59 nghiệm khả thi (và 12/12 nghiệm tại q=5k, h=1s), BS3 nằm tại đúng góc (250,0; 50,0; 25) m."
)

h2("5.6. Kết luận tổng hợp")
bullet("<b>Khác biệt V10A vs V10B và bài toán đánh đổi:</b> Giải phóng tọa độ Y trong V10B giúp IPSO tăng EE trung bình <b>+55,79%</b> (từ 6.452,96 lên 9.956,75 bit/J) và rút ngắn 16,84% đường bay, nhưng làm giảm chỉ số công bằng Jain từ 0,749 xuống 0,569 do ưu tiên dồn dữ liệu cho user có kênh thuận lợi.")
bullet("<b>Bản chất hiện tượng '1 m Corridor':</b> Hiện tượng UAV đi 11-18 bước dài đúng 1,0 m dọc biên X = 75 m hoặc X = 225 m là hệ quả trực tiếp của việc (i) 3 BS co sát về biên trong X = 50 m và X = 250 m (cách hành lang UAV 25 m) tạo ra vùng thu hoạch năng lượng cực đại xung quanh tung độ y<sub>BS</sub>, kết hợp với (ii) ràng buộc cứng ΔY &gt;= 1 m của V10B không cho phép UAV đứng yên (stay). Đây chính là tiền đề trực tiếp để phát triển lên <b>V10C</b> (cho phép stay ΔY &gt;= 0 và tối ưu thời gian hover biến thiên tại từng điểm dừng).")

def draw_header_footer(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(NAVY)
    canvas.setFont("Body-Bold", 7.8)
    canvas.drawString(MARGIN_X, PAGE_H - 26, "BÁO CÁO PHÂN TÍCH V10A & V10B: MÔ HÌNH DRONES, EE, QUỸ ĐẠO UAV & 1M CORRIDOR")
    canvas.setFont("Body", 7.8)
    canvas.setFillColor(MUTED)
    canvas.drawRightString(PAGE_W - MARGIN_X, PAGE_H - 26, "Dự án EE-UAV-SWIPT-NOMA-PSO")
    canvas.setStrokeColor(BORDER_COL)
    canvas.setLineWidth(0.6)
    canvas.line(MARGIN_X, PAGE_H - 31, PAGE_W - MARGIN_X, PAGE_H - 31)
    canvas.line(MARGIN_X, 32, PAGE_W - MARGIN_X, 32)
    canvas.drawString(MARGIN_X, 20, "Nguồn dữ liệu: Campaign 54 runs (168 kết quả độc nhất sau loại trùng) · Seeds: 2026, 608060, 3486784401")
    canvas.drawRightString(PAGE_W - MARGIN_X, 20, f"Trang {doc.page}")
    canvas.restoreState()

doc = SimpleDocTemplate(
    str(OUT_PDF),
    pagesize=A4,
    leftMargin=MARGIN_X,
    rightMargin=MARGIN_X,
    topMargin=38,
    bottomMargin=36,
    title="Báo cáo phân tích V10A và V10B: EE, Quỹ đạo UAV, Tọa độ BS và Hiện tượng 1m Corridor",
    author="Antigravity AI Assistant",
    subject="V10A, V10B, Drones Energy Model, EE vs L/q, UAV Trajectory, BS Coordinates, 1m Corridor",
)
doc.build(story, onFirstPage=draw_header_footer, onLaterPages=draw_header_footer)
print(f"Successfully generated: {OUT_PDF} ({OUT_PDF.stat().st_size} bytes)")
