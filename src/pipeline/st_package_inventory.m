function inventory = st_package_inventory(manifest)
%ST_PACKAGE_INVENTORY Hash the entire delivery, including HTML companions.
inventory = repmat(struct('RelativePath','','SHA256',''),0,1);
folders = [{fileparts(manifest.TestManagerFile)}, {manifest.Targets.OutputDirectory}];
root = [st_absolute_path(manifest.PipelineRoot) filesep];
for k = 1:numel(folders)
    if isempty(folders{k}) || ~isfolder(folders{k}), continue; end
    files = dir(fullfile(folders{k},'**','*'));
    files = files(~[files.isdir]);
    for i = 1:numel(files)
        file = st_absolute_path(fullfile(files(i).folder,files(i).name));
        if ~startsWith(lower(file),lower(root))
            error('simtest:PackageInventoryOutsideRoot','Package file escapes pipeline root: %s',file);
        end
        inventory(end+1,1) = struct('RelativePath',file(numel(root)+1:end), ...
            'SHA256',st_file_signature(file).SHA256); %#ok<AGROW>
    end
end
if ~isempty(inventory)
    [~,order] = sort(string({inventory.RelativePath})); inventory = inventory(order);
end
end
