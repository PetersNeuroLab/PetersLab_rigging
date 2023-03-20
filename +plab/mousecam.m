function mousecam
% Mouse camera recording GUI

%% Set up camera (specific to rig - make this breakout later)

% Clears existing matlab image aquisitions objects
imaqreset

% Set camera properties (from imaqhwinfo)

% Turn on embedding and set imaging properties in PointGrey adaptor
cam_DeviceName = imaqhwinfo('pointgrey').DeviceInfo.DeviceName;
video_object = videoinput('pointgrey',cam_DeviceName,'F7_Mono8_640x512_Mode1');

% (undocumented feature to turn on all embedding)
imaqmex('feature','-pointgreyEmbedMetadata',true)

src = getselectedsource(video_object);
src.FrameRate = 30;
src.ExposureMode = 'manual';
src.Exposure = -6;
src.GainMode = 'manual';
src.Gain = 6;
src.ShutterMode = 'manual';
src.Shutter = 6;
src.Brightness = 7;

% Set GPIO pin direction with GenTL adaptor
cam_DeviceName = imaqhwinfo('gentl').DeviceInfo.DeviceName;
video_object = videoinput('gentl',cam_DeviceName,'Mono8');
src = getselectedsource(video_object);
src.LineSelector = 'Line2';
src.LineMode = 'Input'; % set GPIO2 to input (flipper)
src.LineMode = 'Input'; % (need to double this line to work??)

video_object.FramesPerTrigger = Inf;
video_object.LoggingMode = 'disk&memory';

%% Set up figure

gui_fig = figure('Units','Normalized','Position',[0.01,0.2,0.32,0.5],'color','w');

% Preview image and embedded information text
im_axes = axes(gui_fig,'Position',[0,0.05,1,0.8]);
im_preview = image(zeros(video_object.VideoResolution));

embedded_info_text = uicontrol('Style','text','String','asdf', ...
    'Units','normalized','Position',[0,0,1,0.05], ...
    'BackgroundColor','w','HorizontalAlignment','left','FontSize',12, ...
    'FontName','Consolas');

setappdata(im_preview,'UpdatePreviewWindowFcn',@preview_cam);
setappdata(im_preview,'gui_fig',gui_fig);

preview(video_object,im_preview);
axis(im_axes);axis tight equal

% Control buttons
button_fontsize = 12;
view_button_position = [0,0.85,0.3,0.1];
clear view_button_h
view_button_h(1) = uicontrol('Parent',gui_fig,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'BackgroundColor','w', ...
    'String','Set ROI','Callback',{@set_roi,gui_fig});
view_button_h(end+1) = uicontrol('Parent',gui_fig,'Style','togglebutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'BackgroundColor','w', ...
    'String','Listen','Callback',{@cam_listen,gui_fig});
view_button_h(end+1) = uicontrol('Parent',gui_fig,'Style','togglebutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'BackgroundColor','w', ...
    'String','Manual','Callback',{@cam_manual,gui_fig});
align(view_button_h,'fixed',20,'middle');

% Store gui data
gui_data.video_object = video_object;
gui_data.gui_fig = gui_fig;
gui_data.im_axes = im_axes;
gui_data.im_preview = im_preview;
gui_data.embedded_info_text = embedded_info_text;

% Update GUI data
guidata(gui_fig,gui_data);

end

%% Button functions

function set_roi(h,eventdata,gui_fig)
% Draw and set ROI

% Get GUI data
gui_data = guidata(gui_fig);

% Reset ROI
gui_data.video_object.roi = [0,0,gui_data.video_object.VideoResolution];
axes(gui_data.im_axes); axis tight;

% Draw new ROI and want until finished
roi = drawrectangle(gui_data.im_axes);
wait(roi);

% Set new ROI position
roi_position = roi.Position;
if any(roi_position(2:3) == 0)
    roi_position = [0,0,gui_data.video_object.VideoResolution];
end
delete(roi);
gui_data.video_object.roi = roi_position;

% Set tight axes
axes(gui_data.im_axes); axis tight;

% Update GUI data
guidata(gui_fig,gui_data);

end

function cam_listen(h,event_data,gui_fig)
% Get gui data
gui_data = guidata(gui_fig);

% Set up listener for experiment controller
client_expcontroller = tcpclient("163.1.249.17",plab.locations.mousecam_port);
configureCallback(client_expcontroller, "terminator", ...
    @(src,event,x) read_expcontroller_data(src,event,gui_fig));

% Update gui data
guidata(gui_fig,gui_data);
end

function cam_manual(h,eventdata,gui_fig)

switch h.Value
    case 1
        % Manual recording is turned on

        % Get gui data
        gui_data = guidata(gui_fig);

        % Change button display and disable other buttons
        h.String = 'Stop';
        h.BackgroundColor = [0.8,0,0];
        h.ForegroundColor = 'w';
        set(gui_data.controls_h(gui_data.controls_h ~= h),'Enable','off');

        % User choose mouse name
        mouse_name = cell2mat(inputdlg('Mouse name'));
        if isempty(mouse_name)
            % (if no mouse entered, do nothing)
            return
        end

        % Set save filename
        error('need to update manual save location')
        save_dir = plab.locations.root_save;
        gui_data.save_filename = fullfile(save_dir,[mouse_name,'_timelite.mat']);

        % Update gui data
        guidata(gui_fig,gui_data);

        % Start DAQ acquisition
        cam_start(gui_fig);

    case 0
        % Manual recording is turned off

        % Stop recording
        cam_stop(gui_fig)

        % Get gui data
        gui_data = guidata(gui_fig);

        % Change button display and disable other buttons
        h.String = 'Manual';
        h.BackgroundColor = 'w';
        h.ForegroundColor = 'k';
        set(gui_data.controls_h,'Enable','on');

