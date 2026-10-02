"""copy_files_by_excel 단위 테스트 (stdlib unittest).

실행:
    python -m unittest tools/python/test_copy_files_by_excel.py
    python tools/python/test_copy_files_by_excel.py
"""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))

import copy_files_by_excel as cfe  # noqa: E402

MAIN_NS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PKG_REL_NS = 'http://schemas.openxmlformats.org/package/2006/relationships'
CONTENT_TYPES_NS = 'http://schemas.openxmlformats.org/package/2006/content-types'
SHEETML = 'application/vnd.openxmlformats-officedocument.spreadsheetml'


def _excel_installed() -> bool:
    if sys.platform != 'win32':
        return False
    import winreg
    try:
        winreg.CloseKey(winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, 'Excel.Application'))
        return True
    except OSError:
        return False


def _write_xlsx(path: Path, sheets: dict[str, list[list]]) -> None:
    """Excel 이 쓰는 구조 그대로 최소 .xlsx 를 만든다.

    셀 값: str 은 공유 문자열, int 는 숫자, ('inline', text) 는 인라인 문자열,
    ('rich', [조각...]) 은 서식 run 으로 나뉜 공유 문자열, None 은 빈 셀.
    """
    shared: list[str] = []

    def shared_index(xml: str) -> int:
        shared.append(xml)
        return len(shared) - 1

    sheet_xml = []
    for rows in sheets.values():
        row_xml = []
        for r, values in enumerate(rows, start=1):
            cells = []
            for c, value in enumerate(values):
                ref = f'{"ABC"[c]}{r}'
                if value is None:
                    continue
                if isinstance(value, int):
                    cells.append(f'<c r="{ref}"><v>{value}</v></c>')
                elif isinstance(value, tuple) and value[0] == 'inline':
                    cells.append(f'<c r="{ref}" t="inlineStr"><is><t>{escape(value[1])}</t></is></c>')
                elif isinstance(value, tuple) and value[0] == 'rich':
                    runs = ''.join(f'<r><t>{escape(p)}</t></r>' for p in value[1])
                    cells.append(f'<c r="{ref}" t="s"><v>{shared_index(runs)}</v></c>')
                else:
                    index = shared_index(f'<t>{escape(value)}</t>')
                    cells.append(f'<c r="{ref}" t="s"><v>{index}</v></c>')
            if cells:
                row_xml.append(f'<row r="{r}">{"".join(cells)}</row>')
        sheet_xml.append(
            f'<worksheet xmlns="{MAIN_NS}"><sheetData>{"".join(row_xml)}</sheetData></worksheet>')

    sheet_entries = ''.join(
        f'<sheet name="{escape(name)}" sheetId="{i}" r:id="rId{i}"/>'
        for i, name in enumerate(sheets, start=1))
    rel_entries = ''.join(
        f'<Relationship Id="rId{i}" Target="worksheets/sheet{i}.xml" '
        f'Type="{REL_NS}/worksheet"/>'
        for i in range(1, len(sheets) + 1))
    sheet_types = ''.join(
        f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="{SHEETML}.worksheet+xml"/>'
        for i in range(1, len(sheets) + 1))
    if shared:
        rel_entries += (f'<Relationship Id="rIdS" Target="sharedStrings.xml" '
                        f'Type="{REL_NS}/sharedStrings"/>')
        sheet_types += (f'<Override PartName="/xl/sharedStrings.xml" '
                        f'ContentType="{SHEETML}.sharedStrings+xml"/>')
    with zipfile.ZipFile(path, 'w') as book:
        # Excel 이 열 수 있도록 패키지 구성 파일까지 쓴다.
        book.writestr('[Content_Types].xml',
                      f'<Types xmlns="{CONTENT_TYPES_NS}">'
                      f'<Default Extension="rels" ContentType="application/'
                      f'vnd.openxmlformats-package.relationships+xml"/>'
                      f'<Default Extension="xml" ContentType="application/xml"/>'
                      f'<Override PartName="/xl/workbook.xml" ContentType="{SHEETML}.sheet.main+xml"/>'
                      f'{sheet_types}</Types>')
        book.writestr('_rels/.rels',
                      f'<Relationships xmlns="{PKG_REL_NS}"><Relationship Id="rId1" '
                      f'Type="{REL_NS}/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        book.writestr('xl/workbook.xml',
                      f'<workbook xmlns="{MAIN_NS}" xmlns:r="{REL_NS}">'
                      f'<sheets>{sheet_entries}</sheets></workbook>')
        book.writestr('xl/_rels/workbook.xml.rels',
                      f'<Relationships xmlns="{PKG_REL_NS}">{rel_entries}</Relationships>')
        for i, xml in enumerate(sheet_xml, start=1):
            book.writestr(f'xl/worksheets/sheet{i}.xml', xml)
        if shared:
            items = ''.join(f'<si>{s}</si>' for s in shared)
            book.writestr('xl/sharedStrings.xml', f'<sst xmlns="{MAIN_NS}">{items}</sst>')


