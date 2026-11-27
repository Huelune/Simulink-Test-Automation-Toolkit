function [merged, added] = st_merge_include_dirs(existing, extraDirs)
%ST_MERGE_INCLUDE_DIRS Add folders to a SimUserIncludeDirs value without losing what is there.
%
% [merged, added] = st_merge_include_dirs(existing, extraDirs)
%
% existing is the model's SimUserIncludeDirs text: folders separated by new
% lines, commas, spaces or semicolons, a folder with spaces in double
% quotes. extraDirs are absolute folders. Each extra folder not already in
% the list (case and trailing separators ignored) goes at the end, quoted,
% on its own line. added counts them; merged equals existing when it is 0.
existing = char(string(existing));
present = regexp(existing, '"[^"]+"|[^\s;,]+', 'match');
present = lower(regexprep(strrep(present, '"', ''), '[\\/]+$', ''));
merged = existing;
added = 0;
for k = 1:numel(extraDirs)
    folder = regexprep(char(string(extraDirs{k})), '[\\/]+$', '');
    if isempty(folder) || any(strcmp(present, lower(folder))), continue; end
    if isempty(strtrim(merged))
        merged = ['"' folder '"'];
    else
        merged = [merged newline '"' folder '"']; %#ok<AGROW>
    end
    present{end+1} = lower(folder); %#ok<AGROW>
    added = added + 1;
end
end
