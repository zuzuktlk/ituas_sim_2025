#!/usr/bin/env python3
"""Bir STL govdesinin hidrostatigi: verilen kutle icin su hatti, su cekimi,
kaldirma merkezi ve su hatti alani.

Yontem: govdeyi ustten h x h izgaraya bol; her karenin ortasindan dikey
cizgi gecirip govde dibini (en alt ucgeni) bul; su hatti zw ise o sutunun
su altindaki yuksekligi max(0, zw - dip). Hacim = toplam * h^2.
zw, hacim = kutle / yogunluk olana kadar ikiye bolmeyle aranir.
Varsayim: govde dipten su hattina kadar dolu (ponton icin dogru).

Kullanim:
  python3 hull_hydrostatics.py govde.stl --mass 30 [--scale 1] [--rho 1000] [--grid 0.005]
Yalnizca numpy gerekir.
"""
import argparse, numpy as np

def load_binary_stl(path):
    with open(path, 'rb') as f:
        f.read(80)
        n = int(np.frombuffer(f.read(4), '<u4')[0])
        dt = np.dtype([('n', '<f4', 3), ('v', '<f4', (3, 3)), ('a', '<u2')])
        d = np.frombuffer(f.read(n * 50), dt, count=n)
    return d['v'].astype(np.float64)

def bottom_map(V, h):
    x0, y0 = V[..., 0].min(), V[..., 1].min()
    nx = int((V[..., 0].max() - x0) / h) + 2
    ny = int((V[..., 1].max() - y0) / h) + 2
    zb = np.full((nx, ny), np.inf)
    i0 = np.ceil((V[..., 0].min(1) - x0) / h - 0.5).astype(int)
    i1 = np.floor((V[..., 0].max(1) - x0) / h - 0.5).astype(int)
    j0 = np.ceil((V[..., 1].min(1) - y0) / h - 0.5).astype(int)
    j1 = np.floor((V[..., 1].max(1) - y0) / h - 0.5).astype(int)
    for t in np.where((i1 >= i0) & (j1 >= j0))[0]:
        A, B, C = V[t]
        ii = np.arange(i0[t], i1[t] + 1); jj = np.arange(j0[t], j1[t] + 1)
        X, Y = np.meshgrid(x0 + (ii + 0.5) * h, y0 + (jj + 0.5) * h, indexing='ij')
        d = (B[1]-C[1])*(A[0]-C[0]) + (C[0]-B[0])*(A[1]-C[1])
        if abs(d) < 1e-14:
            continue
        l1 = ((B[1]-C[1])*(X-C[0]) + (C[0]-B[0])*(Y-C[1])) / d
        l2 = ((C[1]-A[1])*(X-C[0]) + (A[0]-C[0])*(Y-C[1])) / d
        l3 = 1 - l1 - l2
        m = (l1 >= -1e-9) & (l2 >= -1e-9) & (l3 >= -1e-9)
        if m.any():
            Z = l1*A[2] + l2*B[2] + l3*C[2]
            sub = zb[np.ix_(ii, jj)]
            zb[np.ix_(ii, jj)] = np.where(m, np.minimum(sub, Z), sub)
    X = x0 + (np.arange(nx) + 0.5) * h
    Y = y0 + (np.arange(ny) + 0.5) * h
    return zb, *np.meshgrid(X, Y, indexing='ij')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stl'); ap.add_argument('--mass', type=float, required=True)
    ap.add_argument('--scale', type=float, default=1.0)
    ap.add_argument('--rho', type=float, default=1000.0)
    ap.add_argument('--grid', type=float, default=0.005)
    a = ap.parse_args()
    V = load_binary_stl(a.stl) * a.scale
    zb, XX, YY = bottom_map(V, a.grid)
    f = np.isfinite(zb); z, x, y = zb[f], XX[f], YY[f]
    vol = lambda zw: np.clip(zw - z, 0, None).sum() * a.grid**2
    target = a.mass / a.rho
    lo, hi = z.min(), z.max()
    for _ in range(60):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if vol(mid) < target else (lo, mid)
    zw = lo; keel = np.percentile(z, 2); d = np.clip(zw - z, 0, None)
    Vt = d.sum() * a.grid**2
    print(f'boyut (x,y,z): {np.ptp(V[...,0]):.3f} x {np.ptp(V[...,1]):.3f} x {np.ptp(V[...,2]):.3f} m')
    print(f'kutle {a.mass} kg, yogunluk {a.rho} -> hacim {target*1000:.1f} L')
    print(f'su hatti z = {zw:.3f} m (STL koordinatinda), omurga z = {keel:.3f} m')
    print(f'su cekimi = {100*(zw-keel):.1f} cm')
    print(f'kaldirma merkezi x={(d*x).sum()*a.grid**2/Vt:.3f} y={(d*y).sum()*a.grid**2/Vt:.3f} '
          f'z={((zw+z)/2*d).sum()*a.grid**2/Vt:.3f} m')
    print(f'su hatti alani = {(z < zw).sum()*a.grid**2:.3f} m2 '
          f'(1 kg ek yuk ~ {0.1/((z < zw).sum()*a.grid**2)/ (a.rho/1000):.2f} cm batma)')

if __name__ == '__main__':
    main()
