%% dicomfolder: imports dicom images.
% [image, headers, folderName] = dicomfolder(folderName) 

% Christian: inserted folderName into output 2016-04-20

%
% Input
% folderName: Name of folder containing dicom images.  Image files must
% have extenstion .dcm, .ima, or no extension.
%
% Output
% image: 3D matrix containing the image data.  If more than one image is found,
% a cell array containing an entry for each image is returned.  Slices
% are sorted according to the Z coordinate of the ImagePositionPatient tag.
% headers: Cell array with header structures for each image.
%
% Dylan O'Connell
% doconnell@mednet.ucla.edu
% University of California, Los Angeles
% Department of Radiation Oncology
% 2015

function [images, headers, folderName] = dicomfolder(varargin)

%% Open dialogue box if no input folder is specified

if nargin == 0
    folderName = uigetdir;
else
    folderName = varargin{1};
end


%% Get image series filenames
dcmFilenames = dir(folderName);

% Remove subdirectories
subDirs = [dcmFilenames.isdir];
dcmFilenames(subDirs) = [];
dcmFilenames = {dcmFilenames.name};

% Check for .dcm and .ima extension
dcmFlag = cellfun(@checkExtension, dcmFilenames);
dcmFlag = logical(dcmFlag);
% Remove files that aren't .dcm, .ima or no extension
dcmFilenames = dcmFilenames(dcmFlag);


% If there are no dicom files in this folder throw error
if (~any(dcmFlag))
	error('No dicoms found in this directory.');
end


%% Import images and headers
nFiles = numel(dcmFilenames);
slicesRaw = cell(nFiles,1);
headersRaw = cell(nFiles,1);
seriesUIDs = cell(nFiles,1);

% dcmBar = waitbar(0,'Loading multi-echo files...','windowstyle', 'modal');
ignoreFiles = false(nFiles,1);

% Read in the image and meta data for all slices
for i = 1:nFiles
    headersRaw{i} = dicominfo(fullfile(folderName,dcmFilenames{i}));
    
    % Check for RTStruct, ignore
    if strcmp(lower(headersRaw{i}.Modality), 'rtstruct')
        ignoreFiles(i) = 1;
        slicesRaw{i} = '';
        sereisUIDs{i} = '';
    else
    
    slicesRaw{i} = dicomread(fullfile(folderName,dcmFilenames{i}));
    seriesUIDs{i} = headersRaw{i}.SeriesInstanceUID;

    end
    
    try
	    % waitbar(i/nFiles, dcmBar);
    end

end

try
    % close(dcmBar);
end

% Remove flagged files
slicesRaw(ignoreFiles) = [];
seriesUIDs(ignoreFiles) = [];
headersRaw(ignoreFiles) = [];


%% Sort images and headers

% Get dicom unique identifiers
imgUIDs = unique(seriesUIDs);

% Get number of images
numImgs = numel(imgUIDs);

% Pre-allocate cell arrays.  Each cell holds one image and one set of
% headers
headers = cell(numImgs,1);
images = cell(numImgs,1);

% For each images, stack the slices into a 3D matrix.  Stack the header
% files in the same order.

for i = 1:numImgs

    % Only consider files with a UID corresponding to this image
	imgFlag = strcmp(seriesUIDs,imgUIDs{i});

    % Build table:
    % header| image slice | z coordinate
	sortTable = cell(nnz(imgFlag),3);
	sortTable(:,1) = headersRaw(imgFlag);
    sortTable(:,2) = slicesRaw(imgFlag);

    % Sort by acquisition time
   	sortTable(:,3) = cellfun(@(x) x.('ImagePositionPatient')(3), headersRaw(imgFlag), 'uni', 0);

    % Sort by z coordinate
	sortTable = sortrows(sortTable,3);

    % Stack to create image matrix and header array
	headers{i} = sortTable(:,1);
	images{i} = double(reshape([sortTable{:,2}],[size(sortTable{1,2}) nnz(imgFlag)]));

	% Rescale image if necessary
    if isfield(headers{i}{1}, 'RescaleSlope')
        if ~isempty(headers{i}{1}.RescaleSlope)  
        images{i} = (images{i} .* headers{i}{1}.RescaleSlope) + headers{i}{1}.RescaleIntercept;
        end
    end
end

% If only one image is found, return a 3D matrix instead of a cell array
if numImgs == 1
	headers = headers{1};
	images = images{1};
end

end


function extFlag = checkExtension(filename)

% If filename is shorter than 4 characters mark it as having no extension
if length(filename) < 4
    extFlag = 1;
    
% Check for .dcm
elseif strcmpi(filename(end - 3: end), '.dcm')
    extFlag = 1;

% Check for .ima
elseif strcmpi(filename(end - 3: end), '.ima')
    extFlag = 1;
else
    extFlag = 0;
end
end
    

