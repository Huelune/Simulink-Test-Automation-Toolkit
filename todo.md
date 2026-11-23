# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 자산 번들에서 결과로 가져올 수 있는 MLDATX 찾기

왜: 번들의 MLDATX를 `importResults`로 열었더니 "not a valid Result file"이 났다. 번들의 MLDATX 중
어느 것이 결과 파일이고 어느 것이 Test File인지 확인한다. 결과 파일은 가져오는 김에 Test Manager에 띄운다.
툴킷 함수를 쓰지 않으므로 `st_setup` 없이 붙여 넣어도 된다. 실행하면 번들 폴더를 고르는 창이 뜬다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
bundleDir = uigetdir(pwd, '자산 번들 폴더(manifest.json이 있는 폴더)를 고르세요');
if isequal(bundleDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
mldatxFiles = dir(fullfile(bundleDir, '**', '*.mldatx'));
for k = 1:numel(mldatxFiles)
    filePath = fullfile(mldatxFiles(k).folder, mldatxFiles(k).name);
    relParts = strsplit(erase(mldatxFiles(k).folder, bundleDir), filesep);
    role = '기타 폴더'; if any(strcmp(relParts, 'raw')), role = 'raw 폴더'; elseif any(strcmp(relParts, 'test-manager')), role = 'test-manager 폴더'; end
    try
        sltest.testmanager.importResults(filePath); verdict = '결과 파일: Test Manager에 가져옴';
    catch importError
        verdict = ['결과 파일 아님 (' importError.identifier ')'];
    end
    fprintf('%d | %s | %s\n', k, role, verdict);
end
sltest.testmanager.view; warning(warnState);
```

확인할 것: `raw 폴더` 줄이 "결과 파일"인지, Test Manager의 Results and Artifacts에 결과가 들어왔는지.

돌려줄 것: 화면 캡처 한 장.
