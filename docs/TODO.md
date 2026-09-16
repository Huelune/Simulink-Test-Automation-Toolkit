# TODO와 보류된 결정

구현이 끝난 항목과, 아직 결정되지 않았거나 runtime 검증이 남은 항목을 구분합니다.
`[x]`는 구현과 정적 검토가 끝난 것이며 **R2025b 인증 완료를 뜻하지 않습니다.**

## 안전성과 기대값

- [ ] `REVIEW` 모드의 출력 형식, 후보 저장 방식, diff 표시, 승인 명령, 거부 동작을
      정의한다.
- [ ] 승인된 baseline을 Git에 둘지, artifact 저장소에 둘지, 프로젝트별 외부
      디렉터리에 둘지 결정한다.
- [ ] 승인된 baseline을 자동으로 다시 캡처하지 않는, 허용 오차를 고려한 Baseline
      Criteria를 추가한다.
- [ ] 적용 전에 Harness, Assessment, Test Manager, 기대값 변경 목록을 보여 주는
      변경 계획(dry-run)을 추가한다.

## 예제와 onboarding

- [x] `st_create_example`로 익명 모델, Dataset MAT, 예제 관리 Excel을 로컬 생성한다.
- [x] 기본 예제는 FILE/MAT를 쓰고 SLDV GENERATE를 요구하지 않는다.
- [x] `docs/manual/` 아래에 작업 중심의 한국어 복사용 runbook을 둔다.
- [x] 결과·checkpoint 경로가 분리된 이름별 모델 profile과 CLI/목록 선택을 추가한다.
- [x] 읽기 전용 readiness 검사와, 선택 단계부터 workflow 끝까지 실행하는 엄격한
      재시작을 추가한다.
- [x] 해시 검증된 저장 증거에서 새 PipelineId로 PACKAGE/SUMMARY를 재생성한다.
- [x] MATLAB을 모르는 사용자를 위한 입문 가이드, 용어집, Excel 열 사전, 설정 사전을
      추가한다.
- [ ] `docs/manual/runtime-verification.md`를 R2025b에서 실행하고 예제 출력,
      재시작·readiness 증거, Test Manager 폴더 버튼 확인 결과를 보존한다.
- [ ] workspace 이전이 안전해지면 로컬 작업 디렉터리 이름의 과거 오타를 정정한다.

## Package 이전

- [ ] `docs/architecture.md`에 기술한 `src/+simtest` 공개 API를 도입한다.
- [ ] 현재 루트 `st_*` 진입점의 호환 기간을 정의한다.
- [ ] 큰 Signal Editor, SLDV 준비, 경로 탐색, 기대값 갱신 파일을 책임 단위로
      분할한다.
- [x] 진단 유틸리티를 `diagnostics/matlab` 아래의 공개 `st_*` 명령으로 유지한다.
- [x] `WORK_HANDOFF.md`, `PATCH_NOTES.txt`, `README_REPLACEMENT_FILES.txt`를
      `docs/archive`에 보존한다.
- [ ] archive의 유용한 내용을 현재 문서로 통합한 뒤 archive 파일을 제거한다.

## 호환성과 검증

- [ ] 지원하는 MATLAB 릴리스 범위를 결정한다. R2024a를 지원할지, 모델 소스 버전으로만
      허용할지 포함한다.
- [ ] 승인된 장비에서 문서화된 MATLAB R2025b end-to-end 검증을 수행한다.
- [x] QUICK/RUNTIME/CERTIFY 검증 코드, 생성 fixture builder, 소스 격리 runtime 검사,
      Excel/JSON/JUnit 결과 writer를 추가한다.
- [ ] 최초 R2025b `CERTIFY + BOTH` 결과를 실행하고 보존한다. 현재 비-MATLAB 개발
      환경에서는 runtime 증거를 만들 수 없다.
- [ ] 최초 R2025b smoke 결과로 실제 단계 소요시간이 확인되면, 유효한 Harness·SLDV
      준비를 다시 만들지 않는 인증 수준의 재개와 실패 항목만 재시도를 추가한다.
- [ ] 최초 R2025b 결과로 runtime 소요시간과 라이선스 동작이 확인되면 정규화된 JUnit
      출력을 CI에 연결한다.

## 보고와 운영

- [x] 대상 수준 증분 준비 checkpoint와 비파괴 `AUTO`/`FORCE` 실행 정책을 추가한다.
- [x] 초기·최종 결과, Decision·Execution coverage, Excel 요약, 공식 PDF, HTML, MLDATX를
      담는 로컬 실행 번들을 추가한다.
- [x] 임시 CVF 격리, 명시적 복원 검증, 대상별 결과 번들, 별도 latest pointer를 갖는
      순차 CUT별 실행을 추가한다.
- [ ] R2025b에서 CUT별 fixture 조합(`SUBSYSTEM+JUSTIFY`, `ALL_CONTENT+EXCLUDE`,
      `OFF`)을 실행하고 apply, run, export, restore, continue-on-failure,
      restore-failure abort 순서의 증거를 보존한다.
- [x] 저장된 내부 Harness 모델, 입력, Test File, dependency, 참조 보고서를 담고
      수신자의 재실행마다 새 workspace를 만드는 비파괴 내보내기 명령을 추가한다.
- [ ] 내보낸 번들을 R2025b에서 end-to-end 검증한다. 내부 Harness 보존, dependency
      완전성, Signal Editor/SLDV 경로 재작성, 반복 실행, 참조 결과 비교를 포함한다.
- [ ] dependency 분석이 복사할 수 없는 외부 자원(환경 변수, 사내 서비스, 라이선스가
      필요한 커스텀 코드)에 대한 정책을 정의한다.
- [ ] 사용자가 추가한 Test File baseline, callback, 요구사항, custom criteria
      dependency까지 탐색·패키징하려면 내보내기에 MATLAB Project가 필요한지 결정한다.
- [ ] MATLAB 검증 이후 다음 릴리스 버전을 선택한다. 현재 변경은 `Unreleased`로 둔다.
- [x] JSON과 JUnit XML을 함께 쓰고, Excel을 사람이 읽는 검증 요약으로 쓴다.
- [ ] 보고서를 공유하기 전에 모델 경로, CUT 이름, 진단 오류에 대한 redaction 규칙을
      정의한다.
- [ ] 현재 대상 fingerprint, 필수 수동 CheckId, 증거 경로로부터 수동 증거 JSON을
      생성하고 사전 검증한다.
- [ ] 두 검증 실행을 검사 상태, 소요시간, 환경, coverage, 산출물 checksum 기준으로
      비교한다.
- [ ] 저장소 baseline 검증 후 개발 포트폴리오에 프로젝트 등록과 개발 이력을 유지할지
      결정한다.
