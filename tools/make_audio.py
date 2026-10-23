# Генератор звуков и музыки в стиле ретро-игр (без внешних библиотек).
# Запуск:  python tools/make_audio.py
# Результат: audio/sfx/*.wav и audio/music/*.wav

import math, random, struct, wave, os

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "audio")
random.seed(7)

# ---------- базовые «инструменты» ----------
def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0

def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p

def noise(_phase=0):
    return random.uniform(-1, 1)

def tone(freq_fn, dur, wave_fn=square, env=None, vol=0.5, duty=0.5):
    """freq_fn(t) -> частота; env(t, dur) -> громкость 0..1"""
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += freq_fn(t) / RATE
        if wave_fn is square:
            s = square(phase, duty)
        else:
            s = wave_fn(phase)
        e = env(t, dur) if env else 1.0
        out.append(s * e * vol)
    return out

def decay(k):
    return lambda t, d: math.exp(-k * t)

def adsr(a=0.005, r=0.05):
    def f(t, d):
        if t < a:
            return t / a
        if t > d - r:
            return max(0.0, (d - t) / r)
        return 1.0
    return f

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, s in enumerate(tr):
            out[i] += s
    return out

def concat(*parts):
    out = []
    for p in parts:
        out += p
    return out

def silence(dur):
    return [0.0] * int(dur * RATE)

def save(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print("saved", os.path.relpath(path, ROOT), "%.2fs" % (len(samples) / RATE))

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)

# ---------- звуковые эффекты ----------
def sfx():
    d = os.path.join(ROOT, "sfx")
    # прыжок: быстрый взлёт тона
    save(os.path.join(d, "jump.wav"), tone(lambda t: 300 + 900 * t / 0.15, 0.15, square, adsr(0.005, 0.06), 0.35, 0.25))
    # батарейка: весёлое арпеджио
    notes = [76, 80, 83, 88]
    save(os.path.join(d, "battery.wav"), concat(*[tone(lambda t, f=midi(n): f, 0.06, square, adsr(0.002, 0.03), 0.3, 0.5) for n in notes],
                                               tone(lambda t: midi(88), 0.18, square, decay(12), 0.3, 0.5)))
    # удар: шум + падающий низкий тон
    save(os.path.join(d, "hit.wav"), mix(tone(lambda t: 1, 0.18, noise, decay(18), 0.5),
                                          tone(lambda t: 220 - 500 * t, 0.25, square, decay(10), 0.4, 0.4)))
    # падение: долгий «свист вниз»
    save(os.path.join(d, "fall.wav"), tone(lambda t: 900 * math.exp(-2.2 * t), 0.7, triangle, adsr(0.01, 0.2), 0.5))
    # батут: «боинг» с дрожанием
    save(os.path.join(d, "launch.wav"), tone(lambda t: (180 + 700 * t / 0.4) * (1 + 0.08 * math.sin(t * 2 * math.pi * 30)), 0.4, square, adsr(0.005, 0.15), 0.35, 0.35))
    # выстрел турели: «пиу»
    save(os.path.join(d, "shoot.wav"), tone(lambda t: 1400 * math.exp(-14 * t) + 120, 0.2, square, decay(12), 0.3, 0.3))
    # рассыпающаяся платформа: треск
    crackle = []
    for k in range(10):
        crackle += tone(lambda t: 1, random.uniform(0.02, 0.05), noise, decay(60), random.uniform(0.2, 0.5))
        crackle += silence(random.uniform(0.0, 0.04))
    save(os.path.join(d, "crumble.wav"), crackle)
    # шипы: металлический «дзынь»
    save(os.path.join(d, "spikes.wav"), mix(tone(lambda t: 1, 0.08, noise, decay(40), 0.25),
                                             tone(lambda t: 1800, 0.15, square, decay(30), 0.15, 0.2)))
    # дрон заметил робота: короткий тревожный писк
    save(os.path.join(d, "alert.wav"), concat(tone(lambda t: 1200, 0.07, square, adsr(0.002, 0.02), 0.25, 0.5), silence(0.03),
                                              tone(lambda t: 1500, 0.07, square, adsr(0.002, 0.02), 0.25, 0.5)))
    # все батарейки собраны: фанфары
    fan = [(72, 0.1), (76, 0.1), (79, 0.1), (84, 0.35)]
    save(os.path.join(d, "all_collected.wav"), concat(*[tone(lambda t, f=midi(n): f, dur, square, adsr(0.005, 0.05), 0.3, 0.5) for n, dur in fan]))
    # уровень пройден: длинная победная мелодия с басом
    win = [(72, 0.12), (76, 0.12), (79, 0.12), (84, 0.24), (79, 0.12), (84, 0.5)]
    lead = concat(*[tone(lambda t, f=midi(n): f, dur, square, adsr(0.005, 0.05), 0.3, 0.5) for n, dur in win])
    bass = concat(tone(lambda t: midi(48), 0.6, triangle, adsr(0.01, 0.05), 0.4), tone(lambda t: midi(43), 0.62, triangle, adsr(0.01, 0.2), 0.4))
    save(os.path.join(d, "level_complete.wav"), mix(lead, bass))
    # эффект батарейки: маленький бонус — две быстрые нотки вверх с блеском
    save(os.path.join(d, "boost_small.wav"), concat(tone(lambda t: midi(84), 0.06, square, adsr(0.002, 0.03), 0.25, 0.25),
                                                   tone(lambda t: midi(91), 0.16, square, decay(14), 0.25, 0.25)))
    # эффект батарейки: большой бонус — взлетающая гамма и «искрящийся» хвост
    rise = [72, 76, 79, 84, 88, 91]
    sparkle = mix(tone(lambda t: midi(96) * (1 + 0.03 * math.sin(t * 2 * math.pi * 18)), 0.45, square, decay(6), 0.18, 0.125),
                  tone(lambda t: 1, 0.45, noise, decay(9), 0.06))
    save(os.path.join(d, "boost_big.wav"), concat(*[tone(lambda t, f=midi(n): f, 0.05, square, adsr(0.002, 0.02), 0.28, 0.25) for n in rise], sparkle))
    # эффект батарейки: помеха — «сдувающийся» звук вниз с дрожанием
    save(os.path.join(d, "debuff.wav"), tone(lambda t: (420 - 520 * t) * (1 + 0.06 * math.sin(t * 2 * math.pi * 12)), 0.55, square, adsr(0.01, 0.2), 0.3, 0.4))
    # эффект закончился: мягкий короткий спуск
    save(os.path.join(d, "effect_end.wav"), concat(tone(lambda t: midi(79), 0.07, triangle, adsr(0.005, 0.03), 0.35),
                                                  tone(lambda t: midi(72), 0.14, triangle, decay(14), 0.35)))
    # заряд кончился: грустный спуск
    lose = [(67, 0.2), (66, 0.2), (65, 0.2), (64, 0.6)]
    save(os.path.join(d, "game_over.wav"), concat(*[tone(lambda t, f=midi(n): f * (1 + 0.01 * math.sin(t * 40)), dur, triangle, adsr(0.01, 0.08), 0.45) for n, dur in lose]))

