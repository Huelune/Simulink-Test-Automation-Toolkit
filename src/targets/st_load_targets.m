function T = st_load_targets(onlyEnabled)
%ST_LOAD_TARGETS Read and normalize the management Excel Targets sheet.
%
% Required logical columns (aliases accepted):
%   CUTName, CUTPath, HarnessName, TestCaseName
% Optional:
%   No, Enabled, SldvMode, SldvDataFile, ExpectedUpdateMode,
%   PreparationMode, PreparationFromStage
%
% Important:
% - CUTName and CUTPath preserve their original whitespace because trailing
%   whitespace can be part of a real Simulink block name/path.
% - HarnessName and TestCaseName are generated identifiers and keep the
%   legacy strtrim behavior.
% - Empty-row detection still uses trimmed copies, so whitespace-only rows
%   are treated as empty.

if nargin < 1
    cfg = st_config();
    onlyEnabled = cfg.OnlyEnabled;
else
    cfg = st_config();
end

if ~isfile(cfg.ManagementExcel)
    error('Management Excel not found: %s', cfg.ManagementExcel);
end

raw = readtable(cfg.ManagementExcel, ...
    'Sheet', cfg.ManagementSheet, ...
    'TextType', 'string', ...
    'VariableNamingRule', 'preserve');

if isempty(raw)
    error('Targets sheet is empty: %s', cfg.ManagementSheet);
end

names = raw.Properties.VariableNames;

idxCUTName = find_column(names, ...
    {'CUTName','ModelName','모델명','CUT','대상모델명'});

idxCUTPath = find_column(names, ...
    {'CUTPath','Path','path','경로','모델경로'});

idxHarness = find_column(names, ...
    {'HarnessName','Harness','하네스명'});

idxTestCase = find_column(names, ...
    {'TestCaseName','TestCase','TCName','테스트케이스명'});

idxNo = find_column_optional(names, ...
    {'No','번호','Number','순번'});

idxEnabled = find_column_optional(names, ...
    {'Enabled','사용','사용여부','활성','활성화'});

idxSldvMode = find_column_optional(names, ...
    {'SldvMode','SLDVMode','SLDV Mode'});

idxSldvDataFile = find_column_optional(names, ...
    {'SldvDataFile','SLDVDataFile','SLDV Data File'});

idxExpectedUpdateMode = find_column_optional(names, ...
    {'ExpectedUpdateMode','Expected Update Mode','기대값갱신모드'});

idxPreparationMode = find_column_optional(names, ...
    {'PreparationMode','Preparation Mode','준비실행모드'});

idxPreparationFromStage = find_column_optional(names, ...
    {'PreparationFromStage','Preparation From Stage','준비시작단계'});

CUTName = string(raw{:, idxCUTName});
CUTPath = string(raw{:, idxCUTPath});
HarnessName = string(raw{:, idxHarness});
TestCaseName = string(raw{:, idxTestCase});

% Preserve CUTName/CUTPath whitespace exactly, but normalize missing values.
CUTName(ismissing(CUTName)) = '';
CUTPath(ismissing(CUTPath)) = '';

% Generated identifiers keep the legacy whitespace trimming behavior.
HarnessName = strtrim(HarnessName);
TestCaseName = strtrim(TestCaseName);

HarnessName(ismissing(HarnessName)) = '';
TestCaseName(ismissing(TestCaseName)) = '';

n = height(raw);

SldvMode = repmat("OFF", n, 1);

if ~isempty(idxSldvMode)
    SldvMode = upper(strtrim(string(raw{:, idxSldvMode})));
    SldvMode(ismissing(SldvMode) | strlength(SldvMode) == 0) = "OFF";
end

SldvDataFile = strings(n,1);

if ~isempty(idxSldvDataFile)
    SldvDataFile = strtrim(string(raw{:, idxSldvDataFile}));
    SldvDataFile(ismissing(SldvDataFile)) = "";
end

ExpectedUpdateMode = repmat("DEFAULT", n, 1);

if ~isempty(idxExpectedUpdateMode)
    ExpectedUpdateMode = string(raw{:, idxExpectedUpdateMode});
end

PreparationMode = repmat("DEFAULT", n, 1);
if ~isempty(idxPreparationMode)
    PreparationMode = upper(strtrim(string(raw{:, idxPreparationMode})));
    PreparationMode(ismissing(PreparationMode) | ...
        strlength(PreparationMode) == 0) = "DEFAULT";
