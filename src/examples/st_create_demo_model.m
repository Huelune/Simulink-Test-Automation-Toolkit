function demo = st_create_demo_model(destination)
%ST_CREATE_DEMO_MODEL Generate a redistributable demo model, inputs and Excel.
% The model exercises the toolkit end to end and every name in it is made
% up, so its harnesses, reports and final document can be shown anywhere.
% Seven CUTs cover every branch family the specification and the final
% document print: If/elseif, Switch, decision-split blocks (Saturate,
% DeadZone, RateLimiter, Relay, Delay, Discrete-Time Integrator), SELECT and
% CASE blocks, an Enabled CUT, a function-call CUT and a filtered parent.
%
% Five CUTs read Dataset MAT files (FILE+MAT). Some of their scenarios avoid
% a branch on purpose, so the final document shows [T], [F], [T/F] and [-]
% rather than a wall of [T/F]. The Enabled and the function-call CUT use
% SldvMode=GENERATE, so the SLDV path and the FcnTriggerPort exclusion run
% too. Nothing is executed here; see docs/reference/example.md.
cfg = struct('ConsoleLogLevel','INFO');
st_log(cfg,'INFO','Demo model generation start');
model = 'ST_DemoModel';
try
destination = st_absolute_path(destination);
if bdIsLoaded(model)
    error('simtest:DemoModelLoaded','Close %s yourself before generating the demo.',model);
end
if isfolder(destination)
    files = dir(destination);
    if any(~ismember({files.name},{'.','..'}))
        error('simtest:DemoDestinationNotEmpty','Choose a new or empty destination.');
    end
else
    mkdir(destination);
end
inputDir = fullfile(destination,'inputs');
mkdir(inputDir);
guard = onCleanup(@() close_if_loaded(model)); %#ok<NASGU>
    new_system(model);
    set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
        'FixedStep','0.01','StopTime','0.1');
    builders = {@build_mode_select,@build_limit_chain,@build_state_keeper, ...
        @build_gear_select,@build_enabled_stage,@build_triggered_stage, ...
        @build_filtered_parent};
    top = 40;
    for i = 1:numel(builders)
        [cut,cutHeight] = builders{i}(model,top);
        wire_root(model,cut);
        st_log(cfg,'DEBUG','Demo CUT built | %d/%d | CUT=%s',i,numel(builders),cut);
        top = top + cutHeight + 60;
    end
    modelFile = fullfile(destination,[model '.slx']);
    st_log(cfg,'INFO','Demo model save start | File=%s',modelFile);
    save_system(model,modelFile);
    close_system(model,0);
    st_log(cfg,'INFO','Demo model save complete');

    inputs = write_inputs(inputDir);
    targets = target_table(model,inputs);
    management = fullfile(destination,'TestManagement.demo.xlsx');
    st_log(cfg,'INFO','Demo workbook write start | File=%s',management);
    writetable(targets,management,'Sheet','Targets');
    st_log(cfg,'INFO','Demo workbook write complete | Rows=%d',height(targets));
    demo = struct('Root',destination,'TopModel',model,'ModelFile',modelFile, ...
        'ManagementExcel',management,'InputFolder',inputDir, ...
        'Targets',targets,'OutputRoot',fullfile(destination,'result'));
    st_log(cfg,'INFO','Demo model generation complete | Root=%s | CUTs=%d | No tests executed', ...
        destination,height(targets));
catch ME
    st_log(cfg,'ERROR','Demo model generation failed | Partial files retained in %s | %s', ...
        destination,ME.message);
    rethrow(ME);
end
end

% ---------------------------------------------------------------- CUTs

function [cut,h] = build_mode_select(model,top)
% If with one elseif and an else, then a Switch: three D lines from the If
% (if, elseif) and one from the Switch.
h = 120;
cut = add_plain_cut(model,'ModeSelect',top,h);
add_block('simulink/Sources/In1',[cut '/level'],'Position',[30 63 60 77]);
add_block('simulink/Sources/In1',[cut '/override'],'Position',[30 213 60 227]);
add_block('simulink/Ports & Subsystems/If',[cut '/ModeIf'], ...
    'NumInputs','1','IfExpression','u1 > 50','ElseIfExpressions','u1 > 20', ...
    'ShowElse','on','Position',[110 40 190 120]);
