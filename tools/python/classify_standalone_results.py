"""standalone 커버리지 결과물을 팀 제출 트리로 재배치한다.

입력은 standalone 파이프라인이 만든 폴더 하나(`result/standalone_coverage/{PipelineId}`)다.
그 안의 CUT 폴더 `{NUM}_UT_REQ_{TestCaseName}` 에는 하네스 `.slx`, Input `.mat`,
`UT_REQ_*.cvf/.cvt/.html` 과 HTML 부속 asset 폴더가 섞여 있다. 이 스크립트는 파일 이름을
바꾸지 않고 확장자별로 세 갈래에 복사한다. 원본은 그대로 둔다.

    {TopModel}/                         TestManager/{TopModel}.mldatx 의 stem
    ├── 테스트 케이스/{CUT 폴더}/       *.mat
    ├── 테스트 보고서/{TopModel}.mldatx
    ├── 테스트 보고서/{CUT 폴더}/       *.cvf *.cvt *.html + asset 하위 폴더
    └── 프로젝트/{CUT 폴더}/            *.slx

세 갈래에 들지 않는 파일(CoverageSummary.xlsx, manifest, logs, target-manifest.json,
launcher .m, .work, .provenance 등)과 CUT 폴더 안의 `scv_images` 폴더는 복사하지 않고
건너뛴 목록으로만 출력한다.

사용법:
    python tools/python/classify_standalone_results.py <pipeline_root> [--out DIR] [--dry-run] [--overwrite]

종료 코드: 0 성공, 1 복사 중 예외, 2 입력/출력 검증 실패.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path

CUT_FOLDER_PATTERN = re.compile(r'^\d{3}_UT_REQ_')
TEST_MANAGER_DIR = 'TestManager'
# CUT 폴더 안에 있어도 제출하지 않는 하위 폴더 (대소문자 무시)
EXCLUDED_DIR_NAMES = frozenset({'scv_images'})

TEST_CASE_DIR = '테스트 케이스'
REPORT_DIR = '테스트 보고서'
PROJECT_DIR = '프로젝트'
CATEGORIES = (TEST_CASE_DIR, REPORT_DIR, PROJECT_DIR)
CATEGORY_BY_SUFFIX = {
    '.mat': TEST_CASE_DIR,
    '.slx': PROJECT_DIR,
    '.cvf': REPORT_DIR,
    '.cvt': REPORT_DIR,
    '.html': REPORT_DIR,
}

EXIT_OK = 0
EXIT_COPY_FAILED = 1
EXIT_INVALID = 2


class ClassifyError(Exception):
    """입력이나 출력 검증 실패. 종료 코드 2로 끝난다."""


@dataclass
class Plan:
    pipeline_root: Path
    model_name: str
    output_root: Path
    cut_folders: list[str] = field(default_factory=list)
    # (원본 파일, 대상 파일)
    files: list[tuple[Path, Path]] = field(default_factory=list)
    # (원본 폴더, 대상 폴더) — HTML 부속 asset 트리
    trees: list[tuple[Path, Path]] = field(default_factory=list)
    # 파일이 없어도 항상 만드는 폴더
    directories: list[Path] = field(default_factory=list)
    # 복사하지 않은 항목, 입력 폴더 기준 상대 경로
    skipped: list[str] = field(default_factory=list)
    # (CUT 폴더, 갈래) — 복사할 파일이 하나도 없는 갈래
    empty: list[tuple[str, str]] = field(default_factory=list)

    def count(self, category: str) -> int:
        marker = self.output_root / category
        return sum(1 for _, dst in self.files if marker in dst.parents)


def _relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def _find_test_file(pipeline_root: Path) -> Path:
    test_manager = pipeline_root / TEST_MANAGER_DIR
    if not test_manager.is_dir():
        raise ClassifyError(f'{TEST_MANAGER_DIR} 폴더가 없습니다: {test_manager}')
    candidates = sorted(
        entry for entry in test_manager.iterdir()
        if entry.is_file() and entry.suffix.lower() == '.mldatx'
    )
    if len(candidates) != 1:
        names = ', '.join(entry.name for entry in candidates) or '(없음)'
        raise ClassifyError(
            f'{TEST_MANAGER_DIR} 안의 .mldatx는 정확히 1개여야 합니다. 찾은 것: {names}')
    return candidates[0]


def _discover_cut_folders(pipeline_root: Path) -> tuple[list[Path], list[Path]]:
    cut_folders: list[Path] = []
    others: list[Path] = []
    for entry in sorted(pipeline_root.iterdir()):
        if entry.is_dir() and CUT_FOLDER_PATTERN.match(entry.name):
            cut_folders.append(entry)
        else:
            others.append(entry)
    return cut_folders, others


def _validate_output(output_root: Path, pipeline_root: Path, overwrite: bool) -> None:
    resolved_output = output_root.resolve()
    resolved_input = pipeline_root.resolve()
    if resolved_output == resolved_input or resolved_input in resolved_output.parents:
        raise ClassifyError(f'출력 폴더가 입력 폴더 안에 있습니다: {output_root}')
    if output_root.is_file():
        raise ClassifyError(f'출력 위치에 파일이 있습니다: {output_root}')
    if output_root.is_dir() and not overwrite:
        raise ClassifyError(
            f'출력 폴더가 이미 있습니다: {output_root}\n'
            '같은 이름의 파일을 덮어쓰려면 --overwrite 를 주세요.')


def build_plan(pipeline_root: Path, output_root: Path | None, overwrite: bool) -> Plan:
    pipeline_root = Path(pipeline_root)
    if not pipeline_root.is_dir():
        raise ClassifyError(f'입력 폴더가 아닙니다: {pipeline_root}')

    test_file = _find_test_file(pipeline_root)
    model_name = test_file.stem
    if output_root is None:
        output_root = pipeline_root.parent / model_name
    output_root = Path(output_root)
    _validate_output(output_root, pipeline_root, overwrite)

    plan = Plan(pipeline_root=pipeline_root, model_name=model_name,
                output_root=output_root)
    for category in CATEGORIES:
        plan.directories.append(output_root / category)
    plan.files.append((test_file, output_root / REPORT_DIR / test_file.name))

    cut_folders, others = _discover_cut_folders(pipeline_root)
    for other in others:
        if other == test_file.parent:
            for child in sorted(other.iterdir()):
                if child != test_file:
                    plan.skipped.append(_relative(child, pipeline_root))
        else:
            plan.skipped.append(_relative(other, pipeline_root))

    for cut in cut_folders:
        plan.cut_folders.append(cut.name)
        counts = {category: 0 for category in CATEGORIES}
        for category in CATEGORIES:
            plan.directories.append(output_root / category / cut.name)
        for entry in sorted(cut.iterdir()):
            if entry.is_dir():
                if entry.name.lower() in EXCLUDED_DIR_NAMES:
                    plan.skipped.append(_relative(entry, pipeline_root))
                    continue
                # 그 외 CUT 폴더 안의 하위 폴더는 cvhtml 보고서의 부속 asset이다.
                # HTML 옆에 있어야 렌더링되므로 보고서 갈래로 트리째 옮긴다.
                plan.trees.append((entry, output_root / REPORT_DIR / cut.name / entry.name))
                continue
            category = CATEGORY_BY_SUFFIX.get(entry.suffix.lower())
            if category is None:
                plan.skipped.append(_relative(entry, pipeline_root))
                continue
            plan.files.append((entry, output_root / category / cut.name / entry.name))
            counts[category] += 1
        for category, count in counts.items():
            if count == 0:
                plan.empty.append((cut.name, category))
    return plan


def execute(plan: Plan, dry_run: bool) -> None:
    if dry_run:
        return
    for directory in plan.directories:
        directory.mkdir(parents=True, exist_ok=True)
    for source, destination in plan.files:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    for source, destination in plan.trees:
        shutil.copytree(source, destination, dirs_exist_ok=True)


def print_summary(plan: Plan, dry_run: bool) -> None:
    lines = [
        f'모델명        : {plan.model_name}',
        f'입력          : {plan.pipeline_root}',
        f'출력          : {plan.output_root}',
        f'CUT 폴더      : {len(plan.cut_folders)}개',
        f'{TEST_CASE_DIR} : {plan.count(TEST_CASE_DIR)}개 파일',
        f'{REPORT_DIR} : {plan.count(REPORT_DIR)}개 파일 (asset 폴더 {len(plan.trees)}개 포함 안 함)',
        f'{PROJECT_DIR}      : {plan.count(PROJECT_DIR)}개 파일',
    ]
    if plan.empty:
        lines.append(f'WARN 비어 있는 갈래 {len(plan.empty)}개:')
        lines.extend(f'  - {cut} / {category}' for cut, category in plan.empty)
    if plan.skipped:
        lines.append(f'건너뛴 항목 {len(plan.skipped)}개:')
        lines.extend(f'  - {item}' for item in plan.skipped)
    if dry_run:
        lines.append('[DRY-RUN] 계획만 보였고 파일은 만들지 않았습니다.')
    else:
        lines.append('복사를 마쳤습니다. 원본은 그대로 있습니다.')
    print('\n'.join(lines))


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='standalone 커버리지 결과 폴더를 팀 제출 트리로 재배치한다 (복사, 원본 유지).')
    parser.add_argument('pipeline_root', type=Path,
                        help='standalone 파이프라인 결과 폴더 (result/standalone_coverage/{PipelineId})')
    parser.add_argument('--out', type=Path, default=None,
                        help='출력 폴더. 기본값은 입력 폴더 옆 {TopModel}/')
    parser.add_argument('--dry-run', action='store_true',
                        help='계획만 출력하고 파일을 만들지 않는다')
    parser.add_argument('--overwrite', action='store_true',
                        help='출력 폴더가 이미 있어도 진행하고 같은 이름의 파일을 덮어쓴다')
    return parser.parse_args(argv)


def _use_utf8_when_piped() -> None:
    # 콘솔은 Python이 유니코드로 직접 쓰지만, 파일이나 파이프로 보낼 때는 Windows
    # 로케일(cp949)이 쓰인다. 그 경우만 UTF-8로 고정해 다른 도구가 읽기 쉽게 한다.
    for stream in (sys.stdout, sys.stderr):
        if not stream.isatty() and hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8')


def main(argv: list[str] | None = None) -> int:
    _use_utf8_when_piped()
    args = _parse_args(argv)
    try:
        plan = build_plan(args.pipeline_root, args.out, args.overwrite)
    except ClassifyError as exc:
        print(f'오류: {exc}', file=sys.stderr)
        return EXIT_INVALID
    try:
        execute(plan, args.dry_run)
    except OSError as exc:
        print(f'복사 실패: {exc}', file=sys.stderr)
        return EXIT_COPY_FAILED
    print_summary(plan, args.dry_run)
    return EXIT_OK


if __name__ == '__main__':
    sys.exit(main())
