# Иконки донат-магазина Zombie Swarm Simulator (тот же стиль, что у расходников: контур, блик, свечение).
# Пишет SVG в svg_donate/, рендер: node render.js svg_donate png_donate
import os, math
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "make_icons.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(HERE, "make_icons.py")}
exec(src[: src.index("C = lambda")], ns)  # общие помощники: Icon, drone, capsule, device, cup...
Icon, INK, W, hexc, lt, dk, mix = ns["Icon"], ns["INK"], ns["W"], ns["hexc"], ns["lt"], ns["dk"], ns["mix"]
drone, capsule, device, cup, nut, vial = ns["drone"], ns["capsule"], ns["device"], ns["cup"], ns["nut"], ns["vial"]
ns["OUT"] = os.path.join(HERE, "svg_donate")
os.makedirs(ns["OUT"], exist_ok=True)


def gem(ic, x, y, s, col, rot=0):
    # гранёный кристалл (как гем в интерфейсе): корона, павильон, грани и блик
    c = col
    t = f' transform="rotate({rot} {x} {y})"' if rot else ""
    w, h1, h2 = 40 * s, 16 * s, 40 * s
    ic.add(f"<g{t}>")
    ic.add(f'<path d="M{x-w} {y} L{x-w*0.55} {y-h1} L{x+w*0.55} {y-h1} L{x+w} {y} L{x} {y+h2}Z" fill="{ic.shade(c)}" stroke="{INK}" stroke-width="{max(3, 6*s):.1f}"/>')
    ic.add(f'<path d="M{x-w} {y} L{x+w} {y} M{x-w*0.55} {y-h1} L{x-w*0.25} {y} L{x} {y+h2} L{x+w*0.25} {y} L{x+w*0.55} {y-h1} M{x-w*0.25} {y} L{x} {y-h1} L{x+w*0.25} {y}" fill="none" stroke="{INK}" stroke-width="{max(2, 3.5*s):.1f}"/>')
    ic.add(f'<path d="M{x-w*0.55} {y-h1} L{x} {y-h1} L{x-w*0.25} {y} L{x-w} {y}Z" fill="#fff" opacity="0.45"/>')
    ic.add(f'<path d="M{x-w*0.25} {y} L{x} {y+h2} L{x-w} {y}Z" fill="#fff" opacity="0.18"/>')
    ic.add(f'<path d="M{x+w*0.25} {y} L{x+w} {y} L{x} {y+h2}Z" fill="#000" opacity="0.18"/>')
    ic.add("</g>")


GEM = (90, 200, 255)
PINK = (255, 110, 210)
GOLD = (255, 205, 50)


def rail_donate(ic):
    # кнопка «Донат»: подарочная коробка с бантом и гемом-пряжкой
    c1, c2 = (255, 80, 150), GOLD
    ic.add(f'<rect x="46" y="112" width="164" height="118" rx="14" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="36" y="86" width="184" height="40" rx="10" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="112" y="86" width="32" height="144" fill="{ic.shade(c2, True)}" stroke="{INK}" stroke-width="5"/>')
    # бант
    for dx in (-1, 1):
        ic.add(f'<path d="M128 84 C{128+dx*20} 40 {128+dx*78} 36 {128+dx*66} 70 C{128+dx*58} 92 {128+dx*24} 88 128 84Z" fill="{ic.shade(c2)}" stroke="{INK}" stroke-width="{W}"/>')
    gem(ic, 128, 78, 0.55, GEM)
    ic.shine(66, 142, 7, 22, 0, 0.45)
    ic.sparkle(214, 50, 14, "#fff6b0")
    ic.sparkle(40, 196, 10, "#fff6b0")


