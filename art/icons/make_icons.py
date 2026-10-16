# Иконки новых расходников, капсул и баффов Zombie Swarm Simulator.
# Пишет SVG 256x256 в svg/, render.js рендерит их в png/ (Chromium, Playwright).
import os
OUT = os.path.join(os.path.dirname(__file__), "svg")
os.makedirs(OUT, exist_ok=True)
INK = "#16181d"

def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(v))) for v in c)

def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def lt(c, t=0.45):
    return hexc(mix(c, (255, 255, 255), t))

def dk(c, t=0.45):
    return hexc(mix(c, (0, 0, 0), t))

class Icon:
    def __init__(self, name, glow):
        self.name, self.defs, self.body, self.n = name, [], [], 0
        g = self.grad("r", [(0, lt(glow, 0.2), 0.75), (0.6, hexc(glow), 0.28), (1, hexc(glow), 0)], cx=0.5, cy=0.5, r=0.5)
        self.body.append(f'<circle cx="128" cy="132" r="118" fill="url(#{g})"/>')

    def grad(self, kind, stops, x1=0, y1=0, x2=0, y2=1, cx=0.35, cy=0.3, r=0.75):
        self.n += 1
        gid = f"g{self.n}"
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in [(s + (1,))[:3] for s in stops])
        if kind == "l":
            self.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        else:
            self.defs.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{st}</radialGradient>')
        return gid

    def shade(self, c, vertical=False):
        # объёмная заливка: светлый блик сверху-слева, тень снизу-справа
        if vertical:
            return "url(#%s)" % self.grad("l", [(0, lt(c, 0.35)), (0.5, hexc(c)), (1, dk(c, 0.45))], x1=0, y1=0, x2=1, y2=0)
        return "url(#%s)" % self.grad("r", [(0, lt(c, 0.55)), (0.45, hexc(c)), (1, dk(c, 0.5))])

    def add(self, s):
        self.body.append(s)

    def shine(self, x, y, w, h, rot=-25, op=0.55):
        self.add(f'<ellipse cx="{x}" cy="{y}" rx="{w}" ry="{h}" fill="#fff" opacity="{op}" transform="rotate({rot} {x} {y})"/>')

    def sparkle(self, x, y, s, col="#fff"):
        self.add(f'<path d="M{x} {y-s} Q{x+s*0.18} {y-s*0.18} {x+s} {y} Q{x+s*0.18} {y+s*0.18} {x} {y+s} Q{x-s*0.18} {y+s*0.18} {x-s} {y} Q{x-s*0.18} {y-s*0.18} {x} {y-s}Z" fill="{col}" stroke="{INK}" stroke-width="3"/>')

    def save(self):
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 256 256"><defs>{"".join(self.defs)}</defs>'
               f'<g stroke-linejoin="round" stroke-linecap="round">{"".join(self.body)}</g></svg>')
        open(os.path.join(OUT, self.name + ".svg"), "w").write(svg)

W = 7  # толщина контура

def drone(ic, x, y, s, col):
    # маленький дрон-квадрокоптер — эмблема игры
    for dx in (-1, 1):
        ic.add(f'<line x1="{x}" y1="{y}" x2="{x+dx*34*s}" y2="{y-14*s}" stroke="{INK}" stroke-width="{9*s}"/>')
        ic.add(f'<ellipse cx="{x+dx*34*s}" cy="{y-18*s}" rx="{20*s}" ry="{5*s}" fill="{lt(col,0.5)}" stroke="{INK}" stroke-width="{4*s}"/>')
    ic.add(f'<ellipse cx="{x}" cy="{y}" rx="{22*s}" ry="{15*s}" fill="{ic.shade(col)}" stroke="{INK}" stroke-width="{5*s}"/>')
    ic.add(f'<circle cx="{x}" cy="{y+2*s}" r="{6*s}" fill="#9ff6ff" stroke="{INK}" stroke-width="{3*s}"/>')

