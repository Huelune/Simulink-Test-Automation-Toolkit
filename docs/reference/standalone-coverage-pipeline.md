# Standalone Coverage 파이프라인

CUT별 Harness를 **독립 실행 가능한 모델**로 떼어내 실행하고, 커버리지 결과와 부속
파일을 제출 가능한 형태로 묶는 기능입니다. 받는 쪽에 원본 Top Model이 없어도 열
수 있는 결과물을 만듭니다.

평소 쓰는 절차와 옵션은 [사용자 매뉴얼](../user-manual.md)에 있습니다. 이 문서는 파이프라인의 경계, 산출물 구조, 예외 처리를 자세히 적습니다.

## 1. 실행 전 조건

이 파이프라인은 **이미 준비가 끝난 Harness와 Test Case를 입력으로 씁니다.**
Harness 생성, Test Case 재생성, 기대값 갱신이 필요하면 먼저 일반 workflow를
실행하십시오.

```matlab
st_run_from_harness('PreparationMode','FORCE','ExecuteTests', false);
```

실행 직전에 다음을 확인합니다.

- 원본 Top Model과 Test File의 미저장 변경을 저장하고 Top Model을 닫습니다
  (`CloseSourceModel` 기본 `true`). 복사된 작업 공간의 모델과 이름이 충돌하기
  때문입니다. 변경을 폐기하지는 않으며, 저장에 실패하면
  `StandalonePipelineSourceSaveFailed`로 멈춥니다. `false`면 열려 있을 때
  `StandaloneModelStillLoadedBeforeRun`으로 멈춥니다
- 각 활성 행이 아래 조합을 갖추었는가

```text
CoverageFilterMode      = ALL_CONTENT
CoverageBoundaryMode    = CUT_ONLY
CoverageFilterAction    = EXCLUDE
CoverageFilterRationale = (비어 있지 않은 사유)
```

## 2. 기본 실행

