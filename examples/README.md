# Examples

## `st_create_example`

`st_create_example(destination)`은 익명 Simulink 모델, Dataset MAT, 관리 Excel을
비어 있는 새 로컬 디렉터리에 생성합니다. 테스트를 실행하지도, profile을 선택하지도
않습니다.

예제는 `FILE+MAT`를 쓰므로 새 SLDV 분석이 필요 없으며, 일반 Decision 분기와 직계
하위 Subsystem 필터를 확인할 수 있는 구조를 포함합니다.

따라 할 수 있는 코드는 [익명 예제 생성](../docs/manual/example.md)에 있습니다.
R2025b 실기 확인은 아직 남아 있습니다.

> 이 폴더에 실제 업무 모델, 관리 workbook, SLDV MAT, 생성된 Test Manager 파일을
> 두지 마십시오. 생성된 샘플 바이너리는 Git에 추가하지 않습니다.

## `manual-evidence.example.json`

`CERTIFY + CURRENT/BOTH`에서 요구하는 수동 검사 증거의 익명 template입니다.
복사본에 실제 reviewer ID, 현재 target fingerprint, 로컬 evidence 경로를
입력하십시오. 작성 방법은 [종합 검증 6장](../docs/verification.md#6-수동-증거-만들기)에
있습니다.

> screenshot이나 업무 모델 정보는 저장소에 커밋하지 마십시오.
