function value = st_target_scope(action, rows)
%ST_TARGET_SCOPE Temporary, nestable target selection; never edits Excel.
% The caller must retain the returned onCleanup guard for its entire scope.
persistent selected
switch action
    case 'enter'
        previous = selected;
        selected = rows;
        value = onCleanup(@() st_target_scope('restore', previous));
    case 'restore'
        selected = rows;
        value = [];
    case 'active'
        value = istable(selected);
    case 'filter'
        value = rows;
        if istable(selected)
            keep = false(height(rows),1);
            for i = 1:height(selected)
                keep = keep | (rows.No == selected.No(i) & ...
                    rows.CUTPath == selected.CUTPath(i) & ...
                    rows.HarnessName == selected.HarnessName(i) & ...
                    rows.TestCaseName == selected.TestCaseName(i));
            end
            value = rows(keep,:);
        end
    otherwise
        error('simtest:InvalidTargetScope','Unknown target scope action: %s',action);
end
end
