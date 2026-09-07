function owners = st_validate_import_mapping(T, cfg)
%ST_VALIDATE_IMPORT_MAPPING Resolve all selected mappings before any mutation.
owners = strings(height(T), 2);
mask = st_is_harness_import(T);
for i = find(mask).'
    owners(i,1) = string(st_normalize_cut_path(T.SourceCUTPath(i), cfg.TopModel));
    owners(i,2) = string(st_normalize_cut_path(T.CUTPath(i), cfg.TopModel));
    if ~startsWith(owners(i,1), string(cfg.TopModel) + "/") || ...
            ~startsWith(owners(i,2), string(cfg.TopModel) + "/")
        error('simtest:ImportDifferentModel', 'Import must stay inside the selected Top Model.');
    end
    if owners(i,1) == owners(i,2)
        error('simtest:ImportSelfReference', 'Source and destination CUT must differ.');
    end
end
destinations = owners(mask,2);
if numel(unique(destinations)) ~= numel(destinations)
    error('simtest:ImportDuplicateTarget', 'Select each destination CUT only once.');
end
if any(ismember(owners(mask,1), destinations))
    error('simtest:ImportChain', 'A source CUT cannot also be an import destination.');
end
for i = find(mask).'
    if sum(string(T.TestCaseName) == string(T.TestCaseName(i))) ~= 1
        error('simtest:ImportDuplicateTestCase', ...
            'Imported TestCaseName must be unique among selected rows: %s',T.TestCaseName(i));
    end
end
for i = find(~mask).'
    normalOwner = string(st_normalize_cut_path(T.CUTPath(i),cfg.TopModel));
    if any(owners(mask,1) == normalOwner)
        error('simtest:ImportSourceSelected', ...
            'Disable the source Targets row to preserve its prepared content: %s',normalOwner);
    end
end
end