def turbo(ic):
    # три стрелки переработки по кругу + молния в центре
    c1, c2 = (130, 255, 110), GOLD
    cx, cy, R = 128, 128, 84
    for i in range(3):
        a0, a1 = math.radians(-80 + i * 120), math.radians(-10 + i * 120)
        x0, y0 = cx + R * math.cos(a0), cy + R * math.sin(a0)
        x1, y1 = cx + R * math.cos(a1), cy + R * math.sin(a1)
        arc = f"M{x0:.1f} {y0:.1f} A{R} {R} 0 0 1 {x1:.1f} {y1:.1f}"
        ic.add(f'<path d="{arc}" fill="none" stroke="{INK}" stroke-width="32"/><path d="{arc}" fill="none" stroke="{hexc(c1)}" stroke-width="19"/>')
        tx, ty = -math.sin(a1), math.cos(a1)  # касательная по часовой
        nx, ny = math.cos(a1), math.sin(a1)
        tip = (x1 + tx * 30, y1 + ty * 30)
        b1 = (x1 + nx * 24 - tx * 2, y1 + ny * 24 - ty * 2)
        b2 = (x1 - nx * 24 - tx * 2, y1 - ny * 24 - ty * 2)
        ic.add(f'<path d="M{tip[0]:.1f} {tip[1]:.1f} L{b1[0]:.1f} {b1[1]:.1f} L{b2[0]:.1f} {b2[1]:.1f}Z" fill="{hexc(c1)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<circle cx="128" cy="128" r="46" fill="{ic.shade((60, 70, 80))}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M138 88 L104 136 L126 136 L114 170 L154 118 L132 118 L144 88Z" fill="{ic.shade(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="168" y="192" width="70" height="44" rx="14" fill="{hexc((40, 120, 40))}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<text x="203" y="225" font-family="Arial Black, Arial" font-weight="900" font-size="30" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="5" paint-order="stroke">x2</text>')


def bigbag(ic):
    c1, c2 = (255, 150, 50), (110, 70, 40)
    ic.add(f'<path d="M92 66 Q92 30 128 30 Q164 30 164 66" fill="none" stroke="{INK}" stroke-width="16"/><path d="M92 66 Q92 30 128 30 Q164 30 164 66" fill="none" stroke="{hexc(c2)}" stroke-width="7"/>')
    ic.add(f'<path d="M50 96 Q50 60 90 60 L166 60 Q206 60 206 96 L212 214 Q212 234 190 234 L66 234 Q44 234 44 214Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M50 112 Q128 140 206 112" fill="none" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="74" y="150" width="108" height="66" rx="16" fill="{lt(c1,0.25)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="114" y="140" width="28" height="22" rx="6" fill="{hexc(GOLD)}" stroke="{INK}" stroke-width="5"/>')
    ic.shine(74, 100, 8, 22, 10, 0.5)
    # плюс
    ic.add(f'<circle cx="200" cy="62" r="34" fill="{ic.shade((90, 220, 90))}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M200 44 L200 80 M182 62 L218 62" stroke="#fff" stroke-width="11"/>')


def lucky(ic):
    # сканер с клевером на экране и лучом
    c1, c2 = (70, 80, 92), (120, 240, 90)
    ic.add(f'<path d="M178 70 L240 30 L240 120Z" fill="{lt(c2,0.35)}" opacity="0.55"/>')
    ic.add(f'<rect x="40" y="52" width="150" height="180" rx="26" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="58" y="72" width="114" height="100" rx="14" fill="{dk(c2,0.6)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="64" y="78" width="102" height="88" rx="10" fill="url(#{ic.grad("l", [(0, lt(c2,0.45)), (1, hexc(c2))])})"/>')
    for a in (0, 90, 180, 270):
        ic.add(f'<g transform="rotate({a} 115 120)"><path d="M115 120 C100 104 98 86 115 88 C132 86 130 104 115 120Z" fill="{hexc((60, 180, 60))}" stroke="{INK}" stroke-width="4"/></g>')
    ic.add(f'<path d="M115 120 Q122 140 138 150" fill="none" stroke="{INK}" stroke-width="5"/>')
    for i, x in enumerate((78, 115, 152)):
        ic.add(f'<circle cx="{x}" cy="200" r="12" fill="{hexc(c2) if i == 1 else "#e6e8ec"}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="180" y="62" width="22" height="30" rx="6" fill="{hexc(c1)}" stroke="{INK}" stroke-width="5"/>')
    ic.sparkle(218, 160, 14, "#e8ffb0")
    ic.sparkle(222, 214, 9, "#e8ffb0")


