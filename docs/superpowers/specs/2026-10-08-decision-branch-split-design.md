# 결정 단위 분기(D) 나누기 설계

- 작성일: 2026-10-08
- 상태: 구현됨 (실기 미확인)
- 대상 브랜치: develop
- 앞선 설계: `2026-10-06-decision-outcome-in-final-document-design.md` (최종 문서의 분기 결과 표기)

## 1. 배경

최종 문서는 결정마다 true/false가 정확히 둘인 블록에만 실제 결과(`[T]`, `[F]`,
`[T/F]`, `[-]`)를 적는다. Saturation처럼 Coverage가 결정을 둘 이상 만드는 블록은
D 줄이 하나뿐이라 결과를 붙일 수 없어서 `[T/F]`로 남는다.

If 블록은 이미 조건마다 D를 하나씩 받는다. 같은 방식으로 이런 블록도 **Coverage
결정마다 D를 하나씩** 주면 결과를 적을 수 있고, D 개수도 리포트의 Decision 수에
가까워진다.

2026-10-08 실기 확인(앞선 설계 10.1절)에서 다음이 확인됐다.

- 결정 텍스트는 `U >= LL`, `U > UL`, `Reset`, `Enable`처럼 짧고 일정한 이름이다.
- 하한(`LL`) 결정이 상한(`UL`)보다 먼저 나온다. MathWorks 문서의 서술 순서와 다르다.
- true 방향이 블록마다 다르다. Saturation과 Dead Zone의 하한은 `U >= LL`이 true이고,
  Discrete-Time Integrator와 Rate Limiter의 하한은 `X < LL`이 true다.

그러므로 D 줄과 결정은 **순서가 아니라 결정 텍스트로** 짝짓는다. D 줄에는 Coverage의
결정 텍스트를 그대로 적어 `[T]`가 리포트의 true와 같은 뜻이 되게 한다.

## 2. 목표

- 아래 블록은 Coverage 결정마다 D를 하나씩 받는다. D 줄에는 결정 텍스트를 줄여
  쓴 형태를 적고, 그 결정에 해당하는 파라미터 값 하나를 붙인다.

  ```text
  Sat 1
  D1 [T/F]Saturate (U >= LL; LowerLimit=-32)
  D2 [F]Saturate (U > UL; UpperLimit=32)
  ```

- 이 블록들도 최종 문서에서 실제 결과를 받는다(catalog `TwoWay=YES`).
- D 순서는 리포트와 같은 순서다(하한 먼저). 사용자가 순서는 상관없다고 했으므로
  리포트와 한 줄씩 대조하기 쉬운 쪽을 택한다.

### 범위 밖

- 결과가 셋 이상인 블록(MinMax, Multiport Switch, Switch Case, Sign, Combinatorial
  Logic). 지금처럼 `[T/F]`로 둔다. 사용자 결정.
- 입력이 벡터·행렬인 블록. 원소마다 같은 텍스트의 결정이 따로 생긴다. 정적 scan은
  신호 폭을 모르므로 짝을 지을 수 없고, `DECISION_OUTCOME_MISMATCH`로 남긴다.
- If 블록. 결정 텍스트가 `Input1`, `Else IF #2`라서 조건식과 대응하지 않는다.
  순서가 실기로 확인됐으므로 지금처럼 순서로 짝짓는다.

## 3. 나누는 블록과 분기

