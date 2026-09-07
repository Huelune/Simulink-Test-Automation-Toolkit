function st_restore_import_backup(files,backup,existed,cfg)
%ST_RESTORE_IMPORT_BACKUP Restore exactly the files enlisted before mutation.
st_log(cfg,'DEBUG','Import file restore start | count=%d',numel(files));
for k = 1:numel(files)
    if existed(k)
        [ok,message] = copyfile(backup{k},files{k},'f');
        if ~ok, error('simtest:ImportRestoreFailed','%s',message); end
        original = st_file_signature(backup{k}); restored = st_file_signature(files{k});
        if ~original.Exists || ~restored.Exists || ~strcmp(original.SHA256,restored.SHA256)
            error('simtest:ImportRestoreMismatch','Restore checksum differs: %s',files{k});
        end
    elseif isfile(files{k})
        delete(files{k}); % Exact newly-created manifest, never a directory.
    end
end
st_log(cfg,'DEBUG','Import file restore end | count=%d',numel(files));
end
