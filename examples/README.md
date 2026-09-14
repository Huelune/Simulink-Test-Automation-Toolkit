# Examples

`st_create_example(destination)` generates an anonymous Simulink model, Dataset MAT,
and management workbook in a new/empty local directory. It does not execute tests
or select a profile. Follow [the copyable example guide](../docs/manual/example.md).
The sample uses FILE/MAT (no new SLDV analysis) and includes normal and filtered
Decision branches. Runtime acceptance on R2025b remains pending.

Do not place real project models, management workbooks, SLDV MAT files, or generated
Test Manager files here. Generated sample binaries are not checked in.

`manual-evidence.example.json`은 `CERTIFY + CURRENT/BOTH`에서 요구하는 수동
검사 증거의 익명 template입니다. 실제 reviewer ID, 현재 target fingerprint와
로컬 evidence 경로를 복사본에 입력하십시오. screenshot이나 업무 모델 정보는
저장소에 커밋하지 않습니다.