# ---------- музыка ----------
def song(path, bpm, chords, melody, bass_pattern, drums, bars, lead_duty=0.5, lead_vol=0.16):
    beat = 60.0 / bpm
    step = beat / 2                      # восьмая нота
    total = int(bars * 8 * step * RATE)
    out = [0.0] * total
    def add(start_s, samples):
        i0 = int(start_s * RATE)
        for k, s in enumerate(samples):
            if i0 + k < total:
                out[i0 + k] += s
    for bar in range(bars):
        root = chords[bar % len(chords)]
        # бас
        for k, off in enumerate(bass_pattern):
            if off is None:
                continue
            add((bar * 8 + k) * step, tone(lambda t, f=midi(root + off - 12): f, step * 0.9, triangle, adsr(0.005, 0.03), 0.32))
        # мелодия
        line = melody[bar % len(melody)]
        for k, n in enumerate(line):
            if n is None:
                continue
            length = 1
            while k + length < 8 and line[k + length] == "-":
                length += 1
            if n == "-":
                continue
            add((bar * 8 + k) * step, tone(lambda t, f=midi(n): f * (1 + 0.004 * math.sin(t * 30)), step * length * 0.92, square, adsr(0.005, 0.04), lead_vol, lead_duty))
        # ударные
        for k, hit in enumerate(drums):
            st = (bar * 8 + k) * step
            if hit == "K":
                add(st, tone(lambda t: 120 * math.exp(-25 * t) + 40, 0.15, triangle, decay(18), 0.5))
            elif hit == "S":
                add(st, tone(lambda t: 1, 0.12, noise, decay(25), 0.22))
            elif hit == "h":
                add(st, tone(lambda t: 1, 0.03, noise, decay(90), 0.08))
    save(path, out)

def music():
    d = os.path.join(ROOT, "music")
    # Уровень 1 «Остров»: бодро, до мажор
    _ = None
    melody1 = [
        [72, "-", 76, 79, "-", 76, 74, 72], [69, "-", 72, 76, "-", 74, 72, _],
        [65, "-", 69, 72, "-", 74, 72, 69], [67, "-", "-", 71, 74, "-", 71, 67],
        [72, 74, 76, "-", 79, "-", 76, 74], [76, "-", 72, "-", 69, 72, 76, _],
        [77, "-", 76, 74, 72, "-", 69, 72], [74, "-", "-", _, 71, 72, 74, _],
    ]
    song(os.path.join(d, "island.wav"), 124, [60, 57, 53, 55], melody1, [0, _, 12, _, 7, _, 12, 7],
         ["K", "h", "S", "h", "K", "K", "S", "h"], 16)
    # Уровень 2 «Башня»: напряжённо, ля минор, быстрее
    melody2 = [
        [69, _, 72, 69, 76, _, 74, 72], [71, _, 69, 68, 69, "-", "-", _],
        [69, 72, 76, "-", 77, 76, 74, 72], [71, "-", 68, "-", 64, "-", _, 68],
        [81, "-", 79, 77, 76, "-", 74, 72], [74, _, 72, 71, 72, "-", 69, _],
        [77, "-", 76, "-", 74, "-", 72, 74], [76, "-", "-", 75, 76, _, _, _],
    ]
    song(os.path.join(d, "tower.wav"), 138, [57, 53, 55, 52], melody2, [0, 0, 12, 0, 0, 12, 7, 12],
         ["K", "h", "S", "K", "K", "h", "S", "h"], 16, lead_duty=0.25, lead_vol=0.14)

if __name__ == "__main__":
    sfx()
    music()
