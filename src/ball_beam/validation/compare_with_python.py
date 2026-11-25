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
Pn = dict(P); Pn['ff_on'] = 0; Pn['Ki_x'] = 0.0
rf = lambda t: 0.1 if t > 1 else 0.0
tap = lambda t: 0.2 if 1 < t < 1.05 else 0.0

cases = {}
for name, mode in (('lqr', 3), ('cascade', 2)):
    cases[name + '_ic'] = (P, [0.1, 0, 0, 0], mode, 5, None, None, 0.0)
    cases[name + '_step'] = (P, [0, 0, 0, 0], mode, 6, rf, None, 0.0)
    cases[name + '_tap'] = (P, [0, 0, 0, 0], mode, 4, None, tap, 0.0)
cases['cascade_noff'] = (Pn, [0, 0, 0, 0], 2, 6, rf, None, 0.0)
cases['beam_tilt'] = (P, [0, 0, 0, 0], 1, 3, None, None, np.radians(-2))


def settle(t, e, tol):
    i = np.where(np.abs(e) > tol)[0]
    return t[i[-1]] if len(i) else 0.0


def load(name):
    return np.loadtxt(os.path.join(R, name + '.csv'), delimiter=',')


print(f"{'case':14s} {'RMS dx[mm]':>10s} {'max dx':>8s} {'RMS dal[deg]':>12s} {'max dal':>8s}"
      " | metric python vs simulink")
for name, (PP, x0, mode, T, ref, push, alman) in cases.items():
    L = simulate(PP, x0, mode, T, ref=ref or (lambda t: 0.0), push=push, alman=alman)
    tp, xp, alp, Vp = L[:, 0], L[:, 1], L[:, 3], L[:, 5]
    M = load(name)
    ts, xs, als, Vs = M[:, 0], M[:, 1], M[:, 3], M[:, 5]
    dx = 1e3*(np.interp(tp, ts, xs) - xp)
    dal = np.degrees(np.interp(tp, ts, als) - alp)
    if 'step' in name or 'noff' in name:
        m = (f"settle(5mm) {settle(tp, xp - 0.1, 0.005) - 1:.2f} / {settle(ts, xs - 0.1, 0.005) - 1:.2f} s,"
             f" overshoot {100*(xp.max() - 0.1)/0.1:.1f} / {100*(xs.max() - 0.1)/0.1:.1f} %,"
             f" final {100*xp[-1]:.2f} / {100*xs[-1]:.2f} cm")
    elif name.endswith('_ic'):
        m = (f"settle(5mm) {settle(tp, xp, 0.005):.2f} / {settle(ts, xs, 0.005):.2f} s,"
             f" Vmax {np.abs(Vp).max():.1f} / {np.abs(Vs).max():.1f} V")
    elif name.endswith('_tap'):
        m = (f"max|x| {100*np.abs(xp).max():.2f} / {100*np.abs(xs).max():.2f} cm,"
             f" settle(2mm) {settle(tp, xp, 0.002) - 1:.2f} / {settle(ts, xs, 0.002) - 1:.2f} s")
    else:
        i_p, i_s = np.argmax(np.abs(xp) > 0.185), np.argmax(np.abs(xs) > 0.185)
        m = (f"reaches the stop at {tp[i_p]:.3f} / {ts[i_s]:.3f} s,"
             f" final alpha {np.degrees(alp[-1]):.2f} / {np.degrees(als[-1]):.2f} deg")
    print(f"{name:14s} {np.sqrt(np.mean(dx**2)):10.3f} {np.abs(dx).max():8.3f} "
          f"{np.sqrt(np.mean(dal**2)):12.3f} {np.abs(dal).max():8.3f} | {m}")

print()
for name in ('lqr_step_ratelim', 'cascade_step_ratelim'):
    M = load(name); ts, xs = M[:, 0], M[:, 1]
    print(f"{name}: settle(5mm) {settle(ts, xs - 0.1, 0.005) - 1:.2f} s, "
          f"overshoot {100*(xs.max() - 0.1)/0.1:.1f} %, Vmax {np.abs(M[:, 6]).max():.1f} V")
for m in ('lqr', 'cascade'):
    for f in ('0.1', '0.25', '0.5'):
        M = load(f'sine_{m}_{f}'); ts, x, r = M[:, 0], M[:, 1], M[:, 7]; k = ts > 8
        E = np.exp(-1j*2*np.pi*float(f)*ts[k]); gx, gr = np.sum(x[k]*E), np.sum(r[k]*E)
        print(f"sine {m:7s} {f:>4s} Hz: gain {abs(gx/gr):.3f}, phase lag {np.degrees(np.angle(gr/gx)):.1f} deg, "
              f"Vmax {np.abs(M[:, 6]).max():.1f} V")
M = load('lqr_noise'); k = M[:, 0] > 2
print(f"noise on: x std after 2 s {1e3*M[k, 1].std():.2f} mm, V std {M[k, 6].std():.2f} V, "
      f"alpha std {np.degrees(M[k, 3]).std():.3f} deg")
