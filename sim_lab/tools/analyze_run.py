#!/usr/bin/env python3
"""thrust_test.sh ciktisini (t,x,y,z,roll,pitch,yaw) ozetler.

Kullanim:
    python3 tools/analyze_run.py logs/fixed_flat_thrust_-40_-40.csv
    python3 tools/analyze_run.py logs/fixed_flat_thrust_-40_-40_stop10.csv --stop 10

Yazdiklari:
  - her saniye: hiz (m/s), donus hizi (derece/s), baş-kıç (pitch, derece)
  - itki bolumunun son 3 saniyesi: ortalama hiz, donus hizi, donus yaricapi
  - --stop verilirse: motorlar durduktan sonra kat edilen yol ve hizin 0.1 m/s'ye inme suresi
Hiz, x-y konumunun 0.5 s'lik pencerede farki alinarak hesaplanir.
"""
import argparse
import csv
import math
import sys


def read(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({k: float(v) for k, v in r.items()})
    if len(rows) < 10:
        sys.exit(f"Cok az satir ({len(rows)}). Kayit bos olabilir.")
    return rows


def unwrap(a):
    out, off = [a[0]], 0.0
    for p, c in zip(a, a[1:]):
        d = c - p
        if d > math.pi:
            off -= 2 * math.pi
        elif d < -math.pi:
            off += 2 * math.pi
        out.append(c + off)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--stop", type=float, default=0.0,
                    help="thrust_test.sh'e verilen durus suresi (s)")
    a = ap.parse_args()

    R = read(a.csv)
    t = [r["t"] for r in R]
    x = [r["x"] for r in R]
    y = [r["y"] for r in R]
    yaw = unwrap([r["yaw"] for r in R])
    t0 = t[0]

    # 0.5 s pencere ile hiz ve donus hizi
    spd, yr, tm = [], [], []
    j = 0
    for i in range(len(t)):
        while t[i] - t[j] > 0.5:
            j += 1
        dt = t[i] - t[j]
        if dt < 0.3:
            continue
        spd.append(math.hypot(x[i] - x[j], y[i] - y[j]) / dt)
        yr.append((yaw[i] - yaw[j]) / dt)
        tm.append(t[i])

    print(f"Dosya: {a.csv}   sure: {t[-1]-t0:.1f} s   satir: {len(t)}")
    print(" t(s)   hiz(m/s)  donus(der/s)  pitch(der)")
    nxt = t0
    for k, tk in enumerate(tm):
        if tk >= nxt:
            i = min(range(len(t)), key=lambda n: abs(t[n] - tk))
            print(f"{tk-t0:5.1f}   {spd[k]:7.3f}   {math.degrees(yr[k]):10.2f}   "
                  f"{math.degrees(R[i]['pitch']):8.2f}")
            nxt += 1.0

    # itki bolumu sonu: kayit sonundan (durus + ~1.5 s) once biter
    t_end_thrust = t[-1] - a.stop - 1.5
    win = [k for k, tk in enumerate(tm) if t_end_thrust - 3.0 <= tk <= t_end_thrust]
    if win:
        v = sum(spd[k] for k in win) / len(win)
        r = sum(yr[k] for k in win) / len(win)
        print("\nItki bolumunun son 3 s ortalamasi:")
        print(f"  hiz            : {v:.3f} m/s")
        print(f"  donus hizi     : {math.degrees(r):.2f} der/s ({r:.4f} rad/s)")
        if abs(r) > 1e-3:
            print(f"  donus yaricapi : {v/abs(r):.2f} m")
        else:
            print("  donus yaricapi : (neredeyse duz gidiyor)")

    if a.stop > 0:
        ks = [k for k, tk in enumerate(tm) if tk >= t_end_thrust]
        if ks:
            k0 = ks[0]
            i0 = min(range(len(t)), key=lambda n: abs(t[n] - tm[k0]))
            dist = sum(math.hypot(x[n+1]-x[n], y[n+1]-y[n]) for n in range(i0, len(t)-1))
            t01 = next((tm[k] - tm[k0] for k in ks if spd[k] < 0.1), None)
            print("\nDurma (motorlar 0):")
            print(f"  baslangic hizi : {spd[k0]:.3f} m/s")
            print(f"  kat edilen yol : {dist:.2f} m (kayit sonuna kadar)")
            print("  0.1 m/s'ye inme: " + (f"{t01:.1f} s" if t01 is not None
                                           else f"kayit icinde inmedi (>{a.stop:.0f} s)"))


if __name__ == "__main__":
    main()
