# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 데모 세팅 명령 `st_setup_demo` 단위 테스트

**왜:** 데모를 만들고 `TestManagement.xlsx`·대상 모델·standalone 결과 폴더까지 한 번에 지정하는 `st_setup_demo`를
새로 만들었다. MATLAB에서 아직 돌리지 않았다. 테스트는 임시 폴더를 저장소 루트처럼 꾸며서 돌리므로 이 클론의
`TestManagement.xlsx`와 `runtime_target.mat`은 건드리지 않는다. 1분 안팎.

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

**확인할 것:** `통과 3 / 전체 3`.

**돌려줄 것:** 화면 캡처 한 장. 테스트 함수 이름은 지어낸 이름이라 찍혀도 된다.
