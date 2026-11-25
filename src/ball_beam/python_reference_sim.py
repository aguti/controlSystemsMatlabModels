"""Python replica of the MATLAB/Simulink ball and beam model.

Used to design and cross-validate the dynamics, gains and controller modes
independently of Simulink (see validation/compare_with_python.py).
State: s = [x, x_dot, alpha, alpha_dot]
  x      ball position along the beam [m] (0 = pivot, + towards the right end)
  alpha  beam angle [rad] (0 = horizontal; alpha > 0 raises the +x end)
Input: motor voltage V [V].
"""
import numpy as np
from scipy.linalg import solve_continuous_are


def params():
    P = dict(
        # ball (solid steel sphere)
        m=0.067, rb=0.0127, bx=2e-3,
        # beam (pivoted at its centre, driven directly by the gearbox output)
        L=0.42, mbeam=0.35,
        g=9.81,
        # beam friction
        Db=1e-3, Tc=0.01, w_eps=0.05,
        # DC motor + gearbox + amplifier
        Rm=2.6, kt=0.00768, km=0.00768, Jm=3.9e-7, Kg=70.0, eta_g=0.9, eta_m=0.69,
        Vmax=10.0,
        # mechanical stops
        al_max=0.35, k_al=200.0, c_al=2.0,
        k_x=2000.0, c_x=5.0,
        # sensors / timing
        res_al=2*np.pi/4096, res_x=0.42/4096,
        Ts=0.002, h=0.001, tau_v=0.005, tau_x=0.02,
        # beam angle loop (PD)
        Kp_a=40.0, Kd_a=1.5,
        # ball loop (cascade PID -> beam angle reference)
        Kp_x=1.3, Kd_x=0.8, Ki_x=0.1, I_max=0.5, al_ref_max=0.25,
        e_int=0.02,   # integrate only when |x - r| < e_int (conditional anti-windup)
        ff_on=1,      # 1 = compensate the ball weight torque on the beam (feedforward)
        # LQR with integral action
        Q=np.diag([1000.0, 50.0, 10.0, 0.5, 200.0]), R=1.0,
    )
    return derived(P)


def derived(P):
    P['Jb'] = 2/5*P['m']*P['rb']**2                          # ball about its centre
    P['mb'] = P['m'] + P['Jb']/P['rb']**2                    # effective rolling mass (7/5 m)
    P['J'] = P['mbeam']*P['L']**2/12 + P['eta_g']*P['Kg']**2*P['Jm']  # beam + reflected rotor
    P['x_max'] = P['L']/2 - P['rb']                          # end stops
    P['kv'] = P['eta_g']*P['eta_m']*P['Kg']*P['kt']/P['Rm']  # torque per volt [N m/V]
    P['beq'] = P['kv']*P['Kg']*P['km'] + P['Db']             # back-EMF + viscous
    return P


def linearize(P):
    M = np.array([[P['mb'], -P['Jb']/P['rb']], [-P['Jb']/P['rb'], P['J'] + P['Jb']]])
    Mi = np.linalg.inv(M)
    dq = np.array([[0, -P['m']*P['g']], [-P['m']*P['g'], 0]])
    dqd = np.array([[-P['bx'], 0], [0, -P['beq']]])
    Aq, Aqd, Bq = Mi @ dq, Mi @ dqd, Mi @ np.array([[0], [P['kv']]])
    A = np.zeros((4, 4)); B = np.zeros((4, 1))
    A[0, 1] = 1; A[2, 3] = 1
    for i, r in enumerate([1, 3]):
        A[r, 0], A[r, 2] = Aq[i]
        A[r, 1], A[r, 3] = Aqd[i]
        B[r, 0] = Bq[i, 0]
    return A, B


def lqr(A, B, Q, R):
    R = np.atleast_2d(R)
    X = solve_continuous_are(A, B, Q, R)
    return np.linalg.solve(R, B.T @ X)


