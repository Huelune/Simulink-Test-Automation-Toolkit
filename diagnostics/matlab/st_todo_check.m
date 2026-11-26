function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 9. Open the latest standalone submission's results to look
% at (st_show_standalone_results): Test Manager cleared and the saved Result
% imported, CVF-applied coverage reports and model highlighting.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | show standalone results');
st_show_standalone_results();
end
