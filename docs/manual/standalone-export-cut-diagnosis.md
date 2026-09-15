# Standalone Harness export의 CUT 식별 실패 진단

Standalone 제출물 생성 중 아래 오류로 멈출 때 원인을 가르는 절차입니다.
읽기 전용 점검이며 모델을 저장하지 않습니다.

```text
simtest:StandaloneCUTIdentificationFailed
Expected exactly one exported CUT matching name and interface.
Source=<TopModel>/<...>/<CUT> | Model=<HarnessName> | Matches=0
```

## 1. 무엇을 검사하다 실패했나

`st_export_standalone_harnesses`는 `sltest.harness.export`로 만든 standalone
모델에서 CUT 블록을 다시 찾습니다. 아래 **두 조건을 모두** 만족하는 블록이
정확히 하나여야 합니다.

1. 블록 이름이 원본 CUT 이름과 같다
2. CUT 바로 아래의 Inport/Outport/Enable/Trigger/Reset을
   `BlockType|Port|Name`으로 모아 정렬한 **포트 시그니처**가 같다

`Matches=0`은 둘을 함께 만족하는 블록이 없었다는 뜻입니다. 어느 조건에서
탈락했는지는 오류 메시지만으로 구분되지 않으므로 아래를 실행합니다.

로그의 `"This operation deletes the harness from the main model"` 경고는
정상입니다. export는 일회용 복사본에서 수행하므로 원본 모델은 바뀌지 않습니다.

## 2. 원본 CUT의 링크 상태 확인

실패한 CUT 경로를 `src`에 넣습니다. 오류 메시지의 `Source=` 값입니다.

```matlab
st_setup
cfg = st_select_model_profile('MODEL_A');
src = '여기에_CUT_경로';        % 오류 메시지의 Source= 값

load_system(cfg.ModelFile)
disp(st_cut_library_link_state(src))

n0 = numel(find_system(src,'SearchDepth',1,'Type','Block'));
n1 = numel(find_system(src,'SearchDepth',1,'FollowLinks','on', ...
    'LookUnderMasks','all','Type','Block'));
fprintf('원본 내부 블록(자기 자신 포함): 기본=%d  링크추적=%d\n', n0, n1);
```

`IsLinked`가 `1`이고 `기본=1`, `링크추적`이 그보다 크면 **활성 라이브러리 링크
때문에 원본 쪽 시그니처가 비어 있는 상태**입니다. export된 모델에서 링크가
비활성·해제되면 그쪽 시그니처만 채워져 두 값이 어긋납니다.

## 3. 시그니처 실제 값 비교

`st_export_standalone_harnesses`의 시그니처 계산과 같은 방식으로 출력합니다.

```matlab
for follow = [false true]
    if follow
        b = find_system(src,'SearchDepth',1,'FollowLinks','on', ...
            'LookUnderMasks','all','Type','Block');
    else
        b = find_system(src,'SearchDepth',1,'Type','Block');
    end
    b = cellstr(string(b(:)));
    b = b(~strcmp(b, src));
    rows = strings(0,1);
    for k = 1:numel(b)
        t = get_param(b{k},'BlockType');
        if ~ismember(t, {'Inport','Outport','EnablePort','TriggerPort','ResetPort'})
            continue
        end
        p = ''; try, p = get_param(b{k},'Port'); catch, end
        rows(end+1,1) = string(t)+"|"+string(p)+"|"+string(get_param(b{k},'Name'));
    end
    fprintf('FollowLinks=%d | 포트 %d개\n', follow, numel(rows));
    disp(sort(rows))
end
```

`FollowLinks=0`에서 `포트 0개`, `FollowLinks=1`에서 실제 포트가 나오면
링크가 원인입니다.

## 4. export 결과 직접 확인

실패 시 standalone 모델은 닫히므로, 같은 조건을 일회용 복사본에서 재현합니다.
**원본 모델을 먼저 닫고** 시작하며, 어떤 경우에도 저장하지 마세요.

```matlab
harnessName = '여기에_Harness명';   % 오류 메시지의 Model= 값
work = fullfile(tempdir, ['cutdiag_' char(datetime('now','Format','HHmmssSSS'))]);
mkdir(work);
copyfile(cfg.ModelFile, fullfile(work, [cfg.TopModel '.slx']));

if bdIsLoaded(cfg.TopModel)
    assert(strcmp(get_param(cfg.TopModel,'Dirty'),'off'), ...
        '원본에 저장하지 않은 변경이 있습니다. 먼저 처리하세요.');
    close_system(cfg.TopModel, 0);
end
load_system(fullfile(work, [cfg.TopModel '.slx']));

previous = pwd;
cd(work)
sltest.harness.export(src, harnessName, 'Name', 'DiagStandalone');
cd(previous)

top = find_system('DiagStandalone','SearchDepth',1,'Type','Block');
top = cellstr(string(top(:)));
top = top(~strcmp(top,'DiagStandalone'));
for k = 1:numel(top)
    fprintf('%-40s | Type=%-12s | Link=%s\n', ...
        get_param(top{k},'Name'), get_param(top{k},'BlockType'), ...
        get_param(top{k},'StaticLinkStatus'));
end
```

정리는 아래와 같이 합니다.

```matlab
close_system('DiagStandalone', 0);
close_system(cfg.TopModel, 0);
rmdir(work, 's');
```

## 5. 결과 해석

| 관찰 | 원인 | 대응 |
| --- | --- | --- |
| 최상위에 CUT 이름 블록이 있고 `Link`가 원본과 다름 | 링크 상태 차이로 시그니처 불일치 | 아래 개발자 확인 지점 |
| 최상위에 CUT 이름 블록이 **없음** | 이름 불일치. export가 SUT 이름을 바꿨거나 한 단계 더 감쌈 | 실제 이름·구조를 기록해 전달 |
| 최상위 블록이 하나도 없음 | 링크 미해결. 라이브러리가 MATLAB path에 없음 | 라이브러리를 path에 추가 후 재시도 |
| `IsLinked=0`인데 실패 | 링크 원인이 아님 | 3절 시그니처 두 값을 그대로 전달 |

## 6. 개발자 확인 지점

`identify_standalone_cut`과 `interface_signature`의 `find_system` 두 곳은
옵션 없이 호출되어 기본값 `FollowLinks='off'`, `LookUnderMasks='graphical'`을
씁니다. 저장소의 다른 모델 탐색은 모두 `'FollowLinks','on','LookUnderMasks','all'`을
명시합니다. 링크된 CUT에서만 재현되는 실패라면 이 비대칭이 원인입니다.
링크·마스크 상태와 무관한 `get_param(block,'PortHandles')` 기반 비교가 더 안전합니다.

이 진단은 MATLAB R2025b 실기에서 아직 확인되지 않았습니다.
