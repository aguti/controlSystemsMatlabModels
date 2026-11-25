"""Python replica of the MATLAB/Simulink rotary (Furuta) pendulum model.

Used to design and cross-validate the dynamics, LQR gains and controller
modes independently of Simulink (see validation/compare_with_python.py).
State: s = [theta, theta_dot, alpha, alpha_dot]
  theta  arm angle [rad] (+ counter-clockwise seen from above)
  alpha  pendulum angle [rad] (0 = upright, pi = hanging; alpha > 0 leans
         towards +theta motion)
Input: motor voltage V [V].
"""
import numpy as np
from scipy.linalg import solve_continuous_are


def params():
    P = dict(
        # arm (rotor)
        mr=0.095, Lr=0.085, Jh=6.0e-6,
        # pendulum
        mp=0.024, Lp=0.129,
        g=9.81,
        # friction
        Dr=1.0e-4, Tc=5.0e-4, w_eps=0.05, Dp=5.0e-6,
        # DC motor + amplifier
        Rm=8.4, kt=0.042, km=0.042, Vmax=10.0, tau_a=0.0,
        # sensors / timing
        res_th=2*np.pi/2048, res_al=2*np.pi/2048,
        Ts=0.002, h=0.001, tau_v=0.005,
        # LQR
        Qup=np.diag([20.0, 0.5, 50.0, 0.5]), Rup=1.0,
        Qdn=np.diag([20.0, 0.5, 10.0, 0.05]), Rdn=1.0,
        # swing-up
        k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0, E_ref=0.2,
        al_catch=0.40, al_release=0.9,
        # PID (pendulum angle) + PD (arm)
        Kp_al=50.0, Ki_al=0.0, Kd_al=4.0, Kp_th=4.0, Kd_th=2.0, I_max=1.0,
        th_safe=2*np.pi,
    )
    P['lp'] = P['Lp']/2
    P['Jr'] = P['mr']*P['Lr']**2/3 + P['Jh']          # arm about the motor axis
    P['Jp'] = P['mp']*P['Lp']**2/12                    # pendulum about its CoM
    P['J0'] = P['Jr'] + P['mp']*P['Lr']**2
    P['Ja'] = P['Jp'] + P['mp']*P['lp']**2            # pendulum about its pivot
    return P


def linearize(P, al0):
    c = np.cos(al0)
    h = P['mp']*P['Lr']*P['lp']*c
    Mt = np.array([[P['J0'], h], [h, P['Ja']]])
    Mi = np.linalg.inv(Mt)
    beq = P['Dr'] + P['kt']*P['km']/P['Rm']          # viscous + back-EMF
    dR_dq = np.array([[0, 0], [0, P['mp']*P['g']*P['lp']*c]])
    dR_dqd = np.array([[-beq, 0], [0, -P['Dp']]])
    Bq = Mi @ np.array([[P['kt']/P['Rm']], [0]])
    Aq, Aqd = Mi @ dR_dq, Mi @ dR_dqd
    A = np.zeros((4, 4)); B = np.zeros((4, 1))
    A[0, 1] = 1; A[2, 3] = 1
    for i, r in enumerate([1, 3]):
        A[r, 0], A[r, 2] = Aq[i, 0], Aq[i, 1]
        A[r, 1], A[r, 3] = Aqd[i, 0], Aqd[i, 1]
        B[r, 0] = Bq[i, 0]
    return A, B


def lqr(A, B, Q, R):
    R = np.atleast_2d(R)
    X = solve_continuous_are(A, B, Q, R)
    return np.linalg.solve(R, B.T @ X)


def design(P):
    A, B = linearize(P, 0.0); P['K_up'] = lqr(A, B, P['Qup'], P['Rup'])
    A2, B2 = linearize(P, np.pi); P['K_dn'] = lqr(A2, B2, P['Qdn'], P['Rdn'])
    return P


