# 문제 해결

오류가 났을 때 무엇을 먼저 볼지, 자주 나오는 오류가 무슨 뜻인지 정리했습니다.

## 1. 실패했을 때 확인 순서

무슨 오류인지 모르겠다면 이 순서대로 보십시오.

1. **Command Window의 마지막 `[단계/대상] FAIL` 줄** — 어느 단계의 몇 번째 대상에서
   멈췄는지 알려 줍니다.
2. **`result/reports/WorkflowPlanResult.ini`** — 이번 실행이 어떤 단계를 하려고
   했는지 보여 줍니다.
3. **해당 단계의 INI 결과 파일**의 `Status`와 `Message` 열.
4. **`PreparationMode='FORCE'`가 필요한 상황인지 판단** — 캐시된 준비 결과가 실제
   모델과 어긋났을 수 있습니다.
5. `PER_CUT` 실행이면 **`result/per_cut_runs/{run-id}/logs/execution.log`**.

단계별 INI 파일 이름은 다음과 같습니다.

| 단계 | 결과 파일 |
| --- | --- |
| CUT 경로 사전 검증 | `PreValidationResult.ini` |
| 기존 Harness 검증 | `ValidationResult.ini` |
| Harness 생성 | `HarnessCreateResult.ini` |
| SLDV 준비 | `SldvGenerationResult.ini`, `SldvScenarioResult.ini` |
| Harness 설정 | `HarnessConfigResult.ini` |
| Signal Editor | `SignalEditorResult.ini` |
| Assessment | `AssessmentResult.ini` |
| Test Manager | `TestManagerResult.ini` |
| Scenario 정렬 | `ScenarioAlignmentResult.ini` |

## 2. 실행 전 점검 명령

실행하기 전에 막힐 곳을 미리 찾고 싶다면 다음 명령을 쓰십시오. 세 명령 모두
**모델과 Test File을 저장하거나 변경하지 않습니다.**

```matlab
% 1. Excel에 적은 CUT 경로가 실제로 존재하는지
st_pre_validate_targets

% 2. 이 단계부터 실행해도 되는 상태인지
[ready, checks] = st_check_readiness('Workflow','FROM_HARNESS','FromStage','HARNESS');
disp(checks)

% 3. 환경·실행 결과·필터 상태를 18비트 코드로
summary = st_check_actual_system();
```

## 3. 준비 단계 오류

### `SldvLinkedCUTRequiresAtomic`

**뜻:** `FILE+SLDV` 또는 `GENERATE` 대상이 Atomic Subsystem이 아닌데, 라이브러리에
링크되어 있어 이 도구가 자동으로 바꿀 수 없습니다.

**왜 자동으로 안 바꾸는가:** 링크된 블록을 고치면 그 변경이 원본 라이브러리로 퍼져
같은 라이브러리를 쓰는 다른 모델까지 바뀝니다.

**대처:**
1. 원본 라이브러리 블록을 열어 `TreatAsAtomicUnit`을 `on`으로 바꿉니다.
2. 모델에서 링크를 갱신합니다.
3. 다시 실행합니다.

일반 `FILE+MAT` 입력은 Atomic이 아니어도 됩니다. SLDV 분석을 돌리지 않기 때문입니다.

### `HarnessChangedLibraryLink`

**뜻:** Harness를 만들거나 복제하는 과정에서 CUT의 `StaticLinkStatus` 또는
`ReferenceBlock`이 달라졌습니다.

**대처:** **모델을 저장하지 마십시오.** 저장하면 링크가 깨진 상태가 굳습니다.
모델을 저장하지 않고 닫은 뒤 원본에서 다시 여십시오. 반복되면 해당 CUT의 라이브러리
링크 상태를 먼저 정리해야 합니다.

### `SignalEditorBlockMissing`

**뜻:** Harness 안에 Signal Editor 블록이 없습니다.

