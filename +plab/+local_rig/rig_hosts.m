% Host computers for rigs

classdef rig_hosts
    properties(Constant = true)

        %% Set rig names/computer

        % N rigs x 2 cell array
        % First column is rig name, second column are computers at rig
        % NOTE: first listed computer should be experiment controller
        computers = {...
            {'bluerig'},{'WIN-AP003','WIN-AP004','WIN-AP004'}; ...
            {'blackrig'},{'WIN-AP009','WIN-AP010'}; ...
            };       


    end


    % % Get local host information
    % host_name = java.net.InetAddress.getLocalHost.getHostAddress;
    % host_address = java.net.InetAddress.getLocalHost.getHostName;
    % 
    % % Set experiment control computer by rig

end
