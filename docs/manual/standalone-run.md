# Standalone 제출물 생성

먼저 [일반 준비](prepare.md)를 끝내야 합니다. 원본 Top Model과 Test File을 저장하고
열린 Harness와 Top Model을 직접 닫으세요. 아래 코드는 사용자 모델을 강제로 닫지 않습니다.

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
[ready, checks] = st_check_readiness('Workflow','STANDALONE','FromStage','EXECUTE');
disp(checks)
assert(ready.Ready, 'Resolve readiness checks first.');
info = st_run_from_stage('Workflow','STANDALONE','FromStage','EXECUTE');
[code, summary, details] = st_check_standalone_coverage('PipelineId',info.PipelineId);
disp(code)
disp(summary)
disp(details)
```

이 진입점은 `ALL + SaveTestResult=true`로 EXECUTE → PACKAGE → SUMMARY를 수행합니다.
기존 `st_run_standalone_coverage_pipeline()`의 기본 `ALL + SaveTestResult=false`는
그대로이며, 그 결과에서 PACKAGE를 새로 생성하려면 저장 Result가 없으므로 EXECUTE가 필요합니다.

Standalone export는 Top Model 전체가 아니라 생성된 standalone Harness 모델의 dependency만
수집합니다. 따라서 대상과 무관한 Top Model branch의 미해결 dependency는 export를 막지
않습니다. 반대로 standalone `.slx` 자체가 필요한 파일을 찾지 못하면 받는 PC에서 열리지
않는 제출물을 만들지 않도록 export가 중단됩니다.

정상 완료 기준은 `1111111111 PASS`, TC별 standalone 모델·Input·
`UT_REQ_{TC_NAME}.cvf`·`UT_REQ_{TC_NAME}.cvt`·원본 `UT_REQ_{TC_NAME}.html`,
root의 11열 `CoverageSummary.xlsx`입니다. 대상 폴더는 `{NUM}_UT_REQ_{TC_NAME}`이며
실행하지 못한 대상도 폴더는 만들어집니다.
HTML은 Test Manager 요약 보고서가 아닌 Coverage REPORT 화살표의 원본이며 부속 asset도
함께 보존합니다. 압축 파일은 캡처 증거용이지 최종 HTML 대신 제출하는 파일이 아닙니다.

시뮬레이션 예외는 `ExecutionStatus=EXCEPT`로 남습니다. 가능한 Harness/Input은
패키징하지만 없는 CVT/HTML/metric을 만들어 PASS로 위장하지 않습니다. 따라서
그런 결과의 PACKAGE/SUMMARY 또는 checker는 FAIL/PARTIAL일 수 있습니다.
하네스와 Input까지도 생성 전 실패한 경우에는 보존을 보장하지 않습니다.
필터가 적용돼 objective가 없는 유효한 `0/0, N/A`와 Coverage 객체 자체의 누락은 다릅니다.

실패 상세 확인(정상적으로 반환된 `info`가 없으면 PipelineId를 직접 입력):

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
pipelineId = '여기에_PipelineId';
[m, manifestPath] = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,pipelineId);
fprintf('Manifest: %s\n',manifestPath);
T = struct2table(m.Targets);
disp(T(:,{'TestCaseName','ExecutionStatus','PackageEvidenceStatus','PackageStatus','Message'}));
for k = 1:numel(m.Targets)
    if ~isfield(m.Targets,'PackageFailure'), continue; end
    f = m.Targets(k).PackageFailure;
    if isempty(f.Identifier), continue; end
    fprintf('\n[%03d] %s\n%s: %s\n',k,m.Targets(k).TestCaseName,f.Identifier,f.Message);
end
```
