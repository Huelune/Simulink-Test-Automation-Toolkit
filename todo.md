# MATLAB 실행 요청

작성: 2026-10-12. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 데모 모델로 전 과정 돌리기 (Top Model 저장 상태 추적)

**왜:** 지난번에는 5단계(결과 정리)까지 지나간 뒤 명세서 직전에 Top Model이 저장 안 된 상태(Dirty)라서
`SpecificationUnsaved`로 멈췄다. 실행 단계가 모델을 바꾸고 저장하지 않은 것으로 보인다. 이번에는 단계마다
Top Model 상태를 찍는다. 명세서 직전에 Dirty면 메모리의 모델과 저장된 파일을 파라미터 단위로 비교해
**바뀐 파라미터의 종류**(Model/Config/블록 종류와 파라미터 이름)만 찍는다. 그 뒤 진단을 위해 저장하지 않고
닫은 다음 남은 단계를 계속한다. 이렇게 하면 standalone과 최종 문서도 한 번에 시험된다. SLDV가 필요하고
수십 분 걸릴 수 있다.

**먼저 `D:\st_demo` 폴더를 지운다.** 툴킷을 그 안에 새로 복사해서 돌리므로 원래 클론의
`TestManagement.xlsx`, `runtime_target.mat`, `result`는 건드리지 않는다. 끝나면 MATLAB 경로와 현재 폴더를
되돌린다.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
savedPath = path; savedFolder = pwd;
demoRoot = 'D:\st_demo'; model = 'ST_DemoModel';
stages = ["복사" "생성" "사전 검사" "준비와 실행" "결과 정리" "명세서" "standalone" "검사" "최종 문서"];
labels = ["닫힘" "저장됨" "Dirty"];
dirtyOf = @(m) labels(1 + bdIsLoaded(m) + (bdIsLoaded(m) && strcmp(get_param(m, 'Dirty'), 'on')));
states = strings(1, 0); changed = strings(0, 1); diffNote = "";
done = 0; failId = ''; code = ''; finalFile = '';
try
    if isfolder(demoRoot), error('demo:RootExists', 'remove the demo folder first'); end
    evalc('st_setup');
    source = st_project_root(); toolkit = fullfile(demoRoot, 'toolkit'); mkdir(toolkit);
    items = dir(source);
    skip = {'.', '..', '.git', 'result', 'runtime_target.mat', 'TestManagement.xlsx'};
    for k = 1:numel(items)
        if ~ismember(items(k).name, skip)
            copyfile(fullfile(source, items(k).name), fullfile(toolkit, items(k).name));
        end
    end
    restoredefaultpath; cd(toolkit); evalc('st_setup'); done = 1;
    demo = st_create_demo_model(fullfile(demoRoot, 'model'));
    copyfile(demo.ManagementExcel, fullfile(st_project_root(), 'TestManagement.xlsx'));
    st_save_runtime_target_fields(fullfile(st_project_root(), 'runtime_target.mat'), ...
        struct('TopModel', demo.TopModel, 'ModelFile', demo.ModelFile));
    evalc('st_set_standalone_coverage_root(fullfile(demoRoot, ''model_result''))'); done = 2;
    st_pre_validate_targets(); done = 3; states(end+1) = dirtyOf(model);
    st_run_from_harness; done = 4; states(end+1) = dirtyOf(model);
    st_collect_per_cut_results; done = 5; states(end+1) = dirtyOf(model);
    if dirtyOf(model) == "Dirty"
        hs = sltest.harness.find(model); openH = 0; dirtyH = 0;
        for k = 1:numel(hs)
            if bdIsLoaded(hs(k).name)
                openH = openH + 1; dirtyH = dirtyH + strcmp(get_param(hs(k).name, 'Dirty'), 'on');
            end
        end
        copyDir = fullfile(demoRoot, 'saved_copy'); mkdir(copyDir);
        copyfile(demo.ModelFile, fullfile(copyDir, 'ST_DemoSaved.slx'));
        load_system(fullfile(copyDir, 'ST_DemoSaved.slx'));
        A = st_snapshot_model_state('ST_DemoSaved'); B = st_snapshot_model_state(model);
        close_system('ST_DemoSaved', 0);
        [inSaved, at] = ismember(B.Key, A.Key);
        for k = find(inSaved).'
            if ~isequaln(B.Value{k}, A.Value{at(k)}), changed(end+1, 1) = B.Label(k); end
        end
        changed = changed(~ismember(changed, ["Model Name" "Model FileName" "Model Handle" ...
            "Model Dirty" "Model ModelWorkspace"]));
        diffNote = sprintf('열린 Harness %d (Dirty %d) | 메모리에만 있는 파라미터 %d | 파일에만 있는 파라미터 %d', ...
            openH, dirtyH, sum(~inSaved), sum(~ismember(A.Key, B.Key)));
        close_system(model, 0);
    end
    st_export_test_specification(); done = 6; states(end+1) = dirtyOf(model);
    info = st_run_standalone_coverage_pipeline(); done = 7;
    code = st_check_standalone_coverage(); done = 8;
    [~, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId); done = 9;
