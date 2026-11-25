# Conversation: rotary pendulum (Furuta) — second experiment and experiments README

Claude Code session `861c5db6`, 2026-11-25 (continuation of the linear pendulum conversation). Exported from the session transcript.
Internal reasoning and harness metadata are omitted; tool outputs are collapsed and truncated.

## 🧑 User

Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo estilo, crea un nuevo directorio para el código y para le manual. Que se vea correctmente en la animación.

## 🤖 Claude

Esto es un trabajo grande. Primero repaso el estilo del manual del péndulo lineal (preámbulo, entornos y estructura) para reutilizarlo tal cual:

**🔧 Bash** — Read manual preamble and sizes

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/linear_pendulum && sed -n 1,200p manual.tex; wc -l *.tex
```

</details>

<details><summary>Output</summary>

```
\documentclass[11pt,a4paper,openany]{report}

% ------------------------------------------------------------------
% Idioma, fuentes y página
% ------------------------------------------------------------------
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[english]{babel}
\babelprovide[import,main]{spanish}
\usepackage{lmodern}
\usepackage{microtype}
\usepackage[a4paper,margin=2.4cm,headheight=14pt]{geometry}
\usepackage{fancyhdr}
\usepackage{amsmath,amssymb,bm}
\usepackage{siunitx}
\sisetup{output-decimal-marker={,},group-separator={\,},per-mode=symbol}
\usepackage{booktabs,array,tabularx,multirow}
\usepackage{enumitem}
\usepackage{float}
\usepackage{caption,subcaption}
\captionsetup{font=small,labelfont=bf}
\usepackage{xcolor}

% ------------------------------------------------------------------
% Gráficos
% ------------------------------------------------------------------
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,calc,patterns,shapes.geometric,
  decorations.pathmorphing,decorations.markings,fit,backgrounds,matrix,shadows}
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}
\usepgfplotslibrary{groupplots}
\pgfplotsset{
  manual/.style={width=\linewidth,height=4.6cm,grid=major,
    grid style={gray!25},tick label style={font=\footnotesize},
    label style={font=\small},legend style={font=\footnotesize,
    fill=white,fill opacity=0.85,text opacity=1,draw=gray!50},
    every axis plot/.append style={line width=0.9pt},
    /pgf/number format/use comma},
}
\definecolor{c1}{RGB}{0,114,189}
\definecolor{c2}{RGB}{217,83,25}
\definecolor{c3}{RGB}{237,177,32}
\definecolor{c4}{RGB}{126,47,142}
\definecolor{c5}{RGB}{119,172,48}
\definecolor{c6}{RGB}{77,190,238}

