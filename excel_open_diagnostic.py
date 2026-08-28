from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import tempfile
import traceback
from contextlib import suppress
from pathlib import Path
from typing import Any, Callable


def _short_error(exc: BaseException) -> dict[str, str]:
    return {
        'type': type(exc).__name__,
        'message': str(exc),
    }


def _result(name: str) -> dict[str, Any]:
    return {
        'name': name,
        'status': 'NOT_RUN',
        'details': {},
        'error': None,
    }


def _close_book(book: Any) -> None:
    if book is None:
        return
    with suppress(Exception):
        book.close()


def _quit_app(app: Any) -> None:
    if app is None:
        return
    with suppress(Exception):
        app.quit()


def _sheet_names_xlwings(book: Any) -> list[str]:
    return [sheet.name for sheet in book.sheets]


def _sheet_names_com(book_api: Any) -> list[str]:
    count = int(book_api.Worksheets.Count)
    return [str(book_api.Worksheets.Item(i).Name) for i in range(1, count + 1)]


def test_app_books_open(xw: Any, path: Path) -> dict[str, Any]:
    item = _result('app.books.open(read_only=True)')
    app = None
    book = None
    try:
        app = xw.App(visible=False, add_book=False)
        book = app.books.open(
            str(path),
            update_links=False,
            read_only=True,
            ignore_read_only_recommended=True,
        )
        item['status'] = 'OK'
        item['details'] = {
            'excel_version': str(app.version),
            'book_name': str(book.name),
            'sheet_names': _sheet_names_xlwings(book),
            'native_read_only': bool(book.api.ReadOnly),
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        _close_book(book)
        _quit_app(app)
    return item


def test_native_workbooks_open(xw: Any, path: Path) -> dict[str, Any]:
    item = _result('app.api.Workbooks.Open(ReadOnly=True)')
    app = None
    book_api = None
    try:
        app = xw.App(visible=False, add_book=False)
        excel_api = app.api
        book_api = excel_api.Workbooks.Open(
            str(path),
            UpdateLinks=0,
            ReadOnly=True,
            IgnoreReadOnlyRecommended=True,
        )
        item['status'] = 'OK'
        item['details'] = {
            'excel_version': str(app.version),
            'book_name': str(book_api.Name),
            'sheet_names': _sheet_names_com(book_api),
            'native_read_only': bool(book_api.ReadOnly),
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        if book_api is not None:
            with suppress(Exception):
                book_api.Close(SaveChanges=False)
        _quit_app(app)
    return item


def test_book_constructor(xw: Any, path: Path) -> dict[str, Any]:
    item = _result('xw.Book(path, read_only=True)')
    book = None
    app = None
    try:
        book = xw.Book(
            str(path),
            update_links=False,
            read_only=True,
            ignore_read_only_recommended=True,
        )
        app = book.app
        item['status'] = 'OK'
        item['details'] = {
            'excel_version': str(app.version),
            'book_name': str(book.name),
            'sheet_names': _sheet_names_xlwings(book),
            'native_read_only': bool(book.api.ReadOnly),
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        _close_book(book)
        _quit_app(app)
    return item


def test_reader_mode(xw: Any, path: Path) -> dict[str, Any]:
    item = _result("xw.Book(path, mode='r')")
    book = None
    try:
        book = xw.Book(str(path), mode='r')
        item['status'] = 'OK'
        item['details'] = {
            'book_name': str(book.name),
            'sheet_names': _sheet_names_xlwings(book),
            'note': 'Reader mode opened the workbook without an interactive Excel instance.',
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        _close_book(book)
    return item


def test_read_write_open_no_save(xw: Any, path: Path) -> dict[str, Any]:
    item = _result('app.books.open(read_only=False), close without save')
    app = None
    book = None
    try:
        app = xw.App(visible=False, add_book=False)
        book = app.books.open(
            str(path),
            update_links=False,
            read_only=False,
            ignore_read_only_recommended=True,
        )
        native_read_only = bool(book.api.ReadOnly)
        item['status'] = 'OK' if not native_read_only else 'FORCED_READ_ONLY'
        item['details'] = {
            'excel_version': str(app.version),
            'book_name': str(book.name),
            'native_read_only': native_read_only,
            'note': 'The original workbook is never modified and is closed without saving.',
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        _close_book(book)
        _quit_app(app)
    return item


def test_new_workbook_save(xw: Any, target_dir: Path) -> dict[str, Any]:
    item = _result('create and save disposable workbook in target directory')
    app = None
    book = None
    probe_path = None
    try:
        app = xw.App(visible=False, add_book=False)
        book = app.books.add()
        book.sheets[0].range('A1').value = 'xlwings write probe'

        fd, temp_name = tempfile.mkstemp(
            prefix='_xlwings_write_probe_',
            suffix='.xlsx',
            dir=str(target_dir),
        )
        os.close(fd)
        os.unlink(temp_name)
        probe_path = Path(temp_name)

        book.save(str(probe_path))
        item['status'] = 'OK'
        item['details'] = {
            'probe_path': str(probe_path),
            'saved': probe_path.is_file(),
            'note': 'Disposable probe file is deleted after the test.',
        }
    except Exception as exc:
        item['status'] = 'FAIL'
        item['error'] = _short_error(exc)
    finally:
        _close_book(book)
        _quit_app(app)
        if probe_path is not None:
            with suppress(Exception):
                probe_path.unlink()
    return item


def print_human_report(report: dict[str, Any]) -> None:
    print('')
    print('============================================================')
    print('xlwings Excel Access Diagnostic')
    print('============================================================')
    print(f"Python      : {report['environment']['python_version']}")
    print(f"Platform    : {report['environment']['platform']}")
    print(f"xlwings     : {report['environment'].get('xlwings_version', 'unavailable')}")
    print(f"Target      : {report['target']['path']}")
    print(f"Exists      : {report['target']['exists']}")
    print(f"Readable    : {report['target']['readable']}")
    print('')

    for test in report['tests']:
        print(f"[{test['status']}] {test['name']}")
        if test['details']:
            for key, value in test['details'].items():
                print(f'  {key}: {value}')
        if test['error']:
            print(f"  error_type: {test['error']['type']}")
            print(f"  error: {test['error']['message']}")
        print('')

    ok_names = [
        item['name']
        for item in report['tests']
        if item['status'] == 'OK'
    ]
    print('Successful methods:')
    if ok_names:
        for name in ok_names:
            print(f'  - {name}')
    else:
        print('  - none')


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            'Compare xlwings workbook opening paths without modifying the '
            'target workbook.'
        )
    )
    parser.add_argument('workbook', help='Path to the .xlsx/.xlsm workbook')
    parser.add_argument(
        '--write-probe',
        action='store_true',
        help=(
            'Also test read-write opening without saving and create/delete '
            'a disposable workbook in the same directory.'
        ),
    )
    parser.add_argument(
        '--json-out',
        default='',
        help='Optional path for the JSON diagnostic report.',
    )
    args = parser.parse_args()

    path = Path(args.workbook).expanduser().resolve()

    report: dict[str, Any] = {
        'environment': {
            'python_version': sys.version.replace('\n', ' '),
            'platform': platform.platform(),
        },
        'target': {
            'path': str(path),
            'exists': path.is_file(),
            'readable': os.access(path, os.R_OK) if path.exists() else False,
            'writable': os.access(path, os.W_OK) if path.exists() else False,
        },
        'tests': [],
    }

    if not path.is_file():
        report['fatal_error'] = 'Target workbook does not exist.'
        print_human_report(report)
        return 2

    try:
        import xlwings as xw
    except Exception as exc:
        report['environment']['xlwings_import_error'] = _short_error(exc)
        report['fatal_error'] = 'xlwings import failed.'
        print_human_report(report)
        return 3

    report['environment']['xlwings_version'] = getattr(xw, '__version__', 'unknown')

    tests: list[Callable[[], dict[str, Any]]] = [
        lambda: test_app_books_open(xw, path),
        lambda: test_native_workbooks_open(xw, path),
        lambda: test_book_constructor(xw, path),
        lambda: test_reader_mode(xw, path),
    ]

    if args.write_probe:
        tests.extend(
            [
                lambda: test_read_write_open_no_save(xw, path),
                lambda: test_new_workbook_save(xw, path.parent),
            ]
        )

    for run_test in tests:
        try:
            report['tests'].append(run_test())
        except Exception as exc:
            report['tests'].append(
                {
                    'name': 'unexpected diagnostic failure',
                    'status': 'FAIL',
                    'details': {},
                    'error': _short_error(exc),
                    'traceback': traceback.format_exc(),
                }
            )

    print_human_report(report)

    if args.json_out:
        json_path = Path(args.json_out).expanduser().resolve()
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2),
            encoding='utf-8',
        )
        print('')
        print(f'JSON report: {json_path}')

    if any(item['status'] == 'OK' for item in report['tests']):
        return 0
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
