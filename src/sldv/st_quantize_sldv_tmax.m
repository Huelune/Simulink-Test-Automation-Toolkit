function tmax = st_quantize_sldv_tmax(rawTmax, resolution)
%ST_QUANTIZE_SLDV_TMAX Round an SLDV end time upward to a safe time grid.

rawTmax = double(rawTmax);

if ~isscalar(rawTmax) || ~isfinite(rawTmax) || rawTmax < 0
    error('SLDV Tmax must be one finite nonnegative scalar.');
end

if nargin < 2 || isempty(resolution)
    tmax = rawTmax;
    return;
end

resolution = double(resolution);
if ~isscalar(resolution) || ~isfinite(resolution) || resolution <= 0
    error('SLDV Tmax resolution must be one finite positive scalar or [].');
end

% Do not let a binary representation of an exact grid value (for example
% 1.06) force a needless extra step. A meaningful source tail such as
% 1.060000001 remains well above this floating-point tolerance and rounds
% safely to 1.07 for a 0.01-second grid.
tolerance = 16 * eps(max([1, abs(rawTmax), resolution]));
tmax = max(0, ceil((rawTmax - tolerance) / resolution)) * resolution;
end
