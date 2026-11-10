%% Parameters for FsaeDynoFull (FSAE dyno + HV precharge/discharge circuits)
%  Sections up to "Mechanical / coupling" are identical to ../FsaeDynoData.m,
%  except the DC-link capacitance, which is set in the HV section at the end.
%  Machine under test (DUT) : EMRAX 228, LV+100% winding, driven by Unitek Bamocar D3-400
%  Load machine            : YASA P400R, driven by YASA Si400 inverter
%
%  Sources:
%   EMRAX 228 datasheet v1.7 (LV+100% column): Rs = 5.31 mOhm, Ld/Lq = 40.8/42 uH,
%     psi_PM = 0.03095 Vs, 10 pole pairs, peak torque 220 Nm, 124 kW peak, 6500 rpm
%   Bamocar D3-400: 24..400 V DC supply, 200 A continuous / 400 A peak power stage
%   YASA 400 product sheet: 360 Nm peak @ 450 Arms, 250 Nm cont., 0..7500 rpm,
%     90 kW peak @ 400 V DC
%  YASA does not publish pole pairs / flux linkage; see the ASSUMPTION notes below.

%% ======================= DUT: EMRAX 228 (LV+100%) ======================
p    = 10;          % Number of pole pairs                       [-]
Rs   = 5.31e-3;     % Stator resistance per phase                [Ohm]
Ld   = 40.8e-6;     % Stator d-axis inductance                   [H]
Lq   = 42.0e-6;     % Stator q-axis inductance                   [H]
L0   = Ld;          % Stator zero-sequence inductance            [H]
psim = 0.03095;     % Permanent magnet flux linkage              [Wb]
J_emrax = 0.0398;   % Rotor inertia (lumped into Jm below)       [kg*m^2]

%% =================== DUT inverter: Bamocar D3-400 =======================
Imax_dut = 400;     % Inverter peak current (treated as peak amplitude) [A]
Vnom = 240;         % Nominal DC-link voltage (Bamocar max 400 V)       [V]
V1   = 0.92*Vnom;   % Battery voltage at charge AH1 (must be < Vnom)    [V]
Cdc  = 1e-3;        % (overridden by Cdc_dut / Cdc_load in the HV section)  [F]

% Torque limit = min(motor peak torque, torque at inverter current limit)
Tmax = min(220, 1.5*p*psim*Imax_dut);              % [N*m]  (~186 Nm)
% Power limit = min(motor peak power, inverter voltage x current limit)
Pmax = min(124e3, 1.5*(Vnom/sqrt(3))*Imax_dut);    % [W]

%% ======================== Sample times ==================================
Ts   = 1e-5;        % Fundamental / Simscape local solver sample time [s]
fsw  = 8e3;         % Bamocar PWM switching frequency                 [Hz]
Tsi  = 1e-4;        % DUT current-loop sample time (100 us task)      [s]

%% ================= DUT current controllers (pole/zero cancel) ==========
% PI (parallel form) Kp = L*wc, Ki = R*wc  ->  zero cancels the R/L pole.
% Bandwidth fsw/20 keeps wc*Tsi ~ 0.25 (stable with the 1.5-sample delay).
wc_dut = 2*pi*(fsw/20);
Kp_id = Ld*wc_dut;
Ki_id = Rs*wc_dut;
Kp_iq = Lq*wc_dut;
Ki_iq = Rs*wc_dut;

% Zero-cancellation transfer functions (kept for compatibility)
numd_id = Tsi/(Kp_id/Ki_id);
dend_id = [1 (Tsi-(Kp_id/Ki_id))/(Kp_id/Ki_id)];
numd_iq = Tsi/(Kp_iq/Ki_iq);
dend_iq = [1 (Tsi-(Kp_iq/Ki_iq))/(Kp_iq/Ki_iq)];

%% ====== DUT current-reference tables (generated automatically) ==========
% The PMSM Current Reference Generator is set to "Automatically generated
% lookup-table": it builds MTPA / field-weakening id-iq maps for the EMRAX
% from p, psim, Ld, Lq, Rs over these breakpoints. (The old
% IPMSM35kWCurrentReferences.mat maps belong to the original 35 kW IPMSM and
% must not be used with the EMRAX.)
% Every grid point must be reachable: with a 240 V bus the EMRAX cannot
% produce full torque far above ~3000 rpm, so the grid is limited to the
% test-profile range (load speed <= 2350 rpm). Widen RPM_VECT only together
% with a higher Vnom.
RPM_VECT = 0:250:3000;                         % [rpm]
TQ_VECT  = linspace(-Tmax, Tmax, 37);          % [N*m]
VDC_VECT = Vnom*[0.9 1.0 1.1];                 % [V]

