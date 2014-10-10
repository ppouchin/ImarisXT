% XT3DFish_model for Imaris 7.6.4
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
%        <Submenu name="FISH">
%          <Item name="3D FISH Model" icon="Matlab" tooltip="Compute a model based on a FISH image">
%            <Command>MatlabXT::XTFISH_3DModel(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension computes a model based on a FISH image.
%
%
function XTFISH_3DModel(aImarisApplicationID) % ID corresponds to Imaris instance

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
vDataSet = vImarisApplication.GetDataSet;
aSurpassScene = vImarisApplication.GetSurpassScene;

%% Size variables
sizeX = vDataSet.GetSizeX;
sizeY = vDataSet.GetSizeY;
sizeZ = vDataSet.GetSizeZ;
sizeC = vDataSet.GetSizeC;
sizeT = vDataSet.GetSizeT;
extendMinX = vDataSet.GetExtendMinX;
extendMaxX = vDataSet.GetExtendMaxX;
extendMinY = vDataSet.GetExtendMinY;
extendMaxY = vDataSet.GetExtendMaxY;
extendMinZ = vDataSet.GetExtendMinZ;
extendMaxZ = vDataSet.GetExtendMaxZ;
spacingX = (extendMaxX - extendMinX) / sizeX;
spacingY = (extendMaxY - extendMinY) / sizeY;
unit = vDataSet.GetUnit;

%% Channel colors
% Red - Green - Blue - Magenta
rgbm = zeros(4,1);
for i=0:sizeC-1
    rgba = vDataSet.GetChannelColorRGBA(i);
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
prompt={'Enter channel number for the nucleus:'};
defaultanswer={num2str(rgbm(3))};
prompt{2}='Enter the estimated size of the nucleus:';
defaultanswer{2} = '0';
for i=1:sizeC-1
    prompt{i+2} = ['Enter the expected size (µm) of the objects in channel n°' num2str(i) ' with "spots":'];
    defaultanswer{i+2}='2';
end

% We retrieve the answers
answer=inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end

nucleus = answer{1}-1;
nucleusSize = str2double(answer{2});
spotSize = zeros(sizeC-1,1);
for i=1:sizeC-1
    spotSize(i) = str2double(answer{i+2});
end

% We rectify incorrect answers
if(nucleus < 0)
    nucleus = 0;
elseif nucleus >= sizeC
    nucleus = sizeC-1;
end

%% Working Dataset and Z size
sizeZ = vDataSet.GetSizeZ;
extendMinZ = vDataSet.GetExtendMinZ;
extendMaxZ = vDataSet.GetExtendMaxZ;
spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

%% Nucleus detection
% Compute Imaris Surfaces

if nucleusSize > 0
    aNucleus = vImarisApplication.GetImageProcessing.DetectSurfacesRegionGrowing(vDataSet,[],nucleus,0.2,0,1,0,nucleusSize,1,...
                                                                                    '"Quality" above 0', ...
                                                                                    '"Number of Voxels" above 100');
%                                                                                    ['"Number of Voxels" above 100'...
%                                                                                     ' "Distance to Image Border XY" above ' num2str(cellsSize) ' ' char(unit)]);
else
    aNucleus = vImarisApplication.GetImageProcessing.DetectSurfaces(vDataSet,[],nucleus,0.2,0,1,0,'"Number of Voxels" above 100');
end
aRGBA=vDataSet.GetChannelColorRGBA(nucleus);
aNucleus.SetColorRGBA(aRGBA);
aNucleus.SetName('Nucleus');
aSurpassScene.AddChild(aNucleus,-1);


%% Nuclei mask (& prepare distance map)
aType=Imaris.tType.eTypeUInt16;
vDataSet.SetType(aType);
vDataSet.SetSizeC(sizeC+1);

n = aNucleus.GetNumberOfSurfaces;
tracks = aNucleus.GetTrackIds;
if isempty(tracks)
    tracks = 1:n;
end

% for i=1:n
%     % Get the time index of the object
%     time = aNucleus.GetTimeIndex(i-1);
%     
%     % Get the mask image from the surface object
%     vMaskImage = aNucleus.GetSingleMask(i-1,extendMinX, extendMinY, extendMinZ, extendMaxX, extendMaxY, extendMaxZ, sizeX, sizeY, sizeZ);
    
% Show mask (quickly if image is rather small)
if sizeX * sizeY * sizeZ < 419430400
    vNewChannel = int16(zeros(sizeX * sizeY * sizeZ,1));
    
    for i=1:n
        % Get the time index of the object
        time = aNucleus.GetTimeIndex(i-1);

        % Get the mask image from the surface object
        vMaskImage = aNucleus.GetSingleMask(i-1,extendMinX, extendMinY, extendMinZ, extendMaxX, extendMaxY, extendMaxZ, sizeX, sizeY, sizeZ);
        vMask = tracks(i) * int16(vMaskImage.GetDataVolumeAs1DArrayBytes(0,time));
        vNewChannel = vNewChannel + vMask;
    end
    vDataSet.SetDataVolumeAs1DArrayShorts(vNewChannel,sizeC,time);
else
    for z=0:sizeZ-1
        vNewSlice = int16(zeros(sizeX,sizeY));

        for i=1:n
            % Get the time index of the object
            time = aNucleus.GetTimeIndex(i-1);

            % Get the mask image from the surface object
            vMaskImage = aNucleus.GetSingleMask(i-1,extendMinX, extendMinY, extendMinZ, extendMaxX, extendMaxY, extendMaxZ, sizeX, sizeY, sizeZ);
            vMaskSlice = tracks(i) * int16(vMaskImage.GetDataSliceBytes(z,0,time));
            vNewSlice = vNewSlice + vMaskSlice;
        end
        vDataSet.SetDataSliceShorts(vNewSlice,z,sizeC,time);
    end
end

% end

aType=Imaris.tType.eTypeUInt16;
vDataSet.SetType(aType);
vDataSet.SetChannelName(sizeC,'Nuclei');
vImarisApplication.SetDataSet(vDataSet);


%% Spots detection
% We wait a bit before going further
pause(2);
aSpots = javaArray('Imaris.ISpotsPrxHelper', sizeC-1);

for i=1:sizeC-1
    if i>=nucleus+1
        ch=i;
    else
        ch=i-1;
    end
    aSpots(i) = vImarisApplication.GetImageProcessing.DetectSpots2(vDataSet,[],ch,spotSize(i),1,['"Quality" above automatic threshold'...
                                                                                                 ' "Intensity Center Ch=',num2str(sizeC+1),'" above 0.5']);
    aRGBA=vDataSet.GetChannelColorRGBA(ch);
    aSpots(i).SetColorRGBA(aRGBA);
    aSpots(i).SetName(['Spots Ch' num2str(ch+1)]);
    aSurpassScene.AddChild(aSpots(i),-1);
end

%% Distance from nucleus centroid to sphere centroid to boundary
XTFISH_Regenerate_Stats(aImarisApplicationID);

end