function kind = st_model_file_kind(file, cfg)
%ST_MODEL_FILE_KIND Say where a model file lives without naming it.
%
% kind = st_model_file_kind(file, cfg)
%
% For screens that leave the company: returns "없음", "모델 파일",
% "standalone 폴더", "결과 폴더", "모델 폴더" or "기타", never a path.
% The standalone folder sits inside the result folder, and the result folder
% can sit inside the model folder, so the narrower folder is tested first.
file = lower(string(file));
if strlength(file) == 0
    kind = "없음";
elseif file == lower(string(cfg.ModelFile))
    kind = "모델 파일";
elseif under(file, cfg.StandaloneCoverageRootDir)
    kind = "standalone 폴더";
elseif under(file, cfg.ResultDir)
    kind = "결과 폴더";
elseif under(file, fileparts(char(cfg.ModelFile)))
    kind = "모델 폴더";
else
    kind = "기타";
end
end


function tf = under(file, folder)
folder = lower(string(folder));
tf = strlength(folder) > 0 && startsWith(file, folder);
end
