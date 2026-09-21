"""classify_standalone_results 단위 테스트 (stdlib unittest).

실행:
    python -m unittest tools/python/test_classify_standalone_results.py
    python tools/python/test_classify_standalone_results.py
"""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import classify_standalone_results as csr  # noqa: E402

CUT_A = '001_UT_REQ_Controller_12345'
CUT_B = '002_UT_REQ_Motor_Ctrl_Unit_67890'


def _touch(path: Path, text: str = 'x') -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


def _build_pipeline(root: Path, mldatx_names: tuple[str, ...] = ('TOP.mldatx',)) -> Path:
    pipeline = root / 'standalone_coverage' / '20250921_143312_871_3f9a2c1b'
    _touch(pipeline / 'pipeline-manifest.json')
    _touch(pipeline / 'pipeline-manifest.sha256')
    _touch(pipeline / 'CoverageSummary.xlsx')
    _touch(pipeline / 'StandaloneCoverageResults.mldatx')
    _touch(pipeline / 'logs' / 'execution.log')
    _touch(pipeline / '.work' / 'bundle' / 'template' / 'x.txt')
    for name in mldatx_names:
        _touch(pipeline / 'TestManager' / name)
    _touch(pipeline / 'TestManager' / 'open_standalone_coverage_test_manager.m')

    cut_a = pipeline / CUT_A
    _touch(cut_a / 'Controller_Harness.slx')
    _touch(cut_a / 'TOP_Controller_Harness_HarnessInputs.mat')
    _touch(cut_a / 'UT_REQ_Controller_12345.cvf')
    _touch(cut_a / 'UT_REQ_Controller_12345.cvt')
    _touch(cut_a / 'UT_REQ_Controller_12345.html')
    _touch(cut_a / 'UT_REQ_Controller_12345_files' / 'style.css')
    _touch(cut_a / 'UT_REQ_Controller_12345_files' / 'img' / 'a.png')
    _touch(cut_a / 'scv_images' / 'block1.png')
    _touch(cut_a / 'target-manifest.json')

    # 실행에 실패한 대상: 하네스와 Input만 있고 보고서가 없다.
    cut_b = pipeline / CUT_B
    _touch(cut_b / 'Motor_Ctrl_Unit_Harness.slx')
    _touch(cut_b / 'TOP_Motor_Harness_HarnessInputs.mat')
    _touch(cut_b / 'target-manifest.json')
    return pipeline


def _listing(root: Path) -> list[str]:
    return sorted(p.relative_to(root).as_posix() for p in root.rglob('*'))


def _run(argv: list[str]) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = csr.main(argv)
    return code, out.getvalue(), err.getvalue()


class ClassifyStandaloneResultsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_builds_three_way_tree_and_keeps_names(self) -> None:
        pipeline = _build_pipeline(self.root)
        before = _listing(pipeline)

        code, out, err = _run([str(pipeline)])

        self.assertEqual(code, csr.EXIT_OK, err)
        output = pipeline.parent / 'TOP'
        expected = {
            f'{csr.TEST_CASE_DIR}/{CUT_A}/TOP_Controller_Harness_HarnessInputs.mat',
            f'{csr.TEST_CASE_DIR}/{CUT_B}/TOP_Motor_Harness_HarnessInputs.mat',
            f'{csr.REPORT_DIR}/TOP.mldatx',
            f'{csr.REPORT_DIR}/{CUT_A}/UT_REQ_Controller_12345.cvf',
            f'{csr.REPORT_DIR}/{CUT_A}/UT_REQ_Controller_12345.cvt',
            f'{csr.REPORT_DIR}/{CUT_A}/UT_REQ_Controller_12345.html',
            f'{csr.REPORT_DIR}/{CUT_A}/UT_REQ_Controller_12345_files/style.css',
            f'{csr.REPORT_DIR}/{CUT_A}/UT_REQ_Controller_12345_files/img/a.png',
            f'{csr.PROJECT_DIR}/{CUT_A}/Controller_Harness.slx',
            f'{csr.PROJECT_DIR}/{CUT_B}/Motor_Ctrl_Unit_Harness.slx',
        }
        files = {p for p in _listing(output) if (output / p).is_file()}
        self.assertEqual(files, expected)
        # 실패한 대상도 세 갈래 모두에 폴더가 있다.
        self.assertTrue((output / csr.REPORT_DIR / CUT_B).is_dir())
        # 원본은 그대로.
        self.assertEqual(_listing(pipeline), before)
        self.assertIn(f'WARN 비어 있는 갈래', out)
        self.assertIn(f'{CUT_B} / {csr.REPORT_DIR}', out)

    def test_skipped_items_are_reported_not_copied(self) -> None:
        pipeline = _build_pipeline(self.root)
        plan = csr.build_plan(pipeline, None, overwrite=False)
        skipped = set(plan.skipped)
        for item in (
            'pipeline-manifest.json', 'pipeline-manifest.sha256', 'CoverageSummary.xlsx',
            'StandaloneCoverageResults.mldatx', 'logs', '.work',
            'TestManager/open_standalone_coverage_test_manager.m',
            f'{CUT_A}/target-manifest.json', f'{CUT_B}/target-manifest.json',
            f'{CUT_A}/scv_images',
        ):
            self.assertIn(item, skipped)
        self.assertNotIn(f'{CUT_A}/scv_images', {src.relative_to(pipeline).as_posix() for src, _ in plan.trees})
        self.assertNotIn('TestManager/TOP.mldatx', skipped)
        self.assertEqual(plan.count(csr.TEST_CASE_DIR), 2)
        self.assertEqual(plan.count(csr.REPORT_DIR), 4)  # cvf, cvt, html, mldatx
        self.assertEqual(plan.count(csr.PROJECT_DIR), 2)

    def test_rejects_missing_or_ambiguous_mldatx(self) -> None:
        none = _build_pipeline(self.root / 'none', mldatx_names=())
        two = _build_pipeline(self.root / 'two', mldatx_names=('TOP.mldatx', 'OTHER.mldatx'))
        for pipeline in (none, two):
            code, _, err = _run([str(pipeline)])
            self.assertEqual(code, csr.EXIT_INVALID)
            self.assertIn('.mldatx', err)

    def test_existing_output_requires_overwrite(self) -> None:
        pipeline = _build_pipeline(self.root)
        (pipeline.parent / 'TOP').mkdir()
        code, _, err = _run([str(pipeline)])
        self.assertEqual(code, csr.EXIT_INVALID)
        self.assertIn('--overwrite', err)
        code, _, err = _run([str(pipeline), '--overwrite'])
        self.assertEqual(code, csr.EXIT_OK, err)

    def test_dry_run_writes_nothing(self) -> None:
        pipeline = _build_pipeline(self.root)
        code, out, _ = _run([str(pipeline), '--dry-run'])
        self.assertEqual(code, csr.EXIT_OK)
        self.assertFalse((pipeline.parent / 'TOP').exists())
        self.assertIn('[DRY-RUN]', out)

    def test_out_argument_and_nested_output_rejected(self) -> None:
        pipeline = _build_pipeline(self.root)
        target = self.root / 'deliver' / 'anything'
        code, _, err = _run([str(pipeline), '--out', str(target)])
        self.assertEqual(code, csr.EXIT_OK, err)
        self.assertTrue((target / csr.REPORT_DIR / 'TOP.mldatx').is_file())
        code, _, err = _run([str(pipeline), '--out', str(pipeline / 'inside')])
        self.assertEqual(code, csr.EXIT_INVALID)
        self.assertIn('입력 폴더 안', err)


if __name__ == '__main__':
    unittest.main()
