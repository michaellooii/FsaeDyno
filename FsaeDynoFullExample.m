%% FSAE Electric Dyno with HV Precharge / Discharge Circuits
%
% This example extends FsaeDyno (EMRAX 228 on a Bamocar D3-400 driven against
% a YASA P400R on a YASA Si400) with the tractive-system HV circuits of both
% inverters. Each inverter is fed from its accumulator through a masked
% "Precharge / Discharge Circuit" subsystem built from
% PrechargeDischargeCircuit_BAMOCAR / PrechargeDischargeCircuit_YASA:
%
% * AIR+ and AIR- accumulator isolation contactors
% * Precharge relay with precharge resistor
% * Inverter-side discharge relay with discharge resistor, plus bleeder
% * Accumulator voltage, DC-link voltage and accumulator current sensing
% * Sequencer: TS_On -> close AIR- and precharge relay; when
%   Vdc >= 95 % of Vbatt close AIR+, open the precharge relay and enable the
%   inverter 50 ms later; TS_On = 0 -> open AIRs, close discharge relay.
%
% Requirements (both inverters), set in FsaeDynoFullData.m:
%
% * Precharge: DC link reaches 95 % of accumulator voltage in 1.0 s
% * Discharge: DC link falls to 60 V within 5.0 s of shutdown
%
% The precharge and discharge resistances are calculated from these
% requirements, the DC-link capacitance and the leakage paths, so they stay
% consistent if any of those are changed.
%
% Test sequence: 0 s TS on and precharge -> ~1.0 s AIR+ closes -> 1.2 s dyno
% torque/speed profile (the original FsaeDyno profile) -> torque and speed
% ramp to zero -> 2.7 s TS off and discharge -> 8.0 s end.

%% Model
open_system('FsaeDynoFull')

%% Simulate and check the precharge / discharge timing
% The scope Visualization/HV Precharge-Discharge shows the same signals live.
out = sim('FsaeDynoFull');
res = FsaeDynoFullPlot(out);
