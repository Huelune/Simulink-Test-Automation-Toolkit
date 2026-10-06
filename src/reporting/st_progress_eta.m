function text = st_progress_eta(elapsedSeconds, done, total)
%ST_PROGRESS_ETA Elapsed and remaining time of a target loop.
%
%   st_progress_eta(toc(loopTimer), i-1, n)   line printed as target i starts
%   st_progress_eta(toc(loopTimer), i,   n)   line printed after target i ends
%
% The remaining total-done targets are assumed to take the average time of
% the done ones: 'elapsed=40m00s eta=1h49m'. Before any target has finished
% there is no pace yet, so the estimate reads 'eta=--'.
if done < 1
    eta = '--';
else
    eta = st_log_elapsed_text(elapsedSeconds / done * (total - done));
end
text = sprintf('elapsed=%s eta=%s', st_log_elapsed_text(elapsedSeconds), eta);
end
