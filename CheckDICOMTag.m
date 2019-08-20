function CheckDICOMTag(patientFolder)

%% This functions check the DICOM tags on each DICOM file. The DICOM tags are
% compared to a defined template. This makes sure that the images has been
% aquired with the correct MRI aqusition sequence.
% The script should cover all visable parameters in the MRI protocols that
% have the possibility to be changed.

% Input is tested with DICOM files recieved with ConQuest DICOM server. The
% files has not been anonomized.

%% Version
% 2017-03-13
% (C) Christian Jamtheim Gustafsson, PhD
% Dept Haematology, Oncology and Radiation Physics
% Skåne University Hospital
% SE 221 85 Lund, Sweden
% +46 46 177647
% christian.JamtheimGustafsson@skane.se
% Adress: 3rd floor, Klinikgatan 5, Lund

% If script is being used, please cite the paper 
%%

%% SET UP ENVIRONMENT
% Define error count variable
errorCount = 0;

% Create an folder for keeping track of analysed patients
% If not exist create folder
folderAnalysed = 'Analysed';
if exist(folderAnalysed, 'dir') == 0
    mkdir(folderAnalysed)
end

% Serie to look for.
WhatWeNameTheSerie = 'Stor T2 till sCT';

%% OPTIONS FOR EMAIL
setpref('Internet','E_mail','MRIParameterCheckSyntheticCT@domain.se');
setpref('Internet','SMTP_Server','SMTP_Server.domain.se');
mailReceivers = {'user1@domain.se'; 'user2@domain.se'; 'user3@domain.se'};


%% READ DICOM SERIES
% Load the DICOM data.
% Using script downloaded from https://se.mathworks.com/matlabcentral/fileexchange/52390-dicomfolder
% DISCLAIMER REGARDING THE DOWNLOADED SCRIPT
% Copyright (c) 2016, Dylan O'Connell
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 
% * Redistributions of source code must retain the above copyright notice, this
%   list of conditions and the following disclaimer.
% 
% * Redistributions in binary form must reproduce the above copyright notice,
%   this list of conditions and the following disclaimer in the documentation
%   and/or other materials provided with the distribution
% * Neither the name of University of California, Los Angeles nor the names of its
%   contributors may be used to endorse or promote products derived from this
%   software without specific prior written permission.
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
% OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
% END DISCLAIMER

% Added extra output in his original script. 
% Check if input has also been given to the function
if  exist('patientFolder','var') == 0
    [import.DicomData, import.DicomInfo, import.patientFolder] = dicomfolder();
else
    [import.DicomData, import.DicomInfo, import.patientFolder] = dicomfolder(patientFolder);
end

% Convertion to single precision for reserving memory
DicomData.Imported = single(import.DicomData);
% Determine log file name
logfileName = [import.DicomInfo{1}.PatientName.FamilyName '_' num2str(import.DicomInfo{1}.SeriesDate) '_' num2str(import.DicomInfo{1}.SeriesTime) '.txt'];
%%

