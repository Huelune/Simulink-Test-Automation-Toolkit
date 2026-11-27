function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 17. Run the second model's clone through the manual for the
% first time, Excel check to team tree, keeping its Harnesses
% (st_run_model_first).
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | first run of this clone''s model');
st_run_model_first();
end
