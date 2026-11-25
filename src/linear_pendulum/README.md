# Linear pendulum (cart-pole): Simulink simulation

Experiment 1 of the control systems series (followed by the [rotary pendulum](../rotary_pendulum/README.md); see the [list of experiments](../../README.md)).

A cart runs on a ±0.8 m rail, driven by a linear force actuator. An articulated rod hangs from the cart. **Only positions are measured**, with a linear encoder for `x` and an angular one for `θ`. The controller estimates velocities with a filtered derivative.

The theory/practice manual (in Spanish) is in [`doc/linear_pendulum_manual.pdf`](../../doc/linear_pendulum_manual.pdf), with its LaTeX sources in `doc/src/linear_pendulum/`.

## Requirements
- MATLAB + Simulink, R2020b or later (for `uifigure` and `tiledlayout`). Real-time simulation uses *pacing*, available since R2018a.
- The Control System Toolbox is **optional**. Without it, `cp_lqr` solves the Riccati equation with the Hamiltonian method.

## Quick start
```matlab
cd src/linear_pendulum
cp_build_model      % generates cartpole_sim.slx (first time only, or after editing the *_block.m files)
cp_gui              % live visual interface
% or, from code:
cp = CartPole(); cp.setMode('swingup'); cp.setInitialState([0 0 pi 0]);
res = cp.run(12); cp_plot_results(res); cp.animate(res);
```
`examples.m` contains a section-by-section walkthrough: LQR, step, push, swing-up, PID, crane, chirp identification, parameter sweep and live control from code.

## Conventions
| Variable | Meaning |
|---|---|
| `x` | Cart position [m]; positive to the right |
| `θ` | Pendulum angle [rad]; **0 = up**, π = hanging. If θ > 0 it leans towards +x |
| `F` | Force on the cart [N]; ±15 N saturation, first-order actuator with τ = 10 ms |
| State | `[x; ẋ; θ; θ̇]` |

## Structure of the `cartpole_sim.slx` model
```
Clock, cmd_ref, ref_ext → [Reference] → r ─┐
cmd_ctrl ──────────────────────────────────┼→ [Controller] → (+u_ext) → [Actuator] → [Plant] → s
                    y_meas ← [Sensors] ←───┘                   cmd_dist + d_ext ┘           │
                                ↑───────────────────────────────────────────────────────────┘
s, y_meas, F, r, info → telemetry → out.tel (13 signals) + Scope
```
- **Plant**: full nonlinear dynamics (Lagrange; the rod has inertia). Includes viscous and Coulomb friction on the cart, pivot friction and elastic end stops at the rail ends.
- **Sensors**: encoder quantization (0.1 mm and 4096 counts/rev), optional noise and 500 Hz sampling.
- **Controller**: discrete, `Ts` = 2 ms. Offers 5 modes and a safety cut-off if |x| > 0.78 m.
- **Solver**: fixed-step ode4, h = 1 ms.

The code of each *MATLAB Function* block lives in `cp_plant_block.m`, `cp_controller_block.m` and `cp_ref_block.m`. If you edit any of them, run `cp_build_model` again.

## Control modes
| # | Mode | Description |
|---|---|---|
| 0 | `open` | Applies `F = u_manual + u_ext`. Useful for identification |
| 1 | `lqr` | LQR with the pendulum up; the cart tracks the reference `r` |
| 2 | `swingup` | Energy pumping (Åström–Furuta) until \|θ\| < 20°; then LQR catch |
| 3 | `pid` | PID on the angle plus PD on the cart |
| 4 | `crane` | Pendulum down: moves the cart to `r` while damping the sway (LQR around θ = π) |

## Code interface (`CartPole`)
| Method | What it does |
|---|---|
| `run(T)` | Batch simulation; returns a struct with `t, x, xd, th, thd, xm, thm, Fcmd, Fact, r, mode, E, caught, tripped` |
| `start()` / `stop()` / `pause()` / `resume()` | Live execution at `PacingRate` speed (1 = real time) |
| `setMode`, `enable`, `setForce`, `setRef(type, offset, amp, f)`, `push(F, dur)` | Work **live** |
| `setParam(name, value)` / `setParams(struct)` | Change parameters, recompute the LQR and apply it, also live |
| `setParamRaw(name, value)` | Changes a parameter without recomputing gains (robustness tests) |
| `setRefSignal(t, r)`, `setForceSignal(t, u)`, `setDisturbanceSignal(t, Fd)` | Load time signals; read when the simulation starts |
| `addTelemetryCallback(@(t, d) ...)` | Calls your function with live telemetry at `TelemetryRate` Hz |

## GUI (`cp_gui`)
- Cart-pole animation and live plots of x/r, θ and F.
- Controls for: mode, control enable, manual force, push, reference (constant, sine, square, triangle or external), LQR Q/R weights with hot recomputation, sensor noise, simulation speed and initial state.
- Keyboard: ←/→ arrows apply a ±5 N manual force; space bar gives a push.
- **Export** stores the last run in `cp_res` in the workspace and plots it.

## Validation
`validation/run_validation.m` runs the reference scenarios on the Simulink model and `validation/compare_with_python.py` compares them sample by sample with the Python replica. Under matched conditions the discrepancies are ≤1.3 mm RMS in `x` and ≤0.2° RMS in `θ` (see appendix B of the manual).
```matlab
cd src/linear_pendulum/validation
run_validation                     % writes results/*.csv
!python3 compare_with_python.py
```

## Expected behaviour
Verified in Simulink (R2025b) and against a Python replica of the same physics and controllers (`python_reference_sim.py`):
- **LQR from θ₀ = 0.15 rad**: settles in under 3 s, with a force peak of about 13 N. K = [−22.4 −19.6 −84.2 −14.3].
- **0.3 m step**: the cart first moves the opposite way (non-minimum phase, as expected: ~19 mm with the default rate limiter) and reaches the reference in 2–3 s. Afterwards it shows a slow ±8 mm limit cycle caused by Coulomb friction (±20 mm with the PID), since neither controller has integral action on `x`.
- **Swing-up**: catches the pendulum in 3–6 s depending on the initial state, without leaving the rail (|x| < 0.75 m).
- **Crane**: with a 0.5 m step, the cart reaches its target with negligible residual sway.
- **Sine tracking**: pure LQR shows noticeable lag above about 0.1 Hz. This is the natural limitation without feedforward or integral action, and a good candidate for the next experiment.
