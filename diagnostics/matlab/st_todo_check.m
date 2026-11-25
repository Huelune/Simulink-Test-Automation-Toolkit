function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 6. Find out why the defect iterations' Custom Criteria
% result cannot be read from the saved results
% (st_probe_defect_criteria_results). Runs nothing and deletes nothing.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | defect criteria result probe');
st_probe_defect_criteria_results();
end