names = {'High','Mid','Low'}; gains = {'3','2','1'};
for k = 1:3
    y = 20 + 60*(k-1);
    action = [cut '/' names{k}];
    add_block('simulink/Ports & Subsystems/If Action Subsystem',action, ...
        'Position',[250 y 330 y+40]);
    gain_inside(action,gains{k});
    add_line(cut,sprintf('ModeIf/%d',k),[names{k} '/Ifaction'],'autorouting','on');
    add_line(cut,'level/1',[names{k} '/1'],'autorouting','on');
end
add_block('simulink/Signal Routing/Merge',[cut '/ModeMerge'], ...
    'Inputs','3','InitialOutput','0','Position',[380 30 410 170]);
for k = 1:3
    add_line(cut,[names{k} '/1'],sprintf('ModeMerge/%d',k),'autorouting','on');
end
add_block('simulink/Sources/Constant',[cut '/manual'],'Value','0', ...
    'Position',[400 193 430 207]);
add_block('simulink/Signal Routing/Switch',[cut '/OverrideSwitch'], ...
    'Criteria','u2 > Threshold','Threshold','0.5','Position',[480 150 530 230]);
add_line(cut,'manual/1','OverrideSwitch/1','autorouting','on');
add_line(cut,'override/1','OverrideSwitch/2','autorouting','on');
add_line(cut,'ModeMerge/1','OverrideSwitch/3','autorouting','on');
add_block('simulink/Sinks/Out1',[cut '/mode'],'Position',[580 183 610 197]);
add_line(cut,'OverrideSwitch/1','mode/1','autorouting','on');
end

function [cut,h] = build_limit_chain(model,top)
% Blocks Simulink Coverage splits into several decisions: Saturate and
% DeadZone (lower, upper) and RateLimiter (falling, rising). Abs and MinMax
% are single-decision implicit branches.
h = 100;
cut = add_plain_cut(model,'LimitChain',top,h);
add_block('simulink/Sources/In1',[cut '/u'],'Position',[30 103 60 117]);
add_block('simulink/Discontinuities/Saturation',[cut '/Clamp'], ...
    'UpperLimit','50','LowerLimit','-50','Position',[120 30 160 70]);
add_block('simulink/Discontinuities/Rate Limiter',[cut '/Slew'], ...
    'RisingSlewLimit','1000','FallingSlewLimit','-1000','Position',[120 130 160 170]);
add_block('simulink/Discontinuities/Dead Zone',[cut '/Band'], ...
    'LowerValue','-5','UpperValue','5','Position',[200 130 240 170]);
add_block('simulink/Math Operations/Abs',[cut '/Magnitude'], ...
    'Position',[280 135 310 165]);
add_block('simulink/Sources/Constant',[cut '/floor'],'Value','20', ...
    'Position',[280 193 310 207]);
add_block('simulink/Math Operations/MinMax',[cut '/AtLeastFloor'], ...
    'Function','max','Inputs','2','Position',[350 140 380 200]);
add_block('simulink/Sinks/Out1',[cut '/limited'],'Position',[440 43 470 57]);
add_block('simulink/Sinks/Out1',[cut '/shaped'],'Position',[440 163 470 177]);
add_line(cut,'u/1','Clamp/1','autorouting','on');
add_line(cut,'Clamp/1','limited/1','autorouting','on');
add_line(cut,'u/1','Slew/1','autorouting','on');
add_line(cut,'Slew/1','Band/1','autorouting','on');
add_line(cut,'Band/1','Magnitude/1','autorouting','on');
add_line(cut,'Magnitude/1','AtLeastFloor/1','autorouting','on');
add_line(cut,'floor/1','AtLeastFloor/2','autorouting','on');
add_line(cut,'AtLeastFloor/1','shaped/1','autorouting','on');
end

function [cut,h] = build_state_keeper(model,top)
% Stateful blocks whose decisions are named Enable and Reset, plus a Relay.
h = 140;
cut = add_plain_cut(model,'StateKeeper',top,h);
add_block('simulink/Sources/In1',[cut '/u'],'Position',[30 63 60 77]);
add_block('simulink/Sources/In1',[cut '/hold'],'Position',[30 143 60 157]);
add_block('simulink/Sources/In1',[cut '/reset'],'Position',[30 223 60 237]);
% Delay ports with an enable port and an external reset: u, enable, reset.
add_block('simulink/Discrete/Delay',[cut '/HoldDelay'], ...
    'DelayLength','1','ShowEnablePort','on','ExternalReset','Rising', ...
    'Position',[150 40 210 120]);
