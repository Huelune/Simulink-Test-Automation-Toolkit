# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 재실행이 파이프라인과 다른 Data Dictionary(.sldd)를 읽는지 확인

왜: 새 세션에서 다시 돌려도, CVF를 실행 전에 걸든 후에 걸든 CUT 결정 11/22·실행 41/45다. 파이프라인 원본은 20/22·45/45다.
모델 파일, 입력 MAT, CVF, Iteration 수가 같으니 남은 후보는 모델이 읽는 데이터다. standalone 제출물에는 sldd가 없다.
그래서 재실행은 프로젝트에 잡힌 sldd를 읽는다. 파이프라인은 실행 작업 공간(번들 사본)에 있는 sldd를 읽었다.
두 파일이 다른지 해시로 비교한다. 이름이나 경로는 찍지 않는다.
앞 절처럼 프로젝트를 열고 `RunPerTestCase`로 돌린 MATLAB에서 이어서 붙여 넣는다(standalone 모델이 열려 있어야 한다).

```matlab
clearvars; clc; warnState = warning('off', 'all');
pipeline = st_load_standalone_pipeline_manifest(st_config().StandaloneCoverageRootDir, 'LATEST');
searchRoots = {char(string(pipeline.Workspace)), char(string(pipeline.BundleDirectory))};
fprintf('파이프라인 작업 공간 있음 %d | 번들 폴더 있음 %d\n', isfolder(searchRoots{1}), isfolder(searchRoots{2}));
for t = 1:numel(pipeline.Targets)
    [~, modelName] = fileparts(char(string(pipeline.Targets(t).PackagedStandaloneModel)));
    if ~bdIsLoaded(modelName), fprintf('대상 %d | 모델이 안 열려 있음\n', t); continue; end
    ddName = char(string(get_param(modelName, 'DataDictionary')));
    hasCallback = ~isempty(get_param(modelName, 'PreLoadFcn')) || ~isempty(get_param(modelName, 'PostLoadFcn')) || ~isempty(get_param(modelName, 'InitFcn'));
    if isempty(ddName), fprintf('대상 %d | sldd 연결 없음 | 모델 콜백 있음 %d\n', t, hasCallback); continue; end
    usedFile = which(ddName);
    copies = {};
    for r = 1:numel(searchRoots)
        if isfolder(searchRoots{r})
            found = dir(fullfile(searchRoots{r}, '**', ddName));
            copies = [copies, fullfile({found.folder}, {found.name})]; %#ok<AGROW>
        end
    end
    sameCount = 0;
    for c = 1:numel(copies)
        sameCount = sameCount + strcmpi(st_file_signature(copies{c}).SHA256, st_file_signature(usedFile).SHA256);
    end
    fprintf('대상 %d | sldd 연결 있음 | 재실행이 읽는 파일 찾음 %d | 파이프라인 쪽 사본 %d개 | 그중 내용이 같은 것 %d | 모델 콜백 있음 %d\n', ...
        t, ~isempty(usedFile), numel(copies), sameCount, hasCallback);
end
warning(warnState);
```

확인할 것: "파이프라인 쪽 사본"이 있는데 "내용이 같은 것"이 0이면, 파이프라인과 재실행이 서로 다른 sldd 값으로 돈 것이다.
작업 공간과 번들 폴더가 모두 없으면(지워졌으면) 이 방법으로는 비교할 수 없다. "sldd 연결 없음"이면 데이터는 모델 콜백이나
base workspace에서 온다.

돌려줄 것: 화면 캡처 한 장.
