"""엑셀 목록대로 파일을 폴더에 복사한다.

엑셀의 각 행에서 A열은 폴더 이름, B열은 파일 이름이다. 두 이름의 기준 경로는 실행할 때
따로 준다. 행마다 `<파일 기준>/<B열>` 파일을 `<폴더 기준>/<A열>/` 안으로 복사한다.
원본은 그대로 둔다.

    목록.xlsx                  폴더 기준/              파일 기준/
    | A         | B     |      ├── 001_Ctrl/           ├── a.mat
    | 001_Ctrl  | a.mat |  →   │   └── a.mat           └── b.mat
    | 002_Motor | b.mat |      └── 002_Motor/
                                   └── b.mat

- A열 폴더가 없으면 만든다.
- 같은 이름의 파일이 이미 있으면 건너뛴다. --overwrite 를 주면 덮어쓴다.
- B열 파일이 없거나 A·B열 중 하나만 비어 있으면 그 행만 실패로 남기고 계속한다.
  둘 다 빈 행은 넘어간다.
- 첫 번째 시트를 읽고, 값이 있는 첫 행은 제목 행으로 보고 건너뛴다
  (--sheet 이름, --no-header).
- .xlsx 를 표준 라이브러리로 직접 읽으므로 설치할 것이 없다. 회사 DRM(SoftCamp)이
  암호화한 파일처럼 zip 으로 열리지 않으면, PowerShell 로 Excel 을 보이지 않게 띄워
  읽기 전용으로 읽는다(Windows + Excel 필요). 옛 형식 .xls 는 이 경로로 읽힌다.
- 셀은 화면에 보이는 값이 아니라 저장된 값으로 읽힌다. 숫자로 저장된 셀은 001 → 1 이
  되므로, 0 으로 시작하는 이름은 Excel 에서 텍스트로 넣는다.

사용법:
    python tools/python/copy_files_by_excel.py <목록.xlsx> <폴더 기준> <파일 기준>
        [--sheet 이름] [--no-header] [--overwrite] [--dry-run]

종료 코드: 0 성공, 1 실패한 행 있음, 2 입력 검증 실패.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
SHEET_REL_ID = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id'
PACKAGE_REL = '{http://schemas.openxmlformats.org/package/2006/relationships}Relationship'

EXIT_OK = 0
EXIT_ROW_FAILED = 1
EXIT_INVALID = 2


class InputError(Exception):
    """입력 검증 실패. 종료 코드 2로 끝난다."""


def read_columns_ab(xlsx: Path, sheet: str | None = None) -> list[tuple[int, str, str]]:
    """시트에서 A열이나 B열에 값이 있는 행의 (행 번호, A열, B열). 값은 앞뒤 공백을 지운다."""
    if not zipfile.is_zipfile(xlsx):
        print(f'엑셀이 zip 형식이 아니어서(DRM 암호화 등) Excel 로 읽습니다: {xlsx}')
        return _read_with_excel(xlsx, sheet)
    try:
        with zipfile.ZipFile(xlsx) as book:
            strings = _shared_strings(book)
            root = ET.fromstring(book.read(_sheet_path(book, sheet)))
    except (zipfile.BadZipFile, KeyError, ET.ParseError, OSError) as exc:
        raise InputError(f'.xlsx 로 읽을 수 없습니다: {xlsx} ({exc})') from exc

    rows = []
    for index, row in enumerate(root.iterfind('m:sheetData/m:row', NS), start=1):
        values = {'A': '', 'B': ''}
        for cell in row.iterfind('m:c', NS):
            column = re.match(r'[A-Z]*', cell.get('r', '')).group()
            if column in values:
                values[column] = _cell_text(cell, strings).strip()
        if values['A'] or values['B']:
            rows.append((int(row.get('r', index)), values['A'], values['B']))
    return rows


def _sheet_path(book: zipfile.ZipFile, sheet: str | None) -> str:
    sheets = ET.fromstring(book.read('xl/workbook.xml')).findall('m:sheets/m:sheet', NS)
    if not sheets:
        raise InputError('엑셀에 시트가 없습니다.')
    if sheet is None:
        chosen = sheets[0]
    else:
        matches = [s for s in sheets if s.get('name') == sheet]
        if not matches:
            names = ', '.join(s.get('name', '') for s in sheets)
            raise InputError(f'시트 "{sheet}" 가 없습니다. 있는 시트: {names}')
        chosen = matches[0]
    rels = ET.fromstring(book.read('xl/_rels/workbook.xml.rels'))
    for rel in rels.iter(PACKAGE_REL):
        if rel.get('Id') == chosen.get(SHEET_REL_ID):
            target = rel.get('Target', '')
            if target.startswith('/'):
                return target.lstrip('/')
            return posixpath.normpath(posixpath.join('xl', target))
    raise InputError(f'시트 "{chosen.get("name")}" 의 데이터 위치를 찾을 수 없습니다.')


def _shared_strings(book: zipfile.ZipFile) -> list[str]:
    try:
        root = ET.fromstring(book.read('xl/sharedStrings.xml'))
    except KeyError:
        return []
    # <si><t>..</t></si> 이거나 서식 run 으로 나뉜 <si><r><t>..</t></r>...</si>.
    # 윗주(<rPh>) 안의 <t> 는 셀 값이 아니므로 뺀다.
    return [''.join(t.text or '' for t in si.findall('m:t', NS) + si.findall('m:r/m:t', NS))
            for si in root.iterfind('m:si', NS)]


def _cell_text(cell: ET.Element, strings: list[str]) -> str:
    kind = cell.get('t')
    if kind == 'inlineStr':
        return ''.join(t.text or '' for t in cell.iterfind('m:is//m:t', NS))
    value = cell.findtext('m:v', default='', namespaces=NS)
    if kind == 's' and value:
        return strings[int(value)]
    return value


# DRM 이 걸린 파일은 DRM 을 아는 Excel 만 연다. Excel 을 보이지 않게 띄워 읽기 전용으로
# 열고, A:B 를 저장된 값(Value2)으로 한 번에 가져와 행마다 JSON 한 줄로 내보낸 뒤 닫는다.
# 파일은 쓰지 않는다. 경로와 시트 이름은 따옴표 문제를 피하려고 환경 변수로 넘긴다.
EXCEL_READ_SCRIPT = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$missing = $null
try {
    $xl = New-Object -ComObject Excel.Application
    try {
        $xl.Visible = $false
        $xl.DisplayAlerts = $false
        $wb = $xl.Workbooks.Open($env:COPY_XLSX_PATH, 0, $true)
        try {
            $ws = $wb.Worksheets.Item(1)
            if ($env:COPY_XLSX_SHEET) {
                $ws = $null
                foreach ($s in $wb.Worksheets) {
                    if ($s.Name -ceq $env:COPY_XLSX_SHEET) { $ws = $s }
                }
                if (-not $ws) {
                    $missing = ($wb.Worksheets | ForEach-Object { $_.Name }) -join ', '
                }
            }
            if ($ws) {
                $used = $ws.UsedRange
                $first = $used.Row
                $count = $used.Rows.Count
                $values = $ws.Range("A${first}:B$($first + $count - 1)").Value2
                for ($i = 1; $i -le $count; $i++) {
                    [pscustomobject]@{ r = $first + $i - 1; a = $values[$i, 1]; b = $values[$i, 2] } |
                        ConvertTo-Json -Compress
                }
            }
        } finally {
            $wb.Close($false)
        }
    } finally {
        $xl.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
if ($null -ne $missing) {
    [Console]::Error.WriteLine($missing)
    exit 3
}
'''
EXCEL_TIMEOUT_SEC = 600


def _read_with_excel(xlsx: Path, sheet: str | None) -> list[tuple[int, str, str]]:
    powershell = shutil.which('powershell')
    if powershell is None:
        raise InputError(f'.xlsx 가 zip 형식이 아닌데 Excel 을 띄울 PowerShell 이 없습니다: {xlsx}')
    env = {**os.environ, 'COPY_XLSX_PATH': str(xlsx.resolve()), 'COPY_XLSX_SHEET': sheet or ''}
    encoded = base64.b64encode(EXCEL_READ_SCRIPT.encode('utf-16-le')).decode('ascii')
    try:
        completed = subprocess.run(
            [powershell, '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
            env=env, capture_output=True, timeout=EXCEL_TIMEOUT_SEC)
    except subprocess.TimeoutExpired as exc:
        raise InputError(f'Excel 이 {EXCEL_TIMEOUT_SEC}초 안에 응답하지 않았습니다: {xlsx}') from exc
    stdout = completed.stdout.decode('utf-8', errors='replace')
    stderr = completed.stderr.decode('utf-8', errors='replace').strip()
    if completed.returncode == 3:
        raise InputError(f'시트 "{sheet}" 가 없습니다. 있는 시트: {stderr}')
    if completed.returncode != 0:
        raise InputError(f'Excel 로 읽지 못했습니다: {xlsx} ({stderr})')

    rows = []
    for line in stdout.splitlines():
        if line.strip():
            item = json.loads(line)
            folder, name = _excel_text(item['a']), _excel_text(item['b'])
            if folder or name:
                rows.append((int(item['r']), folder, name))
    return rows


def _excel_text(value: object) -> str:
    """Excel Value2 를 .xlsx 에 저장된 값과 같은 글자로 바꾼다 (7.0 → '7', True → '1')."""
    if value is None:
        return ''
    if isinstance(value, bool):
        return '1' if value else '0'
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


@dataclass
class Report:
    copied: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    failed: list[str] = field(default_factory=list)


def copy_rows(rows: list[tuple[int, str, str]], folder_root: Path, file_root: Path,
              *, overwrite: bool = False, dry_run: bool = False) -> Report:
    report = Report()
    for number, folder, name in rows:
        if not folder or not name:
            report.failed.append(f'{number}행: A열 또는 B열이 비어 있습니다 (A="{folder}", B="{name}")')
            continue
        source = file_root / name
        if not source.is_file():
            report.failed.append(f'{number}행: 파일이 없습니다: {source}')
            continue
        target = folder_root / folder / source.name
        if target.exists() and not overwrite:
            report.skipped.append(f'{number}행: 이미 있음 {target}')
            continue
        if not dry_run:
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            except OSError as exc:
                report.failed.append(f'{number}행: 복사 실패 {source} → {target} ({exc})')
                continue
        report.copied.append(f'{number}행: {source} → {target}')
    return report


def _print_report(report: Report, dry_run: bool) -> None:
    copied_title = '복사 예정 (dry-run)' if dry_run else '복사'
    for title, items in ((copied_title, report.copied), ('건너뜀', report.skipped),
                         ('실패', report.failed)):
        if items:
            print(f'[{title}]')
            print('\n'.join(f'  {item}' for item in items))
    print(f'완료 | 복사 {len(report.copied)} | 건너뜀 {len(report.skipped)} | '
          f'실패 {len(report.failed)}' + (' | dry-run: 실제로 복사하지 않음' if dry_run else ''))


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='엑셀 A열 폴더에 B열 파일을 복사한다.')
    parser.add_argument('excel', type=Path, help='목록 .xlsx')
    parser.add_argument('folder_root', type=Path, help='A열 폴더 이름의 기준 경로')
    parser.add_argument('file_root', type=Path, help='B열 파일 이름의 기준 경로')
    parser.add_argument('--sheet', default=None, help='읽을 시트 이름 (기본: 첫 번째 시트)')
    parser.add_argument('--no-header', dest='header', action='store_false',
                        help='첫 행도 데이터로 읽는다 (기본: 첫 행은 제목 행)')
    parser.add_argument('--overwrite', action='store_true',
                        help='같은 이름의 파일이 이미 있으면 덮어쓴다')
    parser.add_argument('--dry-run', action='store_true',
                        help='복사하지 않고 할 일만 출력한다')
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        if not args.excel.is_file():
            raise InputError(f'엑셀 파일이 없습니다: {args.excel}')
        for label, path in (('폴더 기준 경로', args.folder_root), ('파일 기준 경로', args.file_root)):
            if not path.is_dir():
                raise InputError(f'{label}가 없습니다: {path}')
        rows = read_columns_ab(args.excel, args.sheet)
    except InputError as exc:
        print(f'오류: {exc}', file=sys.stderr)
        return EXIT_INVALID
    if args.header:
        rows = rows[1:]

    print(f'시작 | 엑셀={args.excel} | 시트={args.sheet or "(첫 번째)"} | '
          f'폴더 기준={args.folder_root} | 파일 기준={args.file_root} | 행 {len(rows)}')
    report = copy_rows(rows, args.folder_root, args.file_root,
                       overwrite=args.overwrite, dry_run=args.dry_run)
    _print_report(report, args.dry_run)
    return EXIT_ROW_FAILED if report.failed else EXIT_OK


if __name__ == '__main__':
    sys.exit(main())
