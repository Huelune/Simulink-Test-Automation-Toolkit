# Standalone Coverage Runtime Commands

이 문서는 실제 MATLAB R2025b에서 실행할 명령만 모아 둔 수동 검증용 runbook이다.
각 블록은 위에서 아래 순서로 복사해 실행한다. 새 코드가 반영된 뒤에는 이전
PipelineId를 재사용하지 말고 새 `ALL` 실행을 만든다.

## 1. 새 파이프라인 실행

원본 Top Model과 Test File을 저장한 뒤 Top Model을 닫는다. MATLAB을 다시 시작한
직후에는 아래 블록만 실행하면 된다.

```matlab
st_setup;
cfg = st_require_runtime_target('LoadModel', false);
assert(~bdIsLoaded(cfg.TopModel), ...
    '원본 Top Model을 저장하고 닫은 후 다시 실행하세요.');

packageFile = which('st_package_standalone_coverage_artifacts');
perCutFile = which('st_run_tests_per_cut');
fprintf('PACKAGE source: %s\n', packageFile);
fprintf('PER_CUT source: %s\n', perCutFile);
assert(contains(fileread(packageFile), ...
    'PACKAGE captured coverage data promotion complete'), ...
    '최신 PACKAGE helper가 아닙니다. 최신 브랜치를 pull한 경로에서 st_setup을 다시 실행하세요.');
assert(contains(fileread(packageFile), ...
    'item.PackageFailure = package_failure_detail(ME)'), ...
    'PACKAGE failure stack 기록 코드가 없습니다. 최신 브랜치를 pull하세요.');
assert(contains(fileread(perCutFile), ...
    'save_package_evidence_cvt(cvtPath, coverageObjects, cfg)'), ...
    '열린 모델에서 CVT evidence를 만드는 최신 PER_CUT 코드가 아닙니다.');
assert(contains(fileread(perCutFile), ...
    'cvhtml(reportHTML, coverageObjects{1}, ''-sRT=0'')'), ...
    'Test Manager Coverage Results 원본 HTML을 만드는 최신 PER_CUT 코드가 아닙니다.');
assert(contains(fileread(perCutFile), ...
    'copyfile(scratchZip, reportZip, ''f'')'), ...
    '긴 CUT 경로를 피하는 Coverage report scratch 승격 코드가 없습니다.');

info = st_run_standalone_coverage_pipeline( ...
    'Action', 'ALL', ...
    'ContinueOnFailure', true, ...
    'FailOnNonPass', false);

[code, summary, details] = st_check_standalone_coverage( ...
    'PipelineId', info.PipelineId);
disp(code)
disp(summary)
disp(details)
```

성공 기준은 `code = '1111111111'` 및 `summary.Status = 'PASS'`다.

## 2. PACKAGE 실패 시 호출 위치 확인

새 실행의 PACKAGE가 실패하면, 다음 블록으로 실패 원인과 최초 호출 파일·라인을
확인한다. `disp`에는 표 하나만 전달한다. `PackageFailure`가 없다는 출력은 그
PipelineId가 최신 PACKAGE helper로 생성되지 않았다는 증거다.

```matlab
[m, manifestPath] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);

fprintf('Manifest: %s\n', manifestPath);
T = struct2table(m.Targets);
disp(T(:, {'CUTName', 'ExecutionStatus', 'PackageEvidenceStatus', ...
    'PackageStatus', 'Message'}));

for k = 1:numel(m.Targets)
    if ~isfield(m.Targets, 'PackageFailure')
        fprintf('\n[%03d] %s: PackageFailure field is absent.\n', ...
            k, m.Targets(k).CUTName);
        continue;
    end
    f = m.Targets(k).PackageFailure;
    if strlength(string(f.Identifier)) == 0
        continue;
    end
    fprintf('\n[%03d] %s\n%s: %s\n', k, m.Targets(k).CUTName, ...
        f.Identifier, f.Message);
    if isfield(f, 'Stack') && ~isempty(f.Stack)
        fprintf('Caller: %s (%s:%d)\n', f.Stack(1).Name, ...
            f.Stack(1).File, f.Stack(1).Line);
    end
end
```

`PackageEvidenceStatus='OK'`이면 열린 execution standalone model에서 Test Manager
Coverage Results의 REPORT 화살표가 여는 원본 `cvhtml` HTML ZIP, metric, CVT evidence까지
생성된 상태다. 이후 PACKAGE는 해당 evidence를 SHA-256으로 검증해 결과 폴더로 복사만
한다.

## 3. PACKAGE evidence 읽기 전용 실패 위치 확인

`Message`에 `The current directory is read only`가 있고
`PackageEvidenceStatus='FAIL'`이면 다음 블록을 실행한다. PACKAGE의
`st_package_standalone_coverage_artifacts:37`은 EXECUTE 실패를 전달하는 위치일 뿐
원래 Coverage API 호출 위치가 아니다. 아래 출력은 실패 target마다 어느 evidence까지
생성됐는지와 `PACKAGE_EVIDENCE` event를 함께 보여 준다.

