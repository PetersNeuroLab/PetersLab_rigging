% Host computers for rigs

classdef config
    properties(Constant = true)


    end

    methods(Static)

        function rig_definitions = rigdef
            % Define all rig configurations 

            % Set info for rigs: 
            % - rig name (character)
            % - computers (cell array) 
            % - client (character: computer that runs experiment controller)
            rig_definitions = struct('name',{},'computers',{},'client',{});

            % Blackrig
            rig_idx = length(rig_definitions)+1;
            rig_definitions(rig_idx).name = 'blackrig';
            rig_definitions(rig_idx).computers = {'WIN-AP003','WIN-AP004','WIN-AP004'};
            rig_definitions(rig_idx).client = 'WIN-AP003';

            % Blackrig
            rig_idx = length(rig_definitions)+1;
            rig_definitions(rig_idx).name = 'bluerig';
            rig_definitions(rig_idx).computers = {'WIN-AP009','WIN-AP010'};
            rig_definitions(rig_idx).client = 'WIN-AP010';

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
            rig_info = rig_definitions(local_rig_index);
        end
        
    end

end