**대처:** `SldvMode=OFF` 대상이라면 입력 Scenario 없이 계속 진행하며 WARN만
남습니다. 정상입니다. `FILE`이나 `GENERATE` 대상이라면 Harness가 입력을 받을
구조가 아니라는 뜻이므로 Harness를 다시 만들어야 합니다.

### `SignalEditorActiveScenarioInvalid`

**뜻:** Signal Editor 블록은 있지만 MAT 파일이나 ActiveScenario 설정이 손상됐습니다.

**대처:** Harness를 열어 Signal Editor 블록의 파일 경로와 선택된 Scenario를
확인하십시오. 파일이 다른 위치로 옮겨졌거나 지워졌을 수 있습니다.

### `MatHarnessInterfaceMismatch`

**뜻:** `DataFileFormat=MAT`으로 지정한 Dataset의 입력 구성이 Harness의 입력
인터페이스와 다릅니다.

**대처:** Dataset과 Harness의 입력 **개수·순서·이름·자료형·차원**이 모두 정확히
같아야 합니다. 여러 Dataset을 쓸 때는 Dataset끼리도 서로 같아야 합니다.

### `UnsupportedDataFileFormat`

**뜻:** `DataFileFormat` 값이 `SLDV`도 `MAT`도 아닙니다.

**대처:** 두 값 중 하나로 고치십시오. 이 도구는 확장자로 형식을 추측하지 않습니다.

### SLDV MAT을 찾을 수 없음

**대처:** `SldvDataFile`의 상대 경로 기준은 MATLAB의 Current Folder가 아니라
**`TestManagement.xlsx`가 있는 폴더**입니다. 가장 흔한 실수입니다.

### 준비가 이상하게 오래 걸린다

Harness 생성은 모델 컴파일을 포함하고, SLDV `GENERATE`는 분기를 탐색하므로 CUT 하나에
수 분 이상 걸릴 수 있습니다. 정상입니다.

지금 어디서 기다리는지는 마지막 `START` 로그로 확인합니다. blocking API 안의 진행률은
MATLAB이 알려 주지 않으므로 퍼센트를 표시할 수 없습니다.

`cfg.CheckSharedSignalEditorDataFile=true`로 켜 두면 모든 Harness를 열고 닫으므로
크게 느려집니다. 기본값은 `false`입니다.

## 4. 실행과 커버리지 오류

### `CoverageFilterRestoreFailed`

**뜻:** CUT 실행이 끝난 뒤 원래 커버리지 필터 설정으로 되돌리지 못했습니다.

**왜 전체가 멈추는가:** 복원되지 않은 필터가 남으면 다음 CUT의 커버리지 수치가
오염됩니다. `ContinueOnFailure=true`여도 이 오류만은 전체 실행을 즉시 중단합니다.

**대처:** Test File을 열어 Test File / Test Suite / Test Case 각 수준의 Coverage
Settings에 남아 있는 필터를 확인하고 손으로 정리한 뒤 다시 실행하십시오.

### `ResultCoverageDataMissing`

**뜻:** 테스트는 실행됐는데 결과에 커버리지 객체가 없습니다.

**대처:** Test Case의 Coverage Settings에서 `RecordCoverage`가 켜져 있는지, Simulink
Coverage 라이선스가 실제로 checkout되는지 확인하십시오.

### `ResultCoverageFilterRequired`

**뜻:** `ResultFilterMode='POST_RUN_REQUIRED'`인데 결과에 CVF를 등록하지 못했습니다.

**대처:** standalone pipeline에서만 쓰는 모드입니다. 일반 실행에서 이 오류가 보이면
`ResultFilterMode`를 기본값 `'DURING_RUN'`으로 두십시오.

### 커버리지가 `0/0` 또는 `N/A`로 나온다

