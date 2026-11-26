function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 12. Make the final document and team tree again from the
% latest standalone run, with defect rows keeping the whole D list
% (st_redo_final_document). Its unit tests run first and must all pass.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | redo final document');
st_redo_final_document();
end
