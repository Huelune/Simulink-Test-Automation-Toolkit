# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 파이프라인이 저장한 Coverage를 CVF 적용 상태로 보기

왜: 다시 실행하면 파이프라인보다 덜 충족되는데, 원인을 아직 못 찾았다. 그래서 다시 실행하지 않는 방법을 넣었다.
`st_open_standalone_test_manager('ShowSavedCoverage', true)`는 파이프라인이 CUT마다 저장한 Coverage 원본(CVT)에 CVF를
걸어 보고서를 열고 모델에 Coverage를 색으로 표시한다. 시뮬레이션은 하지 않는다. 단위 테스트도 함께 돌린다.

순서: 모델 프로젝트(.prj)를 연다. 클론에서 main을 pull한다. 열려 있는 모델 중 저장 안 한 것이 없을 때 아래 블록을 붙여
넣는다. 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
evalc('testResults = runtests(fullfile(st_project_root(), ''tests'', ''unit'', ''test_open_standalone_test_manager.m''));');
fprintf('단위 테스트 %d | 통과 %d | 실패 %d\n', numel(testResults), sum([testResults.Passed]), sum([testResults.Failed]));
failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
for k = 1:numel(failedTests), fprintf('실패 | %s\n', failedTests(k).Name); end
loadedNames = find_system('type', 'block_diagram');
if any(strcmp(get_param(loadedNames, 'Dirty'), 'on')), fprintf('저장 안 한 모델이 있습니다. 저장하거나 닫은 뒤 다시 돌려 주세요\n'); warning(warnState); return; end
bdclose('all');
try
    evalc('openInfo = st_open_standalone_test_manager(''ClearTestManager'', true, ''ShowSavedCoverage'', true, ''View'', false);');
    saved = openInfo.SavedCoverage;
    fprintf('MATLAB %s | 대상 %d | 보고서 연 것 %d | 실패 %d\n', version('-release'), height(saved), sum(saved.Status == "OK"), sum(saved.Status ~= "OK"));
    for t = 1:height(saved)
        if saved.Status(t) == "OK"
            fprintf('대상 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, saved.DecisionCovered(t), saved.DecisionTotal(t), saved.ExecutionCovered(t), saved.ExecutionTotal(t));
        else
            fprintf('대상 %d | 실패 | 식별자 %s\n', t, saved.ErrorId(t));
        end
    end
catch openError
    fprintf('열기 실패 | 식별자 %s\n', openError.identifier);
end
warning(warnState);
```

확인할 것: 단위 테스트 실패 0. 대상마다 CUT 결정 20/22, 실행 45/45(`CoverageSummary.xlsx`와 같은 값). 보고서가 브라우저에
열리고 Filter 항목에 뺀 것이 나오는지, 모델에 Coverage 색이 칠해지고 하위 Subsystem이 빠졌는지.

돌려줄 것: 화면 캡처 한 장과 "보고서에 필터 항목 나옴/안 나옴, 모델 색 표시 됨/안 됨" 한 줄. 보고서와 모델 화면은 블록
이름이 보이므로 캡처하지 마세요.

## 2. st_config.m에서 바꾼 SldvCoverageFilter 되돌리고 pull

왜: 비교하려고 클론의 `src\config\st_config.m`에서 `cfg.SldvCoverageFilter`를 `false`로 직접 바꿨다. 이제 main에서 기본값이
`false`가 되었다. 직접 바꾼 줄이 남아 있으면 pull할 때 같은 줄이 충돌한다. 그래서 그 파일의 직접 바꾼 내용을 버리고 pull한다.
툴킷 클론 폴더에서 명령 프롬프트로 실행한다.

```cmd
git checkout -- src/config/st_config.m && git pull
```

확인할 것: 오류 없이 끝나는지. pull 뒤 `st_config.m`에 `cfg.SldvCoverageFilter = false;`가 있는지.

돌려줄 것: 오류가 나면 그 화면. 정상이면 "됨" 한 줄.

## 3. 시나리오 2의 입력 데이터가 파이프라인과 같은지 비교

왜: 세 Iteration의 설정 구조가 똑같다. 파라미터 덮어쓰기(Variables, ModelParams)는 하나도 없고, TestParams 항목 수도 같다.
그러니 시나리오 2만 다르게 도는 이유는 Iteration 설정이 아니다. 남은 것은 입력 데이터다. 파이프라인은 실행 작업 공간의 입력
MAT를 읽었고, 재실행은 제출물 폴더에 복사된 입력 MAT를 읽는다. 두 파일의 해시와, 시나리오마다 담긴 데이터가 같은지 비교한다.
이름과 값은 찍지 않는다. 시뮬레이션은 하지 않는다. MATLAB에서 `st_setup`이 된 상태면 어디서든 붙여 넣는다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t);
    packagedFile = char(string(target.PackagedInput)); workFile = char(string(target.SignalEditorInput));
    if ~isfile(packagedFile) || ~isfile(workFile)
        fprintf('대상 %d | 제출물 입력 있음 %d | 작업 공간 입력 있음 %d\n', t, isfile(packagedFile), isfile(workFile)); continue;
    end
    sameHash = strcmpi(st_file_signature(packagedFile).SHA256, st_file_signature(workFile).SHA256);
    packagedData = load(packagedFile); workData = load(workFile);
    packagedNames = fieldnames(packagedData); workNames = fieldnames(workData);
    perScenario = strings(1, numel(packagedNames));
    for k = 1:numel(packagedNames)
        if k <= numel(workNames) && strcmp(packagedNames{k}, workNames{k})
            perScenario(k) = string(double(isequaln(packagedData.(packagedNames{k}), workData.(workNames{k}))));
        else
            perScenario(k) = "이름다름";
        end
    end
    fprintf('대상 %d | 해시 같음 %d | 시나리오 수 제출물 %d, 작업 공간 %d | 시나리오별 같음 %s\n', t, sameHash, ...
        numel(packagedNames), numel(workNames), strjoin(perScenario, ' '));
end
warning(warnState);
```

확인할 것: 해시가 같으면 입력 데이터도 원인이 아니다. 해시가 다르면 "시나리오별 같음"에서 몇 번째가 0인지 본다(2번째만 0이면 원인이다).

돌려줄 것: 화면 캡처 한 장.