% ------------------------------------------------------------------
% Código
% ------------------------------------------------------------------
\usepackage{listings}
\lstdefinestyle{matlab}{
  language=Matlab, basicstyle=\ttfamily\footnotesize,
  keywordstyle=\color{blue!70!black}\bfseries,
  commentstyle=\color{green!45!black}\itshape,
  stringstyle=\color{violet},
  numbers=left, numberstyle=\tiny\color{gray}, numbersep=6pt,
  frame=single, rulecolor=\color{gray!40}, backgroundcolor=\color{gray!5},
  breaklines=true, columns=fullflexible, keepspaces=true,
  showstringspaces=false, xleftmargin=1.6em, framexleftmargin=1.4em,
  morekeywords={classdef,properties,methods,persistent,assert},
  literate={á}{{\'a}}1 {é}{{\'e}}1 {í}{{\'i}}1 {ó}{{\'o}}1 {ú}{{\'u}}1
           {ñ}{{\~n}}1 {Á}{{\'A}}1 {É}{{\'E}}1 {Ó}{{\'O}}1 {ü}{{\"u}}1
           {θ}{{$\theta$}}1 {°}{{$^\circ$}}1 {±}{{$\pm$}}1 {→}{{$\to$}}1
           {─}{{-}}1 {►}{{$\triangleright$}}1 {┐}{{+}}1 {┘}{{+}}1 {┼}{{+}}1
           {│}{{|}}1 {◄}{{$\triangleleft$}}1 {┴}{{+}}1
}
\lstset{style=matlab}

% ------------------------------------------------------------------
% Cajas
% ------------------------------------------------------------------
\usepackage[most]{tcolorbox}
\newtcolorbox{nota}[1][]{colback=c1!5,
... [truncated, 4398 more characters]
```

</details>

**🔧 Bash** — Write Python rotary pendulum prototype and test

<details><summary>Command</summary>

```bash
mkdir -p /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data && cat > /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/python_reference_sim.py <<'EOF'
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
        Dr=1.0e-4, Tc=1.0e-3, w_eps=0.05, Dp=5.0e-6,
        # DC motor + amplifier
        Rm=8.4, kt=0.042, km=0.042, Vmax=10.0, tau_a=0.0,
        # sensors / timing
        res_th=2*np.pi/2048, res_al=2*np.pi/2048,
        Ts=0.002, h=0.001, tau_v=0.005,
        # LQR
        Qup=np.diag([5.0, 0.1, 50.0, 0.5]), Rup=1.0,
        Qdn=np.diag([5.0, 0.1, 5.0, 0.05]), Rdn=1.0,
        # swing-up
        k_E=150.0, a_max=60.0, kx_sw=20.0, kv_sw=2.0,
        al_catch=0.40, al_release=0.9,
        # PID (pendulum angle) + PD (arm)
        Kp_al=45.0, Ki_al=0.0, Kd_al=3.0, Kp_th=3.0, Kd_th=1.5, I_max=1.0,
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
    a = P['k_E']*E*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd
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
EOF
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
P=design(params())
A,B=linearize(P,0); A2,B2=linearize(P,np.pi)
print('OL up',np.round(np.linalg.eigvals(A),2)); print('OL dn',np.round(np.linalg.eigvals(A2),2))
print('K_up',P['K_up'].round(2),'CL',np.round(np.linalg.eigvals(A-B@P['K_up']),2))
print('K_dn',P['K_dn'].round(2),'CL',np.round(np.linalg.eigvals(A2-B2@P['K_dn']),2))
pid=-np.array([[P['Kp_th'],P['Kd_th'],P['Kp_al'],P['Kd_al']]]); print('PID CL',np.round(np.linalg.eigvals(A-B@pid),2))
def rep(name,L,col=3):
    t=L[:,0]; al=np.degrees(wrap(L[:,3])); th=np.degrees(L[:,1])
    i=np.where(abs(al)>1)[0]; 
    print(f'{name}: settle(1deg) {t[i[-1]] if len(i) else 0:.2f}s Vmax {abs(L[:,5]).max():.1f} th range [{th.min():.0f},{th.max():.0f}] deg final al {al[-1]:.2f} th {th[-1]:.1f}')
rep('lqr 10deg',simulate(P,[0,0,np.radians(10),0],1,5))
rep('pid 10deg',simulate(P,[0,0,np.radians(10),0],3,5))
L=simulate(P,[0,0,np.pi,0],2,10); c=L[:,6]; print('swing catch', L[np.argmax(c>0),0] if c.any() else None, 'th range', np.degrees(L[:,1]).min().round(), np.degrees(L[:,1]).max().round(), 'Vmax',abs(L[:,5]).max().round(1), 'final al', np.degrees(wrap(L[-1,3])).round(2))
"
```

</details>

<details><summary>Output</summary>

```
OL up [  0.   -13.16  -0.76  12.74]
OL dn [ 0.   +0.j   -0.76 +0.j   -0.2 +12.93j -0.2 -12.93j]
K_up [[ -2.24  -1.16 -37.86  -3.25]] CL [-19.94+0.j   -10.79+0.j    -3.71+2.75j  -3.71-2.75j]
K_dn [[2.24 0.66 1.41 0.02]] CL [-2.59+12.46j -2.59-12.46j -4.13 +3.35j -4.13 -3.35j]
PID CL [-10.7 +17.83j -10.7 -17.83j  -3.06 +2.21j  -3.06 -2.21j]
lqr 10deg: settle(1deg) 0.54s Vmax 6.6 th range [-6,29] deg final al -0.40 th 3.2
pid 10deg: settle(1deg) 0.36s Vmax 7.9 th range [-4,22] deg final al 0.26 th -3.2
swing catch None th range -29.0 30.0 Vmax 9.4 final al -117.76
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

## 🤖 Claude

El LQR y el PID estabilizan bien, pero el swing-up no llega arriba: se queda en unos 118°. Hago un barrido de sus parámetros:

**🔧 Bash** — Grid-search swing-up gains

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys, itertools; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
res=[]
for kE,am,kx,kv in itertools.product([100,300,800],[40,80,120],[2,6,15],[0.5,2]):
    P=design(params()); P.update(k_E=kE,a_max=am,kx_sw=kx,kv_sw=kv)
    L=simulate(P,[0,0,np.pi,0],2,10); c=L[:,6]
    if c.any():
        tc=L[np.argmax(c>0),0]; ok=abs(np.degrees(wrap(L[-1,3])))<2 and c[-1]>0
        res.append((ok,tc,kE,am,kx,kv,np.degrees(abs(L[:,1])).max().round(),abs(L[:,5]).max().round(1)))
for r in sorted(res,key=lambda r:(not r[0],r[1]))[:15]: print(r)
"
```

</details>

<details><summary>Output</summary>

```
(True, 0.884, 800, 120, 2, 0.5, 333.0, 10.0)
(True, 1.008, 800, 120, 6, 2, 127.0, 10.0)
(True, 1.032, 800, 120, 2, 2, 108.0, 10.0)
(True, 1.428, 800, 80, 2, 0.5, 330.0, 10.0)
(True, 1.474, 800, 80, 15, 2, 132.0, 10.0)
(True, 1.504, 800, 80, 6, 2, 151.0, 10.0)
(True, 1.508, 800, 80, 15, 0.5, 123.0, 10.0)
(True, 1.542, 800, 80, 2, 2, 153.0, 10.0)
(True, 1.59, 800, 120, 15, 2, 100.0, 10.0)
(True, 1.754, 800, 120, 15, 0.5, 177.0, 10.0)
(True, 1.812, 800, 120, 6, 0.5, 280.0, 10.0)
(True, 1.834, 800, 40, 15, 2, 106.0, 10.0)
(True, 1.846, 800, 80, 6, 0.5, 297.0, 10.0)
(True, 1.87, 800, 40, 2, 2, 147.0, 10.0)
(True, 1.8900000000000001, 300, 120, 15, 0.5, 58.0, 10.0)
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Robust swing-up tuning over initial conditions

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys, itertools; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
ics=[[0,0,np.pi,0],[0,0,np.pi-0.2,0],[0.5,0,np.pi,1.0],[0,0,np.pi+0.05,-2]]
out=[]
for kE,am,kx,kv in itertools.product([200,300,450],[80,120],[10,15,25],[0.5,1,2]):
    P=design(params()); P.update(k_E=kE,a_max=am,kx_sw=kx,kv_sw=kv)
    tcs=[];ths=[];ok=True
    for x0 in ics:
        L=simulate(P,x0,2,10); c=L[:,6]
        if not(c.any() and c[-1]>0 and abs(np.degrees(wrap(L[-1,3])))<2): ok=False;break
        tcs.append(L[np.argmax(c>0),0]); ths.append(np.degrees(abs(L[:,1])).max())
    if ok: out.append((max(ths).round(),max(tcs).round(2),kE,am,kx,kv))
for r in sorted(out)[:10]: print(r)
"
```

</details>

<details><summary>Output</summary>

```
(47.0, 2.4, 200, 120, 25, 0.5)
(47.0, 2.44, 200, 80, 25, 0.5)
(50.0, 2.32, 200, 120, 25, 1)
(50.0, 2.4, 200, 80, 25, 1)
(59.0, 2.57, 300, 80, 15, 2)
(60.0, 1.83, 300, 120, 25, 2)
(60.0, 1.84, 300, 80, 25, 2)
(61.0, 2.57, 300, 120, 15, 2)
(62.0, 3.9, 200, 80, 15, 0.5)
(66.0, 3.09, 300, 120, 10, 2)
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Check arm reference steps for each mode

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i 's/k_E=150.0, a_max=60.0, kx_sw=20.0, kv_sw=2.0,/k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0,/' python_reference_sim.py && cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
P=design(params())
r=np.radians(45); rf=lambda t: r if t>1 else 0
for name,mode,x0 in [('lqr step',1,[0,0,0,0]),('pid step',3,[0,0,0,0]),('down step',4,[0,0,np.pi,0])]:
    L=simulate(P,x0,mode,6,ref=rf); t=L[:,0]; th=np.degrees(L[:,1]); al=np.degrees(wrap(L[:,3]-(np.pi if mode==4 else 0)))
    i=np.where(abs(th-45)>2.25)[0]
    print(f'{name}: min th {th.min():.1f} settle5% {t[i[-1]]:.2f}s  max|al| {abs(al).max():.1f} Vmax {abs(L[:,5]).max():.1f}  final th {th[-1]:.1f} sway t>4 {abs(al[t>4]).max():.2f}')
Pn=dict(P); K=P['K_dn'].copy(); K[0,2:]=0; Pn['K_dn']=K
L=simulate(Pn,[0,0,np.pi,0],4,6,ref=rf); t=L[:,0]; print('down no-sway: sway t>4', np.degrees(abs(wrap(L[t>4,3]-np.pi))).max().round(2))
"
```

</details>

<details><summary>Output</summary>

```
lqr step: min th -2.0 settle5% 5.86s  max|al| 3.0 Vmax 2.4  final th 45.5 sway t>4 0.46
pid step: min th -2.9 settle5% 6.00s  max|al| 3.8 Vmax 2.6  final th 48.1 sway t>4 0.45
down step: min th 0.0 settle5% 3.17s  max|al| 6.5 Vmax 1.8  final th 44.4 sway t>4 0.21
down no-sway: sway t>4 0.85
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Tune LQR weights vs Coulomb friction

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
r=np.radians(45); rf=lambda t: r if t>1 else 0
for Tc in [1e-3,5e-4]:
  for qth,qal in [(20,50),(50,100),(100,200)]:
    P=params(); P['Tc']=Tc; P['Qup']=np.diag([qth,0.5,qal,0.5]); P['Qdn']=np.diag([qth,0.5,qth/2,0.05]); P=design(P)
    out=[]
    for mode,x0 in [(1,[0,0,0,0]),(4,[0,0,np.pi,0])]:
        L=simulate(P,x0,mode,6,ref=rf); t=L[:,0]; th=np.degrees(L[:,1]); al=np.degrees(wrap(L[:,3]-(np.pi if mode==4 else 0)))
        i=np.where(abs(th-45)>2.25)[0]; out.append(f'mode{mode}: settle {t[i[-1]]-1:.2f}s min {th.min():.1f} V {abs(L[:,5]).max():.1f} fin {th[-1]:.1f} maxal {abs(al).max():.1f}')
    Pn=dict(P); K=P['K_dn'].copy(); K[0,2:]=0; Pn['K_dn']=K
    L=simulate(Pn,[0,0,np.pi,0],4,6,ref=rf); t=L[:,0]
    L0=simulate(P,[0,0,np.radians(10),0],1,4)
    print(Tc,qth,qal,'K',P['K_up'].round(1),'|',' | '.join(out),'| nosway',np.degrees(abs(wrap(L[t>4,3]-np.pi))).max().round(2), '| ic10 V',abs(L0[:,5]).max().round(1))
"
```

</details>

<details><summary>Output</summary>

```
0.001 20 50 K [[ -4.5  -2.  -50.3  -4.4]] | mode1: settle 5.00s min -3.2 V 3.5 fin 42.6 maxal 4.2 | mode4: settle 0.59s min 0.0 V 3.5 fin 44.9 maxal 9.8 | nosway 2.67 | ic10 V 8.8
0.001 50 100 K [[ -7.1  -2.6 -59.4  -5.2]] | mode1: settle 0.57s min -4.6 V 6.2 fin 45.8 maxal 5.7 | mode4: settle 0.60s min 0.0 V 5.6 fin 45.0 maxal 13.0 | nosway 4.02 | ic10 V 10.0
0.001 100 200 K [[-10.   -3.4 -69.6  -6.1]] | mode1: settle 0.51s min -5.9 V 7.9 fin 44.5 maxal 7.0 | mode4: settle 0.69s min 0.0 V 7.9 fin 45.0 maxal 15.4 | nosway 5.2 | ic10 V 10.0
0.0005 20 50 K [[ -4.5  -2.  -50.3  -4.4]] | mode1: settle 0.72s min -3.4 V 3.5 fin 44.1 maxal 4.2 | mode4: settle 0.55s min 0.0 V 3.5 fin 45.0 maxal 10.1 | nosway 1.6 | ic10 V 8.8
0.0005 50 100 K [[ -7.1  -2.6 -59.4  -5.2]] | mode1: settle 0.59s min -4.7 V 5.6 fin 44.5 maxal 5.7 | mode4: settle 0.68s min 0.0 V 5.6 fin 45.0 maxal 13.2 | nosway 2.38 | ic10 V 10.0
0.0005 100 200 K [[-10.   -3.4 -69.6  -6.1]] | mode1: settle 0.53s min -5.9 V 7.9 fin 44.8 maxal 7.0 | mode4: settle 0.69s min 0.0 V 7.9 fin 45.0 maxal 15.6 | nosway 3.55 | ic10 V 10.0
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Recheck swing-up and tune PID with new defaults

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i -e 's/Dr=1.0e-4, Tc=1.0e-3,/Dr=1.0e-4, Tc=5.0e-4,/' -e 's/Qup=np.diag(\[5.0, 0.1, 50.0, 0.5\]), Rup=1.0,/Qup=np.diag([20.0, 0.5, 50.0, 0.5]), Rup=1.0,/' -e 's/Qdn=np.diag(\[5.0, 0.1, 5.0, 0.05\]), Rdn=1.0,/Qdn=np.diag([20.0, 0.5, 10.0, 0.05]), Rdn=1.0,/' python_reference_sim.py && grep -n "Tc=\|Qup=\|Qdn=" python_reference_sim.py && cd /tmp && python3 -c "
import sys,itertools; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
P=design(params()); A,B=linearize(P,0)
ics=[[0,0,np.pi,0],[0,0,np.pi-0.2,0],[0.5,0,np.pi,1.0],[0,0,np.pi+0.05,-2]]
for x0 in ics:
    L=simulate(P,x0,2,8); c=L[:,6]; print('swing',x0,'catch',L[np.argmax(c>0),0] if c.any() else None,'end caught',c[-1],'final al',np.degrees(wrap(L[-1,3])).round(2),'max th',np.degrees(abs(L[:,1])).max().round())
r=np.radians(45); rf=lambda t: r if t>1 else 0
for kp,kd,kpa,kda in [(3,1.5,45,3),(4.5,2,50,4.4),(6,2,55,4.5)]:
    P.update(Kp_th=kp,Kd_th=kd,Kp_al=kpa,Kd_al=kda)
    pid=-np.array([[kp,kd,kpa,kda]]); ev=np.linalg.eigvals(A-B@pid)
    L=simulate(P,[0,0,0,0],3,6,ref=rf); t=L[:,0]; th=np.degrees(L[:,1]); i=np.where(abs(th-45)>2.25)[0]
    L0=simulate(P,[0,0,np.radians(10),0],3,4)
    print('pid',kp,kd,kpa,kda,'stable',all(ev.real<0),'settle',(t[i[-1]]-1).round(2),'fin',th[-1].round(1),'V',abs(L[:,5]).max().round(1),'ic V',abs(L0[:,5]).max().round(1), 'ic final al', np.degrees(wrap(L0[-1,3])).round(2))
"
```

</details>

<details><summary>Output</summary>

```
23:        Dr=1.0e-4, Tc=5.0e-4, w_eps=0.05, Dp=5.0e-6,
30:        Qup=np.diag([20.0, 0.5, 50.0, 0.5]), Rup=1.0,
31:        Qdn=np.diag([20.0, 0.5, 10.0, 0.05]), Rdn=1.0,
swing [0, 0, 3.141592653589793, 0] catch 2.236 end caught 1.0 final al 0.09 max th 43.0
swing [0, 0, 2.941592653589793, 0] catch 1.79 end caught 1.0 final al -0.09 max th 41.0
swing [0.5, 0, 3.141592653589793, 1.0] catch 2.468 end caught 1.0 final al 0.08 max th 40.0
swing [0, 0, 3.191592653589793, -2] catch 2.164 end caught 1.0 final al -0.1 max th 43.0
pid 3 1.5 45 3 stable True settle 2.45 fin 44.3 V 2.6 ic V 7.9 ic final al 0.08
pid 4.5 2 50 4.4 stable True settle 0.73 fin 44.0 V 3.5 ic V 8.7 ic final al -0.09
pid 6 2 55 4.5 stable True settle 1.03 fin 44.6 V 4.7 ic V 9.7 ic final al -0.12
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Set PID defaults in Python replica

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i 's/Kp_al=45.0, Ki_al=0.0, Kd_al=3.0, Kp_th=3.0, Kd_th=1.5, I_max=1.0,/Kp_al=50.0, Ki_al=0.0, Kd_al=4.0, Kp_th=4.0, Kd_th=2.0, I_max=1.0,/' python_reference_sim.py && grep -n "Kp_al" python_reference_sim.py
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_params.m` (4277 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_linearize.m` (889 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_lqr.m` (430 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_design.m` (739 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_ref_block.m` (564 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_plant_block.m` (1377 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_controller_block.m` (3354 characters)

<details><summary>Output</summary>

```
36:        Kp_al=50.0, Ki_al=0.0, Kd_al=4.0, Kp_th=4.0, Kd_th=2.0, I_max=1.0,
117:            V = (P['Kp_al']*alw + P['Ki_al']*s.I + P['Kd_al']*ald
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_params.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_linearize.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_lqr.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_design.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_ref_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_plant_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_controller_block.m (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Ahora el generador del modelo Simulink. Es la misma arquitectura que en el péndulo lineal; el actuador es el amplificador del motor, con saturación de ±10 V:

**🔧 Bash** — Derive rp_build_model.m from cp_build_model.m

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && python3 - <<'EOF'
s=open('linear_pendulum/cp_build_model.m').read()
rep=[
("function mdl = cp_build_model(mdl)\n%CP_BUILD_MODEL  Generates the Simulink model of the linear pendulum (cart-pole).",
 "function mdl = rp_build_model(mdl)\n%RP_BUILD_MODEL  Generates the Simulink model of the rotary (Furuta) pendulum."),
("%   cp_build_model            -> creates and saves 'cartpole_sim.slx' in this folder",
 "%   rp_build_model            -> creates and saves 'rotpend_sim.slx' in this folder"),
("[Actuator] ─► [Plant] ─┐","[Amplifier] ► [Plant] ─┐"),
("%     u_ext   [t u]   additional force on the cart","%     u_ext   [t u]   additional voltage on the motor"),
("%     cmd_dist  Constant  disturbance force at the tip [N]","%     cmd_dist  Constant  disturbance force at the pendulum tip [N]"),
("%     [x xd th thd | x_meas th_meas | F_cmd F_act | r | mode E caught tripped]",
 "%     [th thd al ald | th_meas al_meas | V_cmd V_act | r | mode E caught tripped]"),
("mdl = 'cartpole_sim'","mdl = 'rotpend_sim'"),
("cp_design(cp_params())","rp_design(rp_params())"),
("'CartPole.onModelStart(bdroot);'","'RotaryPendulum.onModelStart(bdroot);'"),
("'CartPole.onModelStop(bdroot);'","'RotaryPendulum.onModelStop(bdroot);'"),
("'cp_ref_block.m'","'rp_ref_block.m'"),
("'RisingSlewLimit', 'P.ref_rate', 'FallingSlewLimit', '-P.ref_rate');\nblk([S '/Rail limit'], 'simulink/Discontinuities/Saturation', [400 85 450 115], ...\n    'UpperLimit', 'P.x_ref_max', 'LowerLimit', '-P.x_ref_max');",
 "'RisingSlewLimit', 'P.ref_rate', 'FallingSlewLimit', '-P.ref_rate');\nblk([S '/Range limit'], 'simulink/Discontinuities/Saturation', [400 85 450 115], ...\n    'UpperLimit', 'P.th_ref_max', 'LowerLimit', '-P.th_ref_max');"),
("ln(S, 'Rate limiter/1', 'Rail limit/1');\nln(S, 'Rail limit/1', 'r/1');","ln(S, 'Rate limiter/1', 'Range limit/1');\nln(S, 'Range limit/1', 'r/1');"),
("{'y_meas', 'r', 'cmd'}, {'F', 'info'}","{'y_meas', 'r', 'cmd'}, {'V', 'info'}"),
("'cp_controller_block.m'","'rp_controller_block.m'"),
("ln(S, 'Control law/1', 'F/1');","ln(S, 'Control law/1', 'V/1');"),
("""%% ---------------- Subsystem: Actuator ----------------
S = sub(mdl, 'Actuator', [700 240 820 300], {'F_cmd'}, {'F_act'});
blk([S '/Actuator dynamics'], 'simulink/Continuous/Transfer Fcn', [120 30 220 70], ...
    'Numerator', '1', 'Denominator', '[P.tau_a 1]');
blk([S '/Saturation'], 'simulink/Discontinuities/Saturation', [270 35 320 65], ...
    'UpperLimit', 'P.Fmax', 'LowerLimit', '-P.Fmax');
ln(S, 'F_cmd/1', 'Actuator dynamics/1'); ln(S, 'Actuator dynamics/1', 'Saturation/1');
ln(S, 'Saturation/1', 'F_act/1');""",
"""%% ---------------- Subsystem: Amplifier ----------------
S = sub(mdl, 'Amplifier', [700 240 820 300], {'V_cmd'}, {'V_act'});
blk([S '/Saturation'], 'simulink/Discontinuities/Saturation', [270 35 320 65], ...
    'UpperLimit', 'P.Vmax', 'LowerLimit', '-P.Vmax');
ln(S, 'V_cmd/1', 'Saturation/1');
ln(S, 'Saturation/1', 'V_act/1');"""),
("S = sub(mdl, 'Plant', [920 240 1040 360], {'F', 'Fd'}, {'s'});","S = sub(mdl, 'Plant', [920 240 1040 360], {'V', 'Fd'}, {'s'});"),
("'cp_plant_block.m'","'rp_plant_block.m'"),
("ln(S, 'F/1', 'Dynamics/2');","ln(S, 'V/1', 'Dynamics/2');"),
("blk([S '/Term xd'], 'simulink/Sinks/Terminator', [150 55 170 75]);\nblk([S '/Term thd'], 'simulink/Sinks/Terminator', [150 125 170 145]);",
 "blk([S '/Term thd'], 'simulink/Sinks/Terminator', [150 55 170 75]);\nblk([S '/Term ald'], 'simulink/Sinks/Terminator', [150 125 170 145]);"),
("blk([S '/Noise x'], 'simulink/Sources/Random Number', [90 180 120 210], ...","blk([S '/Noise th'], 'simulink/Sources/Random Number', [90 180 120 210], ..."),
("blk([S '/Noise th'], 'simulink/Sources/Random Number', [90 240 120 270], ...","blk([S '/Noise al'], 'simulink/Sources/Random Number', [90 240 120 270], ..."),
("blk([S '/sigma x'], 'simulink/Math Operations/Gain', [150 180 200 210], 'Gain', 'P.noise_on*P.noise_x');\nblk([S '/sigma th'], 'simulink/Math Operations/Gain', [150 240 200 270], 'Gain', 'P.noise_on*P.noise_th');",
 "blk([S '/sigma th'], 'simulink/Math Operations/Gain', [150 180 200 210], 'Gain', 'P.noise_on*P.noise_th');\nblk([S '/sigma al'], 'simulink/Math Operations/Gain', [150 240 200 270], 'Gain', 'P.noise_on*P.noise_al');"),
("blk([S '/Sum x'], 'simulink/Math Operations/Sum', [240 25 260 45], 'Inputs', '++');\nblk([S '/Sum th'], 'simulink/Math Operations/Sum', [240 95 260 115], 'Inputs', '++');\nblk([S '/Encoder x'], 'simulink/Discontinuities/Quantizer', [300 20 340 50], 'QuantizationInterval', 'P.res_x');\nblk([S '/Encoder th'], 'simulink/Discontinuities/Quantizer', [300 90 340 120], 'QuantizationInterval', 'P.res_th');",
 "blk([S '/Sum th'], 'simulink/Math Operations/Sum', [240 25 260 45], 'Inputs', '++');\nblk([S '/Sum al'], 'simulink/Math Operations/Sum', [240 95 260 115], 'Inputs', '++');\nblk([S '/Encoder th'], 'simulink/Discontinuities/Quantizer', [300 20 340 50], 'QuantizationInterval', 'P.res_th');\nblk([S '/Encoder al'], 'simulink/Discontinuities/Quantizer', [300 90 340 120], 'QuantizationInterval', 'P.res_al');"),
("""ln(S, 'Demux/1', 'Sum x/1');  ln(S, 'Demux/2', 'Term xd/1');
ln(S, 'Demux/3', 'Sum th/1'); ln(S, 'Demux/4', 'Term thd/1');
ln(S, 'Noise x/1', 'sigma x/1');   ln(S, 'sigma x/1', 'Sum x/2');
ln(S, 'Noise th/1', 'sigma th/1'); ln(S, 'sigma th/1', 'Sum th/2');
ln(S, 'Sum x/1', 'Encoder x/1');   ln(S, 'Sum th/1', 'Encoder th/1');
ln(S, 'Encoder x/1', 'Mux/1');     ln(S, 'Encoder th/1', 'Mux/2');""",
"""ln(S, 'Demux/1', 'Sum th/1'); ln(S, 'Demux/2', 'Term thd/1');
ln(S, 'Demux/3', 'Sum al/1'); ln(S, 'Demux/4', 'Term ald/1');
ln(S, 'Noise th/1', 'sigma th/1'); ln(S, 'sigma th/1', 'Sum th/2');
ln(S, 'Noise al/1', 'sigma al/1'); ln(S, 'sigma al/1', 'Sum al/2');
ln(S, 'Sum th/1', 'Encoder th/1'); ln(S, 'Sum al/1', 'Encoder al/1');
ln(S, 'Encoder th/1', 'Mux/1');    ln(S, 'Encoder al/1', 'Mux/2');"""),
("blk([mdl '/SumF'], 'simulink/Math Operations/Sum', [620 255 640 285], 'Inputs', '++');","blk([mdl '/SumV'], 'simulink/Math Operations/Sum', [620 255 640 285], 'Inputs', '++');"),
("ln(mdl, 'Controller/1', 'SumF/1');\nln(mdl, 'u_ext/1', 'SumF/2');\nln(mdl, 'SumF/1', 'Actuator/1');\nln(mdl, 'Actuator/1', 'Plant/1');",
 "ln(mdl, 'Controller/1', 'SumV/1');\nln(mdl, 'u_ext/1', 'SumV/2');\nln(mdl, 'SumV/1', 'Amplifier/1');\nln(mdl, 'Amplifier/1', 'Plant/1');"),
("ln(mdl, 'SumF/1', 'Mux tel/3');\nln(mdl, 'Actuator/1', 'Mux tel/4');","ln(mdl, 'SumV/1', 'Mux tel/3');\nln(mdl, 'Amplifier/1', 'Mux tel/4');"),
("sel = {'x y r', '[1 9]', 470; 'theta', '[3]', 530; 'F cmd-act', '[7 8]', 590};","sel = {'theta r', '[1 9]', 470; 'alpha', '[3]', 530; 'V cmd-act', '[7 8]', 590};"),
("% Pacing (real time) disabled by default; CartPole.start() enables it","% Pacing (real time) disabled by default; RotaryPendulum.start() enables it"),
("warning('cp_build_model:param'","warning('rp_build_model:param'"),
]
for a,b in rep:
    assert a in s, a[:80]
    s=s.replace(a,b)
open('rotary_pendulum/rp_build_model.m','w').write(s)
EOF
grep -n "cp_\|CartPole\|Fmax\|x_\|F_\|cart" rotary_pendulum/rp_build_model.m
```

</details>

<details><summary>Output</summary>

```
(Bash completed with no output)
```

</details>

## 🤖 Claude

Ahora la clase `RotaryPendulum`, adaptada de `CartPole`:

**🔧 Bash** — Derive RotaryPendulum class from CartPole

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && python3 - <<'EOF'
s=open('linear_pendulum/CartPole.m').read()
rep=[
("classdef CartPole < handle\n%CARTPOLE  Code interface for the Simulink model of the linear pendulum.",
 "classdef RotaryPendulum < handle\n%ROTARYPENDULUM  Code interface for the Simulink model of the rotary (Furuta) pendulum.\n%\n%   All angles are in radians (theta = arm, alpha = pendulum, 0 = up)."),
("%   cp = CartPole();                 % loads (or generates) cartpole_sim.slx",
 "%   rp = RotaryPendulum();           % loads (or generates) rotpend_sim.slx"),
("%   cp.setInitialState([0 0 0.15 0]);","%   rp.setInitialState([0 0 pi 0]);  % [theta thetad alpha alphad]"),
("%   cp.setMode('lqr');               % 'open','lqr','swingup','pid','crane' (or 0..4)",
 "%   rp.setMode('swingup');           % 'open','lqr','swingup','pid','down' (or 0..4)"),
("%   res = cp.run(8);                 % simulates 8 s and returns a struct of signals\n%   cp_plot_results(res); cp.animate(res);",
 "%   res = rp.run(8);                 % simulates 8 s and returns a struct of signals\n%   rp_plot_results(res); rp.animate(res);"),
("%   cp.start();                      % starts with StopTime = inf and 1x pacing\n%   cp.setRef('sine', 0, 0.2, 0.1);  % type, offset [m], amplitude [m], freq [Hz]\n%   cp.setForce(2);                  % manual force [N] (added to the controller's)\n%   cp.push(1, 0.1);                 % push: 1 N at the tip for 0.1 s\n%   cp.setParam('Qup', diag([100 1 200 1]));   % recomputes the LQR and applies it live\n%   cp.stop(); res = cp.lastResult();",
 "%   rp.start();                      % starts with StopTime = inf and 1x pacing\n%   rp.setRef('sine', 0, pi/4, 0.2); % type, offset [rad], amplitude [rad], freq [Hz]\n%   rp.setVoltage(1);                % manual voltage [V] (added to the controller's)\n%   rp.push(0.05, 0.05);             % push: 0.05 N at the tip for 0.05 s\n%   rp.setParam('Qup', diag([50 0.5 100 0.5]));   % recomputes the LQR and applies it live\n%   rp.stop(); res = rp.lastResult();"),
("%   cp.setRefSignal(t, r)      external reference (activates type 'external')\n%   cp.setForceSignal(t, u)    additional force on the cart (identification)\n%   cp.setDisturbanceSignal(t, Fd)   scheduled disturbance at the tip",
 "%   rp.setRefSignal(t, r)       external arm reference [rad] (activates type 'external')\n%   rp.setVoltageSignal(t, u)   additional motor voltage (identification)\n%   rp.setDisturbanceSignal(t, Fd)   scheduled disturbance force at the tip"),
("%   cp.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 13-signal vector\n%   Indices: CartPole.TEL.x, .xd, .th, .thd, .xm, .thm, .Fcmd, .Fact, .r,\n%            .mode, .E, .caught, .tripped",
 "%   rp.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 13-signal vector\n%   Indices: RotaryPendulum.TEL.th, .thd, .al, .ald, .thm, .alm, .Vcmd, .Vact,\n%            .r, .mode, .E, .caught, .tripped"),
("% parameter struct (cp_params + cp_design)","% parameter struct (rp_params + rp_design)"),
("Model = 'cartpole_sim'","Model = 'rotpend_sim'"),
("TEL = struct('x',1,'xd',2,'th',3,'thd',4,'xm',5,'thm',6, ...\n                     'Fcmd',7,'Fact',8,'r',9,'mode',10,'E',11, ...",
 "TEL = struct('th',1,'thd',2,'al',3,'ald',4,'thm',5,'alm',6, ...\n                     'Vcmd',7,'Vact',8,'r',9,'mode',10,'E',11, ..."),
("MODES = {'open','lqr','swingup','pid','crane'}","MODES = {'open','lqr','swingup','pid','down'}"),
("function obj = CartPole(varargin)","function obj = RotaryPendulum(varargin)"),
("obj.P = cp_params();\n            [obj.P, obj.Lin] = cp_design(obj.P);","obj.P = rp_params();\n            [obj.P, obj.Lin] = rp_design(obj.P);"),
("cp_build_model(obj.Model);","rp_build_model(obj.Model);"),
("setappdata(0, 'CartPoleInstance', obj);","setappdata(0, 'RotaryPendulumInstance', obj);"),
("%SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'crane'","%SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'down'"),
("""        function setForce(obj, u)
            %SETFORCE  Manual force [N] added to the controller's.
            obj.CmdCtrl(3) = max(min(u, obj.P.Fmax), -obj.P.Fmax); obj.applyCmd();""",
"""        function setVoltage(obj, u)
            %SETVOLTAGE  Manual voltage [V] added to the controller's.
            obj.CmdCtrl(3) = max(min(u, obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();"""),
("%SETREF  setRef(type, offset, amplitude, frequency)","%SETREF  setRef(type, offset, amplitude, frequency)   (angles in rad)"),
("""            %PUSH  Horizontal push at the pendulum tip (live).
            if nargin < 2, F = 1; end
            if nargin < 3, dur = 0.1; end""",
"""            %PUSH  Tangential push at the pendulum tip (live). F [N], dur [s].
            if nargin < 2, F = 0.05; end
            if nargin < 3, dur = 0.05; end"""),
("[obj.P, obj.Lin] = cp_design(obj.P);\n            obj.pushParams();\n            obj.refresh();\n        end\n\n        function setParamRaw",
 "[obj.P, obj.Lin] = rp_design(obj.P);\n            obj.pushParams();\n            obj.refresh();\n        end\n\n        function setParamRaw"),
("%SETPARAMS  Several at once: cp.setParams(struct('M',0.8,'m',0.3))","%SETPARAMS  Several at once: rp.setParams(struct('mp',0.03,'Lp',0.15))"),
("            [obj.P, obj.Lin] = cp_design(obj.P);\n            obj.pushParams(); obj.refresh();","            [obj.P, obj.Lin] = rp_design(obj.P);\n            obj.pushParams(); obj.refresh();"),
("imposing gains by hand: cp.setParamRaw('K_up', [...]).","imposing gains by hand: rp.setParamRaw('K_up', [...])."),
("%SETINITIALSTATE  [x xd theta thetad] for the next start.","%SETINITIALSTATE  [theta thetad alpha alphad] for the next start."),
("        function setForceSignal(~, t, u)","        function setVoltageSignal(~, t, u)"),
("            cp_animate(res, obj.P, speed);","            rp_animate(res, obj.P, speed);"),
("            obj = CartPole.instance(mdl);\n            if ~isempty(obj), obj.attach(); end","            obj = RotaryPendulum.instance(mdl);\n            if ~isempty(obj), obj.attach(); end"),
("            obj = CartPole.instance(mdl);\n            if ~isempty(obj), obj.detach(); end","            obj = RotaryPendulum.instance(mdl);\n            if ~isempty(obj), obj.detach(); end"),
("obj = getappdata(0, 'CartPoleInstance');","obj = getappdata(0, 'RotaryPendulumInstance');"),
("            I = CartPole.TEL;","            I = RotaryPendulum.TEL;"),
("            res.th_deg = rad2deg(mod(res.th + pi, 2*pi) - pi);",
 "            res.th_deg = rad2deg(res.th);                       % arm: not wrapped\n            res.al_deg = rad2deg(mod(res.al + pi, 2*pi) - pi);  % pendulum: wrapped\n            res.r_deg  = rad2deg(res.r);"),
]
for a,b in rep:
    assert a in s, a[:90]
    s=s.replace(a,b)
open('rotary_pendulum/RotaryPendulum.m','w').write(s)
EOF
grep -n "cp\.\|cp_\|CartPole\|Fmax\|setForce\|crane\|cart" rotary_pendulum/RotaryPendulum.m
```

</details>

<details><summary>Error</summary>

```
Exit code 2
Traceback (most recent call last):
  File "<stdin>", line 57, in <module>
AssertionError: imposing gains by hand: cp.setParamRaw('K_up', [...]).
ugrep: warning: rotary_pendulum/RotaryPendulum.m: No such file or directory
```

</details>

**🔧 Bash** — Find exact setParamRaw comment text

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && grep -n "setParamRaw('K_up'" linear_pendulum/CartPole.m
```

</details>

<details><summary>Output</summary>

```
150:            %   impose gains by hand: cp.setParamRaw('K_up', [...]).
```

</details>

**🔧 Bash** — Generate RotaryPendulum.m

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
s=open('linear_pendulum/CartPole.m').read()
rep=[
("classdef CartPole < handle\n%CARTPOLE  Code interface for the Simulink model of the linear pendulum.",
 "classdef RotaryPendulum < handle\n%ROTARYPENDULUM  Code interface for the Simulink model of the rotary (Furuta) pendulum.\n%\n%   All angles are in radians (theta = arm, alpha = pendulum, 0 = up)."),
("%   cp = CartPole();                 % loads (or generates) cartpole_sim.slx",
 "%   rp = RotaryPendulum();           % loads (or generates) rotpend_sim.slx"),
("%   cp.setInitialState([0 0 0.15 0]);","%   rp.setInitialState([0 0 pi 0]);  % [theta thetad alpha alphad]"),
("%   cp.setMode('lqr');               % 'open','lqr','swingup','pid','crane' (or 0..4)",
 "%   rp.setMode('swingup');           % 'open','lqr','swingup','pid','down' (or 0..4)"),
("%   res = cp.run(8);                 % simulates 8 s and returns a struct of signals\n%   cp_plot_results(res); cp.animate(res);",
 "%   res = rp.run(8);                 % simulates 8 s and returns a struct of signals\n%   rp_plot_results(res); rp.animate(res);"),
("%   cp.start();                      % starts with StopTime = inf and 1x pacing\n%   cp.setRef('sine', 0, 0.2, 0.1);  % type, offset [m], amplitude [m], freq [Hz]\n%   cp.setForce(2);                  % manual force [N] (added to the controller's)\n%   cp.push(1, 0.1);                 % push: 1 N at the tip for 0.1 s\n%   cp.setParam('Qup', diag([100 1 200 1]));   % recomputes the LQR and applies it live\n%   cp.stop(); res = cp.lastResult();",
 "%   rp.start();                      % starts with StopTime = inf and 1x pacing\n%   rp.setRef('sine', 0, pi/4, 0.2); % type, offset [rad], amplitude [rad], freq [Hz]\n%   rp.setVoltage(1);                % manual voltage [V] (added to the controller's)\n%   rp.push(0.05, 0.05);             % push: 0.05 N at the tip for 0.05 s\n%   rp.setParam('Qup', diag([50 0.5 100 0.5]));   % recomputes the LQR and applies it live\n%   rp.stop(); res = rp.lastResult();"),
("%   cp.setRefSignal(t, r)      external reference (activates type 'external')\n%   cp.setForceSignal(t, u)    additional force on the cart (identification)\n%   cp.setDisturbanceSignal(t, Fd)   scheduled disturbance at the tip",
 "%   rp.setRefSignal(t, r)       external arm reference [rad] (activates type 'external')\n%   rp.setVoltageSignal(t, u)   additional motor voltage (identification)\n%   rp.setDisturbanceSignal(t, Fd)   scheduled disturbance force at the tip"),
("%   cp.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 13-signal vector\n%   Indices: CartPole.TEL.x, .xd, .th, .thd, .xm, .thm, .Fcmd, .Fact, .r,\n%            .mode, .E, .caught, .tripped",
 "%   rp.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 13-signal vector\n%   Indices: RotaryPendulum.TEL.th, .thd, .al, .ald, .thm, .alm, .Vcmd, .Vact,\n%            .r, .mode, .E, .caught, .tripped"),
("% parameter struct (cp_params + cp_design)","% parameter struct (rp_params + rp_design)"),
("Model = 'cartpole_sim'","Model = 'rotpend_sim'"),
("TEL = struct('x',1,'xd',2,'th',3,'thd',4,'xm',5,'thm',6, ...\n                     'Fcmd',7,'Fact',8,'r',9,'mode',10,'E',11, ...",
 "TEL = struct('th',1,'thd',2,'al',3,'ald',4,'thm',5,'alm',6, ...\n                     'Vcmd',7,'Vact',8,'r',9,'mode',10,'E',11, ..."),
("MODES = {'open','lqr','swingup','pid','crane'}","MODES = {'open','lqr','swingup','pid','down'}"),
("function obj = CartPole(varargin)","function obj = RotaryPendulum(varargin)"),
("obj.P = cp_params();\n            [obj.P, obj.Lin] = cp_design(obj.P);","obj.P = rp_params();\n            [obj.P, obj.Lin] = rp_design(obj.P);"),
("cp_build_model(obj.Model);","rp_build_model(obj.Model);"),
("setappdata(0, 'CartPoleInstance', obj);","setappdata(0, 'RotaryPendulumInstance', obj);"),
("%SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'crane'","%SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'down'"),
("""        function setForce(obj, u)
            %SETFORCE  Manual force [N] added to the controller's.
            obj.CmdCtrl(3) = max(min(u, obj.P.Fmax), -obj.P.Fmax); obj.applyCmd();""",
"""        function setVoltage(obj, u)
            %SETVOLTAGE  Manual voltage [V] added to the controller's.
            obj.CmdCtrl(3) = max(min(u, obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();"""),
("%SETREF  setRef(type, offset, amplitude, frequency)","%SETREF  setRef(type, offset, amplitude, frequency)   (angles in rad)"),
("""            %PUSH  Horizontal push at the pendulum tip (live).
            if nargin < 2, F = 1; end
            if nargin < 3, dur = 0.1; end""",
"""            %PUSH  Tangential push at the pendulum tip (live). F [N], dur [s].
            if nargin < 2, F = 0.05; end
            if nargin < 3, dur = 0.05; end"""),
("cp_design(obj.P)","rp_design(obj.P)"),
("%SETPARAMS  Several at once: cp.setParams(struct('M',0.8,'m',0.3))","%SETPARAMS  Several at once: rp.setParams(struct('mp',0.03,'Lp',0.15))"),
("impose gains by hand: cp.setParamRaw('K_up', [...]).","impose gains by hand: rp.setParamRaw('K_up', [...])."),
("%SETINITIALSTATE  [x xd theta thetad] for the next start.","%SETINITIALSTATE  [theta thetad alpha alphad] for the next start."),
("        function setForceSignal(~, t, u)","        function setVoltageSignal(~, t, u)"),
("            cp_animate(res, obj.P, speed);","            rp_animate(res, obj.P, speed);"),
("CartPole.instance(mdl)","RotaryPendulum.instance(mdl)"),
("obj = getappdata(0, 'CartPoleInstance');","obj = getappdata(0, 'RotaryPendulumInstance');"),
("            I = CartPole.TEL;","            I = RotaryPendulum.TEL;"),
("            res.th_deg = rad2deg(mod(res.th + pi, 2*pi) - pi);",
 "            res.th_deg = rad2deg(res.th);                       % arm: not wrapped\n            res.al_deg = rad2deg(mod(res.al + pi, 2*pi) - pi);  % pendulum: wrapped\n            res.r_deg  = rad2deg(res.r);"),
]
for a,b in rep:
    assert a in s, a[:90]
    s=s.replace(a,b)
open('rotary_pendulum/RotaryPendulum.m','w').write(s)
EOF
grep -n "cp\.\|cp_\|CartPole\|Fmax\|setForce\|crane\|cart\|Force" rotary_pendulum/RotaryPendulum.m
```

</details>

<details><summary>Output</summary>

```
206:            res = CartPole.parse(out.tel, obj.P);
244:            res = CartPole.parse(out.tel, obj.P);
```

</details>

**🔧 Bash** — Fix parse references

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i 's/res = CartPole.parse(out.tel, obj.P);/res = RotaryPendulum.parse(out.tel, obj.P);/' RotaryPendulum.m && grep -c "RotaryPendulum.parse" RotaryPendulum.m
```

</details>

<details><summary>Output</summary>

```
2
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_draw.m` (3543 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_view.m` (464 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_animate.m` (845 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_plot_results.m` (987 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_draw.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_view.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_animate.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_plot_results.m (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Primera prueba en MATLAB: genero el modelo, simulo el swing-up y renderizo fotogramas de la animación a PNG para revisarlos:

**🔧 Bash** — Build rotary model, run swing-up, render frames

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; mkdir -p $S/rp; cat > $S/rp1.m <<'EOF'
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
O = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/';
try
  rp_build_model();
  rp = RotaryPendulum();
  disp('K_up ='); disp(rp.P.K_up); disp('K_dn ='); disp(rp.P.K_dn);
  disp('poles up OL/CL'); disp([rp.Lin.up.poles_OL rp.Lin.up.poles_CL]);
  rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const', 0);
  res = rp.run(8);
  k = find(res.caught > 0.5, 1);
  fprintf('swing-up: catch at %.3f s, max|th| %.1f deg, final al %.2f deg, Vmax %.1f\n', res.t(k), max(abs(res.th_deg)), res.al_deg(end), max(abs(res.Vact)));
  writematrix([res.t res.th res.thd res.al res.ald res.Vcmd res.Vact res.caught res.r], [O 'swingup.csv']);
  % render frames
  fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1400 900]);
  tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
  ts = [0 0.8 1.5 2.0 2.4 6];
  for i = 1:numel(ts)
    ax = nexttile(tl); h = rp_draw(ax, rp.P);
    j = find(res.t >= ts(i), 1);
    rp_draw(ax, rp.P, h, res.th(j), res.al(j), res.r(j));
    title(ax, sprintf('t = %.1f s  \\theta=%.0f°  \\alpha=%.0f°', res.t(j), res.th_deg(j), res.al_deg(j)));
  end
  exportgraphics(fig, [O 'frames_swingup.png'], 'Resolution', 90);
  rp_plot_results(res, 'Swing-up + LQR'); f2 = gcf; f2.Visible = 'off'; f2.Position = [0 0 900 800];
  exportgraphics(f2, [O 'plot_swingup.png'], 'Resolution', 80);
  disp('DONE');
catch err
  disp(getReport(err, 'extended'));
end
EOF
cd $S && timeout 590 matlab -batch "run('$S/rp1.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -40
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
K_up =
   -4.4721   -1.9780  -50.2905   -4.4173

K_dn =
    4.4721    1.1131    1.8941   -0.0547

poles up OL/CL
   0.0000 + 0.0000i -22.1802 + 0.0000i
 -13.1563 + 0.0000i -10.7894 + 0.0000i
  -0.7582 + 0.0000i  -5.5628 + 2.7157i
  12.7449 + 0.0000i  -5.5628 - 2.7157i

swing-up: catch at 2.236 s, max|th| 42.9 deg, final al 0.10 deg, Vmax 10.0
DONE
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

## 🤖 Claude

Simulink reproduce el prototipo: captura a los 2,236 s, igual que en Python. Reviso los fotogramas renderizados:

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/frames_swingup.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Fix scene geometry and render view options

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='rp_draw.m'; s=open(p).read()
rep=[
("zf  = -0.11;                          % base plate height\nR   = P.Lr + P.Lp + 0.02;             % scene radius",
 "zf  = -(P.Lp + 0.025);                % base plate height (below the hanging pendulum)\nR   = sqrt(P.Lr^2 + P.Lp^2) + 0.015; % scene radius (furthest reach of the tip)\nrr  = P.Lr + 0.016;                   % radius of the reference marker"),
("        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.75 0.75 0.75]);",
 "        'FaceColor', [0.94 0.94 0.94], 'EdgeColor', [0.75 0.75 0.75], 'FaceLighting', 'none');"),
("    h.ref = plot3(ax, P.Lr, 0, 0, 'v', 'MarkerSize', 8, ...","    h.ref = plot3(ax, rr, 0, 0, 'v', 'MarkerSize', 8, ..."),
("    view(ax, 35, 22);","    view(ax, 62, 18);"),
("set(h.ref,   'XData', P.Lr*cos(r), 'YData', P.Lr*sin(r));","set(h.ref,   'XData', rr*cos(r), 'YData', rr*sin(r));"),
]
for a,b in rep:
    assert a in s, a[:60]; s=s.replace(a,b)
open(p,'w').write(s)
s=open('rp_view.m').read(); s=s.replace("otherwise,    view(ax, 35, 22);","otherwise,    view(ax, 62, 18);"); open('rp_view.m','w').write(s)
EOF
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp2.m <<'EOF'
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
O = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/';
P = rp_design(rp_params());
M = readmatrix([O 'swingup.csv']); t = M(:,1);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1500 1000]);
tl = tiledlayout(fig, 3, 4, 'TileSpacing', 'compact');
views = [62 18; 40 20; 75 15];
ts = [0 1.5 2.0 6];
for v = 1:3
  for i = 1:4
    ax = nexttile(tl); h = rp_draw(ax, P);
    j = find(t >= ts(i), 1);
    rp_draw(ax, P, h, M(j,2), M(j,4), M(j,9)); view(ax, views(v,1), views(v,2));
    title(ax, sprintf('view(%d,%d) t=%.1f s  \\theta=%.0f° \\alpha=%.0f°', views(v,1), views(v,2), t(j), rad2deg(M(j,2)), rad2deg(mod(M(j,4)+pi,2*pi)-pi)));
  end
end
exportgraphics(fig, [O 'views.png'], 'Resolution', 80);
EOF
cd $S && timeout 300 matlab -batch "run('$S/rp2.m')" 2>&1 | tail -5
```

</details>

<details><summary>Output</summary>

```
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/views.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Fix plate lighting and default view

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='rp_draw.m'; s=open(p).read()
rep=[("        'FaceColor', [0.94 0.94 0.94], 'EdgeColor', [0.75 0.75 0.75], 'FaceLighting', 'none');",
      "        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.70 0.70 0.70], ...\n        'AmbientStrength', 1, 'DiffuseStrength', 0, 'SpecularStrength', 0);"),
     ("    cyl(ax, 0.028, zf, -0.018, [0.25 0.25 0.28]);","    cyl(ax, 0.028, zf, -0.018, [0.32 0.33 0.36]);"),
     ("    view(ax, 62, 18);","    view(ax, 62, 20);")]
for a,b in rep:
    assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
s=open('rp_view.m').read(); s=s.replace("view(ax, 62, 18);","view(ax, 62, 20);"); open('rp_view.m','w').write(s)
EOF
grep -n "62" rp_draw.m rp_view.m; sed -n 1,80p ../linear_pendulum/cp_gui.m | head -5
```

</details>

<details><summary>Output</summary>

```
rp_view.m:11:    otherwise,    view(ax, 62, 20);
rp_draw.m:48:    view(ax, 62, 20);
function cp = cp_gui(cp)
%CP_GUI  Live visual interface of the linear pendulum (cart-pole).
%
%   cp_gui              creates a new CartPole and opens the panel
%   cp = cp_gui(cp)     uses an existing CartPole object (you can keep
```

</details>

## 🤖 Claude

Escribo la GUI. Tiene la misma disposición que la del péndulo lineal, pero las unidades de la interfaz son grados y voltios, y añade un selector de vista 3D (iso, superior, frontal, lateral):

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_gui.m` (11559 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rp_gui.m (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Pruebo la GUI de verdad: la abro, arranco la simulación en vivo con swing-up, la dejo correr unos segundos y capturo la ventana. A la vez renderizo de nuevo los fotogramas:

**🔧 Bash** — Render frames and test GUI live with screenshots

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp3.m <<'EOF'
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
O = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/';
try
  P = rp_design(rp_params());
  M = readmatrix([O 'swingup.csv']); t = M(:,1);
  fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1400 450]);
  tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact');
  for ts = [0 1.5 2.0 6]
    ax = nexttile(tl); h = rp_draw(ax, P); j = find(t >= ts, 1);
    rp_draw(ax, P, h, M(j,2), M(j,4), M(j,9));
    title(ax, sprintf('t=%.1f s', t(j)));
  end
  exportgraphics(fig, [O 'frames2.png'], 'Resolution', 80);
  % ---- GUI live test ----
  rp = rp_gui();
  f = findall(groot, 'Type', 'figure', 'Name', 'Rotary pendulum — live Simulink');
  drawnow; pause(1);
  exportapp(f, [O 'gui_idle.png']);
  % emulate user: down initial state, swing-up mode, start
  c = findall(f, 'Type', 'uidropdown');
  ic = c(arrayfun(@(x) any(strcmp(x.Items, 'Down (α=180°)')), c));
  ic.Value = 'Down (α=180°)';
  md = c(arrayfun(@(x) any(strcmp(x.Items, '2  Swing-up + LQR')), c));
  md.Value = 2;
  b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start'));
  bs.ButtonPushedFcn(bs, []);
  w0 = tic; while toc(w0) < 12, pause(0.2); end
  fprintf('live: simT=%.2f running=%d\n', rp.LastTime, rp.isRunning());
  exportapp(f, [O 'gui_live.png']);
  bt = b(strcmp({b.Text}, '■ Stop')); bt.ButtonPushedFcn(bt, []);
  pause(1);
  res = rp.lastResult();
  fprintf('after stop: T=%.2f caught=%d final al=%.2f deg\n', res.t(end), res.caught(end), res.al_deg(end));
  disp('DONE');
catch err
  disp(getReport(err, 'extended'));
end
EOF
cd $S && timeout 400 matlab -batch "run('$S/rp3.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -30
```

</details>

<details><summary>Output</summary>

```
live: simT=6.38 running=1
after stop: T=6.38 caught=1 final al=0.10 deg
DONE
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

## 🤖 Claude

La GUI funciona en vivo: el péndulo sube y queda capturado en α = 0,10°. Reviso las capturas:

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/gui_live.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/frames2.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Enlarge 3D scene in GUI

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='rp_gui.m'; s=open(p).read()
a="hA = rp_draw(axA, P);\nrp_draw(axA, P, hA, P.x0(1), P.x0(3), 0);"
b="hA = rp_draw(axA, P);\nrp_draw(axA, P, hA, P.x0(1), P.x0(3), 0);\naxA.XTickLabel = {}; axA.YTickLabel = {}; axA.ZTickLabel = {};   % more room for the scene\nxlabel(axA, ''); ylabel(axA, ''); zlabel(axA, '');\ncamzoom(axA, 1.35);"
assert a in s; s=s.replace(a,b)
a="L.RowHeight = {'1.9x', '1x', '1x', '1x'};"; assert a in s; s=s.replace(a,"L.RowHeight = {'2.2x', '1x', '1x', '1x'};")
a="    'Value', 'iso', 'ValueChangedFcn', @(s,~) rp_view(axA, s.Value));"
assert a in s
open(p,'w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Ahora `examples.m`, la validación y el README:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/examples.m` (4219 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/run_validation.m` (2892 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/compare_with_python.py` (3786 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/examples.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/run_validation.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/compare_with_python.py (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Ejecuto la validación completa en Simulink y la comparo con la réplica de Python:

**🔧 Bash** — Run rotary validation and compare with Python

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation && timeout 590 matlab -batch "run_validation" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -5 && cd /tmp && python3 -I /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/compare_with_python.py; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
Validation runs written to /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/results
case         RMS dth[deg]  max dth RMS dal[deg]  max dal | metric python vs simulink
lqr_ic              0.075    0.275        0.023    0.142 | al settle(1deg) 0.40 vs 0.41 s, Vmax 8.8 vs 8.8 V
lqr_step            0.235    0.873        0.036    0.200 | th settle(5%) 0.72 vs 0.72 s, min th -3.4 vs -3.4 deg
lqr_push            0.257    1.146        0.068    0.348 | al settle(1deg) 1.90 vs 1.90 s, Vmax 10.0 vs 10.0 V
swingup             0.153    0.644        0.269    1.204 | catch 2.236 vs 2.236 s, max|th| 42.9 vs 42.9 deg
pid_ic              0.057    0.210        0.023    0.159 | al settle(1deg) 0.35 vs 0.35 s, Vmax 8.7 vs 8.7 V
pid_step            0.108    0.438        0.020    0.169 | th settle(5%) 0.91 vs 0.91 s, min th -3.4 vs -3.4 deg
down_step           0.025    0.121        0.025    0.118 | residual sway t>4s: 0.41 vs 0.41 deg
down_nosway         0.025    0.122        0.033    0.127 | residual sway t>4s: 1.60 vs 1.60 deg

lqr_step_ratelim: th settle(5%) 0.94 s, min th -0.9 deg, Vmax 3.0 V
sine 0.2 Hz: gain 0.999, phase lag 28.5 deg, Vmax 3.1 V, tripped=0
sine 0.5 Hz: gain 0.905, phase lag 73.3 deg, Vmax 3.7 V, tripped=0
sine 1 Hz: gain 0.657, phase lag 138.5 deg, Vmax 3.5 V, tripped=0
noise on: alpha std after 2 s 0.050 deg, V std 1.18 V, theta std 0.34 deg
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Run examples.m sections 0-9 headless

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed '/^%% 10)/,$d' examples.m | sed 's/^clear; close all; clc$/close all; clc; set(0,"DefaultFigureVisible","off");/' > $S/examples_test.m && grep -n "DefaultFigureVisible\|%% 9" $S/examples_test.m && timeout 590 matlab -batch "cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum'); try, run('$S/examples_test.m'); disp('EXAMPLES OK'); catch e, disp(getReport(e,'extended')); end" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -25
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/README.md` (6408 characters)

<details><summary>Output</summary>

```
Command running in background with ID: bh9nwukr2. Output is being written to: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/tasks/bh9nwukr2.output. You will be notified when it completes — do not poll that file or sleep while waiting. Read the file only if the user asks for progress, or if you need a line it prints before you can go on, such as a server's ready line or port.
Session cwd remains /home/aguti/universidad/controlSystemsMatlabModels; directory changes made by the backgrounded command do not apply to subsequent commands.
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/README.md (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/generate_data.m` (9740 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/generate_data.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Read examples test output

<details><summary>Command</summary>

```bash
tail -30 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/tasks/bh9nwukr2.output
```

</details>

<details><summary>Output</summary>

```
7:close all; clc; set(0,"DefaultFigureVisible","off");
91:%% 9) Live mode from code (no GUI): commands while simulating
Unrecognized function or variable 'rp_build_model'.

Error in examples_test (line 8)
rp_build_model();          % (re)generates rotpend_sim.slx — only needed the first time
^^^^^^^^^^^^^^^^
Error in run (line 112)
evalin('caller', strcat(scriptStem, ';'));
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

[exited with code 0]
```

</details>

## 🤖 Claude

Este fallo lo provoca mi prueba, no el código: `run()` cambia a la carpeta del script de prueba y pierde la ruta. Lo relanzo añadiendo la ruta:

**🔧 Bash** — Rerun examples.m test with path

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; timeout 590 matlab -batch "addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum'); cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum'); try, run('$S/examples_test.m'); disp('EXAMPLES OK'); catch e, disp(getReport(e,'extended')); end" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -25
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
LQR gain (up):
   -4.4721   -1.9780  -50.2905   -4.4173

Open-loop poles (up):
         0  -13.1563   -0.7582   12.7449

Closed-loop poles (up):
 -22.1802 + 0.0000i -10.7894 + 0.0000i  -5.5628 + 2.7157i  -5.5628 - 2.7157i

EXAMPLES OK
```

</details>

## 🤖 Claude

`examples.m` corre entero sin errores. Ahora genero los datos del manual (simulaciones, valores numéricos, fotogramas y captura de la GUI):

**🔧 Bash** — Generate manual data from Simulink

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data && timeout 590 matlab -batch "generate_data" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -15; cat num.txt; ls
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
Manual data written to /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data
K_up = [-4.472 -1.978 -50.29 -4.417]
K_dn = [4.472 1.113 1.894 -0.05471]
A_up = [0 1 0 0;0 -1.115 -53.96 0.01777;0 0 0 1;0 1.102 167.4 -0.05512]
B_up = [0;17.98;0;-17.77]
A_dn = [0 1 0 0;0 -1.115 -53.96 -0.01777;0 0 0 1;0 -1.102 -167.4 -0.05512]
B_dn = [0;17.98;0;17.77]
poles_OL_up = [0 -13.16 -0.7582 12.74]
poles_CL_up = [-22.18 -10.79 -5.563+2.716i -5.563-2.716i]
poles_OL_dn = [0 -0.7607 -0.2045+12.93i -0.2045-12.93i]
poles_CL_dn = [-7.507+3.205i -7.507-3.205i -2.597+11.44i -2.597-11.44i]
J0 = 0.0004082  Ja = 0.0001331  Jr = 0.0002348  Jp = 3.328e-05  hc = 0.0001316
beq = 0.00031  b_emf = 0.00021  wn_down = 10.68
zpk_up_y1: zeros=[-10.7 10.66]  poles=[0 -13.16 -0.7582 12.74]  k=17.98
zpk_up_y2: zeros=[0 5.183e-17]  poles=[0 -13.16 -0.7582 12.74]  k=-17.77
rank_ctrb_up = 4  cond = 813
rank_obs_up: theta only 4, alpha only 3
zpk_dn_y1: zeros=[-0.01878+10.68i -0.01878-10.68i]  poles=[0 -0.7607 -0.2045+12.93i -0.2045-12.93i]  k=17.98
zpk_dn_y2: zeros=[0 5.183e-17]  poles=[0 -0.7607 -0.2045+12.93i -0.2045-12.93i]  k=17.77
rank_ctrb_dn = 4  cond = 802
rank_obs_dn: theta only 4, alpha only 3
poles_PID = [-13.74+13.99i -13.74-13.99i -4.402+1.398i -4.402-1.398i]
lqr_ic: Vmax 8.79, settle1deg 0.41, max|th| 23.8
lqr_step (rate limited): min th -0.87, settle5% 0.94, max|al| 2.22, Vmax 3.03
lqr_push: max|al| 14.97, max|th| 57.29, Vmax 10.00, settle 1.90
swingup: catch 2.236 s, max|th| 42.9, Vmax 10.0, E0 -0.03037
pid_ic: Vmax 8.74, settle 0.35
pid_step: min th -0.84, settle5% 1.12, final th 45.89
down_step 90: sway t>4 0.26, max sway 4.25, settle 1.16
down_nosway 90: sway t>4 0.87, max sway 4.62
qsweep 10: K [-4.47 -1.96 -49.5 -4.38] Vmax 8.65 settle 0.40
qsweep 50: K [-4.47 -1.98 -50.3 -4.42] Vmax 8.79 settle 0.41
qsweep 250: K [-4.47 -2.05 -54 -4.57] Vmax 9.48 settle 0.41
rsweep 0.2: K [-10 -4.01 -84.7 -7.65] Vmax 10.00 settle 0.35
rsweep 5: K [-2 -1.06 -35.1 -2.99] Vmax 6.13 settle 0.52
msweep 0.012: settle 0.41 final al -0.07 stable 1
msweep 0.048: settle 0.76 final al -0.03 stable 1
msweep 0.072: settle 0.76 final al -0.02 stable 1
sine 0.2 Hz: gain 0.999 lag 28.5
sine 0.5 Hz: gain 0.905 lag 73.3
sine 1 Hz: gain 0.657 lag 138.5
noise: al std 0.050 deg, V std 1.18, th std 0.34 deg
quantization only: V std 1.10
frames at t = [0 1.2 1.6 2.15 4]
bode_dn_al.dat
bode_dn_th.dat
bode_up_al.dat
bode_up_th.dat
down_nosway.dat
down_step.dat
frames.png
generate_data.m
gui.png
lqr_ic.dat
lqr_locus.dat
lqr_noise.dat
lqr_push.dat
lqr_step.dat
msweep_0.012.dat
msweep_0.048.dat
msweep_0.072.dat
num.txt
pid_ic.dat
pid_step.dat
qsweep_10.dat
qsweep_250.dat
qsweep_50.dat
rsweep_0.2.dat
rsweep_5.dat
sine_0.5.dat
swingup.dat
velest.dat
```

</details>

## 🤖 Claude

Los datos están generados. Antes de escribir reviso las dos imágenes que irán en el manual:

**🔧 Read** {"file_path": "/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/frames.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Read** {"file_path": "/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/gui.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Compare live vs batch swing-up trajectories

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp4.m <<'EOF'
addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
try
rp = RotaryPendulum();
rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const', 0);
rb = rp.run(6);
for trial = 1:3
  rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const', 0);
  if trial == 3, rp.addTelemetryCallback(@(t,d) drawnow('limitrate')); end
  rp.start(); w0 = tic; while rp.LastTime < 4 && toc(w0) < 60, pause(0.1); end
  rp.stop(); rl = rp.lastResult();
  n = min(numel(rl.t), numel(rb.t));
  fprintf('trial %d: batch max th %.1f catch %.3f | live max th %.1f catch %.3f | max|dth| first 1.5 s %.4f deg, n=%d dt live %.4g\n', trial, ...
    max(abs(rb.th_deg(rb.t<4))), rb.t(find(rb.caught>0.5,1)), max(abs(rl.th_deg)), rl.t(find(rl.caught>0.5,1)), ...
    max(abs(rb.th_deg(1:min(n,1500)) - rl.th_deg(1:min(n,1500)))), numel(rl.t), median(diff(rl.t)));
  k = find(abs(rb.th_deg(1:n) - rl.th_deg(1:n)) > 0.01, 1);
  if ~isempty(k), fprintf('   first divergence at t = %.4f s (batch t %.4f)\n', rl.t(k), rb.t(k)); end
end
catch err, disp(getReport(err,'extended')); end
EOF
timeout 400 matlab -batch "run('$S/rp4.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -12
```

</details>

<details><summary>Output</summary>

```
trial 1: batch max th 42.9 catch 2.236 | live max th  catch  | max|dth| first 1.5 s  deg, n=0 dt live NaN
trial 2: batch max th 42.9 catch 2.236 | live max th  catch  | max|dth| first 1.5 s  deg, n=0 dt live NaN
trial 3: batch max th 42.9 catch 2.236 | live max th  catch  | max|dth| first 1.5 s  deg, n=0 dt live NaN
```

</details>

**🔧 Bash** — Debug live run after batch run

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp5.m <<'EOF'
addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
try
rp = RotaryPendulum();
rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const', 0);
rb = rp.run(6);
rp.start(); w0 = tic;
while toc(w0) < 25
  pause(0.5);
  fprintf('wall %.1f status %s LastTime %.2f\n', toc(w0), get_param(rp.Model,'SimulationStatus'), rp.LastTime);
  if rp.LastTime > 4, break; end
end
rp.stop();
fprintf('status after stop: %s; exist out=%d\n', get_param(rp.Model,'SimulationStatus'), evalin('base','exist(''out'',''var'')'));
rl = rp.lastResult(); fprintf('n live=%d\n', numel(rl.t));
n = min(numel(rl.t), numel(rb.t));
fprintf('batch max th %.1f catch %.3f | live max th %.1f catch %.3f\n', max(abs(rb.th_deg(rb.t<4))), rb.t(find(rb.caught>0.5,1)), max(abs(rl.th_deg)), rl.t(find(rl.caught>0.5,1)));
k = find(abs(rb.th_deg(1:n) - rl.th_deg(1:n)) > 0.01, 1);
if ~isempty(k), fprintf('first divergence at t = %.4f s\n', rl.t(k)); else, disp('identical'); end
catch err, disp(getReport(err,'extended')); end
EOF
timeout 400 matlab -batch "run('$S/rp5.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -20
```

</details>

<details><summary>Output</summary>

```
wall 0.5 status running LastTime 0.49
wall 1.0 status running LastTime 0.99
wall 1.5 status running LastTime 1.49
wall 2.0 status running LastTime 1.99
wall 2.5 status running LastTime 2.49
wall 3.0 status running LastTime 2.99
wall 3.5 status running LastTime 3.50
wall 4.0 status running LastTime 4.00
wall 4.5 status running LastTime 4.50
status after stop: stopped; exist out=1
n live=4498
batch max th 42.9 catch 2.236 | live max th 42.9 catch 2.236
identical
```

</details>

**🔧 Bash** — Reproduce trajectory difference after noise toggle

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='RotaryPendulum.m'; s=open(p).read()
a="            obj.pushParams(); obj.applyCmd();\n            set_param(obj.Model, 'StopTime', 'inf',"
assert a in s
s=s.replace(a,"            obj.pushParams(); obj.applyCmd();\n            obj.LastTime = 0; obj.Last = zeros(13,1);\n            set_param(obj.Model, 'StopTime', 'inf',")
open(p,'w').write(s)
EOF
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp6.m <<'EOF'
addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
try
sw = @(rp) rp.run(4);
rp = RotaryPendulum(); rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const',0);
r0 = sw(rp); fprintf('fresh: max th %.2f\n', max(abs(r0.th_deg)));
rp.setParam('noise_on', 1); rp.setInitialState([0 0 deg2rad(10) 0]); rp.setMode('lqr'); rp.run(1);
rp.setParam('noise_on', 0);
rp2 = RotaryPendulum(); rp2.setInitialState([0 0 pi 0]); rp2.setMode('swingup'); rp2.setRef('const',0);
r1 = sw(rp2); fprintf('after noise on/off + new object: max th %.2f\n', max(abs(r1.th_deg)));
P = evalin('base','P'); fprintf('base P.noise_on = %d\n', P.noise_on);
rp2.setParam('noise_on', 1); rp2.setParam('noise_on', 0);
r2 = sw(rp2); fprintf('same object noise on/off: max th %.2f\n', max(abs(r2.th_deg)));
rp3 = RotaryPendulum(); rp3.setInitialState([0 0 pi 0]); rp3.setMode('swingup');
rp3.setRef('sine', 0, pi/4, 0.5); rp3.setRef('const', 0);
r3 = sw(rp3); fprintf('after sine->const: max th %.2f\n', max(abs(r3.th_deg)));
catch err, disp(getReport(err,'extended')); end
EOF
timeout 400 matlab -batch "run('$S/rp6.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -12
```

</details>

<details><summary>Output</summary>

```
fresh: max th 42.86
after noise on/off + new object: max th 42.86
base P.noise_on = 0
same object noise on/off: max th 42.86
after sine->const: max th 42.86
```

</details>

## 🤖 Claude

Ninguna combinación reproduce la diferencia fuera de la GUI. Repito la prueba de la GUI dos veces y comparo cada ejecución en vivo, muestra a muestra, con la simulación por lotes:

**🔧 Bash** — GUI live run vs batch comparison

<details><summary>Command</summary>

```bash
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp7.m <<'EOF'
addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
try
rp = RotaryPendulum(); rp.setInitialState([0 0 pi 0]); rp.setMode('swingup'); rp.setRef('const',0);
rb = rp.run(5);
for trial = 1:2
  rp_gui(rp);
  f = findall(groot, 'Type', 'figure', 'Name', 'Rotary pendulum — live Simulink');
  c = findall(f, 'Type', 'uidropdown');
  c(arrayfun(@(x) any(strcmp(x.Items, 'Down (α=180°)')), c)).Value = 'Down (α=180°)';
  c(arrayfun(@(x) any(strcmp(x.Items, '2  Swing-up + LQR')), c)).Value = 2;
  b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start')); bs.ButtonPushedFcn(bs, []);
  w0 = tic; while rp.LastTime < 4.5 && toc(w0) < 60, pause(0.1); end
  rp.stop(); pause(0.5); rl = rp.lastResult(); delete(f);
  n = min(numel(rl.t), numel(rb.t));
  k = find(abs(rb.th_deg(1:n) - rl.th_deg(1:n)) > 0.01, 1);
  fprintf('trial %d: live max th %.1f catch %.3f, x0=%s, Pk %s, first div t=%s, ref max %.3f, mode %s, Vman max %.2f\n', trial, ...
     max(abs(rl.th_deg)), rl.t(find(rl.caught>0.5,1)), mat2str(rp.P.x0',3), mat2str(rp.P.K_up,3), mat2str(rl.t(k)), max(abs(rl.r)), mat2str(unique(rl.mode)'), max(abs(rl.Vcmd - 0)));
  fprintf('   CmdCtrl %s CmdRef %s\n', mat2str(rp.CmdCtrl,3), mat2str(rp.CmdRef,3));
end
catch err, disp(getReport(err,'extended')); end
EOF
timeout 400 matlab -batch "run('$S/rp7.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -12
```

</details>

<details><summary>Output</summary>

```
trial 1: live max th 42.9 catch 2.236, x0=[0 0 3.14 0], Pk [-4.47 -1.98 -50.3 -4.42], first div t=zeros(0,1), ref max 0.000, mode 2, Vman max 10.00
   CmdCtrl [2 1 0] CmdRef [0 0 0.785 0.2]
trial 2: live max th 42.9 catch 2.236, x0=[0 0 3.14 0], Pk [-4.47 -1.98 -50.3 -4.42], first div t=zeros(0,1), ref max 0.000, mode 2, Vman max 10.00
   CmdCtrl [2 1 0] CmdRef [0 0 0.785 0.2]
```

</details>

**🔧 Bash** — Update sweep and GUI zoom, regenerate data

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels && python3 - <<'EOF'
p='src/rotary_pendulum/rp_gui.m'; s=open(p).read()
for a,b in [("camzoom(axA, 1.35);","camzoom(axA, 1.15);"),("L.RowHeight = {'2.2x', '1x', '1x', '1x'};","L.RowHeight = {'2.5x', '1x', '1x', '1x'};")]:
    assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
p='doc/src/rotary_pendulum/data/generate_data.m'; s=open(p).read()
rep=[("""% Q_alpha and R sweeps (LQR from 10 deg)
rp.setMode('lqr'); rp.setRef('const', 0); rp.setInitialState([0 0 deg2rad(10) 0]);
for q = [10 50 250]
    rp.setParam('Qup', diag([P.Qup(1,1) P.Qup(2,2) q P.Qup(4,4)]));""",
"""% Q_theta and R sweeps (LQR from 10 deg)
rp.setMode('lqr'); rp.setRef('const', 0); rp.setInitialState([0 0 deg2rad(10) 0]);
for q = [5 20 80]
    rp.setParam('Qup', diag([q P.Qup(2,2) P.Qup(3,3) P.Qup(4,4)]));"""),
("""    res = rp.run(3); save_(D, sprintf('qsweep_%d', q), res);
    pr('qsweep %d: K %s Vmax %.2f settle %.2f\\n', q, mat2str(rp.P.K_up, 3), max(abs(res.Vact)), settle(res.t, res.al_deg, 1));""",
"""    res = rp.run(3); save_(D, sprintf('qsweep_%d', q), res);
    pr('qsweep Qth=%d: K %s Vmax %.2f settle %.2f max|th| %.1f\\n', q, mat2str(rp.P.K_up, 3), max(abs(res.Vact)), ...
        settle(res.t, res.al_deg, 1), max(abs(res.th_deg)));"""),
("""for q = logspace(0, 4, 40)
    K = rp_lqr(lin.up.A, lin.up.B, diag([P.Qup(1,1) P.Qup(2,2) q P.Qup(4,4)]), P.Rup);""",
"""for q = logspace(-1, 3, 40)
    K = rp_lqr(lin.up.A, lin.up.B, diag([q P.Qup(2,2) P.Qup(3,3) P.Qup(4,4)]), P.Rup);"""),
("""exportapp(f, fullfile(D, 'gui.png'));
rp.stop(); delete(f);""",
"""exportapp(f, fullfile(D, 'gui.png'));
rp.stop(); pause(0.5); rl = rp.lastResult(); delete(f);
pr('gui run: max|th| %.1f, catch %.3f, x0 %s, CmdCtrl %s, CmdRef %s\\n', max(abs(rl.th_deg)), ...
    rl.t(find(rl.caught > 0.5, 1)), mat2str(rp.P.x0', 3), mat2str(rp.CmdCtrl, 3), mat2str(rp.CmdRef, 3));"""),
]
for a,b in rep:
    assert a in s, a[:60]; s=s.replace(a,b)
open(p,'w').write(s)
EOF
cd doc/src/rotary_pendulum/data && rm -f *.dat *.png num.txt && timeout 590 matlab -batch "generate_data" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -5; grep -E "qsweep|gui run|swingup" num.txt
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
Manual data written to /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data
swingup: catch 2.236 s, max|th| 42.9, Vmax 10.0, E0 -0.03037
qsweep Qth=5: K [-2.24 -1.4 -42.7 -3.71] Vmax 7.48 settle 0.49 max|th| 27.1
qsweep Qth=20: K [-4.47 -1.98 -50.3 -4.42] Vmax 8.79 settle 0.41 max|th| 23.8
qsweep Qth=80: K [-8.94 -3.06 -64.2 -5.72] Vmax 10.00 settle 0.65 max|th| 21.5
gui run: max|th| 42.9, catch 2.236, x0 [0 0 3.14 0], CmdCtrl [2 1 0], CmdRef [0 0 0.785 0.2]
```

</details>

**🔧 Read** {"file_path": "/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/gui.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Remove zoom, recapture GUI mid swing-up

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='rp_gui.m'; s=open(p).read()
for a,b in [("\ncamzoom(axA, 1.15);",""),("L.RowHeight = {'2.5x', '1x', '1x', '1x'};","L.RowHeight = {'3x', '1x', '1x', '1x'};")]:
    assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
EOF
S=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad; cat > $S/rp8.m <<'EOF'
addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
cd('/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum');
rp = RotaryPendulum(); rp_gui(rp);
f = findall(groot, 'Type', 'figure', 'Name', 'Rotary pendulum — live Simulink');
c = findall(f, 'Type', 'uidropdown');
c(arrayfun(@(x) any(strcmp(x.Items, '2  Swing-up + LQR')), c)).Value = 2;
c(arrayfun(@(x) any(strcmp(x.Items, 'Down (α=180°)')), c)).Value = 'Down (α=180°)';
b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start')); bs.ButtonPushedFcn(bs, []);
w0 = tic; while rp.LastTime < 1.55 && toc(w0) < 60, pause(0.02); end
exportapp(f, '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/gui3.png');
rp.stop();
EOF
timeout 300 matlab -batch "run('$S/rp8.m')" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -5
```

</details>

<details><summary>Output</summary>

```
(Bash completed with no output)
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rp/gui3.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Add plot padding; read manual style samples

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels && python3 - <<'EOF'
p='src/rotary_pendulum/rp_gui.m'; s=open(p).read()
a="legend(axT, {'\\theta', 'r'}, 'Location', 'northwest');"
assert a in s
s=s.replace(a,a+"\ntry, set([axT axP axV], 'YLimitMethod', 'padded'); catch, end   % R2021a+")
open(p,'w').write(s)
EOF
sed -n 1,60p doc/src/linear_pendulum/cap8_practicas.tex; sed -n 1,40p doc/src/linear_pendulum/cap2_modelo.tex
```

</details>

<details><summary>Output</summary>

```
\chapter{Prácticas guiadas}
\label{cap:practicas}

Las prácticas están ordenadas de menor a mayor dificultad. Cada una indica sus objetivos, el procedimiento con el código necesario, las cuestiones a responder y lo que debe entregarse. Al empezar cada sesión conviene ejecutar:
\begin{lstlisting}
clear; close all; cp = CartPole(); cp.clearSignals();
\end{lstlisting}
Los valores numéricos que se citan como referencia corresponden a los parámetros por defecto.

% ----------------------------------------------------------------
\stepcounter{practica}
\begin{practica}{Exploración en lazo abierto y validación del modelo}
\objetivos
\begin{itemize}
  \item Familiarizarse con la interfaz y comprobar el modelo frente a la teoría.
  \item Medir la frecuencia y el amortiguamiento de la oscilación colgante.
\end{itemize}
\procedimiento
\begin{enumerate}
  \item Ensayo de caída libre desde arriba (sin control):
\begin{lstlisting}
cp.setMode('open'); cp.setInitialState([0 0 0.01 0]);
res = cp.run(3); cp_plot_results(res); cp.animate(res);
\end{lstlisting}
  \item Ajustar a los primeros \SI{0.5}{s} una exponencial $\theta(t)\approx\theta_0\cosh(pt)$ y estimar $p$.
  \item Oscilación libre colgando: \code{cp.setInitialState([0 0 pi-0.2 0]); res = cp.run(20);}. Medir el periodo y el decremento logarítmico $\delta=\ln(A_k/A_{k+1})$, y calcular $\zeta=\delta/\sqrt{4\pi^2+\delta^2}$.
  \item Repetir el punto anterior con el carro bloqueado (\code{cp.setParam('M',1e3)}) y comparar con $\omega_0=\sqrt{mgl/\Jp}$.
\end{enumerate}
\preguntas
\begin{enumerate}
  \item ¿Coincide $p$ con el polo inestable de la tabla~\ref{tab:polos} ($5{,}45$)? ¿Por qué no exactamente?
  \item Explicar por qué la frecuencia con el carro libre (\SI{0.89}{Hz}) es mayor que con el carro bloqueado (\SI{0.79}{Hz}).
  \item ¿Qué fricción domina el amortiguamiento de la oscilación, la del carro o la del pivote? Comprobarlo variando \code{bc} y \code{bp}.
\end{enumerate}
\entregables Gráficas de los tres ensayos y una tabla comparativa entre teoría y simulación.
\end{practica}

% ----------------------------------------------------------------
\stepcounter{practica}
\begin{practica}{Identificación experimental con una señal chirp}
\objetivos Obtener la respuesta en frecuencia del sistema colgante a partir de datos y compararla con la figura~\ref{fig:bode}.
\procedimiento
\begin{enumerate}
  \item Generar un chirp de fuerza de \SI{0.7}{N} entre \SI{0.5}{Hz} y \SI{3}{Hz} durante \SI{20}{s} y aplicarlo en lazo abierto:
\begin{lstlisting}
T = 20; tt = (0:cp.P.h:T)'; f0 = 0.5; f1 = 3;
u = 0.7*sin(2*pi*(f0*tt + (f1-f0)/(2*T)*tt.^2));
cp.setInitialState([0 0 pi 0]); cp.setMode('open');
cp.setForceSignal(tt, u); res = cp.run(T); cp.clearSignals();
\end{lstlisting}
  \item Estimar la respuesta en frecuencia con \code{tfestimate(res.Fact, mod(res.th,2*pi)-pi, [], [], [], 1/cp.P.h)}, de la Signal Processing Toolbox, o dividiendo directamente las FFT.
  \item Ajustar un modelo de segundo orden a $\Theta/F$ cer
... [truncated, 2652 more characters]
```

</details>

## 🤖 Claude

Antes de redactar, cojo los valores definitivos que citará el texto:

**🔧 Bash** — Show final numeric values for the manual

<details><summary>Command</summary>

```bash
cat /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/num.txt; head -3 /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/swingup.dat; python3 -c "
import numpy as np
d=np.loadtxt('/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/bode_dn_th.dat',skiprows=1); i=np.argmax(d[:,1]); j=np.argmin(d[20:,1])+20
print('dn th: peak f',d[i,0],d[i,1],' notch',d[j,0],d[j,1])
d=np.loadtxt('/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/bode_dn_al.dat',skiprows=1); i=np.argmax(d[:,1]); print('dn al peak',d[i,0],d[i,1])
"
```

</details>

<details><summary>Output</summary>

```
K_up = [-4.472 -1.978 -50.29 -4.417]
K_dn = [4.472 1.113 1.894 -0.05471]
A_up = [0 1 0 0;0 -1.115 -53.96 0.01777;0 0 0 1;0 1.102 167.4 -0.05512]
B_up = [0;17.98;0;-17.77]
A_dn = [0 1 0 0;0 -1.115 -53.96 -0.01777;0 0 0 1;0 -1.102 -167.4 -0.05512]
B_dn = [0;17.98;0;17.77]
poles_OL_up = [0 -13.16 -0.7582 12.74]
poles_CL_up = [-22.18 -10.79 -5.563+2.716i -5.563-2.716i]
poles_OL_dn = [0 -0.7607 -0.2045+12.93i -0.2045-12.93i]
poles_CL_dn = [-7.507+3.205i -7.507-3.205i -2.597+11.44i -2.597-11.44i]
J0 = 0.0004082  Ja = 0.0001331  Jr = 0.0002348  Jp = 3.328e-05  hc = 0.0001316
beq = 0.00031  b_emf = 0.00021  wn_down = 10.68
zpk_up_y1: zeros=[-10.7 10.66]  poles=[0 -13.16 -0.7582 12.74]  k=17.98
zpk_up_y2: zeros=[0 5.183e-17]  poles=[0 -13.16 -0.7582 12.74]  k=-17.77
rank_ctrb_up = 4  cond = 813
rank_obs_up: theta only 4, alpha only 3
zpk_dn_y1: zeros=[-0.01878+10.68i -0.01878-10.68i]  poles=[0 -0.7607 -0.2045+12.93i -0.2045-12.93i]  k=17.98
zpk_dn_y2: zeros=[0 5.183e-17]  poles=[0 -0.7607 -0.2045+12.93i -0.2045-12.93i]  k=17.77
rank_ctrb_dn = 4  cond = 802
rank_obs_dn: theta only 4, alpha only 3
poles_PID = [-13.74+13.99i -13.74-13.99i -4.402+1.398i -4.402-1.398i]
lqr_ic: Vmax 8.79, settle1deg 0.41, max|th| 23.8
lqr_step (rate limited): min th -0.87, settle5% 0.94, max|al| 2.22, Vmax 3.03
lqr_push: max|al| 14.97, max|th| 57.29, Vmax 10.00, settle 1.90
swingup: catch 2.236 s, max|th| 42.9, Vmax 10.0, E0 -0.03037
pid_ic: Vmax 8.74, settle 0.35
pid_step: min th -0.84, settle5% 1.12, final th 45.89
down_step 90: sway t>4 0.26, max sway 4.25, settle 1.16
down_nosway 90: sway t>4 0.87, max sway 4.62
qsweep Qth=5: K [-2.24 -1.4 -42.7 -3.71] Vmax 7.48 settle 0.49 max|th| 27.1
qsweep Qth=20: K [-4.47 -1.98 -50.3 -4.42] Vmax 8.79 settle 0.41 max|th| 23.8
qsweep Qth=80: K [-8.94 -3.06 -64.2 -5.72] Vmax 10.00 settle 0.65 max|th| 21.5
rsweep 0.2: K [-10 -4.01 -84.7 -7.65] Vmax 10.00 settle 0.35
rsweep 5: K [-2 -1.06 -35.1 -2.99] Vmax 6.13 settle 0.52
msweep 0.012: settle 0.41 final al -0.07 stable 1
msweep 0.048: settle 0.76 final al -0.03 stable 1
msweep 0.072: settle 0.76 final al -0.02 stable 1
sine 0.2 Hz: gain 0.999 lag 28.5
sine 0.5 Hz: gain 0.905 lag 73.3
sine 1 Hz: gain 0.657 lag 138.5
noise: al std 0.050 deg, V std 1.18, th std 0.34 deg
quantization only: V std 1.10
frames at t = [0 1.2 1.6 2.15 4]
gui run: max|th| 42.9, catch 2.236, x0 [0 0 3.14 0], CmdCtrl [2 1 0], CmdRef [0 0 0.785 0.2]
t th al V r caught E
0 0 -180 1.33508 0 0 -30.3718
0.005 0.0164406 -179.984 1.33508 0 0 -30.3718
dn th: peak f 0.1 25.92  notch 100.0 -86.832
dn al peak 2.06244 10.3962
```

</details>

## 🤖 Claude

Tengo todos los valores. Escribo el manual con la misma plantilla que el del péndulo lineal. Primero el documento principal:

**🔧 Bash** — Create manual.tex from linear template

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src && python3 - <<'EOF'
s=open('linear_pendulum/manual.tex').read()
start=s.index('\\usepackage[hidelinks]{hyperref}')
pre=s[:start]
post=r"""\usepackage{graphicx}
\usepackage[hidelinks]{hyperref}
\hypersetup{pdftitle={Manual del péndulo rotacional (péndulo de Furuta)},
  pdfauthor={Serie de experimentos de sistemas de control}}

% ------------------------------------------------------------------
% Macros
% ------------------------------------------------------------------
\newcommand{\dd}{\mathrm{d}}
\newcommand{\vect}[1]{\bm{#1}}
\newcommand{\code}[1]{\texttt{#1}}
\newcommand{\thd}{\dot{\theta}}
\newcommand{\thdd}{\ddot{\theta}}
\newcommand{\ald}{\dot{\alpha}}
\newcommand{\aldd}{\ddot{\alpha}}
\newcommand{\Ja}{J_\alpha}
\renewcommand{\figurename}{Figura}
\renewcommand{\tablename}{Tabla}
\renewcommand{\contentsname}{Índice}
\renewcommand{\listfigurename}{Índice de figuras}
\renewcommand{\chaptername}{Capítulo}
\renewcommand{\appendixname}{Apéndice}
\renewcommand{\bibname}{Bibliografía}
\renewcommand{\lstlistingname}{Listado}

\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\nouppercase{\leftmark}}
\fancyhead[R]{\small Péndulo rotacional}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.4pt}
\fancypagestyle{plain}{\fancyhf{}\fancyfoot[C]{\thepage}\renewcommand{\headrulewidth}{0pt}}

\setlength{\parskip}{0.35em}
\setlist{itemsep=0.15em,topsep=0.3em}

\begin{document}

% ------------------------------------------------------------------
% Portada
% ------------------------------------------------------------------
\begin{titlepage}
\centering
\vspace*{1.2cm}
{\large Serie de experimentos de sistemas de control\par}
\vspace{0.4cm}
{\color{c1}\rule{\linewidth}{1.2pt}\par}
\vspace{0.4cm}
{\Huge\bfseries Péndulo rotacional\\[0.2em] (péndulo de Furuta)\par}
\vspace{0.4cm}
{\Large Manual teórico y práctico\par}
\vspace{0.2cm}
{\large Modelado, análisis, control y simulación en MATLAB/Simulink\par}
{\color{c1}\rule{\linewidth}{1.2pt}\par}
\vspace{1.0cm}
\input{fig_sistema}
\vfill
{\large Versión 1.0 \quad·\quad Noviembre 2026\par}
\vspace{0.6cm}
{\small Acompaña al paquete de software \code{rotary\_pendulum} (\code{rp\_build\_model}, \code{RotaryPendulum}, \code{rp\_gui}).\par}
\end{titlepage}

\tableofcontents
\listoffigures

\input{cap1_intro}
\input{cap2_modelo}
\input{cap3_analisis}
\input{cap4_sensores}
\input{cap5_control}
\input{cap6_simulink}
\input{cap7_codigo}
\input{cap8_practicas}

\appendix
\input{apendices}

\begin{thebibliography}{9}
\bibitem{furuta1992} K.~Furuta, M.~Yamakita y S.~Kobayashi, «Swing-up control of inverted pendulum using pseudo-state feedback», \emph{Proc. IMechE, Part I}, 206(4):263--269, 1992.
\bibitem{astrom2000} K.~J.~Åström y K.~Furuta, «Swinging up a pendulum by energy control», \emph{Automatica}, 36(2):287--295, 2000.
\bibitem{cazzolato2011} B.~S.~Cazzolato y Z.~Prime, «On the dynamics of the Furuta pendulum», \emph{Journal of Control Science and Engineering}, 2011:528341, 2011.
\bibitem{lineal} \emph{Péndulo lineal (carro-péndulo): manual teórico y práctico}, primer experimento de esta serie (\code{doc/linear\_pendulum\_manual.pdf}).
\end{thebibliography}

\end{document}
"""
pre=pre.replace("\\definecolor{c6}{RGB}{77,190,238}","\\definecolor{c6}{RGB}{77,190,238}\n\\usetikzlibrary{3d,perspective}")
pre=pre.replace("{θ}{{$\\theta$}}1","{θ}{{$\\theta$}}1 {α}{{$\\alpha$}}1")
open('rotary_pendulum/manual.tex','w').write(pre+post)
EOF
grep -n "spanish\|alpha\|perspective" rotary_pendulum/manual.tex | head
```

</details>

<details><summary>Output</summary>

```
9:\babelprovide[import,main]{spanish}
47:\usetikzlibrary{3d,perspective}
65:           {θ}{{$\theta$}}1 {α}{{$\alpha$}}1 {°}{{$^\circ$}}1 {±}{{$\pm$}}1 {→}{{$\to$}}1
107:\newcommand{\ald}{\dot{\alpha}}
108:\newcommand{\aldd}{\ddot{\alpha}}
109:\newcommand{\Ja}{J_\alpha}
```

</details>

## 🤖 Claude

Ahora el esquema del sistema en TikZ, en perspectiva. Lo uso en la portada y en la introducción, y muestra θ, α, el brazo, el péndulo y el motor:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/fig_sistema.tex` (2936 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/fig_sistema.tex (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Compilo el esquema aislado para comprobar que se ve bien antes de seguir:

**🔧 Bash** — Compile system sketch standalone

<details><summary>Command</summary>

```bash
O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest; mkdir -p $O && cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum && cat > $O/t.tex <<'EOF'
\documentclass[border=4pt]{standalone}
\usepackage{tikz}\usetikzlibrary{arrows.meta,3d,perspective}
\definecolor{c1}{RGB}{0,114,189}\definecolor{c2}{RGB}{217,83,25}\definecolor{c4}{RGB}{126,47,142}\definecolor{c5}{RGB}{119,172,48}
\begin{document}\input{fig_sistema}\end{document}
EOF
TEXINPUTS=.: pdflatex -interaction=nonstopmode -output-directory=$O $O/t.tex >/dev/null 2>&1; grep "^!" $O/t.log | head; pdftoppm -png -r 110 $O/t.pdf $O/t && ls $O
```

</details>

<details><summary>Output</summary>

```
t-1.png
t.aux
t.log
t.pdf
t.tex
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest/t-1.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

El esquema se entiende, pero los rótulos de θ y del brazo se solapan. Agrando el arco de θ, separo las etiquetas y añado la sombra del brazo para que la del péndulo no quede suelta:

**🔧 Bash** — Fix sketch labels and recompile

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
p='fig_sistema.tex'; s=open(p).read()
rep=[("  \\draw[->,c4,thick] (1.3,0) arc (0:\\th:1.3);\n  \\node[c4] at ({1.75*cos(\\th/2)},{1.75*sin(\\th/2)}) {$\\theta$};",
      "  \\draw[->,c4,thick] (2.0,0) arc (0:\\th:2.0);\n  \\node[c4] at ({2.45*cos(\\th/2)},{2.45*sin(\\th/2)}) {$\\theta$};"),
     ("\\draw[gray!45,line width=2.2pt,line cap=round] (\\tx,\\ty,-2.9) -- (\\ex,\\ey,-2.9);",
      "\\draw[gray!35,line width=3.5pt,line cap=round] (0,0,-2.9) -- (\\tx,\\ty,-2.9);\n\\draw[gray!45,line width=2.2pt,line cap=round] (\\tx,\\ty,-2.9) -- (\\ex,\\ey,-2.9);"),
     ("\\node[c1,below] at ({0.55*\\tx},{0.55*\\ty},-0.1) {brazo $L_r$};",
      "\\node[c1,anchor=north east] at ({0.35*\\tx},{0.35*\\ty},-0.15) {brazo $L_r$};")]
for a,b in rep:
    assert a in s, a[:40]; s=s.replace(a,b)
open(p,'w').write(s)
EOF
O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest; TEXINPUTS=.: pdflatex -interaction=nonstopmode -output-directory=$O $O/t.tex >/dev/null 2>&1; grep "^!" $O/t.log | head -3; pdftoppm -png -r 110 $O/t.pdf $O/t
```

</details>

<details><summary>Output</summary>

```
(Bash completed with no output)
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest/t-1.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

Ahora la etiqueta del brazo tapa la tapa del motor. La paso arriba a la izquierda, que está libre:

**🔧 Bash** — Move arm label

<details><summary>Command</summary>

```bash
sed -i 's/\\node\[c1,anchor=north east\] at ({0.35\*\\tx},{0.35\*\\ty},-0.15) {brazo $L_r$};/\\node[c1,anchor=south east] at (-0.15,0,0.2) {brazo $L_r$};/' fig_sistema.tex && grep -n "brazo" fig_sistema.tex && O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest; TEXINPUTS=.: pdflatex -interaction=nonstopmode -output-directory=$O $O/t.tex >/dev/null 2>&1; pdftoppm -png -r 110 $O/t.pdf $O/t
```

</details>

<details><summary>Output</summary>

```
45:\node[c1,anchor=south east] at (-0.15,0,0.2) {brazo $L_r$};
[This command modified 1 file you've previously read: fig_sistema.tex. Call Read before editing.]
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/figtest/t-1.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

El esquema ya es claro. Ahora escribo los capítulos, empezando por la introducción y el modelado:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap1_intro.tex` (5890 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap2_modelo.tex` (7849 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap1_intro.tex (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap2_modelo.tex (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Sigo con el análisis lineal y los sensores:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap3_analisis.tex` (5718 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap4_sensores.tex` (2941 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap3_analisis.tex (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap4_sensores.tex (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Ahora el capítulo de control, el más extenso:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap5_control.tex` (13699 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap5_control.tex (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Verify PID sign claim and unlimited down step

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
P=design(params()); A,B=linearize(P,0)
for kp in [4,-4]:
    pid=-np.array([[kp,P['Kd_th'],P['Kp_al'],P['Kd_al']]]); print('Kp_th',kp,'poles',np.round(np.linalg.eigvals(A-B@pid),2))
r=np.radians(90); rf=lambda t: r if t>1 else 0
Pn=dict(P); K=P['K_dn'].copy(); K[0,2:]=0; Pn['K_dn']=K
for name,PP in [('antisway',P),('nosway',Pn)]:
    L=simulate(PP,[0,0,np.pi,0],4,6,ref=rf); t=L[:,0]; s=np.degrees(np.abs(wrap(L[:,3]-np.pi)))
    print(name,'max sway',s.max().round(2),'sway t>4',s[t>4].max().round(2),'Vmax',abs(L[:,5]).max().round(1))
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
Kp_th 4 poles [-13.74+13.99j -13.74-13.99j  -4.4  +1.4j   -4.4  -1.4j ]
Kp_th -4 poles [-14.44+19.57j -14.44-19.57j  -8.95 +0.j     1.55 +0.j  ]
antisway max sway 21.43 sway t>4 0.61 Vmax 7.0
nosway max sway 25.73 sway t>4 2.26 Vmax 7.0
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Correct control chapter claims

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum && python3 - <<'EOF'
p='cap5_control.tex'; s=open(p).read()
rep=[("El LQR multiplica por 13 el amortiguamiento del modo pendular (de $\\zeta=0{,}016$ a $0{,}22$).",
      "El LQR multiplica por 14 el amortiguamiento del modo pendular (de $\\zeta=0{,}016$ a $0{,}22$)."),
     ("La diferencia es menor que en la grúa del péndulo lineal ($0{,}3^\\circ$ frente a $16^\\circ$ allí).",
      "La diferencia es mucho menor que en la grúa del péndulo lineal ($0{,}34^\\circ$ frente a $16{,}5^\\circ$ allí)."),
     ("Si se quita el limitador (\\code{setParamRaw('ref\\_rate', 1e6)}) el escalón brusco excita mucho más el péndulo y la ventaja del anti-balanceo se hace evidente (práctica~\\ref{pr:down}).",
      "Si se quita el limitador (\\code{setParamRaw('ref\\_rate', 1e6)}), el escalón brusco balancea el péndulo hasta $21$--$26^\\circ$ y la oscilación residual pasa a ser de $0{,}6^\\circ$ con anti-balanceo frente a $2{,}3^\\circ$ sin él (práctica~\\ref{pr:down})."),
     ("La energía sube de \\SI{-30.4}{mJ} a cero en tres balanceos;","La energía sube de \\SI{-30.4}{mJ} a cero en unos pocos balanceos;"),
     ("La ganancia \\emph{positiva} sobre el error del brazo es, de nuevo, consecuencia de la fase no mínima: un lazo PD «intuitivo» con $K_{p\\theta}<0$ es inestable.",
      "La ganancia \\emph{positiva} sobre el error del brazo es, de nuevo, consecuencia de la fase no mínima: con el signo «intuitivo», $K_{p\\theta}=-4$, aparece un polo real inestable en $+1{,}55$."),
     ("Con el triple, el tiempo de asentamiento pasa de \\SI{0.41}{s} a \\SI{0.76}{s}.","Con el doble o el triple de masa, el tiempo de asentamiento pasa de \\SI{0.41}{s} a \\SI{0.76}{s}."),
]
for a,b in rep:
    assert a in s, a[:50]; s=s.replace(a,b)
open(p,'w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Para los capítulos de Simulink y de la interfaz de código parto de los del péndulo lineal, que describen la misma arquitectura:

**🔧 Bash** — Read linear cap6 for adaptation

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/linear_pendulum && sed -n 20,122p cap6_simulink.tex
```

</details>

<details><summary>Output</summary>

```
\section{Arquitectura}

\begin{figure}[H]
\centering
\resizebox{\linewidth}{!}{%
\begin{tikzpicture}[>=Latex,font=\small,
  ss/.style={draw,very thick,fill=#1,minimum width=2.2cm,minimum height=1.5cm,align=center,rounded corners=1pt},
  ss/.default=c1!10,
  cst/.style={draw,fill=yellow!25,minimum width=1.6cm,minimum height=0.6cm,font=\footnotesize\ttfamily},
  fw/.style={draw,fill=orange!20,minimum width=1.6cm,minimum height=0.6cm,font=\footnotesize\ttfamily},
  sm/.style={draw,circle,inner sep=1pt}]
\node[cst] (clk) at (0,2.2) {Clock};
\node[cst] (cref) at (0,1.4) {cmd\_ref};
\node[fw] (rext) at (0,0.6) {ref\_ext};
\node[ss=gray!12] (ref) at (2.8,1.4) {Reference};
\node[cst] (cctrl) at (2.8,-1.0) {cmd\_ctrl};
\node[ss=c4!12] (ctl) at (5.6,0.4) {Controller};
\node[sm] (sf) at (7.6,0.6) {$+$};
\node[fw] (uext) at (7.6,1.7) {u\_ext};
\node[ss=c2!12] (act) at (9.6,0.6) {Actuator};
\node[cst] (cd) at (11.4,2.3) {cmd\_dist};
\node[fw] (dext) at (12.9,2.3) {d\_ext};
\node[sm] (sd) at (12.2,1.4) {$+$};
\node[ss=c5!14] (pl) at (12.2,0.2) {Plant};
\node[ss=yellow!18] (sen) at (12.2,-2.0) {Sensors};
\node[draw,fill=gray!20,minimum height=4cm,minimum width=0.15cm] (mux) at (14.8,-0.4) {};
\node[draw,fill=c3!25,minimum width=1.5cm,minimum height=0.7cm,font=\footnotesize\ttfamily] (tel) at (16.4,-0.4) {telemetry};
\node[draw,fill=gray!10,minimum width=1.3cm,font=\footnotesize] (tw) at (18.4,0.3) {out.tel};
\node[draw,fill=gray!10,minimum width=1.3cm,font=\footnotesize] (sc) at (18.4,-1.1) {Scope};
\draw[->] (clk) -| ($(ref.west)+(-0.5,0.5)$) -- ($(ref.west)+(0,0.5)$);
\draw[->] (cref) -- (ref);
\draw[->] (rext) -| ($(ref.west)+(-0.5,-0.5)$) -- ($(ref.west)+(0,-0.5)$);
\draw[->] (ref.east) -- node[above]{$r$} ++(0.5,0) |- ($(ctl.west)+(0,0.3)$);
\draw[->] (cctrl) -| ($(ctl.west)+(-0.4,-0.45)$) -- ($(ctl.west)+(0,-0.45)$);
\draw[->] ($(ctl.east)+(0,0.2)$) -- node[above]{$F_c$} (sf);
\draw[->] (uext) -- (sf);
\draw[->] (sf) -- node[above]{$F_{\text{cmd}}$} (act);
\draw[->] (act) -- node[above]{$F$} ($(pl.west)+(0,0.4)$);
\draw[->] (cd) -| (sd); \draw[->] (dext) -| (sd);
\draw[->] (sd) -- node[right]{$F_d$} (pl);
\draw[->] (pl.east) -- node[above]{$\vect s$} ++(0.6,0) coordinate (b1) |- (sen.east);
\draw[->] (sen.west) -- ++(-1.5,0) -| node[pos=0.3,below]{$\vect y_m$} ($(ctl.south)+(-0.4,0)$);
\draw[->] (b1) -- ($(mux.west)+(0,0.6)$);
\draw[->,densely dotted] ($(ctl.east)+(0,-0.4)$) -- node[below,font=\footnotesize]{info} ++(0.7,0) |- (14.3,-3.2) |- ($(mux.west)+(0,-1.9)$);
\draw[->,densely dotted] (sen.east) ++(0,-0.3) -- ($(mux.west)+(0,-1.2)$);
\draw[->] (mux) -- (tel);
\draw[->] (tel) -- ++(0.9,0) |- (tw); \draw[->] (tel) -- ++(0.9,0) |- (sc);
\node[font=\scriptsize,align=left,anchor=north west] at (0,-1.7) {\colorbox{yellow!25}{\strut} Constant: modificable en vivo\\ \colorbox{orange!20}{\strut} From Workspace: se lee al arrancar};
\end{tikzpicture}}
\caption{Nivel superior del modelo \code{cartpole\_sim}. Los bloques amarillos son el «panel de mando» que mo
... [truncated, 3645 more characters]
```

</details>

**🔧 Bash** — Adapt Simulink chapter; read linear cap7

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src && python3 - <<'EOF'
s=open('linear_pendulum/cap6_simulink.tex').read()
rep=[
("El modelo \\code{cartpole\\_sim.slx} no se dibuja a mano: lo genera \\code{cp\\_build\\_model.m}","El modelo \\code{rotpend\\_sim.slx} no se dibuja a mano: lo genera \\code{rp\\_build\\_model.m}"),
("se lee de \\code{cp\\_plant\\_block.m}, \\code{cp\\_controller\\_block.m} y \\code{cp\\_ref\\_block.m}","se lee de \\code{rp\\_plant\\_block.m}, \\code{rp\\_controller\\_block.m} y \\code{rp\\_ref\\_block.m}"),
("ch.Script = fileread('cp_controller_block.m');","ch.Script = fileread('rp_controller_block.m');"),
("Si se edita alguno de los archivos \\code{*\\_block.m}, hay que volver a ejecutar \\code{cp\\_build\\_model}.","Si se edita alguno de los archivos \\code{*\\_block.m}, hay que volver a ejecutar \\code{rp\\_build\\_model}."),
("\\node[ss=c2!12] (act) at (9.6,0.6) {Actuator};","\\node[ss=c2!12] (act) at (9.6,0.6) {Amplifier};"),
("node[above]{$F_c$} (sf);","node[above]{$V_c$} (sf);"),
("node[above]{$F_{\\text{cmd}}$} (act);","node[above]{$V_{\\text{cmd}}$} (act);"),
("\\draw[->] (act) -- node[above]{$F$} ($(pl.west)+(0,0.4)$);","\\draw[->] (act) -- node[above]{$V$} ($(pl.west)+(0,0.4)$);"),
("\\caption{Nivel superior del modelo \\code{cartpole\\_sim}. Los bloques amarillos son el «panel de mando» que modifican la clase \\code{CartPole} y la GUI.}",
 "\\caption{Nivel superior del modelo \\code{rotpend\\_sim}. Los bloques amarillos son el «panel de mando» que modifican la clase \\code{RotaryPendulum} y la GUI.}"),
("\\emph{MATLAB Function} \\code{cp\\_ref\\_block}: constante, seno, cuadrada, triangular o externa. Le siguen un \\emph{Rate Limiter} ($\\pm$\\code{P.ref\\_rate}) y una \\emph{Saturation} ($\\pm$\\code{P.x\\_ref\\_max}).",
 "\\emph{MATLAB Function} \\code{rp\\_ref\\_block}: constante, seno, cuadrada, triangular o externa. Le siguen un \\emph{Rate Limiter} ($\\pm$\\code{P.ref\\_rate}, \\SI{2}{rad/s}) y una \\emph{Saturation} ($\\pm$\\code{P.th\\_ref\\_max}, $\\pm180^\\circ$)."),
("\\code{cmd\\_ctrl} $\\to F_c$, info & ZOH sobre $r$ y \\emph{MATLAB Function} \\code{cp\\_controller\\_block}","\\code{cmd\\_ctrl} $\\to V_c$, info & ZOH sobre $r$ y \\emph{MATLAB Function} \\code{rp\\_controller\\_block}"),
("\\code{Actuator} & $F_{\\text{cmd}}\\to F$ & \\emph{Transfer Fcn} $1/(\\tau_as+1)$ más \\emph{Saturation} $\\pm F_{\\max}$.\\\\",
 "\\code{Amplifier} & $V_{\\text{cmd}}\\to V$ & \\emph{Saturation} $\\pm V_{\\max}$. La dinámica eléctrica del motor se desprecia y la fuerza contraelectromotriz se calcula dentro de la planta.\\\\"),
("\\code{Plant} & $F$, $F_d\\to\\vect s$ & \\emph{MATLAB Function} \\code{cp\\_plant\\_block} (modelo~\\eqref{eq:nl})","\\code{Plant} & $V$, $F_d\\to\\vect s$ & \\emph{MATLAB Function} \\code{rp\\_plant\\_block} (modelo~\\eqref{eq:nl} y motor~\\eqref{eq:motor})"),
("El paso fijo hace la simulación determinista y compatible con el \\emph{pacing}. Los topes del raíl ($k_w=\\SI{1e4}{N/m}$) tienen una frecuencia propia de unos \\SI{140}{rad/s}, de modo que $\\omega h\\approx0{,}14$ y la integración sigue siendo estable.",
 "El paso fijo hace la simulación determinista y compatible con el \\emph{pacing}. La dinámica más rápida es el polo del lazo cerrado en \\SI{22}{rad/s}, de modo que $\\omega h\\approx0{,}02$ y la integración tiene un margen enorme. A diferencia del péndulo lineal no hay topes rígidos."),
("Lo activa \\code{CartPole.start()} y lo desactiva \\code{CartPole.run()}.","Lo activa \\code{RotaryPendulum.start()} y lo desactiva \\code{RotaryPendulum.run()}."),
("""1 & \\code{x} & posición real & m & 8 & \\code{Fact} & fuerza aplicada & N\\\\
2 & \\code{xd} & velocidad real & m/s & 9 & \\code{r} & referencia filtrada & m\\\\
3 & \\code{th} & ángulo real & rad & 10 & \\code{mode} & modo activo & --\\\\
4 & \\code{thd} & vel. angular real & rad/s & 11 & \\code{E} & energía (swing-up) & J\\\\
5 & \\code{xm} & $x$ medida & m & 12 & \\code{caught} & capturado por LQR & 0/1\\\\
6 & \\code{thm} & $\\theta$ medida & rad & 13 & \\code{tripped} & corte de seguridad & 0/1\\\\
7 & \\code{Fcmd} & fuerza pedida & N & & & & \\\\""",
"""1 & \\code{th} & ángulo del brazo & rad & 8 & \\code{Vact} & tensión aplicada & V\\\\
2 & \\code{thd} & vel. del brazo & rad/s & 9 & \\code{r} & referencia filtrada & rad\\\\
3 & \\code{al} & ángulo del péndulo & rad & 10 & \\code{mode} & modo activo & --\\\\
4 & \\code{ald} & vel. del péndulo & rad/s & 11 & \\code{E} & energía (swing-up) & J\\\\
5 & \\code{thm} & $\\theta$ medida & rad & 12 & \\code{caught} & capturado por LQR & 0/1\\\\
6 & \\code{alm} & $\\alpha$ medida & rad & 13 & \\code{tripped} & corte de seguridad & 0/1\\\\
7 & \\code{Vcmd} & tensión pedida & V & & & & \\\\"""),
("\\caption{Vector de telemetría (\\code{CartPole.TEL}).}","\\caption{Vector de telemetría (\\code{RotaryPendulum.TEL}).}"),
]
for a,b in rep:
    assert a in s, a[:60]; s=s.replace(a,b)
open('rotary_pendulum/cap6_simulink.tex','w').write(s)
EOF
grep -n "cp_\|cp\\\\_\|CartPole\|cart\|carro\|raíl\|F_" rotary_pendulum/cap6_simulink.tex; sed -n 1,40p linear_pendulum/cap7_codigo.tex; sed -n 60,130p linear_pendulum/cap7_codigo.tex
```

</details>

<details><summary>Output</summary>

```
59:\draw[->] (sd) -- node[right]{$F_d$} (pl);
84:\code{Plant} & $V$, $F_d\to\vect s$ & \emph{MATLAB Function} \code{rp\_plant\_block} (modelo~\eqref{eq:nl} y motor~\eqref{eq:motor}) más un \emph{Integrator} vectorial con condición inicial \code{P.x0}.\\
\chapter{Interfaces de usuario: código y GUI}
\label{cap:codigo}

\section{La clase \code{CartPole}}

\code{CartPole} encapsula todo el acceso al modelo. Permite trabajar de dos maneras (figura~\ref{fig:modos}):
\begin{itemize}
  \item \textbf{Por lotes} (\code{run(T)}): simula $T$ segundos tan rápido como puede y devuelve un \emph{struct} con todas las señales. Es la forma adecuada para diseñar, hacer barridos y generar figuras.
  \item \textbf{En vivo} (\code{start}/\code{stop}): simula indefinidamente en tiempo real. Los comandos tienen efecto inmediato y la telemetría llega a las funciones registradas como \emph{callback}.
\end{itemize}

\begin{figure}[H]
\centering
\resizebox{\linewidth}{!}{%
\begin{tikzpicture}[>=Latex,font=\small,
  ll/.style={draw,thick,minimum width=2.6cm,minimum height=0.8cm,fill=#1,align=center},ll/.default=gray!10,
  lab/.style={above,font=\scriptsize,fill=white,inner sep=1pt}]
\def\xa{0}\def\xb{6.5}\def\xc{13}
\node[ll=c1!12] (u) at (\xa,0) {Usuario /\\script / GUI};
\node[ll=c4!12] (c) at (\xb,0) {\code{CartPole}};
\node[ll=c5!12] (s) at (\xc,0) {Simulink\\\code{cartpole\_sim}};
\foreach \n in {u,c,s} \draw[dashed,gray] (\n.south) -- ++(0,-8.4);
\draw[->] (\xa,-1.1) -- node[lab]{\code{setMode}, \code{setRef}, \code{setInitialState}} (\xb,-1.1);
\draw[->] (\xb,-1.8) -- node[lab]{\code{set\_param(cmd\_*)}, \code{assignin('base','P')}} (\xc,-1.8);
\draw[->] (\xa,-2.6) -- node[lab]{\code{start()}} (\xb,-2.6);
\draw[->] (\xb,-3.3) -- node[lab]{\code{SimulationCommand=start} (pacing 1x)} (\xc,-3.3);
\draw[->,c2] (\xc,-4.0) -- node[lab]{\code{StartFcn}: \emph{listener} sobre \code{telemetry}} (\xb,-4.0);
\draw[->,c2] (\xc,-4.7) -- node[lab]{\code{PostOutputs} (cada paso)} (\xb,-4.7);
\draw[->,c2] (\xb,-5.4) -- node[lab]{\code{callback(t,d)} a 30 Hz} (\xa,-5.4);
\draw[->] (\xa,-6.2) -- node[lab]{\code{push(F,dur)}, \code{setParam(...)}} (\xb,-6.2);
\draw[->] (\xb,-6.9) -- node[lab]{\code{cmd\_dist} / \code{SimulationCommand=update}} (\xc,-6.9);
\draw[->] (\xa,-7.7) -- node[lab]{\code{stop(); res = lastResult()}} (\xb,-7.7);
\end{tikzpicture}}
\caption{Secuencia de interacción en el modo en vivo.}
\label{fig:modos}
\end{figure}

\subsection{Referencia de métodos}

\begin{table}[H]
\code{cp.addTelemetryCallback(f)} & Registra \code{f(t,d)}, con \code{d} el vector de la tabla~\ref{tab:tel}. & --\\
\code{res = cp.lastResult()} & Datos de la última sesión en vivo. & --\\
\code{cp.animate(res, vel)} & Reproduce un ensayo. & --\\
\bottomrule
\end{tabularx}
\caption{API de \code{CartPole}.}
\end{table}

\subsection{Ejemplos}

\begin{ejemplo}{Ensayo por lotes y métricas}
\begin{lstlisting}
cp = CartPole();
cp.setInitialState([0 0 0.15 0]);
cp.setMode('lqr'); cp.setRef('const', 0);
re
... [truncated, 2257 more characters]
```

</details>

## 🤖 Claude

El capítulo de Simulink está adaptado. El de la interfaz lo escribo nuevo: en lugar de una maqueta dibujada, usa la captura real de la GUI.

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap7_codigo.tex` (9467 characters)

**🔧 Bash** — Read rest of linear practices and appendix

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/linear_pendulum && sed -n 60,204p cap8_practicas.tex | head -150; cat apendices.tex | sed -n 1,60p
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap7_codigo.tex (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
\entregables Bode experimental superpuesto al teórico y parámetros identificados.
\end{practica}

% ----------------------------------------------------------------
\stepcounter{practica}
\begin{practica}{Diseño de un LQR: influencia de $Q$ y $R$}
\objetivos Entender el compromiso entre rapidez, esfuerzo y recorrido del carro.
\procedimiento
\begin{enumerate}
  \item Desde $\theta_0=\SI{0.15}{rad}$, repetir el ensayo con $Q_\theta\in\{20,200,2000\}$ y luego con $R\in\{0{,}01,\ 0{,}1,\ 1\}$ (véase la figura~\ref{fig:qsweep}).
  \item Para cada diseño, anotar $K$, los polos del lazo cerrado (\code{cp.Lin.up.poles\_CL}), el tiempo de asentamiento a $0{,}5^\circ$, $F_{\max}$ y $|x|_{\max}$.
  \item Aplicar la regla de Bryson con $\theta_{\max}=5^\circ$, $x_{\max}=\SI{0.2}{m}$ y $F_{\max}=\SI{10}{N}$. Comparar el resultado con el diseño por defecto.
  \item En la GUI, cambiar $Q$ y $R$ en vivo mientras se aplican empujones.
\end{enumerate}
\preguntas
\begin{enumerate}
  \item Comprobar que $K_x=-\sqrt{Q_x/R}$ en todos los diseños y justificarlo.
  \item ¿Qué ocurre cuando el diseño satura el actuador? ¿Hay un ángulo inicial máximo recuperable? Encontrarlo por bisección.
\end{enumerate}
\entregables Tabla de diseños con sus métricas y una recomendación justificada.
\end{practica}

% ----------------------------------------------------------------
\stepcounter{practica}
\begin{practica}{Seguimiento de referencias y fase no mínima}
\objetivos Observar la respuesta inversa y cuantificar los límites de seguimiento.
\procedimiento
\begin{enumerate}
  \item Aplicar un escalón con \code{cp.setRefSignal([0 1 1.001 8], [0 0 0.3 0.3])} y medir el retroceso inicial (figura~\ref{fig:lqrstep}).
  \item Referencias senoidales de \SI{0.2}{m} a 0,05; 0,1; 0,2 y \SI{0.4}{Hz}: medir la ganancia y el desfase entre $x$ y $r$, y dibujar el Bode del lazo cerrado.
  \item Implementar el modo 5 con acción integral (sección~\ref{sec:nuevo_modo}) y repetir el ensayo de escalón con la fricción de Coulomb aumentada a \code{Fc = 1}.
\end{enumerate}
\preguntas
\begin{enumerate}
  \item Relacionar el ancho de banda medido con la posición del cero $z=4{,}91$.
  \item ¿Desaparece la respuesta inversa con el integrador? ¿Por qué no puede desaparecer con ningún controlador?
  \item Proponer un prefiltro o feedforward que reduzca el retraso con referencias senoidales.
\end{enumerate}
\entregables Gráficas, Bode del lazo cerrado y comparación con y sin integral.
\end{practica}

% ----------------------------------------------------------------
\stepcounter{practica}
\begin{practica}{Rechazo de perturbaciones y robustez}
\objetivos Evaluar el LQR frente a empujones y a errores en los parámetros.
\procedimiento
\begin{enumerate}
  \item Programar empujones de amplitud creciente (\SI{0.5}{N} a \SI{3}{N}, durante \SI{0.1}{s}) con \code{setDisturbanceSignal} y determinar la amplitud máxima admisible antes de que salte la seguridad.
  \item Sin recalcular $K$, variar la masa real del carro, la 
... [truncated, 9759 more characters]
```

</details>

## 🤖 Claude

Escribo las prácticas y los apéndices:

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap8_practicas.tex` (10820 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/apendices.tex` (5741 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/cap8_practicas.tex (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/apendices.tex (file state is current in your context — no need to Read it back)
```

</details>

## 🤖 Claude

Verifico con la réplica una afirmación de la tabla de problemas que he escrito sin medir: la tensión mínima con la que el swing-up todavía funciona.

**🔧 Bash** — Check swing-up vs amplifier saturation

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
for vm in [3,4,5,6,8]:
    P=design(params()); P['Vmax']=vm
    L=simulate(P,[0,0,np.pi,0],2,15); c=L[:,6]
    print(vm, 'catch', L[np.argmax(c>0),0] if c.any() else None, 'end caught', c[-1], 'final al', np.degrees(wrap(L[-1,3])).round(1))
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
3 catch None end caught 0.0 final al -70.9
4 catch None end caught 0.0 final al -146.1
5 catch None end caught 0.0 final al 112.4
6 catch None end caught 0.0 final al 60.7
8 catch None end caught 0.0 final al 154.8
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Diagnose swing-up failure at 8 V

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
P=design(params()); P['Vmax']=8
L=simulate(P,[0,0,np.pi,0],2,8); t=L[:,0]; al=L[:,3]; ald=L[:,4]
E=0.5*P['Ja']*ald**2+P['mp']*P['g']*P['lp']*(np.cos(al)-1)
for tt in np.arange(0,8,0.5):
    k=int(tt/0.001); print(f't={tt:.1f} E={E[k]*1e3:6.2f}mJ al={np.degrees(wrap(al[k])):7.1f} th={np.degrees(L[k,1]):6.1f} V={L[k,5]:5.1f} caught={L[k,6]:.0f}')
print('max E', E.max()*1e3, 'any caught', L[:,6].max())
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
t=0.0 E=-30.37mJ al= -180.0 th=   0.0 V=  1.3 caught=0
t=0.5 E=-30.27mJ al= -178.0 th=  27.9 V= -0.9 caught=0
t=1.0 E=-23.41mJ al= -126.7 th=   4.9 V=  2.7 caught=0
t=1.5 E=-11.27mJ al=  137.3 th= -39.9 V= -1.3 caught=0
t=2.0 E= -1.49mJ al=  146.4 th=  18.2 V= -7.9 caught=0
t=2.5 E= -0.92mJ al= -155.7 th=  -3.1 V=  5.7 caught=0
t=3.0 E= -1.20mJ al= -129.1 th=  -1.3 V=  7.9 caught=0
t=3.5 E= -1.74mJ al=   90.6 th=  -3.6 V= -4.7 caught=0
t=4.0 E= -1.78mJ al=  -62.5 th=   5.9 V=  0.6 caught=0
t=4.5 E= -1.75mJ al=   43.6 th=  -7.0 V=  1.1 caught=0
t=5.0 E= -1.74mJ al=  -32.7 th=   7.6 V= -1.4 caught=0
t=5.5 E= -1.71mJ al=   27.8 th=  -7.8 V=  1.5 caught=0
t=6.0 E= -1.71mJ al=  -28.3 th=   7.4 V= -1.5 caught=0
t=6.5 E= -1.78mJ al=   34.1 th=  -6.4 V=  1.6 caught=0
t=7.0 E= -1.86mJ al=  -46.1 th=   4.9 V= -1.1 caught=0
t=7.5 E= -1.90mJ al=   66.8 th=  -3.0 V= -1.5 caught=0
max E -0.8660584471635625 any caught 0.0
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Test target-energy offset for robust swing-up

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && python3 - <<'EOF'
p='python_reference_sim.py'; s=open(p).read()
for a,b in [("k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0,","k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0, E_ref=0.0,"),
            ("    a = P['k_E']*E*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd","    a = P['k_E']*(E - P['E_ref'])*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd")]:
    assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
EOF
cd /tmp && python3 -c "
import sys, itertools; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
ics=[[0,0,np.pi,0],[0,0,np.pi-0.2,0],[0.5,0,np.pi,1.0],[0,0,np.pi+0.05,-2]]
for Eref in [0,1e-3,2e-3,3e-3,5e-3]:
  for kE in [200,400]:
    row=[]
    for vm in [6,8,10,12]:
        ok=0; tc=[]; thm=[]
        for x0 in ics:
            P=design(params()); P.update(Vmax=vm,E_ref=Eref,k_E=kE)
            L=simulate(P,x0,2,10); c=L[:,6]
            if c.any() and c[-1]>0 and abs(np.degrees(wrap(L[-1,3])))<2: ok+=1; tc.append(L[np.argmax(c>0),0]); thm.append(np.degrees(abs(L[:,1])).max())
        row.append(f'{vm}V:{ok}/4 tc<={max(tc) if tc else 0:.1f} th<={max(thm) if thm else 0:.0f}')
    print(f'Eref={Eref*1e3:.0f}mJ kE={kE}: ', ' | '.join(row))
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
Eref=0mJ kE=200:  6V:0/4 tc<=0.0 th<=0 | 8V:0/4 tc<=0.0 th<=0 | 10V:4/4 tc<=2.5 th<=43 | 12V:4/4 tc<=2.2 th<=43
Eref=0mJ kE=400:  6V:0/4 tc<=0.0 th<=0 | 8V:4/4 tc<=2.0 th<=84 | 10V:4/4 tc<=1.7 th<=84 | 12V:4/4 tc<=1.5 th<=84
Eref=1mJ kE=200:  6V:0/4 tc<=0.0 th<=0 | 8V:4/4 tc<=2.8 th<=68 | 10V:4/4 tc<=2.2 th<=45 | 12V:4/4 tc<=2.2 th<=45
Eref=1mJ kE=400:  6V:0/4 tc<=0.0 th<=0 | 8V:4/4 tc<=2.0 th<=91 | 10V:4/4 tc<=1.5 th<=91 | 12V:4/4 tc<=1.5 th<=91
Eref=2mJ kE=200:  6V:0/4 tc<=0.0 th<=0 | 8V:4/4 tc<=2.5 th<=47 | 10V:4/4 tc<=2.0 th<=47 | 12V:4/4 tc<=2.0 th<=47
Eref=2mJ kE=400:  6V:4/4 tc<=4.7 th<=201 | 8V:4/4 tc<=1.5 th<=97 | 10V:4/4 tc<=1.5 th<=97 | 12V:4/4 tc<=1.5 th<=97
Eref=3mJ kE=200:  6V:0/4 tc<=0.0 th<=0 | 8V:4/4 tc<=2.4 th<=50 | 10V:4/4 tc<=2.1 th<=50 | 12V:4/4 tc<=1.9 th<=50
Eref=3mJ kE=400:  6V:4/4 tc<=2.1 th<=105 | 8V:4/4 tc<=1.6 th<=105 | 10V:4/4 tc<=1.6 th<=105 | 12V:4/4 tc<=1.6 th<=105
Eref=5mJ kE=200:  6V:4/4 tc<=3.4 th<=123 | 8V:4/4 tc<=2.0 th<=57 | 10V:4/4 tc<=1.9 th<=57 | 12V:4/4 tc<=1.9 th<=57
Eref=5mJ kE=400:  6V:4/4 tc<=2.0 th<=113 | 8V:4/4 tc<=1.5 th<=117 | 10V:4/4 tc<=1.5 th<=117 | 12V:4/4 tc<=1.6 th<=117
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Check swing-up robustness to plant changes

<details><summary>Command</summary>

```bash
cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
ics=[[0,0,np.pi,0],[0,0,np.pi-0.2,0],[0.5,0,np.pi,1.0],[0,0,np.pi+0.05,-2]]
for Eref in [0,5e-3]:
  for name,upd in [('nominal',{}),('mp x0.5',{'mp':0.012}),('mp x2',{'mp':0.048}),('Lp 0.10',{'Lp':0.10}),('Lp 0.18',{'Lp':0.18}),('Tc x3',{'Tc':1.5e-3})]:
    ok=0; tcs=[]; ths=[]
    for x0 in ics:
        P=params(); P.update(upd); P['lp']=P['Lp']/2; P['Jp']=P['mp']*P['Lp']**2/12; P['J0']=P['Jr']+P['mp']*P['Lr']**2; P['Ja']=P['Jp']+P['mp']*P['lp']**2
        P=design(P); P['E_ref']=Eref
        L=simulate(P,x0,2,10); c=L[:,6]
        if c.any() and c[-1]>0 and abs(np.degrees(wrap(L[-1,3])))<2: ok+=1; tcs.append(L[np.argmax(c>0),0]); ths.append(np.degrees(abs(L[:,1])).max())
    print(f'Eref={Eref*1e3:.0f} {name:8s}: {ok}/4  tc<={max(tcs) if tcs else 0:.1f}  th<={max(ths) if ths else 0:.0f}')
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
Eref=0 nominal : 4/4  tc<=2.5  th<=43
Eref=0 mp x0.5 : 0/4  tc<=0.0  th<=0
Eref=0 mp x2   : 0/4  tc<=0.0  th<=0
Eref=0 Lp 0.10 : 4/4  tc<=3.6  th<=37
Eref=0 Lp 0.18 : 4/4  tc<=2.5  th<=81
Eref=0 Tc x3   : 1/4  tc<=2.4  th<=59
Eref=5 nominal : 4/4  tc<=1.9  th<=57
Eref=5 mp x0.5 : 4/4  tc<=2.5  th<=60
Eref=5 mp x2   : 0/4  tc<=0.0  th<=0
Eref=5 Lp 0.10 : 4/4  tc<=1.7  th<=41
Eref=5 Lp 0.18 : 4/4  tc<=2.3  th<=92
Eref=5 Tc x3   : 4/4  tc<=2.3  th<=54
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Test relative target-energy fraction robustness

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i "s/    a = P\['k_E'\]\*(E - P\['E_ref'\])\*ald\*c/    a = P['k_E']*(E - P['E_ref']*2*mp*g*lp)*ald*c/; s/kv_sw=1.0, E_ref=0.0,/kv_sw=1.0, E_ref=0.15,/" python_reference_sim.py && grep -n "E_ref" python_reference_sim.py && cd /tmp && python3 -c "
import sys; sys.path.insert(0,'/home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum')
from python_reference_sim import *
ics=[[0,0,np.pi,0],[0,0,np.pi-0.2,0],[0.5,0,np.pi,1.0],[0,0,np.pi+0.05,-2]]
for fr in [0.1,0.15,0.2,0.3]:
  out=[]
  for name,upd in [('nom',{}),('Vmax6',{'Vmax':6.0}),('mp/2',{'mp':0.012}),('mp*2',{'mp':0.048}),('Lp.10',{'Lp':0.10}),('Lp.18',{'Lp':0.18}),('Tc*3',{'Tc':1.5e-3})]:
    ok=0; tcs=[]; ths=[]
    for x0 in ics:
        P=params(); P.update(upd); P['lp']=P['Lp']/2; P['Jp']=P['mp']*P['Lp']**2/12; P['J0']=P['Jr']+P['mp']*P['Lr']**2; P['Ja']=P['Jp']+P['mp']*P['lp']**2
        P=design(P); P['E_ref']=fr
        L=simulate(P,x0,2,10); c=L[:,6]
        if c.any() and c[-1]>0 and abs(np.degrees(wrap(L[-1,3])))<2: ok+=1; tcs.append(L[np.argmax(c>0),0]); ths.append(np.degrees(abs(L[:,1])).max())
    out.append(f'{name}:{ok}/4,{max(tcs) if tcs else 0:.1f}s,{max(ths) if ths else 0:.0f}°')
  print(f'frac {fr}: ', ' '.join(out))
"; rm -rf /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/__pycache__
```

</details>

<details><summary>Output</summary>

```
33:        k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0, E_ref=0.15,
129:    a = P['k_E']*(E - P['E_ref']*2*mp*g*lp)*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd
frac 0.1:  nom:4/4,2.1s,50° Vmax6:0/4,0.0s,0° mp/2:4/4,3.9s,31° mp*2:0/4,0.0s,0° Lp.10:4/4,2.0s,39° Lp.18:4/4,2.2s,92° Tc*3:4/4,2.2s,53°
frac 0.15:  nom:4/4,1.9s,55° Vmax6:4/4,3.9s,58° mp/2:4/4,3.4s,31° mp*2:4/4,3.9s,114° Lp.10:4/4,2.1s,40° Lp.18:4/4,2.3s,94° Tc*3:4/4,2.2s,54°
frac 0.2:  nom:4/4,1.9s,60° Vmax6:4/4,2.8s,71° mp/2:4/4,2.9s,33° mp*2:4/4,2.5s,122° Lp.10:4/4,1.7s,41° Lp.18:4/4,1.9s,96° Tc*3:4/4,1.7s,55°
frac 0.3:  nom:4/4,1.8s,68° Vmax6:4/4,2.3s,61° mp/2:4/4,2.7s,52° mp*2:4/4,1.9s,122° Lp.10:4/4,1.6s,43° Lp.18:4/4,1.7s,94° Tc*3:4/4,1.8s,59°
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Add target energy to MATLAB and Python swing-up

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && sed -i "s/kv_sw=1.0, E_ref=0.15,/kv_sw=1.0, E_ref=0.2,/" python_reference_sim.py && python3 - <<'EOF'
p='rp_params.m'; s=open(p).read()
a="P.kv_sw      = 1;\n"
assert a in s
s=s.replace(a,a+"P.E_ref      = 0.2;       % target energy as a fraction of 2 mp g lp (keeps pumping\n                          % until slightly above the upright energy; robustness)\n")
open(p,'w').write(s)
p='rp_controller_block.m'; s=open(p).read()
a="            acc = P.k_E*E*ald*c - P.kx_sw*(th - r) - P.kv_sw*thd;"
assert a in s
s=s.replace(a,"            Eref = P.E_ref*2*P.mp*P.g*P.lp;                   % slightly above upright\n            acc = P.k_E*(E - Eref)*ald*c - P.kx_sw*(th - r) - P.kv_sw*thd;")
open(p,'w').write(s)
EOF
grep -n "E_ref\|Eref" rp_params.m rp_controller_block.m python_reference_sim.py
```

</details>

<details><summary>Output</summary>

```
rp_controller_block.m:62:            Eref = P.E_ref*2*P.mp*P.g*P.lp;                   % slightly above upright
rp_controller_block.m:63:            acc = P.k_E*(E - Eref)*ald*c - P.kx_sw*(th - r) - P.kv_sw*thd;
python_reference_sim.py:33:        k_E=200.0, a_max=80.0, kx_sw=25.0, kv_sw=1.0, E_ref=0.2,
python_reference_sim.py:129:    a = P['k_E']*(E - P['E_ref']*2*mp*g*lp)*ald*c - P['kx_sw']*(th - r) - P['kv_sw']*thd
rp_params.m:76:P.E_ref      = 0.2;       % target energy as a fraction of 2 mp g lp (keeps pumping
[This command modified 2 files you've previously read: rp_controller_block.m, rp_params.m. Call Read before editing.]
```

</details>

**🔧 Bash** — Regenerate manual data and rerun validation

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels && python3 - <<'EOF'
p='doc/src/rotary_pendulum/data/generate_data.m'; s=open(p).read()
a="swing = res;\n"
assert a in s
s=s.replace(a,a+"""for c = {{'Vmax', 6}, {'mp', 0.048}, {'Lp', 0.18}}
    rp.setParam(c{1}{1}, c{1}{2}); rp.setInitialState([0 0 pi 0]);
    res = rp.run(8); k = find(res.caught > 0.5, 1);
    pr('swingup %s=%g: catch %.3f s, max|th| %.1f, final al %.2f\\n', c{1}{1}, c{1}{2}, res.t(k), max(abs(res.th_deg)), res.al_deg(end));
    rp.setParam(c{1}{1}, P.(c{1}{1}));
end
""")
open(p,'w').write(s)
EOF
(cd doc/src/rotary_pendulum/data && rm -f *.dat *.png num.txt && timeout 590 matlab -batch "generate_data" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -3) && (cd src/rotary_pendulum/validation && timeout 590 matlab -batch "run_validation" 2>&1 | grep -v "Unable to close\|close_system\|^To save" | tail -2 && cd /tmp && python3 -I /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/compare_with_python.py); cat /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/num.txt | sed -n '/lqr_ic/,$p'
```

</details>

<details><summary>Output</summary>

```
Command running in background with ID: bzr00j0cd. Output is being written to: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/tasks/bzr00j0cd.output. You will be notified when it completes — do not poll that file or sleep while waiting. Read the file only if the user asks for progress, or if you need a line it prints before you can go on, such as a server's ready line or port.
Session cwd remains /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum; directory changes made by the backgrounded command do not apply to subsequent commands.
```

</details>

## 🤖 Claude

Mientras se regeneran los datos, actualizo la sección del swing-up del manual con la energía objetivo y el motivo para usarla:

**🔧 Bash** — Update manual swing-up section with target energy

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum && python3 - <<'EOF'
p='cap5_control.tex'; s=open(p).read()
a=r"""Con la función de Lyapunov $V_L=\tfrac12E^2$, la elección
\begin{equation}
  a = k_E\,E\,\ald\cos\alpha \;-\; k_x(\theta-r) \;-\; k_v\thd, \qquad |a|\le a_{\max},
\end{equation}
da $\dot V_L=-k_Eh\,E^2\cos^2\!\alpha\,\ald^2\le0$ (sin los términos de recentrado). Los dos últimos términos mantienen el brazo cerca de la referencia durante el bombeo. Si el péndulo está en reposo colgando, $\ald=0$ y la ley no haría nada; por eso se añade un pequeño empujón inicial. Valores por defecto: $k_E=200$, $a_{\max}=\SI{80}{rad/s^2}$, $k_x=25$, $k_v=1$."""
b=r"""Con la función de Lyapunov $V_L=\tfrac12(E-E_r)^2$, la elección
\begin{equation}
  a = k_E\,(E-E_r)\,\ald\cos\alpha \;-\; k_x(\theta-r) \;-\; k_v\thd, \qquad |a|\le a_{\max},
  \label{eq:swing}
\end{equation}
da $\dot V_L=-k_Eh\,(E-E_r)^2\cos^2\!\alpha\,\ald^2\le0$ (sin los términos de recentrado). Los dos últimos términos mantienen el brazo cerca de la referencia durante el bombeo. Si el péndulo está en reposo colgando, $\ald=0$ y la ley no haría nada; por eso se añade un pequeño empujón inicial.

\paragraph{Energía objetivo.} Lo natural sería $E_r=0$, la energía del péndulo arriba en reposo. Pero la ley es proporcional a $E-E_r$ y se apaga justo cuando más falta hace: cerca del objetivo, el pequeño bombeo que queda se equilibra con la fricción y con el recentrado del brazo, y el péndulo se queda oscilando unos $30^\circ$ por debajo de la vertical, sin entrar en la zona de captura. Con los parámetros nominales y \SI{10}{V} la ley con $E_r=0$ funciona por poco; con \SI{8}{V}, con el doble de fricción o con otra masa de péndulo, ya no. La solución es apuntar un poco por encima,
\begin{equation}
  E_r = e_r\cdot2m_pgl_p,\qquad e_r = 0{,}2 \quad(\text{\code{P.E\_ref}}),
\end{equation}
de modo que el péndulo llega arriba con algo de velocidad sobrante y el LQR la absorbe al capturarlo. Expresar $E_r$ como fracción de la energía colgado hace que el ajuste se adapte solo si cambian $m_p$ o $L_p$.

Valores por defecto: $k_E=200$, $a_{\max}=\SI{80}{rad/s^2}$, $k_x=25$, $k_v=1$, $e_r=0{,}2$."""
assert a in s; s=s.replace(a,b)
open(p,'w').write(s)
p='apendices.tex'; s=open(p).read()
a=r"El péndulo no se captura en el \emph{swing-up} & Comprobar \code{a\_max} y \code{Vmax}: con menos de \SI{6}{V} el motor no puede bombear suficiente energía con los valores por defecto.\\"
b=r"El péndulo no se captura en el \emph{swing-up} y oscila por debajo de la vertical & La energía no llega al objetivo: subir \code{E\_ref} (fracción de $2m_pgl_p$) o \code{k\_E}. Con \code{E\_ref = 0} la captura falla si la tensión o la fricción se alejan de los valores nominales (sección~\ref{sec:swingup}).\\"
assert a in s; s=s.replace(a,b)
s=s.replace(r"\code{kx\_sw}, \code{kv\_sw} & 25 / 1 & -- & recentrado durante el \emph{swing-up}\\",
            r"\code{kx\_sw}, \code{kv\_sw} & 25 / 1 & -- & recentrado durante el \emph{swing-up}\\"+"\n"+r"\code{E\_ref} & 0,2 & -- & energía objetivo, fracción de $2m_pgl_p$\\")
open(p,'w').write(s)
EOF
grep -n "E\\\\_ref" apendices.tex cap5_control.tex | head
```

</details>

<details><summary>Output</summary>

```
cap5_control.tex:167:  E_r = e_r\cdot2m_pgl_p,\qquad e_r = 0{,}2 \quad(\text{\code{P.E\_ref}}),
apendices.tex:31:\code{E\_ref} & 0,2 & -- & energía objetivo, fracción de $2m_pgl_p$\\
apendices.tex:85:El péndulo no se captura en el \emph{swing-up} y oscila por debajo de la vertical & La energía no llega al objetivo: subir \code{E\_ref} (fracción de $2m_pgl_p$) o \code{k\_E}. Con \code{E\_ref = 0} la captura falla si la tensión o la fricción se alejan de los valores nominales (sección~\ref{sec:swingup}).\\
```

</details>

**🔧 Bash** — Refine swing-up text and add practice item

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
p='cap5_control.tex'; s=open(p).read()
a="con \\SI{8}{V}, con el doble de fricción o con otra masa de péndulo, ya no."
assert a in s; s=s.replace(a,"con \\SI{8}{V}, con el triple de fricción de Coulomb o con la mitad o el doble de masa del péndulo, ya no.")
open(p,'w').write(s)
p='cap8_practicas.tex'; s=open(p).read()
a="  \\item Eliminar el recentrado (\\code{kx\\_sw = 0}, \\code{kv\\_sw = 0}) y observar cuántas vueltas da el brazo.\n"
assert a in s
s=s.replace(a,a+"  \\item Poner \\code{E\\_ref = 0} y repetir con $V_{\\max}=8$ y \\SI{10}{V} (\\code{rp.setParam('Vmax', 8)}). Explicar por qué el péndulo se queda oscilando sin llegar arriba.\n")
open(p,'w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Estoy esperando a que terminen en MATLAB la regeneración de los datos del manual y la validación (unos 6 minutos). Con esos resultados actualizaré las cifras del swing-up en el manual y en el README, lo compilaré y revisaré el PDF.

**🔧 Bash** — Read regeneration and validation output

<details><summary>Command</summary>

```bash
cat /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/tasks/bzr00j0cd.output
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
Manual data written to /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/rotpend_sim.slx
Validation runs written to /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum/validation/results
case         RMS dth[deg]  max dth RMS dal[deg]  max dal | metric python vs simulink
lqr_ic              0.075    0.275        0.023    0.142 | al settle(1deg) 0.40 vs 0.41 s, Vmax 8.8 vs 8.8 V
lqr_step            0.235    0.873        0.036    0.200 | th settle(5%) 0.72 vs 0.72 s, min th -3.4 vs -3.4 deg
lqr_push            0.257    1.146        0.068    0.348 | al settle(1deg) 1.90 vs 1.90 s, Vmax 10.0 vs 10.0 V
swingup             0.111    0.486        0.249    1.251 | catch 1.888 vs 1.888 s, max|th| 42.6 vs 42.6 deg
pid_ic              0.057    0.210        0.023    0.159 | al settle(1deg) 0.35 vs 0.35 s, Vmax 8.7 vs 8.7 V
pid_step            0.108    0.438        0.020    0.169 | th settle(5%) 0.91 vs 0.91 s, min th -3.4 vs -3.4 deg
down_step           0.025    0.121        0.025    0.118 | residual sway t>4s: 0.41 vs 0.41 deg
down_nosway         0.025    0.122        0.033    0.127 | residual sway t>4s: 1.60 vs 1.60 deg

lqr_step_ratelim: th settle(5%) 0.94 s, min th -0.9 deg, Vmax 3.0 V
sine 0.2 Hz: gain 0.999, phase lag 28.5 deg, Vmax 3.1 V, tripped=0
sine 0.5 Hz: gain 0.905, phase lag 73.3 deg, Vmax 3.7 V, tripped=0
sine 1 Hz: gain 0.657, phase lag 138.5 deg, Vmax 3.5 V, tripped=0
noise on: alpha std after 2 s 0.050 deg, V std 1.18 V, theta std 0.34 deg
lqr_ic: Vmax 8.79, settle1deg 0.41, max|th| 23.8
lqr_step (rate limited): min th -0.87, settle5% 0.94, max|al| 2.22, Vmax 3.03
lqr_push: max|al| 14.97, max|th| 57.29, Vmax 10.00, settle 1.90
swingup: catch 1.888 s, max|th| 42.6, Vmax 10.0, E0 -0.03037
swingup Vmax=6: catch 2.844 s, max|th| 35.1, final al 0.10
swingup mp=0.048: catch 2.468 s, max|th| 92.8, final al -0.09
swingup Lp=0.18: catch 1.708 s, max|th| 64.3, final al 0.09
pid_ic: Vmax 8.74, settle 0.35
pid_step: min th -0.84, settle5% 1.12, final th 45.89
down_step 90: sway t>4 0.26, max sway 4.25, settle 1.16
down_nosway 90: sway t>4 0.87, max sway 4.62
qsweep Qth=5: K [-2.24 -1.4 -42.7 -3.71] Vmax 7.48 settle 0.49 max|th| 27.1
qsweep Qth=20: K [-4.47 -1.98 -50.3 -4.42] Vmax 8.79 settle 0.41 max|th| 23.8
qsweep Qth=80: K [-8.94 -3.06 -64.2 -5.72] Vmax 10.00 settle 0.65 max|th| 21.5
rsweep 0.2: K [-10 -4.01 -84.7 -7.65] Vmax 10.00 settle 0.35
rsweep 5: K [-2 -1.06 -35.1 -2.99] Vmax 6.13 settle 0.52
msweep 0.012: settle 0.41 final al -0.07 stable 1
msweep 0.048: settle 0.76 final al -0.03 stable 1
msweep 0.072: settle 0.76 final al -0.02 stable 1
sine 0.2 Hz: gain 0.999 lag 28.5
sine 0.5 Hz: gain 0.905 lag 73.3
sine 1 Hz: gain 0.657 lag 138.5
noise: al std 0.050 deg, V std 1.18, th std 0.34 deg
quantization only: V s
... [truncated, 155 more characters]
```

</details>

**🔧 Bash** — Find outdated swing-up numbers

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels && grep -rn "2.236\|2,236\|2\.24\|2,24\|2\.2 s\|42,9\|42\.9\|43\^\|±43\|0,153\|0,269\|tres balanceos" doc/src/rotary_pendulum/*.tex src/rotary_pendulum/README.md
```

</details>

<details><summary>Output</summary>

```
doc/src/rotary_pendulum/cap5_control.tex:190:\draw[gray,dashed] (axis cs:2.236,-200) -- (axis cs:2.236,200);
doc/src/rotary_pendulum/cap5_control.tex:199:\caption{Swing-up desde el reposo colgando. La energía sube de \SI{-30.4}{mJ} a cero en unos pocos balanceos; a los \SI{2.24}{s} (línea discontinua) se captura con el LQR. El brazo no pasa de $\pm43^\circ$. Tras la captura $E$ deja de calcularse y se muestra como cero.}
doc/src/rotary_pendulum/apendices.tex:54:Swing-up + LQR & 0,153 & 0,269 & captura en 2,236 / 2,236 s; $|\theta|_{\max}$ 42,9 / 42,9$^\circ$\\
doc/src/rotary_pendulum/cap1_intro.tex:93:La figura~\ref{fig:frames} muestra la animación de ese ensayo: el controlador bombea energía al péndulo con movimientos alternos del brazo y lo captura arriba a los \SI{2.24}{s}.
src/rotary_pendulum/README.md:88:- **Swing-up**: catches the pendulum in 2.2 s from rest hanging, with the arm within ±43°.
```

</details>

**🔧 Bash** — Update swing-up figures in manual and README

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
edits={
'doc/src/rotary_pendulum/cap5_control.tex':[
 ("\\draw[gray,dashed] (axis cs:2.236,-200) -- (axis cs:2.236,200);","\\draw[gray,dashed] (axis cs:1.888,-200) -- (axis cs:1.888,200);"),
 ("La energía sube de \\SI{-30.4}{mJ} a cero en unos pocos balanceos; a los \\SI{2.24}{s} (línea discontinua) se captura con el LQR. El brazo no pasa de $\\pm43^\\circ$.",
  "La energía sube de \\SI{-30.4}{mJ} hacia el objetivo $E_r=\\SI{6.1}{mJ}$ en unos pocos balanceos; a los \\SI{1.89}{s} (línea discontinua) se captura con el LQR. El brazo no pasa de $\\pm43^\\circ$."),
 ("de modo que el péndulo llega arriba con algo de velocidad sobrante y el LQR la absorbe al capturarlo. Expresar $E_r$ como fracción de la energía colgado hace que el ajuste se adapte solo si cambian $m_p$ o $L_p$.",
  "de modo que el péndulo llega arriba con algo de velocidad sobrante y el LQR la absorbe al capturarlo. Expresar $E_r$ como fracción de la energía colgado hace que el ajuste se adapte solo si cambian $m_p$ o $L_p$. Con $e_r=0{,}2$ el swing-up captura el péndulo con \\SI{6}{V} de saturación (en \\SI{2.84}{s}), con el doble de masa del péndulo (\\SI{2.47}{s}, aunque el brazo llega a $93^\\circ$) y con un péndulo de \\SI{18}{cm} (\\SI{1.71}{s})."),
],
'doc/src/rotary_pendulum/apendices.tex':[
 ("Swing-up + LQR & 0,153 & 0,269 & captura en 2,236 / 2,236 s; $|\\theta|_{\\max}$ 42,9 / 42,9$^\\circ$\\\\","Swing-up + LQR & 0,111 & 0,249 & captura en 1,888 / 1,888 s; $|\\theta|_{\\max}$ 42,6 / 42,6$^\\circ$\\\\"),
],
'doc/src/rotary_pendulum/cap1_intro.tex':[
 ("y lo captura arriba a los \\SI{2.24}{s}.","y lo captura arriba a los \\SI{1.89}{s}."),
],
'src/rotary_pendulum/README.md':[
 ("- **Swing-up**: catches the pendulum in 2.2 s from rest hanging, with the arm within ±43°.",
  "- **Swing-up**: catches the pendulum in 1.9 s from rest hanging, with the arm within ±43°. Pumping aims slightly above the upright energy (`E_ref = 0.2`), which keeps it working with a 6 V supply, twice the pendulum mass or an 18 cm pendulum."),
 ("- **Encoder quantization** makes the balancing voltage chatter (≈1 V RMS): a good starting point for filter or observer design.",
  "- **Encoder quantization** alone makes the balancing voltage chatter by ≈1.1 V RMS (1.2 V with encoder noise on): a good starting point for filter or observer design."),
 ("| 2 | `swingup` | Energy pumping (Åström–Furuta) until \\|α\\| < 23°; then LQR catch |","| 2 | `swingup` | Energy pumping (Åström–Furuta) towards a target slightly above the upright energy until \\|α\\| < 23°; then LQR catch |"),
 ("Under matched conditions the discrepancies are ≤0.26° RMS in `θ` and ≤0.27° RMS in `α`","Under matched conditions the discrepancies are ≤0.26° RMS in `θ` and ≤0.25° RMS in `α`"),
]}
for p,rep in edits.items():
    s=open(p).read()
    for a,b in rep:
        assert a in s, (p,a[:50]); s=s.replace(a,b)
    open(p,'w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Reviso los fotogramas regenerados, porque la trayectoria del swing-up ha cambiado:

**🔧 Read** {"file_path": "/home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum/data/frames.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

Los fotogramas siguen contando bien la secuencia: colgando, bombeo, péndulo horizontal, recién capturado y equilibrado. Compilo el manual:

**🔧 Bash** — Compile rotary pendulum manual

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/doc/src/rotary_pendulum && O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex; mkdir -p $O; for i in 1 2 3; do pdflatex -interaction=nonstopmode -output-directory=$O manual.tex >/dev/null 2>&1; echo rc=$?; done; grep -E "^!" -A3 $O/manual.log | head -30; grep -E "undefined|Overfull" $O/manual.log | sort | uniq -c | head; grep -a -A1 "Output written" $O/manual.log
```

</details>

<details><summary>Output</summary>

```
rc=0
rc=0
rc=0
      1 Overfull \hbox (11.42674pt too wide) in paragraph at lines 75--76
      1 Overfull \hbox (21.1062pt too wide) in paragraph at lines 97--98
      1 Overfull \hbox (7.02658pt too wide) in paragraph at lines 198--199
Output written on /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlab
Models/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex/manual.pdf (38 page
```

</details>

## 🤖 Claude

Compila sin errores ni referencias rotas (38 páginas). Para revisar las páginas con figuras sin abrirlas una a una, genero una hoja de miniaturas:

**🔧 Bash** — Make thumbnail contact sheet of manual pages

<details><summary>Command</summary>

```bash
O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex; cd $O && rm -f pg-*.png && pdftoppm -png -r 45 manual.pdf pg && python3 -c "
from PIL import Image; import glob
fs=sorted(glob.glob('pg-*.png')); ims=[Image.open(f) for f in fs]; w,h=ims[0].size; cols=8; rows=(len(ims)+cols-1)//cols
sheet=Image.new('RGB',(cols*w,rows*h),'white')
for i,im in enumerate(ims): sheet.paste(im,((i%cols)*w,(i//cols)*h))
sheet.save('sheet.png'); print(len(ims), sheet.size)
"; grep -n "Overfull" -B0 -A0 manual.log | head; grep -o "(./cap[0-9a-z_]*.tex" manual.log | head -20
```

</details>

<details><summary>Output</summary>

```
38 (2984, 2635)
1412:Overfull \hbox (11.42674pt too wide) in paragraph at lines 75--76
1448:Overfull \hbox (7.02658pt too wide) in paragraph at lines 198--199
1465:Overfull \hbox (21.1062pt too wide) in paragraph at lines 97--98
(./cap1_intro.tex
(./cap2_modelo.tex
(./cap3_analisis.tex
(./cap4_sensores.tex
(./cap5_control.tex
(./cap6_simulink.tex
(./cap7_codigo.tex
(./cap8_practicas.tex
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex/sheet.png"}

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

En la vista general la estructura es correcta. Miro de cerca las páginas de figuras más densas (pesos del LQR y swing-up):

**🔧 Bash** — Render control chapter pages

<details><summary>Command</summary>

```bash
O=/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex; cd $O && pdftoppm -png -r 70 -f 17 -l 19 manual.pdf zz && python3 -c "
from PIL import Image
ims=[Image.open(f'zz-{i}.png') for i in (17,18,19)]; w,h=ims[0].size
s=Image.new('RGB',(3*w,h),'white')
for i,im in enumerate(ims): s.paste(im,(i*w,0))
s.save('zz.png')"
```

</details>

**🔧 Read** {"file_path": "/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex/zz.png"}

<details><summary>Output</summary>

```
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Install PDF, update gitignore, show status

<details><summary>Command</summary>

```bash
cp /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/rtex/manual.pdf doc/rotary_pendulum_manual.pdf && sed -i 's#^src/\*\*/cartpole_sim.slx$#src/**/*_sim.slx#' .gitignore && find . -name __pycache__ -not -path ./.git/\* -exec rm -rf {} + ; git status --short | grep -v "doc/src/rotary_pendulum/data/.*\.dat"; ls src/rotary_pendulum
```

</details>

<details><summary>Output</summary>

```
 M .gitignore
?? doc/rotary_pendulum_manual.pdf
?? doc/src/rotary_pendulum/
?? src/rotary_pendulum/
examples.m
python_reference_sim.py
README.md
RotaryPendulum.m
rotpend_sim.slx
rotpend_sim.slxc
rp_animate.m
rp_build_model.m
rp_controller_block.m
rp_design.m
rp_draw.m
rp_gui.m
rp_linearize.m
rp_lqr.m
rp_params.m
rp_plant_block.m
rp_plot_results.m
rp_ref_block.m
rp_view.m
slprj
validation
```

</details>

## 🤖 Claude

El péndulo rotacional (péndulo de Furuta) está terminado. Lo he ejecutado y validado en Simulink, y la animación la he revisado sobre imágenes renderizadas y capturas de la GUI en marcha. Todavía no he hecho commit.

## Dónde está
- **Código:** `src/rotary_pendulum/`. Sigue la misma estructura que el péndulo lineal: `rp_build_model`, la clase `RotaryPendulum`, `rp_gui`, `examples.m`, la réplica en Python y la carpeta `validation/`.
- **Manual:** `doc/rotary_pendulum_manual.pdf` (38 páginas), con las fuentes LaTeX en `doc/src/rotary_pendulum/`. Todas las gráficas salen de Simulink, generadas por `data/generate_data.m`.

Para probarlo en MATLAB:
```matlab
cd src/rotary_pendulum
rp_build_model
rp_gui
```

## El modelo
- Brazo horizontal movido por un motor DC con entrada en tensión (±10 V) y péndulo en su extremo. Solo se miden los dos ángulos, con encoders de 2048 cuentas por vuelta, y el controlador estima las velocidades.
- La dinámica es la no lineal completa, incluidos los términos centrífugos y de Coriolis que no existen en el carro-péndulo, más la fuerza contraelectromotriz del motor y fricción viscosa y de Coulomb.
- Tiene los mismos 5 modos que el lineal: `open`, `lqr`, `swingup`, `pid` y `down`. El último equivale a la grúa: posiciona el brazo amortiguando el balanceo del péndulo colgante.
- La interfaz de código trabaja en radianes. La GUI y los resultados (campos `*_deg`) también dan los ángulos en grados.

## La animación
- Es una escena 3D con el motor, el brazo, el péndulo, sus sombras sobre la base y la referencia del brazo marcada en la circunferencia que recorre su extremo.
- Probé varios puntos de vista y dejé por defecto uno que mira a lo largo del brazo, de modo que el balanceo del péndulo se ve de lado.
- En la GUI hay un selector de vista (3D, superior, frontal, lateral) y la escena se puede girar con el ratón.
- Corregí sobre las imágenes tres fallos que no habría visto sin renderizar: el péndulo colgando atravesaba la base, la iluminación oscurecía la placa y el zoom hacía que la escena tapara la gráfica de θ.

## Resultados
| Ensayo | Resultado |
|---|---|
| LQR desde α = 10° | estable en 0,41 s, con 8,8 V de pico |
| Swing-up desde colgado | captura en 1,89 s, con el brazo dentro de ±43° |
| Simulink frente a Python | diferencias ≤0,26° RMS; el swing-up captura en el mismo instante en ambos |
| En vivo frente a por lotes | trayectorias idénticas, también lanzando desde la GUI |

## Lo que conviene que sepas
1. **Mejoré el swing-up.** Mi primer ajuste solo funcionaba con 10 V exactos: con 8 V, o con otra masa de péndulo, el péndulo se quedaba oscilando por debajo de la vertical sin llegar a capturarse. Ahora el bombeo apunta a una energía un poco superior a la de arriba (`E_ref = 0.2`). Con eso funciona en los 28 casos que probé, entre ellos 6 V, el doble y la mitad de masa del péndulo y el triple de fricción. El manual explica el problema y la solución, y una práctica lo propone como ejercicio.
2. **El anti-balanceo del modo `down` mejora menos que en el péndulo lineal:** deja 0,26° de oscilación residual frente a 0,87° sin él. Es un efecto físico, no un fallo: este péndulo es corto y oscila deprisa respecto al movimiento del brazo. El manual lo explica.
3. **Una discrepancia que no he podido reproducir.** En una de las capturas de la GUI, la trayectoria en vivo se separó de la simulación por lotes. En seis repeticiones posteriores coincidieron exactamente. No encontré la causa; si ves algo raro al usar la GUI, dímelo.

¿Hago commit y push de este segundo experimento, como con el primero?

## 🧑 User

Sí, commit y push exactamente igual. Pero antes, genera un readme con los experimentos, que vamos a ir creciendo poco a poco

**🔧 Bash** — Inspect repo root, conversations and last commit

<details><summary>Command</summary>

```bash
ls -la && ls admin/conversations && cat README.md 2>/dev/null | head -50; git log --stat -1 | head -40; ls /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad
```

</details>

<details><summary>Output</summary>

```
total 28
drwxrwxr-x  6 aguti aguti 4096 Nov 25 14:35 .
drwxrwxr-x 13 aguti aguti 4096 Nov 25 12:49 ..
drwxrwxr-x  3 aguti aguti 4096 Nov 25 13:26 admin
drwxrwxr-x  3 aguti aguti 4096 Nov 25 14:35 doc
drwxrwxr-x  8 aguti aguti 4096 Nov 25 14:35 .git
-rw-rw-r--  1 aguti aguti  262 Nov 25 14:35 .gitignore
drwxrwxr-x  4 aguti aguti 4096 Nov 25 13:45 src
2026-11-25_linear_pendulum_setup_and_validation.md
commit 162f62a5677f0757cf433eef8fb0daef86cd2ad6
Author: aguti <[redacted]>
Date:   Wed Nov 25 13:23:45 2026 +0100

    Add linear pendulum (cart-pole) Simulink experiment
    
    - Script-generated Simulink model (cp_build_model), CartPole code
      interface with batch and live real-time modes, and live GUI (cp_gui).
    - All code, identifiers and directory names in English.
    - Fix invalid block name containing '/' that broke cp_build_model.
    - Cross-validation against the Python replica (validation/), run on
      MATLAB R2025b: <=1.3 mm RMS in x and <=0.2 deg RMS in theta.
    - LaTeX theory/practice manual (Spanish) with a new validation appendix.
    
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

 .gitignore                                         |   21 +
 ...6-11-25_linear_pendulum_setup_and_validation.md | 2858 ++++++++++++++++++++
 doc/linear_pendulum_manual.pdf                     |  Bin 0 -> 928463 bytes
 doc/src/linear_pendulum/apendices.tex              |  121 +
 doc/src/linear_pendulum/cap1_intro.tex             |  122 +
 doc/src/linear_pendulum/cap2_modelo.tex            |  123 +
 doc/src/linear_pendulum/cap3_analisis.tex          |  151 ++
 doc/src/linear_pendulum/cap4_sensores.tex          |   78 +
 doc/src/linear_pendulum/cap5_control.tex           |  354 +++
 doc/src/linear_pendulum/cap6_simulink.tex          |  122 +
 doc/src/linear_pendulum/cap7_codigo.tex            |  181 ++
 doc/src/linear_pendulum/cap8_practicas.tex         |  204 ++
 doc/src/linear_pendulum/data/bode_dn_th.dat        |  301 +++
 doc/src/linear_pendulum/data/bode_dn_x.dat         |  301 +++
 doc/src/linear_pendulum/data/bode_up_th.dat        |  301 +++
 doc/src/linear_pendulum/data/bode_up_x.dat         |  301 +++
 doc/src/linear_pendulum/data/crane.dat             |  401 +++
 doc/src/linear_pendulum/data/crane_nosway.dat      |  401 +++
 doc/src/linear_pendulum/data/generar_datos.py      |   73 +
 doc/src/linear_pendulum/data/lqr_ic.dat            |  301 +++
 doc/src/linear_pendulum/data/lqr_locus.dat         |  161 ++
 doc/src/linear_pendulum/data/lqr_push.dat          |  301 +++
 doc/src/linear_pendulum/data/lqr_step.dat          |  401 +++
 doc/src/linear_pendulum/data/msweep_0.3.dat        |  301 +++
compare.py
examples_test.m
export.py
figtest
lqr_ic.mat
rotpend_sim.slxc
rp
rp1.m
rp2.m
rp3.m
rp4.m
rp5.m
rp6.m
rp7.m
rp8.m
rtex
sl
slprj
tex
val1.m
val2.m
val3.m
```

</details>

**🔧 Bash** — Show export script and linear README header

<details><summary>Command</summary>

```bash
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad && cat export.py; head -30 /home/aguti/universidad/controlSystemsMatlabModels/src/linear_pendulum/README.md
```

</details>

<details><summary>Output</summary>

```
import json, sys, re
src, dst = sys.argv[1], sys.argv[2]
MAXRES = 3000
def clean_user(s):
    s = re.sub(r'<pasted_content id="[^"]*">', '<pasted_content>', s)
    s = re.sub(r'</pasted_content id="[^"]*">', '</pasted_content>', s)
    return s.strip()
def fence(s, lang=''):
    s = s.rstrip()
    n = 3
    while '`'*n in s: n += 1
    return f"{'`'*n}{lang}\n{s}\n{'`'*n}"
def trunc(s):
    return s if len(s) <= MAXRES else s[:MAXRES] + f"\n... [truncated, {len(s)-MAXRES} more characters]"
out = ["# Conversation: linear pendulum — setup, English translation and Simulink validation",
       "", "Claude Code session `861c5db6`, 2026-11-25. Exported from the session transcript.",
       "Internal reasoning and harness metadata are omitted; tool outputs are collapsed and truncated.", ""]
seen_tool = {}
for line in open(src):
    d = json.loads(line); t = d.get('type')
    if d.get('isSidechain'): continue
    if t == 'attachment':
        a = d.get('attachment', {})
        if a.get('type') == 'queued_command':
            p = a.get('prompt')
            p = p if isinstance(p, str) else ' '.join(x.get('text','') for x in (p or []) if isinstance(x, dict))
            if p and '<task-notification>' not in p:
                out += ["## 🧑 User (sent while Claude was working)", "", clean_user(p), ""]
        continue
    m = d.get('message') or {}
    c = m.get('content')
    if t == 'user':
        if isinstance(c, str):
            if any(k in c for k in ('<local-command', '<command-name>', '<task-notification>')): continue
            out += ["## 🧑 User", "", clean_user(c), ""]
        elif isinstance(c, list):
            for x in c:
                if x.get('type') == 'tool_result':
                    r = x.get('content')
                    if isinstance(r, list): r = '\n'.join(y.get('text', '') for y in r if y.get('type') == 'text')
                    r = trunc(str(r or '(no output)'))
                    label = 'Error' if x.get('is_error') else 'Output'
                    out += [f"<details><summary>{label}</summary>", "", fence(r), "", "</details>", ""]
                elif x.get('type') == 'text' and not x['text'].startswith('<'):
                    out += ["## 🧑 User", "", clean_user(x['text']), ""]
    elif t == 'assistant' and isinstance(c, list):
        for x in c:
            if x.get('type') == 'text' and x['text'].strip():
                out += ["## 🤖 Claude", "", x['text'].strip(), ""]
            elif x.get('type') == 'tool_use':
                n, i = x['name'], x.get('input', {})
                if n == 'Bash':
                    out += [f"**🔧 Bash** — {i.get('description','')}", "", "<details><summary>Command</summary>", "", fence(i.get('command',''), 'bash'), "", "</details>", ""]
                elif n in ('Write',):
                    out += [f"**🔧 Write** `{i.get('file_path')}` ({len(i.get('content',''))} characters)", ""]
                elif n == 'Edit':
                    out += [f"**🔧 Edit** `{i.get('file_path')}`"
... [truncated, 2091 more characters]
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/README.md` (3570 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/README.md (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Link experiment READMEs to root and locate transcript

<details><summary>Command</summary>

```bash
sed -i 's|^Experiment 1 of the control systems series (the rotary pendulum, ball and plate, etc. will follow).|Experiment 1 of the control systems series (followed by the [rotary pendulum](../rotary_pendulum/README.md); see the [list of experiments](../../README.md)).|' src/linear_pendulum/README.md && sed -i 's|^Experiment 2 of the control systems series (after the \[linear pendulum\](../linear_pendulum/README.md)).|Experiment 2 of the control systems series (after the [linear pendulum](../linear_pendulum/README.md); see the [list of experiments](../../README.md)).|' src/rotary_pendulum/README.md && sed -n 3p src/*/README.md
ls -la ~/.claude/projects/-home-aguti-universidad-controlSystemsMatlabModels/*.jsonl
grep -c '' ~/.claude/projects/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6*.jsonl; grep -n 'Vamos a generar un segundo' ~/.claude/projects/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6*.jsonl | cut -c1-120
```

</details>

<details><summary>Output</summary>

```
Experiment 1 of the control systems series (followed by the [rotary pendulum](../rotary_pendulum/README.md); see the [list of experiments](../../README.md)).
-rw------- 1 aguti aguti 9780927 Nov 25 15:32 /home/aguti/.claude/projects/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f.jsonl
1695
742:{"parentUuid":"36122dca-8fbe-455c-a2b8-9cc3af5d83c0","isSidechain":false,"promptId":"58cf1ea9-6b71-4664-a2f5-4b990c3
752:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
765:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
789:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
807:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
830:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
854:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
878:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
900:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
926:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
941:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
951:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
971:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
994:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo es
1016:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1035:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1051:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1066:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1092:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1109:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1126:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1144:{"type":"last-prompt","lastPrompt":"Vamos a generar un segundo experimento. Un pendulo rotacional. Sigue el mismo e
1161:{
... [truncated, 3493 more characters]
```

</details>

