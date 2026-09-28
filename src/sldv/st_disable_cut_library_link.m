function info = st_disable_cut_library_link(cfg, cutPath)
%ST_DISABLE_CUT_LIBRARY_LINK Disable the library link that owns a CUT.
%
% The source library file is never opened or saved here. Only the
% model-side instance link is set to LinkStatus=inactive.
%
% The CUT is often not the linked block itself but a block inside a linked
% ancestor (StaticLinkStatus=implicit). Only the ancestor that owns the
% link can be disabled, so this walks up to it first. Blocks inside the
% disabled link stay implicit, so the Harness link protection still treats
% the CUT as linked and keeps SyncOnOpen.
%
% Simulink refuses to disable a link while any block inside it has a test
% harness. That is why the workflow calls this before creating Harnesses.
% On an already-prepared model the Harnesses inside the link owner must be
% deleted once by hand; see docs/troubleshooting.md.

cutPath = char(string(cutPath));
before = st_cut_library_link_state(cutPath);

linkOwner = find_library_link_owner(cutPath);
ownerBefore = char(string(get_param(linkOwner, 'StaticLinkStatus')));
ownerReference = char(string(get_param(linkOwner, 'ReferenceBlock')));

info = struct( ...
    'CUTPath', cutPath, ...
    'CUTStatusBefore', before.StaticLinkStatus, ...
    'CUTStatusAfter', before.StaticLinkStatus, ...
    'LinkOwner', linkOwner, ...
    'OwnerStatusBefore', ownerBefore, ...
    'OwnerStatusAfter', ownerBefore, ...
    'Reference', ownerReference, ...
    'Changed', false);

if strcmpi(ownerBefore, 'inactive')
    st_log(cfg, 'DEBUG', ...
        '[SLDV] Library link already inactive | CUT=%s | Link owner=%s', ...
        cutPath, linkOwner);
    return;
end

st_log(cfg, 'WARN', ...
    ['[SLDV] Disabling the library link of a non-atomic CUT because ' ...
     'cfg.DisableLibraryLinkForSldvTargets=true. The whole linked ' ...
     'instance will no longer follow library updates and restoring the ' ...
     'link reverts the atomic conversion | CUT=%s | CUT status=%s | ' ...
     'Link owner=%s | Owner status=%s | Reference=%s'], ...
    cutPath, before.StaticLinkStatus, linkOwner, ownerBefore, ...
    ownerReference);

try
    set_param(linkOwner, 'LinkStatus', 'inactive');
catch ME
    if contains(lower(ME.message), 'harness')
        error('simtest:SldvLibraryLinkDisableBlockedByHarness', ...
            ['Simulink refused to disable the library link because ' ...
             'blocks inside it already have test harnesses. Delete the ' ...
             'Harnesses inside the link owner once (they are recreated ' ...
             'by the HARNESS stage) and run again with ' ...
             'PreparationMode=FORCE. CUT=%s | Link owner=%s | ' ...
             'Harnesses inside=[%s] | Simulink: %s'], ...
            cutPath, linkOwner, harness_names_inside(linkOwner), ...
            ME.message);
    end
    rethrow(ME);
end

ownerAfter = char(string(get_param(linkOwner, 'StaticLinkStatus')));
if ~strcmpi(ownerAfter, 'inactive')
    error('simtest:SldvLibraryLinkDisableFailed', ...
        ['Disabling the library link did not take effect. Do not save ' ...
         'the model; close it without saving and reopen the saved ' ...
         'source. CUT=%s | Link owner=%s | Owner status=%s->%s | ' ...
         'Reference=%s'], ...
        cutPath, linkOwner, ownerBefore, ownerAfter, ownerReference);
end

after = st_cut_library_link_state(cutPath);
info.CUTStatusAfter = after.StaticLinkStatus;
info.OwnerStatusAfter = ownerAfter;
info.Changed = true;

st_log(cfg, 'INFO', ...
    ['[SLDV] Library link disabled | CUT=%s | CUT status=%s->%s | ' ...
     'Link owner=%s | Owner status=%s->%s'], ...
    cutPath, before.StaticLinkStatus, after.StaticLinkStatus, ...
    linkOwner, ownerBefore, ownerAfter);

end


function linkOwner = find_library_link_owner(blockPath)
% Return the nearest ancestor (or the block itself) that owns a library
% link. A block inside a link reports StaticLinkStatus=implicit and cannot
% be disabled on its own.

linkOwner = char(string(blockPath));
modelName = bdroot(linkOwner);

while strcmpi(char(string(get_param(linkOwner, 'StaticLinkStatus'))), ...
        'implicit')
    parent = char(string(get_param(linkOwner, 'Parent')));
    if isempty(parent) || strcmp(parent, modelName)
        error('simtest:SldvLibraryLinkOwnerNotFound', ...
            ['The CUT reports an implicit library link but no linked ' ...
             'ancestor was found: %s'], blockPath);
    end
    linkOwner = parent;
end

end


function text = harness_names_inside(linkOwner)
% Best-effort list of Harnesses owned by blocks inside the link owner.

text = '';
try
    subsystems = find_system(linkOwner, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', 'SubSystem');
    names = {};
    for k = 1:numel(subsystems)
        items = sltest.harness.find(subsystems{k}, 'SearchDepth', 0);
        for j = 1:numel(items)
            names{end+1} = sprintf('%s:%s', ...
                items(j).ownerFullPath, items(j).name); %#ok<AGROW>
        end
    end
    text = strjoin(names, ', ');
catch
    text = 'unknown';
end

end
