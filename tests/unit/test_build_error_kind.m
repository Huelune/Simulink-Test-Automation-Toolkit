function tests = test_build_error_kind
%TEST_BUILD_ERROR_KIND A build failure reaches the screen as identifiers and a kind only.
tests = functiontests(localfunctions);
end

function testIncludeFileMissingWithCauses(testCase)
ME = failure('Simulink:cgxe:BuildError', 'Build failed for Secret_Harness', { ...
    failure('SecretTeam:Code:Failed', ...
    'D:\Secret\src\secret.c(12): fatal error C1083: Cannot open include file: ''secret.h''', {})});
text = st_build_error_kind(ME);
verifyEqual(testCase, text, '식별자 Simulink:cgxe:BuildError, (다른 식별자) | 종류 include 파일 없음');
verifyFalse(testCase, contains(text, 'Secret'));
end

function testLinkAndPathKinds(testCase)
link = failure('Simulink:cgxe:BuildError', 'secret.obj : error LNK2019: unresolved external symbol Secret_fn', {});
verifyEqual(testCase, st_build_error_kind(link), '식별자 Simulink:cgxe:BuildError | 종류 링크 실패(정의 없는 함수)');
longPath = failure('Simulink:cgxe:BuildError', 'The filename or extension is too long. D:\Secret', {});
verifyEqual(testCase, st_build_error_kind(longPath), '식별자 Simulink:cgxe:BuildError | 종류 경로 길이 초과');
end

function testUnknownTextIsOther(testCase)
other = failure('Simulink:cgxe:BuildError', 'Secret something went wrong', {});
verifyEqual(testCase, st_build_error_kind(other), '식별자 Simulink:cgxe:BuildError | 종류 기타');
end

function ME = failure(identifier, message, causes)
ME = struct('identifier', identifier, 'message', message);
ME.cause = causes;
end
