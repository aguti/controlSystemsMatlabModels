# Ball and plate: Simulink simulation

Experiment 4 of the control systems series (the two-axis extension of the [ball and beam](../ball_beam/README.md); see the [list of experiments](../../README.md)).

A steel ball rolls on a 30 × 30 cm plate held by a two-axis gimbal at its centre. Motor A tilts the outer frame (angle `α`, about the y axis) and motor B, riding on the outer frame, tilts the plate (angle `β`, about the x axis). An **overhead camera** measures the ball position at 50 fps with one frame of latency; encoders measure both plate angles. The inputs are the two motor **voltages** (±10 V).

The theory/practice manual (in Spanish) is in [`doc/ball_plate_manual.pdf`](../../doc/ball_plate_manual.pdf), with its LaTeX sources in `doc/src/ball_plate/`.

## Requirements
- MATLAB + Simulink, R2020b or later (for `uifigure` and `tiledlayout`). Real-time simulation uses *pacing*, available since R2018a. Tested on R2025b.
- The Control System Toolbox is **optional**. Without it, `bp_lqr` solves the Riccati equation with the Hamiltonian method.

## Quick start
```matlab
cd src/ball_plate
bp_build_model      % generates ballplate_sim.slx (first time only, or after editing the *_block.m files)
bp_gui              % live visual interface: 3D view + clickable camera view
% or, from code:
bp = BallPlate(); bp.setMode('lqr'); bp.setRef('circle', [0 0], 0.06, 0.2);
res = bp.run(15); bp_plot_results(res); bp.animate(res);
```
`examples.m` contains a section-by-section walkthrough: LQR, LQR vs cascade, circle, figure of eight and square, camera frame rate, tap rejection, open-loop instability, axis coupling and live control from code.

## Conventions
| Variable | Meaning |
|---|---|
| `x`, `y` | Ball position on the plate [m]; 0 = centre. Rim at ±(a − rb) = ±13.7 cm on each axis |
| `α` | Plate tilt about the y axis [rad]. **α > 0 raises the +x edge** (the ball rolls towards −x). Driven by motor A |
| `β` | Plate tilt about the x axis [rad]. **β > 0 raises the +y edge** (the ball rolls towards −y). Driven by motor B |
| `Va`, `Vb` | Motor voltages [V]; ±10 V saturation |
| State | `[x; ẋ; y; ẏ; α; α̇; β; β̇]` |

The code interface works in **metres and radians**; the GUI and the `*_cm`/`*_deg` fields of the results use centimetres and degrees.

## Structure of the `ballplate_sim.slx` model
```
Clock, cmd_ref, ref_ext → [Reference] → r ─┐
cmd_ctrl ──────────────────────────────────┼→ [Controller] → (+u_ext) → [Amplifier] → [Plant] → s
                    y_meas ← [Sensors] ←───┘                    cmd_dist + d_ext ┘          │
                                ↑───────────────────────────────────────────────────────────┘
s, y_meas, V, r, info → telemetry → out.tel (23 signals) + Scope
```
- **Plant**: full nonlinear 4-DOF dynamics (Lagrange, `q = [x, y, α, β]`). The ball rolls without slipping (7/5 m effective mass); the α axis also carries the inner gimbal frame. All coupling terms are kept: centrifugal, Coriolis and the `m x y α̇ β̇` cross-inertia between the two tilt axes. Two DC motors with back-EMF through 70:1 gearboxes, viscous + Coulomb friction on each axis, rolling friction on the ball, stiff stops at the rim and at ±15° of tilt.
- **Amplifier**: ±10 V saturation on each channel.
- **Sensors**: overhead camera (frame period `Tcam` = 20 ms, `cam_delay` = 1 frame of latency, 0.5 mm/pixel) and 4096 counts/rev encoders on both tilt axes at 500 Hz; optional noise.
- **Controller**: discrete, `Ts` = 2 ms for the plate loops; the ball loops update once per camera frame.
- **Solver**: fixed-step ode4, h = 1 ms.

The code of each *MATLAB Function* block lives in `bp_plant_block.m`, `bp_controller_block.m` and `bp_ref_block.m`. If you edit any of them, run `bp_build_model` again.

## Control modes
| # | Mode | Description |
|---|---|---|
| 0 | `open` | Applies `[Va Vb] = manual + u_ext`. Useful for identification |
| 1 | `plate` | PD servo of both plate angles to `(α_manual, β_manual)`; the ball is free |
| 2 | `cascade` | Per axis: outer PID on the ball (camera rate, output = tilt reference, ±11.5°) → inner PD on the plate angle (every `Ts`) |
| 3 | `lqr` | One LQR with integral action per axis (x → α, y → β), designed on the decoupled linear model |