%% ===================== Load machine: YASA P400R ========================
p_y    = 10;        % Pole pairs  -- ASSUMPTION (not published by YASA)
Rs_y   = 0.015;     % Phase resistance -- ASSUMPTION (user estimate)  [Ohm]
Ld_y   = 65e-6;     % d-axis inductance -- ASSUMPTION (user estimate) [H]
Lq_y   = 65e-6;     % q-axis inductance (axial-flux SPM: Ld = Lq)      [H]
% Flux linkage derived from the published torque constant:
% 360 Nm @ 450 Arms -> Kt = 0.8 Nm/Arms = 0.566 Nm/A(peak) = 1.5*p_y*psim_y
Kt_y   = 360/(450*sqrt(2));                    % [N*m/A peak]
psim_y = Kt_y/(1.5*p_y);                       % [Wb]
Tmax_y = 360;       % Peak torque                                   [N*m]
Pmax_y = 90e3;      % Peak power at 400 V DC                         [W]

%% ==================== Load inverter: YASA Si400 ========================
Vnom2 = 400;        % Load-side DC bus voltage                       [V]
V1_2  = 0.92*Vnom2; % Battery voltage at charge AH1 (must be < Vnom2) [V]
fsw2  = 10e3;       % Si400 PWM switching frequency                  [Hz]
Tsc   = 1e-4;       % Load-machine control sample time (multiple of Ts) [s]

% Current PI gains (pole/zero cancellation, bandwidth fsw2/20)
wc_load = 2*pi*(fsw2/20);
Kp_ids = Ld_y*wc_load;
Ki_ids = Rs_y*wc_load;
Kp_iqs = Lq_y*wc_load;
Ki_iqs = Rs_y*wc_load;

%% ==================== Mechanical / coupling ============================
Jm = 0.15;          % Combined shaft inertia (EMRAX + YASA + coupling) [kg*m^2]
% The "Elastic Coupling" blocks are rotational dampers that transmit the
% torque between the machines: T = ce*dw. ce must be large, otherwise the
% DUT (which has no inertia of its own) is not held by the load machine.
% Two dampers are in series (effective ce/2): 220 Nm -> ~4.4 rad/s slip.
ce = 100;           % Coupling damping coefficient          [N*m/(rad/s)]

% Load speed controller (velocity mode of PMSM FOC block, mechanical rad/s)
wbw_speed = 2*pi*15;                 % Speed-loop bandwidth          [rad/s]
Kp_wr  = Jm*wbw_speed;               % [N*m/(rad/s)]
Ki_wr  = Kp_wr*wbw_speed/4;          % [N*m/rad]
Kaw_wr = Ki_wr/Kp_wr;                % Anti-windup back-calculation gain

%% ============== HV system: accumulators, DC links, precharge/discharge ==============
% Both inverters get their own precharge/discharge circuit (the
% PrechargeDischargeCircuit_BAMOCAR / _YASA models built into the dyno as masked
% subsystems). Requirements for both circuits:
%   precharge : DC link reaches k_pre = 95 % of the accumulator voltage
%               t_pre = 1.0 s after the tractive system is switched on
%   discharge : DC link falls to V_dis = 60 V within t_dis = 5.0 s after shutdown
% The resistor values below are calculated from these numbers, so they stay
% correct if you change a capacitance, a bleed path or the battery state.

k_pre = 0.95;       % Precharge-complete threshold (fraction of accumulator V) [-]
t_pre = 1.0;        % Required precharge time to k_pre                         [s]
V_dis = 60;         % Discharge safe-voltage target                            [V]
t_dis = 5.0;        % Required discharge time to V_dis                         [s]
t_InvEnDelay = 0.05;% Delay from AIR+ closed to inverter enable (as in source)  [s]
VbattMin = 50;      % Ignore precharge-complete until accumulator V is valid    [V]

% DC-link capacitance (the "Standby capacitor" from the source circuits)
Cdc_dut  = 320e-6;  % Bamocar D3-400 DC link                                    [F]
Cdc_load = 1000e-6; % YASA Si400 DC link                                        [F]
Cdc      = Cdc_dut; % Kept for compatibility with FsaeDynoData naming

% Standby (bleeder) resistor permanently across each DC link (source circuits)
R_stby_dut  = 50e3; % [Ohm]
R_stby_load = 50e3; % [Ohm]

% Contactor / relay models (SPST Switch blocks copied from the source circuits)
R_AIR    = 0.0003;  % Closed resistance of AIR+/AIR-/precharge relay           [Ohm]
G_AIRoff = 1e-6;    % Open conductance of the contactors                       [S]
R_disRly = 0.01;    % Closed resistance of the discharge relay                 [Ohm]
G_disRlyOff = 1e-6; % Open conductance of the discharge relay                  [S]

% Off-state leakage of a gated-off three-phase converter (Converter block:
% IGBT Goff = diode Goff = 1e-5 S per switch). Upper and lower halves are in
% series: 3 legs * (2*1e-5) in series with 3 legs * (2*1e-5) -> 3e-5 S.
G_inv_off = (3*2e-5)/2;  % [S]

