% Definitions for shared locations across the lab

% TO DO: add method to construct (and search for?) filename
% - model in AP_cortexlab_filename
% maybe also something like AP_find_experiments


classdef locations
    properties( Constant = true )

        %% NAS server location
        server_path = 'Z:\';

        %% Local data paths
        local_data_path = 'C:\LocalData';

        %% Ports for tcp servers and clients
        bonsai_port = 50001
        timelite_port = 50002
        mousecam_port = 50003

        %% Local save
        root_save = 'C:\Users\peterslab\Documents';
        root_workflows = 'C:\Users\peterslab\Documents\GitHub\PetersLab_code\Bonsai stuff';

        %% Github paths
        github_rigging = 'C:\????\PetersLab_rigging';
         
    end

end






