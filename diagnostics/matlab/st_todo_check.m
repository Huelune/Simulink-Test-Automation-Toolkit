function st_todo_check()
%ST_TODO_CHECK Run the check that todo.md asks for now.
%
% todo.md blocks call only this. A block recalled from the command history
% then still runs the check of the code just pulled, not the one the block
% was first written for. Point it at the current section's check whenever
% todo.md changes.
%
% Now: no section needs a MATLAB check.
clc;
fprintf('지금 todo.md에 MATLAB으로 돌릴 점검이 없습니다\n');
end
