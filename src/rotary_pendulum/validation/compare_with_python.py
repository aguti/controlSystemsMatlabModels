"""Compares the Simulink runs produced by run_validation.m against the
Python replica (python_reference_sim.py) under the same conditions.

Usage:  python3 compare_with_python.py [results_dir]   (default: ./results)
"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from python_reference_sim import params, design, simulate, wrap  # noqa: E402

R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'results')
P = design(params())
d45 = np.radians(45)
rf = lambda t: d45 if t > 1 else 0.0
Pn = dict(P); Kn = P['K_dn'].copy(); Kn[0, 2:] = 0; Pn['K_dn'] = Kn

cases = {
    'lqr_ic':      (P, [0, 0, np.radians(10), 0], 1, 4, None, None),
    'lqr_step':    (P, [0, 0, 0, 0], 1, 6, rf, None),
    'lqr_push':    (P, [0, 0, 0, 0], 1, 4, None, lambda t: 0.1 if 1 < t < 1.05 else 0.0),
    'swingup':     (P, [0, 0, np.pi, 0], 2, 8, None, None),
    'pid_ic':      (P, [0, 0, np.radians(10), 0], 3, 4, None, None),
    'pid_step':    (P, [0, 0, 0, 0], 3, 6, rf, None),
    'down_step':   (P, [0, 0, np.pi, 0], 4, 6, rf, None),
    'down_nosway': (Pn, [0, 0, np.pi, 0], 4, 6, rf, None),
}


def settle(t, y, tol):
    i = np.where(np.abs(y) > tol)[0]
    return t[i[-1]] if len(i) else 0.0


def load(name):
    return np.loadtxt(os.path.join(R, name + '.csv'), delimiter=',')


print(f"{'case':12s} {'RMS dth[deg]':>12s} {'max dth':>8s} {'RMS dal[deg]':>12s} {'max dal':>8s}"
      " | metric python vs simulink")
for name, (PP, x0, mode, T, ref, push) in cases.items():
    L = simulate(PP, x0, mode, T, ref=ref or (lambda t: 0.0), push=push)
    tp, thp, alp = L[:, 0], L[:, 1], L[:, 3]
    M = load(name)
    ts, ths, als = M[:, 0], M[:, 1], M[:, 3]
    dth = np.degrees(np.interp(tp, ts, ths) - thp)
    dal = np.degrees(wrap(np.interp(tp, ts, np.unwrap(als)) - np.unwrap(alp)))
    thd_p, thd_s = np.degrees(thp), np.degrees(ths)
    if name.startswith('down'):
        sp = np.degrees(np.abs(wrap(alp[tp > 4] - np.pi))).max()
        ss = np.degrees(np.abs(wrap(als[ts > 4] - np.pi))).max()
        m = f"residual sway t>4s: {sp:.2f} vs {ss:.2f} deg"
    elif name == 'swingup':
        cp_, cs = tp[np.argmax(L[:, 6] > 0)], ts[np.argmax(M[:, 7] > 0)]
        m = (f"catch {cp_:.3f} vs {cs:.3f} s, max|th| {np.abs(thd_p).max():.1f} vs "
             f"{np.abs(thd_s).max():.1f} deg")
    elif 'step' in name:
        m = (f"th settle(5%) {settle(tp, thd_p - 45, 2.25) - 1:.2f} vs {settle(ts, thd_s - 45, 2.25) - 1:.2f} s,"
             f" min th {thd_p.min():.1f} vs {thd_s.min():.1f} deg")
    else:
        m = (f"al settle(1deg) {settle(tp, np.degrees(wrap(alp)), 1):.2f} vs "
             f"{settle(ts, np.degrees(wrap(als)), 1):.2f} s, Vmax {np.abs(L[:, 5]).max():.1f} vs "
             f"{np.abs(M[:, 5]).max():.1f} V")
    print(f"{name:12s} {np.sqrt(np.mean(dth**2)):12.3f} {np.abs(dth).max():8.3f} "
          f"{np.sqrt(np.mean(dal**2)):12.3f} {np.abs(dal).max():8.3f} | {m}")

print()
M = load('lqr_step_ratelim'); ts, th = M[:, 0], np.degrees(M[:, 1])
print(f"lqr_step_ratelim: th settle(5%) {settle(ts, th - 45, 2.25) - 1:.2f} s, "
      f"min th {th.min():.1f} deg, Vmax {np.abs(M[:, 6]).max():.1f} V")
for f in ['0.2', '0.5', '1']:
    M = load('sine_' + f); ts, th, r = M[:, 0], M[:, 1], M[:, 8]; k = ts > 5
    E = np.exp(-1j*2*np.pi*float(f)*ts[k]); gx, gr = np.sum(th[k]*E), np.sum(r[k]*E)
    print(f"sine {f} Hz: gain {abs(gx/gr):.3f}, phase lag {np.degrees(np.angle(gr/gx)):.1f} deg, "
          f"Vmax {np.abs(M[:, 6]).max():.1f} V, tripped={int(M[:, 9].max())}")
M = load('lqr_ic_noise'); k = M[:, 0] > 2
print(f"noise on: alpha std after 2 s {np.degrees(M[k, 3]).std():.3f} deg, "
      f"V std {M[k, 6].std():.2f} V, theta std {np.degrees(M[k, 1]).std():.2f} deg")
