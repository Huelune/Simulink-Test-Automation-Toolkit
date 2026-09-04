function specification = st_specification_table(rows, verifyCells, maxTimes)
%ST_SPECIFICATION_TABLE Insert step columns before the fixed metadata columns.
if numel(verifyCells) ~= size(rows,1)
    error('simtest:SpecificationRowMismatch', 'Verify groups must match specification rows.');
end
if nargin < 3, maxTimes = NaN(size(rows,1),1); end
if ~isnumeric(maxTimes) || numel(maxTimes) ~= size(rows,1)
    error('simtest:SpecificationRowMismatch', 'MaxTime values must match specification rows.');
end
count = max([1; cellfun(@numel, verifyCells(:))]);
values = strings(size(rows,1), count);
for k = 1:size(rows,1)
    group = string(verifyCells{k});
    values(k,1:numel(group)) = reshape(group, 1, []);
end
verifyHeaders = {'verify 내용'};
for k = 2:count, verifyHeaders{k} = sprintf('verify 내용 %d', k); end %#ok<AGROW>
headers = [{'테스트 케이스명','대상 모델명','하네스명','하네스 input 파일명', ...
    'Test Sequence scenario 명','input 시나리오 내용'}, verifyHeaders, ...
    {'TopModel','CUTPath','Iteration명','InputScenario명','추출상태','비고'}];
specification = array2table([rows(:,1:6) values rows(:,8:13)], 'VariableNames', headers);
specification = addvars(specification, maxTimes(:), ...
    'Before', '추출상태', 'NewVariableNames', 'MaxTime');
end