add_line(cut,'u/1','HoldDelay/1','autorouting','on');
add_line(cut,'hold/1','HoldDelay/2','autorouting','on');
add_line(cut,'reset/1','HoldDelay/3','autorouting','on');
% gainval 100 makes one step of |u| = 2 move the state by 2, so the +-3
% limits are reached within a ten-step scenario.
add_block('simulink/Discrete/Discrete-Time Integrator',[cut '/Accumulator'], ...
    'gainval','100','ExternalReset','rising','LimitOutput','on', ...
    'UpperSaturationLimit','3','LowerSaturationLimit','-3', ...
    'Position',[150 160 210 220]);
add_line(cut,'u/1','Accumulator/1','autorouting','on');
add_line(cut,'reset/1','Accumulator/2','autorouting','on');
add_block('simulink/Discontinuities/Relay',[cut '/Hysteresis'], ...
    'OnSwitchValue','0.5','OffSwitchValue','-0.5', ...
    'OnOutputValue','1','OffOutputValue','0','Position',[150 250 210 290]);
add_line(cut,'u/1','Hysteresis/1','autorouting','on');
add_block('simulink/Sinks/Out1',[cut '/delayed'],'Position',[280 73 310 87]);
add_block('simulink/Sinks/Out1',[cut '/accumulated'],'Position',[280 183 310 197]);
add_block('simulink/Sinks/Out1',[cut '/active'],'Position',[280 263 310 277]);
add_line(cut,'HoldDelay/1','delayed/1','autorouting','on');
add_line(cut,'Accumulator/1','accumulated/1','autorouting','on');
add_line(cut,'Hysteresis/1','active/1','autorouting','on');
end

function [cut,h] = build_gear_select(model,top)
% SELECT and CASE outcomes: Multiport Switch and Switch Case with a default.
h = 100;
cut = add_plain_cut(model,'GearSelect',top,h);
add_block('simulink/Sources/In1',[cut '/gear'],'Position',[30 43 60 57]);
add_block('simulink/Sources/In1',[cut '/u'],'Position',[30 143 60 157]);
gains = {'1','2','3'};
for k = 1:3
    y = 110 + 40*(k-1);
    add_block('simulink/Math Operations/Gain',[cut sprintf('/Ratio%d',k)], ...
        'Gain',gains{k},'Position',[110 y 140 y+30]);
    add_line(cut,'u/1',sprintf('Ratio%d/1',k),'autorouting','on');
end
add_block('simulink/Signal Routing/Multiport Switch',[cut '/RatioSelect'], ...
    'Inputs','3','DataPortOrder','One-based contiguous', ...
    'Position',[200 40 240 230]);
add_line(cut,'gear/1','RatioSelect/1','autorouting','on');
for k = 1:3
    add_line(cut,sprintf('Ratio%d/1',k),sprintf('RatioSelect/%d',k+1),'autorouting','on');
end
add_block('simulink/Ports & Subsystems/Switch Case',[cut '/GearCase'], ...
    'CaseConditions','{1, 2}','ShowDefaultCase','on','Position',[110 260 190 340]);
add_line(cut,'gear/1','GearCase/1','autorouting','on');
names = {'Low','Second','Other'}; values = {'10','20','30'};
add_block('simulink/Signal Routing/Merge',[cut '/LimitMerge'], ...
    'Inputs','3','InitialOutput','0','Position',[380 250 410 370]);
for k = 1:3
    y = 250 + 45*(k-1);
    action = [cut '/' names{k}];
    add_block('simulink/Ports & Subsystems/Switch Case Action Subsystem',action, ...
        'Position',[250 y 320 y+35]);
    gain_inside(action,values{k});
    add_line(cut,sprintf('GearCase/%d',k),[names{k} '/Ifaction'],'autorouting','on');
    add_line(cut,'u/1',[names{k} '/1'],'autorouting','on');
    add_line(cut,[names{k} '/1'],sprintf('LimitMerge/%d',k),'autorouting','on');
end
add_block('simulink/Sinks/Out1',[cut '/ratio'],'Position',[460 128 490 142]);
add_block('simulink/Sinks/Out1',[cut '/limit'],'Position',[460 303 490 317]);
add_line(cut,'RatioSelect/1','ratio/1','autorouting','on');
add_line(cut,'LimitMerge/1','limit/1','autorouting','on');
end

