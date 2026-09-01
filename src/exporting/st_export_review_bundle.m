function info = st_export_review_bundle(varargin)
%ST_EXPORT_REVIEW_BUNDLE Quickly archive saved test artifacts for review.
%
%   INFO = ST_EXPORT_REVIEW_BUNDLE() copies the saved top model (including
%   internal Harnesses), Test File, management Excel, and latest integrated
%   report into result/exports/review. It deliberately skips model
%   dependency analysis, Harness input collection, toolbox analysis, and
%   file SHA-256 calculation. The resulting folder is for review/archive;
%   it is not a self-contained rerunnable bundle.
%
%   Name-value options:
%     Destination            Parent folder for the review bundle.
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
    destination = fullfile(cfg.ExportRootDir, 'review');
end

info = st_export_test_bundle( ...
    'Destination', destination, ...
    'RunId', p.Results.RunId, ...
    'CreateArchive', p.Results.CreateArchive, ...
    'IncludeReferenceReport', p.Results.IncludeReferenceReport, ...
    'Profile', 'REVIEW');
end
