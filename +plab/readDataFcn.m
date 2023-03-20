function readDataFcn(server_stim, ~, server_timelite, server_mousecam, StartButton)
    disp('Data received')
    server_stim.UserData = readline(server_stim);
    disp(server_stim.UserData)
    if strfind(server_stim.UserData, 'done')
        % send stop to all servers 
        if server_timelite.Connected
            writeline(server_timelite, 'stop');
        end
%         writeline(server_mousecam, 'stop');

        % change button
        StartButton.Text = 'Start';
        StartButton.Value = 0;
    end
end

       