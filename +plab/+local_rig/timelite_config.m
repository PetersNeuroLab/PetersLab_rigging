function daq_device = timelite_config
% Connect and configure DAQ for Timelite recording
% This is a template: modify for each rig and keep in rig local code

%% Set DAQ parameters 

% Set sample rate for DAQ
daq_sample_rate = 1000;

% Set DAQ buffer time (uploads and processes every n seconds)
daq_buffer_time = 1;

% Set daq index to use
use_daq_idx = 1;

%% Connect to DAQ

% Find and connect to DAQ
daqs_available = daqlist;
daq_device = daq(daqs_available.VendorID(use_daq_idx));

% Set DAQ properties 
daq_device.Rate = daq_sample_rate;
daq_device.ScansAvailableFcnCount = daq_buffer_time*daq_sample_rate;

%% Configure input/output channels

% Analog inputs
ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ctr0','Position');
ch.EncoderType = 'X4';
ch.Name = 'wheel';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai0','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'flipper';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai1','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'widefield_camera';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai2','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'face_camera';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai3','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'photodiode';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai4','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'stim_screen';

ch = addinput(daq_device,daqs_available.DeviceID(use_daq_idx),'ai5','Voltage');
ch.TerminalConfig = 'SingleEnded';
ch.Name = 'reward_valve';

% Digital output
ch = addoutput(daq_device,daqs_available.DeviceID(use_daq_idx),'port1/line0','Digital');
ch.Name = 'widefield_on';