def design(P):
    A, B = linearize(P)
    Aa = np.zeros((5, 5)); Aa[:4, :4] = A; Aa[4, 0] = 1           # z' = x - r
    Ba = np.vstack([B, [[0]]])
    P['K'] = lqr(Aa, Ba, P['Q'], P['R'])
    return P


def stop_force(q, qd, qmax, k, c):
    """Penalty contact force of a one-sided stop at +-qmax (never pulls)."""
    if q > qmax:
        return min(0.0, -k*(q - qmax) - c*qd)
    if q < -qmax:
        return max(0.0, -k*(q + qmax) - c*qd)
    return 0.0


def plant(s, V, Fd, P):
    x, xd, al, ald = s
    m, g, Jb, rb = P['m'], P['g'], P['Jb'], P['rb']
    tau = P['kv']*(V - P['Kg']*P['km']*ald)
    Tf = P['Db']*ald + P['Tc']*np.tanh(ald/P['w_eps'])
    Fs = stop_force(x, xd, P['x_max'], P['k_x'], P['c_x'])
    Ts = stop_force(al, ald, P['al_max'], P['k_al'], P['c_al'])
    M = np.array([[P['mb'], -Jb/rb], [-Jb/rb, P['J'] + Jb + m*x*x]])
    rhs = np.array([-P['bx']*xd + Fs + Fd + m*x*ald**2 - m*g*np.sin(al),
                    tau - Tf + Ts - 2*m*x*xd*ald - m*g*x*np.cos(al)])
    acc = np.linalg.solve(M, rhs)
    return np.array([xd, acc[0], ald, acc[1]])


class Ctrl:
    def __init__(s, P):
        s.P = P; s.yp = None; s.v = np.zeros(2); s.I = 0.0; s.alr = 0.0
        s.a = np.exp(-P['Ts']/np.array([P['tau_x'], P['tau_v']]))

    def __call__(s, y, r, mode, uman=0.0, alman=0.0):
        P = s.P
        if s.yp is None: s.yp = y.copy()
        s.v = s.a*s.v + (1 - s.a)*(y - s.yp)/P['Ts']; s.yp = y.copy()
        x, al = y; xd, ald = s.v
        V = 0.0; s.alr = 0.0
        if mode == 1:
            s.alr = alman
            V = P['Kp_a']*(s.alr - al) - P['Kd_a']*ald
        elif mode == 2:
            e = x - r
            if abs(e) < P['e_int']:
                s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            s.alr = np.clip(P['Kp_x']*e + P['Kd_x']*xd + P['Ki_x']*s.I,
                            -P['al_ref_max'], P['al_ref_max'])
            V = P['Kp_a']*(s.alr - al) - P['Kd_a']*ald + P['ff_on']*P['m']*P['g']*x/P['kv']
        elif mode == 3:
            e = x - r
            if abs(e) < P['e_int']:
                s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            V = (-P['K'] @ np.array([e, xd, al, ald, s.I])).item() + P['ff_on']*P['m']*P['g']*r/P['kv']
        return float(np.clip(V + uman, -P['Vmax'], P['Vmax']))


def simulate(P, x0, mode, T, ref=lambda t: 0.0, push=None, alman=0.0):
    s = np.array(x0, float); C = Ctrl(P)
    n = int(round(T/P['h'])); every = int(round(P['Ts']/P['h']))
    log = []; Vc = 0.0
    for k in range(n):
        t = k*P['h']
        if k % every == 0:
            y = np.array([np.round(s[0]/P['res_x'])*P['res_x'],
                          np.round(s[2]/P['res_al'])*P['res_al']])
            Vc = C(y, ref(t), mode, alman=alman)
        Fd = push(t) if push else 0.0
        f = lambda z: plant(z, Vc, Fd, P)
        k1 = f(s); k2 = f(s + P['h']/2*k1); k3 = f(s + P['h']/2*k2); k4 = f(s + P['h']*k3)
        s = s + P['h']/6*(k1 + 2*k2 + 2*k3 + k4)
        log.append([t, *s, Vc, C.alr])
    return np.array(log)
