"""Draw the specialty range figure for the README.

One row per main-comparison specialty: the dot is the observed new-patient
share, the line is the Scenario D suppression range. Color and marker shape
show which robust-comparison group the specialty is in.

Reads the dbt marts, so run `dbt build` first. Run from the repo root:
    python scripts/make_figure.py
"""

from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "medicare.duckdb"
OUT_DIR = ROOT / "figures"

QUERY = """
with sides as (
    select specialty_a as specialty, ordering_d = 'a_higher' as is_higher, ordering_d = 'b_higher' as is_lower
    from fct_specialty_pairs
    union all
    select specialty_b, ordering_d = 'b_higher', ordering_d = 'a_higher'
    from fct_specialty_pairs
),

groups as (
    select
        specialty,
        case
            when bool_or(is_higher) then 'higher'
            when bool_or(is_lower)  then 'lower'
            else 'neither'
        end as robust_group
    from sides
    group by specialty
)

select
    b.provider_type,
    100 * b.observed_share as observed,
    100 * b.lower_d        as lower_d,
    100 * b.upper_d        as upper_d,
    g.robust_group
from fct_specialty_bounds as b
inner join groups as g
    on b.provider_type = g.specialty
where b.scope_group = 'main'
order by b.observed_share
"""

# Colors from a validated categorical palette (slots 1 and 2); "neither" is muted gray.
THEMES = {
    "light": {
        "surface": "#fcfcfb", "ink": "#0b0b0b", "ink2": "#52514e", "muted": "#898781",
        "grid": "#e1e0d9", "higher": "#2a78d6", "lower": "#eb6834", "neither": "#898781",
    },
    "dark": {
        "surface": "#1a1a19", "ink": "#f0efec", "ink2": "#c3c2b7", "muted": "#898781",
        "grid": "#2c2c2a", "higher": "#3987e5", "lower": "#d95926", "neither": "#898781",
    },
}

# Shape is a second channel, so group identity never depends on color alone.
MARKERS = {"higher": "o", "lower": "s", "neither": "o"}
LABELS = {
    "higher": "Higher group: robustly above at least one specialty",
    "lower": "Lower group: robustly below at least one specialty",
    "neither": "In no robust pair",
}


def draw(rows, theme_name):
    t = THEMES[theme_name]
    fig, ax = plt.subplots(figsize=(9, 14), dpi=150)
    fig.patch.set_facecolor(t["surface"])
    ax.set_facecolor(t["surface"])

    for y, (name, obs, lo, hi, grp) in enumerate(rows):
        color = t[grp]
        ax.plot([lo, hi], [y, y], color=color, linewidth=2, solid_capstyle="round", zorder=2)
        hollow = grp == "neither"
        ax.plot(
            obs, y, marker=MARKERS[grp], markersize=6,
            markerfacecolor=t["surface"] if hollow else color,
            markeredgecolor=color if hollow else t["surface"],
            markeredgewidth=1.5 if hollow else 1, zorder=3,
        )

    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels([r[0] for r in rows], fontsize=8, color=t["ink2"])
    ax.set_ylim(-0.8, len(rows) - 0.2)
    ax.set_xlim(0, 60)
    ax.set_xticks(range(0, 61, 10))
    ax.set_xticklabels([f"{x}%" for x in range(0, 61, 10)], fontsize=8, color=t["muted"])
    ax.xaxis.set_ticks_position("top")
    ax.grid(axis="x", color=t["grid"], linewidth=0.6, zorder=0)
    ax.tick_params(axis="both", length=0)
    for spine in ax.spines.values():
        spine.set_visible(False)

    fig.text(
        0.02, 0.985, "New-patient share of office E/M services, by specialty",
        fontsize=13, fontweight="bold", color=t["ink"], ha="left", va="top",
    )
    fig.text(
        0.02, 0.968,
        "Medicare fee-for-service, 2024. Dot: observed share. Line: range if hidden rows are filled in (Scenario D).",
        fontsize=8.5, color=t["ink2"], ha="left", va="top",
    )

    handles = [
        Line2D([0], [0], color=t[g], linewidth=2, marker=MARKERS[g], markersize=6,
               markerfacecolor=t["surface"] if g == "neither" else t[g],
               markeredgecolor=t[g], label=LABELS[g])
        for g in ("higher", "lower", "neither")
    ]
    legend = fig.legend(
        handles=handles, loc="upper left", bbox_to_anchor=(0.015, 0.958),
        frameon=False, fontsize=8, ncol=1, handlelength=2.2,
    )
    for text in legend.get_texts():
        text.set_color(t["ink2"])

    fig.text(
        0.02, 0.008,
        "66 specialties, 400,495 providers. Source: CMS Medicare Physician & Other Practitioners. "
        "Sorted by observed share.",
        fontsize=7, color=t["muted"], ha="left", va="bottom",
    )

    fig.subplots_adjust(left=0.36, right=0.97, top=0.885, bottom=0.025)
    out = OUT_DIR / f"specialty_ranges_{theme_name}.png"
    fig.savefig(out, facecolor=t["surface"])
    plt.close(fig)
    print(f"Wrote {out.relative_to(ROOT)}")


def main() -> None:
    con = duckdb.connect(str(DB_PATH), read_only=True)
    rows = con.sql(QUERY).fetchall()
    con.close()
    if len(rows) != 66:
        raise SystemExit(f"Expected 66 specialties, got {len(rows)}. Run dbt build first.")

    OUT_DIR.mkdir(exist_ok=True)
    for theme_name in THEMES:
        draw(rows, theme_name)


if __name__ == "__main__":
    main()