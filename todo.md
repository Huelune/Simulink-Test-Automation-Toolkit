# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 재실행 커버리지와 파이프라인 커버리지를 같은 기준으로 비교

왜: 이제 자기 입력 MAT로 돌아가는데도 재실행은 결정 11/22·실행 42/46이고, 파이프라인 `CoverageSummary.xlsx`는
20/22·45/45다. 지금까지 재실행 숫자는 모델 전체를 기준으로 셌고, 파이프라인은 CUT 경로를 기준으로 셌다. 실행
분모(46과 45)가 다른 것도 그 때문일 수 있다. 같은 기준으로 다시 센다. 재실행 결과와, 파이프라인이 남긴
Coverage 원본(CUT 폴더의 `.cvt`)에 같은 CVF를 걸어 CUT 경로에서 센다. 파이프라인 원본도 11/22라면 Excel 쪽
집계가 다른 것이다. 원본이 20/22이고 재실행만 11/22라면 재실행이 다르게 돈 것이다.
`RunPerTestCase`로 연 MATLAB을 닫지 않은 상태에서 붙여 넣는다(재실행 결과와 모델이 열려 있어야 한다).

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
resultSets = sltest.testmanager.getResultSets;
for t = 1:numel(pipeline.Targets)
    target = pipeline.Targets(t); cutPath = char(string(target.StandaloneCUTPath)); cvfFile = char(string(target.PackagedCVF));
    try
        [~, savedData] = cvload(char(string(target.CoverageResult)));
        if iscell(savedData), savedData = savedData{1}; end
        savedData.filter = cvfFile;
        savedDecision = decisioninfo(savedData, cutPath); savedExec = executioninfo(savedData, cutPath);
        fprintf('대상 %d 파이프라인 원본 | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, savedDecision(1), savedDecision(2), savedExec(1), savedExec(2));
    catch savedError
        fprintf('대상 %d 파이프라인 원본 | 읽기 실패 | 식별자 %s\n', t, savedError.identifier);
    end
    for k = 1:numel(resultSets)
        pending = {getCoverageResults(resultSets(k))}; covObjects = {};
        while ~isempty(pending)
            item = pending{1}; pending(1) = [];
            if iscell(item), pending = [pending, item(:)']; %#ok<AGROW>
            elseif isa(item, 'cv.cvdatagroup'), pending = [pending, getAll(item)']; %#ok<AGROW>
            elseif isa(item, 'cvdata'), covObjects = [covObjects, num2cell(item(:)')]; end %#ok<AGROW>
        end
        for j = 1:numel(covObjects)
            try
                rerunDecision = decisioninfo(covObjects{j}, cutPath); rerunExec = executioninfo(covObjects{j}, cutPath);
                fprintf('대상 %d 재실행 결과 %d | CUT 결정 %d/%d | CUT 실행 %d/%d\n', t, k, rerunDecision(1), rerunDecision(2), rerunExec(1), rerunExec(2));
            catch
                % 다른 대상의 결과에는 이 CUT 경로가 없다
            end
        end
    end
end
warning(warnState);
```

확인할 것: 대상마다 "파이프라인 원본"과 "재실행 결과"의 CUT 결정 수가 같은지. 대상마다 재실행 결과 줄이 하나만
나와야 한다.

돌려줄 것: 화면 캡처 한 장.
