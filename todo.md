# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

## 1. 분기 결과 표기와 결정 단위 D 단위 테스트 (develop의 새 기능)

develop에만 있는 기능이다. 모델 프로젝트 안의 클론에서 develop을 받은 뒤
`st_setup`을 하고 실행한다. `tests`는 `st_setup`이 path에
넣지 않으므로 파일 경로로 돌린다(이름만 쓰면 "테스트 스위트를 만들 수 없습니다"로 멈춘다).

```matlab
st_setup
unitDir = fullfile(st_project_root(), 'tests', 'unit');
names = ["test_decision_outcomes", "test_export_final_document", ...
    "test_export_test_specification", "test_specification_decision_blocks", ...
    "test_coverage_filters"];
r = runtests(cellstr(fullfile(unitDir, names + ".m")));
clc
known = ["testScanReportsTheSubsystemNotThePortBlock", ...
    "testCatalogHidesOnlySwitchCaseExpressionInTheMainCell", ...
    "testApplicationCanIsolateAndRestoreExistingFilters", ...
    "testGeneratedFilterTargetsDirectChildSubsystems", ...
    "testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote", ...
    "testStaticScanIgnoresCommentsAndDocumentationStrings"];
logFile = fullfile(tempdir, 'failed_tests.txt');
fid = fopen(logFile, 'w', 'n', 'UTF-8');
skipped = 0;
fprintf('Passed %d / %d\n', sum([r.Passed]), numel(r));
for k = find(~[r.Passed])
    name = string(r(k).Name);
    short = extractAfter(name, "/");
    rec = r(k).Details.DiagnosticRecord;
    at = NaN;
    reason = "(no diagnostic)";
    if ~isempty(rec)
        rec = rec(1);
        fprintf(fid, '%s\n%s\n\n', name, rec.Report);
        for s = reshape(rec.Stack, 1, [])
            if contains(s.file, unitDir), at = s.line; break; end
        end
        if isprop(rec, 'Exception') && ~isempty(rec.Exception)
            reason = string(rec.Exception.message);
        elseif isprop(rec, 'FrameworkDiagnosticResults') && ~isempty(rec.FrameworkDiagnosticResults)
            reason = strjoin(string({rec.FrameworkDiagnosticResults.DiagnosticText}), " ");
        else
            reason = string(rec.Report);
        end
    end
    if any(short == known), skipped = skipped + 1; continue; end
    reason = strtrim(regexprep(reason, '\s+', ' '));
    if strlength(reason) > 230, reason = extractBefore(reason, 231) + "..."; end
    fprintf('%s:%d\n   %s\n', short, at, reason);
end
fclose(fid);
fprintf('known failures skipped: %d | full reports: %s\n', skipped, logFile);
```

돌려줄 것: 화면 캡처 한 장. 실패한 테스트마다 "이름:행 번호"와 이유가 두 줄로 나온다. 이유가
잘려서 판단이 안 되면 마지막 줄의 `failed_tests.txt` 내용을 붙인다.

이번 변경과 무관하게 **이미 실패하던 테스트 여섯 개**가 있다. 이것들이 실패해도 회귀가
아니며, 따로 고친다.

- `test_specification_decision_blocks/testScanReportsTheSubsystemNotThePortBlock`:
  지금 코드에 없는 `conditional_subsystems` 함수를 찾는다.
- `test_specification_decision_blocks/testCatalogHidesOnlySwitchCaseExpressionInTheMainCell`:
  `HIDE`가 SwitchCase 하나라고 가정하지만 catalog에는 CombinatorialLogic과
  Enable/Trigger/Reset도 `HIDE`다.
- `test_coverage_filters/testApplicationCanIsolateAndRestoreExistingFilters`(118행):
  `CoverageFilterReplacementRequiresRuntime`를 찾지만 지금 `src`에 없다.
- `test_coverage_filters/testGeneratedFilterTargetsDirectChildSubsystems`(178행):
  큰따옴표 MATLAB 문자열 안의 `\\(`가 역슬래시 자체를 찾는 정규식이 되어 맞지 않는다.
- `test_export_test_specification/testWorkbookKeepsFirstPrimaryOverflowPartAndAddsRowNote`(169행):
  빈 `Message` 셀을 readtable이 `NaN`으로 읽는다.
- `test_export_test_specification/testStaticScanIgnoresCommentsAndDocumentationStrings`(304행):
  `st_executable_source`가 호출을 하나도 남기지 않는다.

2026-10-08 실행의 나머지 실패 7건은 고쳤다(`b8412b1`, `23d3fd6`). 다시 돌리면 위 6건만
"known failures skipped: 6"으로 세고 화면에는 나오지 않아야 한다.

결과가 나오면 실제 모델로 최종 문서를 한 번 뽑아, Saturation이나 Discrete-Time
Integrator가 있는 CUT에서 결정마다 D가 나뉘고 `[T]`/`[F]`/`[T/F]`/`[-]`가 적히는지
본다. Discrete FIR Filter나 Discrete Transfer Fcn이 있으면 그 블록 줄도 함께 본다
(결정 이름을 실기로 확인하지 못한 블록이다).