def _touch(path: Path, text: str = 'x') -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


class CopyFilesByExcelTest(unittest.TestCase):

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.excel = root / '목록.xlsx'
        self.folders = root / 'folders'
        self.files = root / 'files'
        self.folders.mkdir()
        self.files.mkdir()
        _touch(self.files / 'a.mat', 'A')
        _touch(self.files / 'b.mat', 'B')

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _run(self, *extra: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cfe.main([str(self.excel), str(self.folders), str(self.files), *extra])
        return code, out.getvalue(), err.getvalue()

    def test_copies_each_file_into_its_folder_and_skips_header(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [
            ['폴더', '파일'],
            ['001_Ctrl', 'a.mat'],
            ['002_Motor', 'b.mat'],
        ]})
        code, out, _ = self._run()
        self.assertEqual(code, cfe.EXIT_OK)
        self.assertEqual((self.folders / '001_Ctrl' / 'a.mat').read_text(encoding='utf-8'), 'A')
        self.assertEqual((self.folders / '002_Motor' / 'b.mat').read_text(encoding='utf-8'), 'B')
        self.assertFalse((self.folders / '폴더').exists())
        self.assertTrue((self.files / 'a.mat').is_file(), '원본은 그대로 둔다')
        self.assertIn('복사 2', out)

    def test_existing_file_is_skipped_unless_overwrite(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [['폴더', '파일'], ['001_Ctrl', 'a.mat']]})
        _touch(self.folders / '001_Ctrl' / 'a.mat', 'OLD')
        code, out, _ = self._run()
        self.assertEqual(code, cfe.EXIT_OK)
        self.assertEqual((self.folders / '001_Ctrl' / 'a.mat').read_text(encoding='utf-8'), 'OLD')
        self.assertIn('건너뜀 1', out)

        code, _, _ = self._run('--overwrite')
        self.assertEqual(code, cfe.EXIT_OK)
        self.assertEqual((self.folders / '001_Ctrl' / 'a.mat').read_text(encoding='utf-8'), 'A')

    def test_bad_rows_fail_alone_and_the_rest_still_copy(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [
            ['폴더', '파일'],
            ['001_Ctrl', 'missing.mat'],
            ['002_Motor', None],
            [None, None],
            ['003_Ok', 'b.mat'],
        ]})
        code, out, _ = self._run()
        self.assertEqual(code, cfe.EXIT_ROW_FAILED)
        self.assertTrue((self.folders / '003_Ok' / 'b.mat').is_file())
        self.assertFalse((self.folders / '001_Ctrl').exists())
        self.assertIn('실패 2', out)
        self.assertIn('2행', out)
        self.assertIn('3행', out)

    def test_dry_run_copies_nothing(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [['폴더', '파일'], ['001_Ctrl', 'a.mat']]})
        code, out, _ = self._run('--dry-run')
        self.assertEqual(code, cfe.EXIT_OK)
        self.assertFalse((self.folders / '001_Ctrl').exists())
        self.assertIn('dry-run', out)

    def test_sheet_option_and_no_header(self) -> None:
        _write_xlsx(self.excel, {
            '다른 시트': [['999_Wrong', 'a.mat']],
            '목록': [['001_Ctrl', 'a.mat']],
        })
        code, _, _ = self._run('--sheet', '목록', '--no-header')
        self.assertEqual(code, cfe.EXIT_OK)
        self.assertTrue((self.folders / '001_Ctrl' / 'a.mat').is_file())
        self.assertFalse((self.folders / '999_Wrong').exists())

    def test_unknown_sheet_lists_available_sheets(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [['001_Ctrl', 'a.mat']]})
        code, _, err = self._run('--sheet', '없음')
        self.assertEqual(code, cfe.EXIT_INVALID)
        self.assertIn('Sheet1', err)

    def test_missing_inputs_exit_invalid(self) -> None:
        code, _, err = self._run()
        self.assertEqual(code, cfe.EXIT_INVALID)
        self.assertIn('엑셀', err)

        _write_xlsx(self.excel, {'Sheet1': [['001_Ctrl', 'a.mat']]})
        out, err_io = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err_io):
            code = cfe.main([str(self.excel), str(self.folders / 'nope'), str(self.files)])
        self.assertEqual(code, cfe.EXIT_INVALID)

    def test_reads_inline_rich_and_numeric_cells(self) -> None:
        _write_xlsx(self.excel, {'Sheet1': [
            [('inline', ' 001_Ctrl '), ('rich', ['a', '.mat'])],
            [7, 'b.mat'],
        ]})
        rows = cfe.read_columns_ab(self.excel)
        self.assertEqual(rows, [(1, '001_Ctrl', 'a.mat'), (2, '7', 'b.mat')])

    def test_non_zip_file_is_read_through_excel(self) -> None:
        # 회사 DRM(SoftCamp)은 Excel 이 저장한 .xlsx 를 SCDSA 헤더로 감싸 zip 이 아니게 만든다.
        self.excel.write_bytes(b'SCDSA004' + b'\0' * 64)
        with mock.patch.object(cfe, '_read_with_excel',
                               return_value=[(2, '001_Ctrl', 'a.mat')]) as reader:
            self.assertEqual(cfe.read_columns_ab(self.excel, '목록'), [(2, '001_Ctrl', 'a.mat')])
        reader.assert_called_once_with(self.excel, '목록')

    def test_excel_values_are_normalized_like_the_zip_reader(self) -> None:
        self.assertEqual(cfe._excel_text(None), '')
        self.assertEqual(cfe._excel_text(7.0), '7')
        self.assertEqual(cfe._excel_text(1.5), '1.5')
        self.assertEqual(cfe._excel_text(True), '1')
        self.assertEqual(cfe._excel_text(' a.mat '), 'a.mat')

    @unittest.skipUnless(_excel_installed(), 'Excel 이 있어야 한다')
    def test_excel_reader_matches_zip_reader(self) -> None:
        _write_xlsx(self.excel, {
            '목록': [
                ['폴더', '파일'],
                [7, ('rich', ['a', '.mat'])],
                [None, None],
                [' 002_모터 ', 'b 파일.mat'],
            ],
            '둘째': [['x', 'y']],
        })
        self.assertEqual(cfe._read_with_excel(self.excel, None), cfe.read_columns_ab(self.excel))
        self.assertEqual(cfe._read_with_excel(self.excel, '둘째'), [(1, 'x', 'y')])
        with self.assertRaises(cfe.InputError) as raised:
            cfe._read_with_excel(self.excel, '없음')
        self.assertIn('목록', str(raised.exception))


if __name__ == '__main__':
    unittest.main()
