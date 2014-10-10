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
%        <Item name="3D FISH Model" icon="Matlab" tooltip="Compute a model based on a FISH image">
%          <Command>MatlabXT::XT3DFish_model(%i)</Command>
%        </Item>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension computes a model based on a FISH image.
%
%
function XT3DFish_model(aImarisApplicationID) % ID corresponds to Imaris instance

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
for i=2:sizeC
    prompt{i} = ['Enter the expected size (µm) of the objects in channel n°' num2str(i-1) ' with "spots":'];
    defaultanswer{i}='2';
end

% We retrieve the answers
answer=inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end

nucleus = answer{1}-1;
spotSize = zeros(sizeC-1,1);
for i=2:sizeC
    spotSize(i-1) = str2double(answer{i});
end

% We rectify incorrect answers
if(nucleus < 0)
    nucleus = 0;
elseif nucleus >= sizeC
    nucleus = sizeC-1;
end

%% Working Dataset and Z size
aDataSet = vDataSet.Clone;
sizeZ = aDataSet.GetSizeZ;
extendMinZ = aDataSet.GetExtendMinZ;
extendMaxZ = aDataSet.GetExtendMaxZ;
spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

extendMin = [extendMinX extendMinY extendMinZ];
spacing = [spacingX spacingY spacingZ];

%% Nucleus detection
% Compute Imaris Surfaces

% aNucleus = vImarisApplication.GetImageProcessing.DetectSurfacesRegionGrowing(aDataSet,[],nucleus,0.2,0,0,0,cellsSize,1,...
%                                                                                 '"Quality" above 0', ...
%                                                                                ['"Number of Voxels" above 100'...
%                                                                                 ' "Distance to Image Border XY" above ' num2str(cellsSize) ' ' char(unit)]);
aNucleus = vImarisApplication.GetImageProcessing.DetectSurfaces(aDataSet,[],nucleus,0.2,0,1,0,'"Number of Voxels" above 100');
aRGBA=aDataSet.GetChannelColorRGBA(nucleus);
aNucleus.SetColorRGBA(aRGBA);
aNucleus.SetName('Nucleus');
aSurpassScene.AddChild(aNucleus,-1);


%% Spots detection
aSpots = javaArray('Imaris.ISpotsPrxHelper', sizeC-1);

for i=1:sizeC-1
    if i>=nucleus+1
        ch=i;
    else
        ch=i-1;
    end
    aSpots(i) = vImarisApplication.GetImageProcessing.DetectSpots2(aDataSet,[],ch,spotSize(i),1,['"Quality" above automatic threshold'...
                                                                                                 ' "Intensity Center Ch=',num2str(nucleus+1),'" above automatic threshold']);
    aRGBA=aDataSet.GetChannelColorRGBA(ch);
    aSpots(i).SetColorRGBA(aRGBA);
    aSpots(i).SetName(['Spots Ch' num2str(ch+1)]);
    aSurpassScene.AddChild(aSpots(i),-1);
end

%% Add statistics

%% Nuclei mask (& prepare distance map)
aType=Imaris.tType.eTypeUInt16;
vDataSet.SetType(aType);
vDataSet.SetSizeC(sizeC+2);

n = aNucleus.GetNumberOfSurfaces;
tracks = aNucleus.GetTrackIds;
if isempty(tracks)
    tracks = 1:n;
end

for i=1:n
    % Get the time index of the object
    time = aNucleus.GetTimeIndex(i-1);
    
    % Get the mask image from the surface object
    vMaskImage = aNucleus.GetSingleMask(i-1,extendMinX, extendMinY, extendMinZ, extendMaxX, extendMaxY, extendMaxZ, sizeX, sizeY, sizeZ);
    
    % Show mask (quickly if image is rather small)
    if sizeX * sizeY * sizeZ < 419430400
        vMask = tracks(i) * int16(vMaskImage.GetDataVolumeAs1DArrayBytes(0,time));
        vNewChannel = vDataSet.GetDataVolumeAs1DArrayShorts(sizeC,time) + vMask;
        vDataSet.SetDataVolumeAs1DArrayShorts(vNewChannel,sizeC,time);
        vDataSet.SetDataVolumeAs1DArrayShorts(vNewChannel,sizeC+1,time);
    else
        for z=0:sizeZ-1
            vMaskSlice = tracks(i) * int16(vMaskImage.GetDataSliceBytes(z,0,time));
            vNewSlice = vDataSet.GetDataSliceShorts(z,sizeC,time) + vMaskSlice;
            vDataSet.SetDataSliceShorts(vNewSlice,z,sizeC,time);
            vDataSet.SetDataSliceShorts(vNewSlice,z,sizeC+1,time);
        end
    end
end
    
%% Distance map
aType=Imaris.tType.eTypeFloat;
vDataSet.SetType(aType);
vImarisApplication.GetImageProcessing.DistanceTransformChannel(vDataSet,sizeC+1,1,true);

%aColorRGB=(0:256:65280)';
%aColorRGB=[0:197379:16777215,16580607:-196608:65535,65280:-766:255]';
%aA = 0;
%vDataSet.SetChannelColorTable(sizeC+1, aColorRGB, aA);
vImarisApplication.SetDataSet(vDataSet);

%% Distance from nucleus centroid to sphere centroid to boundary
% % nb_surfaces = aNucleus.GetNumberOfSurfaces;
% % for j=1:nb_surfaces
% %     CMN = aNucleus.GetCenterOfMass(j);
% %     vertices = aNucleus.GetVertices(j);
% %     triangles = aNucleus.GetTriangles(j);
% %     faces = triangles + 1; % Index correction for Matlab
% %     
% %     %CMS = aSpots(1).GetPositionsXYZ
% %     l = [CMN CMS-CMN];
% %     [inters pos] = intersectLineMesh3d(l,vertices, faces);
% %     point = inters(pos>0,:);
% % end

% XT2DArea_regenerate(aImarisApplicationID);
% precision = 10e3;
% for i=1:nb_surfaces
%     % Get stats
%     stats = aSurface(i).GetStatistics;
%     aNames = cell(stats.mNames);
%     aUnits = cell(stats.mUnits);
%     aFactornames = cell(stats.mFactorNames);
%     aUnit = char(aUnits(find(ismember(aNames, 'Area')==1, 1)));
%     aName = '2D Area';
%     
%     % Compute 2D area
%     n = aSurface(i).GetNumberOfSurfaces;
%     areas = zeros(n,1);
%     ids = zeros(n,1);
%     names = cell(n,1);
%     units = cell(n,1);
%     factors = cell(4,n);
%     for j=0:n-1
%         % Find vertices in Z=0 plane (or close enough)
%         vertices = aSurface(i).GetVertices(j);
%         I=find(round(precision*vertices(:,3))==round(precision*(extendMinZ+spacingZ/2)));
%         
%         % Sort 2D vertices %% To fix
%         x=vertices(I,1);
%         y=vertices(I,2);
%         cx = mean(x);
%         cy = mean(y);
%         a = atan2(y - cy, x - cx);
%         [~, order] = sort(a);
%         x = x(order);
%         y = y(order);
%         
%         % Compute 2D area
%         areas(j+1) = polyarea(x,y);
%         ids(j+1) = j;
%         names(j+1) = {aName};
%         units(j+1) = {aUnit};
%         factors(:,j+1) = {'Surface';'';'';num2str(aSurface(i).GetTimeIndex(j)+1)};
%     end
%     
%     % Add statistics
%     aSurface(i).AddStatistics(names,areas,units,factors,aFactornames,ids);
% end

% aType=Imaris.tType.eTypeUInt8;
% vDataSet.SetType(aType);

end