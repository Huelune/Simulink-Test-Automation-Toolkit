function [environment, checks] = st_verification_environment(profile)
%ST_VERIFICATION_ENVIRONMENT Inspect release, products, licenses, and APIs.

profile = upper(string(profile));
certify = profile == "CERTIFY";

Name = ["MATLAB"; "Simulink"; "Simulink Test"; ...
    "Simulink Coverage"; "Simulink Design Verifier"];
Version = strings(5,1);
Required = [true; true; true; true; certify];
Installed = false(5,1);
Licensed = false(5,1);
Status = strings(5,1);
Detail = strings(5,1);
productQuery = {'MATLAB','Simulink','Simulink Test', ...
    'Simulink Coverage','Simulink Design Verifier'};
licenseFeature = {'MATLAB','SIMULINK','Simulink_Test', ...
    'Simulink_Coverage','Simulink_Design_Verifier'};

for i = 1:numel(Name)
    try
        info = ver(productQuery{i});
        Installed(i) = ~isempty(info);
        if ~isempty(info)
            Version(i) = string(info(1).Version);
        end
    catch
        Installed(i) = false;
    end
    try
        Licensed(i) = logical(license('test', licenseFeature{i}));
    catch
        Licensed(i) = false;
    end
    if Installed(i) && Licensed(i)
        Status(i) = "PASS";
        Detail(i) = "Installed and license exists";
    elseif Required(i)
        Status(i) = "BLOCKED";
        Detail(i) = missing_detail(Installed(i), Licensed(i));
    else
        Status(i) = "WARN";
        Detail(i) = missing_detail(Installed(i), Licensed(i));
    end
end

environment = table(Name, Version, Required, Installed, Licensed, ...
    Status, Detail);
checks = st_empty_verification_checks();
for i = 1:height(environment)
    checks = [checks; st_verification_check( ...
        "ENV." + upper(regexprep(Name(i), '[^A-Za-z0-9]+', '_')), ...
        'CORE', profile, 'ENVIRONMENT', Required(i), Status(i), ...
        Name(i) + ": " + Detail(i))]; %#ok<AGROW>
end

apiNames = ["sltest.harness.create"; ...
    "sltest.testmanager.TestFile"; "decisioninfo"; "executioninfo"; ...
    "dependencies.fileDependencyAnalysis"];
for i = 1:numel(apiNames)
    exists = exist(char(apiNames(i)), 'file') ~= 0 || ...
        exist(char(apiNames(i)), 'class') ~= 0;
    if exists
        status = 'PASS'; message = "API available: " + apiNames(i);
    else
        status = 'BLOCKED'; message = "API missing: " + apiNames(i);
    end
    checks = [checks; st_verification_check( ...
        "ENV.API." + string(i), 'CORE', profile, 'ENVIRONMENT', ...
        true, status, message)]; %#ok<AGROW>
end
end

function text = missing_detail(installed, licensed)
if ~installed && ~licensed
    text = "Product is not installed and no license was found";
elseif ~installed
    text = "Product is not installed";
else
    text = "License was not found";
end
end
