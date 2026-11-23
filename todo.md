# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. 자산 번들의 MLDATX가 더블클릭으로 안 열리는 이유 확인

왜: `st_export_test_asset_bundle`이 만든 번들의 결과 MLDATX를 더블클릭하면 오류가 나며 안 열린다.
어느 파일(결과 `raw/` 또는 `test-manager/` Test File)이 어떤 오류 종류로 실패하는지 알아야 고친다.
더블클릭과 같은 `open`으로 고른 번들의 MLDATX를 하나씩 연다. Test Manager 창이 뜰 수 있다.
툴킷 함수를 쓰지 않으므로 `st_setup` 없이 어느 폴더에서 붙여 넣어도 된다. 실행하면 폴더 고르는 창이 뜬다.

```matlab
clearvars; clc; warnState = warning('off', 'all');
bundleDir = uigetdir(pwd, '안 열리는 자산 번들 폴더(manifest.json이 있는 폴더)를 고르세요');
if isequal(bundleDir, 0), fprintf('폴더를 고르지 않아 멈췄습니다\n'); warning(warnState); return; end
mldatxFiles = dir(fullfile(bundleDir, '**', '*.mldatx'));
reportFile = fullfile(tempdir, 'st_bundle_open_report.txt'); fid = fopen(reportFile, 'w');
fprintf('MATLAB %s | 열린 Test File %d개 | 열린 모델 %d개 | MLDATX %d개\n', version('-release'), ...
    numel(sltest.testmanager.getTestFiles), numel(find_system('type', 'block_diagram')), numel(mldatxFiles));
okCount = 0;
for k = 1:numel(mldatxFiles)
    filePath = fullfile(mldatxFiles(k).folder, mldatxFiles(k).name);
    relParts = strsplit(erase(mldatxFiles(k).folder, bundleDir), filesep);
    role = 'other'; if any(strcmp(relParts, 'raw')), role = 'raw 결과'; elseif any(strcmp(relParts, 'test-manager')), role = 'Test File'; end
    try
        open(filePath); okCount = okCount + 1;
    catch openError
        causeIds = strjoin(cellfun(@(c) c.identifier, openError.cause, 'UniformOutput', false), ',');
        fprintf('실패 %d | %s | 경로 길이 %d | 식별자 %s | 원인 %s\n', k, role, strlength(filePath), ...
            openError.identifier, causeIds);
        fprintf(fid, '=== %d %s\n%s\n', k, role, openError.getReport('extended', 'hyperlinks', 'off'));
    end
end
fclose(fid); warning(warnState);
fprintf('열림 %d개 / 실패 %d개 | 자세한 오류: %%TEMP%%\st_bundle_open_report.txt\n', okCount, numel(mldatxFiles) - okCount);
```

확인할 것: 실패 줄의 종류(`raw 결과` / `Test File`)와 식별자.
같은 이름의 Test File이나 모델이 이미 열려 있으면 그것이 원인일 수 있으므로 첫 줄의 개수도 본다.

돌려줄 것: 화면 캡처 한 장. 자세한 오류 파일은 보내지 말고, 식별자가 비어 있으면 그 파일의 첫 오류 문장을
모델·경로 이름 없이 말로 바꿔 적어 주세요.
