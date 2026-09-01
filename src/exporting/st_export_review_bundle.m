function info = st_export_review_bundle(varargin)
%ST_EXPORT_REVIEW_BUNDLE Compatibility alias for test asset export.

warning('simtest:RenamedExportCommand', ...
    ['st_export_review_bundle was renamed to ' ...
     'st_export_test_asset_bundle.']);
info = st_export_test_asset_bundle(varargin{:});
end
