function defects = st_final_document_defects(cfg)
%ST_FINAL_DOCUMENT_DEFECTS One row per defect iteration of every target.
% profile.DefectIterations is the only place the defect list lives, so the
% final document reads it through st_get_sldv_profile instead of working it
% out again. OutcomeTexts joins the outcome texts of one block with "|";
% Approximate is true when any of them was found only under approximation.
%
% The document must still come out when one target cannot be read, so that
% target is skipped with a WARN and its defect rows stay ordinary rows.
defects = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    strings(0,1), false(0,1), 'VariableNames', {'TestCaseName','Name', ...
    'BlockType','RelativePath','OutcomeTexts','Approximate'});
st_log(cfg, 'INFO', 'Final document defects start');
try
    targets = st_load_targets(config_value(cfg, 'OnlyEnabled', true));
catch ME
    st_log(cfg, 'WARN', ...
        'Final document defects skipped | Targets unreadable | Kind=%s', error_kind(ME));
    return;
end
skipped = 0;
for i = 1:height(targets)
    try
        profile = st_get_sldv_profile(targets(i,:), cfg);
        defects = [defects; profile_rows(targets.TestCaseName(i), profile)]; %#ok<AGROW>
    catch ME
        skipped = skipped + 1;
        st_log(cfg, 'WARN', ['Final document defects skipped a target | No=%g | ' ...
            'Kind=%s | Its defect rows stay ordinary rows'], targets.No(i), error_kind(ME));
        st_log(cfg, 'DEBUG', 'Final document defects target error | No=%g | %s', ...
            targets.No(i), ME.message);
    end
end
st_log(cfg, 'INFO', ...
    'Final document defects end | Targets=%d | Skipped=%d | Defects=%d', ...
    height(targets), skipped, height(defects));
end


function rows = profile_rows(testCaseName, profile)
items = [];
if isfield(profile, 'DefectIterations'), items = profile.DefectIterations(:); end
count = numel(items);
names = strings(count, 1);
types = strings(count, 1);
paths = strings(count, 1);
texts = strings(count, 1);
approximate = false(count, 1);
for k = 1:count
    outcomes = items(k).Outcomes;
    names(k) = string(items(k).Name);
    types(k) = string(items(k).BlockType);
    paths(k) = string(items(k).RelativePath);
    texts(k) = strjoin(string({outcomes.Text}), "|");
    approximate(k) = any([outcomes.Approximate]);
end
rows = table(repmat(string(testCaseName), count, 1), names, types, paths, ...
    texts, approximate, 'VariableNames', {'TestCaseName','Name', ...
    'BlockType','RelativePath','OutcomeTexts','Approximate'});
end


function kind = error_kind(ME)
kind = ME.identifier;
if isempty(kind), kind = 'unidentified'; end
end


function value = config_value(cfg, name, fallback)
value = fallback;
if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
    value = cfg.(name);
end
end