Around the centre with a level plate the two axes decouple exactly, so each axis is a ball-and-beam. Both ball controllers compensate the ball weight torque (`ff_on = 1`) and integrate only within 2 cm of the target.

## Reference types
`setRef(type, [cx cy], A, f)`: `'point'` (cx, cy), `'circle'` of radius A, `'square'` (jumps between the four corners cx ± A, cy ± A), `'eight'` (Lissajous 1:2 of half width A) and `'external'` (`ref_ext`). The reference is rate limited (0.3 m/s per axis) and saturated at ±10 cm.

## Code interface (`BallPlate`)
| Method | What it does |
|---|---|
| `run(T)` | Batch simulation; returns a struct with the 23 telemetry signals (`t, x, xd, y, yd, al, ald, be, bed, xm, ym, alm, bem, Vca, Vcb, Va, Vb, rx, ry, mode, alr, ber, Ix, Iy`) plus `x_cm, y_cm, rx_cm, ry_cm, al_deg, be_deg` |
| `start()` / `stop()` / `pause()` / `resume()` | Live execution at `PacingRate` speed (1 = real time) |
| `setMode`, `enable`, `setVoltage(Va, Vb)`, `setPlateAngle(α, β)`, `setRef(...)`, `push([Fx Fy], dur)` | Work **live** |
| `setParam(name, value)` / `setParams(struct)` | Change parameters, recompute inertias and both LQRs and apply them, also live |
| `setParamRaw(name, value)` | Changes a parameter without recomputing gains (robustness tests) |
| `setRefSignal(t, [rx ry])`, `setVoltageSignal(t, [Va Vb])`, `setDisturbanceSignal(t, [Fx Fy])` | Load time signals; read when the simulation starts |
| `addTelemetryCallback(@(t, d) ...)` | Calls your function with live telemetry at up to `TelemetryRate` Hz |

`Tcam` and `cam_delay` set sample times, so they take effect at the next start.

## GUI (`bp_gui`)
- 3D animation of the gimbal, plate (5 cm grid), two-tone rolling ball with a trail and shadow, and the reference ring; next to it, the **camera view** (top view). **Clicking on the camera view moves the target point.** Live plots of x, y and their references, both tilts and both voltages.
- Controls for: mode, control enable, weight feedforward, manual voltages, plate tilts (mode `plate`), taps, reference (point, circle, square, figure of eight, external), cascade gains and LQR weights with hot recomputation, sensor noise, camera frame rate (25–250 fps, applied at the next start), simulation speed, view and initial position.
- Keyboard: arrow keys tap the ball in that direction.
- **Export** stores the last run in `bp_res` in the workspace and plots it.

## Validation
`validation/run_validation.m` runs the reference scenarios on the Simulink model and `validation/compare_with_python.py` compares them sample by sample with the Python replica (`python_reference_sim.py`), which models the camera timing too. Under matched conditions the discrepancies are ≤0.27 mm RMS in position and ≤0.07° RMS in tilt (see appendix B of the manual).
```matlab
cd src/ball_plate/validation
run_validation                     % writes results/*.csv
!python3 compare_with_python.py
```

## Expected behaviour
Verified in Simulink (R2025b) and against the Python replica:
- **LQR from (8, −5) cm**: within 5 mm of the centre in 1.95 s. Kx = [−33.5 −14.0 17.6 1.12 −10], Ky = [−33.5 −13.8 16.7 0.96 −10] (the β axis is lighter: it does not carry the inner gimbal frame).
- **Point-to-point move to (8, −5) cm** (default rate limiter): LQR 2.1 s with 7 % overshoot; cascade 1.75 s with 1 % overshoot. The camera latency costs damping: it is the main limit of this experiment.
- **Circle** (r = 6 cm, 0.2 Hz): LQR radius 5.75 cm (5.4–6.1); cascade 5.14 cm with a near-perfect round shape.
- **Camera frame rate**: the cascade barely notices it (1.73 / 1.75 / 1.77 s at 25 / 50 / 100 fps), while the LQR goes from 4.8 s with 19 % overshoot at 25 fps to 1.5 s at 100 fps. Each extra frame of latency roughly doubles the LQR settling time.
- **Tap** (0.28 N diagonal × 50 ms): ≈3.2 cm displacement; back within 2 mm in 1.6 s (cascade) or 3.0 s (LQR).
- **Open-loop instability**: with the plate tilted (−1°, 0.5°) the ball reaches the rim in 1.5 s.
