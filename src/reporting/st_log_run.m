function varargout = st_log_run(commandName, fn, logDir)
%ST_LOG_RUN Run a command body inside its log scope.
%
% [varargout{1:nargout}] = st_log_run(mfilename, @() body(varargin{:}))
%
% The outermost call owns the run log. A failure is recorded before it is
% rethrown, so the log ends with the command's FAILED line. Only a normal
% return marks the run complete; Ctrl+C skips the catch below, and the log
% then ends with INTERRUPTED instead of done.
if nargin < 3, logDir = ''; end
guard = st_log_scope('enter', commandName, logDir); %#ok<NASGU>
try
    [varargout{1:nargout}] = fn();
catch ME
    st_log_scope('fail', ME);
    rethrow(ME);
end
st_log_scope('complete');
end
