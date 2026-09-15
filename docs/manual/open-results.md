# 제출된 Test Manager와 standalone 모델 열기

launcher를 반드시 사용할 필요는 없습니다. **Model 폴더 버튼으로 standalone `.slx`를
선택하는 방식**을 지원합니다. 이 파일은 원본 Top Model의 내부 Harness가 아니라 독립 Model입니다.
Test Harness 항목에는 원본 Top Model/Harness 연결을 다시 지정하지 않습니다.

## 현재 PC에서 모든 대상 폴더 연결

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
pipelineId = '여기에_PipelineId';
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
`UT_REQ_{TC_NAME}.cvf`인지 확인하세요.
경로 설정은 MATLAB 세션마다, 다른 PC에서도 필요합니다. `savepath`를 강제하지 않습니다.

전체 결과 폴더를 다른 위치로 복사했다면 manifest의 예전 절대 경로를 그대로 쓰지 말고
새 위치의 TC 폴더들을 Add to Path 한 뒤 `TestManager/*.mldatx`를 직접 여세요.
모델·Input·CVF·CVT·HTML 부속 파일을 함께 보관합니다. `.work` 없이 제출 파일을 여는 것과
PACKAGE 재생성이 가능한지는 서로 다른 조건입니다.

## 선택 사항: 자동 연결 launcher

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
pipelineId = '여기에_PipelineId';
m = st_load_standalone_pipeline_manifest(cfg.StandaloneCoverageRootDir,pipelineId);
assert(isfile(m.TestManagerLauncher));
run(m.TestManagerLauncher);
```

launcher는 모델 경로와 CVF readback을 준비하는 편의 기능입니다. launcher에서
filter readback 오류가 나면 해당 오류를 숨기지 말고 CVF 파일·대상 model·저장 경로를 확인합니다.
이전에 한 번 열었다고 다른 PC의 MATLAB 경로까지 자동으로 연결되지는 않습니다.

## CVF 내용을 볼 때 이름이 n/a로 나오는 경우

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
