function bonsai_server

%% Initialize bonsai server

% Create figure on iPad screens
monitors_pos = get(0, 'MonitorPosition');
ipad_screens = monitors_pos(1,:);
% set(0,'DefaultFigurePosition', ipad_screens);
bonsai_server_fig = ...
    uifigure('Position',ipad_screens,'color',[0.5,0.5,0.5], ...
    'toolbar','none','menubar','none','CloseRequestFcn',@close_bonsai_server);

% Set up structure for listeners and receivers
communication_handles = struct;

% Open TCP client for MC
communication_handles.client_mc = tcpclient("163.1.249.17",plab.locations.bonsai_port);
configureCallback(communication_handles.client_mc, "terminator", @(src, event, x) readData (src, event, bonsai_server_fig));

% Open UDP connection for Bonsai
communication_handles.u_bonsai = udpport("IPV4");

% Setup listening to Bonsai workflow
% (load the jar file)
java_path = fullfile(fileparts(which('plab.bonsai_server')),'+bonsai_server_helpers');
javaaddpath(fullfile(java_path,'javaosctomatlab.jar'));

% (import java packages)
import com.illposed.osc.*;
import java.lang.String;

% (set up OSC listener and receiver)
oscport= 20000;
communication_handles.oscreceiver = OSCPortIn(oscport);
communication_handles.osclistener = MatlabOSCListener();
communication_handles.oscreceiver.addListener(String('/stop'),communication_handles.osclistener);
communication_handles.oscreceiver.startListening();

% Upload receiver/listener to figure
guidata(bonsai_server_fig,communication_handles);

end

function readData(client, ~, bonsai_server_fig)
    disp('Data received')
    client.UserData = readline(client);
    if strcmp(client.UserData, 'stop')
        % send stop to bonsai
        communication_handles = guidata(bonsai_server_fig);
        plab.bonsai_server_helpers.bonsai_oscsend(communication_handles.u_bonsai,'/stop',"localhost",30000,'s','stop');
    else
        run_bonsai(bonsai_server_fig);
    end
end


function run_bonsai(bonsai_server_fig)

    communication_handles = guidata(bonsai_server_fig);

    % decode json
    data_struct = jsondecode(communication_handles.client_mc.UserData);
    
    % Set local filename for bonsai workflow
    local_worfkflow_file = ...
        plab.locations.make_local_filename( ...
        data_struct.mouse,data_struct.date,data_struct.time,data_struct.protocol_name);
    [save_filepath,~,~] = fileparts(local_worfkflow_file);

    % Make local save directory
    mkdir(fileparts(local_worfkflow_file));

    % get paths for files
    workflowpath = fullfile(plab.locations.local_workflow_path, data_struct.protocol_path, data_struct.protocol_name);
    save_filename = fullfile(save_filepath, 'test.csv');

    % copy bonsai workflow in new folder
    copyfile(workflowpath, local_worfkflow_file);

    % start bonsai
    plab.bonsai_server_helpers.runBonsaiWorkflow(local_worfkflow_file, {'FileName', save_filename}, [], 1);
    
    bonsai_timer_fcn = timer('TimerFcn', ...
    {@get_bonsai_message,communication_handles}, ...
    'Period', 1/10, 'ExecutionMode','fixedDelay', ...
    'TasksToExecute', inf);
    start(bonsai_timer_fcn)

end

function get_bonsai_message(obj, ~, communication_handles)
    getlastmessage = communication_handles.osclistener.getMessageArgumentsAsString();    
    if ~isempty(getlastmessage)
        disp('Read something')
        % close Bonsai
        system('taskkill /F /IM Bonsai.EXE');
        system('taskkill /F /IM OpenConsole.EXE');
        % send done to exp control
        writeline(communication_handles.client_mc, 'done');
        % delete timer
        stop(obj)
        delete(obj)
    end
end

function close_bonsai_server(obj, ~)

% Confirm close
confirm_close = uiconfirm(obj,'Close Bonsai server?','Confirm close');
if strcmp(confirm_close,'OK')

    % Get OSC handler and stop listeners
    communication_handles = guidata(obj);
    communication_handles.oscreceiver.stopListening();
    communication_handles.oscreceiver.close();

    % Delete the figure
    delete(obj);

    % Clear TCP client
    delete(communication_handles.client_mc)
    
    % Exit matlab (stops the waitfor and resets ports)
    exit
end

end