def sprint(ic):
    c1, c2 = (60, 170, 255), (255, 255, 255)
    for y, l in ((96, 60), (126, 80), (156, 54)):
        ic.add(f'<line x1="20" y1="{y}" x2="{20+l}" y2="{y}" stroke="{INK}" stroke-width="15"/><line x1="20" y1="{y}" x2="{20+l}" y2="{y}" stroke="{lt(c1,0.4)}" stroke-width="6"/>')
    # кроссовок
    ic.add(f'<path d="M84 196 L84 108 Q84 92 100 92 L136 92 Q146 92 148 104 L156 128 Q200 140 226 168 Q238 182 232 198Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M76 196 L236 196 Q238 222 214 222 L92 222 Q76 222 76 206Z" fill="#f2f4f8" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M80 210 L234 210" stroke="{hexc(GOLD)}" stroke-width="6"/>')
    for i in range(3):
        ic.add(f'<line x1="{118+i*16}" y1="{112+i*12}" x2="{140+i*16}" y2="{106+i*12}" stroke="#fff" stroke-width="6"/>')
    ic.add(f'<path d="M150 158 Q176 150 204 172" fill="none" stroke="{lt(c1,0.6)}" stroke-width="8"/>')
    ic.add(f'<path d="M98 176 Q130 150 170 168" fill="none" stroke="{hexc(GOLD)}" stroke-width="9"/>')
    ic.shine(100, 120, 6, 18, 0, 0.5)


def gemtime(ic):
    # магнит-подкова полюсами вниз притягивает гемы
    c1 = (235, 60, 60)
    ic.add('<g transform="rotate(180 128 112)">')
    ic.add(f'<path d="M60 40 L60 130 A68 68 0 0 0 196 130 L196 40 L156 40 L156 130 A28 28 0 0 1 100 130 L100 40Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="60" y="30" width="40" height="34" fill="#dfe3ea" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="156" y="30" width="40" height="34" fill="#dfe3ea" stroke="{INK}" stroke-width="{W}"/>')
    ic.add('</g>')
    ic.shine(170, 80, 6, 22, 0, 0.5)
    for x in (80, 176):
        for k, w in enumerate((10, 16)):
            ic.add(f'<path d="M{x-w} {206+k*12} Q{x} {196+k*12} {x+w} {206+k*12}" fill="none" stroke="{lt(GEM,0.5)}" stroke-width="4" opacity="{0.9-k*0.3}"/>')
    for (x, y, s, r) in ((128, 206, 0.6, 0), (64, 232, 0.36, -18), (192, 232, 0.36, 18)):
        gem(ic, x, y, s, GEM, r)
    ic.add(f'<rect x="174" y="20" width="66" height="42" rx="14" fill="{hexc((30, 120, 200))}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<text x="207" y="52" font-family="Arial Black, Arial" font-weight="900" font-size="30" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="5" paint-order="stroke">x2</text>')


def vip(ic):
    c1 = GOLD
    ic.add(f'<path d="M40 190 L30 78 L84 126 L128 52 L172 126 L226 78 L216 190Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="36" y="180" width="184" height="42" rx="12" fill="{ic.shade((230, 170, 30), True)}" stroke="{INK}" stroke-width="{W}"/>')
    for x, y in ((30, 76), (128, 48), (226, 76)):
        ic.add(f'<circle cx="{x}" cy="{y}" r="12" fill="#fff4c0" stroke="{INK}" stroke-width="5"/>')
    gem(ic, 128, 140, 0.62, (255, 70, 110))
    gem(ic, 76, 162, 0.32, GEM)
    gem(ic, 180, 162, 0.32, (120, 240, 90))
    ic.add(f'<text x="128" y="213" font-family="Arial Black, Arial" font-weight="900" font-size="30" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="5" paint-order="stroke" letter-spacing="3">VIP</text>')
    ic.shine(70, 120, 8, 22, -20, 0.5)
    ic.sparkle(214, 34, 14, "#fff6b0")


