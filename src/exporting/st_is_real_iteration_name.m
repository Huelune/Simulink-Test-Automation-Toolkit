function tf = st_is_real_iteration_name(iterationName)
%ST_IS_REAL_ITERATION_NAME False for the placeholders of an unbound row.
% A specification row bound to no named iteration carries one of these
% placeholders. Such a row is matched at the Test Case level, for its
% verdict and its decision outcomes alike.
iterationName = strtrim(string(iterationName));
tf = strlength(iterationName) > 0 && ...
    ~ismember(iterationName, ["<기본 설정>", "(단일 실행)", "연결 없음"]);
end
