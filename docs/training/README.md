# 교육 자료

## 수동 작업 매뉴얼 (PPT)

[manual-workflow-training.pptx](manual-workflow-training.pptx) — 25장, 한국어.

이 도구가 자동으로 해 주는 일을 **사람이 Simulink · Test Manager GUI에서 직접
하는 절차**를 정리한 팀 교육용 슬라이드입니다. CUT 하나를 기준으로 사전 확인부터
standalone 제출물까지 8단계로 나누어 설명합니다.

| 장 | 내용 |
| --- | --- |
| 1~3 | 표지, 범위, 전체 8단계 흐름 |
| 4~5 | 1단계 사전 확인과 이름 규칙 |
| 6~8 | 2단계 Test Harness 생성과 대화상자 설정값 |
| 9~10 | 3단계 입력 데이터 준비 (기존 / MAT·SLDV / 생성) |
| 11~12 | 4단계 StopTime과 Signal Editor 연결 |
| 13~14 | 5단계 Assessment 스텝 구조와 verify 작성 |
| 15~16 | 6단계 Test Case와 Iteration |
| 17~20 | 7단계 커버리지 설정, CVF, 실행, 기대값 확정 |
| 21~22 | 8단계 결과 정리와 standalone 제출물 |
| 23~25 | 단계별 완료 조건, 자주 나는 실수, 마무리 |

각 장에는 발표자 노트가 들어 있습니다.

내용의 근거는 [운영자 매뉴얼](../operator-manual.md),
[Standalone Coverage 파이프라인](../standalone-coverage-pipeline.md),
[관리 Excel 열 사전](../workbook-reference.md)입니다. 도구의 동작이 바뀌면 이
자료도 함께 고쳐야 합니다.

### 고치는 방법

**PPTX를 PowerPoint에서 직접 고치는 것이 기본입니다.** 한 장을 손보려고
스크립트를 다시 돌릴 필요는 없습니다.

`generator/`에는 이 파일을 처음 만든 Python 스크립트가 들어 있습니다. 구조를
크게 바꿀 때만 씁니다. **다시 돌리면 PowerPoint에서 손으로 고친 내용은
사라집니다.**

```bash
pip install python-pptx
cd docs/training/generator
python main.py ../manual-workflow-training.pptx
```
