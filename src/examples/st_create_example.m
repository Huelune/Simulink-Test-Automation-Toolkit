function example = st_create_example(destination)
%ST_CREATE_EXAMPLE Generate redistributable FILE/MAT inputs, without running.
cfg = struct('VerboseLogging',true);
st_log(cfg,'INFO','Example generation start');
model = 'ST_ExampleModel';
try
destination = st_absolute_path(destination);
if bdIsLoaded(model)
    error('simtest:ExampleModelLoaded','Close %s yourself before generating the example.',model);
end
if isfolder(destination)
    files = dir(destination);
    if any(~ismember({files.name},{'.','..'}))
        error('simtest:ExampleDestinationNotEmpty','Choose a new or empty destination.');
    end
else
    mkdir(destination);
end
oldPath = path; oldFolder = pwd;
guard = onCleanup(@() restore(model,oldPath,oldFolder)); %#ok<NASGU>
    new_system(model);
    set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
        'FixedStep','0.01','StopTime','0.04');
    names = ["NormalDecision";"FilteredDecision"];
    for i = 1:2
        cut = [model '/' char(names(i))];
        add_block('simulink/Ports & Subsystems/Subsystem',cut, ...
            'Position',[80 50+170*(i-1) 330 170+170*(i-1)]);
        clear_subsystem(cut);
        add_block('simulink/Sources/In1',[cut '/u']);
        add_block('simulink/Sinks/Out1',[cut '/y']);
        if i == 1
            build_branch(cut);
        else
            nested = [cut '/ExcludedBranch'];
            add_block('simulink/Ports & Subsystems/Subsystem',nested);
            clear_subsystem(nested);
            add_block('simulink/Sources/In1',[nested '/u']);
            add_block('simulink/Sinks/Out1',[nested '/y']);
            build_branch(nested);
            add_line(cut,'u/1','ExcludedBranch/1','autorouting','on');
            add_line(cut,'ExcludedBranch/1','y/1','autorouting','on');
        end
    end
    modelFile = fullfile(destination,[model '.slx']);
    st_log(cfg,'INFO','Example model save start | File=%s',modelFile);
    save_system(model,modelFile);
    close_system(model,0);
    st_log(cfg,'INFO','Example model save complete');
    Scenario = Simulink.SimulationData.Dataset;
    signal = Simulink.SimulationData.Signal;
    signal.Name = 'u';
    signal.Values = timeseries([-1;1;-1;1],[0;0.01;0.02;0.04]);
    Scenario = addElement(Scenario,signal);
    inputFile = fullfile(destination,'ExampleInput.mat');
    save(inputFile,'Scenario');
    No = [1;2]; Enabled = true(2,1); CUTName = names;
    CUTPath = model + "/" + names;
    HarnessName = "h_" + names;
    TestCaseName = "tc_" + names;
    SldvMode = repmat("FILE",2,1);
    DataFileFormat = repmat("MAT",2,1);
    SldvDataFile = repmat(string(inputFile),2,1);
    MatVariableName = repmat("Scenario",2,1);
    ExpectedUpdateMode = repmat("DEFAULT",2,1);
    CoverageFilterMode = repmat("ALL_CONTENT",2,1);
    CoverageBoundaryMode = repmat("CUT_ONLY",2,1);
    CoverageFilterAction = repmat("EXCLUDE",2,1);
    CoverageFilterRationale = repmat("none",2,1);
    targets = table(No,Enabled,CUTName,CUTPath,HarnessName,TestCaseName, ...
        SldvMode,DataFileFormat,SldvDataFile,MatVariableName,ExpectedUpdateMode, ...
        CoverageFilterMode,CoverageBoundaryMode,CoverageFilterAction,CoverageFilterRationale);
    management = fullfile(destination,'TestManagement.example.xlsx');
    st_log(cfg,'INFO','Example workbook write start | File=%s',management);
    writetable(targets,management,'Sheet','Targets');
    st_log(cfg,'INFO','Example workbook write complete');
    example = struct('Root',destination,'ModelFile',modelFile, ...
        'ManagementExcel',management,'InputFile',inputFile, ...
        'OutputRoot',fullfile(destination,'result'));
    st_log(cfg,'INFO','Example generation complete | Root=%s | No tests executed',destination);
catch ME
    st_log(cfg,'ERROR','Example generation failed | Partial files retained in %s | %s',destination,ME.message);
    rethrow(ME);
end
end

function build_branch(root)
add_block('simulink/Sources/Constant',[root '/positive'],'Value','1');
add_block('simulink/Sources/Constant',[root '/negative'],'Value','-1');
add_block('simulink/Signal Routing/Switch',[root '/Decision'], ...
    'Criteria','u2 >= Threshold','Threshold','0');
add_line(root,'positive/1','Decision/1','autorouting','on');
add_line(root,'u/1','Decision/2','autorouting','on');
add_line(root,'negative/1','Decision/3','autorouting','on');
add_line(root,'Decision/1','y/1','autorouting','on');
end

function clear_subsystem(root)
delete_line(root,'In1/1','Out1/1');
delete_block([root '/In1']); delete_block([root '/Out1']);
end

function restore(model,oldPath,oldFolder)
if bdIsLoaded(model), close_system(model,0); end
path(oldPath);
if ~strcmp(pwd,oldFolder), cd(oldFolder); end
end
