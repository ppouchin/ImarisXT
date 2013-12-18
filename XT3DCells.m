% ImarisXT3DCells for Imaris 7.6.5
%
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%        <Submenu name="Mouse">
%          <Item name="Cells segmentation" icon="Matlab" tooltip="Detects the cells using a membrane marker">
%            <Command>MatlabXT::XT3DCells(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension detects the cells using a membrane marker.
%
%

function XT3DCells(aImarisApplicationID) % ID corresponds to Imaris instance

if isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
    vImarisApplication = aImarisApplicationID;
else
    % Connect to Imaris interface
    if exist('ImarisLib','class') == 0
        javaaddpath ImarisLib.jar
    end
    vImarisLib = ImarisLib;
    if ischar(aImarisApplicationID)
        aImarisApplicationID = round(str2double(aImarisApplicationID));
    end
    vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
end

% Get the dataset and the scene
aSurpassScene = vImarisApplication.GetSurpassScene;
aDataSet = vImarisApplication.GetDataSet.Clone;
sizeC = aDataSet.GetSizeC;
sizeT = aDataSet.GetSizeT;

%% Channel colors
% Red - Green - Blue - Magenta
rgbm = zeros(4,1);
for i=0:sizeC-1
    rgba = aDataSet.GetChannelColorRGBA(i);
    switch rgba
        case 255
            rgbm(1) = i+1;
        case 65280
            rgbm(2) = i+1;
        case 16711680
            rgbm(3) = i+1;
        case 16711935;
            rgbm(4) = i+1;
    end
end

%% User interface
% We have the user select which channel corresponds to the DNA
name='Parameters';
numlines=1;
prompt={'Enter the channel number of the membranes (green):'};
prompt{2} = 'Enter the channel number of the (red) marker to quantify (0 if none):';
prompt{3} = 'Enter the DAPI (blue) channel number (0 if no blue):';
prompt{4} = 'Enter the magenta channel number (0 if no magenta):';
prompt{5} = 'Enter the approximate cell size: (diameter / µm)';
if sizeT > 1
    prompt{6} = 'Enter the maximum search distance (tracking)';
end
defaultanswer={num2str(rgbm(2))};
defaultanswer{2}=num2str(rgbm(1));
defaultanswer{3}=num2str(rgbm(3));
defaultanswer{4}=num2str(rgbm(4));
defaultanswer{5}='10';
defaultanswer{6}='3';

% We retrieve the answers
answer=inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
rgbm(1)=floor(str2double(answer{2})-1); % Red Channel
rgbm(2)=floor(str2double(answer{1})-1); % Green Channel
rgbm(3)=floor(str2double(answer{3})-1); % Blue Channel
rgbm(4)=floor(str2double(answer{4})-1); % Magenta Channel
cellsSize = str2double(answer{5});

% We rectify incorrect answers
rgbm(rgbm < 0) = -1;
rgbm(rgbm >= sizeC) = -1;

%% Smoothing
aSize = [5 5 1];
vImarisApplication.GetImageProcessing.GaussFilterChannel(aDataSet,rgbm(2),0.3);
vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,rgbm(2),aSize);
% if rgbm(2) >= 0
%     vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,rgbm(2),aSize);
% end

%% Inverting
vImarisApplication.GetImageProcessing.InvertChannel(aDataSet,rgbm(2));


%% Segmentation
unit = aDataSet.GetUnit;

% DAPI Filter
blueFilter = '';
if rgbm(3) >= 0 && rgbm(3) < sizeC
    blueFilter = [' "Intensity Mean Ch=',num2str(rgbm(3)+1),'" above automatic threshold'];
end

% Imaris Surfaces
aSurface = vImarisApplication.GetImageProcessing.DetectSurfacesRegionGrowing(aDataSet,[],rgbm(2),0.3,0,1,0,cellsSize,1,...
                                                                             '"Quality" above 0', ...
                                                                             ['"Number of Voxels" between 10000 and automatic threshold'...
                                                                             blueFilter, ...
                                                                             ' "Distance to Image Border XY" above ' num2str(cellsSize) ' ' char(unit)]);
    % Put object in the scene
    aRGBA=aDataSet.GetChannelColorRGBA(rgbm(2));
    aSurface.SetColorRGBA(aRGBA);
    aSurface.SetName('Cells');
    aSurpassScene.AddChild(aSurface,-1);

%% Re-Inverting
vImarisApplication.GetImageProcessing.InvertChannel(aDataSet,rgbm(2));

%% Add stats
XT3DCells_distance(aImarisApplicationID);

end