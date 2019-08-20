function WriteToLogAndDisplay(fid, message)
% Function for writing message to Matlab display windows + a log file

% Display on screen
display(num2str(message)); 
% Write to log file
fprintf(fid, '%s \n', [num2str(message)]);
end

