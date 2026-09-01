function info = st_export_test_asset_bundle(varargin)
%ST_EXPORT_TEST_ASSET_BUNDLE Collect saved test assets and results.
%
%   INFO = ST_EXPORT_TEST_ASSET_BUNDLE() collects the Test Manager file,
%   top model containing internal Harnesses, Harness Signal Editor and SLDV
%   inputs, management Excel, and latest integrated report including
%   coverage into result/exports/assets.
%
%   The command skips whole-model dependency analysis, toolbox analysis,
%   and file SHA-256 calculation. The resulting folder manages the saved
%   test assets and results together, but is not a self-contained rerunnable
%   bundle for another computer.
%
%   Name-value options:
%     Destination            Parent folder for the asset bundle.
%     RunId                  'LATEST' or an existing result/runs folder.
%     CreateArchive          Create a ZIP (default false).
%     IncludeReferenceReport Include the selected report (default true).


p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Destination', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunId', 'LATEST', @(x) ischar(x) || isstring(x));
addParameter(p, 'CreateArchive', false, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'IncludeReferenceReport', true, ...
    @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

cfg = st_require_runtime_target();
destination = strtrim(char(string(p.Results.Destination)));
if isempty(destination)
    destination = fullfile(cfg.ExportRootDir, 'assets');
end

info = st_export_test_bundle( ...
    'Destination', destination, ...
    'RunId', p.Results.RunId, ...
    'CreateArchive', p.Results.CreateArchive, ...
    'IncludeReferenceReport', p.Results.IncludeReferenceReport, ...
    'Profile', 'ASSET');
end
