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

        %% Github paths
        github_rigging = 'C:\Github\PetersLab_rigging';
         
    end

end






