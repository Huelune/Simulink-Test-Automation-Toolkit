function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: section 8. Why adding the packaged CVFs to the standalone Result in
% Test Manager changed no value (st_probe_standalone_cvf_effect). Changes
% nothing on disk and leaves Test Manager as it is.
cfg = st_config();
st_log(cfg, 'INFO', 'todo check start | standalone CVF effect probe');
st_probe_standalone_cvf_effect();
end