% Accumulators: the dyno's battery blocks use infinite capacity, so their
% terminal voltage is Vnom / Vnom2 (verified in simulation: 240.0 V / 400.0 V).
Vbatt_dut  = Vnom;    % [V]
Vbatt_load = Vnom2;   % [V]
R1_batt    = 0.001;                                        % Battery series R [Ohm]

% ---- Precharge resistor: solve V(t_pre) = k_pre*Vbatt for an RC with leakage
%      V(t) = Vb*Gp/(Gp+Gl) * (1 - exp(-t*(Gp+Gl)/C))
G_leak_dut  = 1/R_stby_dut  + G_inv_off;
G_leak_load = 1/R_stby_load + G_inv_off;
preErr = @(R,C,Gl) (1/(R+2*R_AIR+R1_batt) + G_AIRoff) ./ ...
    ((1/(R+2*R_AIR+R1_batt) + G_AIRoff) + Gl) .* ...
    (1 - exp(-t_pre*((1/(R+2*R_AIR+R1_batt) + G_AIRoff) + Gl)/C)) - k_pre;
% During precharge the open discharge relay adds ~G_disRlyOff of leakage.
R_pre_dut  = fzero(@(R) preErr(R, Cdc_dut,  G_leak_dut  + G_disRlyOff), [1 1e5]);  % ~754 Ohm
R_pre_load = fzero(@(R) preErr(R, Cdc_load, G_leak_load + G_disRlyOff), [1 1e5]);  % ~304 Ohm

% ---- Discharge resistor. After shutdown the accumulator still feeds the DC
%      link through the open AIRs (AIR+ || precharge relay, in series with AIR-):
%      G_inj = 1/(1/(2*G_AIRoff) + 1/G_AIRoff). With G = Gdis + Gleak:
%      V(t) = Vi + (V0 - Vi)*exp(-t*(G+G_inj)/C),  Vi = Vb*G_inj/(G+G_inj)
G_inj  = 1/(1/(2*G_AIRoff) + 1/G_AIRoff);
disErr = @(Gd,C,Gl,Vb) Vb*G_inj/(Gd+Gl+G_inj) + (Vb - Vb*G_inj/(Gd+Gl+G_inj)) .* ...
    exp(-t_dis*(Gd+Gl+G_inj)/C) - V_dis;
assert(disErr(0, Cdc_dut, G_leak_dut, Vbatt_dut) > 0 && ...
       disErr(0, Cdc_load, G_leak_load, Vbatt_load) > 0, ...
    'Leakage alone already discharges the DC link faster than t_dis.');
G_dis_dut  = fzero(@(G) disErr(G, Cdc_dut,  G_leak_dut,  Vbatt_dut),  [0 1]);
G_dis_load = fzero(@(G) disErr(G, Cdc_load, G_leak_load, Vbatt_load), [0 1]);
R_dis_dut  = 1/G_dis_dut  - R_disRly;   % ~25.4 kOhm
R_dis_load = 1/G_dis_load - R_disRly;   % ~3.03 kOhm

%% ======================== Test sequence timing ==========================
%  0            : tractive system on -> both circuits precharge
%  ~t_pre       : AIR+ closes, precharge relay opens
%  +t_InvEnDelay: inverters enabled (gate signals released)
%  t_test       : dyno torque/speed profile starts (original 0.8 s profile)
%  t_test+0.8   : torque ramps to 0, then load speed ramps to 0
%  t_TSoff      : tractive system off -> AIRs open, discharge relays close
%  t_TSoff+t_dis: both DC links must be <= V_dis
t_test  = 1.2;                       % [s]
t_TSoff = t_test + 0.8 + 0.7;        % [s]  (= 2.7 s)
t_stop  = t_TSoff + t_dis + 0.3;     % [s]  (= 8.0 s)

% Original FsaeDyno profiles (from FsaeDynoLoadSpeed.mat / FsaeDynoTorqueRequest.mat)
spd_t = [0 0.1 0.2 0.6 0.6 0.644 0.8];
spd_v = [0 0   1000 1000 1010 2350 2350];                      % [rpm]
tq_t  = [0 0.11 0.11 0.23 0.23 0.318 0.318 0.42 0.42 0.565 0.565 0.704 0.704 0.8];
tq_v  = [0 0 100 100 150 150 205 205 60.5 60.5 -56 -56 -155 -155]; % [N*m]
% Shift by t_test, then torque -> 0 in 0.1 s and speed -> 0 in 0.4 s
tq_t  = [0, t_test + tq_t,  t_test+0.9, t_stop];
tq_v  = [0, tq_v,           0,          0];
spd_t = [0, t_test + spd_t, t_test+0.9, t_test+1.3, t_stop];
spd_v = [0, spd_v,          2350,       0,          0];
LoadSpeedProfile = timeseries(spd_v(:), spd_t(:), 'Name', 'LoadSpeed');
TqRequestProfile = timeseries(tq_v(:),  tq_t(:),  'Name', 'TqRequest');
clear preErr disErr
