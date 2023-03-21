% Definitions for shared locations across the lab

% TO DO:
% Add method to search for filename? like AP_cortexlab filename
% maybe also something like AP_find_experiments

classdef locations
    properties( Constant = true )

        %% Set common lab locations

        % NAS server location
        server_data_path = 'P:\Data';

        % Local data paths
        local_data_path = 'C:\LocalData';

        % Ports for tcp servers and clients
        bonsai_port = 50001
        timelite_port = 50002
        mousecam_port = 50003

        % Local bonsai workflow folder
        local_workflow_path = 'C:\Users\peterslab\Documents\GitHub\PetersLab_code\Bonsai stuff';

        % Github paths
        github_rigging = 'C:\????\PetersLab_rigging';
         
    end

    methods(Static)

        %% Methods to construct filenames
        % Filename structure: 
        % storage\animal\<YYYY-MM-DD>\<recording_HHMM>\filename
        % e.g. P:\AP001\2023-03-21\recording_1301\timelite.mat

        function local_filename = make_local_filename(animal,rec_day,rec_time,filename)
            % Generate local filename
            local_filename = fullfile(plab.locations.local_data_path, ...
                animal,rec_day,sprintf('recording_%s',rec_time),filename);
        end
        function server_filename = make_server_filename(animal,rec_day,rec_time,filename)
            % Generate server filename
            server_filename = fullfile(plab.locations.server_data_path, ...
                animal,rec_day,sprintf('recording_%s',rec_time),filename);
        end

        function [protocol_dir, day_dir, mouse_dir] = make_file_structure(root, animal, date, time)
            % make mouse dir
            mouse_dir = fullfile(root,animal);
            mkdir(mouse_dir);

            % make day dir
            day_dir = fullfile(mouse_dir,date);
            mkdir(day_dir);

            % make exp dir
            protocol_dir = fullfile(day_dir, ['protocol_' time]);
            mkdir(protocol_dir);
        end


    end

end






