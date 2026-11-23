# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. standalone 열기 명령과 제출물 launcher 단위 테스트

왜: `st_open_standalone_test_manager`에 `RunPerTestCase`를 넣었고, 제출물의 launcher
(`open_standalone_coverage_test_manager.m`)도 Test Case마다 자기 CVF를 건 직후 실행하게 바꿨다. MATLAB이 없어
단위 테스트를 못 돌렸다. 먼저 클론에서 main을 pull한다. 실행하면 툴킷 폴더(`st_setup.m`이 있는 폴더)를 고르는 창이 뜬다.
이미 만든 제출물 폴더의 launcher는 PACKAGE 때 복사한 옛 것이다. 바뀐 launcher는 다음 PACKAGE부터 들어간다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
toolkitDir = uigetdir(pwd, '툴킷 폴더(st_setup.m이 있는 폴더)를 고르세요');
if isequal(toolkitDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
oldDir = cd(toolkitDir); evalc('st_setup'); cd(oldDir);
testFiles = fullfile(st_project_root(), 'tests', 'unit', ...
    {'test_open_standalone_test_manager.m', 'test_standalone_coverage_pipeline.m', 'test_classify_standalone_results.m'});
evalc('testResults = runtests(testFiles);');
fprintf('MATLAB %s | 테스트 %d | 통과 %d | 실패 %d | 미완료 %d\n', version('-release'), numel(testResults), ...
    sum([testResults.Passed]), sum([testResults.Failed]), sum([testResults.Incomplete]));
failedTests = testResults([testResults.Failed] | [testResults.Incomplete]);
for k = 1:numel(failedTests), fprintf('실패 | %s\n', failedTests(k).Name); end
warning(warnState);
```

확인할 것: 실패 0. 실패하면 줄에 테스트 이름이 찍힌다(툴킷 테스트 이름이라 내부 정보가 아니다).

돌려줄 것: 화면 캡처 한 장.
