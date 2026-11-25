function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 7. Run the standalone pipeline and the final document again
% now that step 1 holds the defect scenarios, then read the defect
% iterations of both runs (st_rebuild_standalone_and_document).
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | standalone and final document rebuild');
st_rebuild_standalone_and_document();
end
