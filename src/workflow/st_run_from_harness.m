function varargout = st_run_from_harness(varargin)
%ST_RUN_FROM_HARNESS Run the full incremental automation workflow.
%
% st_run_from_harness
% st_run_from_harness('PreparationMode','FORCE','FromStage','SLDV')

[varargout{1:nargout}] = st_run_workflow('FULL', varargin{:});
end