평소에는 `st_run_standalone_coverage_pipeline()`을 옵션 없이 부르고
`st_check_standalone_coverage()`로 검사합니다. 절차와 확인 방법은
[사용자 매뉴얼 5절](../user-manual.md#5-3단계--standalone-제출물)에, 옵션 전체는
[실행 명령 사전](execution-commands.md#st_run_standalone_coverage_pipeline)에
있습니다. 검사 코드의 자리별 뜻은 [6절](#6-한-화면-검사-비트)에 있습니다.

## 3. Action별 실행과 재개

긴 실행을 나눠서 하거나 다른 MATLAB 세션에서 이어서 하고 싶을 때 Action을 나눠
실행합니다.

```matlab
% EXECUTE 단독 실행은 재개용 aggregate Result를 기본 저장합니다.
info = st_run_standalone_coverage_pipeline('Action','EXECUTE');

% 새 세션에서 저장된 Result를 한 번 import해 패키징합니다.
st_run_standalone_coverage_pipeline('Action','PACKAGE', 'PipelineId', info.PipelineId);
st_run_standalone_coverage_pipeline('Action','SUMMARY', 'PipelineId', info.PipelineId);
```

| Action | 하는 일 |
| --- | --- |
| `PREPARE` | standalone export, Test Case를 standalone 모델로 재배선한 Test File 저장. **실행하지 않습니다** |
| `EXECUTE` | standalone export, Test Case 1회 실행, CVF 1회 등록, 모델이 열린 동안 report/metric/CVT 임시 증거 캡처 |
| `PACKAGE` | 임시 증거를 검증해 Model/Input/CVF/CVT/HTML/Test File을 최종 산출물로 승격 |
| `SUMMARY` | manifest 값에서 `CoverageSummary.xlsx` 생성 |
| `ALL` (기본) | `EXECUTE` → `PACKAGE` → `SUMMARY` 연속 실행 |

`PREPARE`는 `EXECUTE`가 실행 직전까지 하는 일만 하고 멈춥니다. 산출물은
`<PipelineRoot>/TestManager/<TopModel>.mldatx` 하나이고 standalone 모델은
`.work` 아래 실행 workspace에 남습니다. 실행 증거가 없으므로 같은 PipelineId에
`PACKAGE`나 `SUMMARY`를 부르면 `StandalonePipelinePrepareOnly`로 멈추고,
`latest.json`을 갱신하지 않아 `LATEST`가 되지 않으며,
`st_check_standalone_coverage`에 넘기면 `FAIL`입니다. 절차는
[11절](#11-test-file만-만들기-prepare)에 있습니다.

### `SaveTestResult`의 기본값이 Action마다 다른 이유

| Action | 기본값 | 이유 |
| --- | --- | --- |
| `ALL` | `false` | live Result를 그대로 PACKAGE에 넘기므로 export/import가 필요 없습니다 |
| `EXECUTE` | `true` | 다른 세션에서 재개하려면 Result를 파일로 남겨야 합니다 |
| `PACKAGE` / `SUMMARY` | 지정 불가 | 이미 만들어진 증거를 읽기만 합니다 |
| `PREPARE` | 지정 불가 | 실행하지 않으므로 저장할 Result가 없습니다 |

### 한 번만 실행할 수 있는 이유

lifecycle 횟수를 보존하기 위해 **각 PipelineId의 `PACKAGE`와 `SUMMARY`는 한 번만**
실행할 수 있습니다. 다시 만들려면 `st_run_from_stage`가 저장된 증거를 검증하고
**새 PipelineId**를 만듭니다.

증거가 없거나 바뀌었으면 재생성을 막고 `EXECUTE`부터 다시 실행하도록 안내합니다.
`.work` 폴더를 지웠거나 report 캡처 자체가 실패했다면 PACKAGE 재생성으로 복구할 수
없습니다. 절차는 [재시작](restart.md)에 있습니다.

> 예전 `RunMode`와 준비 옵션을 전달하면 새 Action API와 `st_run_from_harness`를
> 안내하는 migration 오류가 납니다.

## 4. 산출물

각 CUT 폴더(`{NUM}_UT_REQ_{TC_NAME}`)에는 다음만 둡니다.

- Harness 이름과 같은 파일 stem의 standalone 모델
- Signal Editor Input MAT (대상에 Input이 있을 때)
- `UT_REQ_{TC_NAME}.cvf`
- `UT_REQ_{TC_NAME}.cvt`
- Test Manager Coverage Results의 REPORT 화살표가 여는 원본 `UT_REQ_{TC_NAME}.html`
- target manifest

실행하지 못한 대상도 폴더는 만들어집니다.

파이프라인 root에는 복사된 Test File, pipeline manifest, JSONL lifecycle event log,
`CoverageSummary.xlsx`가 생성됩니다. `SaveTestResult=true`일 때만 aggregate Result가
추가됩니다.

`TestManager` 폴더에는 재배선된 MLDATX와
`open_standalone_coverage_test_manager.m` launcher가 함께 생성됩니다. launcher는
편의 기능이며 필수가 아닙니다.

제출물을 Test Manager에서 여는 방법은 [12절](#12-제출물-열기)에 있습니다.

### 일부러 만들지 않는 것

`FilteredResults.mldatx`, `coverage-metrics.mat`, `TestSummary.xlsx`, PDF와 별도 보조
Coverage HTML은 만들지 않습니다. `UT_REQ_{TC_NAME}.html`은 CUT별 원본 `cvhtml`
Coverage 보고서 하나만 보존하며, 렌더링에 필요한 부속 asset은 같은 폴더에 둡니다.

> 원본 Coverage HTML은 긴 실행 경로에 직접 만들지 않습니다. Windows의 legacy path
> 경계를 피하려고 짧은 writable scratch에서 report tree와 ZIP을 완성한 뒤 ZIP만
> package evidence 경로로 승격합니다. 압축 파일은 캡처 증거용이며 최종 HTML 대신
> 제출하는 파일이 아닙니다.

### 팀 제출 트리로 재배치

팀 내부 제출은 위 폴더를 파일 종류별 세 갈래(테스트 케이스·테스트 보고서·프로젝트)로
나눈 형태를 씁니다. `st_classify_standalone_results`가 파이프라인 폴더 옆에
`{TopModel}/`을 만들어 파일 이름을 바꾸지 않고 복사하며, 원본 폴더는 그대로 둡니다.
트리 구조와 옵션은 [사용자 매뉴얼 6절](../user-manual.md#6-4단계--팀-제출-트리)에
있습니다. 파이프라인에 `'ClassifyResults', true`를 주면 `ALL` 끝에 자동으로
재배치하며, 이때 재배치가 실패해도 파이프라인은 실패로 끝나지 않고 WARN만 남깁니다.

## 5. `CoverageSummary.xlsx`

`CoverageSummary` 시트의 열은 다음 순서로 고정합니다.

```text
NUM
CUT_NAME
CUT_PATH
Test Case Name
Harness Name
Decision Executed
Decision Total
Decision (%)
Execution Executed
Execution Total
Execution (%)
```

| 상황 | 표시 |
| --- | --- |
| 분모가 0이거나 값이 없음 | `N/A` |
| CVF로 모든 objective가 제외됨 | 유효한 `0/0`, `N/A` |
| CUT path 후보가 둘 이상 일치 | `AMBIGUOUS`로 실패 |

metric source는 Result coverage API와 standalone CUT path가 **정확히 하나** 일치할
것을 요구합니다. 실제 R2025b HTML Details와 대조하기 전 source 상태는
`PROVISIONAL`입니다.

## 6. 한 화면 검사 비트

```matlab
[code, summary, details] = st_check_standalone_coverage('PipelineId', info.PipelineId);
```

| 비트 | 검사 |
| --- | --- |
| B1 | manifest v2/v3, Action, Result 저장·재개 정책 또는 재생성 provenance, 주요 함수 중복 경로 |
| B2 | Harness명 = standalone 모델명 = `.slx` stem |
| B3 | SUT / iteration / input / assessment readback |
| B4 | `RunCount=1`, rerun 없음, lifecycle event 일치 |
| B5 | CVF 생성, rule/file/hash, Result 등록 1회 |
| B6 | 필수 패키지 존재와 금지 artifact 부재 |
| B7 | Decision/Execution scalar와 metric source |
| B8 | Summary 파일, 11개 열, CUT row 수 |
| B9 | 원본 model/Test File/Harness/Input/Excel 불변 |
| B10 | filter restore, model/path cleanup, CUT 폴더 격리 |

아직 적용할 수 없는 비트(예: `EXECUTE`까지만 끝난 상태의 PACKAGE/SUMMARY 비트)는
`-`로 표시하고 전체 상태는 `PARTIAL`을 반환합니다.

checker는 Result import, model load/save, Test Manager clear, 파일 생성을 하지
않습니다. 검사 결과 화면은 최대 20줄이고, 직접 부르면 실행 로그 틀 4줄(`==>`,
`<==`, `log:` 두 줄)이 더 붙습니다. 다른 명령 안에서 부르면 틀이 붙지 않습니다. 전체
CUT 결과는 `details` 표에 있습니다.

> B9는 **현재** 원본이 그대로인지 봅니다. 원본 모델이 나중에 바뀐 뒤 과거 결과를
> 재생성하면, 재생성 자체가 성공해도 B9는 실패할 수 있습니다.

## 7. 예외가 난 대상

시뮬레이션 예외는 `ExecutionStatus=EXCEPT`로 남습니다.

- 만들 수 있었던 Harness와 Input은 패키징합니다.
- 없는 CVT/HTML/metric을 만들어 PASS로 위장하지 않습니다.
- 따라서 그런 결과의 PACKAGE/SUMMARY 또는 checker 판정은 `FAIL`/`PARTIAL`일 수
  있습니다.
- Harness와 Input이 만들어지기 **전에** 실패한 경우에는 보존을 보장하지 않습니다.
- 모든 비트가 1이어도 `EXCEPT` 대상이 있으면 `PASS`가 아니라 `PARTIAL`입니다.
  커버리지 누락을 녹색 코드 뒤에 숨기지 않기 위한 의도적 정책입니다.
- `EXCEPT` 대상이 있어도, 실행은 끝났지만 Test Case 판정이 Passed가 아닌
  대상(`ExecutionStatus=WARN`)은 B1을 깨지 않습니다. 설명되지 않은 `FAIL`이나
  `SKIP`은 여전히 B1을 0으로 만듭니다.

필터가 적용돼 objective가 없어진 유효한 `0/0`, `N/A`와 Coverage 객체 자체의 누락은
서로 다른 상황입니다.

## 8. dependency 수집 범위

standalone export는 Top Model 전체가 아니라 **생성된 standalone Harness 모델의
dependency만** 수집합니다.

- 대상과 무관한 Top Model branch의 미해결 dependency는 export를 막지 않습니다.
- 반대로 standalone `.slx` 자체가 필요한 파일을 찾지 못하면, 받는 PC에서 열리지
  않는 제출물을 만들지 않도록 export를 중단합니다.

## 9. 완료 기준

정적 테스트만으로 runtime 완료를 주장하지 않습니다. 실제 MATLAB R2025b에서
`tests/integration/test_standalone_coverage_pipeline_runtime.m`과 multi-CUT
acceptance를 실행하고 최종 checker 결과 `1111111111 PASS`를 확보해야 완료로 봅니다.

실패 원인 확인 방법은 [10절](#10-실패-상세-확인)과
[문제 해결 6장](troubleshooting.md#6-standalone-제출물-오류)에 있습니다.

## 10. 실패 상세 확인

`info`가 정상적으로 반환되지 않았다면 PipelineId를 직접 넣어 manifest를 읽습니다.

```matlab
st_setup
cfg = st_config();
pipelineId = '여기에_PipelineId';

[m, manifestPath] = st_load_standalone_pipeline_manifest( ...
    cfg.StandaloneCoverageRootDir, pipelineId);
fprintf('Manifest: %s\n', manifestPath);

T = struct2table(m.Targets);
disp(T(:, {'TestCaseName','ExecutionStatus','PackageEvidenceStatus', ...
    'PackageStatus','Message'}));

for k = 1:numel(m.Targets)
    if ~isfield(m.Targets, 'PackageFailure'), continue; end
    f = m.Targets(k).PackageFailure;
    if isempty(f.Identifier), continue; end
    fprintf('\n[%03d] %s\n%s: %s\n', k, m.Targets(k).TestCaseName, ...
        f.Identifier, f.Message);
end
```

오류 식별자별 대처는 [문제 해결](troubleshooting.md)에 있습니다.

## 11. Test File만 만들기 (`PREPARE`)

standalone 모델·Input·CVF는 이미 있고, 그 모델들을 가리키는 **Test Manager
파일(`.mldatx`)만** 새로 필요할 때 씁니다. 실행 직전까지만 하고 멈추므로
시뮬레이션과 커버리지 수집은 하지 않습니다.

```matlab
st_setup

info = st_run_standalone_coverage_pipeline('Action', 'PREPARE');
disp(info.TestManagerFile)
```

전제 조건은 1절과 같습니다. 원본 Top Model은 여기서도 파이프라인이 저장하고
닫습니다.

하는 일은 `EXECUTE`의 앞부분과 같습니다. standalone 모델을 export하고, 복사한
Test File의 모든 Test Case를 **Harness SUT에서 standalone 모델 SUT로 다시
연결**해 저장한 뒤, 그 파일을 다음 위치에 복사합니다.

```text
<StandaloneCoverageRootDir>/<PipelineId>/TestManager/<TopModel>.mldatx
```

이 Test File은 standalone 모델을 **이름으로** 참조합니다. 같은 이름의 모델이
있는 폴더를 path에 올린 뒤 열면 Test Manager에서 바로 실행할 수 있습니다.

```matlab
addpath('<standalone 모델 폴더>');            % 이미 갖고 있는 모델
tf = sltest.testmanager.load(info.TestManagerFile);
sltest.testmanager.view
```

방금 export한 모델을 쓰려면 경로는 `info.Targets(k).StandaloneModelFile`에 있습니다.
`<PipelineId>/.work/.../workspace/standalone/` 아래입니다.

주의할 점입니다.

- 실행 증거가 없으므로 같은 PipelineId에 `PACKAGE`나 `SUMMARY`를 부르면
  `StandalonePipelinePrepareOnly` 오류로 멈춥니다. 커버리지를 모으려면
  `Action='ALL'`을 새로 실행합니다.
- `latest.json`을 갱신하지 않습니다. `st_check_standalone_coverage()`나
  `st_open_standalone_test_manager()`의 `LATEST`는 마지막 `EXECUTE`/`ALL`을
  계속 가리킵니다. PREPARE 결과를 checker에 넘기면 `FAIL`이 정상입니다.
- `SaveTestResult`는 지정할 수 없습니다. 실행이 없어 저장할 Result가 없습니다.

## 12. 제출물 열기

파이프라인을 돌린 PC(저장소와 `runtime_target.mat`이 있는 곳)에서는
`st_open_standalone_test_manager` 하나로 엽니다. manifest를 읽어 대상 폴더를 전부
`addpath`하고, 재배선된 Test File을 열고, Test Manager 창을 엽니다. 모델은 로드하지
않고 파일도 만들거나 바꾸지 않습니다. 옵션은
[실행 명령 사전](execution-commands.md#st_open_standalone_test_manager)에 있습니다.

```matlab
st_open_standalone_test_manager                                  % 가장 최근 제출물
st_open_standalone_test_manager('PipelineId', '여기에_PipelineId')
```

제출물 폴더를 다른 위치로 옮겼거나 다른 PC라면 manifest의 절대 경로가 맞지 않으므로
아래 수동 방법을 씁니다.

### 수동으로 열기

launcher를 반드시 사용할 필요는 없습니다. **Model 폴더 버튼으로 standalone `.slx`를
선택하는 방식**을 지원합니다. 이 파일은 원본 Top Model의 내부 Harness가 아니라 독립 Model입니다.
Test Harness 항목에는 원본 Top Model/Harness 연결을 다시 지정하지 않습니다.

### 현재 PC에서 모든 대상 폴더 연결

```matlab
st_setup
cfg = st_config();
pipelineId = '여기에_PipelineId';   % 생략하려면 'LATEST'
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,pipelineId);
for k = 1:numel(m.Targets)
    folder = m.Targets(k).OutputDirectory;
    assert(isfolder(folder), 'Packaged target folder is missing.');
    addpath(folder);
end
sltest.testmanager.TestFile(m.TestManagerFile);
sltest.testmanager.view;
```

Test Manager에서 각 TC의 Model 폴더 버튼 → 해당 대상 폴더의 `.slx` 선택 → Model 열기.
Signal Editor 파일은 모델 옆의 Input MAT을 사용합니다. 동명 다른 모델이 로드돼 있으면
사용자가 저장/닫기 후 다시 선택해야 합니다. CVF 경로도 옆의
`UT_REQ_{TC_NAME}.cvf`인지 확인하십시오.
경로 설정은 MATLAB 세션마다, 다른 PC에서도 필요합니다. `savepath`를 강제하지 않습니다.

전체 결과 폴더를 다른 위치로 복사했다면 manifest의 예전 절대 경로를 그대로 쓰지 말고
새 위치의 TC 폴더들을 Add to Path 한 뒤 `TestManager/*.mldatx`를 직접 여십시오.
모델·Input·CVF·CVT·HTML 부속 파일을 함께 보관합니다. `.work` 없이 제출 파일을 여는 것과
PACKAGE 재생성이 가능한지는 서로 다른 조건입니다.

### 선택 사항: 자동 연결 launcher

```matlab
st_setup
cfg = st_config();
pipelineId = '여기에_PipelineId';
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,pipelineId);
assert(isfile(m.TestManagerLauncher));
run(m.TestManagerLauncher);
```

launcher는 모델 경로와 CVF readback을 준비하는 편의 기능입니다. launcher에서
filter readback 오류가 나면 해당 오류를 숨기지 말고 CVF 파일·대상 model·저장 경로를 확인합니다.
이전에 한 번 열었다고 다른 PC의 MATLAB 경로까지 자동으로 연결되지는 않습니다.

### CVF 내용을 볼 때 이름이 n/a로 나오는 경우

정상 동작이며 CVF가 잘못 만들어진 것이 아닙니다. 규칙은 블록을 경로가 아니라
**SID**로 지정하고, 뷰어의 Name 칸은 그 SID를 **로드된 모델에 대조해서** 이름을
풀어냅니다. 모델이 열려 있지 않으면 풀 수가 없어 `n/a`로 표시됩니다.

해당 CVF를 만든 standalone 모델을 먼저 열면 이름이 나옵니다. 그 모델은 CVF 바로
옆에 `{HarnessName}.slx`로 들어 있습니다.

```matlab
folder = '여기에_대상_폴더';
model = dir(fullfile(folder, '*.slx'));
load_system(fullfile(folder, model(1).name));
```

이 상태에서 CVF를 열면 Name 칸이 채워집니다. 규칙이 가리키는 블록을 명령으로
확인하려면 아래를 씁니다.

```matlab
f = slcoverage.Filter(fullfile(folder, '여기에_CVF_파일명'));
r = getRules(f);
for k = 1:numel(r)
    fprintf('%s\n', getfullname(Simulink.ID.getHandle(char(r(k).Selector.Id))));
end
```

**원본 Top Model을 열어서는 안 됩니다.** standalone 모델은 원본의 SID를 재사용하지
않으므로, 그 CVF가 만들어진 바로 그 standalone 모델이어야 이름이 풀립니다.
launcher가 Test Manager를 열기 전에 모든 standalone 모델을 로드하는 이유가 이것입니다.

rule의 rationale이 `none`으로 보이는 것도 의도된 값입니다. 규칙 분류는 rationale
문구가 아니라 selector 경로로 판정하므로 진단에 영향을 주지 않습니다.