def can(ic, c1, c2):
    ic.add(f'<path d="M150 70 L196 40" stroke="{INK}" stroke-width="18"/><path d="M150 70 L196 40" stroke="#c9ccd2" stroke-width="8"/>')
    ic.add(f'<circle cx="200" cy="37" r="9" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="70" y="80" width="116" height="140" rx="24" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="96" y="58" width="64" height="28" rx="8" fill="#5a5e66" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="70" y="126" width="116" height="44" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    drone(ic, 128, 150, 0.6, c1)
    ic.shine(92, 104, 9, 22, 0)

def spray(ic, c1, c2):
    for i, (x, y, r) in enumerate([(176, 62, 12), (200, 84, 9), (192, 44, 7), (214, 60, 6)]):
        ic.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{hexc(c1)}" stroke="{INK}" stroke-width="3" opacity="0.9"/>')
    ic.add(f'<rect x="84" y="86" width="84" height="146" rx="18" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M84 104 Q126 64 168 104 Z" fill="{lt(c1,0.2)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="114" y="56" width="26" height="26" rx="5" fill="#eceef2" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="138" y="62" width="18" height="10" rx="3" fill="#30333a" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<rect x="84" y="150" width="84" height="40" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.sparkle(126, 170, 13, lt(c1, 0.3))
    ic.shine(100, 120, 7, 22, 0)

def syringe(ic, c1, c2):
    ic.add('<g transform="rotate(40 128 128)">')
    ic.add(f'<rect x="120" y="196" width="16" height="44" rx="4" fill="#d9dde4" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="96" y="64" width="64" height="136" rx="16" fill="#e8f2ff" fill-opacity="0.85" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="104" y="112" width="48" height="80" rx="10" fill="{ic.shade(c1, True)}"/>')
    for yy in (90, 112, 134, 156):
        ic.add(f'<line x1="140" y1="{yy}" x2="152" y2="{yy}" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<rect x="78" y="52" width="100" height="18" rx="7" fill="#3a3e47" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="120" y="20" width="16" height="34" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="100" y="10" width="56" height="16" rx="6" fill="{hexc(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.shine(110, 100, 5, 18, 0)
    ic.add('</g>')

def flare(ic, c1, c2):
    ic.add(f'<path d="M128 70 C100 40 116 18 128 8 C140 18 156 40 128 70Z" fill="{lt(c2,0.2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<path d="M128 64 C116 46 122 34 128 26 C134 34 140 46 128 64Z" fill="#fff8d0"/>')
    ic.add(f'<rect x="100" y="66" width="56" height="168" rx="14" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    for yy in (100, 186):
        ic.add(f'<rect x="100" y="{yy}" width="56" height="16" fill="#f2f2f2" stroke="{INK}" stroke-width="5"/>')
    ic.shine(114, 140, 6, 26, 0)
    for x, y in ((70, 60), (186, 70), (178, 30)):
        ic.sparkle(x, y, 11, lt(c2, 0.3))

def device(ic, c1, c2):
    ic.add(f'<line x1="170" y1="58" x2="186" y2="20" stroke="{INK}" stroke-width="10"/><circle cx="187" cy="18" r="10" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="64" y="56" width="128" height="176" rx="24" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="82" y="76" width="92" height="74" rx="12" fill="{dk(c2,0.55)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="88" y="82" width="80" height="62" rx="9" fill="url(#{ic.grad("l", [(0, lt(c2,0.4)), (1, hexc(c2))])})"/>')
    drone(ic, 128, 118, 0.55, c2)
    for i, x in enumerate((92, 128, 164)):
        col = hexc(c2) if i == 1 else "#e6e8ec"
        ic.add(f'<circle cx="{x}" cy="190" r="13" fill="{col}" stroke="{INK}" stroke-width="5"/>')
    ic.shine(86, 70, 14, 6, 0, 0.4)

def crate(ic, c1, c2):
    ic.add(f'<path d="M50 100 L128 66 L206 100 L206 196 L128 232 L50 196Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M50 100 L128 134 L206 100 M128 134 L128 232" fill="none" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M128 134 L206 100 L206 196 L128 232Z" fill="#000" opacity="0.18"/>')
    for d in ("M64 118 L114 140 L114 160 L64 138Z", "M64 158 L114 180 L114 200 L64 178Z"):
        ic.add(f'<path d="{d}" fill="{hexc(c2)}" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<path d="M144 150 L190 130 L190 170 L144 190Z" fill="#ffd54a" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<path d="M167 140 L160 162 L170 162 L164 182" fill="none" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<path d="M128 66 L128 40" stroke="{INK}" stroke-width="7"/><circle cx="128" cy="36" r="11" fill="#ff4a30" stroke="{INK}" stroke-width="5"/>')
    ic.sparkle(150, 26, 10, "#ffe27a")

def nut(ic, c1, c2):
    import math
    pts = " ".join(f"{128+92*math.cos(math.radians(30+60*i)):.1f},{132+92*math.sin(math.radians(30+60*i)):.1f}" for i in range(6))
    ic.add(f'<polygon points="{pts}" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<circle cx="128" cy="132" r="40" fill="{dk(c1,0.55)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M128 112 C122 98 104 100 104 116 C104 126 116 134 128 146 C140 134 152 126 152 116 C152 100 134 98 128 112Z" transform="translate(0 6) scale(1)" fill="{hexc(c2)}" stroke="{INK}" stroke-width="4"/>')
    ic.shine(90, 78, 22, 9, -30)
    ic.sparkle(200, 52, 14)

def box(ic, c1, c2):
    ic.add(f'<path d="M96 84 Q96 52 128 52 Q160 52 160 84" fill="none" stroke="{INK}" stroke-width="14"/><path d="M96 84 Q96 52 128 52 Q160 52 160 84" fill="none" stroke="#666b74" stroke-width="6"/>')
    ic.add(f'<rect x="48" y="84" width="160" height="140" rx="16" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="44" y="80" width="168" height="34" rx="10" fill="{hexc(c2)}" stroke="{INK}" stroke-width="{W}"/>')
    for (x, y) in ((88, 160), (168, 160)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="9" fill="{dk(c1,0.6)}" stroke="{INK}" stroke-width="3"/>')
    drone(ic, 128, 172, 0.65, c2)
    ic.shine(70, 136, 7, 18, 0, 0.4)

def tube(ic, c1, c2):
    ic.add('<g transform="rotate(-30 128 128)">')
    ic.add(f'<path d="M84 210 L172 210 L162 70 Q128 58 94 70Z" fill="{ic.shade(c2, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="78" y="202" width="100" height="22" rx="4" fill="{lt(c2,0.2)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="108" y="36" width="40" height="34" rx="8" fill="{hexc(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M104 110 L152 110 L148 170 L108 170Z" fill="{hexc(c1)}" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<path d="M116 124 L116 150 Q128 162 140 150 L140 124" fill="none" stroke="#fff" stroke-width="8"/>')
    ic.add('</g>')
    ic.add(f'<path d="M70 70 Q66 90 74 96 Q84 98 82 82Z" fill="{hexc(c1)}" stroke="{INK}" stroke-width="4"/>')

def vial(ic, c1, c2):
    ic.add(f'<circle cx="128" cy="160" r="72" fill="#e9f4ff" fill-opacity="0.85" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M62 168 A66 66 0 0 0 194 168 Q160 150 128 166 Q96 182 62 168Z" fill="{ic.shade(c1)}"/>')
    ic.add(f'<rect x="104" y="44" width="48" height="58" fill="#e9f4ff" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="96" y="22" width="64" height="30" rx="8" fill="{hexc(c2)}" stroke="{INK}" stroke-width="{W}"/>')
    for (x, y, r) in ((110, 180, 8), (146, 196, 6), (132, 150, 5)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity="0.6"/>')
    ic.shine(92, 128, 9, 24, 30, 0.7)

def jar(ic, c1, c2):
    ic.add(f'<rect x="58" y="74" width="140" height="156" rx="30" fill="#e9f4ff" fill-opacity="0.85" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="66" y="112" width="124" height="110" rx="24" fill="{ic.shade(c1)}"/>')
    ic.add(f'<rect x="48" y="44" width="160" height="38" rx="10" fill="{ic.shade(c2, True)}" stroke="{INK}" stroke-width="{W}"/>')
    for (x, y, r) in ((96, 150, 13), (150, 180, 10), (126, 200, 8), (160, 140, 7)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{lt(c1,0.6)}" stroke="{INK}" stroke-width="3"/>')
        ic.add(f'<circle cx="{x-r*0.3}" cy="{y-r*0.3}" r="{r*0.3}" fill="#fff"/>')
    ic.shine(80, 120, 7, 26, 0, 0.6)

def cup(ic, c1, c2):
    ic.add(f'<path d="M160 120 L196 20" stroke="{INK}" stroke-width="16"/><path d="M160 120 L196 20" stroke="{hexc(c2)}" stroke-width="7"/>')
    ic.add(f'<path d="M62 74 L194 74 L176 228 L80 228Z" fill="#e9f4ff" fill-opacity="0.85" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M68 112 L188 112 L176 222 L80 222Z" fill="url(#{ic.grad("l", [(0, lt(c1,0.25)), (0.6, hexc(c1)), (1, hexc(c2))])})"/>')
    ic.add(f'<path d="M68 112 L188 112" stroke="{INK}" stroke-width="4"/>')
    ic.add(f'<circle cx="86" cy="76" r="24" fill="#ff4c5c" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<path d="M84 52 Q92 40 104 42" fill="none" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<path d="M150 64 Q178 46 196 70 Z" fill="#7fe07a" stroke="{INK}" stroke-width="5"/>')
    ic.shine(90, 160, 7, 30, 6, 0.6)

def seed(ic, c1, c2):
    ic.add(f'<path d="M128 60 C122 40 132 26 146 22" fill="none" stroke="{INK}" stroke-width="12"/><path d="M128 60 C122 40 132 26 146 22" fill="none" stroke="#66c845" stroke-width="5"/>')
    ic.add(f'<path d="M140 30 Q176 10 196 34 Q170 50 140 30Z" fill="#7fe07a" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<ellipse cx="128" cy="146" rx="70" ry="88" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    for d in ("M96 96 Q112 146 96 200", "M128 66 Q140 146 128 230", "M160 96 Q146 146 160 200"):
        ic.add(f'<path d="{d}" fill="none" stroke="{hexc(c2)}" stroke-width="7"/>')
    ic.shine(102, 104, 12, 24, 20, 0.5)
    ic.sparkle(206, 120, 13, lt(c2, 0.3))
    ic.sparkle(48, 180, 10, lt(c2, 0.3))

def capsule(ic, c1, c2):
    ic.add('<g transform="rotate(-35 128 128)">')
    ic.add(f'<rect x="72" y="28" width="112" height="200" rx="56" fill="#e9f4ff" fill-opacity="0.85" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M72 128 L184 128 L184 172 A56 56 0 0 1 72 172Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="66" y="118" width="124" height="20" rx="6" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add('</g>')
    drone(ic, 112, 106, 0.75, c1)
    ic.shine(150, 70, 8, 22, -35, 0.6)

def buff_drone_gear(ic, c1, c2):
    drone(ic, 128, 120, 1.6, c1)
    for x, y in ((70, 190), (128, 210), (186, 190)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="14" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')

def buff_recycle(ic, c1, c2):
    import math
    for i in range(3):
        a = i * 120
        ic.add(f'<g transform="rotate({a} 128 132)"><path d="M128 52 A80 80 0 0 1 200 104" fill="none" stroke="{INK}" stroke-width="30"/>'
               f'<path d="M128 52 A80 80 0 0 1 200 104" fill="none" stroke="{hexc(c1)}" stroke-width="18"/>'
               f'<path d="M214 86 L206 128 L172 106Z" fill="{hexc(c1)}" stroke="{INK}" stroke-width="5"/></g>')
    ic.add(f'<circle cx="128" cy="132" r="30" fill="{ic.shade(c2)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M132 112 L118 136 L130 136 L124 154 L140 128 L128 128Z" fill="#fff" stroke="{INK}" stroke-width="3"/>')

def buff_crosshair(ic, c1, c2):
    ic.add(f'<circle cx="128" cy="128" r="84" fill="none" stroke="{INK}" stroke-width="26"/><circle cx="128" cy="128" r="84" fill="none" stroke="{hexc(c1)}" stroke-width="14"/>')
    ic.add(f'<circle cx="128" cy="128" r="42" fill="none" stroke="{INK}" stroke-width="22"/><circle cx="128" cy="128" r="42" fill="none" stroke="{lt(c1,0.3)}" stroke-width="10"/>')
    for a in (0, 90, 180, 270):
        ic.add(f'<g transform="rotate({a} 128 128)"><rect x="118" y="18" width="20" height="54" rx="6" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/></g>')
    ic.add(f'<circle cx="128" cy="128" r="12" fill="#fff" stroke="{INK}" stroke-width="5"/>')

def buff_turbo(ic, c1, c2):
    for y, l in ((96, 70), (128, 90), (160, 62)):
        ic.add(f'<line x1="{36}" y1="{y}" x2="{36+l}" y2="{y}" stroke="{INK}" stroke-width="16"/><line x1="{36}" y1="{y}" x2="{36+l}" y2="{y}" stroke="{hexc(c2)}" stroke-width="7"/>')
    drone(ic, 158, 134, 1.35, c1)

C = lambda *a: a
ITEMS = [
    # name, kind, glow, c1, c2
    ("lube", can, C(240, 200, 70), C(70, 120, 60), C(240, 200, 70)),
    ("beacon", device, C(80, 200, 255), C(70, 76, 90), C(80, 200, 255)),
    ("stim", syringe, C(255, 80, 60), C(255, 70, 50), C(230, 235, 245)),
    ("goldpaint", spray, C(255, 205, 50), C(255, 200, 40), C(40, 40, 45)),
    ("flare", flare, C(255, 100, 50), C(230, 50, 40), C(255, 220, 120)),
    ("microconv", device, C(130, 255, 120), C(100, 106, 118), C(130, 255, 120)),
    ("scrapbomb", crate, C(255, 160, 50), C(150, 110, 65), C(255, 170, 40)),
    ("luckycoin", nut, C(120, 240, 90), C(255, 215, 70), C(110, 240, 90)),
    ("candybars", box, C(255, 140, 210), C(255, 120, 200), C(120, 220, 255)),
    ("botbox", box, C(80, 255, 140), C(80, 92, 80), C(80, 255, 140)),
    ("magglue", tube, C(120, 160, 255), C(120, 160, 255), C(220, 230, 255)),
    ("rageextract", vial, C(255, 60, 60), C(255, 50, 60), C(120, 40, 30)),
    ("gatherextract", vial, C(70, 150, 255), C(60, 140, 255), C(120, 80, 40)),
    ("enzymes", jar, C(150, 255, 90), C(150, 255, 90), C(90, 100, 80)),
    ("motoroil", can, C(255, 150, 40), C(40, 40, 46), C(255, 140, 30)),
    ("cocktail", cup, C(255, 180, 70), C(255, 170, 60), C(90, 230, 120)),
    ("nanocloud", vial, C(200, 225, 255), C(210, 228, 255), C(140, 170, 210)),
    ("mutantseed", seed, C(255, 210, 60), C(150, 60, 200), C(255, 210, 60)),
    ("mutagen", vial, C(180, 80, 255), C(170, 60, 255), C(90, 40, 110)),
    ("supershake", cup, C(255, 120, 200), C(255, 70, 110), C(70, 255, 230)),
    ("capsule", capsule, C(175, 70, 255), C(175, 70, 255), C(220, 225, 235)),
    ("goldcapsule", capsule, C(255, 205, 35), C(255, 200, 40), C(255, 240, 180)),
    ("starcapsule", capsule, C(120, 220, 255), C(255, 120, 220), C(255, 255, 255)),
    ("buff_dgather", buff_drone_gear, C(240, 200, 70), C(240, 200, 70), C(255, 160, 60)),
    ("buff_convb", buff_recycle, C(150, 255, 90), C(150, 255, 90), C(255, 200, 60)),
    ("buff_crit", buff_crosshair, C(255, 110, 70), C(255, 110, 70), C(255, 230, 90)),
    ("buff_dspeed", buff_turbo, C(255, 150, 40), C(255, 150, 40), C(255, 230, 120)),
]
for name, fn, glow, c1, c2 in ITEMS:
    ic = Icon(name, glow)
    fn(ic, c1, c2)
    if name == "starcapsule":
        for x, y, s in ((200, 50, 16), (54, 200, 12), (212, 186, 10)):
            ic.sparkle(x, y, s, "#fff5b0")
    ic.save()
print(len(ITEMS), "svg")
