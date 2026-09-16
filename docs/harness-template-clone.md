# Template Harness clone

이미 잘 만들어 둔 Harness 하나를 본떠 다른 CUT의 Harness를 만드는 기능입니다.
입력 구성이나 Assessment 구조가 비슷한 CUT이 여러 개일 때, 매번 처음부터 만들지
않고 검증된 Template을 복제합니다.

## 1. 설정

관리 Excel의 해당 행에 다음 세 열을 적습니다.

```text
TestPreparationSource : HARNESS_CLONE
SourceCUTPath         : TEMPLATE_MODEL/TemplateCUT
SourceHarnessName     : TemplateHarness
```

| 열 | 역할 |
| --- | --- |
| `TestPreparationSource` | `HARNESS_CLONE`이면 복제, `EXISTING`(기본, 빈 값 포함)이면 일반 생성 |
| `SourceCUTPath` | 복제할 원본 Harness가 붙어 있는 CUT의 **모델 이름을 포함한 전체 경로** |
| `SourceHarnessName` | 복제할 Template Harness의 이름 |

두 `Source*` 열은 Template을 고르는 데만 씁니다. 대상의 `CUTPath`, `HarnessName`,
`TestCaseName`은 기존 규칙을 그대로 따릅니다. 일반 행은 세 열을 비워 두거나
`TestPreparationSource`를 `EXISTING`으로 둡니다.

`HARNESS_IMPORT`는 폐지되었습니다. 그 값이 남아 있으면 오류로 중단하며, 자동으로
`HARNESS_CLONE`으로 바꾸지 않습니다.

## 2. 전제 조건

- 원본 모델을 MATLAB 경로에서 로드할 수 있어야 합니다.
- Template은 저장하고 닫아 두십시오.
- Template을 변경할 수 있는 행은 활성 대상 목록에서 제외하십시오.

원본과 대상의 상위 모델이 달라도 되고 CUT 이름이 달라도 됩니다. 다만 컴파일된
포트 순서·이름·타입·차원·버스 정의·샘플 시간을 기존 인터페이스 분석기로
비교하며, 지원하지 않는 물리/event 포트나 호환되지 않는 인터페이스는 **그 CUT만**
실패로 보고합니다.

## 3. 처리 순서

1. 기존 Harness를 확인합니다. 기본값 `cfg.OverwriteHarness=false`는 기존 Harness가
   있으면 복제와 입력·Assessment 보정을 건너뜁니다.
2. Template의 Signal Editor, Test Assessment, 입력 MAT을 확인합니다.
3. `sltest.harness.clone`에 `DestinationOwner=대상 CUT 전체 경로`와 기존 Harness
   이름을 전달합니다. Harness 파일 복사나 블록 재구축은 쓰지 않습니다.
4. 입력 MAT을 `result/harness_clone/<transaction>/input.mat`으로 분리합니다.
   **이 파일은 실행에 필요한 산출물이므로 그 Harness를 쓰는 동안 보존해야 합니다.**
5. 기존 SLDV 준비, Signal Editor 매칭, Assessment verify 생성, Harness 설정 함수를
   대상별로 실행합니다. SLDV `OFF`/`FILE`/`GENERATE`와 기대값 갱신 설정은 그대로
   유지됩니다.
6. 복제 대상의 Step1은 Action 없이 `after(ExpectedValueSampleTime, sec)`로 Step2에
   진입합니다. 기본 0.01초이며 Step2 verify는 대상 출력 기준으로 만듭니다. 일반
   대상의 `VerifyAtSampleTimeOnly` 동작은 바뀌지 않습니다.
7. Harness update, 저장, 닫기를 마치고 다음 CUT을 처리합니다.

`st_create_harnesses`를 직접 호출해도 복제 대상의 입력·Assessment 보정까지
수행합니다. `st_run_after_harness`는 기존 Harness의 후속 준비 진입점이므로, 새 복제가
필요하면 `st_run_from_harness`를 쓰십시오. Test Manager는 기존 생성기를 그대로 쓰며
`cfg.OverwriteTestFile` 설정은 Harness 교체와 독립입니다.

## 4. 라이브러리 링크 보호

원본 Template 또는 대상 CUT이 library-linked block이면, 각 Harness를 처음 열기 전에
동기화 모드를 `SyncOnOpen`으로 바꿉니다. 그래야 Harness를 닫을 때 CUT 복사본이 원본
모델로 push되지 않습니다.

Template close, clone, 대상의 첫 close, 최종 update/close 전후로
`StaticLinkStatus`와 `ReferenceBlock`을 비교합니다. 변경이 감지되면 자동 rollback이
손상 상태를 저장하지 않도록 즉시 중단합니다.

`FILE+SLDV` 또는 `GENERATE`가 비-Atomic linked CUT을 대상으로 하면
`TreatAsAtomicUnit`을 자동으로 바꾸지 않습니다. 원본 library block을 Atomic으로 만든
뒤 instance link를 갱신해야 합니다. `FILE+MAT`는 Atomic 변환이 필요 없습니다.

## 5. 실패와 복구

### `OverwriteHarness=true`일 때

기존 Harness를 같은 owner의 임시 recovery Harness로 복제해 저장한 뒤 교체합니다.
후처리가 실패하면 recovery Harness에서 원래 이름으로 복원하고 SLDV manifest도
복원합니다.

### 신규 생성이 실패했을 때

불완전한 Harness를 제거합니다.

### 복구까지 실패했을 때

로그에 recovery Harness 이름과 transaction 폴더를 남깁니다. **실패한 transaction의
파일은 진단을 위해 보존하며 자동으로 삭제하지 않습니다.**

### 다른 CUT은 어떻게 되는가

복제에 실패한 대상은 이후 준비, Test Manager 생성, 실행에서 제외합니다. **다른
CUT은 계속 처리합니다.** 실패 내역은 `HarnessCreateResult`와
`reportInfo.CloneFailures`에서 확인합니다. 사용자 중단(`Ctrl+C`)은 그대로
전파합니다.

## 6. 검증

MATLAB R2025b와 필요한 제품·라이선스가 있는 PC에서 실행합니다.

```matlab
st_setup
runtests('tests/unit/test_harness_clone.m')
runtests('tests/unit/test_incremental_workflow.m')
runtests('tests/unit/test_export_test_specification.m')
runtests('tests/integration/test_harness_clone_runtime.m')
runtests('tests/integration/test_library_link_harness_runtime.m')
```

통합 테스트는 임시 프로젝트와 서로 다른 두 모델을 만들며, 원래 프로젝트의 관리
Excel과 runtime 설정을 수정하지 않습니다. 검사하는 항목은 소유자/CUT 내용, 입력
독립성, Assessment, 중간 실패 후 다음 대상 진행, 기존 Harness 건너뜀, 후처리 실패
복구, Test Manager 연결입니다.

내부/외부 Harness, 버스·배열, SLDV `FILE`/`GENERATE`, 실제 실행과 bundle 재실행은
실제 R2025b 환경에서도 확인해야 합니다. 현재 개발 PC에서는 MATLAB runtime 검증을
수행하지 않았습니다.
