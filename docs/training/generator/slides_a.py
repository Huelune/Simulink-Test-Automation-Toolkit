# -*- coding: utf-8 -*-
"""1~9장: 표지 · 범위 · 전체 흐름 · 0단계 · 이름 · 1단계 · 2단계 진입."""

from pptx.enum.shapes import MSO_SHAPE
from deckkit import *  # noqa
from common import chip, marker, steps, kv, menu_path


def build(prs):
    # ============================================== 1 표지
    s = blank(prs)
    dark_bg(s)
    rect(s, 8.15, 0, 5.183, SH, fill="2B3A47", shape=MSO_SHAPE.RECTANGLE)
    badge(s, 0.95, 1.15, 0.62, "M", fill=ACCENT, size=19)
    write(s, 1.73, 1.28, 4.5, 0.3, "팀 교육 자료", size=12, color=ACCENT,
          bold=True)
    write(s, 0.95, 2.05, 6.9, 2.0,
          [{"t": "Simulink 단위 테스트", "sa": 2},
           {"t": "수동 작업 매뉴얼"}],
          size=42, color=WHITE, bold=True, line=1.12)
    write(s, 0.95, 4.35, 6.9, 1.0,
          "자동화 툴킷 없이 Simulink · Test Manager GUI만으로\n"
          "CUT 한 개를 제출물까지 가져가는 전체 절차",
          size=15.5, color=DARK_FG, line=1.45)
    write(s, 0.95, 5.95, 6.9, 0.3,
          "MATLAB R2025b · Simulink Test · Simulink Coverage 기준",
          size=11.5, color=MUTED)

    write(s, 8.85, 1.18, 4.0, 0.3, "전체 8단계", size=12, color=ACCENT,
          bold=True)
    stages = [("01", "사전 확인"), ("02", "Test Harness 생성"),
              ("03", "입력 데이터 준비"), ("04", "StopTime · 입력 연결"),
              ("05", "Assessment(verify) 작성"),
              ("06", "Test Case · Iteration"),
              ("07", "실행과 기대값 확정"), ("08", "결과 정리 · 제출물")]
    yy = 1.78
    for num, name in stages:
        write(s, 8.85, yy, 0.6, 0.3, num, size=13, color=ACCENT, bold=True,
              font=MONO)
        write(s, 9.5, yy, 3.3, 0.3, name, size=13, color=DARK_FG)
        yy += 0.52
    notes(s, "자동화 명령을 쓰지 않고 사람이 직접 하는 절차만 다룹니다. "
             "오른쪽 8단계가 이 자료의 목차입니다.")
    STATE["n"] = 1

    # ============================================== 2 범위
    s = blank(prs)
    y = title_block(s, "이 자료의 범위",
                    "툴킷이 대신해 주던 일을 사람이 직접 하는 절차를 "
                    "그대로 적었습니다.")
    write(s, ML, y + 0.02, 5.8, 0.3, "수동 절차를 알아야 하는 이유",
          size=15, color=INK, bold=True)
    marker(s, ML, y + 0.5,
           "자동화가 무엇을 하고 있는지 알아야 그 결과를 검증할 수 있습니다.",
           w=6.2)
    marker(s, ML, y + 1.16,
           "툴킷을 쓸 수 없는 환경, CUT 한두 개 작업에는 수작업이 더 빠릅니다.",
           w=6.4)
    marker(s, ML, y + 1.82,
           "실행이 중간에 멈췄을 때 사람이 이어받아 마무리해야 합니다.",
           w=6.2)

    chip(s, 7.25, y + 0.02, CW - 6.53, 1.42, "다룬다",
         "CUT 하나를 기준으로 Harness 생성부터 standalone 제출물까지의 "
         "GUI 절차와 단계별 확인 항목")
    chip(s, 7.25, y + 1.62, CW - 6.53, 1.42, "다루지 않는다",
         "툴킷 명령 사용법, 관리 Excel 열 사전, 증분 재실행(checkpoint) 동작",
         fill=ACCENT_TNT)

    write(s, ML, 5.5, 5.0, 0.3, "필요한 제품", size=13, color=INK, bold=True)
    prods = [("MATLAB R2025b", "필수"), ("Simulink", "필수"),
             ("Simulink Test", "필수"), ("Simulink Coverage", "커버리지용"),
             ("Design Verifier", "입력 생성용")]
    cw = (CW - 4 * 0.24) / 5
    for i, (nm, tag) in enumerate(prods):
        xx = ML + i * (cw + 0.24)
        rect(s, xx, 5.9, cw, 0.74, fill=PANEL, radius=0.12)
        write(s, xx + 0.17, 6.02, cw - 0.34, 0.26, nm, size=12, color=INK,
              bold=True)
        write(s, xx + 0.17, 6.31, cw - 0.34, 0.24, tag, size=10.5,
              color=MUTED)
    footer(s, "범위와 전제")
    notes(s, "이 자료는 절차서이면서 자동 실행 결과를 검증하는 기준입니다.")

    # ============================================== 3 전체 흐름
    s = blank(prs)
    y = title_block(s, "전체 흐름",
                    "앞 단계의 산출물을 뒤 단계가 읽습니다. 순서를 바꾸면 "
                    "그 자리에서 실패합니다.")
    flow = [("1", "사전 확인", "백업 · CUT 경로 · 이름 규칙"),
            ("2", "Test Harness", "CUT마다 Harness를 만듭니다"),
            ("3", "입력 데이터", "기존 / MAT·SLDV 파일 / 생성"),
            ("4", "Harness 설정", "StopTime과 Signal Editor 연결"),
            ("5", "Assessment", "step1 → step2의 verify 문장"),
            ("6", "Test Case", "Test File · Test Case · Iteration"),
            ("7", "실행 · 기대값", "실행하고 기대값을 확정합니다"),
            ("8", "결과 · 제출물", "보고서 · 커버리지 · standalone")]
    cwid, gapx = 2.66, 0.41
    for i, (num, head, body) in enumerate(flow):
        col, row = i % 4, i // 4
        xx = ML + col * (cwid + gapx)
        yy = y + 0.14 + row * 2.2
        rect(s, xx, yy, cwid, 1.95, fill=PANEL, radius=0.1)
        badge(s, xx + 0.22, yy + 0.22, 0.46, num, size=15)
        write(s, xx + 0.22, yy + 0.86, cwid - 0.44, 0.3, head, size=14.5,
              color=INK, bold=True)
        write(s, xx + 0.22, yy + 1.2, cwid - 0.44, 0.62, body, size=11.5,
              color=BODY, line=1.3)
        if col < 3:
            arrow(s, xx + cwid + 0.07, yy + 0.9, 0.27, 0.2, color=LINE)
    write(s, ML, y + 4.68, CW, 0.32,
          [{"t": [("가장 자주 나는 실수", {"bold": True, "color": ACCENT}),
                  ("   3단계 입력 준비를 건너뛰거나, 입력을 바꾼 뒤 "
                   "6단계 Iteration을 다시 만들지 않는 것입니다.", {})]}],
          size=13)
    footer(s, "전체 흐름")
    notes(s, "이 장을 인쇄해 옆에 두고 작업하면 순서 오류를 줄일 수 있습니다.")

    # ============================================== 4 0단계
    s = blank(prs)
    y = title_block(s, "사전 확인", step=1,
                    lead="모델을 실제로 바꾸기 전에, 되돌릴 수 있는 상태를 "
                         "만들어 둡니다.")
    write(s, ML, y + 0.02, 6.2, 0.3, "시작 전 체크", size=15, color=INK,
          bold=True)
    for i, c in enumerate([
            "모델 · Test File(.mldatx) · 입력 MAT을 백업했는가",
            "열려 있는 모델과 Test File을 전부 저장하고 닫았는가",
            "같은 이름의 모델이 이미 로드되어 있지 않은가",
            "CUT 경로가 실제로 있는 Subsystem을 가리키는가"]):
        marker(s, ML, y + 0.5 + i * 0.62, c, w=6.4)
    chip(s, 7.35, y + 0.02, CW - 6.63, 2.48,
         "CUT 경로를 눈으로 확인하십시오",
         "경로가 틀리면 엉뚱한 블록에 Harness를 만듭니다. 뒤 단계는 전부 "
         "정상으로 돌기 때문에 끝까지 드러나지 않습니다.\n\n"
         "Top Model에서 대상 Subsystem을 선택하고 경로를 그대로 복사해 "
         "표에 넣으십시오. 기억해서 적지 마십시오.",
         fill=ACCENT_TNT)
    write(s, ML, y + 3.0, CW, 0.3, "이런 표를 하나 만들어 둔 다음 시작합니다",
          size=13, color=INK, bold=True)
    table(s, ML, y + 3.4, CW, [0.7, 1.5, 3.2, 2.1, 1.7],
          [["번호", "CUT 이름", "CUT 경로", "Harness 이름", "Test Case 이름"],
           ["1", "Controller", "TopModel/Logic/Controller",
            "Controller_Harness", "Controller"],
           ["2", "Monitor", "TopModel/Safety/Monitor",
            "Monitor_Harness", "Monitor"]],
          head_h=0.4, row_h=0.38, size=11.5,
          aligns=["c", "l", "l", "l", "l"])
    footer(s, "1단계 · 사전 확인")
    notes(s, "백업이 없으면 되돌릴 수 없습니다. 1~5단계는 모델과 Test File을 "
             "실제로 저장합니다.")

    # ============================================== 5 이름 규칙
    s = blank(prs)
    y = title_block(s, "이름 규칙을 먼저 고정하기",
                    "뒤 단계의 모든 파일 이름이 여기서 파생됩니다. 도중에 "
                    "바꾸면 제출물이 어긋납니다.")
    table(s, ML, y + 0.08, CW, [2.4, 3.6, 3.2],
          [["대상", "규칙", "예"],
           ["Harness 이름", "팀에서 정한 고정 서식", "Controller_Harness"],
           ["Test Case 이름", "CUT과 1:1", "Controller"],
           ["입력 Scenario", "UT_REQ_{CUT 이름}_{번호}",
            "UT_REQ_Controller_001"],
           ["standalone 모델", "Harness 이름과 같은 파일 이름",
            "Controller_Harness.slx"],
           ["CVF · CVT · HTML", "UT_REQ_{Test Case 이름}.확장자",
            "UT_REQ_Controller.cvf"],
           ["제출 폴더", "{번호}_UT_REQ_{Test Case 이름}",
            "1_UT_REQ_Controller"]],
          head_h=0.42, row_h=0.47, size=12, bold_first_col=True)
    chip(s, ML, 5.3, 5.85, 1.42, "규칙이 필요한 이유",
         "Scenario 이름은 Test Case의 Iteration이 가리키는 이름이기도 "
         "합니다. 둘이 어긋나면 어떤 입력으로 돌았는지 알 수 없게 됩니다.")
    chip(s, ML + 6.05, 5.3, CW - 6.05, 1.42, "공백 주의",
         "블록 이름의 공백은 CUT 경로에 그대로 넣습니다. 반대로 Harness와 "
         "Test Case 이름에는 공백을 쓰지 마십시오. 파일 이름이 됩니다.")
    footer(s, "1단계 · 이름 규칙")
    notes(s, "이름 규칙은 팀 단위로 한 번 정해 문서로 남기십시오.")

    # ============================================== 6 1단계 Harness 생성
    s = blank(prs)
    y = title_block(s, "Test Harness 생성", step=2,
                    lead="CUT 하나에 Harness 하나를 만듭니다. 모델 컴파일을 "
                         "포함하므로 수 분이 걸릴 수 있습니다.")
    menu_path(s, ML, y + 0.02, 6.35,
              ["CUT 블록 우클릭", "Test Harness", "Create for '<CUT 이름>'"])
    steps(s, ML, y + 0.72, 6.35, [
        "Top Model을 열고 표에 적은 CUT 블록을 선택합니다.",
        "우클릭 메뉴에서 Test Harness 생성을 고릅니다.",
        [{"t": [("다음 장의 설정값", {"bold": True, "color": INK}),
                ("을 그대로 지정합니다.", {})]}],
        "OK를 누르면 컴파일이 시작됩니다. 끝날 때까지 기다립니다.",
        "Harness 창이 열리면 구성 요소를 확인합니다."], gap=0.72)
    write(s, 7.5, y + 0.02, CW - 6.78, 0.3, "만들어지는 구성",
          size=13.5, color=INK, bold=True)
    px = 7.5
    pw = CW + ML - px
    rect(s, px, y + 0.44, pw, 3.62, fill=PANEL, radius=0.08)
    bw = (pw - 0.5 - 0.44) / 3
    for i, nm in enumerate([["Signal", "Editor"], ["CUT", "복사본"],
                            ["Outport", ""]]):
        bx = px + 0.25 + i * (bw + 0.22)
        rect(s, bx, y + 0.82, bw, 0.95, fill=WHITE, radius=0.1)
        lines = [ln for ln in nm if ln]
        top = y + (0.98 if len(lines) > 1 else 1.12)
        write(s, bx + 0.08, top, bw - 0.16, 0.66,
              [{"t": ln} for ln in lines], size=11.5,
              color=INK, bold=True, align="c", line=1.2)
        if i < 2:
            arrow(s, bx + bw + 0.02, y + 1.22, 0.18, 0.16, color=MUTED)
    rect(s, px + 0.25, y + 2.06, pw - 0.5, 0.95, fill=WHITE, radius=0.1)
    write(s, px + 0.4, y + 2.28, pw - 0.8, 0.5,
          [{"t": [("Test Assessment", {"bold": True, "color": INK}),
                  ("   verify 문장이 들어갈 블록", {"color": BODY})]}],
          size=11.5, align="c")
    write(s, px + 0.25, y + 3.28, pw - 0.5, 0.4,
          "Harness 창을 열어 이 네 가지가 있는지 확인합니다.",
          size=11, color=MUTED, align="c")
    write(s, ML, y + 4.42, CW, 0.32,
          [{"t": [("이미 같은 이름의 Harness가 있으면 새로 만들지 말고 "
                   "그대로 재사용하십시오.",
                   {"bold": True, "color": ACCENT}),
                  ("  지우고 다시 만들면 손으로 고친 설정이 사라집니다.",
                   {})]}], size=13)
    footer(s, "2단계 · Test Harness 생성")
    notes(s, "생성은 컴파일을 포함합니다. 멈춘 것처럼 보이는 것이 정상입니다.")

    # ============================================== 7 생성 대화상자 설정
    s = blank(prs)
    y = title_block(s, "Harness 생성 대화상자 설정값", step=2,
                    lead="이 조합이 뒤 단계의 전제입니다. 하나라도 다르면 "
                         "4~6단계에서 막힙니다.")
    table(s, ML, y + 0.04, CW, [3.1, 2.9, 5.0],
          [["항목", "값", "이유"],
           ["Name", "표에 적은 Harness 이름",
            "standalone 모델 파일 이름이 됩니다"],
           ["Sources", "Signal Editor",
            "시나리오 여러 개를 Iteration으로 쓰기 위해"],
           ["Sinks", "Outport", "verify 대상 출력을 Harness 밖으로 뺍니다"],
           ["Scheduler", "Test Sequence", "실행 순서를 스텝으로 제어합니다"],
           ["Add separate assessment block", "체크",
            "verify 문장을 넣을 Test Assessment 블록"],
           ["Automatically shape inputs", "해제",
            "입력 차원을 임의로 바꾸지 않습니다"],
           ["Save test harness externally", "해제",
            "Harness를 모델 안에 보관합니다"],
           ["Rebuild harness on open", "해제",
            "열 때마다 손으로 고친 내용이 지워지지 않게"],
           ["Verification mode", "Normal", "일반 시뮬레이션으로 실행합니다"],
           ["Synchronization mode", "Sync on harness open",
            "라이브러리 링크 CUT의 원본 역전파를 막습니다"]],
          head_h=0.4, row_h=0.35, size=11.5, bold_first_col=True)
    chip(s, ML, y + 4.12, CW, 1.02, "라이브러리에 링크된 CUT",
         "Harness를 닫을 때 CUT 복사본이 원본 모델로 되돌아가 반영될 수 "
         "있습니다. Sync on harness open으로 만들고, 링크 상태가 바뀐 것을 "
         "발견하면 모델을 저장하지 말고 닫으십시오.",
         fill=ACCENT_TNT, bs=11.5)
    footer(s, "2단계 · 생성 설정")
    notes(s, "Synchronization mode는 라이브러리 링크가 있는 CUT에서 특히 "
             "중요합니다.")

    # ============================================== 8 1단계 확인과 주의
    s = blank(prs)
    y = title_block(s, "2단계 확인과 주의", step=2,
                    lead="다음 단계로 넘어가도 되는지 여기서 판단합니다.")
    write(s, ML, y + 0.02, 5.6, 0.3, "확인", size=15, color=GREEN, bold=True)
    for i, t in enumerate([
            "모델의 CUT 블록에 Harness 배지가 붙었습니다.",
            "Harness 안에 Signal Editor · CUT 복사본 · Outport가 있습니다.",
            "Test Assessment 블록이 별도로 있습니다.",
            "Harness 이름이 표에 적은 이름과 같습니다."]):
        marker(s, ML, y + 0.48 + i * 0.64, t, w=5.7)
    write(s, 6.75, y + 0.02, 5.8, 0.3, "주의", size=15, color=ACCENT,
          bold=True)
    for i, t in enumerate([
            "이미 있는 Harness는 지우지 말고 재사용합니다.",
            "CUT 하나에 수 분 이상 걸립니다. 중간에 끊지 마십시오.",
            "Ctrl+C로 멈췄으면 열린 모델의 저장 여부를 먼저 판단합니다.",
            "라이브러리 링크 상태가 바뀌었으면 저장하지 않고 닫습니다."]):
        marker(s, 6.75, y + 0.48 + i * 0.64, t, char="!", fill=ACCENT,
               w=5.85)
    chip(s, ML, y + 3.3, CW, 1.15,
         "Harness는 원본 모델 안에 저장됩니다",
         "2단계를 끝내면 Top Model 파일 자체가 바뀝니다. 되돌릴 방법은 "
         "1단계에서 만든 백업뿐입니다. 여기서 한 번 저장하고, 이후 단계에서 "
         "문제가 생기면 이 지점으로 돌아올 수 있게 해 두십시오.")
    footer(s, "2단계 · 확인")
    notes(s, "여기서 한 번 백업 지점을 만들어 두는 것을 권합니다.")

    # ============================================== 9 2단계 세 갈래
    s = blank(prs)
    y = title_block(s, "입력 데이터 준비: 세 갈래", step=3,
                    lead="어디서 입력을 가져올지 먼저 정합니다. 뒤 단계의 "
                         "작업량이 여기서 갈립니다.")
    cards = [
        ("A", "기존 입력 그대로",
         ["Harness에 이미 있는 입력을 씁니다.",
          "Scenario 이름만 규칙에 맞게 바꿉니다.",
          "가장 빠르고 위험이 적습니다."],
         "입력이 이미 검토되어 있을 때"),
        ("B", "준비된 MAT · SLDV 파일",
         ["승인된 입력 파일을 Scenario로 넣습니다.",
          "Harness 인터페이스와 정확히 맞아야 합니다.",
          "같은 입력을 다시 쓸 수 있습니다."],
         "기준 입력 파일이 따로 있을 때"),
        ("C", "Design Verifier로 생성",
         ["SLDV 분석으로 입력을 새로 만듭니다.",
          "CUT이 Atomic이어야 합니다.",
          "가장 오래 걸립니다."],
         "쓸 수 있는 입력이 아예 없을 때")]
    cwid, gapx = 3.69, 0.41
    for i, (tag, head, items, when) in enumerate(cards):
        xx = ML + i * (cwid + gapx)
        rect(s, xx, y + 0.06, cwid, 3.5, fill=PANEL, radius=0.1)
        badge(s, xx + 0.26, y + 0.28, 0.48, tag, size=16)
        write(s, xx + 0.26, y + 0.94, cwid - 0.52, 0.34, head, size=15,
              color=INK, bold=True)
        bullets(s, xx + 0.26, y + 1.4, cwid - 0.52, 1.5, items, size=11.5,
                gap=7)
        rect(s, xx + 0.26, y + 2.74, cwid - 0.52, 0.62, fill=WHITE,
             radius=0.12)
        write(s, xx + 0.42, y + 2.85, cwid - 0.84, 0.44, when, size=11,
              color=BODY, line=1.25)
    chip(s, ML, y + 3.78, CW, 0.95, "어느 갈래든 결과물은 같아야 합니다",
         "Harness의 Signal Editor에 UT_REQ_ 규칙의 Scenario가 들어 있고, "
         "Scenario 개수와 각 입력의 마지막 시각(Tmax)을 알고 있는 상태. "
         "4단계는 이 두 값을 씁니다.")
    footer(s, "3단계 · 입력 데이터")
    notes(s, "세 갈래 중 하나를 고르되, 결과 상태는 동일해야 한다는 점을 "
             "강조하십시오.")
