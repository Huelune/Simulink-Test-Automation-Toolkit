function varargout = st_run_after_harness(varargin)
%ST_RUN_AFTER_HARNESS Run automation for existing Harnesses.
%
% st_run_after_harness
% st_run_after_harness('PreparationMode','FORCE','FromStage','SLDV')
% st_run_after_harness('ExecutionMode','PER_CUT','ReportMode','FULL')

[varargout{1:nargout}] = ...
    st_run_workflow('AFTER_HARNESS', varargin{:});
end
