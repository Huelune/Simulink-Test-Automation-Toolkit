function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 11. Delete the Harnesses and the Test File and run the
% manual again from Harness creation to the team tree and final document
% (st_rebuild_all). Its unit tests run first and must all pass.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | rebuild all');
st_rebuild_all();
end