def plant(s, V, Fd, P):
    th, thd, al, ald = s
    mp, Lr, lp, Ja, J0, g = P['mp'], P['Lr'], P['lp'], P['Ja'], P['J0'], P['g']
    c, sn = np.cos(al), np.sin(al)
    tau = P['kt']*(V - P['km']*thd)/P['Rm']
    tf = P['Dr']*thd + P['Tc']*np.tanh(thd/P['w_eps'])
    Mt = np.array([[J0 + Ja*sn*sn, mp*Lr*lp*c], [mp*Lr*lp*c, Ja]])
    rhs = np.array([tau - tf - 2*Ja*sn*c*ald*thd + mp*Lr*lp*sn*ald**2 + Fd*Lr,
                    Ja*sn*c*thd**2 + mp*g*lp*sn - P['Dp']*ald + Fd*P['Lp']*c])
    acc = np.linalg.solve(Mt, rhs)
    return np.array([thd, acc[0], ald, acc[1]])


def wrap(a):
    return (a + np.pi) % (2*np.pi) - np.pi


class Ctrl:
    def __init__(s, P):
        s.P = P; s.yp = None; s.v = np.zeros(2); s.I = 0.0; s.caught = 0
        s.a = np.exp(-P['Ts']/P['tau_v'])

    def __call__(s, y, r, mode, uman=0.0):
        P = s.P
        if s.yp is None: s.yp = y.copy()
        s.v = s.a*s.v + (1 - s.a)*(y - s.yp)/P['Ts']; s.yp = y.copy()
        th, al = y; thd, ald = s.v
        alw = wrap(al); E = 0.0; V = 0.0
        if mode == 1:
            V = (-P['K_up'] @ np.array([th - r, thd, alw, ald])).item()
        elif mode == 2:
            if s.caught and abs(alw) > P['al_release']: s.caught = 0
            if not s.caught and abs(alw) < P['al_catch']: s.caught = 1
            if s.caught:
                V = (-P['K_up'] @ np.array([th - r, thd, alw, ald])).item()
            else:
                V, E = swingup_voltage(P, th, thd, al, ald, r)
        elif mode == 3:
            s.I = np.clip(s.I + alw*P['Ts'], -P['I_max'], P['I_max'])
            V = (P['Kp_al']*alw + P['Ki_al']*s.I + P['Kd_al']*ald
                 + P['Kp_th']*(th - r) + P['Kd_th']*thd)
        elif mode == 4:
            phi = wrap(al - np.pi)
            V = (-P['K_dn'] @ np.array([th - r, thd, phi, ald])).item()
        return float(np.clip(V + uman, -P['Vmax'], P['Vmax'])), E


def swingup_voltage(P, th, thd, al, ald, r):
    mp, Lr, lp, Ja, J0, g = P['mp'], P['Lr'], P['lp'], P['Ja'], P['J0'], P['g']
    c, sn = np.cos(al), np.sin(al)
    E = 0.5*Ja*ald**2 + mp*g*lp*(c - 1)
    a = P['k_E']*(E - P['E_ref']*2*mp*g*lp)*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd
    if abs(ald) < 0.05 and c < -0.99: a += 0.3*P['a_max']
    a = np.clip(a, -P['a_max'], P['a_max'])
    ald2 = (Ja*sn*c*thd**2 + mp*g*lp*sn - P['Dp']*ald - mp*Lr*lp*c*a)/Ja
    tau = ((J0 + Ja*sn*sn)*a + 2*Ja*sn*c*ald*thd - mp*Lr*lp*sn*ald**2
           + mp*Lr*lp*c*ald2 + P['Dr']*thd)
    V = tau*P['Rm']/P['kt'] + P['km']*thd
    return V, E


def simulate(P, x0, mode, T, ref=lambda t: 0.0, push=None):
    s = np.array(x0, float); C = Ctrl(P)
    n = int(round(T/P['h'])); every = int(round(P['Ts']/P['h']))
    log = []; Vc = 0.0
    for k in range(n):
        t = k*P['h']
        if k % every == 0:
            y = np.array([np.round(s[0]/P['res_th'])*P['res_th'],
                          np.round(s[2]/P['res_al'])*P['res_al']])
            Vc, _ = C(y, ref(t), mode)
        Fd = push(t) if push else 0.0
        f = lambda z: plant(z, Vc, Fd, P)
        k1 = f(s); k2 = f(s + P['h']/2*k1); k3 = f(s + P['h']/2*k2); k4 = f(s + P['h']*k3)
        s = s + P['h']/6*(k1 + 2*k2 + 2*k3 + k4)
        log.append([t, *s, Vc, C.caught])
    return np.array(log)
