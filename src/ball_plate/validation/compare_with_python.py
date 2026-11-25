"""Compares the Simulink runs produced by run_validation.m against the
Python replica (python_reference_sim.py) under the same conditions.

Usage:  python3 compare_with_python.py [results_dir]   (default: ./results)
"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from python_reference_sim import params, design, simulate  # noqa: E402

R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'results')
P = design(params())
P25 = dict(P); P25['Tcam'] = 0.04
tgt = np.array([0.08, -0.05])
rf = lambda t: tgt if t > 1 else np.zeros(2)
tap = lambda t: (0.2, 0.2) if 1 < t < 1.05 else (0.0, 0.0)
circ = lambda t: 0.06*np.array([np.cos(0.4*np.pi*t), np.sin(0.4*np.pi*t)])
x_ic = [0.08, 0, -0.05, 0, 0, 0, 0, 0]

cases = {}
for name, mode in (('lqr', 3), ('cascade', 2)):
    cases[name + '_ic'] = (P, x_ic, mode, 5, None, None, (0, 0))
    cases[name + '_step'] = (P, [0]*8, mode, 6, rf, None, (0, 0))
    cases[name + '_tap'] = (P, [0]*8, mode, 4, None, tap, (0, 0))
    cases[name + '_circle'] = (P, [0.06] + [0]*7, mode, 15, circ, None, (0, 0))
cases['cascade_step_25fps'] = (P25, [0]*8, 2, 6, rf, None, (0, 0))
cases['plate_tilt'] = (P, [0]*8, 1, 4, None, None, (np.radians(-1), np.radians(0.5)))


def settle(t, e, tol):
    i = np.where(np.abs(e) > tol)[0]
    return t[i[-1]] if len(i) else 0.0


def load(name):
    return np.loadtxt(os.path.join(R, name + '.csv'), delimiter=',')


print(f"{'case':19s} {'RMS dpos[mm]':>12s} {'max':>7s} {'RMS dtilt[deg]':>14s} {'max':>7s}"
      " | metric python / simulink")
for name, (PP, x0, mode, T, ref, push, alman) in cases.items():
    L = simulate(PP, x0, mode, T, ref=ref or (lambda t: np.zeros(2)), push=push, alman=alman)
    tp = L[:, 0]; pp = L[:, [1, 3]]; ap = L[:, [5, 7]]; Vp = L[:, 9:11]
    M = load(name)
    ts = M[:, 0]; ps = M[:, [1, 3]]; as_ = M[:, [5, 7]]; Vs = M[:, 9:11]
    dp = 1e3*np.hypot(*(np.column_stack([np.interp(tp, ts, ps[:, i]) for i in range(2)]) - pp).T)
    da = np.degrees(np.column_stack([np.interp(tp, ts, as_[:, i]) for i in range(2)]) - ap)
    da = np.hypot(da[:, 0], da[:, 1])
    if 'step' in name:
        ep, es = np.hypot(*(pp - tgt).T), np.hypot(*(ps - tgt).T)
        m = (f"settle(5mm) {settle(tp, ep, 0.005) - 1:.2f} / {settle(ts, es, 0.005) - 1:.2f} s,"
             f" overshoot x {100*(pp[:, 0].max() - 0.08)/0.08:.1f} / {100*(ps[:, 0].max() - 0.08)/0.08:.1f} %")
    elif name.endswith('_ic'):
        m = (f"settle(5mm) {settle(tp, np.hypot(*pp.T), 0.005):.2f} / {settle(ts, np.hypot(*ps.T), 0.005):.2f} s,"
             f" Vmax {np.abs(Vp).max():.1f} / {np.abs(Vs).max():.1f} V")
    elif name.endswith('_tap'):
        m = (f"max dist {100*np.hypot(*pp.T).max():.2f} / {100*np.hypot(*ps.T).max():.2f} cm")
    elif name.endswith('_circle'):
        rp_, rs = np.hypot(*pp[tp > 5].T), np.hypot(*ps[ts > 5].T)
        m = (f"radius {100*rp_.mean():.2f} ({100*rp_.min():.2f}-{100*rp_.max():.2f}) / "
             f"{100*rs.mean():.2f} ({100*rs.min():.2f}-{100*rs.max():.2f}) cm")
    else:
        i_p = np.argmax(np.abs(pp).max(1) > 0.135); i_s = np.argmax(np.abs(ps).max(1) > 0.135)
        m = f"reaches the rim at {tp[i_p]:.3f} / {ts[i_s]:.3f} s"
    print(f"{name:19s} {np.sqrt(np.mean(dp**2)):12.3f} {dp.max():7.3f} "
          f"{np.sqrt(np.mean(da**2)):14.3f} {da.max():7.3f} | {m}")

print()
for name in ('lqr_step_ratelim', 'cascade_step_ratelim'):
    M = load(name); ts, ps = M[:, 0], M[:, [1, 3]]
    print(f"{name}: settle(5mm) {settle(ts, np.hypot(*(ps - tgt).T), 0.005) - 1:.2f} s, "
          f"overshoot x {100*(ps[:, 0].max() - 0.08)/0.08:.1f} %, Vmax {np.abs(M[:, 9:11]).max():.1f} V")
for name in ('lqr_eight', 'lqr_circle_fast'):
    M = load(name); k = M[:, 0] > 5
    e = np.hypot(M[k, 1] - M[k, 11], M[k, 3] - M[k, 12])
    print(f"{name}: tracking error RMS {1e3*np.sqrt(np.mean(e**2)):.1f} mm, max {1e3*e.max():.1f} mm, "
          f"Vmax {np.abs(M[:, 9:11]).max():.1f} V, max tilt {np.degrees(np.abs(M[:, [5, 7]])).max():.1f} deg")
M = load('lqr_noise'); k = M[:, 0] > 2
print(f"noise on: ball std after 2 s {1e3*M[k, 1].std():.2f} / {1e3*M[k, 3].std():.2f} mm, "
      f"V std {M[k, 9].std():.2f} / {M[k, 10].std():.2f} V")
