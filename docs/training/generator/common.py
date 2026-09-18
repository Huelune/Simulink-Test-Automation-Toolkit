# -*- coding: utf-8 -*-
"""슬라이드 조립용 공통 부품."""

from pptx.enum.shapes import MSO_SHAPE
from deckkit import *  # noqa


def chip(slide, x, y, w, h, head, body, fill=PANEL, head_color=INK,
         body_color=BODY, hs=14.5, bs=12, pad=0.22, radius=0.1):
    rect(slide, x, y, w, h, fill=fill, radius=radius)
    if head:
        write(slide, x + pad, y + pad - 0.03, w - pad * 2, 0.32, head,
              size=hs, color=head_color, bold=True, line=1.1)
    off = 0.33 if head else 0.0
    if body:
        write(slide, x + pad, y + pad + off, w - pad * 2,
              max(h - pad * 2 - off, 0.22), body, size=bs,
              color=body_color, line=1.32)


def marker(slide, x, y, text, char="✓", fill=GREEN, w=5.2,
           size=13, color=BODY, d=0.28, lead=None):
    badge(slide, x, y + 0.03, d, char, fill=fill, size=11.5,
          shape=MSO_SHAPE.OVAL, radius=None, font="Arial")
    if lead:
        spans = [{"t": [(lead, {"bold": True, "color": INK}), (text, {})]}]
    else:
        spans = [{"t": text}]
    write(slide, x + d + 0.18, y, w - d - 0.18, 0.62, spans,
          size=size, color=color, line=1.3)


def steps(slide, x, y, w, items, gap=0.52, size=13, d=0.3, fill=INK,
          start=1, h=None):
    yy = y
    for i, it in enumerate(items):
        badge(slide, x, yy + 0.02, d, start + i, fill=fill, size=11.5,
              shape=MSO_SHAPE.OVAL, radius=None)
        if isinstance(it, str):
            it = [{"t": it}]
        elif isinstance(it, dict):
            it = [it]
        write(slide, x + d + 0.2, yy - 0.02, w - d - 0.2,
              (h or gap) + 0.3, it, size=size, color=BODY, line=1.32)
        yy += gap
    return yy


def kv(slide, x, y, w, pairs, gap=0.42, size=12.5, label_w=1.5):
    yy = y
    for k, v in pairs:
        write(slide, x, yy, label_w, 0.3, k, size=size, color=ACCENT,
              bold=True)
        write(slide, x + label_w, yy, w - label_w, 0.34, v, size=size,
              color=BODY, line=1.3)
        yy += gap
    return yy


def menu_path(slide, x, y, w, parts, size=12.5, h=0.38):
    """Simulink 메뉴 경로를 한 줄로 강조."""
    rect(slide, x, y, w, h, fill=PANEL_DK, radius=0.14)
    chunks = []
    for i, p in enumerate(parts):
        if i:
            chunks.append(("  ▸  ", {"color": ACCENT, "bold": True}))
        chunks.append((p, {"color": INK, "bold": True}))
    write(slide, x + 0.16, y + 0.075, w - 0.32, h, [{"t": chunks}],
          size=size, line=1.1)
