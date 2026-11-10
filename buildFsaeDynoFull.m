function buildFsaeDynoFull()
%buildFsaeDynoFull  Build FsaeDynoFull.slx from ../FsaeDyno.slx and the two
%   precharge/discharge circuit models (../PrechargeDischargeCircuit_*.slx).
%
%   The parent-folder models are only read, never modified. Re-running this
%   script regenerates FsaeDynoFull.slx from scratch.

here = fileparts(mfilename('fullpath'));
src  = fileparts(here);
mdl  = 'FsaeDynoFull';

bdclose('all');
oldDir = cd(src);
cleanup = onCleanup(@() cd(oldDir));

% Load source models (FsaeDyno's PreLoadFcn needs FsaeDynoData in src)
load_system(fullfile(src,'FsaeDyno.slx'));
load_system(fullfile(src,'PrechargeDischargeCircuit_BAMOCAR.slx'));
load_system(fullfile(src,'PrechargeDischargeCircuit_YASA.slx'));

% Copy the dyno to the new folder under the new name
save_system('FsaeDyno', fullfile(here,[mdl '.slx']), 'OverwriteIfChangedOnDisk', true);
cd(here);
evalin('base','FsaeDynoFullData;');

set_param(mdl, 'PreLoadFcn','FsaeDynoFullData;', 'InitFcn','FsaeDynoFullData;', ...
    'StopTime','t_stop', 'ReturnWorkspaceOutputs','on', 'SignalLoggingName','logsout_FsaeDynoFull');

%% ---------------- DC-link capacitors and batteries -----------------------
set_param([mdl '/C'],  'c','Cdc_dut',  'c_unit','F', 'vc','0');   % DC links start discharged
set_param([mdl '/C1'], 'c','Cdc_load', 'c_unit','F', 'vc','0');
set_param([mdl '/HV  Battery'],  'R1','R1_batt');
set_param([mdl '/HV  Battery1'], 'R1','R1_batt');

%% ---------------- Profiles: Signal Editor -> From Workspace --------------
replaceWithFromWs(mdl, 'Load Speed', 'LoadSpeedProfile');
replaceWithFromWs(mdl, 'Tq Request', 'TqRequestProfile');

%% ---------------- Tractive-system master switch --------------------------
add_block('simulink/Sources/Step', [mdl '/TS Master Switch'], ...
    'Time','t_TSoff', 'Before','1', 'After','0', 'SampleTime','Ts', ...
    'Position',[-345 -270 -315 -240]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto TS_On'], ...
    'GotoTag','TS_On', 'TagVisibility','global', 'ShowName','off', 'Position',[-285 -263 -225 -247]);
add_line(mdl, 'TS Master Switch/1', 'Goto TS_On/1');
set_param(getOut([mdl '/TS Master Switch']), 'DataLogging','on', ...
    'DataLoggingNameMode','Custom', 'DataLoggingName','TS_On');

%% ---------------- Precharge / discharge subsystems -----------------------
pdcDut  = buildPDC(mdl, 'Precharge-Discharge (BAMOCAR)', 'PrechargeDischargeCircuit_BAMOCAR', ...
    'DUT',  {'R_pre_dut','R_dis_dut','R_stby_dut'},  [-245 -60 -135 70]);
pdcLoad = buildPDC(mdl, 'Precharge-Discharge (YASA)',    'PrechargeDischargeCircuit_YASA', ...
    'LOAD', {'R_pre_load','R_dis_load','R_stby_load'}, [790 -60 900 70]);
set_param(pdcLoad, 'Orientation','left');   % battery ports face the YASA battery

%% ---------------- Re-wire the DUT (Bamocar) DC side ----------------------
bat  = [mdl '/HV  Battery'];
ref  = [mdl '/Electrical Reference'];
C    = [mdl '/C'];
vs   = [mdl '/Sensing voltage1'];
inv  = [mdl '/IPMSM Converter'];
scfg = [mdl '/Solver Configuration'];
deletePhysLines({bat, ref, C, vs, scfg}, {inv,'RConn'});
set_param(bat, 'Position',[-345 -35 -285 25]);
set_param(ref, 'Position',[-325 65 -305 85]);
pb = ph(bat); pp = ph(pdcDut); pc = ph(C); pv = ph(vs); pv2 = ph(inv); ps = ph(scfg); pr = ph(ref);
L = @(a,b) add_line(mdl, a, b, 'autorouting','smart');
L(pb.LConn(1), pp.LConn(1));   % B+  -> circuit
L(pb.RConn(1), pp.LConn(2));   % B-  -> circuit
L(pr.LConn(1), pb.RConn(1));   % reference at accumulator minus
L(pp.RConn(1), pc.LConn(1));   % DC+ -> capacitor
L(pc.LConn(1), pv.LConn(1));
L(pv.LConn(1), pv2.RConn(1));   % DC+ -> converter
L(ps.RConn(1), pp.RConn(1));   % solver configuration on DC+
L(pp.RConn(2), pc.RConn(1));   % DC- -> capacitor
L(pc.RConn(1), pv.RConn(1));
L(pv.RConn(1), pv2.RConn(2));   % DC- -> converter

%% ---------------- Re-wire the load (YASA) DC side ------------------------
bat = [mdl '/HV  Battery1'];
ref = [mdl '/Electrical Reference2'];
C   = [mdl '/C1'];
vs  = [mdl '/Sensing voltage2'];
inv = [mdl '/Load machine  converter'];
deletePhysLines({bat, ref, C, vs}, {inv,'RConn'});
set_param(bat, 'Position',[955 -30 1015 30]);
set_param(ref, 'Position',[975 65 995 85]);
pb = ph(bat); pp = ph(pdcLoad); pc = ph(C); pv = ph(vs); pv2 = ph(inv); pr = ph(ref);
L(pb.LConn(1), pp.LConn(1));
L(pb.RConn(1), pp.LConn(2));
L(pr.LConn(1), pb.RConn(1));
L(pp.RConn(1), pc.LConn(1));
L(pc.LConn(1), pv.LConn(1));
L(pv.LConn(1), pv2.RConn(1));
L(pp.RConn(2), pc.RConn(1));
L(pc.RConn(1), pv.RConn(1));
L(pv.RConn(1), pv2.RConn(2));

%% ---------------- Inverter enable: gate the PWM signals ------------------
gateEnable([mdl '/Gate driver'],  'EN_DUT');
gateEnable([mdl '/Gate driver1'], 'EN_LOAD');

%% ---------------- Visualization ------------------------------------------
addHvScope([mdl '/Visualization']);

% Log shaft speed for the summary plot
set_param(getOut([mdl '/PS-S W2']), 'DataLogging','on', 'DataLoggingNameMode','Custom', ...
    'DataLoggingName','ShaftSpeed', 'DataLoggingDecimateData','on', 'DataLoggingDecimation','10');

%% ---------------- Annotation ---------------------------------------------
note = Simulink.Annotation([mdl '/HV sequence']);
note.Text = sprintf(['HV sequence (both inverters)\n' ...
    't = 0: TS on -> AIR- + precharge relay close, DC links charge through R_pre\n' ...
    'Vdc >= 95%% Vbatt (1.0 s): AIR+ closes, precharge relay opens; +50 ms: inverter enabled\n' ...
    't_test: dyno profile runs;  t_TSoff: AIRs open, discharge relay closes\n' ...
    'Vdc <= 60 V within 5.0 s.  Scope: Visualization/HV Precharge-Discharge']);
note.Position = [-345 -400 -45 -320];

Simulink.BlockDiagram.arrangeSystem([pdcDut '/Sequencer']);
Simulink.BlockDiagram.arrangeSystem([pdcLoad '/Sequencer']);
save_system(mdl);
fprintf('Saved %s\n', fullfile(here,[mdl '.slx']));
end

%% ======================================================================
function p = ph(b), p = get_param(b,'PortHandles'); end

function p = phc(b)
% Port handles; for a Connection Port block expose its single port as RConn(1)
p = get_param(b,'PortHandles');
if strcmp(get_param(b,'BlockType'),'PMIOPort')
    p.RConn = [p.LConn p.RConn];
end
end

function h = getOut(b), p = get_param(b,'PortHandles'); h = p.Outport(1); end

function replaceWithFromWs(mdl, name, var)
b   = [mdl '/' name];
pos = get_param(b,'Position');
lh  = get_param(b,'LineHandles');
dst = get_param(lh.Outport,'DstBlockHandle');
delete_line(lh.Outport);
delete_block(b);
add_block('simulink/Sources/From Workspace', b, 'VariableName',var, ...
    'SampleTime','0', 'Interpolate','on', 'OutputAfterFinalValue','Holding final value', ...
    'Position',pos);
add_line(mdl, [name '/1'], [get_param(dst,'Name') '/1']);
end

function deletePhysLines(blocks, extra)
% Delete every line attached to the given blocks' physical ports, plus the
% lines on the extra{2} ('RConn') side of block extra{1}.
hs = [];
for i = 1:numel(blocks)
    lh = get_param(blocks{i},'LineHandles');
    hs = [hs, lh.LConn, lh.RConn]; %#ok<AGROW>
end
lh = get_param(extra{1},'LineHandles');
hs = [hs, lh.(extra{2})];
hs = unique(hs(hs > 0));
for h = hs
    if ishandle(h), delete_line(h); end
end
end

function gateEnable(gd, tag)
% Insert  S -> double -> x Enable -> Demux  inside a Gate driver subsystem
dmx = find_system(gd,'SearchDepth',1,'BlockType','Demux'); dmx = dmx{1};
in  = find_system(gd,'SearchDepth',1,'BlockType','Inport');  in = in{1};
lh  = get_param(in,'LineHandles'); delete_line(lh.Outport);
p   = get_param(dmx,'Position');
add_block('simulink/Signal Attributes/Data Type Conversion', [gd '/To double'], ...
    'OutDataTypeStr','double', 'Position',[p(1)-170 p(2)+(p(4)-p(2))/2-10 p(1)-120 p(2)+(p(4)-p(2))/2+10]);
add_block('simulink/Math Operations/Product', [gd '/Inverter enable'], ...
    'Inputs','**', 'Position',[p(1)-80 p(2)+(p(4)-p(2))/2-15 p(1)-50 p(2)+(p(4)-p(2))/2+15]);
add_block('simulink/Signal Routing/From', [gd '/From ' tag], 'GotoTag',tag, ...
    'Position',[p(1)-170 p(2)+(p(4)-p(2))/2+30 p(1)-120 p(2)+(p(4)-p(2))/2+46]);
add_line(gd, [get_param(in,'Name') '/1'], 'To double/1', 'autorouting','smart');
add_line(gd, 'To double/1', 'Inverter enable/1', 'autorouting','smart');
add_line(gd, ['From ' tag '/1'], 'Inverter enable/2', 'autorouting','smart');
add_line(gd, 'Inverter enable/1', [get_param(dmx,'Name') '/1'], 'autorouting','smart');
end

function ss = buildPDC(mdl, name, srcMdl, tag, rVars, pos)
% Build one masked precharge/discharge circuit subsystem from the blocks of
% the stand-alone source model srcMdl.
ss = [mdl '/' name];
add_block('built-in/Subsystem', ss, 'Position',pos, 'BackgroundColor','orange');
s = @(n) [srcMdl '/' n];
d = @(n) [ss '/' n];

% Layout: power circuit in the lower part, sequencing logic and outputs on
% top. Signals between them use local Goto/From tags to keep wiring clear.
gt = @(n,tag,ps) add_block('simulink/Signal Routing/Goto', d(n), 'GotoTag',tag, ...
    'TagVisibility','local', 'ShowName','off', 'Position',ps);
fr = @(n,tag,ps) add_block('simulink/Signal Routing/From', d(n), 'GotoTag',tag, ...
    'ShowName','off', 'Position',ps);

% --- physical ports
addCP(d('B+'),  'Left',  '1', [20 245 50 265]);
addCP(d('B-'),  'Left',  '2', [20 485 50 505]);
addCP(d('DC+'), 'Right', '3', [960 245 990 265]);
addCP(d('DC-'), 'Right', '4', [960 485 990 505]);

% --- power components copied from the stand-alone circuit
add_block(s('Precharge contactor'), d('Precharge relay'),     'Position',[200 120 245 182]);
add_block(s('Precharge resistor'),  d('Precharge resistor'),  'Position',[300 136 340 164], 'R','Rpre', 'R_unit','Ohm');
add_block(s('Positive contactor'),  d('AIR+'),                'Position',[200 230 245 292]);
add_block(s('Negative contactor'),  d('AIR-'),                'Position',[200 470 245 532]);
add_block(s('Current Sensor'),      d('Current Sensor'),      'Position',[400 235 440 275]);
add_block(s('SPST Switch3'),        d('Discharge relay'),     'Position',[600 320 645 365]);
add_block(s('Discharge resistor'),  d('Discharge resistor'),  'Position',[650 395 690 425], 'R','Rdis', 'R_unit','Ohm', 'Orientation','down');
add_block(s('Standby resistor'),    d('Standby resistor'),    'Position',[770 350 810 380], 'R','Rstby', 'R_unit','Ohm', 'Orientation','down');
add_block(s('Voltage Sensor'),      d('Accumulator V sensor'),'Position',[90 340 130 380], 'Orientation','down');
add_block(s('Voltage Sensor1'),     d('DC-link V sensor'),    'Position',[860 340 900 380], 'Orientation','down');
cnm  = {'S-PS Pre','S-PS AIR+','S-PS AIR-','S-PS Dis'};
ctag = {'Pre','AIRp','AIRn','Dis'};
cpos = {[150 92 165 108],[150 202 165 218],[150 442 165 458],[550 302 565 318]};
for k = 1:4
    add_block(s('Simulink-PS Converter'), d(cnm{k}), 'Position',cpos{k}, ...
        'FilteringAndDerivatives','zero');
    fr(['From ' ctag{k} ' (cmd)'], ctag{k}, cpos{k} + [-75 0 -40 0]);
    add_line(ss, ['From ' ctag{k} ' (cmd)/1'], [cnm{k} '/1']);
end
add_block(s('PS-Simulink Converter'),  d('PS-S Vbatt'), 'Position',[160 400 175 416]);
add_block(s('PS-Simulink Converter1'), d('PS-S Vdc'),   'Position',[930 400 945 416]);
add_block(s('PS-Simulink Converter2'), d('PS-S Ibatt'), 'Position',[470 200 485 216]);
gt('Goto Vbatt', 'Vbatt', [195 400 245 416]);
gt('Goto Vdc',   'Vdc',   [960 400 1010 416]);
gt('Goto Ibatt', 'Ibatt', [505 200 555 216]);
add_line(ss, 'PS-S Vbatt/1', 'Goto Vbatt/1');
add_line(ss, 'PS-S Vdc/1',   'Goto Vdc/1');
add_line(ss, 'PS-S Ibatt/1', 'Goto Ibatt/1');

P = @(n) phc(d(n));
L = @(a,b) add_line(ss, a, b, 'autorouting','smart');
% accumulator side
L(P('B+').RConn(1),                P('Precharge relay').LConn(2));
L(P('Precharge relay').LConn(2),   P('AIR+').LConn(2));
L(P('B+').RConn(1),                P('Accumulator V sensor').LConn(1));
L(P('Precharge relay').RConn(1),   P('Precharge resistor').LConn(1));
L(P('B-').RConn(1),                P('AIR-').LConn(2));
L(P('B-').RConn(1),                P('Accumulator V sensor').RConn(2));
% HV+ path through current sensor to DC+
L(P('Precharge resistor').RConn(1),P('Current Sensor').LConn(1));
L(P('AIR+').RConn(1),              P('Current Sensor').LConn(1));
L(P('Current Sensor').RConn(2),    P('DC+').RConn(1));
L(P('AIR-').RConn(1),              P('DC-').RConn(1));
% inverter-side discharge, bleeder and DC-link sensor
L(P('Current Sensor').RConn(2),    P('Discharge relay').RConn(1));
L(P('Discharge relay').LConn(2),   P('Discharge resistor').LConn(1));
L(P('Discharge resistor').RConn(1),P('DC-').RConn(1));
L(P('Current Sensor').RConn(2),    P('Standby resistor').LConn(1));
L(P('Standby resistor').RConn(1),  P('DC-').RConn(1));
L(P('DC+').RConn(1),               P('DC-link V sensor').LConn(1));
L(P('DC-link V sensor').RConn(2),  P('DC-').RConn(1));
% sensors -> Simulink
L(P('Accumulator V sensor').RConn(1), P('PS-S Vbatt').LConn(1));
L(P('DC-link V sensor').RConn(1),     P('PS-S Vdc').LConn(1));
L(P('Current Sensor').RConn(1),       P('PS-S Ibatt').LConn(1));
% control -> contactors
L(P('S-PS Pre').RConn(1),  P('Precharge relay').LConn(1));
L(P('S-PS AIR+').RConn(1), P('AIR+').LConn(1));
L(P('S-PS AIR-').RConn(1), P('AIR-').LConn(1));
L(P('S-PS Dis').RConn(1),  P('Discharge relay').LConn(1));

% --- sequencing logic (top)
seq = d('Sequencer');
buildSequencer(seq, [170 -230 300 -50]);
add_block('simulink/Sources/In1', d('TS_On'), 'Position',[40 -207 70 -193]);
fr('From Vbatt (seq)', 'Vbatt', [20 -148 70 -132]);
fr('From Vdc (seq)',   'Vdc',   [20 -88 70 -72]);
add_line(ss, 'TS_On/1',           'Sequencer/1', 'autorouting','smart');
add_line(ss, 'From Vbatt (seq)/1','Sequencer/2', 'autorouting','smart');
add_line(ss, 'From Vdc (seq)/1',  'Sequencer/3', 'autorouting','smart');
stag = {'Pre','AIRp','AIRn','Dis','En'};
sp = get_param(seq,'PortHandles');
for k = 1:5
    y = get_param(sp.Outport(k),'Position'); y = y(2);
    gt(['Goto ' stag{k}], stag{k}, [340 y-8 390 y+8]);
    add_line(ss, sprintf('Sequencer/%d',k), ['Goto ' stag{k} '/1']);
end

% --- subsystem outputs (top right)
fr('From En (out)', 'En', [480 -258 530 -242]);
add_block('simulink/Sinks/Out1', d('Inv_Enable'), 'Position',[600 -257 630 -243]);
add_line(ss, 'From En (out)/1', 'Inv_Enable/1');
add_block('simulink/Signal Routing/Mux', d('Mux state'), 'Inputs','5', 'Position',[580 -215 585 -105]);
for k = 1:5
    fr(['From ' stag{k} ' (state)'], stag{k}, [480 -218+22*k 530 -202+22*k]);
    add_line(ss, ['From ' stag{k} ' (state)/1'], sprintf('Mux state/%d',k), 'autorouting','smart');
end
add_block('simulink/Sinks/Out1', d('State [Pre AIR+ AIR- Dis En]'), 'Position',[640 -167 670 -153], 'Port','3');
add_line(ss, 'Mux state/1', 'State [Pre AIR+ AIR- Dis En]/1');
add_block('simulink/Signal Routing/Mux', d('Mux meas'), 'Inputs','3', 'Position',[580 -80 585 -10]);
mtag = {'Vbatt','Vdc','Ibatt'};
for k = 1:3
    fr(['From ' mtag{k} ' (meas)'], mtag{k}, [480 -92+22*k 530 -76+22*k]);
    add_line(ss, ['From ' mtag{k} ' (meas)/1'], sprintf('Mux meas/%d',k), 'autorouting','smart');
end
add_block('simulink/Sinks/Out1', d('Meas [Vbatt Vdc Ibatt]'), 'Position',[640 -52 670 -38], 'Port','2');
add_line(ss, 'Mux meas/1', 'Meas [Vbatt Vdc Ibatt]/1');

% --- mask
mk = Simulink.Mask.create(ss);
mk.Type = 'Precharge / Discharge Circuit';
mk.Description = sprintf(['Accumulator isolation (AIR+, AIR-), precharge relay + resistor, ' ...
    'inverter-side discharge relay + resistor and bleeder, with the sequencing logic ' ...
    'from %s.\nTS_On = 1: precharge, close AIR+ at Vdc >= kpre*Vbatt, enable inverter ' ...
    'after tEnable.  TS_On = 0: open AIRs, close discharge relay.'], srcMdl);
mk.addParameter('Name','Rpre',     'Prompt','Precharge resistance [Ohm]',       'Value',rVars{1});
mk.addParameter('Name','Rdis',     'Prompt','Discharge resistance [Ohm]',       'Value',rVars{2});
mk.addParameter('Name','Rstby',    'Prompt','Standby (bleeder) resistance [Ohm]','Value',rVars{3});
mk.addParameter('Name','kpre',     'Prompt','Precharge-complete threshold [-]', 'Value','k_pre');
mk.addParameter('Name','tEnable',  'Prompt','Inverter enable delay after AIR+ [s]','Value','t_InvEnDelay');
mk.addParameter('Name','VbattMin', 'Prompt','Minimum valid accumulator voltage [V]','Value','VbattMin');
mk.Display = sprintf(['port_label(''LConn'',1,''B+''); port_label(''LConn'',2,''B-'');\n' ...
    'port_label(''RConn'',1,''DC+''); port_label(''RConn'',2,''DC-'');\n' ...
    'port_label(''input'',1,''TS\\_On''); port_label(''output'',1,''En'');\n' ...
    'port_label(''output'',2,''Meas''); port_label(''output'',3,''State'');']);

% --- top-level connections: TS_On in, Gotos out (names hidden: tag is shown)
x = pos(1); y = pos(2); yb = pos(4);
add_block('simulink/Signal Routing/From', [mdl '/From TS_On ' tag], 'GotoTag','TS_On', ...
    'ShowName','off', 'Position',[x y-45 x+50 y-29]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto EN_' tag],   'GotoTag',['EN_' tag], ...
    'ShowName','off', 'TagVisibility','global', 'Position',[x yb+40 x+70 yb+56]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto PDC_' tag '_meas'],  'GotoTag',['PDC_' tag '_meas'], ...
    'ShowName','off', 'TagVisibility','global', 'Position',[x yb+65 x+100 yb+81]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto PDC_' tag '_state'], 'GotoTag',['PDC_' tag '_state'], ...
    'ShowName','off', 'TagVisibility','global', 'Position',[x yb+90 x+100 yb+106]);
add_line(mdl, ['From TS_On ' tag '/1'], [name '/1'], 'autorouting','smart');
add_line(mdl, [name '/1'], ['Goto EN_' tag '/1'],        'autorouting','smart');
add_line(mdl, [name '/2'], ['Goto PDC_' tag '_meas/1'],  'autorouting','smart');
add_line(mdl, [name '/3'], ['Goto PDC_' tag '_state/1'], 'autorouting','smart');
p = get_param(ss,'PortHandles');
set_param(p.Outport(2), 'DataLogging','on', 'DataLoggingNameMode','Custom', ...
    'DataLoggingName',['PDC_' tag '_meas'],  'DataLoggingDecimateData','on', 'DataLoggingDecimation','10');
set_param(p.Outport(3), 'DataLogging','on', 'DataLoggingNameMode','Custom', ...
    'DataLoggingName',['PDC_' tag '_state'], 'DataLoggingDecimateData','on', 'DataLoggingDecimation','10');
end

function addCP(path, side, port, pos)
add_block('nesl_utility/Connection Port', path, 'Side',side, 'Port',port, 'Position',pos);
if strcmp(side,'Right'), set_param(path,'Orientation','left'); end
end

function buildSequencer(seq, pos)
% Inputs : 1 TS_On, 2 Vbatt, 3 Vdc
% Outputs: 1 Precharge relay, 2 AIR+, 3 AIR-, 4 Discharge relay, 5 Inverter enable
%   done  = TS_On & (done_prev | (Vdc >= kpre*Vbatt & Vbatt > VbattMin))
%   Pre   = TS_On & ~done          AIR+ = done          AIR- = TS_On
%   Dis   = ~TS_On                 En   = AIR+ & AIR+ delayed by tEnable
add_block('built-in/Subsystem', seq, 'Position',pos);
d = @(n) [seq '/' n];
add_block('simulink/Sources/In1', d('TS_On'), 'Port','1');
add_block('simulink/Sources/In1', d('Vbatt'), 'Port','2');
add_block('simulink/Sources/In1', d('Vdc'),   'Port','3');
% One-sample delay = controller sampling of the sensors (also breaks the
% algebraic loop sensor -> logic -> contactor -> network)
add_block('simulink/Discrete/Unit Delay', d('Sample Vbatt'), 'InitialCondition','0', 'SampleTime','Ts');
add_block('simulink/Discrete/Unit Delay', d('Sample Vdc'),   'InitialCondition','0', 'SampleTime','Ts');
add_block('simulink/Logic and Bit Operations/Compare To Constant', d('TS on'), 'relop','>', 'const','0.5');
add_block('simulink/Logic and Bit Operations/Compare To Constant', d('Vbatt valid'), 'relop','>', 'const','VbattMin');
add_block('simulink/Math Operations/Gain', d('kpre'), 'Gain','kpre');
add_block('simulink/Logic and Bit Operations/Relational Operator', d('Vdc >= kpre*Vbatt'), 'Operator','>=');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('Reached'),   'Operator','AND', 'Inputs','2');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('Set or hold'),'Operator','OR', 'Inputs','2');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('Precharged'),'Operator','AND', 'Inputs','2');
add_block('simulink/Discrete/Memory', d('Latch'), 'InitialCondition','0');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('NOT done'), 'Operator','NOT');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('Pre'),      'Operator','AND', 'Inputs','2');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('NOT TS'),   'Operator','NOT');
add_block('simulink/Discrete/Delay', d('Enable delay'), 'DelayLength','max(1,round(tEnable/Ts))', ...
    'InitialCondition','0', 'SampleTime','Ts');