| 블록 | 분기 (Coverage 텍스트 → 붙이는 파라미터) | 분기가 있는 조건 |
| --- | --- | --- |
| Saturate | `U >= LL` → `LowerLimit`, `U > UL` → `UpperLimit` | 항상 |
| DeadZone | `U >= LL` → `LowerValue`, `U > UL` → `UpperValue` | 항상 |
| RateLimiter | `X < LL` → `FallingSlewLimit`, `X > UL` → `RisingSlewLimit` | 항상 |
| Relay | `U >= OnThresh` → `OnSwitchValue`, `U <= OffThresh` → `OffSwitchValue` | 항상 |
| DiscreteIntegrator | `Reset` → `ExternalReset` | `ExternalReset!=none` |
| | `X < LL` → `LowerSaturationLimit`, `X > UL` → `UpperSaturationLimit` | `LimitOutput=on` |
| Delay | `Enable` → `ShowEnablePort` | `ShowEnablePort=on` |
| | `Reset` → `ExternalReset` | `ExternalReset!=None` |
| DiscreteFir | Delay와 같음 | Delay와 같음 |
| DiscreteFilter | `Reset` → `ExternalReset` | `ExternalReset!=None` |
| DiscreteTransferFcn | `Reset` → `ExternalReset` | `ExternalReset!=None` |

- 분기 순서는 실기에서 본 순서다. DiscreteFir과 DiscreteTransferFcn은 실기에서 찍지
  않았으므로 Delay·DiscreteFilter와 같다고 가정한다(10절).
- DiscreteFilter와 DiscreteTransferFcn은 분기가 하나뿐이지만 같은 방식으로 다룬다.
  D 줄 표기가 다른 블록과 같아지고, 텍스트 짝짓기를 거친다.

## 4. catalog: `Branches` 열

`src/exporting/st_specification_decision_catalog.m`에 열 하나를 더한다.

```text
Branches  분기 목록. ';'로 나눈 항목마다 "<Coverage 텍스트>:<파라미터>[:<조건>]".
          비어 있으면 지금처럼 블록 하나가 D 하나(또는 descriptor의 CUSTOM 분기)다.
```

예:

```text
Saturate            "U >= LL:LowerLimit; U > UL:UpperLimit"
DiscreteIntegrator  "Reset:ExternalReset:ExternalReset!=none; X < LL:LowerSaturationLimit:LimitOutput=on; X > UL:UpperSaturationLimit:LimitOutput=on"
```

- `<조건>`은 `DecisionWhen`과 같은 문법(`Name=value`, `Name!=value`, `,`로 이으면
  하나라도 맞을 때)이고 같은 판정 함수를 쓴다.
- 블록 단위 `DecisionWhen`은 그대로 둔다. 분기가 하나도 남지 않는 블록은 지금처럼
  목록에서 빠진다.
- `Branches`가 있는 행의 `Parameters`와 `OptionalParameters`는 쓰지 않는다. 분기가
  자기 파라미터를 직접 가진다. catalog 형식 테스트가 둘이 함께 쓰이지 않는지 본다.
- 이 9개 행의 `TwoWay`를 `YES`로 바꾼다.

## 5. descriptor

`st_specification_decision_descriptor`가 `Branches`가 있는 행이면 분기마다 한 줄을
만든다.

- 출력에 세 번째 값 `coverageTexts`(분기마다 Coverage 텍스트, 그 밖의 블록은 빈
  문자열)를 더한다. 기존 두 출력을 쓰는 호출자는 그대로 동작한다.
- 분기 줄의 식: `<Coverage 텍스트>; <파라미터>=<저장 값>`. 예: `U >= LL; LowerLimit=-32`.
  값은 지금처럼 저장된 문자열이며 평가하지 않는다.
- 분기 조건이 맞지 않는 분기는 만들지 않는다. 남은 분기가 없으면 빈 결과를 돌려준다
  (지금의 "Decision objective 없음"과 같은 처리).
- 파라미터 읽기 실패는 지금처럼 오류로 올라가고, scan이 그 블록을 WARN 한 줄로
  기록한다.

## 6. scan과 JSON

`st_specification_decision_blocks`는 descriptor의 세 번째 출력을 받아 JSON 항목에
`CoverageText` 필드로 넣는다. 그 밖의 블록은 빈 문자열이다. `DecisionBlockDetails`
시트에는 열을 더하지 않는다. 그 시트의 `JSON` 열이 항목 전체를 담으므로
`CoverageText`도 거기 있다. 메인 셀의 D 줄 형식은 바뀌지 않는다.

