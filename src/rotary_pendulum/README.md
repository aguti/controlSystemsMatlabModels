# Rotary pendulum (Furuta pendulum): Simulink simulation

Experiment 2 of the control systems series (after the [linear pendulum](../linear_pendulum/README.md); see the [list of experiments](../../README.md)).

A DC motor turns a horizontal arm; an unactuated pendulum hangs from the arm tip and swings in the plane perpendicular to the arm. **Only angles are measured**, with an encoder on the motor (`θ`, arm) and one on the pendulum pivot (`α`). The controller estimates velocities with a filtered derivative. The input is the motor **voltage** (±10 V).

The theory/practice manual (in Spanish) is in [`doc/rotary_pendulum_manual.pdf`](../../doc/rotary_pendulum_manual.pdf), with its LaTeX sources in `doc/src/rotary_pendulum/`.

## Requirements
- MATLAB + Simulink, R2020b or later (for `uifigure` and `tiledlayout`). Real-time simulation uses *pacing*, available since R2018a. Tested on R2025b.
- The Control System Toolbox is **optional**. Without it, `rp_lqr` solves the Riccati equation with the Hamiltonian method.

## Quick start
```matlab
cd src/rotary_pendulum
rp_build_model      % generates rotpend_sim.slx (first time only, or after editing the *_block.m files)
rp_gui              % live visual interface with 3D animation
% or, from code:
rp = RotaryPendulum(); rp.setMode('swingup'); rp.setInitialState([0 0 pi 0]);
res = rp.run(8); rp_plot_results(res); rp.animate(res);
```
`examples.m` contains a section-by-section walkthrough: LQR, arm step, tap, swing-up, PID, down mode, chirp identification, parameter sweep and live control from code.

## Conventions
| Variable | Meaning |
|---|---|
| `θ` | Arm angle [rad]; positive counter-clockwise seen from above. Not wrapped (the arm may turn) |
| `α` | Pendulum angle [rad]; **0 = up**, π = hanging. If α > 0 it leans towards +θ |
| `V` | Motor voltage [V]; ±10 V saturation. Torque `τ = kt (V − km θ̇)/Rm` |
| State | `[θ; θ̇; α; α̇]` |

The code interface works in **radians**; the GUI and the `*_deg` fields of the results use degrees.

## Structure of the `rotpend_sim.slx` model
```
Clock, cmd_ref, ref_ext → [Reference] → r ─┐
cmd_ctrl ──────────────────────────────────┼→ [Controller] → (+u_ext) → [Amplifier] → [Plant] → s
                    y_meas ← [Sensors] ←───┘                    cmd_dist + d_ext ┘          │
                                ↑───────────────────────────────────────────────────────────┘
s, y_meas, V, r, info → telemetry → out.tel (13 signals) + Scope
```
- **Plant**: full nonlinear Furuta dynamics (Lagrange; the pendulum has inertia and the centripetal/Coriolis coupling terms are kept) and a DC motor with back-EMF. Includes viscous and Coulomb friction on the arm and viscous friction on the pendulum pivot.
- **Amplifier**: ±10 V saturation.
- **Sensors**: encoder quantization (2048 counts/rev on both axes), optional noise and 500 Hz sampling.
- **Controller**: discrete, `Ts` = 2 ms. Offers 5 modes and a safety cut-off if |θ| > 360° (cable wrap).
- **Solver**: fixed-step ode4, h = 1 ms.

The code of each *MATLAB Function* block lives in `rp_plant_block.m`, `rp_controller_block.m` and `rp_ref_block.m`. If you edit any of them, run `rp_build_model` again.

## Control modes
| # | Mode | Description |
|---|---|---|
| 0 | `open` | Applies `V = u_manual + u_ext`. Useful for identification |
| 1 | `lqr` | LQR with the pendulum up; the arm tracks the reference `r` |
| 2 | `swingup` | Energy pumping (Åström–Furuta) towards a target slightly above the upright energy until \|α\| < 23°; then LQR catch |
| 3 | `pid` | PID on the pendulum angle plus PD on the arm |
| 4 | `down` | Pendulum hanging: moves the arm to `r` while damping the sway (LQR around α = π) |

## Code interface (`RotaryPendulum`)
| Method | What it does |
|---|---|
| `run(T)` | Batch simulation; returns a struct with `t, th, thd, al, ald, thm, alm, Vcmd, Vact, r, mode, E, caught, tripped` plus `th_deg, al_deg, r_deg` |
| `start()` / `stop()` / `pause()` / `resume()` | Live execution at `PacingRate` speed (1 = real time) |
| `setMode`, `enable`, `setVoltage`, `setRef(type, offset, amp, f)`, `push(F, dur)` | Work **live** |
| `setParam(name, value)` / `setParams(struct)` | Change parameters, recompute inertias and the LQR and apply them, also live |
| `setParamRaw(name, value)` | Changes a parameter without recomputing gains (robustness tests) |
| `setRefSignal(t, r)`, `setVoltageSignal(t, u)`, `setDisturbanceSignal(t, Fd)` | Load time signals; read when the simulation starts |
| `addTelemetryCallback(@(t, d) ...)` | Calls your function with live telemetry at `TelemetryRate` Hz |

## GUI (`rp_gui`)
- 3D animation of the rotary pendulum (motor, arm, pendulum, shadows on the base plate, arm reference marker) and live plots of θ/r, α and V. The view can be rotated with the mouse or chosen from the **View** list (3D, top, front, side).
- Controls for: mode, control enable, manual voltage, push, arm reference (constant, sine, square, triangle or external, in degrees), LQR Q/R weights with hot recomputation, sensor noise, simulation speed and initial state.
- Keyboard: ←/→ arrows apply a ±3 V manual voltage; space bar gives a push at the pendulum tip.
- **Export** stores the last run in `rp_res` in the workspace and plots it.

## Validation
`validation/run_validation.m` runs the reference scenarios on the Simulink model and `validation/compare_with_python.py` compares them sample by sample with the Python replica (`python_reference_sim.py`). Under matched conditions the discrepancies are ≤0.26° RMS in `θ` and ≤0.25° RMS in `α` (see appendix B of the manual).
```matlab
cd src/rotary_pendulum/validation
run_validation                     % writes results/*.csv
!python3 compare_with_python.py
```

## Expected behaviour
Verified in Simulink (R2025b) and against the Python replica:
- **LQR from α₀ = 10°**: settles within 1° in 0.4 s, with a voltage peak of 8.8 V. K = [−4.47 −1.98 −50.3 −4.42].
- **45° arm step**: the arm first moves the opposite way (non-minimum phase, −3.4° without rate limiter, −0.9° with the default 2 rad/s limiter) and settles within 5% in 0.7–0.9 s.
- **Swing-up**: catches the pendulum in 1.9 s from rest hanging, with the arm within ±43°. Pumping aims slightly above the upright energy (`E_ref = 0.2`), which keeps it working with a 6 V supply, twice the pendulum mass or an 18 cm pendulum.
- **Down mode**: a 45° arm step leaves 0.4° of residual sway, versus 1.6° without pendulum feedback.
- **Sine tracking (±45°)** with pure LQR: phase lag of 29° at 0.2 Hz, 73° at 0.5 Hz and 139° at 1 Hz.
- **Encoder quantization** alone makes the balancing voltage chatter by ≈1.1 V RMS (1.2 V with encoder noise on): a good starting point for filter or observer design.