catch ME
    failId = ME.identifier;
    fid = fopen(fullfile(tempdir, 'st_demo_run_report.txt'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    fclose(fid);
end
if bdIsLoaded(model), close_system(model, 0); end
path(savedPath); cd(savedFolder); warning(oldWarning);
clc
fprintf('데모 전 과정: %d / %d 단계 통과\n', done, numel(stages));
if done < numel(stages)
    fprintf('  멈춘 단계: %s | 오류 식별자: %s\n', stages(done + 1), failId);
    fprintf('  자세한 내용: %%TEMP%%\st_demo_run_report.txt (밖으로 보내지 마세요)\n');
end
fprintf('Top Model 상태 (사전 검사, 실행, 결과 정리, 명세서 뒤): %s\n', strjoin(states, ' → '));
if strlength(diffNote) > 0
    fprintf('결과 정리 뒤 Dirty: %s\n', diffNote);
    if isempty(changed)
        fprintf('  바뀐 파라미터 없음 (Dirty 표시만 켜짐)\n');
    else
        [kinds, ~, idx] = unique(changed); counts = accumarray(idx(:), 1);
        [~, order] = sort(counts, 'descend');
        for k = order(1:min(12, numel(order))).'
            fprintf('  바뀐 파라미터: %-50s %d곳\n', kinds(k), counts(k));
        end
        if numel(kinds) > 12, fprintf('  ... 종류 %d개 더\n', numel(kinds) - 12); end
    end
end
if ~isempty(code), fprintf('standalone 검사 코드: %s\n', char(string(code))); end
if ~isempty(finalFile)
    C = readcell(finalFile, 'Sheet', 'TestCase');
    verdict = string(C(2:end, 13)); verdict(ismissing(verdict)) = "";
    R = string(readcell(finalFile, 'Sheet', 'TestResults')); R(ismissing(R)) = "";
    fprintf('최종 문서 %d행 | PASS %d | FAIL %d | 빈 칸 %d | UNAVAILABLE %d | MISMATCH %d\n', ...
        size(C, 1) - 1, sum(verdict == "PASS"), sum(verdict == "FAIL"), sum(verdict == ""), ...
        sum(contains(R(:), 'DECISION_OUTCOME_UNAVAILABLE')), sum(contains(R(:), 'DECISION_OUTCOME_MISMATCH')));
    for k = 2:size(C, 1)
        description = C{k, 5};
        if ~ischar(description) && ~isstring(description), description = ''; end
        tokens = regexp(char(description), 'D\d+ \[([^\]]*)\]', 'tokens');
        tokens = string(cellfun(@(t) t{1}, tokens, 'UniformOutput', false));
        fprintf('  ID %-6s | %s\n', string(C{k, 2}), strjoin(tokens, ' '));
    end
end
```

**확인할 것:**

- Top Model 상태 줄: 어느 단계 뒤에 처음 `Dirty`가 되는지.
- 바뀐 파라미터 줄: 무엇이 바뀌었는지. `바뀐 파라미터 없음`이면 실제 변경 없이 Dirty 표시만 켜진 것이다.
- 끝까지 가면 `9 / 9`, standalone 검사 코드 `1111111111`, FAIL 0, UNAVAILABLE·MISMATCH 0, ID별 기대값:
  - `90001` (If/elseif + Switch) 두 행: 하나는 `T/F T/F T/F`, 다른 하나는 `F F F`.
  - `90002` (Saturation 등): Saturation 두 줄이 `T`와 `F`로 나온다.
  - `90003` (Delay, Discrete-Time Integrator, Relay): `T/F`가 대부분이다.
  - `90004` (Multiport Switch, Switch Case) 두 행: 정적 블록이라 둘 다 `T/F T/F`.
  - `90005` (Enabled CUT), `90006` (함수 호출 CUT): SLDV가 만든 행이다. `90006`의 첫 D는 `T`다.
  - `90007` (필터를 건 부모): D 한 줄, `T/F`.

**돌려줄 것:** 화면 캡처 한 장. 데모 모델 이름, 파라미터 이름, ID는 지어낸 값이거나 공개된 Simulink 이름이라
찍혀도 된다.
