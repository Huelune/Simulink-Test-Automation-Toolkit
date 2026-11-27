function text = st_short_outcome_text(text)
%ST_SHORT_OUTCOME_TEXT Shorten a coverage outcome text for a D line's bracket.
% SLDV prefixes its objective text with the decision name, which says
% nothing on a D line: "Logic to determine output input 2 is the maximum".
% That prefix is dropped. A MinMax outcome names the input the block passed
% on: coverage says "input 2", SLDV "input 2 is the maximum"; both become
% "u2" (u1, u2 are the block's inputs; the D line already says min or max).
% Any other text is kept, spacing collapsed.
text = strtrim(regexprep(string(text), '\s+', ' '));
text = regexprep(text, '^logic to determine output\s*:?\s*', '', 'ignorecase');
text = regexprep(text, '^input (\d+)( is the (max|min)imum)?$', 'u$1', 'ignorecase');
end
