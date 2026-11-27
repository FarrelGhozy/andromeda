"""Generate proposal figures (PNG) with matplotlib - fixed layout v2."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon
import os

OUT = os.path.expanduser("~/andromeda-semnas-proposal/figures")
os.makedirs(OUT, exist_ok=True)

NAVY, TEAL, ORANGE, GREEN, PURPLE, GREY, RED, BLUE = (
    "#1F3A5F", "#0E7C7B", "#E8862E", "#2E7D32", "#6A4C93",
    "#5D6D7E", "#C0392B", "#2471A3")


def layer(ax, x, y, w, h, title, color, bg):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.6",
                                fc=bg, ec=color, lw=2))
    ax.text(x + 2, y + h - 1.5, title, fontsize=11, fontweight="bold",
            color=color, va="top", ha="left")


def node(ax, x, y, w, h, text, ec=NAVY, fc="white", fs=8.5):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.4",
                                fc=fc, ec=ec, lw=1.6))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
            fontsize=fs, color="#1a1a1a")


def varr(ax, x, y1, y2, label=None, color="#333333", lx=1.6, fs=7.5):
    """Vertical arrow from y1 to y2 at x. Label placed beside midpoint."""
    ax.add_patch(FancyArrowPatch((x, y1), (x, y2), arrowstyle="-|>",
                                 mutation_scale=13, lw=1.5, color=color))
    if label:
        ax.text(x + lx, (y1 + y2) / 2, label, fontsize=fs, color=color,
                style="italic", va="center")


def harr(ax, x1, x2, y, color="#333333"):
    ax.add_patch(FancyArrowPatch((x1, y), (x2, y), arrowstyle="-|>",
                                 mutation_scale=13, lw=1.5, color=color))


# ================= FIG 1: ARSITEKTUR SISTEM =================
fig, ax = plt.subplots(figsize=(12, 8))
ax.set_xlim(0, 100)
ax.set_ylim(0, 100)
ax.axis("off")
ax.set_title("Arsitektur Sistem ANDROMEDA (1 ESP32 - 6 Zona)", fontsize=14,
             fontweight="bold", pad=10)

# Power layer: outer 73-96, header baseline ~94, nodes 77-86
layer(ax, 2, 73, 96, 23, "LAPIS DAYA (off-grid)", ORANGE, "#FEF3E6")
node(ax, 5, 77, 17, 9, "Surya\n300Wp", ec=ORANGE)
node(ax, 25, 77, 13, 9, "SCC\n20A", ec=ORANGE)
node(ax, 41, 77, 15, 9, "Aki 100Ah\n12V", ec=ORANGE)
node(ax, 59, 81, 36, 5, "Step-down 5V  ->  ESP32 + relay", ec=ORANGE, fs=7.5)
node(ax, 59, 75.5, 36, 5, "12V langsung  ->  valve + router", ec=ORANGE, fs=7.5)
harr(ax, 22, 25, 81.5, ORANGE)
harr(ax, 38, 41, 81.5, ORANGE)
harr(ax, 56, 59, 81.5, ORANGE)

# Edge layer: outer 47-69, header ~67, nodes 51-60
layer(ax, 2, 47, 96, 22,
      "LAPIS EDGE - ESP32-01 (baca tiap 30 mnt, heartbeat 60 dtk)",
      BLUE, "#EAF2FB")
node(ax, 5, 51, 24, 9, "6x Sensor kapasitif\nGPIO 32,33,34,35,36,39", ec=BLUE)
node(ax, 38, 51, 24, 9, "ESP32 DevKit\n1 node, 6 zona", ec=BLUE, fc="#D6EAF8")
node(ax, 71, 51, 24, 9, "6x Relay -> Solenoid\n12V NC (fail-safe)", ec=BLUE)
harr(ax, 29, 38, 55.5, BLUE)
harr(ax, 62, 71, 55.5, BLUE)

# Cloud layer: outer 25-43, header ~41, nodes 28.5-35.5
layer(ax, 2, 25, 96, 18, "LAPIS CLOUD - Supabase (single source of truth)",
      PURPLE, "#F1EAF9")
node(ax, 5, 28.5, 21.5, 7, "devices\n(last_seen)", ec=PURPLE, fs=8)
node(ax, 28.5, 28.5, 21.5, 7, "sensor_readings\n+ pending_commands",
     ec=PURPLE, fs=7.5)
node(ax, 52, 28.5, 21.5, 7, "system_config\n(mode, threshold)", ec=PURPLE,
     fs=8)
node(ax, 75.5, 28.5, 19.5, 7, "Realtime\nWebSocket", ec=PURPLE, fs=8)

# Mobile layer: outer 2-21, header ~19, nodes 5.5-13.5
layer(ax, 2, 2, 96, 19,
      "LAPIS MOBILE - Flutter Android (offline-first + Open-Meteo)",
      GREEN, "#E8F5E9")
node(ax, 5, 5.5, 29, 8, "Dasbor + kontrol valve\n+ atur threshold", ec=GREEN,
     fs=8)
node(ax, 36.5, 5.5, 29, 8, "Cache snapshot lokal\n+ banner offline", ec=GREEN,
     fs=8)
node(ax, 68, 5.5, 29, 8, "Cuaca 7 hari + saran\nsiram (Open-Meteo)", ec=GREEN,
     fs=8)

# Inter-layer arrows (in the gaps, labels beside the line)
varr(ax, 84, 73, 69.5, "daya", color=ORANGE)            # power -> edge
varr(ax, 16, 47, 43.5, "POST bacaan", color=BLUE)       # edge -> cloud
varr(ax, 50, 43.5, 47, "GET config +\nantrean", color=BLUE, lx=1.6)
varr(ax, 84, 47, 43.5, "heartbeat", color=BLUE)         # edge -> cloud
varr(ax, 30, 25, 21.5, "REST + Realtime", color=PURPLE)  # cloud -> mobile
varr(ax, 65, 21.5, 25, "VALVE_ON / OFF", color=PURPLE)   # mobile -> cloud
plt.tight_layout()
fig.savefig(f"{OUT}/fig1_arsitektur.png", dpi=200)
plt.close(fig)


# ================= FIG 2: FLOWCHART FIRMWARE =================
fig2, ax2 = plt.subplots(figsize=(8.5, 12))
ax2.set_xlim(0, 100)
ax2.set_ylim(0, 112)
ax2.axis("off")
ax2.set_title("Siklus Firmware ESP32-01 per Zona", fontsize=13,
              fontweight="bold", pad=10)

BX = 24  # box left
BW = 52  # box width


def pbox(y, text, h=6, fc="white", ec=NAVY, fs=8.5):
    node(ax2, BX, y, BW, h, text, ec=ec, fc=fc, fs=fs)
    return y, y + h  # bottom, top


def diamond(cy, text, hw=24, hh=6.5, fs=8):
    cx = 50
    ax2.add_patch(Polygon([(cx, cy + hh), (cx + hw, cy),
                           (cx, cy - hh), (cx - hw, cy)],
                          closed=True, fc="#FEF9E7", ec=ORANGE, lw=1.8))
    ax2.text(cx, cy, text, ha="center", va="center", fontsize=fs)
    return cy + hh, cy - hh  # top, bottom


def varr2(x, y1, y2, label=None, color="#333333", lx=2.0):
    ax2.add_patch(FancyArrowPatch((x, y1), (x, y2), arrowstyle="-|>",
                                  mutation_scale=13, lw=1.5, color=color))
    if label:
        ax2.text(x + lx, (y1 + y2) / 2, label, fontsize=8, color=color,
                 fontweight="bold", va="center")


# main chain
# main chain (arrows run from previous BOTTOM border to next TOP border)
b0, t0 = pbox(104, "Mulai / bangun dari tidur")
b1, t1 = pbox(94.5, "Baca ADC 6 kanal + filter")
varr2(50, b0 - 0.3, t1 + 0.3)
b2, t2 = pbox(85, "Konversi ke persen\n(kalibrasi 2700=0%, 1500=100%)")
varr2(50, b1 - 0.3, t2 + 0.3)
b3, t3 = pbox(75.5, "POST sensor_readings\nke Supabase")
varr2(50, b2 - 0.3, t3 + 0.3)
b4, t4 = pbox(66, "GET system_config\n+ pending_commands")
varr2(50, b3 - 0.3, t4 + 0.3)
d1top, d1bot = diamond(57, "Ada perintah\npending?")
varr2(50, b4 - 0.3, d1top + 0.3)
b5, t5 = pbox(41.5, "Eksekusi valve +\ntandai executed", fc="#FDEDEC", ec=RED)
varr2(50, d1bot - 0.3, t5 + 0.3, label="ya", color=GREEN)
d2top, d2bot = diamond(32, "mode = auto?")
varr2(50, b5 - 0.3, d2top + 0.3)
b6, t6 = pbox(16.5, "Logika dual-threshold:\n<30% buka, >70% tutup",
              fc="#EAF2FB", ec=BLUE)
varr2(50, d2bot - 0.3, t6 + 0.3, label="auto", color=GREEN)
b7, t7 = pbox(7, "Heartbeat (update last_seen)\n+ tidur s/d interval",
              fc="#E8F5E9", ec=GREEN)
varr2(50, b6 - 0.3, t7 + 0.3)

# "tidak" bypass on LEFT: diamond1 left vertex -> down -> merge into the
# Eksekusi->mode vertical segment (skips Eksekusi box, no shared vertex)
ax2.plot([26, 10], [57, 57], color=RED, lw=1.5)
ax2.plot([10, 10], [57, 39.8], color=RED, lw=1.5)
ax2.plot([10, 50], [39.8, 39.8], color=RED, lw=1.5)  # join stem, no arrowhead
ax2.text(18, 59.3, "tidak", fontsize=8, color=RED, fontweight="bold",
         ha="center")

# "manual" bypass: diamond2 left vertex -> down -> heartbeat box left edge
ax2.plot([26, 12], [32, 32], color=RED, lw=1.5)
ax2.plot([12, 12], [32, 10], color=RED, lw=1.5)
ax2.add_patch(FancyArrowPatch((12, 10), (24, 10), arrowstyle="-|>",
                              mutation_scale=13, lw=1.5, color=RED))
ax2.text(19, 29.6, "manual", fontsize=8, color=RED, fontweight="bold",
         ha="center")

# loop-back on RIGHT: heartbeat right -> up -> mulai right
ax2.plot([76, 90], [10, 10], color=TEAL, lw=1.5)
ax2.plot([90, 90], [10, 107], color=TEAL, lw=1.5)
ax2.add_patch(FancyArrowPatch((90, 107), (76, 107), arrowstyle="-|>",
                              mutation_scale=13, lw=1.5, color=TEAL))
ax2.text(92.5, 58, "siklus\nberikutnya", fontsize=8, color=TEAL,
         fontweight="bold", ha="center", va="center", rotation=90)
plt.tight_layout()
fig2.savefig(f"{OUT}/fig2_firmware.png", dpi=200)
plt.close(fig2)


# ================= FIG 3: SKEMA DATABASE =================
fig3, ax3 = plt.subplots(figsize=(11.5, 7.2))
ax3.set_xlim(0, 100)
ax3.set_ylim(0, 100)
ax3.axis("off")
ax3.set_title("Skema Data Supabase (4 Tabel)", fontsize=14, fontweight="bold",
              pad=10)


def table(x, top, title, rows, w, step=5.6, fs=9):
    h = 7.5 + len(rows) * step
    y = top - h
    ax3.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.4",
                                 fc="white", ec=PURPLE, lw=2))
    ax3.text(x + w / 2, top - 1.8, title, ha="center", va="top",
             fontsize=11, fontweight="bold", color=PURPLE)
    for i, r in enumerate(rows):
        ax3.text(x + 2, top - 9.5 - i * step, r, ha="left", va="top",
                 fontsize=fs, family="monospace")
    return y, y + h  # bottom, top


d_bot, d_top = table(3, 80, "devices",
                     ["PK device_id petak-01..06", "esp32_id = esp32-01",
                      "sensor_index 0..5", "status active/inactive",
                      "* last_seen (heartbeat)"],
                     w=33)
s_bot, s_top = table(55, 96, "sensor_readings",
                     ["FK device_id", "moisture ADC 100-4000",
                      "percent 0-100, valve ON/OFF", "created_at"],
                     w=41)
p_bot, p_top = table(55, 66, "pending_commands",
                     ["FK device_id", "cmd VALVE_ON / OFF",
                      "status pending/exec/...", "source android / auto"],
                     w=41)
c_bot, c_top = table(55, 36, "system_config",
                     ["FK device_id UNIQUE", "mode auto / manual",
                      "threshold dry 30 wet 70", "dur 30s, interval 1800s"],
                     w=41)

# relation arrows: devices right edge (x=36) -> each table left edge (x=55)
ax3.add_patch(FancyArrowPatch((36, 68), (55, 83), arrowstyle="-|>",
                              mutation_scale=14, lw=1.6, color=PURPLE))
ax3.text(43, 77.5, "1 : N", fontsize=9, color=PURPLE, style="italic",
         ha="center", bbox=dict(fc="white", ec="none", pad=1))
ax3.add_patch(FancyArrowPatch((36, 57), (55, 52), arrowstyle="-|>",
                              mutation_scale=14, lw=1.6, color=PURPLE))
ax3.text(45.5, 56.5, "1 : N", fontsize=9, color=PURPLE, style="italic",
         ha="center", bbox=dict(fc="white", ec="none", pad=1))
ax3.add_patch(FancyArrowPatch((36, 50), (55, 24), arrowstyle="-|>",
                              mutation_scale=14, lw=1.6, color=PURPLE))
ax3.text(43, 35, "1 : 1", fontsize=9, color=PURPLE, style="italic",
         ha="center", bbox=dict(fc="white", ec="none", pad=1))

# trigger note bottom-left + dashed link to devices bottom
ax3.add_patch(FancyBboxPatch((3, 3), 33, 12, boxstyle="round,pad=0.5",
                             fc="#F9F9F9", ec="#BBBBBB", lw=1.2))
ax3.text(19.5, 9, "Trigger touch_device_last_seen +\nRPC heartbeat(esp32_id)",
         ha="center", va="center", fontsize=8.5, style="italic",
         color="#555555")
ax3.plot([19.5, 19.5], [15, 46.5], color="#999999", lw=1.2, ls="--")
ax3.text(4, 92, "PK = primary key   FK = foreign key   UQ = unique",
         ha="left", fontsize=8.5, style="italic", color="#555555")
plt.tight_layout()
fig3.savefig(f"{OUT}/fig3_database.png", dpi=200)
plt.close(fig3)


# ================= FIG 4: HISTEREIS DUAL-THRESHOLD =================
fig4, ax4 = plt.subplots(figsize=(10, 4.8))
t = list(range(25))
moist = [62, 58, 52, 46, 40, 34, 29, 33, 38, 44, 50, 56, 62, 68, 72,
         70, 64, 56, 48, 40, 32, 28, 36, 48, 60]
ax4.axhspan(30, 70, color="grey", alpha=0.10)
# full watering-ON spans: below 30 -> above 70
ax4.axvspan(6, 14, color=TEAL, alpha=0.14)
ax4.axvspan(21, 24, color=TEAL, alpha=0.14)
ax4.plot(t, moist, lw=2.2, color=NAVY, marker="o", markersize=4,
         label="Kelembaban tanah (%)")
ax4.axhline(30, ls="--", color=RED, lw=1.5, label="Ambang kering 30%")
ax4.axhline(70, ls="--", color=BLUE, lw=1.5, label="Ambang basah 70%")
ax4.text(10, 10, "SIRAM (valve ON)", ha="center", fontsize=10,
         fontweight="bold", color=TEAL)
ax4.text(22.5, 10, "SIRAM", ha="center", fontsize=9, fontweight="bold",
         color=TEAL)
ax4.text(10, 42, "naik: valve ON (menahan)", ha="center", fontsize=8,
         style="italic", color="#555555")
ax4.text(17.5, 40, "turun: valve OFF (menahan)", ha="center", fontsize=8,
         style="italic", color="#555555")
# ON/OFF event markers
ax4.scatter([6, 21], [29, 28], s=70, color=RED, zorder=5)
ax4.text(6, 23.5, "ON\n(<30%)", ha="center", fontsize=8, color=RED,
         fontweight="bold")
ax4.scatter([14], [72], s=70, color=BLUE, zorder=5)
ax4.text(14.6, 79, "OFF (>70%)", ha="left", fontsize=8, color=BLUE,
         fontweight="bold")
ax4.set_xlabel("Waktu (siklus baca, 1 siklus = 30 menit)")
ax4.set_ylabel("Kelembaban (%)")
ax4.set_title("Kendali Histeresis Dual-Threshold 30%/70%",
              fontsize=12, fontweight="bold")
ax4.set_xlim(-0.5, 24.5)
ax4.set_ylim(0, 100)
ax4.legend(loc="upper left", fontsize=8)
ax4.grid(alpha=0.3)
plt.tight_layout()
fig4.savefig(f"{OUT}/fig4_threshold.png", dpi=200)
plt.close(fig4)

print("saved:", sorted(os.listdir(OUT)))
