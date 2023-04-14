% NOTE ON INSTALLING SOFTWARE: 
% install these: https://dcam-api.com/hamamatsu-software/
% in matlab: imaqregister('C:\Users\peterslab\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\Hamamatsu Image Acquisition\hamamatsu.dll')

function hamamatsu_test

cam_DeviceName = imaqhwinfo('hamamatsu').DeviceInfo.DeviceName;
video_object = videoinput('hamamatsu',cam_DeviceName);
src = getselectedsource(video_object);


video_object.LoggingMode = "disk";

% Set input trigger
src.TriggerSource = "external";
src.TriggerActive = "level";
src.TriggerGlobalExposure = "globalreset";

% Set outputs
src.OutputTriggerKindOpt1 = "triggerready";
src.OutputTriggerKindOpt2 = "exposure";

% Set ROI (doesn't work?)
src.SubarrayMode = "on";
src.SubarrayHorizontalPos = 256;
src.SubarrayHorizontalSize = 512;
src.SubarrayVerticalPos = 256;
src.SubarrayVerticalSize = 512;

% % vid roi?
% vid.ROIPosition = [256,256,512,512];


% Make preview fig
preview_fig = figure;
clear preview_im
p1 = subplot(1,2,1); preview_im(1) = image(zeros(video_object.VideoResolution));
p2 = subplot(1,2,2); preview_im(2) = image(zeros(video_object.VideoResolution));

setappdata(preview_im(1),'UpdatePreviewWindowFcn',@preview_cam);

keyboard

preview(video_object,preview_im(1));

%% Cheaty way to alternate since only one image can be passed in: get parent figure? or struct input

end



function preview_cam(obj,event,himage)
% Example update preview window function.

% Get timestamp for frame.
tstampstr = event.Timestamp;

% Get handle to text label uicontrol.
ht = getappdata(himage,'HandleToTimestampLabel');

% Set the value of the text label.
ht.String = tstampstr;

% Display image data.
himage.CData = event.Data

end
















