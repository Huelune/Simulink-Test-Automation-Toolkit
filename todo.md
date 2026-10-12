# MATLAB 실행 요청

작성: 2026-10-12. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 데모 모델로 전 과정 돌리기

**왜:** 데모 모델로 Harness 생성 → 실행 → 결과 정리 → 명세서 → standalone 제출물 → 최종 문서까지
한 번에 지나가는지, 최종 문서에 분기 결과 `[T]`, `[F]`, `[T/F]`, `[-]`가 의도대로 나오는지 본다.
실제 업무 모델에 없던 Saturation 같은 결정 단위 블록, Enabled CUT, SLDV `GENERATE`도 여기서
처음 실물로 지나간다. 생성기 단위 테스트는 2026-10-12에 전부 통과했다. SLDV가 필요하고 수십 분 걸릴 수 있다.

**업무 결과와 섞이지 않게** 툴킷을 `D:\st_demo\toolkit`에 복사해서 그 안에서 돌린다. 원래 클론의
`TestManagement.xlsx`, `runtime_target.mat`, `result`는 건드리지 않는다. 끝나면 MATLAB 경로와 현재
폴더를 되돌린다. `D:\st_demo`가 이미 있으면 지우거나 이름을 바꾼 뒤 돌린다.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
savedPath = path; savedFolder = pwd;
demoRoot = 'D:\st_demo';
stages = ["복사" "생성" "사전 검사" "준비와 실행" "결과 정리" "명세서" "standalone" "검사" "최종 문서"];
done = 0; failId = ''; code = ''; finalFile = '';
try
    if isfolder(demoRoot)
        error('demo:RootExists', 'remove the demo folder first');
    end
    evalc('st_setup');
    source = st_project_root();
    toolkit = fullfile(demoRoot, 'toolkit');
    mkdir(toolkit);
    items = dir(source);
    skip = {'.', '..', '.git', 'result', 'runtime_target.mat', 'TestManagement.xlsx'};
    for k = 1:numel(items)
        if ~ismember(items(k).name, skip)
            copyfile(fullfile(source, items(k).name), fullfile(toolkit, items(k).name));
        end
    end
    restoredefaultpath;
    cd(toolkit); evalc('st_setup'); done = 1;
    demo = st_create_demo_model(fullfile(demoRoot, 'model'));
    copyfile(demo.ManagementExcel, fullfile(st_project_root(), 'TestManagement.xlsx'));
    st_save_runtime_target_fields(fullfile(st_project_root(), 'runtime_target.mat'), ...
        struct('TopModel', demo.TopModel, 'ModelFile', demo.ModelFile));
    evalc('st_set_standalone_coverage_root(fullfile(demoRoot, ''model_result''))'); done = 2;
    st_pre_validate_targets(); done = 3;
    st_run_from_harness; done = 4;
    st_collect_per_cut_results; done = 5;
    st_export_test_specification(); done = 6;
    info = st_run_standalone_coverage_pipeline(); done = 7;
    code = st_check_standalone_coverage(); done = 8;
    [~, finalFile] = st_export_final_document('CoveragePipelineId', info.PipelineId); done = 9;
catch ME
    failId = ME.identifier;
    fid = fopen(fullfile(tempdir, 'st_demo_run_report.txt'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    fclose(fid);
end
if bdIsLoaded('ST_DemoModel'), close_system('ST_DemoModel', 0); end
path(savedPath); cd(savedFolder); warning(oldWarning);
clc
fprintf('데모 전 과정: %d / %d 단계 통과\n', done, numel(stages));
if done < numel(stages)
    fprintf('  멈춘 단계: %s | 오류 식별자: %s\n', stages(done + 1), failId);
    fprintf('  자세한 내용: %%TEMP%%\\st_demo_run_report.txt (밖으로 보내지 마세요)\n');
end
if ~isempty(code), fprintf('standalone 검사 코드: %s\n', char(string(code))); end
if ~isempty(finalFile)
    C = readcell(finalFile, 'Sheet', 'TestCase');
    verdict = string(C(2:end, 13)); verdict(ismissing(verdict)) = "";
    fprintf('최종 문서 %d행 | PASS %d | FAIL %d | 빈 칸 %d\n', size(C, 1) - 1, ...
        sum(verdict == "PASS"), sum(verdict == "FAIL"), sum(verdict == ""));
    R = string(readcell(finalFile, 'Sheet', 'TestResults')); R(ismissing(R)) = "";
    fprintf('UNAVAILABLE %d | MISMATCH %d | AMBIGUOUS %d\n', ...
        sum(contains(R(:), 'DECISION_OUTCOME_UNAVAILABLE')), ...
        sum(contains(R(:), 'DECISION_OUTCOME_MISMATCH')), ...
        sum(contains(R(:), 'AMBIGUOUS')));
    fprintf('ID     | D 줄의 분기 결과 (D1부터 차례로)\n');
    for k = 2:size(C, 1)
        description = C{k, 5};
        if ~ischar(description) && ~isstring(description), description = ''; end
        tokens = regexp(char(description), 'D\d+ \[([^\]]*)\]', 'tokens');
        tokens = string(cellfun(@(t) t{1}, tokens, 'UniformOutput', false));
        fprintf('%-6s | %s\n', string(C{k, 2}), strjoin(tokens, ' '));
    end
end
```

**확인할 것:**

- `9 / 9 단계 통과`, standalone 검사 코드 `1111111111`, FAIL 0, UNAVAILABLE·MISMATCH 0.
- ID별 기대값. ID는 관리 Excel의 지어낸 번호다.
  - `90001` (If/elseif + Switch) 두 행: 하나는 `T/F T/F T/F`, 다른 하나는 `F F F`.
  - `90002` (Saturation, DeadZone, RateLimiter 등): Saturation 두 줄이 `T`와 `F`로 나온다.
  - `90003` (Delay, Discrete-Time Integrator, Relay): `T/F`가 대부분이다.
  - `90004` (Multiport Switch, Switch Case) 두 행: 정적 블록이라 둘 다 `T/F T/F`.
  - `90005` (Enabled CUT), `90006` (함수 호출 CUT): SLDV가 만든 행이다. `90006`의 첫 D는 `T`다.
  - `90007` (필터를 건 부모): D 한 줄, `T/F`.

**돌려줄 것:** 화면 캡처 한 장. 멈췄다면 멈춘 단계와 오류 식별자가 같이 찍힌다. 데모 모델 이름과 ID는
지어낸 값이라 찍혀도 된다.