function [cut,h] = build_enabled_stage(model,top)
% The CUT itself is an Enabled Subsystem, so its enable is one of its
% branches. Sign gives a non-two-way branch, printed as a static [T/F].
h = 100;
cut = add_conditional_cut(model,'EnabledStage', ...
    'simulink/Ports & Subsystems/Enabled Subsystem',top,h);
add_block('simulink/Sources/Constant',[cut '/ceiling'],'Value','10', ...
    'Position',[120 33 150 47]);
add_block('simulink/Signal Routing/Switch',[cut '/CeilingSwitch'], ...
    'Criteria','u2 > Threshold','Threshold','10','Position',[200 30 250 110]);
add_line(cut,'ceiling/1','CeilingSwitch/1','autorouting','on');
add_line(cut,'u/1','CeilingSwitch/2','autorouting','on');
add_line(cut,'u/1','CeilingSwitch/3','autorouting','on');
add_line(cut,'CeilingSwitch/1','y/1','autorouting','on');
add_block('simulink/Math Operations/Sign',[cut '/Direction'], ...
    'Position',[200 150 230 180]);
add_block('simulink/Sinks/Out1',[cut '/direction'],'Position',[300 158 330 172]);
add_line(cut,'u/1','Direction/1','autorouting','on');
add_line(cut,'Direction/1','direction/1','autorouting','on');
end

function [cut,h] = build_triggered_stage(model,top)
% A function-call CUT. The Harness scheduler makes the call, so SLDV's
% FcnTriggerPort input is dropped, and Simulink Coverage records only that
% the subsystem executed.
h = 80;
cut = add_conditional_cut(model,'TriggeredStage', ...
    'simulink/Ports & Subsystems/Function-Call Subsystem',top,h);
add_block('simulink/Sources/Constant',[cut '/zero'],'Value','0', ...
    'Position',[120 113 150 127]);
add_block('simulink/Signal Routing/Switch',[cut '/PositiveOnly'], ...
    'Criteria','u2 >= Threshold','Threshold','0','Position',[200 30 250 130]);
add_line(cut,'u/1','PositiveOnly/1','autorouting','on');
add_line(cut,'u/1','PositiveOnly/2','autorouting','on');
add_line(cut,'zero/1','PositiveOnly/3','autorouting','on');
add_line(cut,'PositiveOnly/1','y/1','autorouting','on');
end

function [cut,h] = build_filtered_parent(model,top)
% Two direct child subsystems for CoverageFilterMode. The Switch inside
% Diagnostics is depth 2, so it is neither listed nor, with ALL_CONTENT,
% counted; the parent's own Switch stays.
h = 100;
cut = add_plain_cut(model,'FilteredParent',top,h);
add_block('simulink/Sources/In1',[cut '/u'],'Position',[30 93 60 107]);
scaling = [cut '/Scaling'];
add_block('simulink/Ports & Subsystems/Subsystem',scaling,'Position',[110 30 190 70]);
gain_inside(scaling,'0.5');
diagnostics = [cut '/Diagnostics'];
add_block('simulink/Ports & Subsystems/Subsystem',diagnostics,'Position',[110 150 190 190]);
delete_line(diagnostics,'In1/1','Out1/1');
add_block('simulink/Sources/Constant',[diagnostics '/alarm'],'Value','1', ...
    'Position',[100 23 130 37]);
add_block('simulink/Sources/Constant',[diagnostics '/normal'],'Value','0', ...
    'Position',[100 113 130 127]);
add_block('simulink/Signal Routing/Switch',[diagnostics '/AlarmSwitch'], ...
    'Criteria','u2 > Threshold','Threshold','90','Position',[170 30 220 120]);
add_line(diagnostics,'alarm/1','AlarmSwitch/1','autorouting','on');
add_line(diagnostics,'In1/1','AlarmSwitch/2','autorouting','on');
add_line(diagnostics,'normal/1','AlarmSwitch/3','autorouting','on');
add_line(diagnostics,'AlarmSwitch/1','Out1/1','autorouting','on');
add_line(cut,'u/1','Scaling/1','autorouting','on');
add_line(cut,'u/1','Diagnostics/1','autorouting','on');
add_block('simulink/Sources/Constant',[cut '/zero'],'Value','0', ...
    'Position',[230 123 260 137]);