add_block('simulink/Logic and Bit Operations/Logical Operator', d('En'), 'Operator','AND', 'Inputs','2');
on = {'Precharge_relay','AIR_pos','AIR_neg','Discharge_relay','Inv_Enable'};
for k = 1:5
    add_block('simulink/Signal Attributes/Data Type Conversion', d(['dbl' num2str(k)]), 'OutDataTypeStr','double');
    add_block('simulink/Sinks/Out1', d(on{k}), 'Port',num2str(k));
    add_line(seq, ['dbl' num2str(k) '/1'], [on{k} '/1']);
end
a = @(x,y) add_line(seq, x, y);
a('TS_On/1','TS on/1');
a('Vbatt/1','Sample Vbatt/1');
a('Vdc/1','Sample Vdc/1');
a('Sample Vbatt/1','kpre/1');
a('Sample Vbatt/1','Vbatt valid/1');
a('Sample Vdc/1','Vdc >= kpre*Vbatt/1');
a('kpre/1','Vdc >= kpre*Vbatt/2');
a('Vdc >= kpre*Vbatt/1','Reached/1');
a('Vbatt valid/1','Reached/2');
a('Reached/1','Set or hold/1');
a('Latch/1','Set or hold/2');
a('TS on/1','Precharged/1');
a('Set or hold/1','Precharged/2');
a('Precharged/1','Latch/1');
a('Precharged/1','NOT done/1');
a('TS on/1','Pre/1');
a('NOT done/1','Pre/2');
a('TS on/1','NOT TS/1');
a('Precharged/1','Enable delay/1');
a('Precharged/1','En/1');
a('Enable delay/1','En/2');
a('Pre/1','dbl1/1');
a('Precharged/1','dbl2/1');
a('TS on/1','dbl3/1');
a('NOT TS/1','dbl4/1');
a('En/1','dbl5/1');
end

function addHvScope(vis)
x = 900; y = 50;
tags = {'TS_On','PDC_DUT_meas','PDC_DUT_state','PDC_LOAD_meas','PDC_LOAD_state'};
for k = 1:numel(tags)
    add_block('simulink/Signal Routing/From', [vis '/From ' tags{k}], 'GotoTag',tags{k}, ...
        'Position',[x y+40*(k-1) x+90 y+40*(k-1)+16]);
end
sc = [vis '/HV Precharge-Discharge'];
add_block('simulink/Sinks/Scope', sc, 'Position',[x+160 y-10 x+220 y+190]);
cfg = get_param(sc,'ScopeConfiguration');
cfg.NumInputPorts   = '5';
cfg.LayoutDimensions = [5 1];
cfg.TimeSpan        = 't_stop';
cfg.ShowLegend      = true;
for k = 1:numel(tags)
    add_line(vis, ['From ' tags{k} '/1'], sprintf('HV Precharge-Discharge/%d',k), 'autorouting','smart');
end
end
