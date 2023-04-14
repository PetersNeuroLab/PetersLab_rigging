function timelite
% Light-weight NI-DAQ acquisition GUI (lite version of Timeline)
%
% FOR RIG-SPECIFIC DAQ SETUP: 
% Make local custom version of <plab.timelite_config>
%
% Requires: 
% data acquisition toolbox
% instrument control toolbox

%% Make GUI

% Create figure at left edge of the screen
gui_fig = figure('Name','Timelite','Units','Normalized', ...
    'Position',[0,0.05,0.15,0.9],'color','w','menu','none');

% Initialize text
uicontrol('Parent',gui_fig,'Style','text', ...
    'String','TIMELITE','FontSize',20, ...
    'HorizontalAlignment','center', ...
    'Units','normalized','BackgroundColor',[0.8,0.8,0.8],'Position',[0,0.95,1,0.05]);

text_h = uicontrol('Parent',gui_fig,'Style','text', ...
    'FontSize',12,'FontName','Courier','HorizontalAlignment','left', ...
    'Units','normalized','BackgroundColor','w','Position',[0,0.1,1,0.85]);

% Initialize buttons
user_button_h = uicontrol('Parent',gui_fig,'Style','pushbutton', ...
    'String','PREVIEW','Callback',{@user_buttonpress,gui_fig}, ...
    'FontSize',16,'BackgroundColor',[0,0.8,0],'ForegroundColor','w', ...
    'Units','normalized','Position',[0,0,1,0.1],'Enable','off');

% Draw initial controls (so user knows startup is in progress)
drawnow;

% Set up DAQ
update_status_text(text_h,'Setting up DAQ...');
try
    % Set up DAQ according to local config file
    daqreset;
    daq_device = plab.local_rig.timelite_config;
    daq_device.analog.ScansAvailableFcn = @(src,evt,x) daq_upload(src,evt,gui_fig);
catch me
    % Error if DAQ could not be configured
    error('Timelite -- DAQ device could not be configured: \n %s',me.message)
end

% Start listener for experiment controller
update_status_text(text_h,'Connecting to experiment server...');
try
client_expcontroller = tcpclient("163.1.249.17",plab.locations.timelite_port,'ConnectTimeout',2);
configureCallback(client_expcontroller, "terminator", ...
    @(src,event,x) read_expcontroller_data(src,event,gui_fig));
catch me
    % Error if no connection to experiment controller
    update_status_text(text_h,'Error connecting to experiment server');
    error('Timelite -- Cannot connect to experiment controller: \n %s',me.message)
end

% Write text
status_text = [ ...
    {sprintf('Status: \n')}
    {sprintf('Sample rate: %d',daq_device.analog.Rate)}
    {sprintf('Samples/upload: %d \n',daq_device.analog.ScansAvailableFcnCount)}
    {'Analog input channels: '}
    join([{daq_device.analog.Channels.ID}',{daq_device.analog.Channels.Name}',],' | ')
    {sprintf('\nDigital output channels: ')}
    join([{daq_device.digital.Channels.ID}',{daq_device.digital.Channels.Name}',],' | ')];
set(text_h,'String',status_text)

% Initialize and upload gui data
gui_data = struct;
gui_data.text_h = text_h;
gui_data.user_button_h = user_button_h;
gui_data.daq_device = daq_device;
gui_data.client_expcontroller = client_expcontroller;

% Update status
update_status_text(gui_data.text_h,'Listening for start...');

% Update gui data
guidata(gui_fig,gui_data);

% Enable button
set(gui_data.user_button_h,'Enable','on');

end

function user_buttonpress(h,eventdata,gui_fig)

% Get gui data
gui_data = guidata(gui_fig);

if gui_data.daq_device.analog.Running
    % If DAQ is running: stop recording (with confirmation dialog)
    confirm = questdlg('\fontsize{14}Stop timelite?','Confirm timelite stop', ...
        'Yes','No',struct('Default','No','Interpreter','tex'));
    if strcmp(confirm,'Yes')
        daq_stop(gui_fig)
    end
else
    % If DAQ isn't running: start DAQ with no saving (preview mode)
    daq_start(gui_fig,[])
end

end

function daq_start(gui_fig,save_filename)

% Get gui data
gui_data = guidata(gui_fig);

if ~isempty(save_filename)
    % If save filename, create save file
    % (daq information)
    daq_info = struct( ...
        'rate',gui_data.daq_device.analog.Rate, ...
        'device',gui_data.daq_device.analog.Channels(1).Device.Model, ...
        'type',{gui_data.daq_device.analog.Channels.Type}, ...
        'channel',{gui_data.daq_device.analog.Channels.ID}, ...
        'measurement_type',{gui_data.daq_device.analog.Channels.MeasurementType}, ...
        'channel_name',{gui_data.daq_device.analog.Channels.Name});
    % (daq data - to be filled during streaming)
    [timestamps,data] = deal([]);
    % (save initial variables and keep open for streaming)
    save(save_filename,'daq_info','timestamps','data','-v7.3');
    gui_data.save_file_mat = matfile(save_filename,'Writable',true);
    % Update status
    update_status_text(gui_data.text_h,'RECORDING');
    % Update gui data
    guidata(gui_fig,gui_data);
else
    % If no save filename, empty (preview mode - no recording)
    gui_data.save_file_mat = [];
    % Update status
    update_status_text(gui_data.text_h,'PREVIEWING');
    % Update gui data
    guidata(gui_fig,gui_data);
end

% Start DAQ input acquisition, set outputs to HIGH
start(gui_data.daq_device.analog,'continuous');
pause(2); % ensure start before outputs high
write(gui_data.daq_device.digital,true);