end

PreparationFromStage = repmat("DEFAULT", n, 1);
if ~isempty(idxPreparationFromStage)
    PreparationFromStage = ...
        upper(strtrim(string(raw{:, idxPreparationFromStage})));
    PreparationFromStage(ismissing(PreparationFromStage) | ...
        strlength(PreparationFromStage) == 0) = "DEFAULT";
end

No = (1:n)';

if ~isempty(idxNo)

    temp = raw{:, idxNo};

    if isnumeric(temp)

        valid = ~isnan(temp);
        No(valid) = temp(valid);

    else

        tempNum = str2double(string(temp));
        valid = ~isnan(tempNum);
        No(valid) = tempNum(valid);
    end
end

Enabled = true(n,1);

if ~isempty(idxEnabled)

    temp = raw{:, idxEnabled};

    if islogical(temp)

        Enabled = temp;

    elseif isnumeric(temp)

        Enabled = temp ~= 0;

    else

        s = lower(strtrim(string(temp)));

        Enabled = ismember( ...
            s, ...
            {'true','1','yes','y','on','사용','o'});
    end
end

% Drop completely empty rows, but keep partially invalid rows for
% validation. Use trimmed copies only for the emptiness decision.
keep = ...
    ~(strlength(strtrim(CUTName)) == 0 & ...
      strlength(strtrim(CUTPath)) == 0 & ...
      strlength(strtrim(HarnessName)) == 0 & ...
      strlength(strtrim(TestCaseName)) == 0);

No = No(keep);
Enabled = Enabled(keep);
CUTName = CUTName(keep);
CUTPath = CUTPath(keep);
HarnessName = HarnessName(keep);
TestCaseName = TestCaseName(keep);
SldvMode = SldvMode(keep);
SldvDataFile = SldvDataFile(keep);
ExpectedUpdateMode = ExpectedUpdateMode(keep);
PreparationMode = PreparationMode(keep);
PreparationFromStage = PreparationFromStage(keep);

ExpectedUpdateMode = ...
    st_resolve_expected_update_modes( ...
        ExpectedUpdateMode, ...
        cfg.ExpectedUpdateMode);

validPreparationModes = ["DEFAULT", "AUTO", "FORCE"];
invalidPreparationModes = ...
    ~ismember(PreparationMode, validPreparationModes);
if any(invalidPreparationModes)
    error('simtest:InvalidPreparationMode', ...
        'PreparationMode must be DEFAULT, AUTO, or FORCE: %s', ...
        char(strjoin(unique(PreparationMode(invalidPreparationModes)), ', ')));
end

validPreparationStages = [ ...
    "DEFAULT", "START", "HARNESS", "SLDV", "HARNESS_CONFIG", ...
    "SIGNAL_EDITOR", "ASSESSMENT", "TEST_MANAGER", "ALIGNMENT"];
invalidPreparationStages = ...
    ~ismember(PreparationFromStage, validPreparationStages);
if any(invalidPreparationStages)
    error('simtest:InvalidPreparationFromStage', ...
        'Invalid PreparationFromStage: %s', ...
        char(strjoin(unique(PreparationFromStage( ...
            invalidPreparationStages)), ', ')));
end

T = table( ...
    Enabled, ...
    No, ...
    CUTName, ...
    CUTPath, ...
    HarnessName, ...
    TestCaseName, ...
    SldvMode, ...
    SldvDataFile, ...
    ExpectedUpdateMode, ...
    PreparationMode, ...
    PreparationFromStage);

if onlyEnabled
    T = T(T.Enabled, :);
end

end


function idx = find_column(names, aliases)

idx = find_column_optional(names, aliases);

if isempty(idx)
    error( ...
        'Required Excel column not found. Accepted names: %s', ...
        strjoin(aliases, ', '));
end

end


function idx = find_column_optional(names, aliases)

idx = [];

normalizedNames = ...
    cellfun( ...
        @(x) lower(strtrim(x)), ...
        names, ...
        'UniformOutput', false);

normalizedAliases = ...
    cellfun( ...
        @(x) lower(strtrim(x)), ...
        aliases, ...
        'UniformOutput', false);

for k = 1:numel(normalizedAliases)

    p = find( ...
        strcmp(normalizedNames, normalizedAliases{k}), ...
        1, ...
        'first');

    if ~isempty(p)
        idx = p;
        return;
    end
end

end