**정상일 수 있습니다.** 필터가 objective를 전부 제외했거나 원래 objective가 없는
CUT이면 분모가 0이 되어 백분율을 계산할 수 없습니다. 이것과 "커버리지 수집 자체가
실패한 경우"는 다릅니다. 후자는 값이 아예 비어 있습니다.

### 커버리지가 낮은데 테스트는 통과다

의도된 동작입니다. 커버리지 미달은 보고용이며 테스트 판정을 바꾸지 않습니다.
부족한 분기는 보고서에서 확인하고 테스트를 추가할지 판단하십시오.

### CVF 뷰어에서 이름이 `n/a`로 보인다

**정상입니다.** CVF 규칙은 블록을 경로가 아니라 SID로 가리키고, 뷰어는 그 SID를
**로드된 모델에 대조해서** 이름을 풉니다. 모델이 열려 있지 않으면 풀 수 없습니다.

해당 CVF를 만든 standalone 모델을 먼저 여십시오. 그 모델은 CVF 바로 옆에 있습니다.
**원본 Top Model을 열어서는 안 됩니다.** standalone 모델은 원본의 SID를 재사용하지
않습니다. 자세한 설명은 [결과 열기](manual/open-results.md)에 있습니다.

rule의 rationale이 `none`으로 보이는 것도 의도된 값입니다. 규칙 분류는 rationale
문구가 아니라 selector 경로로 판정합니다.

## 5. Test Manager 오류

### 같은 이름의 모델이 이미 열려 있다

MATLAB은 같은 이름의 모델을 두 개 로드할 수 없습니다. 이 도구는 사용자가 연 모델을
강제로 닫지 않습니다.

**대처:** 이미 열려 있는 모델을 저장하고 닫은 뒤 다시 실행하십시오. 확실하게 하려면
MATLAB을 새로 시작하는 것이 가장 빠릅니다.

### Test Case가 중복으로 생겼다

`TestCaseName`이 기존 Test File의 Test Case와 다르면 새로 추가됩니다. 기존 이름과
정확히 맞추거나, 전체를 다시 만들려면 `cfg.OverwriteTestFile=true`로 바꾸십시오.
`true`는 사람이 Test Manager에서 직접 고쳐 둔 설정을 전부 날립니다.

### Scenario와 Iteration 개수가 맞지 않는다

`ALIGNMENT` 단계에서 잡힙니다. 입력 Scenario가 3개면 Iteration도 3개여야 합니다.
입력 MAT을 바꾼 뒤 Test Manager 단계를 다시 실행하지 않았을 때 자주 납니다.

**대처:**

```matlab
st_run_after_harness('PreparationMode','FORCE','FromStage','SLDV');
```

## 6. Standalone 제출물 오류

### `StandaloneCUTIdentificationFailed`

**뜻:** standalone 모델로 내보낸 뒤 그 안에서 CUT을 다시 찾지 못했습니다.

**대처:** 오류 메시지의 `Candidates=` 항목에 후보 블록의 이름·타입·링크 상태가
들어 있습니다. 그 줄 전체를 보존하십시오. CUT이 라이브러리 링크 **안쪽**에 있는
경우에 자주 발생했으며, 링크와 마스크를 넘어 탐색하도록 수정되어 있습니다.

현재 CUT이 링크 안에 있는지 직접 확인하려면 (`n1`이 `n0`보다 크면 링크된 CUT입니다):

```matlab
src = '여기에_CUT_경로';
n0 = numel(find_system(src,'SearchDepth',1,'Type','Block'))
n1 = numel(find_system(src,'SearchDepth',1, ...
    'FollowLinks','on','LookUnderMasks','all','Type','Block'))
```

옵션 이름은 `FollowLinks`와 `LookUnderMasks`입니다. 철자가 틀리면 `find_system`이
오류 없이 블록 필터로 해석해 `0`을 돌려주므로, `n1=0`이면 오타를 의심하십시오.

### `ExecutionStatus=EXCEPT`

