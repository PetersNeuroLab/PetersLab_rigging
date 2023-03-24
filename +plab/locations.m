% Definitions for shared locations across the lab

% TO DO:
% Add method to search for filename? like AP_cortexlab filename
% maybe also something like AP_find_experiments

classdef locations
    properties(Constant = true)

        %% Set common lab locations

        % NAS server location
        server_data_path = 'P:\Data';

        % Ports for tcp servers and clients
        bonsai_port = 50001
        timelite_port = 50002
        mousecam_port = 50003

        % Local bonsai workflow folder
        local_workflow_path = 'C:\Users\peterslab\Documents\GitHub\PetersLab_code\Bonsai stuff';

        % Github paths
        github_rigging = 'C:\Users\peterslab\Documents\GitHub\PetersLab_rigging';

    end

    methods(Static)

        %% Methods to get local data path 
        function x = local_data_path
            
            if exist('D:\','dir')
                % Use D: if available
                local_data_drive = 'D:';
            else
                % Otherwise, use C:
                local_data_drive = 'C:';
            end

            % Set local data path
            x = fullfile(local_data_drive,'Local_data');
  
        end


        %% Methods to construct filenames
        % Filename structure:
        % storage\animal\<YYYY-MM-DD>\<Protocol_HHMM>\filename
        % e.g. P:\AP001\2023-03-21\Protocol_1301\timelite.mat

        function local_filename = make_local_filename(animal,rec_day,rec_time,filename)
            % Generate local filename
            % local_filename = make_local_filename(animal,rec_day,rec_time,filename)
            local_filename = fullfile(plab.locations.local_data_path, ...
                animal,rec_day,sprintf('Protocol_%s',rec_time),filename);
        end
        function server_filename = make_server_filename(animal,rec_day,rec_time,filename)
            % Generate server filename
            % server_filename = make_server_filename(animal,rec_day,rec_time,filename)
            server_filename = fullfile(plab.locations.server_data_path, ...
                animal,rec_day,sprintf('Protocol_%s',rec_time),filename);
        end


    end

end