% Check if the patient alredy has been analysed
% If file does not exist, then run the analysis, else ignore
if exist(fullfile(pwd,folderAnalysed,logfileName), 'file') == 0
    %% OPEN LOG FILE
    fid = fopen(logfileName, 'a');
    %% PRIOR DATA INTEGRITY CHECK
    % Get number of slices
    numberSlices = size(DicomData.Imported,3);
    % Should be the same as number of objects in DICOM info
    if numberSlices ~= size(import.DicomInfo,1)
        WriteToLogAndDisplay(fid, 'Something is wrong with number of slices and DICOM info objects')
        % h  = msgbox('Something is wrong with the number of slices and DICOM info objects', 'Error','error');
        errorCount = errorCount + 1;
    end
    
    
    % Test to check the validity of SpacingBetweenSlices and SliceThickness and SliceLocation.
    % If errors larger than 0.1 mm exist, throw message.
    if strcmp(num2str(import.DicomInfo{1}.Modality),'MR')
        for i = 0:size(import.DicomInfo,1)-1
            if import.DicomInfo{1}.ImagePositionPatient(3) + i*import.DicomInfo{1}.SpacingBetweenSlices - import.DicomInfo{i+1}.SliceLocation > 0.1
                WriteToLogAndDisplay(fid, 'Something is wrong with the the assumed slice thickness');
                % h  = msgbox('Something is wrong with the the assumed slice thickness', 'Error','error');
                errorCount = errorCount + 1;
            end
        end
    else % For CT
        for i = 0:size(import.DicomInfo,1)-1
            if import.DicomInfo{1}.ImagePositionPatient(3) + i*import.DicomInfo{1}.SliceThickness - import.DicomInfo{i+1}.SliceLocation > 0.1
                WriteToLogAndDisplay(fid, 'Something is wrong with the the assumed slice thickness');
                % h  = msgbox('Something is wrong with the the assumed slice thickness', 'Error','error');
                errorCount = errorCount + 1;
            end
        end
    end
    
    
    %%
    
    %% CHECK THE DICOM  HEADER TAGS
    % Compare the strings in the DICOM header to template values
    
    % Start try block
    try
        
        % For all slices
        for i = 1:size(import.DicomInfo,1)
            % Check:
            if strcmp(num2str(import.DicomInfo{i}.Modality),'MR') ~= 1
                WriteToLogAndDisplay(fid, ['Modality is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Modality)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.StationName),'ONKMR01') ~= 1
                WriteToLogAndDisplay(fid, ['StationName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.StationName)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.SoftwareVersion),'27\LX\MR Software release:DV25.1_R02_1649.a') ~= 1
                WriteToLogAndDisplay(fid, ['Software version is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SoftwareVersion)])
                errorCount = errorCount + 1;
            end
            
            
            if strcmp(num2str(import.DicomInfo{i}.SeriesDescription),WhatWeNameTheSerie) ~= 1
                WriteToLogAndDisplay(fid, ['SeriesDescription is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SeriesDescription)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ProtocolName),'PROSTATA MR-PROTECT ver1') ~= 1
                WriteToLogAndDisplay(fid, ['ProtocolName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ProtocolName)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ManufacturerModelName),'DISCOVERY MR750w') ~= 1
                WriteToLogAndDisplay(fid, ['ManufacturerModelName is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ManufacturerModelName)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ScanningSequence),'SE') ~= 1
                WriteToLogAndDisplay(fid, ['ScanningSequence is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ScanningSequence)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ScanOptions),'FAST_GEMS\FC_SLICE_AX_GEMS\FC\EDR_GEMS\TRF_GEMS\FILTERED_GEMS\FSL_GEMS') ~= 1
                WriteToLogAndDisplay(fid, ['ScanOptions is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ScanOptions)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.MRAcquisitionType),'2D') ~= 1
                WriteToLogAndDisplay(fid, ['MRAcquisitionType is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.MRAcquisitionType)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.SliceThickness),'2.5') ~= 1
                WriteToLogAndDisplay(fid, ['SliceThickness is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.SliceThickness)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.RepetitionTime),'15000') ~= 1
                WriteToLogAndDisplay(fid, ['RepetitionTime is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.RepetitionTime)])
                errorCount = errorCount + 1;
            end
            
            if import.DicomInfo{i}.EchoTime < 90
                WriteToLogAndDisplay(fid, ['Echo time is too low. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.EchoTime)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.NumberOfAverages),'1') ~= 1
                WriteToLogAndDisplay(fid, ['NumberOfAverages is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.NumberOfAverages)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ImagedNucleus),'1H') ~= 1
                WriteToLogAndDisplay(fid, ['ImagedNucleus is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImagedNucleus)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.MagneticFieldStrength),'3') ~= 1
                WriteToLogAndDisplay(fid, ['ImagedNucleus is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImagedNucleus)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.EchoTrainLength),'15') ~= 1
                WriteToLogAndDisplay(fid, ['EchoTrainLength is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.EchoTrainLength)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.PercentSampling),'100') ~= 1
                WriteToLogAndDisplay(fid, ['PercentSampling is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PercentSampling)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.PercentPhaseFieldOfView),'70') ~= 1
                WriteToLogAndDisplay(fid, ['PercentPhaseFieldOfView is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PercentPhaseFieldOfView)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.PixelBandwidth),'244.141') ~= 1
                WriteToLogAndDisplay(fid, ['PixelBandwidth is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PixelBandwidth)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.ReconstructionDiameter),'448') ~= 1
                WriteToLogAndDisplay(fid, ['ReconstructionDiameter is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ReconstructionDiameter)])
                errorCount = errorCount + 1;
            end
            
            if import.DicomInfo{i}.AcquisitionMatrix ~= [640; 0; 0; 512]
                WriteToLogAndDisplay(fid, ['AcquisitionMatrix is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.AcquisitionMatrix(1)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(2)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(3)) ' and ' num2str(import.DicomInfo{i}.AcquisitionMatrix(4))])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.InPlanePhaseEncodingDirection),'COL') ~= 1
                WriteToLogAndDisplay(fid, ['InPlanePhaseEncodingDirection is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.InPlanePhaseEncodingDirection)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.FlipAngle),'130') ~= 1
                WriteToLogAndDisplay(fid, ['FlipAngle is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.FlipAngle)])
                errorCount = errorCount + 1;
            end
            
            % Number of slices can sometime change. 83 slices was limit on one
            % patient who weighted 63 kg (to do 1 pack with TR 15000). Give
            % notice about this
            if strcmp(num2str(import.DicomInfo{i}.ImagesInAcquisition),'88') ~= 1
                WriteToLogAndDisplay(fid, ['ImagesInAcquisition might be incorrect. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.ImagesInAcquisition)])
                % errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.Rows),'1024') ~= 1
                WriteToLogAndDisplay(fid, ['Rows is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Rows)])
                errorCount = errorCount + 1;
            end
            
            if strcmp(num2str(import.DicomInfo{i}.Columns),'1024') ~= 1
                WriteToLogAndDisplay(fid, ['Columns is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Columns)])
                errorCount = errorCount + 1;
            end
            
            
            if import.DicomInfo{i}.PixelSpacing ~= [0.4375; 0.4375]
                WriteToLogAndDisplay(fid, ['PixelSpacing is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.PixelSpacing(1)) ' and ' num2str(import.DicomInfo{i}.PixelSpacing(2)) ])
                errorCount = errorCount + 1;
            end
            
            % Check if the distance between spaces is 0 by comparing 2 values
            if import.DicomInfo{i}.SliceThickness-import.DicomInfo{i}.SpacingBetweenSlices ~= 0
                WriteToLogAndDisplay(fid, ['Slice Spacing isn not correct. Value for slice ' num2str(i) ' was not 0'])
                errorCount = errorCount + 1;
            end
            
            %% Below follows checks that are performed for private DICOM tags
            %% Parameters that can be changed in the protocol on default page
            
            % 3D Distortion correction and SCIC. (w and s are put together)
            if strcmp(num2str(import.DicomInfo{i}.Private_0043_102d),'ws') ~= 1
                WriteToLogAndDisplay(fid, ['3D distortion correction is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_102d)])
                errorCount = errorCount + 1;
            end
            
            % Flow_comp_direction
            % Change is visable is (0018,0022) ScanOptions which is checked already
            % prior to this section
            
            % Phase correct and Shim
            % Specific tag not detected but change was found in tag (0043,1001)
            % which is Bitmap of prescan options.
            % Phase correct = off, (0043,1001) = 4
            % Shim = off, (0043,1001) = 2
            % Phase correct = on and Shim = Auto, (0043,1001) = 6 in my test.
            
            if strcmp(num2str(import.DicomInfo{i}.Private_0043_1001),'6') ~= 1
                WriteToLogAndDisplay(fid, ['Phase correct and/or shim is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0043_1001)])
                errorCount = errorCount + 1;
            end
            
            %  RF Drive mode
            % Specific tag not detected but change was found in tagg (0043,10A8)
            % Dual Drive Mode, Amplitude Attenuation and Phase Offset
            % RF drive mode = preset (0043,10A8) = 2\30\-30
            % RF drive mode = quadrature (0043,10A8)= 1\0\0
            if import.DicomInfo{i}.Private_0043_10a8 ~= [2; 30; -30;];
                WriteToLogAndDisplay(fid, ['RF Drive mode is not correct.'])
                errorCount = errorCount + 1;
            end
            
            %% Parameters that can be changed in the protocol advanced page
            
            % BCO CV7
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10ae),'1') ~= 1
                WriteToLogAndDisplay(fid, ['BCO CV7 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10ae)])
                errorCount = errorCount + 1;
            end
            
            % CAS CV22
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10bd),'1') ~= 1
                WriteToLogAndDisplay(fid, ['CAS CV22 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10bd)])
                errorCount = errorCount + 1;
            end
            
            % EFSL CV21
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10bc),'0') ~= 1
                WriteToLogAndDisplay(fid, ['EFSL CV21 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10bc)])
                errorCount = errorCount + 1;
            end
            
            % FPPC CV8
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10af),'0') ~= 1
                WriteToLogAndDisplay(fid, ['FPPC CV8 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10af)])
                errorCount = errorCount + 1;
            end
            
            % HNE CV17
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10b8),'1') ~= 1
                WriteToLogAndDisplay(fid, ['HNE CV17 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10b8)])
                errorCount = errorCount + 1;
            end
            
            % MSR CV18
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10b9),'1') ~= 1
                WriteToLogAndDisplay(fid, ['MSR CV18 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10b9)])
                errorCount = errorCount + 1;
            end
            
            % RG CV39
            % Could not find specific tag but change detected in
            % (0043,1038)
            % DICOM conformance statement says the tag is a user data 25. Might not
            % be correct.
            if import.DicomInfo{i}.Private_0043_1038 ~= [0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 5; 0; 0; 0; 1; 0; 0; 0; 0; 0; 0; 0; 0; 0]
                WriteToLogAndDisplay(fid, ['RG CV39 is not correct.'])
                errorCount = errorCount + 1;
            end
            
            % SST CV 15
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_10b6),'1') ~= 1
                WriteToLogAndDisplay(fid, ['SST CV15 is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_10b6)])
                errorCount = errorCount + 1;
            end
            
            %%  General sequence check
            
            % FSE sequence
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_109e),'FSE') ~= 1
                WriteToLogAndDisplay(fid, ['Sequence type is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_109e)])
                errorCount = errorCount + 1;
            end
            
            % FRFSE sequence
            if strcmp(num2str(import.DicomInfo{i}.Private_0019_109c),'frfseopt') ~= 1
                WriteToLogAndDisplay(fid, ['Sequence type is not correct. Value for slice ' num2str(i) ' was ' num2str(import.DicomInfo{i}.Private_0019_109c)])
                errorCount = errorCount + 1;
            end
            
            %%
            
        end
        
    catch
        errorCount = errorCount + 1;
        h  = msgbox('Seems that some tags can not be read or are missing', 'Error','error');
    end
    
    %% Check the error status and alert by email
    if errorCount > 0
        WriteToLogAndDisplay(fid, [ num2str(errorCount) ' protocol error(s) were found in total for all slices'])
        % It is important that this row is at the end of the file. This is
        % being read by the Eclipse check script. 
        WriteToLogAndDisplay(fid, 'Line below must not be changed. This is matched in the Eclipse check script.')
        WriteToLogAndDisplay(fid, 'MRI SYNTHETIC CT PARAMETERS NOT OK')
        % WriteToLogAndDisplay(fid, ['It is estimated that ' num2str(errorCount/size(DicomData.Imported,3)) ' parameters were wrong'])
        h = msgbox('Parameters did not match', 'Error', 'error');
        statusCheck = ['Fail'];
        % Close file write
        fclose(fid);
        % Send email
        sendmail(mailReceivers, 'Fail', ['MRI protocol parameters was not correct for patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)], logfileName);
    else
        % It is important that this row is at the end of the file. This is
        % being read by the Eclipse check script. 
        statusCheck = ['OK'];
        WriteToLogAndDisplay(fid, 'Line below must not be changed. This is matched in the Eclipse check script.')
        WriteToLogAndDisplay(fid, 'MRI SYNTHETIC CT PARAMETERS OK')
        h = msgbox('Acqusition parameters are OK','Success');
        % Close file write
        fclose(fid);
        % Send email
        sendmail(mailReceivers, 'Success', ['MRI protocol parameters was OK for patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)], logfileName);
    end
    %%
    
    
    %% MOVE LOG FILE
    % OLD
    % movefile(logfileName,['./' folderAnalysed])
    % When using movefile file permissions for sharing is not propagated
    % correctly. 
    % Use Copy file for this matter to solve the problem.
   copyfile(logfileName,['./' folderAnalysed])
   % Then delete file
   delete(logfileName)
    
    % To do if patient has been analysed before
else
    display('Patient has already been analysed')
    h = msgbox('Patient has already been analysed', 'Warning', 'warn');
    sendmail(mailReceivers, 'Status quo', ['Patient has previously been analysed. Patient ' import.DicomInfo{1}.PatientName.FamilyName ' with image acqusition performed on ' num2str(import.DicomInfo{1}.SeriesDate) ' ' num2str(import.DicomInfo{1}.SeriesTime)]);
    
    % End of statement for checking if patient already has been analysed
end

% END