**뜻:** 시뮬레이션 중 예외가 발생해 그 대상이 끝까지 실행되지 못했습니다.

**정상 동작:** 만들 수 있었던 Harness와 Input은 그대로 보존합니다. 없는 CVT/HTML을
가짜로 만들어 PASS로 위장하지 않습니다. 그래서 이런 결과의 checker 판정은
`FAIL` 또는 `PARTIAL`이 됩니다.

Harness와 Input이 만들어지기 **전에** 실패한 경우에는 보존을 보장하지 않습니다.

### `StandalonePipelineActionAlreadyStarted`

**뜻:** 같은 `PipelineId`로 `PACKAGE` 또는 `SUMMARY`를 이미 한 번 실행했습니다.

**왜 막는가:** 실행 횟수 이력을 보존하기 위해 각 Action은 PipelineId당 한 번만
허용합니다.

**대처:** 다시 만들려면 `st_run_from_stage`를 쓰십시오. 저장된 증거를 검증한 뒤
**새 PipelineId**로 재생성합니다. [재시작](manual/restart.md)에 절차가 있습니다.

### `.work` 폴더를 지웠는데 PACKAGE를 다시 만들고 싶다

불가능합니다. PACKAGE 재생성은 실행 당시 캡처한 증거를 필요로 합니다. `EXECUTE`부터
다시 실행해야 합니다.

### 경로가 너무 길다는 오류

standalone pipeline은 폴더를 여러 겹 만들기 때문에 저장소가 깊은 경로에 있으면
Windows의 260자 제한에 걸립니다.

**대처:**

```matlab
st_set_standalone_coverage_root('D:\st_out')
```

짧은 경로를 지정하면 `runtime_target.mat`에 로컬로 저장됩니다.

## 7. 명세서 추출 오류

### `SpecificationUnsaved`

**뜻:** 모델·Harness·Test File 중 저장되지 않은 것이 있습니다.

**대처:** 전부 저장하고 실행 중인 모델을 멈춘 뒤 다시 실행하십시오.

### `SpecificationSourceChanged`

**뜻:** 추출하는 동안 원본 파일의 SHA-256이 바뀌었습니다.

**대처:** 다른 작업이 같은 파일을 건드리고 있지 않은지 확인하십시오.

### `SpecificationOutputExists`

**뜻:** `OutputFile`로 지정한 파일이 이미 있습니다. 덮어쓰지 않습니다.

**대처:** 다른 이름을 지정하거나 기존 파일을 옮기십시오.

### `step2 없음` / `verify 없음`으로 나온다

`VerifyMode` 기본값 `STEP2`는 각 시나리오의 **직계** Step 2만 읽습니다.
`parent.step_2` 같은 하위 스텝이나 다른 번호의 스텝으로 대체하지 않습니다.

모든 스텝을 보려면:

```matlab
[T, file] = st_export_test_specification('VerifyMode','ALL_STEPS_COLUMNS');
```

### 셀 내용이 `OverflowDetails` 참조로 바뀌었다

Excel 셀의 문자 수나 줄바꿈 수 한도를 넘었습니다. 전체 내용은 `OverflowDetails`
시트에 순번별로 나뉘어 있습니다. 특히 `DecisionBlockScope='ALL'`에서 Lookup 테이블이
많은 CUT에 자주 발생합니다.

## 8. 검증(`st_verify_all`) 오류

### `RUNTIME_TARGET` 또는 `CURRENT_STRUCTURE`가 `BLOCKED`

```matlab
st_select_target_model
cfg = st_require_runtime_target();
```

### `CURRENT_TEST_FILE`이 `BLOCKED`

Test File이 아직 없습니다. 기존 Harness가 있으면 `st_run_after_harness`,
없으면 `st_run_from_harness`를 먼저 실행해 Test File을 만드십시오.

### 제품 또는 라이선스가 `BLOCKED`

`Environment` 시트에서 `Installed`와 `Licensed`를 구분해 보십시오.