add_block('simulink/Signal Routing/Switch',[cut '/SignGate'], ...
    'Criteria','u2 >= Threshold','Threshold','0','Position',[300 30 350 140]);
add_line(cut,'Scaling/1','SignGate/1','autorouting','on');
add_line(cut,'u/1','SignGate/2','autorouting','on');
add_line(cut,'zero/1','SignGate/3','autorouting','on');
add_block('simulink/Sinks/Out1',[cut '/y'],'Position',[410 78 440 92]);
add_block('simulink/Sinks/Out1',[cut '/alarm'],'Position',[410 163 440 177]);
add_line(cut,'SignGate/1','y/1','autorouting','on');
add_line(cut,'Diagnostics/1','alarm/1','autorouting','on');
end

% ---------------------------------------------------------------- inputs

function inputs = write_inputs(folder)
% One MAT per FILE CUT. Each Dataset variable becomes one scenario, in
% variable-name order, so the S1_/S2_ prefixes fix the scenario numbers.
% Element names equal the CUT Inport names, in port order.
dt = 0.01;
inputs = struct();

level = [0 10 30 60 80 30 10 0];
override = [0 0 0 0 1 1 0 0];
inputs.ModeSelect = save_inputs(folder,'ModeSelect', ...
    {'S1_AllModes','S2_LowLevelOnly'}, ...
    {dataset_of(dt,{'level','override'},level,override), ...
     dataset_of(dt,{'level','override'},5*ones(1,8),zeros(1,8))});

% |u| stays below the Clamp limits: Clamp reports [T] and [F], not [T/F].
u = [0 20 40 40 -40 -40 3 0];
inputs.LimitChain = save_inputs(folder,'LimitChain', ...
    {'S1_WithinClamp'},{dataset_of(dt,{'u'},u)});

u = [0 2 2 2 2 -2 -2 -2 0 0];
holdSignal = [1 1 1 0 0 1 1 1 1 1];
resetSignal = [0 0 0 0 0 0 1 1 0 0];
inputs.StateKeeper = save_inputs(folder,'StateKeeper', ...
    {'S1_HoldAndReset'},{dataset_of(dt,{'u','hold','reset'},u,holdSignal,resetSignal)});

inputs.GearSelect = save_inputs(folder,'GearSelect', ...
    {'S1_AllGears','S2_FirstGearOnly'}, ...
    {dataset_of(dt,{'gear','u'},[1 2 3 3 2 1],[1 1 1 2 2 2]), ...
     dataset_of(dt,{'gear','u'},ones(1,6),ones(1,6))});

inputs.FilteredParent = save_inputs(folder,'FilteredParent', ...
    {'S1_Sweep'},{dataset_of(dt,{'u'},[-10 0 50 95 100 20])});
end

function file = save_inputs(folder,cutName,variableNames,datasets)
file = fullfile(folder,[cutName '.mat']);
data = cell2struct(datasets(:),variableNames(:),1);
save(file,'-struct','data');
end