```matlab
[m, manifestPath] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);

perCutFile = which('st_run_tests_per_cut');
perCutSource = fileread(perCutFile);
fprintf('Manifest: %s\n', manifestPath);
fprintf('PER_CUT source: %s\n', perCutFile);
assert(contains(perCutSource, ...
    "st_enter_writable_coverage_directory(cfg, 'CVSAVE')"), ...
    'CVSAVE writable-directory 격리가 없는 이전 코드입니다.');
assert(contains(perCutSource, ...
    "st_enter_writable_coverage_directory(cfg, 'CVHTML')"), ...
    'CVHTML writable-directory 격리가 없는 이전 코드입니다.');

if isfile(m.ExecutionLog)
    lines = splitlines(string(fileread(m.ExecutionLog)));
    relevant = contains(lines, ...
        ["PACKAGE_EVIDENCE", "Coverage writable directory", "read only"], ...
        'IgnoreCase', true);
    fprintf('\nExecution log: %s\n', m.ExecutionLog);
    disp(lines(relevant));
else
    fprintf('\nExecution log is missing: %s\n', m.ExecutionLog);
end

artifactNames = { ...
    'CoverageResult.cvt', ...
    fullfile('CoverageReport', 'report.html'), ...
    'CoverageReport.zip', ...
    'evidence.json'};
for k = 1:numel(m.Targets)
    t = m.Targets(k);
    if ~strcmpi(string(t.PackageEvidenceStatus), "FAIL")
        continue;
    end
    evidenceDirectory = fullfile(t.PerCutTargetDirectory, 'package-evidence');
    fprintf('\n[%03d] %s\n', k, t.CUTName);
    fprintf('  Message: %s\n', t.Message);
    fprintf('  Evidence directory: %s\n', evidenceDirectory);
    for j = 1:numel(artifactNames)
        artifactPath = fullfile(evidenceDirectory, artifactNames{j});
        fprintf('  %-36s exists=%d\n', artifactNames{j}, ...
            isfile(artifactPath));
    end
end
```

`CoverageResult.cvt=0`이면 CVSAVE 이전/도중 실패, CVT가 `1`이고 ZIP이 `0`이면
CVHTML 또는 scratch ZIP 승격 도중 실패, ZIP까지 `1`이고 `evidence.json=0`이면 metric
수집 또는 최종 evidence 직렬화 단계 실패다. 최신 구현의 report tree는 짧은 scratch
안에서만 생성되고 정리되므로 `CoverageReport\report.html`이 evidence 폴더에 남지 않는
것이 정상이다. 출력 전체를 공유한다.

## 4. B7 metric 실패 확인

checker가 `1111110111`을 반환하면 PACKAGE는 성공했고 B7만 실패한 상태다. 다음
블록으로 Result Coverage API에서 선택한 metric source와 두 metric의 scalar 계약을
확인한다.

```matlab
[m, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);

T = struct2table(m.Targets);
metricColumns = {'CUTName', 'MetricSource', 'MetricSourceStatus', ...
    'DecisionMetricStatus', 'DecisionCovered', 'DecisionTotal', ...
    'DecisionPercentage', 'DecisionPercentageText', ...
    'ExecutionMetricStatus', 'ExecutionCovered', 'ExecutionTotal', ...
    'ExecutionPercentage', 'ExecutionPercentageText'};
disp(T(:, metricColumns));
```

정상값은 `MetricSourceStatus='PROVISIONAL'`, 각 `MetricStatus='OK'`다. CVF가 해당
CUT의 objective를 모두 제외했거나 원래 objective가 없으면 `Covered=0`, `Total=0`,
`Percentage=NaN`, `PercentageText='N/A'`도 정상이다. 반대로 `MISSING`, `INCOMPLETE`,
`AMBIGUOUS`, Total이 0이 아닌데 `NaN`, 혹은 Covered가 Total보다 큰 값이 보이면 표
전체를 공유한다.

## 5. 산출물 확인

```matlab
[m, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);

for k = 1:numel(m.Targets)
    t = m.Targets(k);
    fprintf('[%03d] %s\n', k, t.CUTName);
    fprintf('  HTML:        %d  %s\n', isfile(t.ReportHTML), t.ReportHTML);
    fprintf('  CVT:         %d  %s\n', isfile(t.CoverageResult), t.CoverageResult);
    fprintf('  model closed: %d\n', ~bdIsLoaded(t.StandaloneModel));
end
```

`UT_REQ_{TC_NAME}.html`, `UT_REQ_{TC_NAME}.cvt`가 모두 존재하고 각 `model closed`
값이 `1`이면 PACKAGE와
cleanup 산출물 계약을 만족한다.

## 6. 패키지 Test Manager 열기

`TestManager` 폴더의 `.mldatx`는 Test File이며, standalone Harness 모델은 CUT별
결과 폴더의 `PackagedStandaloneModel`이다. Test Manager의 Model 속성은 파일 경로가
아닌 모델명이다. 따라서 폴더 버튼으로 `.slx`를 선택해도 그 결과 폴더가 MATLAB path에
없으면 Refresh/All이 `...Harness1`을 다시 찾지 못할 수 있다.

