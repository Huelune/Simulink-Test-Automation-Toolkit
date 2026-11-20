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
    % 테스트가 남긴 값 요약(오류 식별자, 개수). 이름과 경로는 넣지 않았다.
    if ~isempty(records) && isprop(records(1), 'TestDiagnosticResults') ...
            && ~isempty(records(1).TestDiagnosticResults)
        fprintf('       %s\n', records(1).TestDiagnosticResults(1).DiagnosticText);
    end
end
warning(oldWarning);
```

**확인할 것:** `통과 9 / 전체 9`. 실패하면 그 아래 줄에 기대와 달랐던 값이 찍힌다.

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
- 인터페이스에 `(원래 버스 객체 없음)` 포트가 있는지. Signal Editor 하네스는 버스 객체 없는 가상 버스
  입력을 받지 않는다(`VBusWithNoBusObjNotSupported_SE`). 축소 모델은 버스 객체를 만들어 넣으므로 이
  경우에는 축소 모델이 성공해도 재현 실패가 아니다.

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

## 4. SLDV coverage filter 동작 확인

**왜:** `SldvMode=GENERATE`가 `CoverageFilterMode`를 따라 하위 Subsystem에는 목표를 만들지 않게
바꿨다(기능 브랜치, 아직 main에 없음). 실제 모델에 넣기 전에 세 가지 가정을 확인한다.
`sldvoptions`에 `CovFilter`/`CovFilterFileName`이 있는지, Top Model SID로 만든 CVF가 atomic CUT
분석에서도 걸리는지, 그래서 목표 수가 줄어드는지. 블록 이름이 일반적인 작은 모델을 임시 폴더에
만들어 쓰므로 브랜치는 바꾸지 않아도 된다. 툴킷 함수를 쓰지 않아 어느 폴더에서 붙여 넣어도 된다. 2~3분.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
workDir = fullfile(tempdir, 'st_sldv_filter_check');
if isfolder(workDir), rmdir(workDir, 's'); end
mkdir(workDir); oldDir = cd(workDir);
mdl = 'sldvFilterCheck';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
set_param(mdl, 'Solver', 'FixedStepDiscrete', 'FixedStep', '0.1');
cut = [mdl '/Cut'];
add_block('simulink/Sources/In1', [mdl '/In1']);
add_block('simulink/Sinks/Out1', [mdl '/Out1']);
add_block('simulink/Ports & Subsystems/Subsystem', cut);
set_param(cut, 'TreatAsAtomicUnit', 'on');
delete_line(cut, 'In1/1', 'Out1/1');
add_block('simulink/Discontinuities/Saturation', [cut '/Sat']);
add_block('simulink/Ports & Subsystems/Subsystem', [cut '/Child']);
delete_line([cut '/Child'], 'In1/1', 'Out1/1');
add_block('simulink/Discontinuities/Saturation', [cut '/Child/Sat']);
add_line([cut '/Child'], 'In1/1', 'Sat/1'); add_line([cut '/Child'], 'Sat/1', 'Out1/1');
add_line(cut, 'In1/1', 'Sat/1'); add_line(cut, 'Sat/1', 'Child/1'); add_line(cut, 'Child/1', 'Out1/1');
add_line(mdl, 'In1/1', 'Cut/1'); add_line(mdl, 'Cut/1', 'Out1/1');
save_system(mdl, fullfile(workDir, [mdl '.slx']));

hasOption = isprop(sldvoptions, 'CovFilter') && isprop(sldvoptions, 'CovFilterFileName');
cvfFile = ''; filterError = '';
try
    f = slcoverage.Filter;
    addRule(f, slcoverage.FilterRule(slcoverage.BlockSelector( ...
        slcoverage.BlockSelectorType.SubsystemAllContent, Simulink.ID.getSID([cut '/Child'])), ...
        'none', slcoverage.FilterMode.Exclude));
    save(f, fullfile(workDir, 'child_filter'));
    cvfFile = fullfile(workDir, 'child_filter.cvf');
catch ME
    filterError = ME.identifier;
end

labels = {'필터 없음', '필터 있음'};
runStatus = nan(1, 2); objectiveCount = nan(1, 2); satisfiedCount = nan(1, 2); runError = {'', ''};
for k = 1:2
    try
        opts = sldvoptions;
        opts.Mode = 'TestGeneration';
        opts.OutputDir = fullfile(workDir, sprintf('out%d', k));
        opts.SaveReport = 'off'; opts.SaveHarnessModel = 'off'; opts.MaxProcessTime = 120;
        if k == 2, opts.CovFilter = 'on'; opts.CovFilterFileName = cvfFile; end
        [~, runStatus(k), files] = evalc('sldvrun(cut, opts, false)');
        loaded = load(files.DataFile);
        objectives = loaded.sldvData.Objectives;
        objectiveCount(k) = numel(objectives);
        satisfiedCount(k) = sum(contains(string({objectives.status}), 'Satisfied'));
    catch ME
        runError{k} = ME.identifier;
        if isempty(runError{k}), runError{k} = '(식별자 없음, 메시지는 내부 정보일 수 있어 생략)'; end
    end
end
close_system(mdl, 0); cd(oldDir); warning(oldWarning);

clc
fprintf('MATLAB %s\n', version('-release'));
fprintf('sldvoptions에 CovFilter/CovFilterFileName: %s\n', string(hasOption));
if ~isempty(filterError), fprintf('CVF 만들기 실패: %s\n', filterError); end
for k = 1:2
    if isempty(runError{k})
        fprintf('%s: 상태 %g | 목표 %d개 | 충족 %d개\n', labels{k}, runStatus(k), ...
            objectiveCount(k), satisfiedCount(k));
    else
        fprintf('%s: 실패 %s\n', labels{k}, runError{k});
    end
end
```

**확인할 것:** 둘째 줄이 `true`, 두 실행 모두 상태 `1`, `필터 있음`의 목표 수가 `필터 없음`보다
적다(Saturation 하나 몫만큼). 같으면 Top Model SID 필터가 CUT 분석에 안 걸린 것이다.

**돌려줄 것:** 화면 캡처 한 장.
