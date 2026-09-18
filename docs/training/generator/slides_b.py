# -*- coding: utf-8 -*-
"""10~17장: 입력 생성 · StopTime · Signal Editor · Assessment · Test Case."""

from pptx.enum.shapes import MSO_SHAPE
from deckkit import *  # noqa
from common import chip, marker, steps, kv, menu_path


def build(prs):
    # ============================================== 10 입력 만들기 상세
    s = blank(prs)
    y = title_block(s, "입력 파일로 준비할 때", step=3,
                    lead="B·C 갈래의 실제 작업입니다. A 갈래는 이 장을 "
                         "건너뜁니다.")
    write(s, ML, y + 0.02, 5.6, 0.3,
          [{"t": [("C  ", {"color": ACCENT, "bold": True}),
                  ("Design Verifier로 생성", {})]}],
          size=15, color=INK, bold=True)
    steps(s, ML, y + 0.5, 5.6, [
        "CUT을 Atomic으로 바꿉니다. Block Parameters의 Treat as atomic "
        "unit을 체크합니다.",
        "Top Model의 Design Verifier 설정을 확인합니다.",
        "Apps ▸ Design Verifier ▸ Test Generation ▸ Generate Tests 를 "
        "실행합니다.",
        "생성된 sldvData를 MAT으로 저장하고 각 TestCase의 종료 시각을 "
        "적어 둡니다."], gap=0.78, size=12.5)
    chip(s, ML, y + 3.68, 5.6, 1.0, "링크된 CUT은 하지 마십시오",
         "라이브러리에 링크된 CUT을 Atomic으로 바꾸면 원본 라이브러리가 "
         "훼손됩니다. 이 경우 B 갈래로 진행하십시오.", fill=ACCENT_TNT,
         bs=11.5)

    write(s, 6.9, y + 0.02, 5.7, 0.3,
          [{"t": [("B  ", {"color": ACCENT, "bold": True}),
                  ("MAT 파일이 갖춰야 할 조건", {})]}],
          size=15, color=INK, bold=True)
    bullets(s, 6.9, y + 0.52, 5.7, 2.2, [
        "변수가 비어 있지 않은 Simulink.SimulationData.Dataset 이어야 "
        "합니다.",
        "Harness의 현재 Scenario와 입력 개수 · 순서 · 이름 · 자료형 · "
        "차원이 모두 같아야 합니다.",
        "신호에 시간 정보가 있어야 합니다. 그것이 종료 시각의 근거입니다.",
        "Scenario를 여러 개 쓸 때는 Scenario끼리도 인터페이스가 같아야 "
        "합니다."], size=12, gap=8)
    code(s, 6.9, y + 2.9, 5.7, [
        [("% 입력 MAT 안에 이런 변수가 하나 이상 있어야 합니다",
          {"color": "8FA3AE"})],
        [("ds", {"color": CODE_KEY}),
         (" = Simulink.SimulationData.Dataset;", {})],
        [("%   신호 개수·순서·이름·자료형·차원", {"color": "8FA3AE"})],
        [("%   = Harness 입력과 완전히 동일", {"color": "8FA3AE"})]],
        size=11.5)
    chip(s, 6.9, y + 4.25, 5.7, 0.68, "",
         "하나라도 다르면 Signal Editor에 넣는 4단계에서 막힙니다.",
         fill=PANEL, bs=11.5)
    footer(s, "3단계 · 입력 데이터")
    notes(s, "B 갈래의 조건은 타협할 수 없습니다. 하나라도 어긋나면 "
             "4단계에서 반드시 막힙니다.")

    # ============================================== 11 StopTime
    s = blank(prs)
    y = title_block(s, "Harness StopTime 정하기", step=4,
                    lead="입력의 길이와 검증 시점이 여기서 맞춰집니다.")
    menu_path(s, ML, y + 0.02, 6.3,
              ["Harness 창", "Modeling", "Model Settings", "Solver",
               "Stop time"])
    table(s, ML, y + 0.62, 6.3, [1.7, 4.6],
          [["입력 갈래", "StopTime에 넣을 값"],
           ["A 기존 입력", "팀이 정한 고정값을 그대로 씁니다"],
           ["B · C 입력 파일",
            "입력 신호의 마지막 시각 중 최댓값(Tmax)을\n"
            "0.01초 격자로 올림한 값"]],
          head_h=0.4, row_h=0.62, size=12, bold_first_col=True)
    bullets(s, ML, y + 2.42, 6.3, 1.8, [
        "Tmax는 그 Scenario의 모든 입력 신호 중 가장 늦은 시각입니다.",
        "0.01초 격자로 올려 두면 Assessment의 전이 시점과 기대값을 "
        "읽는 시점이 같은 값이 됩니다.",
        "Scenario마다 길이가 다르면 가장 긴 것을 기준으로 잡습니다."],
        size=12, gap=8)
    chip(s, ML, y + 4.32, 6.3, 0.85, "",
         "StopTime을 정했으면 Harness를 저장하고 다음 단계로 넘어갑니다.",
         bs=12)
    chip(s, 7.4, y + 0.02, CW - 6.68, 2.15,
         "StopTime이 짧으면 결과가 비어 버립니다",
         "step1에서 step2로 넘어가는 시점보다 StopTime이 짧으면 verify 문장이"
         " 한 번도 실행되지 않습니다. 결과는 실패가 아니라 Untested로 "
         "남으므로, 통과한 것으로 착각하기 쉽습니다.", fill=ACCENT_TNT)
    chip(s, 7.4, y + 2.35, CW - 6.68, 1.85,
         "어디서 확인하나",
         "Signal Editor에서 각 Scenario의 신호를 열어 마지막 시간 값을 "
         "봅니다. SLDV로 만든 입력은 생성 결과의 TestCase마다 종료 시각이 "
         "적혀 있습니다.\n\n같은 값을 5단계 전이 조건에도 씁니다.")
    footer(s, "4단계 · StopTime")
    notes(s, "Untested는 실패로 보이지 않기 때문에 특히 위험합니다.")

    # ============================================== 12 Signal Editor 연결
    s = blank(prs)
    y = title_block(s, "Signal Editor에 입력 연결", step=4,
                    lead="준비한 입력을 Harness가 실제로 쓰게 만드는 "
                         "단계입니다.")
    menu_path(s, ML, y + 0.02, 6.4,
              ["Harness 창", "Signal Editor 블록 더블클릭"])
    steps(s, ML, y + 0.62, 6.4, [
        "준비한 Dataset을 Scenario로 넣습니다. A 갈래는 기존 Scenario를 "
        "그대로 씁니다.",
        "Scenario 이름을 UT_REQ_{CUT 이름}_001 부터 순서대로 바꿉니다.",
        "Save를 눌러 MAT을 저장합니다. 블록의 Filename이 그 파일을 "
        "가리켜야 합니다.",
        "Harness를 닫고 다시 열어 Active Scenario를 고릅니다."],
        gap=0.72, size=12.5)
    chip(s, 7.5, y + 0.02, CW - 6.78, 1.95, "확인",
         "· 블록 파라미터의 파일 경로가 저장한 MAT인가\n"
         "· 선택된 Scenario 이름이 UT_REQ_ 로 시작하는가\n"
         "· Scenario 개수가 의도한 개수와 같은가",
         fill=GREEN_TNT, head_color=GREEN)
    chip(s, 7.5, y + 2.15, CW - 6.78, 2.05, "연결이 안 될 때",
         "Dataset과 Harness의 입력 구성이 다르다는 뜻입니다. 개수 · 순서 · "
         "이름 · 자료형 · 차원을 하나씩 대조하십시오. 이름이 비슷하다고 "
         "연결되지 않습니다.", fill=ACCENT_TNT)
    chip(s, ML, y + 3.52, 6.4, 1.1, "Scenario 개수를 적어 두십시오",
         "6단계에서 Iteration 개수와 1:1로 맞춰야 합니다. 이 숫자를 모르면 "
         "Iteration이 맞는지 판단할 수 없습니다.")
    footer(s, "4단계 · 입력 연결")
    notes(s, "Scenario 개수는 6단계에서 바로 필요합니다.")

    # ============================================== 13 Assessment 구조
    s = blank(prs)
    y = title_block(s, "Assessment 스텝 구조", step=5,
                    lead="출력이 기대값과 같은지 판정하는 문장을 여기에 "
                         "적습니다.")
    menu_path(s, ML, y + 0.02, 6.5,
              ["Harness 창", "Test Assessment 블록 더블클릭"])
    px, pw = ML, 6.5
    rect(s, px, y + 0.64, pw, 1.75, fill=PANEL, radius=0.08)
    rect(s, px + 0.35, y + 1.02, 2.4, 0.95, fill=WHITE, radius=0.1)
    write(s, px + 0.5, y + 1.14, 2.1, 0.7,
          [{"t": "step1", "sa": 2},
           {"t": [("Action 비움", {"color": BODY, "size": 11})]}],
          size=14, color=INK, bold=True, align="c", line=1.15)
    arrow(s, px + 2.9, y + 1.42, 0.8, 0.16, color=ACCENT)
    write(s, px + 2.62, y + 1.6, 1.35, 0.3, "after(T, sec)", size=10.5,
          color=ACCENT, bold=True, align="c", font=MONO)
    rect(s, px + 3.85, y + 1.02, 2.3, 0.95, fill=WHITE, radius=0.1)
    write(s, px + 3.95, y + 1.14, 2.1, 0.7,
          [{"t": "step2", "sa": 2},
           {"t": [("verify 문장", {"color": BODY, "size": 11})]}],
          size=14, color=INK, bold=True, align="c", line=1.15)
    bullets(s, ML, y + 2.62, 6.5, 1.7, [
        "step1은 Action을 비웁니다. 출력이 정해질 때까지 기다리는 "
        "스텝입니다.",
        "전이 조건 after(T, sec)의 T가 기대값을 읽는 기준 시점입니다.",
        "step2에만 verify 문장을 넣습니다."], size=12.5, gap=8)
    write(s, 7.6, y + 0.02, CW - 6.88, 0.3, "T에 넣을 값", size=13.5,
          color=INK, bold=True)
    table(s, 7.6, y + 0.4, CW + ML - 7.6, [1.5, 2.6],
          [["입력 갈래", "T"],
           ["A 기존 입력", "0.01초"],
           ["B · C 입력 파일", "그 CUT의 Tmax"]],
          head_h=0.38, row_h=0.42, size=11.5, bold_first_col=True)
    chip(s, 7.6, y + 1.88, CW + ML - 7.6, 2.3,
         "왜 기다렸다가 판정하나",
         "0초 시점의 출력은 아직 입력이 반영되기 전 값입니다. 한 스텝 "
         "기다린 뒤 판정해야 의미 있는 값과 비교할 수 있습니다.\n\n"
         "4단계의 StopTime이 이 T보다 커야 step2에 도달합니다.")
    footer(s, "5단계 · Assessment")
    notes(s, "step1 → step2 구조는 항상 같습니다. 달라지는 것은 T와 "
             "verify 문장입니다.")

    # ============================================== 14 verify 규칙
    s = blank(prs)
    y = title_block(s, "verify 문장 작성 규칙", step=5,
                    lead="어떤 출력을 무엇과 비교할지 정하는 규칙입니다.")
    write(s, ML, y + 0.02, 6.2, 0.3, "출력 신호를 고르는 방법", size=14,
          color=INK, bold=True)
    bullets(s, ML, y + 0.46, 6.2, 2.3, [
        "입력 심볼 목록에서 Signal Editor 입력 개수만큼 건너뜁니다. "
        "그 다음부터가 Harness Outport입니다.",
        "Outport와 심볼은 이름이 아니라 위치(포트 순서)로 대응시킵니다.",
        "이름이 비슷하다고 짝을 지으면 엉뚱한 신호를 검증하게 됩니다.",
        "scalar · 숫자 배열 · Bus · 중첩 Bus를 모두 쓸 수 있습니다."],
        size=12.5, gap=9)
    chip(s, ML, y + 3.02, 6.2, 1.2, "기대값은 지금 확정하지 않습니다",
         "지금은 일단 0 같은 초기값으로 적어 두고, 7단계에서 실제 실행 "
         "결과를 보고 확정합니다.")
    write(s, 7.35, y + 0.02, CW - 6.63, 0.3, "작성 예", size=14, color=INK,
          bold=True)
    code(s, 7.35, y + 0.46, CW + ML - 7.35, [
        [("% scalar", {"color": "8FA3AE"})],
        [("verify", {"color": CODE_KEY}), ("(A == 0);", {})],
        [("", {})],
        [("% 숫자 배열 — 원소마다 한 줄", {"color": "8FA3AE"})],
        [("verify", {"color": CODE_KEY}), ("(A(1) == 0);", {})],
        [("verify", {"color": CODE_KEY}), ("(A(2) == 0);", {})],
        [("", {})],
        [("% Bus — 요소 이름으로 접근", {"color": "8FA3AE"})],
        [("verify", {"color": CODE_KEY}), ("(data(1,1).NAME == 0);", {})]],
        size=12, lh=0.26)
    chip(s, 7.35, y + 3.32, CW + ML - 7.35, 0.9, "쓸 수 있는 출력이 없을 때",
         "Harness 출력이 하나도 없으면 step2는 비어 있게 됩니다. "
         "오류가 아니며, 이 CUT은 커버리지만 수집합니다.")
    footer(s, "5단계 · verify")
    notes(s, "위치로 대응시킨다는 점이 이 장의 핵심입니다.")

    # ============================================== 15 Test Case
    s = blank(prs)
    y = title_block(s, "Test File과 Test Case 만들기", step=6,
                    lead="Harness를 실행할 주체를 Test Manager에 등록합니다.")
    menu_path(s, ML, y + 0.02, 6.4,
              ["Apps", "Simulink Test", "Test Manager"])
    steps(s, ML, y + 0.62, 6.4, [
        "New ▸ Test File 을 만들고 {TopModel}.mldatx 로 저장합니다.",
        "New ▸ Test Case ▸ Simulation Test 를 추가합니다.",
        "이름을 표에 적은 Test Case 이름으로 바꿉니다.",
        "System Under Test에서 Model을 Top Model로, Test Harness를 해당 "
        "Harness로 지정합니다.",
        "Test File을 저장합니다."], gap=0.62, size=12.5)
    chip(s, 7.5, y + 0.02, CW - 6.78, 1.75, "확인",
         "· SUT의 Test Harness 칸이 비어 있지 않은가\n"
         "· Test Case 이름이 표와 같은가\n"
         "· Test File 이름이 {TopModel}.mldatx 인가",
         fill=GREEN_TNT, head_color=GREEN)
    chip(s, 7.5, y + 1.95, CW - 6.78, 2.25, "기존 Test File을 덮어쓰지 마십시오",
         "이미 Test Case가 들어 있는 Test File이면, 없는 것만 추가하고 "
         "나머지는 건드리지 않습니다. 파일을 새로 만들어 덮으면 다른 "
         "사람이 만든 Test Case와 그 설정이 사라집니다.", fill=ACCENT_TNT)
    footer(s, "6단계 · Test Case")
    notes(s, "Test File은 팀이 공유하는 파일입니다. 덮어쓰기 금지.")

    # ============================================== 16 Iteration
    s = blank(prs)
    y = title_block(s, "Iteration 맞추기", step=6,
                    lead="입력 Scenario 하나가 Iteration 하나입니다. 1:1이 "
                         "아니면 결과를 신뢰할 수 없습니다.")
    steps(s, ML, y + 0.02, 6.3, [
        "Test Case의 Iterations ▸ Table Iterations 를 펼칩니다.",
        "Auto Generate에서 Signal Editor Scenario 기준으로 생성합니다.",
        "Scenario 개수와 Iteration 개수가 같은지 확인합니다.",
        "각 Iteration이 어느 Scenario를 가리키는지 하나씩 확인합니다."],
        gap=0.62, size=12.5)
    chip(s, ML, y + 2.62, 6.3, 1.6, "입력을 바꿨다면",
         "입력 MAT이나 Scenario를 바꾼 뒤에는 Iteration을 반드시 다시 "
         "만듭니다. 개수가 우연히 같아도 순서가 어긋나 다른 입력으로 "
         "판정될 수 있습니다.", fill=ACCENT_TNT)
    write(s, 7.4, y + 0.02, CW - 6.68, 0.3, "이렇게 1:1이어야 합니다",
          size=13.5, color=INK, bold=True)
    pairs = [("UT_REQ_Controller_001", "Iteration 1"),
             ("UT_REQ_Controller_002", "Iteration 2"),
             ("UT_REQ_Controller_003", "Iteration 3")]
    px = 7.4
    pw = CW + ML - px
    rect(s, px, y + 0.44, pw, 2.35, fill=PANEL, radius=0.08)
    for i, (sc, it) in enumerate(pairs):
        yy = y + 0.66 + i * 0.66
        rect(s, px + 0.22, yy, 2.55, 0.48, fill=WHITE, radius=0.14)
        write(s, px + 0.32, yy + 0.13, 2.35, 0.26, sc, size=10.5,
              color=INK, font=MONO)
        arrow(s, px + 2.86, yy + 0.17, 0.3, 0.16, color=ACCENT)
        rect(s, px + 3.26, yy, 1.85, 0.48, fill=WHITE, radius=0.14)
        write(s, px + 3.38, yy + 0.13, 1.65, 0.26, it, size=10.5,
              color=INK, font=MONO)
    write(s, px, y + 2.92, pw, 0.6,
          "개수뿐 아니라 순서까지 확인하십시오. 여기서 어긋나면 어떤 "
          "입력으로 돌았는지 알 수 없습니다.", size=11.5, color=MUTED,
          line=1.3)
    footer(s, "6단계 · Iteration")
    notes(s, "여기서 어긋난 채 실행하면 결과 해석이 전부 무의미해집니다.")

    # ============================================== 17 커버리지 설정
    s = blank(prs)
    y = title_block(s, "커버리지 수집 설정", step=7,
                    lead="실행 전에 무엇을 수집할지 정합니다. 필터는 "
                         "다음 장에서 만듭니다.")
    menu_path(s, ML, y + 0.02, 6.4,
              ["Test Manager", "Test File 선택", "Coverage Settings"])
    steps(s, ML, y + 0.62, 6.4, [
        "Record coverage for System Under Test 를 체크합니다.",
        "Coverage Metrics에서 Decision을 체크합니다. 여기에 포함되는 "
        "Block Execution이 함께 수집됩니다.",
        "필터를 걸지 않은 상태로 먼저 한 번 수집합니다."],
        gap=0.78, size=12.5)
    chip(s, ML, y + 3.1, 6.4, 1.1, "먼저 필터 없이 수집하는 이유",
         "무엇을 제외할지 판단하려면 제외하기 전의 결과가 필요합니다. "
         "필터부터 만들면 근거가 남지 않습니다.")
    chip(s, 7.55, y + 0.02, CW - 6.83, 1.5, "커버리지 미달은 실패가 아닙니다",
         "테스트 통과 여부와 커버리지 수치는 별개로 판단합니다. 수치가 "
         "낮다고 결과를 실패로 바꾸지 마십시오.")
    chip(s, 7.55, y + 1.7, CW - 6.83, 1.35, "분모가 0일 때",
         "비율을 계산하지 말고 N/A로 적습니다. 0%로 적으면 측정하지 "
         "못한 것과 구분되지 않습니다.")
    chip(s, 7.55, y + 3.2, CW - 6.83, 1.02, "합치지 마십시오",
         "checksum이 다른 커버리지는 합치지 않습니다.",
         fill=ACCENT_TNT)
    footer(s, "7단계 · 커버리지 설정")
    notes(s, "커버리지는 판정이 아니라 근거입니다.")