## 7. 짝짓기

### 7.1 읽기

`st_final_document_decision_outcomes`의 lookup이 `Counts`와 함께 `Texts`(결정 순서의
`DecisionText`)를 돌려준다. 시트에는 이미 `DecisionText`가 있다.

### 7.2 표시

`st_format_specification_decision_blocks`의 `outcome_labels`에서 블록 경로 묶음마다:

- 묶음의 항목이 모두 `CoverageText`를 가지면 **텍스트로** 짝짓는다. 비교는 공백
  정규화와 대소문자 무시다. 각 항목이 기록된 결정 중 정확히 하나와 맞으면 그 결과를
  적는다.
- 하나라도 맞는 결정이 없거나 둘 이상 맞으면(벡터 입력), 그 블록의 D는 모두
  `[T/F]`로 두고 `DECISION_OUTCOME_MISMATCH`를 남긴다. 기록된 결정 중 D에 없는 것이
  있어도 같다. 일부만 적으면 어느 쪽이 맞는지 읽는 사람이 알 수 없다.
- `CoverageText`가 없는 묶음(If, Switch 등)은 지금처럼 순서로 짝짓는다.
- `TwoWay`, `UNAVAILABLE` 규칙은 바뀌지 않는다.

## 8. 바뀌는 출력

- 명세서 export와 최종 문서 모두, 3절의 블록은 D가 분기 수만큼 늘어난다. 같은 CUT의
  뒤쪽 D 번호가 그만큼 밀린다. CHANGELOG에 적는다.
- 3절 블록의 D 줄 괄호 안이 `UpperLimit=1; LowerLimit=-1` 같은 파라미터 나열에서
  `U >= LL; LowerLimit=-1` 같은 분기 식으로 바뀐다.
- 기존 결과 workbook은 그대로 읽힌다. 시트 열이 바뀌지 않기 때문이다.

## 9. 테스트

모델 없이 도는 단위 테스트로 쓴다.

- catalog: `Branches` 문법, `Branches` 행의 `TwoWay=YES`, `Parameters`와 함께 쓰이지
  않음.
- descriptor: Saturate가 두 줄과 텍스트 두 개를 돌려준다. DiscreteIntegrator는
  설정에 따라 0·1·2·3줄이 된다. Delay는 enable·reset 조합.
- scan: JSON 항목에 `CoverageText`가 들어간다.
- 표시: 텍스트가 순서와 반대로 기록돼도 맞는 D에 결과가 간다(실기 순서 재현).
  텍스트가 맞지 않거나 중복되면 `[T/F]`와 MISMATCH. `CoverageText`가 없는 If는
  지금처럼 순서로 짝짓는다.
- 기존 테스트 중 3절 블록의 식을 확인하는 것은 새 식으로 고친다.

## 10. 확인하지 못한 가정

1. DiscreteFir의 결정 텍스트가 Delay와 같은 `Enable`, `Reset`이고,
   DiscreteTransferFcn이 DiscreteFilter와 같은 `Reset`이다. 아니면 그 블록은
   MISMATCH로 보인다.
2. 결정 텍스트가 MATLAB 릴리스나 언어 설정에 따라 바뀌지 않는다. 실기 확인은 한
   번(R2025b 추정)뿐이다.
3. 입력이 벡터인 블록의 결정 텍스트가 원소마다 같다. 다르면(예: 원소 번호가 붙음)
   지금 규칙에서 MISMATCH가 되며, 그 텍스트를 보고 규칙을 넓힐 수 있다. 이는
   Coverage가 원소마다 결정 하나씩을 낸다는 가정이다. 결과가 셋 이상인 결정 하나로
   내면 `st_decision_outcome_counts`가 빈 값을 돌려 그 블록은 기록되지 않으므로,
   사용자는 MISMATCH가 아니라 `DECISION_OUTCOME_UNAVAILABLE`을 보게 된다.
