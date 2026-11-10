function res = FsaeDynoFullPlot(out)
%FsaeDynoFullPlot  Plot the HV precharge/discharge sequence of FsaeDynoFull
%   and check the timing requirements.
%
%   out = sim('FsaeDynoFull');
%   res = FsaeDynoFullPlot(out);   % out may also be the logsout Dataset

if nargin < 1, out = evalin('base','out'); end
evalin('base','FsaeDynoFullData;');
k_pre   = evalin('base','k_pre');   t_pre = evalin('base','t_pre');
V_dis   = evalin('base','V_dis');   t_dis = evalin('base','t_dis');
t_TSoff = evalin('base','t_TSoff');

if isa(out,'Simulink.SimulationData.Dataset'), L = out;
else, L = out.get('logsout_FsaeDynoFull'); end
side  = {'DUT','LOAD'};
label = {'BAMOCAR / EMRAX 228 (DUT)','YASA Si400 / P400R (load)'};
fig = figure('Name','FsaeDynoFull - HV precharge / discharge','Color','w', ...
             'Position',[100 100 1100 750]);
tl = tiledlayout(fig, 3, 2, 'TileSpacing','compact');
title(tl, 'FsaeDynoFull: precharge, dyno test and discharge');

for k = 1:2
    m  = L.get(['PDC_' side{k} '_meas']).Values;
    st = L.get(['PDC_' side{k} '_state']).Values;
    t  = m.Time;  Vb = m.Data(:,1);  Vdc = m.Data(:,2);  Ib = m.Data(:,3);

    % Precharge: first time Vdc >= k_pre*Vbatt
    iPre  = find(Vdc >= k_pre*Vb & Vb > 50, 1);
    tPre  = t(iPre);
    % Discharge: first time after TS off that Vdc <= V_dis
    iOff  = find(t >= t_TSoff, 1);
    iDis  = find(t >= t_TSoff & Vdc <= V_dis, 1);
    tDis  = t(iDis) - t_TSoff;
    res.(side{k}) = struct('t_precharge',tPre, 'V_at_AIRclose',Vdc(iPre), ...
        'Vbatt',Vb(iPre), 'V_at_TSoff',Vdc(iOff), 't_discharge',tDis, ...
        'precharge_ok', abs(tPre - t_pre) <= 0.02, 'discharge_ok', tDis <= t_dis);
    fprintf('%-28s precharge to %.0f%% of %.1f V: %.3f s (req %.1f s) | discharge %.1f V -> %.0f V: %.3f s (req %.1f s)\n', ...
        label{k}, 100*k_pre, Vb(iPre), tPre, t_pre, Vdc(iOff), V_dis, tDis, t_dis);

    ax = nexttile(tl, k);
    plot(ax, t, Vb, '--', t, Vdc, 'LineWidth',1.2); ylim(ax, [0 1.25*max(Vb)]); hold(ax,'on'); grid(ax,'on');
    yline(ax, V_dis, ':');
    plot(ax, tPre, Vdc(iPre), 'o', t(iDis), Vdc(iDis), 'o', 'LineWidth',1.5);
    text(ax, tPre+0.1, 0.6*Vb(iPre), sprintf('%.0f%% V_{batt} @ %.3f s', 100*k_pre, tPre));
    text(ax, t(iDis), V_dis, sprintf('%g V @ t_{off} + %.3f s  ', V_dis, tDis), ...
        'VerticalAlignment','bottom', 'HorizontalAlignment','right');
    xline(ax, t_TSoff, '-', 'TS off', 'LabelVerticalAlignment','bottom');
    title(ax, label{k}); ylabel(ax, 'Voltage [V]'); legend(ax, 'V_{batt}','V_{dc link}', 'Location','northeast');

    ax = nexttile(tl, k+2);
    plot(ax, t, Ib, 'LineWidth',1); grid(ax,'on');
    ylabel(ax, 'I_{batt} [A]'); title(ax, 'Accumulator current');

    ax = nexttile(tl, k+4);
    S = st.Data;
    stairs(ax, st.Time, S + (0:4)*1.5, 'LineWidth',1.2); grid(ax,'on');
    yticks(ax, (0:4)*1.5 + 0.5); yticklabels(ax, {'Precharge','AIR+','AIR-','Discharge','Inv enable'});
    ylim(ax, [-0.3 7.3]); xlabel(ax, 'Time [s]'); title(ax, 'Contactor / enable states');
end
linkaxes(findall(fig,'Type','axes'), 'x'); xlim(findall(fig,'Type','axes'), [0 t(end)]);
end