def gems1(ic):
    gem(ic, 92, 160, 0.95, GEM, -14)
    gem(ic, 168, 168, 0.85, (130, 150, 255), 12)
    gem(ic, 130, 104, 1.05, GEM)
    ic.sparkle(206, 74, 14)
    ic.sparkle(48, 92, 9)


def gems2(ic):
    # мешок с гемами
    c1 = (190, 140, 90)
    ic.add(f'<path d="M66 110 Q30 230 128 232 Q226 230 190 110Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    gem(ic, 96, 98, 0.7, GEM, -16)
    gem(ic, 162, 100, 0.65, (150, 120, 255), 16)
    gem(ic, 128, 78, 0.8, (110, 220, 255))
    ic.add(f'<path d="M64 112 Q128 132 192 112" fill="none" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M76 120 Q128 140 180 120" fill="none" stroke="{hexc(GOLD)}" stroke-width="8"/>')
    gem(ic, 128, 180, 0.55, GEM)
    ic.shine(80, 170, 8, 24, 10, 0.4)
    ic.sparkle(214, 70, 13)


def gems3(ic):
    # открытый сундук
    c1, c2 = (150, 90, 50), GOLD
    ic.add(f'<path d="M44 92 Q44 44 128 44 Q212 44 212 92 L212 110 L44 110Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="40" y="104" width="176" height="28" rx="6" fill="{ic.shade((40, 30, 50))}" stroke="{INK}" stroke-width="5"/>')
    for (x, y, s, col, r) in ((84, 116, 0.55, GEM, -20), (128, 104, 0.7, (150, 120, 255), 0), (172, 116, 0.55, PINK, 20), (106, 128, 0.45, (110, 230, 255), 10), (152, 128, 0.45, GEM, -10)):
        gem(ic, x, y, s, col, r)
    ic.add(f'<rect x="40" y="136" width="176" height="94" rx="12" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    for x in (60, 196):
        ic.add(f'<rect x="{x-10}" y="136" width="20" height="94" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<rect x="108" y="150" width="40" height="44" rx="8" fill="{ic.shade(c2)}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<circle cx="128" cy="168" r="7" fill="{INK}"/>')
    ic.shine(84, 70, 22, 8, -6, 0.4)
    ic.sparkle(216, 44, 14)
    ic.sparkle(36, 60, 10)


def gems4(ic):
    # гора гемов с огромным розовым кристаллом
    for (x, y, s, col, r) in ((54, 206, 0.6, GEM, -20), (202, 206, 0.6, (150, 120, 255), 20), (92, 214, 0.55, PINK, 8), (164, 214, 0.55, GEM, -8),
                              (74, 172, 0.55, (110, 230, 255), 14), (182, 172, 0.55, PINK, -14), (128, 214, 0.6, (150, 120, 255), 0)):
        gem(ic, x, y, s, col, r)
    gem(ic, 128, 112, 1.55, PINK)
    ic.sparkle(210, 56, 16)
    ic.sparkle(44, 76, 12)
    ic.sparkle(222, 128, 9)


def starter(ic):
    # подарок «новичку»: коробка с лентой, звезда-значок
    c1, c2 = (255, 110, 80), (255, 240, 240)
    ic.add(f'<rect x="52" y="116" width="152" height="112" rx="12" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="42" y="90" width="172" height="38" rx="10" fill="{ic.shade(c1, True)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<rect x="114" y="90" width="28" height="138" fill="{ic.shade(c2, True)}" stroke="{INK}" stroke-width="5"/>')
    for dx in (-1, 1):
        ic.add(f'<path d="M128 88 C{128+dx*14} 40 {128+dx*70} 40 {128+dx*60} 72 C{128+dx*52} 92 {128+dx*22} 92 128 88Z" fill="{ic.shade(c2)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<circle cx="128" cy="84" r="13" fill="{hexc(c2)}" stroke="{INK}" stroke-width="5"/>')
    pts = " ".join(f"{196+(30 if i%2==0 else 13)*math.cos(math.radians(-90+36*i)):.1f},{176+(30 if i%2==0 else 13)*math.sin(math.radians(-90+36*i)):.1f}" for i in range(10))
    ic.add(f'<polygon points="{pts}" fill="{ic.shade(GOLD)}" stroke="{INK}" stroke-width="5"/>')
    gem(ic, 72, 196, 0.42, GEM, -10)
    ic.shine(70, 150, 7, 20, 0, 0.45)
    ic.sparkle(38, 60, 11, "#fff6b0")


def goldcap(ic):
    capsule(ic, GOLD, (255, 245, 200))
    for x, y, s in ((208, 52, 15), (48, 206, 11)):
        ic.sparkle(x, y, s, "#fff3a0")
    ic.add(f'<rect x="168" y="182" width="66" height="40" rx="12" fill="{hexc((175, 70, 255))}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<text x="201" y="211" font-family="Arial Black, Arial" font-weight="900" font-size="22" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="4" paint-order="stroke">EPIC</text>')


def starcap(ic):
    capsule(ic, (255, 120, 220), (255, 255, 255))
    pts = " ".join(f"{196+(34 if i%2==0 else 15)*math.cos(math.radians(-90+36*i)):.1f},{58+(34 if i%2==0 else 15)*math.sin(math.radians(-90+36*i)):.1f}" for i in range(10))
    ic.add(f'<polygon points="{pts}" fill="{ic.shade(GOLD)}" stroke="{INK}" stroke-width="5"/>')
    for x, y, s in ((50, 200, 13), (214, 190, 10), (40, 120, 8)):
        ic.sparkle(x, y, s, "#fff5b0")


def boosts(ic):
    # открытый ящик: торчат пробирки и монета
    c1 = (160, 110, 60)
    ic.add('<g transform="rotate(-14 98 110)">')
    ic.add(f'<rect x="80" y="40" width="36" height="96" rx="16" fill="#e9f4ff" fill-opacity="0.9" stroke="{INK}" stroke-width="6"/>')
    ic.add(f'<rect x="84" y="78" width="28" height="54" rx="12" fill="{ic.shade((255, 60, 70))}"/>')
    ic.add(f'<rect x="76" y="30" width="44" height="16" rx="5" fill="#704030" stroke="{INK}" stroke-width="5"/>')
    ic.add('</g><g transform="rotate(12 160 110)">')
    ic.add(f'<rect x="142" y="46" width="36" height="90" rx="16" fill="#e9f4ff" fill-opacity="0.9" stroke="{INK}" stroke-width="6"/>')
    ic.add(f'<rect x="146" y="80" width="28" height="52" rx="12" fill="{ic.shade((70, 150, 255))}"/>')
    ic.add(f'<rect x="138" y="36" width="44" height="16" rx="5" fill="#704030" stroke="{INK}" stroke-width="5"/>')
    ic.add("</g>")
    ic.add(f'<circle cx="128" cy="98" r="26" fill="{ic.shade(GOLD)}" stroke="{INK}" stroke-width="6"/>')
    ic.add(f'<path d="M128 90 C124 82 112 84 112 93 C112 99 120 104 128 112 C136 104 144 99 144 93 C144 84 132 82 128 90Z" fill="#7fe07a" stroke="{INK}" stroke-width="3"/>')
    ic.add(f'<path d="M36 128 L220 128 L206 228 L50 228Z" fill="{ic.shade(c1)}" stroke="{INK}" stroke-width="{W}"/>')
    ic.add(f'<path d="M30 116 L226 116 L222 140 L34 140Z" fill="{ic.shade((130, 85, 45), True)}" stroke="{INK}" stroke-width="{W}"/>')
    for y in (168, 200):
        ic.add(f'<path d="M44 {y} L212 {y}" stroke="{INK}" stroke-width="4" opacity="0.6"/>')
    ic.add(f'<path d="M116 154 L102 182 L124 182 L112 212 L150 172 L128 172 L140 154Z" fill="{ic.shade((255, 160, 40))}" stroke="{INK}" stroke-width="5"/>')
    ic.sparkle(214, 70, 14, "#fff6b0")
    ic.sparkle(40, 80, 10, "#fff6b0")


def microconv(ic):
    # стопка мини-переработчиков ×5
    c1, c2 = (100, 106, 118), (130, 255, 120)
    for i, (dx, dy, r) in enumerate(((-46, 18, -14), (46, 18, 14))):
        ic.add(f'<g transform="translate({dx} {dy}) rotate({r} 128 140) scale(0.72) translate(50 54)">')
        device(ic, c1, c2)
        ic.add("</g>")
    ic.add('<g transform="translate(0 -6) scale(0.86) translate(21 22)">')
    device(ic, c1, c2)
    ic.add("</g>")
    ic.add(f'<rect x="164" y="186" width="70" height="44" rx="14" fill="{hexc((40, 140, 50))}" stroke="{INK}" stroke-width="5"/>')
    ic.add(f'<text x="199" y="219" font-family="Arial Black, Arial" font-weight="900" font-size="30" text-anchor="middle" fill="#fff" stroke="{INK}" stroke-width="5" paint-order="stroke">x5</text>')


def supershake(ic):
    cup(ic, (255, 70, 110), (70, 255, 230))
    ic.add(f'<path d="M140 120 L112 164 L132 164 L120 200 L160 150 L138 150 L152 120Z" fill="{ic.shade(GOLD)}" stroke="{INK}" stroke-width="5"/>')
    for x, y, s in ((36, 130, 12), (222, 150, 13), (214, 214, 9)):
        ic.sparkle(x, y, s, "#fff5b0")


def rays(ic):
    # лучи «солнышка» для фона карточек (белые, красятся в игре); свечения-фона у этой картинки нет
    ic.body.clear()
    g = ic.grad("r", [(0, "#ffffff", 0.95), (0.35, "#ffffff", 0.55), (1, "#ffffff", 0)], cx=0.5, cy=0.5, r=0.5)
    n = 16
    for i in range(n):
        a0 = math.radians(i * 360 / n - 5.5)
        a1 = math.radians(i * 360 / n + 5.5)
        R = 128
        ic.add(f'<path d="M128 128 L{128+R*math.cos(a0):.1f} {128+R*math.sin(a0):.1f} L{128+R*math.cos(a1):.1f} {128+R*math.sin(a1):.1f}Z" fill="url(#{g})"/>')


ICONS = [
    ("dn_rail", (255, 120, 180), rail_donate),
    ("dn_turbo", (130, 255, 110), turbo),
    ("dn_bigbag", (255, 170, 60), bigbag),
    ("dn_lucky", (120, 240, 90), lucky),
    ("dn_sprint", (80, 200, 255), sprint),
    ("dn_gemtime", (90, 200, 255), gemtime),
    ("dn_vip", (255, 210, 60), vip),
    ("dn_gems1", (110, 210, 255), gems1),
    ("dn_gems2", (80, 180, 255), gems2),
    ("dn_gems3", (150, 120, 255), gems3),
    ("dn_gems4", (255, 120, 220), gems4),
    ("dn_starter", (255, 120, 90), starter),
    ("dn_goldcap", (255, 200, 50), goldcap),
    ("dn_starcap", (255, 120, 230), starcap),
    ("dn_boosts", (255, 150, 50), boosts),
    ("dn_microconv", (130, 255, 120), microconv),
    ("dn_supershake", (255, 110, 190), supershake),
    ("dn_rays", (255, 255, 255), rays),
]
for name, glow, fn in ICONS:
    ic = Icon(name, glow)
    fn(ic)
    ic.save()
print(len(ICONS), "svg")
