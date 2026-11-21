"""Renders the scan samples and OCR test fixtures.

The photos attached to existing demo expenses are separate assets.
Run:  python3 scripts/make_samples.py
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "web", "public", "samples")
FIXTURES = os.path.join(ROOT, "scripts", "tests", "fixtures")
os.makedirs(OUT, exist_ok=True)
os.makedirs(FIXTURES, exist_ok=True)

MONO = "/System/Library/Fonts/Menlo.ttc"
SANS = "/System/Library/Fonts/HelveticaNeue.ttc"
PAPER = (251, 250, 246)
INK = (28, 28, 30)

def mono(size, bold=False):
    return ImageFont.truetype(MONO, size, index=1 if bold else 0)

def sans(size, bold=False):
    return ImageFont.truetype(SANS, size, index=1 if bold else 0)

W = 760

def receipt(name, lines, height=None, *, out=OUT):
    """lines: list of (text, style) where style in {'h1','h2','c','l','lr','rule','total','gap'}"""
    pad = 56
    lh = 38
    est = sum({'h1': 64, 'h2': 44, 'gap': 22, 'rule': 30}.get(s if isinstance(s, str) else 'l', lh) for _, s in lines) + pad * 2
    H = height or est
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    y = pad
    for text, style in lines:
        if style == 'h1':
            f = mono(40, True); w = d.textlength(text, font=f); d.text(((W - w) / 2, y), text, font=f, fill=INK); y += 64
        elif style == 'h2':
            f = mono(26); w = d.textlength(text, font=f); d.text(((W - w) / 2, y), text, font=f, fill=INK); y += 44
        elif style == 'c':
            f = mono(26); w = d.textlength(text, font=f); d.text(((W - w) / 2, y), text, font=f, fill=INK); y += lh
        elif style == 'l':
            d.text((pad, y), text, font=mono(26), fill=INK); y += lh
        elif style == 'rule':
            d.text((pad, y), "-" * 40, font=mono(26), fill=(120, 120, 120)); y += 30
        elif style == 'gap':
            y += 22
        elif isinstance(style, tuple):
            kind, right = style
            f = mono(30, True) if kind == 'total' else mono(26)
            d.text((pad, y), text, font=f, fill=INK)
            w = d.textlength(right, font=f)
            d.text((W - pad - w, y), right, font=f, fill=INK)
            y += 46 if kind == 'total' else lh
    img = img.crop((0, 0, W, min(H, y + pad)))
    rnd = random.Random(7)
    px = img.load()
    for _ in range(9000):
        x, yy = rnd.randrange(img.width), rnd.randrange(img.height)
        r, g, b = px[x, yy]
        if r > 200:
            k = rnd.randint(-5, 2)
            px[x, yy] = (r + k, g + k, b + k)
    img.save(os.path.join(out, name))
    print("wrote", name, img.size)


receipt("bookshop.png", [
    ("LUTHER BOOK SHOP", 'h1'),
    ("Luther College", 'h2'),
    ("700 College Drive, Decorah IA", 'c'),
    ("(563) 387-0000", 'c'),
    ("", 'gap'),
    ("Date: 11/18/2026   2:14 PM", 'l'),
    ("Trans: 004817     Reg: 02", 'l'),
    ("Cashier: Hanna", 'l'),
    ("", 'rule'),
    ("LC Water Bottle  2 @ 12.95", ('lr', "25.90")),
    ("Norse Sticker Pack 4 @ 2.50", ('lr', "10.00")),
    ("Luther Lanyard  2 @ 6.35", ('lr', "12.70")),
    ("", 'rule'),
    ("Subtotal", ('lr', "48.60")),
    ("Sales Tax 7%", ('lr', "3.40")),
    ("TOTAL", ('total', "$52.00")),
    ("", 'gap'),
    ("Paid: C-BOARD CHARGE  ***10", 'l'),
    ("Items: 8", 'l'),
    ("", 'gap'),
    ("Thank you! Go Norse!", 'c'),
])

receipt("pizza.png", [
    ("DOMINO'S PIZZA", 'h1'),
    ("Store #1184 - Decorah, IA", 'h2'),
    ("", 'gap'),
    ("Date: 11/15/2026   6:42 PM", 'l'),
    ("Order: 77213   Carryout", 'l'),
    ("", 'rule'),
    ("Large Pepperoni x3", ('lr', "47.97")),
    ("Large Cheese x2", ('lr', "31.24")),
    ("", 'rule'),
    ("Subtotal", ('lr', "79.21")),
    ("Tax", ('lr', "5.79")),
    ("TOTAL", ('total', "$85.00")),
    ("", 'gap'),
    ("VISA ****4410", 'l'),
    ("", 'gap'),
    ("Thanks for your order!", 'c'),
], out=FIXTURES)

receipt("docucenter.png", [
    ("LUTHER", 'h1'),
    ("DOCUMENT CENTER", 'h2'),
    ("", 'gap'),
    ("Date: 11/10/2026  10:03 AM", 'l'),
    ("CARD SALE", 'l'),
    ("", 'rule'),
    ("TOTAL", ('total', "$35.00")),
    ("", 'gap'),
    ("APPROVED  AUTH 018273", 'l'),
    ("Customer copy", 'c'),
], out=FIXTURES)


def check(name, org, number, date, payee, amount, words, memo, signer, *, out=OUT):
    Wc, Hc = 1400, 640
    img = Image.new("RGB", (Wc, Hc), (238, 243, 247))
    d = ImageDraw.Draw(img)
    for i in range(0, Wc, 14):
        d.line([(i, 0), (i - 300, Hc)], fill=(229, 236, 242), width=1)
    d.rectangle([14, 14, Wc - 14, Hc - 14], outline=(160, 175, 190), width=2)
    d.text((48, 40), org.upper(), font=sans(34, True), fill=INK)
    d.text((48, 84), "Luther College Student Organization", font=sans(24), fill=(70, 70, 76))
    d.text((48, 114), "700 College Drive, Decorah, IA 52101", font=sans(24), fill=(70, 70, 76))
    d.text((Wc - 220, 40), f"No. {number}", font=sans(34, True), fill=INK)
    d.text((Wc - 520, 140), "Date", font=sans(26), fill=(70, 70, 76))
    d.text((Wc - 440, 132), date, font=sans(34), fill=INK)
    d.line([(Wc - 445, 172), (Wc - 60, 172)], fill=(90, 90, 96), width=2)
    d.text((48, 232), "PAY TO THE", font=sans(22), fill=(70, 70, 76))
    d.text((48, 258), "ORDER OF", font=sans(22), fill=(70, 70, 76))
    d.text((190, 240), payee, font=sans(38), fill=INK)
    d.line([(185, 290), (Wc - 330, 290)], fill=(90, 90, 96), width=2)
    d.rectangle([Wc - 300, 228, Wc - 60, 292], outline=(90, 90, 96), width=2)
    d.text((Wc - 285, 240), f"$ {amount}", font=sans(38, True), fill=INK)
    d.text((48, 330), words, font=sans(32), fill=INK)
    d.line([(44, 372), (Wc - 250, 372)], fill=(90, 90, 96), width=2)
    d.text((Wc - 230, 340), "DOLLARS", font=sans(24), fill=(70, 70, 76))
    d.text((48, 440), "MEMO", font=sans(24), fill=(70, 70, 76))
    d.text((140, 430), memo, font=sans(32), fill=INK)
    d.line([(135, 472), (640, 472)], fill=(90, 90, 96), width=2)
    d.text((Wc - 520, 476), signer, font=ImageFont.truetype("/System/Library/Fonts/Supplemental/SnellRoundhand.ttc", 46), fill=(30, 40, 110))
    d.line([(Wc - 560, 530), (Wc - 60, 530)], fill=(90, 90, 96), width=2)
    d.text((Wc - 470, 538), "AUTHORIZED SIGNATURE", font=sans(18), fill=(90, 90, 96))
    d.text((120, 548), f"C{number}C  A073922196A  4801{number}C", font=mono(34), fill=INK)
    img.save(os.path.join(out, name))
    print("wrote", name, img.size)


check("check.png", "Computer Science Club", "1042", "11/18/2026", "Decorah Makerspace", "150.00",
      "One hundred fifty and 00/100", "Soldering workshop", "Priya Shah", out=FIXTURES)
check("check-uptous.png", "Up to Us", "2207", "11/19/2026", "Decorah Public Library", "40.00",
      "Forty and 00/100", "Room rental - Day of Action", "Alex Rivera")
