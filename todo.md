# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 데모 생성기의 경로 가림 검사 단위 테스트

**왜:** `st_setup_demo` 단위 테스트는 4/4 통과했다(2026-10-15). 그때 `ST_DemoModel`이 경로의 다른 것을 가린다는 경고가
나왔다. 같은 세션의 이전 데모 폴더가 경로에 남아 있으면 모델을 이름으로 여는 곳이 옛 파일을 열 수 있어서,
생성기가 그런 경우 `DemoModelOnPath`로 멈추게 했다. 생성기 단위 테스트 전체를 돌린다. 1~2분.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
evalc('st_setup');
testFile = fullfile(st_project_root(), 'tests', 'unit', 'test_create_demo_model.m');
[~, r] = evalc('runtests(testFile)');
clc
fprintf('데모 생성기 단위 테스트: 통과 %d / 전체 %d\n', sum([r.Passed]), numel(r));
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

**확인할 것:** `통과 8 / 전체 8`.

**돌려줄 것:** 화면 캡처 한 장.
