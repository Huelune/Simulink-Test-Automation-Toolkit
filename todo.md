# MATLAB 실행 요청

작성: 2026-10-15. 결과를 붙여 주면 해당 절은 지운다.

블록마다 `clearvars`로 시작한다. 앞서 돌린 블록의 변수가 함수 이름을 가리면 엉뚱한 오류가 난다.
화면에는 개수, Simulink 블록 종류 이름, 정해 둔 안내 문구만 찍는다. 테스트 케이스·모델·블록
이름, 경로, 계정은 찍지 않는다(회사 내부 정보).

## 1. SLDV coverage filter 동작 확인

**왜:** `SldvMode=GENERATE`가 `CoverageFilterMode`를 따라 하위 Subsystem에는 목표를 만들지 않게
바꿨다(기능 브랜치, 아직 main에 없음). 실제 모델에 넣기 전에 세 가지 가정을 확인한다.
`sldvoptions`에 `CovFilter`/`CovFilterFileName`이 있는지, Top Model SID로 만든 CVF가 atomic CUT
분석에서도 걸리는지, 그래서 목표 수가 줄어드는지. 블록 이름이 일반적인 작은 모델을 임시 폴더에
만들어 쓰므로 브랜치는 바꾸지 않아도 된다. 툴킷 함수를 쓰지 않아 어느 폴더에서 붙여 넣어도 된다. 2~3분.

```matlab
clearvars; clc
oldWarning = warning('off', 'all');
workDir = fullfile(tempdir, 'st_sldv_filter_check');
if isfolder(workDir), rmdir(workDir, 's'); end
mkdir(workDir); oldDir = cd(workDir);
mdl = 'sldvFilterCheck';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
set_param(mdl, 'Solver', 'FixedStepDiscrete', 'FixedStep', '0.1');
cut = [mdl '/Cut'];
add_block('simulink/Sources/In1', [mdl '/In1']);
add_block('simulink/Sinks/Out1', [mdl '/Out1']);
add_block('simulink/Ports & Subsystems/Subsystem', cut);
set_param(cut, 'TreatAsAtomicUnit', 'on');
delete_line(cut, 'In1/1', 'Out1/1');
add_block('simulink/Discontinuities/Saturation', [cut '/Sat']);
add_block('simulink/Ports & Subsystems/Subsystem', [cut '/Child']);
delete_line([cut '/Child'], 'In1/1', 'Out1/1');
add_block('simulink/Discontinuities/Saturation', [cut '/Child/Sat']);
add_line([cut '/Child'], 'In1/1', 'Sat/1'); add_line([cut '/Child'], 'Sat/1', 'Out1/1');
add_line(cut, 'In1/1', 'Sat/1'); add_line(cut, 'Sat/1', 'Child/1'); add_line(cut, 'Child/1', 'Out1/1');
add_line(mdl, 'In1/1', 'Cut/1'); add_line(mdl, 'Cut/1', 'Out1/1');
save_system(mdl, fullfile(workDir, [mdl '.slx']));

hasOption = isprop(sldvoptions, 'CovFilter') && isprop(sldvoptions, 'CovFilterFileName');
cvfFile = ''; filterError = '';
try
    f = slcoverage.Filter;
    addRule(f, slcoverage.FilterRule(slcoverage.BlockSelector( ...
        slcoverage.BlockSelectorType.SubsystemAllContent, Simulink.ID.getSID([cut '/Child'])), ...
        'none', slcoverage.FilterMode.Exclude));
    save(f, fullfile(workDir, 'child_filter'));
    cvfFile = fullfile(workDir, 'child_filter.cvf');
catch ME
    filterError = ME.identifier;
end

labels = {'필터 없음', '필터 있음'};
runStatus = nan(1, 2); objectiveCount = nan(1, 2); satisfiedCount = nan(1, 2); runError = {'', ''};
for k = 1:2
    try
        opts = sldvoptions;
        opts.Mode = 'TestGeneration';
        opts.OutputDir = fullfile(workDir, sprintf('out%d', k));
        opts.SaveReport = 'off'; opts.SaveHarnessModel = 'off'; opts.MaxProcessTime = 120;
        if k == 2, opts.CovFilter = 'on'; opts.CovFilterFileName = cvfFile; end
        [~, runStatus(k), files] = evalc('sldvrun(cut, opts, false)');
        loaded = load(files.DataFile);
        objectives = loaded.sldvData.Objectives;
        objectiveCount(k) = numel(objectives);
        satisfiedCount(k) = sum(contains(string({objectives.status}), 'Satisfied'));
    catch ME
        runError{k} = ME.identifier;
        if isempty(runError{k}), runError{k} = '(식별자 없음, 메시지는 내부 정보일 수 있어 생략)'; end
    end
end
close_system(mdl, 0); cd(oldDir); warning(oldWarning);

clc
fprintf('MATLAB %s\n', version('-release'));
fprintf('sldvoptions에 CovFilter/CovFilterFileName: %s\n', string(hasOption));
if ~isempty(filterError), fprintf('CVF 만들기 실패: %s\n', filterError); end
for k = 1:2
    if isempty(runError{k})
        fprintf('%s: 상태 %g | 목표 %d개 | 충족 %d개\n', labels{k}, runStatus(k), ...
            objectiveCount(k), satisfiedCount(k));
    else
        fprintf('%s: 실패 %s\n', labels{k}, runError{k});
    end
end
```

**확인할 것:** 둘째 줄이 `true`, 두 실행 모두 상태 `1`, `필터 있음`의 목표 수가 `필터 없음`보다
적다(Saturation 하나 몫만큼). 같으면 Top Model SID 필터가 CUT 분석에 안 걸린 것이다.

**돌려줄 것:** 화면 캡처 한 장.
