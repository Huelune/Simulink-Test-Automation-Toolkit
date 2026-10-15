# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. `st_setup_demo` 드라이브 검사 단위 테스트

**왜:** `st_setup_demo()`의 기본 위치가 `tempdir`(C:)라서 D:의 툴킷으로 돌리면 standalone이
`NoCommonExportRoot`로 멈췄다. 기본 위치를 툴킷 폴더 옆으로 바꾸고, 다른 드라이브는 세팅 단계에서 거부하게
했다. 이 클론의 `TestManagement.xlsx`와 `runtime_target.mat`은 건드리지 않는다. 1분 안팎.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
evalc('st_setup');
testFile = fullfile(st_project_root(), 'tests', 'unit', 'test_setup_demo.m');
[~, r] = evalc('runtests(testFile)');
clc
fprintf('st_setup_demo 단위 테스트: 통과 %d / 전체 %d\n', sum([r.Passed]), numel(r));
for k = find(~[r.Passed])
    records = r(k).Details.DiagnosticRecord;
    kind = '미완료'; id = '';
    if ~isempty(records)
        kind = records(1).Event;
        if isprop(records(1), 'Exception') && ~isempty(records(1).Exception)
            id = records(1).Exception.identifier;
        end
    end
    fprintf('  실패 %-52s %-20s %s\n', regexprep(r(k).Name, '^.*/', ''), kind, id);
end
warning(oldWarning);
```

**확인할 것:** `통과 4 / 전체 4`.

**돌려줄 것:** 화면 캡처 한 장.
