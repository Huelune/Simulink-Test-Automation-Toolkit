function text = st_log_elapsed_text(secondsValue)
%ST_LOG_ELAPSED_TEXT Short elapsed time for progress lines: 30.9s, 12m38s, 1h02m.
secondsValue = max(0, double(secondsValue));
if secondsValue < 60
    text = sprintf('%.1fs', secondsValue);
elseif secondsValue < 3600
    text = sprintf('%dm%02ds', floor(secondsValue / 60), ...
        floor(mod(secondsValue, 60)));
else
    text = sprintf('%dh%02dm', floor(secondsValue / 3600), ...
        floor(mod(secondsValue, 3600) / 60));
end
end
