function [root, cleanup] = st_isolated_toolkit()
%ST_ISOLATED_TOOLKIT Disposable checkout; never touches the user's settings.
source = st_project_root();
root = tempname; mkdir(root);
for item = {'src','resources','st_setup.m','VERSION.txt'}
    copyfile(fullfile(source,item{1}),fullfile(root,item{1}));
end
oldFolder = pwd; oldPath = path;
cleanup = onCleanup(@() restore(root,oldFolder,oldPath));
cd(root); addpath(root,'-begin'); addpath(genpath(fullfile(root,'src')),'-begin');
clear st_setup st_config st_project_root;
st_setup;
end

function restore(root,oldFolder,oldPath)
cd(oldFolder); path(oldPath);
clear st_setup st_config st_project_root;
if isfolder(root) && startsWith(st_absolute_path(root),[st_absolute_path(tempdir) filesep])
    rmdir(root,'s');
end
end
