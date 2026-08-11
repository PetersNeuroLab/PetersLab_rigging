% Define computer setups for rigs for TCP hosting

classdef config
    properties(Constant = true)
    end

    methods(Static)

        function rig_definitions = rigdef
            % Define all rig configurations 

            % Set info for rigs: 
            % - rig name (character)
            % - computers (cell array) 
            % - server (character: computer that runs experiment controller)
            rig_definitions = struct('name',{},'computers',{},'server',{});

            % Blackrig
            rig_idx = length(rig_definitions)+1;
            rig_definitions(rig_idx).name = 'blackrig';
            rig_definitions(rig_idx).computers = {'WIN-AP003','WIN-AP004','WIN-AP006'};
            rig_definitions(rig_idx).server = 'WIN-AP003';

            % Bluerig
            rig_idx = length(rig_definitions)+1;
            rig_definitions(rig_idx).name = 'bluerig';
            rig_definitions(rig_idx).computers = {'WIN-AP009','WIN-AP010'};
            rig_definitions(rig_idx).server = 'WIN-AP010';

        end

        function rig_info = local
            % Local rig info

            % Get local host information
            local_address = char(java.net.InetAddress.getLocalHost.getHostAddress);
            local_name = char(java.net.InetAddress.getLocalHost.getHostName);

            % Get local rig
            rig_definitions = plab.local_rig.config.rigdef;
            local_rig_index = cellfun(@(x) any(contains(x,local_name)),{rig_definitions.computers});

            % Return local rig info
            if any(local_rig_index)
                rig_info = rig_definitions(local_rig_index);
            else
                % (if no rig config found, just use local computer)
                rig_info = struct( ...
                    'name','local', ...
                    'computers',{{local_name}}, ...
                    'server',local_name);
            end

            % If local rig is also client, tcpclient needs IP address
            if strcmp(local_name,rig_info.server)
                rig_info.server = local_address;
            end
            
        end       
    end
end
