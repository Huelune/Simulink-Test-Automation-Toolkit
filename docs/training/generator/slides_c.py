# -*- coding: utf-8 -*-
"""18~25장: CVF · 실행 · 결과 정리 · 제출물 · 체크리스트 · 마무리."""

from pptx.enum.shapes import MSO_SHAPE
from deckkit import *  # noqa
from common import chip, marker, steps, kv, menu_path


def build(prs):
    # ============================================== 18 CVF
    s = blank(prs)
    y = title_block(s, "Coverage Filter(CVF) 만들기", step=7,
                    lead="제외할 범위를 파일로 남깁니다. 실행하는 쪽이 "
                         "만드는 것이고 준비 단계가 아닙니다.")
    write(s, ML, y + 0.02, 6.3, 0.3, "규칙을 만드는 기준", size=14,
          color=INK, bold=True)
    bullets(s, ML, y + 0.46, 6.3, 2.2, [
        "CUT 자체가 아니라 직속 하위 Subsystem마다 규칙을 만듭니다.",
        "CUT 바깥의 최상위 블록은 따로 제외 규칙을 만듭니다.",
        "Action은 Exclude, 사유(Rationale)는 반드시 채웁니다. 빈 사유는 "
        "근거가 남지 않습니다."], size=12.5, gap=9)
    chip(s, ML, y + 2.62, 6.3, 1.55, "규칙 0개도 정상입니다",
         "제외할 것이 없으면 규칙이 없는 CVF가 됩니다. 오류가 아니며, "
         "필터는 실행 방식이나 결과 판정을 바꾸지 않습니다. 커버리지 "
         "수치의 분모만 달라집니다.")
    write(s, 7.4, y + 0.02, CW + ML - 7.4, 0.3, "절차", size=14, color=INK,
          bold=True)
    steps(s, 7.4, y + 0.46, CW + ML - 7.4, [
        "Coverage Filter Editor에서 규칙을 추가합니다.",
        "UT_REQ_{Test Case 이름}.cvf 로 저장합니다.",
        "Test Manager 실행 설정의 Coverage Filter에 등록합니다.",
        "실행이 끝나면 원래 필터 설정으로 되돌립니다."],
        gap=0.62, size=12.5)
    chip(s, 7.4, y + 3.0, CW + ML - 7.4, 1.17,
         "복원을 잊지 마십시오",
         "임시로 등록한 필터를 그대로 두면 다음 실행과 다른 사람의 결과에도"
         " 그 필터가 적용됩니다.", fill=ACCENT_TNT)
    footer(s, "7단계 · Coverage Filter")
    notes(s, "사유가 비어 있는 제외는 심사에서 받아들여지지 않습니다.")

    # ============================================== 19 실행과 기대값
    s = blank(prs)
    y = title_block(s, "실행하고 기대값 확정하기", step=7,
                    lead="여기서 처음으로 결과가 나옵니다. 그리고 기대값이 "
                         "바뀔 수 있는 유일한 단계입니다.")
    steps(s, ML, y + 0.04, 6.5, [
        "Harness Outport 신호 로깅을 켭니다. 실제값을 읽어야 합니다.",
        "Test Case를 실행합니다.",
        "실패한 Iteration에서 기준 시점의 실제값을 확인합니다. "
        "(Simulation Data Inspector)",
        "verify의 기대값을 그 값으로 고칩니다.",
        "다시 실행해 통과를 확인합니다."], gap=0.68, size=12.5)
    chip(s, ML, y + 3.52, 6.5, 0.72, "",
         "전부 A 갈래이고 기대값을 바꿀 필요가 없으면 1회 실행으로 "
         "끝냅니다.", bs=12)
    write(s, 7.6, y + 0.04, CW + ML - 7.6, 0.3, "실제값을 읽는 기준 시점",
          size=13.5, color=INK, bold=True)
    table(s, 7.6, y + 0.42, CW + ML - 7.6, [1.5, 2.6],
          [["입력 갈래", "기준 시점"],
           ["A 기존 입력", "0.01초"],
           ["B · C 입력 파일", "그 CUT의 Tmax"]],
          head_h=0.38, row_h=0.42, size=11.5, bold_first_col=True)
    chip(s, 7.6, y + 1.9, CW + ML - 7.6, 1.2, "5단계의 T와 같은 값입니다",
         "전이 조건, StopTime, 실제값을 읽는 시점이 모두 같은 값을 "
         "가리켜야 합니다.")
    chip(s, 7.6, y + 3.28, CW + ML - 7.6, 0.96, "기록하십시오",
         "어떤 verify가 무엇에서 무엇으로 바뀌었는지 남기십시오.",
         fill=ACCENT_TNT)
    footer(s, "7단계 · 실행")
    notes(s, "로깅을 켜지 않으면 실제값을 읽을 수 없어 4번을 할 수 "
             "없습니다.")

    # ============================================== 20 기대값 경고 (dark)
    s = blank(prs)
    dark_bg(s)
    badge(s, ML, 0.78, 0.66, "!", fill=ACCENT, size=22)
    write(s, ML + 0.92, 0.72, CW - 0.92, 0.6, "기대값을 바꾼다는 것",
          size=31, color=WHITE, bold=True, line=1.0)
    write(s, ML, 1.78, CW - 1.0, 1.1,
          "기대값을 실제값으로 맞추는 일은\n테스트를 통과시키는 일입니다.",
          size=26, color=ACCENT, bold=True, line=1.3)
    rules = [
        ("승인된 기준값은 바꾸지 마십시오",
         "그 경우 고쳐야 하는 것은 기대값이 아니라 모델이나 입력입니다."),
        ("바꿀 때는 근거를 남기십시오",
         "어떤 verify가 어떻게 바뀌었는지, 그 값이 맞는 이유를 적습니다."),
        ("배열과 Bus는 한 줄씩 확인",
         "여러 줄이 한꺼번에 바뀌면 의도하지 않은 값이 섞여 들어갑니다.")]
    cwid, gapx = 3.69, 0.41
    for i, (head, body) in enumerate(rules):
        xx = ML + i * (cwid + gapx)
        rect(s, xx, 3.5, cwid, 2.1, fill="2E3D4A", radius=0.1)
        badge(s, xx + 0.26, 3.72, 0.42, i + 1, fill=ACCENT, size=14)
        write(s, xx + 0.26, 4.32, cwid - 0.52, 0.42, head, size=14,
              color=WHITE, bold=True, line=1.25)
        write(s, xx + 0.26, 4.86, cwid - 0.52, 0.95, body, size=11.5,
              color=DARK_FG, line=1.32)
    write(s, ML, 6.05, CW, 0.4,
          "목적은 실패를 없애는 것이 아니라, 무엇이 맞는 값인지 정하는 "
          "것입니다.", size=13.5, color=MUTED)
    footer(s, "7단계 · 기대값")
    notes(s, "이 장은 반드시 소리 내어 읽고 넘어가십시오.")

    # ============================================== 21 결과 정리
    s = blank(prs)
    y = title_block(s, "결과 정리", step=8,
                    lead="실행 결과는 그 MATLAB 세션에서만 살아 있습니다. "
                         "파일로 남겨야 나중에 볼 수 있습니다.")
    steps(s, ML, y + 0.04, 6.4, [
        "Results and Artifacts에서 결과를 .mldatx 로 Export합니다.",
        "Test Results에서 보고서를 만듭니다. (PDF 또는 HTML)",
        "커버리지 보고서는 HTML 한 개가 아니라 폴더 전체를 복사합니다.",
        "요약 표에 수치를 옮겨 적습니다."], gap=0.66, size=12.5)
    chip(s, ML, y + 2.78, 6.4, 1.44, "HTML 한 개만 보내지 마십시오",
         "커버리지 HTML은 같은 폴더의 리소스 파일이 없으면 렌더링이 "
         "깨집니다. 받는 쪽에서는 빈 페이지로 보입니다. 폴더 단위로 "
         "전달하십시오.", fill=ACCENT_TNT)
    write(s, 7.5, y + 0.04, CW + ML - 7.5, 0.3, "요약 표에 적는 항목",
          size=13.5, color=INK, bold=True)
    px = 7.5
    pw = CW + ML - px
    rect(s, px, y + 0.42, pw, 3.8, fill=PANEL, radius=0.08)
    cols = ["번호", "CUT 이름", "CUT 경로", "Test Case 이름",
            "Harness 이름", "Decision 실행 / 전체 / %",
            "Execution 실행 / 전체 / %"]
    yy = y + 0.66
    for i, c in enumerate(cols):
        write(s, px + 0.28, yy, 0.42, 0.28, "%02d" % (i + 1), size=11,
              color=ACCENT, bold=True, font=MONO)
        write(s, px + 0.78, yy, pw - 1.06, 0.3, c, size=12, color=INK)
        yy += 0.44
    write(s, px + 0.28, yy + 0.06, pw - 0.56, 0.4,
          "분모가 0이면 비율 대신 N/A로 적습니다.", size=11.5,
          color=MUTED, line=1.3)
    footer(s, "8단계 · 결과 정리")
    notes(s, "세션을 닫으면 결과 객체는 사라집니다. 먼저 내보내십시오.")

    # ============================================== 22 standalone
    s = blank(prs)
    y = title_block(s, "standalone 제출물 만들기", step=8,
                    lead="받는 쪽에 원본 Top Model이 없어도 열리는 결과물을 "
                         "만듭니다.")
    steps(s, ML, y + 0.04, 6.4, [
        "원본 Top Model과 Harness를 저장하고 닫습니다. 이름이 충돌합니다.",
        "Harness를 독립 모델(.slx)로 내보냅니다. 파일 이름은 Harness "
        "이름과 같게 둡니다.",
        "Test File 사본에서 Test Case의 Model을 그 독립 모델로 바꾸고 "
        "Harness 지정을 비웁니다.",
        "Assessment의 신호 경로를 독립 모델 기준으로 다시 잡고 "
        "확인합니다.",
        "CVF를 등록하고 한 번만 실행합니다.",
        "커버리지 결과에서 CVT와 원본 HTML을 꺼내 폴더에 넣습니다."],
        gap=0.62, size=12)
    write(s, 7.5, y + 0.04, CW + ML - 7.5, 0.3, "CUT 하나의 제출 폴더",
          size=13.5, color=INK, bold=True)
    code(s, 7.5, y + 0.44, CW + ML - 7.5, [
        [("1_UT_REQ_Controller/", {"color": CODE_KEY, "bold": True})],
        "  Controller_Harness.slx",
        "  Controller_Harness_Input.mat",
        "  UT_REQ_Controller.cvf",
        "  UT_REQ_Controller.cvt",
        "  UT_REQ_Controller.html",
        "  target-manifest.json"], size=11.5, lh=0.27)
    chip(s, 7.5, y + 2.68, CW + ML - 7.5, 1.54,
         "없는 파일을 만들지 마십시오",
         "실행하지 못한 대상도 폴더는 만듭니다. 다만 CVT나 HTML이 없으면 "
         "없는 대로 남기고, 통과한 것처럼 보이게 채우지 않습니다.",
         fill=ACCENT_TNT)
    footer(s, "8단계 · 제출물")
    notes(s, "독립 모델로 바꾼 뒤 Assessment 경로 재확인이 가장 자주 "
             "빠집니다.")

    # ============================================== 23 체크리스트
    s = blank(prs)
    y = title_block(s, "단계별 완료 조건",
                    "다음 단계로 넘어가도 되는지 이 표로 판단합니다.")
    table(s, ML, y + 0.06, CW, [0.8, 2.7, 6.3],
          [["#", "단계", "끝났다고 볼 수 있는 조건"],
           ["1", "사전 확인",
            "백업이 있고, CUT 경로가 실제 Subsystem을 가리킨다"],
           ["2", "Test Harness",
            "CUT에 배지가 붙고, Signal Editor · CUT 복사본 · Outport · "
            "Test Assessment가 있다"],
           ["3", "입력 데이터",
            "Scenario 개수와 각 Scenario의 Tmax를 알고 있다"],
           ["4", "StopTime · 연결",
            "선택된 Scenario 이름이 UT_REQ_로 시작하고, StopTime이 T보다 "
            "크다"],
           ["5", "Assessment",
            "step2에 검증할 출력마다 verify 줄이 있다"],
           ["6", "Test Case",
            "Scenario 개수 = Iteration 개수이고, SUT에 Harness가 "
            "지정되어 있다"],
           ["7", "실행",
            "결과가 Untested가 아니고, 바뀐 기대값이 기록되어 있다"],
           ["8", "결과 · 제출물",
            "폴더에 모델 · 입력 · CVF · CVT · HTML이 모두 있다"]],
          head_h=0.38, row_h=0.53, size=12,
          aligns=["c", "l", "l"], bold_first_col=True)
    footer(s, "체크리스트")
    notes(s, "이 표만 따로 인쇄해 작업 중에 채우도록 하십시오.")

    # ============================================== 24 자주 나는 실수
    s = blank(prs)
    y = title_block(s, "자주 나는 실수",
                    "여섯 가지가 대부분입니다. 증상과 대처를 함께 "
                    "적었습니다.")
    mistakes = [
        ("입력 준비를 건너뛴다",
         "뒤 단계가 전부 실패합니다.", "3단계부터 다시 합니다."),
        ("입력을 바꾸고 Iteration을 그대로 둔다",
         "다른 입력으로 판정됩니다.", "6단계를 다시 만듭니다."),
        ("StopTime이 T보다 짧다",
         "verify가 Untested로 남습니다.", "4단계에서 StopTime을 올립니다."),
        ("Outport와 심볼을 이름으로 짝지었다",
         "엉뚱한 신호를 검증합니다.", "포트 위치로 다시 대응시킵니다."),
        ("실행 후 필터를 복원하지 않았다",
         "다음 실행에 설정이 남습니다.", "실행 직후 바로 되돌립니다."),
        ("기대값을 무심코 실제값으로 맞췄다",
         "통과처럼 보이는 실패가 됩니다.", "기록을 보고 다시 검토합니다.")]
    cwid, gapx, chgt = 3.69, 0.41, 2.12
    for i, (head, sym, fix) in enumerate(mistakes):
        col, row = i % 3, i // 3
        xx = ML + col * (cwid + gapx)
        yy = y + 0.08 + row * (chgt + 0.28)
        rect(s, xx, yy, cwid, chgt, fill=PANEL, radius=0.1)
        badge(s, xx + 0.24, yy + 0.22, 0.42, i + 1, size=14)
        write(s, xx + 0.24, yy + 0.78, cwid - 0.48, 0.62, head, size=13,
              color=INK, bold=True, line=1.25)
        write(s, xx + 0.24, yy + 1.4, cwid - 0.48, 0.3, sym, size=11.5,
              color=ACCENT, line=1.2)
        write(s, xx + 0.24, yy + 1.72, cwid - 0.48, 0.3,
              [{"t": [("대처  ", {"bold": True, "color": INK}),
                      (fix, {"color": BODY})]}], size=11.5, line=1.2)
    footer(s, "자주 나는 실수")
    notes(s, "실수 목록은 팀에서 겪은 사례를 계속 추가하십시오.")

    # ============================================== 25 마무리
    s = blank(prs)
    dark_bg(s)
    write(s, ML, 0.72, CW, 0.6, "수작업의 양, 그리고 다음 단계", size=31,
          color=WHITE, bold=True, line=1.0)
    write(s, ML, 1.5, CW - 1.0, 0.4,
          "CUT 한 개를 끝내기 위해 사람이 해야 하는 일입니다.",
          size=13.5, color=MUTED)
    stats = [("8", "단계"), ("10", "Harness 생성 설정 항목"),
             ("8", "단계별 완료 조건")]
    cwid, gapx = 3.69, 0.41
    for i, (num, label) in enumerate(stats):
        xx = ML + i * (cwid + gapx)
        rect(s, xx, 2.2, cwid, 1.5, fill="2E3D4A", radius=0.1)
        write(s, xx + 0.28, 2.34, cwid - 0.56, 0.8, num, size=48,
              color=ACCENT, bold=True, line=1.0)
        write(s, xx + 0.28, 3.16, cwid - 0.56, 0.36, label, size=12.5,
              color=DARK_FG)
    write(s, ML, 3.95, CW, 0.4,
          [{"t": [("CUT이 20개면 이 전부를 20번 반복합니다.",
                   {"bold": True, "color": WHITE}),
                  ("  입력이나 모델이 바뀌면 처음부터 다시 합니다.",
                   {"color": MUTED})]}], size=13.5)
    write(s, ML, 4.72, 5.9, 0.36, "이 절차를 그대로 자동화한 것이 "
          "저장소의 툴킷입니다", size=13.5, color=WHITE, bold=True)
    code(s, ML, 5.18, 5.9, [
        "st_setup",
        "st_pre_validate_targets",
        "st_run_from_harness",
        [("st_run_standalone_coverage_pipeline", {"color": CODE_KEY}),
         ("('Action','ALL')", {})]], size=11.5, lh=0.26, bg="141E25")
    rect(s, ML + 6.35, 4.72, CW - 6.35, 1.72, fill="2E3D4A", radius=0.1)
    write(s, ML + 6.6, 4.94, CW - 6.85, 1.3,
          "그래도 이 절차를 알고 있어야 합니다. 자동 실행 결과가 맞는지 "
          "판단하는 기준이 이 절차이고, 실행이 중간에 멈추면 사람이 "
          "이어받아야 합니다.", size=13, color=DARK_FG, line=1.4)
    footer(s, "마무리")
    notes(s, "수동 절차는 자동화의 대안이 아니라 검증 기준이라는 점으로 "
             "마무리하십시오.")