function ds = dataset_of(dt,names,varargin)
ds = Simulink.SimulationData.Dataset;
for k = 1:numel(names)
    values = double(varargin{k}(:));
    signal = Simulink.SimulationData.Signal;
    signal.Name = names{k};
    signal.Values = timeseries(values,(0:numel(values)-1).'*dt);
    ds = addElement(ds,signal);
end
end

function targets = target_table(model,inputs)
CUTName = ["ModeSelect";"LimitChain";"StateKeeper";"GearSelect"; ...
    "EnabledStage";"TriggeredStage";"FilteredParent"];
n = numel(CUTName);
No = (1:n).';
Enabled = true(n,1);
CUTPath = model + "/" + CUTName;
HarnessName = CUTName + "_Harness";
% {CUT}_{ID} with a made-up codeBeamer-style ID, the form the final
% document splits into Test Case ID and ID.
TestCaseName = CUTName + "_" + string(90000 + No);
isGenerate = ismember(CUTName,["EnabledStage";"TriggeredStage"]);
SldvMode = repmat("FILE",n,1);
SldvMode(isGenerate) = "GENERATE";
DataFileFormat = repmat("MAT",n,1);
DataFileFormat(isGenerate) = "SLDV";
SldvDataFile = strings(n,1);
for k = find(~isGenerate).'
    SldvDataFile(k) = string(inputs.(char(CUTName(k))));
end
MatVariableName = strings(n,1);
ExpectedUpdateMode = repmat("DEFAULT",n,1);
% The standalone pipeline requires ALL_CONTENT + CUT_ONLY + EXCLUDE and a
% rationale on every row. Child subsystems of the other CUTs are If/Switch
% Case action subsystems that hold one Gain, so excluding them removes no
% decision; in FilteredParent it removes the Switch inside Diagnostics.
CoverageFilterMode = repmat("ALL_CONTENT",n,1);
CoverageBoundaryMode = repmat("CUT_ONLY",n,1);
CoverageFilterAction = repmat("EXCLUDE",n,1);
CoverageFilterRationale = repmat("Demo: child subsystems are verified separately",n,1);
targets = table(No,Enabled,CUTName,CUTPath,HarnessName,TestCaseName, ...
    SldvMode,DataFileFormat,SldvDataFile,MatVariableName,ExpectedUpdateMode, ...
    CoverageFilterMode,CoverageBoundaryMode,CoverageFilterAction,CoverageFilterRationale);
end

% ---------------------------------------------------------------- helpers

function cut = add_plain_cut(model,name,top,h)
cut = [model '/' name];
add_block('simulink/Ports & Subsystems/Subsystem',cut,'Position',[300 top 460 top+h]);
delete_line(cut,'In1/1','Out1/1');
delete_block([cut '/In1']); delete_block([cut '/Out1']);
end

function cut = add_conditional_cut(model,name,library,top,h)
% Keeps the library's port block, renames In1/Out1 to u/y.
cut = [model '/' name];
add_block(library,cut,'Position',[300 top 460 top+h]);
delete_line(cut,'In1/1','Out1/1');
set_param([cut '/In1'],'Name','u');
set_param([cut '/Out1'],'Name','y');
end

function gain_inside(subsystem,gain)
delete_line(subsystem,'In1/1','Out1/1');
add_block('simulink/Math Operations/Gain',[subsystem '/k'],'Gain',gain, ...
    'Position',[110 35 140 65]);
add_line(subsystem,'In1/1','k/1','autorouting','on');
add_line(subsystem,'k/1','Out1/1','autorouting','on');
end

function wire_root(model,cut)
% Root Inports/Outports named <CUT>_<port>, an enable Inport, and a
% function-call generator, so the top model compiles without dangling ports.
[~,cutName] = fileparts(cut);
ports = get_param(cut,'PortHandles');
inports = find_system(cut,'SearchDepth',1,'BlockType','Inport');
for k = 1:numel(inports)
    number = str2double(get_param(inports{k},'Port'));
    root = add_root_port(model,'simulink/Sources/In1', ...
        [cutName '_' get_param(inports{k},'Name')],ports.Inport(number),-1);
    add_line(model,root.Outport(1),ports.Inport(number),'autorouting','on');
end
if ~isempty(ports.Enable)
    root = add_root_port(model,'simulink/Sources/In1',[cutName '_enable'],ports.Enable,-1);
    add_line(model,root.Outport(1),ports.Enable,'autorouting','on');
end
if ~isempty(ports.Trigger)
    root = add_root_port(model,'simulink/Ports & Subsystems/Function-Call Generator', ...
        [cutName '_call'],ports.Trigger,-1);
    set_param(get_param(root.Outport(1),'Parent'),'sample_time','0.01');
    add_line(model,root.Outport(1),ports.Trigger,'autorouting','on');
end
outports = find_system(cut,'SearchDepth',1,'BlockType','Outport');
for k = 1:numel(outports)
    number = str2double(get_param(outports{k},'Port'));
    root = add_root_port(model,'simulink/Sinks/Out1', ...
        [cutName '_' get_param(outports{k},'Name')],ports.Outport(number),1);
    add_line(model,ports.Outport(number),root.Inport(1),'autorouting','on');
end
end

function handles = add_root_port(model,library,name,anchor,side)
% side -1 places the block left of the CUT port, +1 right of it.
p = get_param(anchor,'Position');
x = p(1) + side*170;
block = add_block(library,[model '/' name],'Position',[x-15 p(2)-7 x+15 p(2)+7]);
handles = get_param(block,'PortHandles');
end

function close_if_loaded(model)
if bdIsLoaded(model), close_system(model,0); end
end