수동 UI 사용 시에는 Harness `.slx`가 있는 대상 결과 폴더를 MATLAB Current Folder에서
**Add to Path → Selected Folders**로 먼저 등록한 뒤 `.mldatx`를 열고, Model 필드의 폴더
버튼으로 같은 Harness를 선택한다. 이 경로 등록은 MATLAB 세션/개인 설정의 일부이며
`.mldatx`에 외부 모델 경로가 이식 가능하게 저장되는 것은 아니다. 다른 사용자는 같은
결과 폴더를 받은 뒤에도 한 번은 해당 폴더를 path에 추가하거나 Harness를 열어야 한다.

Model Editor에서 Harness `.slx`를 먼저 열어 loaded 상태로 만든 뒤, Test Manager의 Model
필드에서 그 모델명을 선택하는 방법도 가능하다. 이 동작은 original model이나 original
Harness를 바꾸지 않고 패키지 standalone Harness만 연다.

```matlab
[m, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);

assert(isfile(m.TestManagerLauncher), ...
    '이 Pipeline은 Test Manager launcher가 없는 이전 패키지입니다.');
run(m.TestManagerLauncher)
```

launcher는 Harness 모델을 먼저 load하고 CVF를 적용한 뒤 Test Manager를 연다. 수동으로
동일한 순서를 재현하려면 아래처럼 한 CUT의 `PackagedStandaloneModel`을 먼저 연 뒤
Test File을 load한다.

```matlab
t = m.Targets(1);
assert(isfile(t.PackagedStandaloneModel));
load_system(t.PackagedStandaloneModel)
assert(bdIsLoaded(t.StandaloneModel));
sltest.testmanager.load(m.TestManagerFile);
sltest.testmanager.view
```

이후 Test Manager에서 해당 Test Case의 Model은 `t.StandaloneModel` 이름으로 선택한다.
Refresh/All 직전에 이 모델을 닫거나 `rmpath(fileparts(t.PackagedStandaloneModel))` 하면
동일한 `Harness1` not found 오류가 재현된다.

launcher 없이 모든 CUT을 한 번에 여는 수동 절차는 아래와 같다. `<PipelineId>` 자리에는
`latest.json`을 따르는 `'LATEST'`도 쓸 수 있다.

```matlab
[m, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, '<PipelineId>');

% 동일 모델명이 이미 열려 있으면 충돌 방지를 위해 먼저 닫습니다.
for k = 1:numel(m.Targets)
    t = m.Targets(k);
    assert(~bdIsLoaded(t.StandaloneModel), ...
        '이미 열린 모델을 먼저 닫으세요: %s', t.StandaloneModel);
    assert(isfolder(t.OutputDirectory));
    assert(isfile(t.PackagedStandaloneModel));
end

% 모든 결과 폴더를 MATLAB path에 등록
folders = cellstr(unique(string({m.Targets.OutputDirectory}), 'stable'));
addpath(folders{:});

% 모든 standalone Harness를 로드
for k = 1:numel(m.Targets)
    t = m.Targets(k);
    load_system(t.PackagedStandaloneModel);
    assert(bdIsLoaded(t.StandaloneModel), ...
        'Harness load 실패: %s', t.StandaloneModel);
end

% 패키지 Test Manager 파일 열기
sltest.testmanager.TestFile(m.TestManagerFile);
sltest.testmanager.view
```

이 절차는 CVF를 적용하지 않으므로 Coverage 결과를 다시 보려면 launcher를 쓰거나 각
Test Case의 Coverage Settings에서 `t.PackagedCVF`를 직접 지정한다. 등록한 path는
세션 설정이므로 작업 후 `rmpath(folders{:})`로 되돌린다.

## 7. 원본 HTML의 CVF 적용 근거

PIPELINE은 Test Manager 실행 뒤 결과 Coverage에 CVF를 붙인다. Test Manager가 결과를
다시 조회할 때 새 `cvdata` 객체를 만들 수 있으므로, `cvhtml`에 넘길 객체에도 CVF를
직접 다시 바인딩한 뒤 보고서를 생성한다. 아래 표에서 active CUT의 `CVFRuleCount`,
`ResultFilterAttachCount`, `ResultFilterStatus`가 각각 `0보다 큼`, `1`, `OK`이면
원본 HTML 생성 전에 CVF 바인딩 readback이 완료된 것이다. 실행 로그에는
`Standalone original Coverage report CVF binding complete`가 남는다.

```matlab
[m, ~] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, info.PipelineId);
T = struct2table(m.Targets);
disp(T(:, {'CUTName', 'CVFRuleCount', 'ResultFilterAttachCount', ...
    'ResultFilterStatus', 'ExecutionCVFPath', 'PackagedCVF', 'ReportHTML'}));
```

Coverage의 공식 API는 simulation 후에도 `cvdata.filter`에 CVF 파일을 설정해 filter를
적용할 수 있다. 따라서 report에서 제외된 항목은 일반 coverage percentage 변화만이
아니라 Excluded/Justified 상태로 확인한다.