% Create live plot (unclosable)
gui_fig_position = gui_fig.Position;
live_fig_position = ...
    [gui_fig_position(1)+gui_fig_position(3),gui_fig_position(2), ...
    1-(gui_fig_position(1)+gui_fig_position(3)),gui_fig_position(4)];

live_plot_fig = figure('CloseRequestFcn',[],'color','w', ...
    'Units','normalized','Position',live_fig_position, ...
    'Name','Timelite live plot','menu','none');
gui_data.live_plot_fig = live_plot_fig;

% Enable stop button
set(gui_data.user_button_h,'String','STOP','BackgroundColor',[0.8,0,0]);

% Update gui data
guidata(gui_fig,gui_data);

end

function daq_stop(gui_fig)

% Get gui data
gui_data = guidata(gui_fig);

% Stop DAQ input acquisition, set outputs to LOW
write(gui_data.daq_device.digital,false); 
pause(2); % ensure outputs low before stopping
stop(gui_data.daq_device.analog)

% Update status
update_status_text(gui_data.text_h,'Listening for start...');

% Delete live plot
delete(gui_data.live_plot_fig);

% Move data to server
move_data_to_server(gui_data.text_h);

% Update gui data
guidata(gui_fig,gui_data);

% Enable preview button
set(gui_data.user_button_h,'String','PREVIEW','BackgroundColor',[0,0.8,0]);

end

function daq_upload(obj,event,gui_fig)

% Get gui data
gui_data = guidata(gui_fig);

% Read buffered data
[daq_data,daq_timestamps] = ...
    read(obj,'all','OutputFormat','Matrix');

% Counter data: convert from unsigned to signed integer type
% (allow for negative values, rather than overflow)
% (assumes 32-bit counter)
position_channels_idx = strcmp({obj.Channels.MeasurementType},'Position');
daq_data(:,position_channels_idx) = ...
    double(typecast(uint32(daq_data(:,position_channels_idx)),'int32'));

% If save file exists, save data by appending
if isfield(gui_data,'save_file_mat') && ~isempty(gui_data.save_file_mat)
    % (get index for new data)
    curr_data_size = size(gui_data.save_file_mat.timestamps,1);
    new_data_size = length(daq_timestamps);
    new_data_row_idx = curr_data_size+1:curr_data_size+new_data_size;
    % (write data appended to existing data .mat file)
    gui_data.save_file_mat.timestamps(new_data_row_idx,1) = daq_timestamps;
    gui_data.save_file_mat.data(new_data_row_idx,1:size(daq_data,2)) = daq_data;
end

% Plot data
daq_plot(obj,gui_data,daq_data,gui_fig);

end

function daq_plot(obj,gui_data,daq_data,gui_fig)

plot_data_t = 5; % seconds of data to plot

if isfield(gui_data,'live_plot_fig') && isvalid(gui_data.live_plot_fig)
    if ~isfield(gui_data,'live_plot_traces') || ~any(isgraphics(gui_data.live_plot_traces))
        % If nothing plotted, create traces and plot data at end
        blank_data = zeros(plot_data_t*obj.Rate,size(daq_data,2));
        gui_data.live_plot_traces = stackedplot(gui_data.live_plot_fig,(0:size(blank_data,1)-1)/obj.Rate,blank_data);
        gui_data.live_plot_traces.DisplayLabels = {gui_data.daq_device.analog.Channels.Name};
        % Update gui data
        guidata(gui_fig,gui_data);
    end

    % Shift off old data, swap in new data
    old_plot_data = get(gui_data.live_plot_traces,'YData');
    new_plot_data = circshift(old_plot_data,-size(daq_data,1),1);
    new_plot_data(end-size(daq_data,1)+1:end,:) = daq_data;

    % Draw new data to plot
    gui_data.live_plot_traces.YData = new_plot_data;
    gui_data.live_plot_traces.DisplayLabels = {gui_data.daq_device.analog.Channels.Name};

    % Update gui data
    guidata(gui_fig,gui_data);
end

end

function read_expcontroller_data(client,event,gui_fig)
% Read message from experiment controller

% Get gui data
gui_data = guidata(gui_fig);

% Get message from experiment controller
expcontroller_message = readline(client);

if strcmp(expcontroller_message, 'stop')
    % If experiment controller sends stop, stop DAQ acquisition
    daq_stop(gui_fig);
else
    % Otherwise, assume message is information to start protocol    
    rec_info = jsondecode(expcontroller_message);

    % Set local filename
    save_filename = ...
        plab.locations.make_local_filename( ...
        rec_info.mouse,rec_info.date,rec_info.time,'timelite.mat');

    % Make local save directory
    mkdir(fileparts(save_filename))
    
    % Start DAQ acquisition
    daq_start(gui_fig,save_filename)
end

end

function update_status_text(text_h,status)
% Update status text

curr_text = get(text_h,'String');
new_text = [{sprintf('Status: %s',status)};curr_text(2:end)];
set(text_h,'String',new_text);

end

function move_data_to_server(text_h)
% Move data from local to server

% Check if the server is available
if ~exist(plab.locations.server_data_path,'dir')
    warning('Server not accessible at %s',plab.locations.server_data_path)
    return
end

% Move/merge all local data directories onto the server
local_data_dirs = dir(plab.locations.local_data_path);
for curr_dir = setdiff({local_data_dirs.name},[".",".."])

    curr_dir_local = fullfile(plab.locations.local_data_path,curr_dir);
    update_status_text(text_h,sprintf('Copying: %s --> %s',curr_dir_local,plab.locations.server_data_path))

    [status,message] = movefile(curr_dir_local,plab.locations.server_data_path);
    if ~status
        update_status_text(text_h,'Last copy to server failed! Listening for start...');
        warning('Timelite -- Failed copying to server: %s',message);
    else
        update_status_text(text_h,'Listening for start...');
    end
end
end







