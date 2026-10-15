# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 하네스 생성 진단 도구 단위 테스트

**왜:** 하네스를 만들 수 없던 문의에 기술지원이 버전, 입력 구성, 축소 모델, '별도의 Test Assessment
블록 추가'를 끈 결과를 물었다. 이를 한 번에 모으는 `st_diagnose_harness_creation`을 만들었다. 실제
모델에 돌리기 전에, 이름이 화면과 축소 모델에 새지 않는지 `secret` 이름을 넣은 작은 모델로 확인한다. 1분.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
evalc('st_setup');
testFile = fullfile(st_project_root(), 'tests', 'unit', 'test_diagnose_harness_creation.m');
[~, r] = evalc('runtests(testFile)');
clc
fprintf('하네스 생성 진단 단위 테스트: 통과 %d / 전체 %d\n', sum([r.Passed]), numel(r));
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

**확인할 것:** `통과 7 / 전체 7`.

**돌려줄 것:** 화면 캡처 한 장.

## 2. 하네스를 만들 수 없던 CUT 진단

**왜:** 기술지원 회신의 1·3·4·5번 질문에 답할 자료를 모은다. 1절이 통과한 뒤 돌린다.

- 1번: `version` 결과를 찍는다.
- 3번: CUT 입출력을 이름 없이 버스 여부, 형식 종류, 크기, 샘플 타임으로 묶어 개수로 찍는다.
- 5번: 원래 모델에서 Signal Editor + 별도 Test Assessment, Signal Editor만, Inport + 별도 Test
  Assessment 세 가지로 하네스를 만들어 보고 성공·실패와 MathWorks 오류 식별자를 찍는다.
- 3·4번: CUT 입출력만 남기고 버스·요소 이름을 `ReproBus_<n>`, `e<n>`으로 바꾼 축소 모델을
  `%TEMP%\st_harness_repro`에 만들고, 같은 세 가지를 다시 해 본다.

진단이 만든 하네스는 지우지만 모델은 바뀐 상태로 남는다. **돌린 뒤 원래 모델은 저장하지 말고 닫는다.**
저장할 변경이 남아 있으면 먼저 저장한 뒤 돌린다. 모델 크기에 따라 몇 분 걸린다.

먼저 모델을 열고, CUT이 **보이는 부모 단계에서** CUT 블록을 한 번 클릭해 선택한 뒤 붙여 넣는다.
CUT 안으로 들어간 상태면 `gcb`가 안쪽 블록을 가리켜 `InvalidHarnessOwnerHandle`이 난다.

```matlab
clearvars
oldWarning = warning('off', 'all');
evalc('st_setup');
cutBlock = gcb;
try
    report = st_diagnose_harness_creation(cutBlock);
catch ME
    clc
    fprintf('진단이 멈춤: %s\n', ME.identifier);
    fprintf('선택한 블록 종류: %s (SubSystem이어야 한다)\n', get_param(cutBlock, 'BlockType'));
    fprintf('CUT이 보이는 부모 단계에서 CUT을 선택했는지 확인한 뒤 다시 돌려 주세요.\n');
end
warning(oldWarning);
```

**확인할 것:**

- `[원래 모델에서 sltest.harness.create]`의 첫 줄이 실패하는지(GUI에서 본 오류가 재현되는지).
- 둘째 줄(Test Assessment 없음)과 셋째 줄(Inport)이 성공하는지.
- `[축소 모델에서]`가 원래 모델과 같은 결과인지. 같게 실패하면 축소 모델로 재현된 것이다.

**돌려줄 것:** 화면 캡처 한 장. `%TEMP%\st_harness_diagnosis.txt`(전체 오류 보고)와
`%TEMP%\st_harness_repro`의 축소 모델은 보내지 않는다. 축소 모델을 기술지원에 보낼지는 결과를 보고 정한다.

## 3. 기술지원에 보낼 오류 화면 (Claude에게는 보내지 않는다)

**왜:** 기술지원이 `sl_sta:editor:errorGeneratingSimInput`이 보이는 화면 전체를 요청했다. GUI로 만들면
이 식별자가 화면에 나오지 않으므로, 명령 창에서 GUI와 같은 설정으로 만들어 오류 원문을 띄운다.
이 화면에는 모델·블록 이름과 경로가 찍힌다. **기술지원용이며 Claude에게는 보내지 않는다.**

2절처럼 CUT이 보이는 부모 단계에서 CUT 블록을 클릭해 선택한 뒤 붙여 넣는다.

```matlab
clearvars; clc
cutBlock = gcb;
fprintf('선택한 블록 종류: %s (SubSystem이어야 한다)\n\n', get_param(cutBlock, 'BlockType'));
try
    sltest.harness.create(cutBlock, 'Name', 'ST_Support_Harness', ...
        'Source', 'Signal Editor', 'SeparateAssessment', true);
    disp('하네스가 만들어졌다. 오류가 재현되지 않았다.');
    sltest.harness.delete(cutBlock, 'ST_Support_Harness');
catch ME
    fprintf('오류 식별자: %s\n\n', ME.identifier);
    disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
end
```

**확인할 것:** 블록 종류가 `SubSystem`이고, 오류 식별자가 `sl_sta:editor:errorGeneratingSimInput`인지.

**돌려줄 것:**

- 기술지원에는 명령 창 화면을 캡처해 보낸다. 사내 이름과 경로를 가릴지는 직접 정한다.
- Claude에게는 식별자가 나왔는지 여부만 말로 알려 준다.
- 돌린 뒤 모델은 저장하지 말고 닫는다.