| 상태 | 의미 |
| --- | --- |
| `Installed=false` | 그 MATLAB 제품이 설치되어 있지 않습니다 |
| `Licensed=false` | 라이선스 구성을 확인해야 합니다 |
| 둘 다 `true`인데 실행 중 실패 | 라이선스 서버 또는 동시 사용자 수 문제입니다 |

### `SOURCE_UNCHANGED`가 `FAIL`

검증 중에 원본 파일이 바뀌었습니다. **자동으로 되돌리지 마십시오.**
`Checks.EvidencePath`와 source inventory로 어떤 파일이 바뀌었는지 먼저 식별하십시오.

### 수동 증거가 `BLOCKED`

순서대로 확인하십시오.

1. JSON에 6개 `CheckId`가 모두 있는가
2. `Status`가 `PASS` 또는 `FAIL`인가
3. `VerifiedBy`, `VerifiedAt`이 비어 있지 않은가
4. `EvidencePaths`의 파일이 실제로 존재하는가
5. `TargetFingerprint`가 현재 값과 같은가

모델·Test File·Excel을 저장하면 fingerprint가 바뀌므로 기존 증거가 무효가 됩니다.

## 9. Excel 접근 문제

관리 환경에서 workbook을 열지 못할 때, 원본을 바꾸지 않는 진단을 실행하십시오.

```matlab
st_diagnose_excel_access
st_diagnose_excel_access(true)   % 임시 workbook 쓰기까지 확인
```

결과는 `result/ExcelAccessDiagnostic.json`에 저장됩니다. `true`를 줘도 원본
workbook은 저장하지 않고, 같은 폴더에 버려도 되는 workbook을 하나 만들어 쓰기
가능 여부만 확인합니다.

## 10. 중간에 중단했을 때 (`Ctrl+C`)

1. 열려 있는 Harness와 모델의 Dirty 상태를 확인합니다.
2. 저장할지 버릴지 판단합니다. **확신이 없으면 저장하지 마십시오.**
3. 다시 실행합니다. 증분 checkpoint는 **성공한 단계만** 재사용하므로 중단된 단계는
   다시 실행됩니다.

## 11. 상태를 초기화하고 싶을 때

정리 명령은 기본적으로 dry-run이며, 무엇을 지울지 보여 주기만 합니다.

```matlab
plan = st_cleanup_results('Scope','STATE');              % 계획만 보기
plan = st_cleanup_results('Scope','STATE','Apply',true); % 실제 삭제
```

| 상황 | Scope |
| --- | --- |
| 증분 캐시가 실제 모델과 어긋난 것 같다 | `STATE` |
| 단계별 INI 결과만 지우고 싶다 | `REPORTS` |
| SLDV 생성 데이터를 다시 만들고 싶다 | `SLDV` |
| PER_CUT 실행 결과를 비우고 싶다 | `PER_CUT_RUNS` |
| 전부 | `ALL` |

모델, Excel, `runtime_target.mat`, `.mldatx`와 `result/` 밖의 사용자 SLDV MAT은
대상에서 **선택되지 않습니다.** `Apply=true`의 폴더 삭제는 재귀적이며 복구되지
않을 수 있습니다.

## 12. 상태를 전달할 때

문의하거나 기록을 남길 때는 다음을 함께 전달하십시오.

- 오류 식별자 전체 (`simtest:`로 시작하는 부분)와 stack
- `SYSTEM-CHECK-v1` 또는 `CVF-CHECK-v2`로 시작하는 출력 줄 전체
- `st_check_actual_system`의 `summary.Environment`, `summary.Run`, `summary.CVF` 표
- standalone이면 `PipelineId`와 pipeline manifest
- 재시작 관련이면 readiness 표

업무 경로나 CUT 이름이 들어간 증거는 저장소에 커밋하지 말고 승인된 위치에
보관하십시오.
