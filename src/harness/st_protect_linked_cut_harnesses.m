function R = st_protect_linked_cut_harnesses(T, cfg)
%ST_PROTECT_LINKED_CUT_HARNESSES Apply safe sync to existing linked CUTs.

n = height(T);
if ~bdIsLoaded(cfg.TopModel)
    st_log(cfg, 'DEBUG', ...
        'Library-link Harness protection model load start | Model=%s', ...
        cfg.TopModel);
    load_system(cfg.ModelFile);
    st_log(cfg, 'DEBUG', ...
        'Library-link Harness protection model load end | Model=%s', ...
        cfg.TopModel);
end
Changed = false(n,1);
Status = repmat("SKIP", n, 1);
Message = strings(n,1);
timerValue = tic;
st_log(cfg, 'INFO', ...
    'Library-link Harness protection start | Targets=%d', n);

for i = 1:n
    cutPath = st_normalize_cut_path(T.CUTPath(i), cfg.TopModel);
    harnessName = char(string(T.HarnessName(i)));
    try
        linkState = st_cut_library_link_state(cutPath);
        if ~linkState.IsLinked
            Message(i) = "CUT is not library-linked";
            continue;
        end
        existing = sltest.harness.find( ...
            cutPath, 'SearchDepth', 0, 'Name', harnessName);
        if isempty(existing)
            Message(i) = "Harness does not exist yet";
            continue;
        end
        Changed(i) = st_protect_linked_cut_harness( ...
            cutPath, harnessName, cfg);
        Status(i) = "OK";
        if Changed(i)
            Message(i) = "SynchronizationMode changed to SyncOnOpen";
        else
            Message(i) = "SynchronizationMode already SyncOnOpen";
        end
    catch ME
        Status(i) = "FAIL";
        Message(i) = string(ME.message);
        st_log(cfg, 'ERROR', ...
            ['Library-link Harness protection failed | CUT=%s | ' ...
             'Harness=%s | %s: %s'], ...
            cutPath, harnessName, ME.identifier, ME.message);
    end
end

if any(Changed) && ~any(Status == "FAIL")
    st_log(cfg, 'DEBUG', ...
        'Library-link Harness protection save start | Model=%s', ...
        cfg.TopModel);
    save_system(cfg.TopModel);
    st_log(cfg, 'DEBUG', ...
        'Library-link Harness protection save end | Model=%s', ...
        cfg.TopModel);
elseif any(Changed)
    st_log(cfg, 'WARN', ...
        ['Library-link Harness protection made safe in-memory changes but ' ...
         'did not save because another target failed | Model=%s'], ...
        cfg.TopModel);
end

R = table(double(T.No), string(T.CUTName), string(T.CUTPath), ...
    string(T.HarnessName), Changed, Status, Message, ...
    'VariableNames', {'No','CUTName','CUTPath','HarnessName', ...
    'Changed','Status','Message'});
st_write_result('LibraryLinkHarnessProtectionResult', R);
st_log(cfg, 'INFO', ...
    ['Library-link Harness protection end | Changed=%d | Fail=%d | ' ...
     'Elapsed=%.3f sec'], ...
    sum(Changed), sum(Status == "FAIL"), toc(timerValue));
end
