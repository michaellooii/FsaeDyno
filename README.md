# FsaeDynoFull — FSAE Dyno with HV Precharge / Discharge Circuits

Simscape Electrical model of the FSAE electric-machine dynamometer
(EMRAX 228 on a Bamocar D3-400, driven against a YASA P400R on a YASA Si400)
featuring integrated precharge and discharge circuits in front of each inverter. 
A single simulation run covers the complete tractive-system lifecycle: 
**Precharge --> Dyno Test --> Shutdown --> Discharge**.

| Requirement (Both Inverters) | Result |
| :--- | :--- |
| **Precharge:** DC link reaches 95% of accumulator voltage in 1.0 s | 1.001 s |
| **Discharge:** DC link falls to 60 V within 5.0 s of shutdown | 5.000 s |

---

## Requirements

- MATLAB / Simulink R2026a
- Simscape, Simscape Electrical, Simscape Battery (Battery Block)

---

## Quick Start

1. Set your MATLAB **Current Folder** to `FsaeDynoFull`. 
   *(The model loads parameters automatically from `FsaeDynoFullData.m` in this directory).*
2. Run the example script from the MATLAB command window:

   FsaeDynoFullExample

   This opens the model, simulates for 8 seconds (approximately 7 minutes wall-clock time due to the 10 µs fixed-step switching inverters), plots the high-voltage sequence, and prints the measured precharge and discharge times:

   BAMOCAR / EMRAX 228 (DUT): precharge to 95% of 240.0 V in 1.001 s; discharge to 60 V in 5.000 s
   YASA Si400 / P400R (load): precharge to 95% of 400.0 V in 1.001 s; discharge to 60 V in 5.000 s

To open the model directly, run `open_system('FsaeDynoFull')` or double-click `FsaeDynoFull.slx`.

---

## Viewing Results

| View / Tool | Description |
| :--- | :--- |
| **Figure from `FsaeDynoFullPlot`** | Accumulator and DC-link voltages (with 95% and 60 V points marked), accumulator current, and contactor/enable states for both inverters. |
| **Scope (`Visualization/HV Precharge-Discharge`)** | Live signals displayed during simulation. |
| **Original Dyno Scopes (`Visualization`)** | Torque, speed, currents, and voltages of both machines. |
| **Simulation Data Inspector** | Logged signals: `PDC_DUT_meas`, `PDC_DUT_state`, `PDC_LOAD_meas`, `PDC_LOAD_state`, `TS_On`, and `ShaftSpeed`. |

`*_meas` format: `[Vbatt, Vdc, Ibatt]`
`*_state` format: `[Precharge relay, AIR+, AIR-, Discharge relay, Inverter enable]`

If you run the simulation manually (`out = sim('FsaeDynoFull')`), you can plot the results using:

```matlab
res = FsaeDynoFullPlot(out);   % res.DUT and res.LOAD hold the measured times
```

---

## Model Architecture & Component Locations

| Block Path / Name | Purpose |
| :--- | :--- |
| `TS Master Switch` (Top left) | Tractive-system on/off command (1 until `t_TSoff`, then 0). |
| `Precharge-Discharge (BAMOCAR)` (Orange, left) | Circuit between the 240 V accumulator and the Bamocar DC link. |
| `Precharge-Discharge (YASA)` (Orange, right) | Circuit between the 400 V accumulator and the YASA DC link. |
| `.../Sequencer` (Inside each block, press `Ctrl+U`) | Contactor and inverter-enable logic controller. |
| `Gate driver`, `Gate driver1` | PWM gates multiplied by the inverter-enable signal. |
| `Tq Request`, `Load Speed` | Test profiles built in `FsaeDynoFullData.m`. |

---

## Changing Parameters

Edit the HV section at the end of `FsaeDynoFullData.m` and re-run. 
*Note: Resistor values are automatically calculated from requirements, so modify the requirement parameters rather than hardcoding the resistor values.*

| Variable | Meaning | Default Value |
| :--- | :--- | :--- |
| `k_pre`, `t_pre` | Precharge threshold and required time | 0.95, 1.0 s |
| `V_dis`, `t_dis` | Discharge target voltage and required time | 60 V, 5.0 s |
| `Cdc_dut`, `Cdc_load` | DC-link capacitance (Bamocar / YASA) | 320 µF, 1000 µF |
| `R_stby_dut`, `R_stby_load` | Permanent bleeder resistor | 50 kΩ |
| `t_InvEnDelay` | Inverter enable delay after AIR+ closes | 50 ms |
| `t_test` | Start of the dyno torque/speed profile | 1.2 s |
| `t_TSoff` | Tractive-system shutdown time | 2.7 s |
| `t_stop` | Simulation stop time | 8.0 s |

**Calculated (read-only) results:** 
`R_pre_dut` ~ 754 Ohm, `R_pre_load` ~ 304 Ohm, `R_dis_dut` ~ 25.3 kOhm, `R_dis_load` ~3.02 kOhm.

To use fixed resistor values instead, double-click a precharge/discharge block and enter your values directly into its mask dialog.

---

## File Structure

| File Name | Purpose |
| :--- | :--- |
| `FsaeDynoFull.slx` | The main simulation model. |
| `FsaeDynoFullData.m` | Parameters, resistor calculations, and test profiles (runs automatically on load). |
| `FsaeDynoFullExample.m` | Script to open, simulate, and plot. |
| `FsaeDynoFullPlot.m` | Plots the HV sequence and validates timing requirements. |
| `buildFsaeDynoFull.m` | Regenerates `FsaeDynoFull.slx` from parent source models. |
| `docs/` | Description document and figures. |

*Warning:* Running `buildFsaeDynoFull` will **overwrite** `FsaeDynoFull.slx`. Only use it to regenerate the model after updating parent-folder source files; manual edits made directly to the `.slx` file will be lost.

---

## Troubleshooting

- **"Unrecognized function or variable"** on load/run: Ensure your MATLAB Current Folder is set to `FsaeDynoFull` so `FsaeDynoFullData.m` is found.
- **Simulation is slow:** Expected (~7 minutes for an 8-second simulation). For a quick preview of precharge behavior only, run: `sim('FsaeDynoFull', 'StopTime', '1.2')`.
- **Precharge/discharge time drifts after parameter changes:** Calculations include inverter off-state leakage and bleeder effects. If you modify the converter block's off conductances, remember to update `G_inv_off` in the data file.