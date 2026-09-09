function st_validate_clone_mapping(T, cfg)
%ST_VALIDATE_CLONE_MAPPING Reject batches that mutate their own templates.
mask = st_is_harness_clone(T);
destinations = strings(height(T),1);
for i = 1:height(T)
    destinations(i) = string(st_normalize_cut_path(T.CUTPath(i),cfg.TopModel));
end
for i = find(mask).'
    source = string(T.SourceCUTPath(i));
    source = replace(source, char(92), '/');
    source = regexprep(source,'^/+','');
    if strlength(source) > 0
        source = string(st_normalize_cut_path(source,strtok(char(source),'/')));
    end
    if any(destinations == source & T.HarnessName == T.SourceHarnessName(i))
        error('simtest:CloneTemplateIsTarget', ...
            'Template must not be an active batch destination: %s / %s', ...
            source,T.SourceHarnessName(i));
    end
end
end
