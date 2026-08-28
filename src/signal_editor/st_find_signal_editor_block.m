function blockPath = st_find_signal_editor_block(harnessName)
%ST_FIND_SIGNAL_EDITOR_BLOCK Find the top-level Signal Editor block.

harnessName = char(harnessName);
blocks = find_system(harnessName, 'SearchDepth', 1, 'Type', 'Block');
found = {};

for i = 1:numel(blocks)
    b = blocks{i};
    try
        get_param(b, 'Filename');
        get_param(b, 'ActiveScenario');
        get_param(b, 'SampleTime');
        get_param(b, 'options@ActiveScenario');
        found{end+1,1} = b; %#ok<AGROW>
    catch
    end
end

if numel(found) ~= 1
    error('Could not identify exactly one Signal Editor block. Found=%d, Harness=%s', ...
        numel(found), harnessName);
end

blockPath = found{1};
end