end

end

function cam_start(gui_fig)
% Start recording

% Get GUI data
gui_data = guidata(gui_fig);

% Create videowriter
[cam_file,cam_path] = fileparts(gui_data.save_filename);
vidWriter = VideoWriter(fullfile(cam_path,cam_file), 'Motion JPEG 2000');
vidWriter.CompressionRatio = 10;
gui_data.video_object.DiskLogger = vidWriter;

header_fn = fullfile(cam_path,[cam_file(1:end-4),'_header.bin']);
gui_data.header_fileID = fopen(header_fn,'w');

% Set header reader function
gui_data.video_object.FramesAcquiredFcnCount = 1;
gui_data.video_object.FramesAcquiredFcn = {@record_cam_header,gui_data.header_fileID};

start(gui_data.video_object)

% Reset relative display info
gui_data.set_relative_info_flag = true;

% Update GUI data
guidata(gui_fig,gui_data);

end

function cam_stop(gui_fig)
% Stop recording

% Get GUI data
gui_data = guidata(gui_fig);

% Stop recording and close header file
stop(gui_data.video_object)
fclose(gui_data.header_fileID);

end

%% Preview/record functions

function preview_embedded_info = preview_cam(h,eventdata,himage)
% Custom preview function: output header information

% Get GUI fig (grab different - can't input to this function)
gui_fig = getappdata(himage,'gui_fig');

% Get GUI data
gui_data = guidata(gui_fig);

% Decode embedded pixel data
flipper_pin = 2; % GPIO input for flipper
embed_pixels = eventdata.Data(1,1:40)';
[timestamp, frame_num, flipper] = AP_preprocess_face_camera(embed_pixels, flipper_pin);

% Set relative timestamp/frame display
if ~isfield(gui_data,'set_relative_info_flag')
    gui_data.set_relative_info_flag = true;
end
if gui_data.set_relative_info_flag
    gui_data.relative_info.timestamp = timestamp;
    gui_data.relative_info.frame_num = frame_num;
    gui_data.set_relative_info_flag = false;
end

% Print camera info
preview_embedded_info = ...
    sprintf('Framerate: %s, Timestamp: %.3f, Frame: %d, Flipper: %d', ...
    eventdata.FrameRate,timestamp - gui_data.relative_info.timestamp, ...
    frame_num - gui_data.relative_info.frame_num,flipper);
set(gui_data.embedded_info_text,'String',preview_embedded_info);

% Update preview image
himage.CData = eventdata.Data;

% Update GUI data
guidata(gui_fig,gui_data);

end


function record_cam_header(video_object,vid_info,header_fileID)
% Pull headers from memory frames and save

if video_object.FramesAvailable > 0

    % Set embedded pixel index
    embedded_pixels_idx = 1:40; % 4 px * 10 items = 40 pixels

    % Grab all frames currently in memory
    curr_im = getdata(video_object, video_object.FramesAvailable);

    % Save raw embedded pixel values in bin file
    embedded_pixels = permute(curr_im(1,embedded_pixels_idx,1,:),[2,4,1,3]);
    fwrite(header_fileID,embedded_pixels);

end

end

%% Communication function

function read_expcontroller_data(client,event,gui_fig)
% Read message from experiment controller

% Get gui data
gui_data = guidata(gui_fig);

% Get message from experiment controller
expcontroller_message = readline(client);

if strfind(expcontroller_message, 'stop')
    % If experiment controller sends stop, stop DAQ acquisition
    cam_stop(gui_fig);
else
    % If experiment controller experiment info
    
    exp_info = jsondecode(expcontroller_message);

    % Set local filename
    gui_data.save_filename = ...
        fullfile(plab.locations.local_data_path, ...
        exp_info.mouse,exp_info.date,num2str(exp_info.protocol),'mousecam.mj2');

    % Make local save directory
    mkdir(fileparts(gui_data.save_filename))
    
    % Start camera recording acquisition
    cam_start(gui_fig)
end

end

%% STORING FOR NOW: READ HEADER FROM SAVE

% % Load in set of frames from middle of experiment
% fn = 'C:\Users\peterslab\Documents\MATLAB\face_camera\mmmgui_test\test.mj2';
% vr = VideoReader(fn);
% curr_movie = read(vr);
%
% header_fn = [fn(1:end-4),'_header.bin'];
% header_fileID = fopen(header_fn,'r');
% embed_pixels = reshape(fread(header_fileID),40,[]);
% fclose(header_fileID);
%
% flipper_pin = 2;
% [timestamps, frame_num, flipper] = AP_preprocess_face_camera(embed_pixels, flipper_pin);







