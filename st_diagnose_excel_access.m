function [status, output, reportFile] = st_diagnose_excel_access(writeProbe, pythonExe)
%ST_DIAGNOSE_EXCEL_ACCESS Compare xlwings workbook opening methods.
%
% Safe default:
%   st_diagnose_excel_access
%
% Also test read-write open without saving and a disposable save:
%   st_diagnose_excel_access(true)
%
% Explicit Python executable:
%   st_diagnose_excel_access(false, 'C:\Python311\python.exe')
%
% The original management workbook is never modified by this diagnostic.

if nargin < 1 || isempty(writeProbe)
    writeProbe = false;
end

if nargin < 2
    pythonExe = '';
end

cfg = st_config();

scriptDir = ...
    fileparts(mfilename('fullpath'));

scriptFile = ...
    fullfile(scriptDir, 'excel_open_diagnostic.py');

if ~isfile(scriptFile)
    error( ...
        'Diagnostic Python script not found: %s', ...
        scriptFile);
end

if ~isfile(cfg.ManagementExcel)
    error( ...
        'Management Excel not found: %s', ...
        cfg.ManagementExcel);
end

pythonExe = ...
    st_diag_resolve_python( ...
        pythonExe);

if ~isfolder(cfg.ResultDir)
    mkdir(cfg.ResultDir);
end

reportFile = ...
    fullfile( ...
        cfg.ResultDir, ...
        'ExcelAccessDiagnostic.json');

q = char(34);

cmd = [ ...
    q pythonExe q ...
    ' ' ...
    q scriptFile q ...
    ' ' ...
    q cfg.ManagementExcel q ...
    ' --json-out ' ...
    q reportFile q];

if logical(writeProbe)
    cmd = [cmd ' --write-probe'];
end

fprintf('\n');
fprintf('============================================\n');
fprintf('Excel Access Diagnostic\n');
fprintf('============================================\n');
fprintf('Python   : %s\n', pythonExe);
fprintf('Workbook : %s\n', cfg.ManagementExcel);
fprintf('WriteProbe: %d\n\n', logical(writeProbe));

[status, output] = ...
    system(cmd);

fprintf('%s\n', output);

if isfile(reportFile)
    fprintf('Diagnostic report: %s\n', reportFile);
end

if status ~= 0
    warning( ...
        ['Excel access diagnostic returned status %d. ' ...
         'Check the method-by-method output above.'], ...
        status);
end

end


function pythonExe = st_diag_resolve_python(pythonExe)

pythonExe = ...
    strtrim( ...
        char(string(pythonExe)));

if ~isempty(pythonExe)
    return;
end

try
    env = pyenv;
    candidate = ...
        strtrim( ...
            char(string(env.Executable)));

    if ~isempty(candidate)
        pythonExe = candidate;
        return;
    end
catch
end

pythonExe = 'python';

end
