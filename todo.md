# MATLAB 실행 요청

작성: 2026-10-07. 결과를 붙여 주면 해당 절은 지운다.

## 1. 분기 결과 표기 단위 테스트 (develop의 새 기능)

develop에만 있는 기능이다. 모델 프로젝트 안의 클론에서 develop을 받은 뒤
`st_setup`을 하고 실행한다.

```matlab
runtests({'test_decision_outcomes','test_export_final_document', ...
    'test_export_test_specification','test_specification_decision_blocks', ...
    'test_coverage_filters'})
```

실패한 테스트가 있으면 출력 전체를 붙인다.
