# -*- coding: utf-8 -*-
import sys
from deckkit import new_deck
import slides_a, slides_b, slides_c

out = sys.argv[1] if len(sys.argv) > 1 else "manual.pptx"
prs = new_deck()
slides_a.build(prs)
slides_b.build(prs)
slides_c.build(prs)
prs.core_properties.title = "Simulink 단위 테스트 수동 작업 매뉴얼"
prs.core_properties.subject = "툴킷 없이 GUI로 진행하는 전체 절차"
prs.save(out)
print("saved:", out, "slides:", len(prs.slides._sldIdLst))
