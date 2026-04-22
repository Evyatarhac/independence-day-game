#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
30 November - Game Intro  |  Little Fighter 2 style
"""

import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter
import imageio

# ── Config ───────────────────────────────────────────────────────────────────
IMG_DIR = r"C:\Users\hacoh\Desktop\INDEPNDENCE DAY GAME\תמונות לוידאו"
OUTPUT  = r"C:\Users\hacoh\Desktop\INDEPNDENCE DAY GAME\intro_30nov.mp4"
W, H    = 1280, 720
FPS     = 30

# ── Fonts (ASCII / Latin only — no Hebrew rendering issues) ──────────────────
def fnt(name, size):
    paths = {
        "impact": [r"C:\Windows\Fonts\impact.ttf"],
        "bold":   [r"C:\Windows\Fonts\arialbd.ttf"],
        "reg":    [r"C:\Windows\Fonts\arial.ttf"],
    }
    for p in paths.get(name, paths["reg"]):
        try: return ImageFont.truetype(p, size)
        except: pass
    return ImageFont.load_default(size=size)

# ── Image helpers ─────────────────────────────────────────────────────────────
def cover(img, w=W, h=H):
    r = img.width / img.height
    nw, nh = (int(h * r), h) if r > w/h else (w, int(w / r))
    img = img.resize((nw, nh), Image.LANCZOS)
    return img.crop(((nw-w)//2, (nh-h)//2, (nw-w)//2+w, (nh-h)//2+h))

def kb(img, t, dur, z0=1.0, z1=1.2, dx=0, dy=0):
    """Ken Burns zoom-pan"""
    p = min(t / max(dur, .001), 1.0)
    z = z0 + (z1-z0)*p
    nw, nh = int(W*z), int(H*z)
    im = cover(img, nw, nh)
    x0 = max(0, min((nw-W)//2 + int(dx*p), nw-W))
    y0 = max(0, min((nh-H)//2 + int(dy*p), nh-H))
    return im.crop((x0, y0, x0+W, y0+H))

def grade(img, contrast=1.5, color=1.6, sharp=1.3):
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    img = ImageEnhance.Sharpness(img).enhance(sharp)
    return img

def vig(img, s=0.45):
    arr = np.array(img, dtype=np.float32)
    Y, X = np.ogrid[:H, :W]
    d = np.sqrt(((X-W/2)/(W/2))**2 + ((Y-H/2)/(H/2))**2)
    arr = np.clip(arr * (1-s*np.clip(d,0,1)**1.5)[:,:,None], 0, 255).astype(np.uint8)
    return Image.fromarray(arr)

def noise(img, strength=18):
    arr = np.array(img, dtype=np.int16)
    n   = np.random.randint(-strength, strength+1, arr.shape, dtype=np.int16)
    return Image.fromarray(np.clip(arr+n, 0, 255).astype(np.uint8))

# ── Draw helpers ───────────────────────────────────────────────────────────────
def otxt(drw, x, y, text, f, fill, outline=(0,0,0), ow=3):
    for ox in range(-ow, ow+1):
        for oy in range(-ow, ow+1):
            if ox or oy:
                drw.text((x+ox, y+oy), text, font=f, fill=outline)
    drw.text((x, y), text, font=f, fill=fill)

def ctxt(drw, y, text, f, fill, outline=(0,0,0), ow=3):
    bb = drw.textbbox((0,0), text, font=f)
    otxt(drw, (W-(bb[2]-bb[0]))//2, y, text, f, fill, outline, ow)

def slam(drw, y, text, f_big, fill, t, t0, slam_dur=0.14):
    """Text that slams in with an overshoot bounce"""
    prog = (t - t0) / slam_dur if t > t0 else 0
    prog = min(prog, 1.0)
    bounce = math.sin(prog * math.pi) * 0.28 if prog < 1 else 0
    sz_base = f_big.size
    sz = int(sz_base * (1 + bounce))
    f2 = fnt("impact", sz)
    bb = drw.textbbox((0,0), text, font=f2)
    x  = (W - (bb[2]-bb[0]))//2
    otxt(drw, x, y, text, f2, fill, (0,0,0), max(3, int(sz/20)))

# ── Flash / overlay effects ────────────────────────────────────────────────────
def flash(frame, t, dur=0.14, col=(255,255,255)):
    if t >= dur: return frame
    a = int(255*(1-t/dur))
    fl = Image.new('RGBA', (W,H), (*col, a))
    return Image.alpha_composite(frame.convert('RGBA'), fl).convert('RGB')

def fade_in(img, t, dur=0.4):
    a = min(t/dur, 1.0)
    return Image.fromarray((np.array(img)*a).astype(np.uint8))

def fade_out(img, t, clip_dur, dur=0.4):
    rt = clip_dur - t
    if rt >= dur: return img
    a = max(rt/dur, 0)
    return Image.fromarray((np.array(img)*a).astype(np.uint8))

# ── LF2-style hit effects ─────────────────────────────────────────────────────
def hit_sparks(img, cx, cy, t, t0, dur=0.4, n=16, radius=80):
    """Burst of spark lines from impact point"""
    prog = (t - t0) / dur if t > t0 else 0
    if prog <= 0 or prog >= 1: return img
    ov  = Image.new('RGBA', (W,H), (0,0,0,0))
    drw = ImageDraw.Draw(ov)
    alpha = int(255 * (1 - prog))
    r = int(radius * prog)
    for i in range(n):
        angle = (i/n)*2*math.pi + t*3
        x0 = cx + int(r*0.3*math.cos(angle))
        y0 = cy + int(r*0.3*math.sin(angle))
        x1 = cx + int(r*math.cos(angle))
        y1 = cy + int(r*math.sin(angle))
        col = (255, 220, 0, alpha) if i % 3 != 0 else (255, 80, 0, alpha)
        drw.line([(x0,y0),(x1,y1)], fill=col, width=3)
    return Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')

def impact_rings(img, cx, cy, t, t0, dur=0.35, rings=3, max_r=120):
    """Concentric rings expanding from hit point"""
    prog = (t - t0) / dur if t > t0 else 0
    if prog <= 0 or prog >= 1: return img
    ov  = Image.new('RGBA', (W,H), (0,0,0,0))
    drw = ImageDraw.Draw(ov)
    for k in range(rings):
        p2 = max(0, prog - k*0.2)
        if p2 <= 0: continue
        r = int(max_r * p2)
        a = int(255*(1-p2))
        col = (255, 220, 0, a)
        drw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=col, width=3)
    return Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')

def speed_lines(img, cx=0.15, cy=0.85, alpha=90, n=48):
    """Radiating speed lines from a point"""
    ov  = Image.new('RGBA', (W,H), (0,0,0,0))
    drw = ImageDraw.Draw(ov)
    ox, oy = int(W*cx), int(H*cy)
    diag = int(math.sqrt(W**2+H**2))
    for i in range(n):
        angle = (i/n)*2*math.pi
        lw = 4 if i%4==0 else 1
        la = alpha if i%4==0 else alpha//2
        drw.line([(ox,oy),(ox+int(diag*math.cos(angle)),oy+int(diag*math.sin(angle)))],
                 fill=(255,255,255,la), width=lw)
    return Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')

def border(img, col=(255,220,0), th=8):
    drw = ImageDraw.Draw(img)
    for i in range(th):
        drw.rectangle([i,i,W-1-i,H-1-i], outline=col)
    return img

def red_grade(img, rt=1.3, gt=0.65, bt=0.55):
    arr = np.array(img, dtype=np.float32)
    arr[:,:,0] = np.clip(arr[:,:,0]*rt, 0, 255)
    arr[:,:,1] = np.clip(arr[:,:,1]*gt, 0, 255)
    arr[:,:,2] = np.clip(arr[:,:,2]*bt, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))

# ── Load images ────────────────────────────────────────────────────────────────
print("Loading images...")
img_files = sorted([f for f in os.listdir(IMG_DIR) if f.lower().endswith(('.jpeg','.jpg','.png'))])
IMGS = [Image.open(os.path.join(IMG_DIR, f)).convert('RGB') for f in img_files]
# 0=MainMenu  1=CharSelect  2=NameEntry  3=NightBG
# 4=Combat1   5=Shop        6=Combat2    7=Combat3
# 8=Ad1  9=Ad2 (skipped)   10=GameOver  11=Boss  12=Editor(skipped)
print(f"  {len(IMGS)} images loaded")

# ── Frame collector ────────────────────────────────────────────────────────────
FRAMES = []

def scene(fn, dur, label=""):
    n = int(dur * FPS)
    print(f"  [{label}] {n} frames ({dur:.1f}s)")
    for i in range(n):
        FRAMES.append(np.array(fn(i/FPS).convert('RGB')))

# ══════════════════════════════════════════════════════════════════════════════
# S1 — BLACK TITLE  "1948"  (2.5 s)
# ══════════════════════════════════════════════════════════════════════════════
def s1(t):
    bg  = Image.new('RGB', (W,H), (0,0,0))
    drw = ImageDraw.Draw(bg)

    if t > 0.25:
        a  = min((t-0.25)/0.5, 1.0)
        jit = random.choice([0,0,0,4,-4]) if t < 1.4 else 0
        f  = fnt("impact", 210)
        bb = drw.textbbox((0,0), "1948", font=f)
        x  = (W-(bb[2]-bb[0]))//2 + jit
        y  = (H-(bb[3]-bb[1]))//2 - 40
        # glow layers
        for g in [60,40,20]:
            gc = (min(255,int(180*a)), 0, 0)
            gg = fnt("impact", 210+g)
            bb2 = drw.textbbox((0,0),"1948",font=gg)
            drw.text(((W-(bb2[2]-bb2[0]))//2+jit, y), "1948",
                     font=gg, fill=(*gc,30))
        otxt(drw, x, y, "1948", f,
             (int(255*a), int(200*a), 0), (120,0,0), 9)

    if t > 1.1:
        a  = min((t-1.1)/0.55, 1.0)
        f2 = fnt("bold", 36)
        ctxt(drw, H//2+105, "WAR OF INDEPENDENCE",
             f2, (int(210*a),)*3, ow=2)

    if t > 1.7:
        a  = min((t-1.7)/0.4, 1.0)
        f3 = fnt("reg", 24)
        ctxt(drw, H//2+155, "Land of Israel, 1947 - 1949",
             f3, (int(150*a),)*3, ow=1)

    return fade_out(bg, t, 2.5, 0.5)

# ══════════════════════════════════════════════════════════════════════════════
# S2 — NIGHT CITY  (2.5 s)
# ══════════════════════════════════════════════════════════════════════════════
def s2(t):
    frame = kb(IMGS[3], t, 2.5, z0=1.0, z1=1.28, dx=70)
    frame = grade(frame, 1.6, 1.5)
    frame = vig(frame, 0.55)
    frame = noise(frame, 14)
    frame = flash(frame, t, 0.2)
    frame = border(frame, (255,220,0), 7)
    drw = ImageDraw.Draw(frame)

    if t > 0.3:
        a = min((t-0.3)/0.55, 1.0)
        ctxt(drw, 28, "JERUSALEM. 1948.",
             fnt("impact", 66), (int(255*a), int(220*a), 0), ow=5)

    if t > 1.1:
        a = min((t-1.1)/0.5, 1.0)
        ctxt(drw, H-105, "The battle for a new nation begins...",
             fnt("reg", 30), (255,255,255), ow=2)

    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S3 — CHARACTER REVEAL  "CHOOSE YOUR FIGHTER"  (3.5 s)
# LF2 style: each fighter "drops in" with a stat strip
# ══════════════════════════════════════════════════════════════════════════════
FIGHTERS = [
    ("PALMACH",  "STRENGTH  ████░  SPEED  ███░░  SKILL  ████░", 0.40, 0.20),
    ("LEHI",     "STRENGTH  ███░░  SPEED  █████  SKILL  █████", 0.72, 0.20),
    ("HAGANAH",  "STRENGTH  █████  SPEED  ███░░  SKILL  ███░░", 0.32, 0.68),
    ("IRGUN",    "STRENGTH  ███░░  SPEED  █████  SKILL  ██░░░", 0.72, 0.68),
]

def s3(t):
    frame = kb(IMGS[1], t, 3.5, z0=1.0, z1=1.08)
    frame = grade(frame)
    frame = flash(frame, t, 0.14)
    frame = border(frame, (255,220,0), 8)
    drw = ImageDraw.Draw(frame)

    if t > 0.1:
        ctxt(drw, 10, "CHOOSE YOUR FIGHTER",
             fnt("impact", 68), (255,255,255), (0,0,0), 5)

    for i, (name, stats, rx, ry) in enumerate(FIGHTERS):
        delay = 0.4 + i*0.45
        if t <= delay: continue
        prog = min((t-delay)/0.22, 1.0)
        # drop-in: starts above, bounces down
        drop = int((1-prog)*60) if prog < 1 else 0
        bounce = math.sin(prog*math.pi)*0.25 if prog < 1 else 0
        sz = int(34*(1+bounce))
        px, py = int(W*rx), int(H*ry) - drop

        # glow box behind name
        fn_ = fnt("impact", sz)
        bb_ = drw.textbbox((0,0), name, font=fn_)
        bw, bh = bb_[2]-bb_[0]+16, bb_[3]-bb_[1]+6
        drw.rectangle([px-8, py-3, px+bw, py+bh+3],
                      fill=(0,0,0,180), outline=(255,220,0), width=2)
        otxt(drw, px, py, name, fn_, (255,220,0), (0,0,0), 3)

        # stats bar
        if prog >= 1 and t > delay+0.22:
            f2 = fnt("reg", 13)
            otxt(drw, px, py+bh+8, stats, f2, (200,255,200), (0,0,0), 1)

    if t > 2.8:
        a = min((t-2.8)/0.4, 1.0)
        ctxt(drw, H-55, "SIDE-SCROLLING BEAT 'EM UP",
             fnt("bold", 26), (255,150,0), ow=2)

    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S4 — COMBAT CUT 1  (1.4 s)  marketplace — fast punch-in
# ══════════════════════════════════════════════════════════════════════════════
def s4(t):
    frame = kb(IMGS[4], t, 1.4, z0=1.0, z1=1.35, dx=200)
    frame = grade(frame, 1.6, 1.7)
    frame = speed_lines(frame, 0.12, 0.88, 100, 48)
    frame = flash(frame, t, 0.14, (255,220,0))
    frame = border(frame, (255,50,50), 10)

    drw = ImageDraw.Draw(frame)
    if t > 0.05:
        slam(drw, H//2-90, "FIGHT!", fnt("impact",120), (255,50,0), t, 0.05)
    frame = hit_sparks(frame, int(W*0.15), int(H*0.87), t, 0.06, 0.5, 20, 90)
    frame = impact_rings(frame, int(W*0.15), int(H*0.87), t, 0.06, 0.45)
    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S5 — COMBAT CUT 2  (1.4 s)  keffiyeh fighter — zoom blast
# ══════════════════════════════════════════════════════════════════════════════
def s5(t):
    frame = kb(IMGS[6], t, 1.4, z0=1.2, z1=1.5, dx=-150)
    frame = grade(frame, 1.7, 1.7)
    frame = speed_lines(frame, 0.88, 0.88, 100, 48)
    frame = flash(frame, t, 0.12, (255,100,0))
    frame = border(frame, (255,120,0), 10)

    drw = ImageDraw.Draw(frame)
    if t > 0.04:
        slam(drw, 18, "POW!", fnt("impact", 110), (255,220,0), t, 0.04)
    frame = hit_sparks(frame, int(W*0.88), int(H*0.87), t, 0.04, 0.45, 18, 85)
    frame = impact_rings(frame, int(W*0.88), int(H*0.87), t, 0.04, 0.4)
    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S6 — COMBAT CUT 3  (1.4 s)  British soldiers — COMBO
# ══════════════════════════════════════════════════════════════════════════════
def s6(t):
    frame = kb(IMGS[7], t, 1.4, z0=1.1, z1=1.4, dx=100)
    frame = grade(frame, 1.7, 1.6)
    frame = speed_lines(frame, 0.5, 0.9, 80, 40)
    frame = flash(frame, t, 0.13)
    frame = border(frame, (80,120,255), 10)

    drw = ImageDraw.Draw(frame)
    if t > 0.05:
        slam(drw, 18, "COMBO x3!", fnt("impact",90), (255,255,255), t, 0.05)
    frame = hit_sparks(frame, W//2, int(H*0.86), t, 0.05, 0.5, 22, 100)
    frame = impact_rings(frame, W//2, int(H*0.86), t, 0.05, 0.45, 3, 130)
    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S7 — SHOP  (1.2 s)  quick upgrade flash
# ══════════════════════════════════════════════════════════════════════════════
def s7(t):
    frame = kb(IMGS[5], t, 1.2, z0=1.0, z1=1.1)
    frame = grade(frame, 1.4, 1.5)
    frame = flash(frame, t, 0.14, (80,255,80))
    frame = border(frame, (80,220,80), 7)
    drw = ImageDraw.Draw(frame)
    if t > 0.12:
        ctxt(drw, 14, "UPGRADE BETWEEN WAVES",
             fnt("impact", 56), (80,255,80), (0,0,0), 4)
    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S8 — BOSS REVEAL  (3.5 s)  slow dramatic zoom — LF2 boss entrance
# ══════════════════════════════════════════════════════════════════════════════
def s8(t):
    frame = kb(IMGS[11], t, 3.5, z0=0.95, z1=1.45, dx=-180)
    frame = red_grade(frame, 1.4, 0.6, 0.5)
    frame = ImageEnhance.Contrast(frame).enhance(1.8)
    frame = vig(frame, 0.70)
    frame = noise(frame, 10)
    frame = flash(frame, t, 0.22, (255,0,0))
    frame = border(frame, (255,0,0), 12)

    drw = ImageDraw.Draw(frame)

    # Pulsing BOSS WARNING bar at top
    pulse = 0.88 + 0.12*math.sin(t*10)
    if t > 0.18:
        sz = int(96*pulse)
        f_ = fnt("impact", sz)
        bb_ = drw.textbbox((0,0),"WARNING: BOSS",font=f_)
        x_ = (W-(bb_[2]-bb_[0]))//2
        # Red backing bar
        drw.rectangle([0, 8, W, 118], fill=(180,0,0))
        otxt(drw, x_, 14, "WARNING: BOSS", f_, (255,255,0), (0,0,0), 7)

    # Boss name plate
    if t > 0.7:
        a = min((t-0.7)/0.4, 1.0)
        drw.rectangle([0, H-120, W, H-64], fill=(0,0,0))
        ctxt(drw, H-115, "SQUAD LEADER  -  STAGE BOSS",
             fnt("impact", 44), (255,220,0), (0,0,0), 4)

    # HP bar
    if t > 1.2:
        a = min((t-1.2)/0.5, 1.0)
        bx, by, bw, bh = 160, H-58, int((W-320)*a), 28
        drw.rectangle([158, by-2, W-158, by+bh+2], fill=(40,0,0))
        drw.rectangle([bx, by, bx+bw, by+bh], fill=(220,0,0))
        ctxt(drw, by, "HP", fnt("bold", 28), (255,255,255), ow=2)

    if t > 2.0:
        a = min((t-2.0)/0.4, 1.0)
        ctxt(drw, H//2+40, "CAN YOU SURVIVE?",
             fnt("impact", 52), (255,255,255), (0,0,0), 4)

    # sparks burst at boss
    frame = hit_sparks(frame, int(W*0.75), int(H*0.78), t, 0.2, 0.6, 24, 120)
    frame = impact_rings(frame, int(W*0.75), int(H*0.78), t, 0.2, 0.55, 4, 160)
    return frame

# ══════════════════════════════════════════════════════════════════════════════
# S9 — TITLE CARD  (4.0 s)  night bg — LF2 logo style
# ══════════════════════════════════════════════════════════════════════════════
def s9(t):
    frame = kb(IMGS[3], t, 4.0, z0=1.3, z1=1.0)
    frame = grade(frame, 1.55, 1.45)
    frame = vig(frame, 0.62)
    frame = noise(frame, 12)
    frame = border(frame, (255,220,0), 13)

    drw = ImageDraw.Draw(frame)

    # Title slam
    if t > 0.15:
        slam(drw, 70, "30 NOVEMBER", fnt("impact",128), (255,220,0), t, 0.15)

    # Subtitle
    if t > 0.75:
        a = min((t-0.75)/0.4, 1.0)
        ctxt(drw, 228, "INDEPENDENCE DAY BEAT 'EM UP",
             fnt("impact", 40), (255,255,255), (0,0,0), 4)

    # Tags
    if t > 1.25:
        ctxt(drw, 285, "PALMACH  |  LEHI  |  HAGANAH  |  IRGUN",
             fnt("bold", 28), (255,150,0), (0,0,0), 2)

    # Animated CTA — LF2 "Press Start" style
    if t > 2.3:
        blink = int(255 * (0.6 + 0.4*math.sin((t-2.3)*5)))
        ctxt(drw, H//2+80, ">> PRESS START <<",
             fnt("impact", 58), (blink, blink, 0), (0,0,0), 4)

    # Divider line
    if t > 1.8:
        drw.line([(80, H-100), (W-80, H-100)], fill=(255,220,0), width=2)

    # Credit
    if t > 2.0:
        a = min((t-2.0)/0.5, 1.0)
        ctxt(drw, H-92, "Made by Ariya Studio  |  Evyatar Hacohen",
             fnt("reg", 24), (int(200*a),)*3, (0,0,0), 2)

    return fade_out(frame, t, 4.0, 0.55)

# ── Build ──────────────────────────────────────────────────────────────────────
print("\nRendering...")
scene(s1, 2.5,  "1948 title")
scene(s2, 2.5,  "Night city")
scene(s3, 3.5,  "Choose Fighter")
scene(s4, 1.4,  "Combat 1 FIGHT")
scene(s5, 1.4,  "Combat 2 POW")
scene(s6, 1.4,  "Combat 3 COMBO")
scene(s7, 1.2,  "Shop upgrade")
scene(s8, 3.5,  "BOSS reveal")
scene(s9, 4.0,  "Title card")

total = len(FRAMES) / FPS
print(f"\nTotal: {len(FRAMES)} frames = {total:.1f}s @ {FPS}fps")

# ── Export ─────────────────────────────────────────────────────────────────────
print(f"Exporting -> {OUTPUT}")
writer = imageio.get_writer(
    OUTPUT, fps=FPS, codec='libx264',
    ffmpeg_params=['-crf','15','-preset','medium','-pix_fmt','yuv420p'])
for i, fr in enumerate(FRAMES):
    if i % (FPS*3) == 0:
        print(f"  {i}/{len(FRAMES)} ({i/FPS:.1f}s)")
    writer.append_data(fr)
writer.close()
print(f"\nDone! -> {OUTPUT}")
