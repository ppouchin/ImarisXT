%
%
%  Mouse Cells Coloc Function for Imaris 7.3.1 (and Sylvain)
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
%           <Item name="Markers coloc" icon="Matlab" tooltip="Computes the colocalization of different markers.">
%             <Command>MatlabXT::XT_Mouse_coloc(%i)</Command>
%           </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
% 
%
%  Description:
%   
%   A function to compute the percentage of colocalization between different cells.
% 

function XT_Mouse_coloc(aImarisApplicationID) % ID corresponds to Imaris instance

% get the application object
if isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
    % called from workspace
    vImarisApplication = aImarisApplicationID;
else
    % connect to Imaris interface
    javaaddpath ImarisLib.jar
    vImarisLib = ImarisLib;
    if ischar(aImarisApplicationID)
        aImarisApplicationID = round(str2double(aImarisApplicationID));
    end
    vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
end

%% Data cloning
aType = Imaris.tType.eTypeUInt16;
vDataSet = vImarisApplication.GetDataSet;
vDataSet.SetType(aType);
aSurpassScene = vImarisApplication.GetSurpassScene;
aDataSet = vDataSet.Clone; %% Current dataset
aBackgroundSubtraction=1;

%% Dataset variables
% Size of Data
%sizeT = vDataSet.GetSizeT;
sizeX = vDataSet.GetSizeX;
sizeY = vDataSet.GetSizeY;
sizeZ = vDataSet.GetSizeZ;
sizeC = vDataSet.GetSizeC;
extendMinX = aDataSet.GetExtendMinX;
extendMinY = aDataSet.GetExtendMinY;
extendMinZ = aDataSet.GetExtendMinZ;
extendMaxX = aDataSet.GetExtendMaxX;
extendMaxY = aDataSet.GetExtendMaxY;
extendMaxZ = aDataSet.GetExtendMaxZ;
spacingX = (extendMaxX - extendMinX) / sizeX;
spacingY = (extendMaxY - extendMinY) / sizeY;
spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

%Name
aParameterSection='Image';
aParameterName='Name';
aDataName = char(vDataSet.GetParameter(aParameterSection,aParameterName));
if isempty(aDataName)
    aDataName = 'res';
end

% Vector "numberofspots" initialization
aNumberOfSpots = {'Canal', 'Nombre'};
aNames = cell(1, sizeC);

%% User interface
name='Colocalization parameters';
numlines=1;
% We have the user select which channel corresponds to the DNA
prompt={'Enter the "DNA Channel" number:'};
defaultanswer={num2str(sizeC)};
% And which is the "gray" channel
prompt{2}='Enter the "gray" channel number:';
defaultanswer{2}=num2str(2);
if sizeC == 4
    defaultanswer{2}=num2str(0);
end
prompt{3}='Nom du fichier résultats ? (dans C:\Temp\)';
defaultanswer{3}=aDataName;
% Sizes of the objects
for i=1:sizeC
    prompt{i+3} = ['(Channel ',num2str(i),') Estimated size of the cells (um):'];
    defaultanswer{i+3}='5';
end

% We retrieve the answers
answer=inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
dapi=floor(str2double(answer{1})-1); % DNA Channel
gray=floor(str2double(answer{2})-1); % Gray Channel
objectsSize = zeros(sizeC,1);
for i=1:sizeC
    objectsSize(i)=str2double(answer{i+3}); % Size of the cells
end

fichier = ['C:\Temp\', answer{3}, '.xls'];

% We rectify incorrect answers
if dapi < 0
    dapi = 0;
else if dapi >= sizeC
    dapi = sizeC - 1;
    end
end

if gray >= sizeC
    gray = dapi - 3;
end

vProgressTotalCount = 4;
vProgressDisplay = waitbar(0,'Gray channel filtering');
vProgressCount = 0;

%% "Gray" channel filtering
aSize = [5 5 3];
aDataDNA1D = aDataSet.GetDataVolumeAs1DArrayShorts(dapi,0);
if gray > -1
    %vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,dapi,aSize);
    aData1D = aDataSet.GetDataVolumeAs1DArrayShorts(gray,0);
    aData1D = aData1D .* min(1,aDataDNA1D);
    aData = reshape(aData1D,sizeX,sizeY,sizeZ);
    aDataSet.SetDataVolumeShorts(uint16(aData),gray,0);
    vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,gray,aSize);
    %aDataSetFiltered = vImarisApplication.GetImageProcessing.MedianFilterDataSet(aDataSet,aSize);
    %vDataSet = aDataSetFiltered;
    %aDataSet = aDataSetFiltered;
end

vProgressCount = vProgressCount + 1;
waitbar(vProgressCount/vProgressTotalCount,vProgressDisplay,'Filtering other channels')

%% Median filter on other channels
% thresh = zeros(1,sizeC);

% histo = histc(single(aDataDNA1D), 0:255);
% P = histo / sum(histo);
% P2 = P .* (1:256);
% muT = ones(256,256) * sum(P2(1:256));
% omega0 = zeros(256, 256);
% omega1 = omega0;
% omega2 = omega0;
% mu0 = omega0;
% mu1 = omega0;
% mu2 = omega0;
% for i=1:255
%     for j=i+1:256
%         omega0(i,j) = sum(P(1:i));
%         omega1(i,j) = sum(P(i+1:j));
%         omega2(i,j) = sum(P(j+1:256));
%         mu0(i,j) = sum(P2(1:i)) ./ omega0(i,j);
%         mu1(i,j) = sum(P2(i+1:j)) ./ omega1(i,j);
%         mu2(i,j) = sum(P2(j+1:256)) ./ omega2(i,j);
%     end
% end
% sigma = omega0 .* (mu0 - muT).^2 + omega1 .* (mu1 - muT).^2 + omega2 .* (mu2 - muT).^2;
% [Y, I] = max(sigma);
% [~, J] = max(Y);
% thresh(dapi+1) = I(J);
% thresh(dapi+1) = 10;
%vImarisApplication.GetImageProcessing.ThresholdChannel(aDataSet, dapi, thresh(dapi+1), 0);
%aDataDNA1D = aDataSet.GetDataVolumeAs1DArrayShorts(dapi,0);

for c=0:sizeC-1
    if c ~= dapi && c ~= gray
        aData1D = aDataSet.GetDataVolumeAs1DArrayShorts(c,0);
        aData1D = aData1D .* min(1,aDataDNA1D);
        aData = reshape(aData1D,sizeX,sizeY,sizeZ);
        aDataSet.SetDataVolumeShorts(uint16(aData),c,0);

%         histo = histc(single(aData1D), 0:255);
%         P = histo / sum(histo);
%         P2 = P .* (1:256);
%         omega0 = zeros(256, 1);
%         omega1 = omega0;
%         mu0 = omega0;
%         mu1 = omega0;
%         for i=1:256
%             omega0(i) = sum(P(1:i));
%             omega1(i) = sum(P(i+1:256));
%             mu0(i) = sum(P2(1:i)) ./ omega0(i);
%             mu1(i) = sum(P2(i+1:256)) ./ omega1(i);
%         end
%         sigma = omega0 .* omega1 .* (mu1 - mu0) .* (mu1 - mu0);
%         [~, thresh(c+1)] = max(sigma);
        vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet, c, aSize);
%         vImarisApplication.GetImageProcessing.ThresholdChannel(aDataSet, c, thresh(c+1), 0);
    end
end
%display(thresh);
vProgressCount = vProgressCount + 1;
waitbar(vProgressCount/vProgressTotalCount,vProgressDisplay,'Segmentation')

%% Cells Segmentation
% DNA
color=aDataSet.GetChannelColorRGBA(dapi);
aNames{dapi+1} = char(aDataSet.GetChannelName(dapi));
aSpots{dapi+1} = vImarisApplication.GetImageProcessing.DetectEllipticSpotsRegionGrowing(aDataSet,[],dapi,[objectsSize(dapi+1) objectsSize(dapi+1) 2*objectsSize(dapi+1)],aBackgroundSubtraction,'"Quality" above 0', 1, 1, 0.0, 1, 1);
aSpots{dapi+1}.SetName(aNames{dapi+1});
aSpots{dapi+1}.SetColorRGBA(color);
aNumberOfSpots{dapi+2,1} = aNames{dapi+1};
len = length(aSpots{dapi+1}.GetRadii);

% Change size of displayed spots
% XYZ = aSpots{dapi+1}.GetPositionsXYZ;
% iT = aSpots{dapi+1}.GetIndicesT;
aSpots{dapi+1}.SetRadiiXYZ(ones(len,1) * [objectsSize(dapi+1)/2 objectsSize(dapi+1)/2 objectsSize(dapi+1)]);
aSurpassScene.AddChild(aSpots{dapi+1},-1);


% Gray
if gray > -1
color=aDataSet.GetChannelColorRGBA(gray);
    aNames{gray+1} = char(aDataSet.GetChannelName(gray));
    aSpots{gray+1} = vImarisApplication.GetImageProcessing.DetectEllipticSpots(aDataSet,[],gray,[objectsSize(gray+1) objectsSize(gray+1) 2*objectsSize(gray+1)],aBackgroundSubtraction,'"Quality" above 0' );
    aSpots{gray+1}.SetName(aNames{gray+1});
    aSpots{gray+1}.SetColorRGBA(color);
    aNumberOfSpots{gray+2,1} = aNames{gray+1};
    aSurpassScene.AddChild(aSpots{gray+1},-1);
end


% Other channels
for c=0:sizeC-1
    if c ~= dapi && c ~= gray
        color = aDataSet.GetChannelColorRGBA(c);
        aNames{c+1} = char(aDataSet.GetChannelName(c));
%         aSpots{c+1} = vImarisApplication.GetImageProcessing.DetectSpots2(aDataSet,[],dapi,objectsSize(c+1),aBackgroundSubtraction,['"Intensity Center Ch=',num2str(c+1),'" above automatic threshold']);
%         aSpots{c+1} = vImarisApplication.GetImageProcessing.DetectEllipticSpots(aDataSet,[],c,[objectsSize(c+1) objectsSize(c+1) 2*objectsSize(c+1)],aBackgroundSubtraction,['"Quality" above automatic threshold "Intensity Min Ch=',num2str(dapi+1),'" above ',num2str(thresh(dapi+1))]);
%         aSpots{c+1} = vImarisApplication.GetImageProcessing.DetectSpots2(aDataSet,[],c,objectsSize(c+1),aBackgroundSubtraction,'"Quality" above 0');
        aSpots{c+1} = vImarisApplication.GetImageProcessing.DetectEllipticSpots(aDataSet,[],c,[objectsSize(c+1) objectsSize(c+1) 2*objectsSize(c+1)],aBackgroundSubtraction,'"Quality" above automatic threshold');
        aSpots{c+1}.SetName(aNames{c+1});
        aSpots{c+1}.SetColorRGBA(color);
        aNumberOfSpots{c+2,1} = aNames{c+1};
        aSurpassScene.AddChild(aSpots{c+1},-1);
    end
end

vProgressCount = vProgressCount + 1;
waitbar(vProgressCount/vProgressTotalCount,vProgressDisplay,'Cleaning Zones')

%% Cleaning & sorting

aDataDNA1D = aDataSet.GetDataVolumeAs1DArrayShorts(sizeC,0);
aDataDNA = reshape(aDataDNA1D, sizeX, sizeY, sizeZ);
vmin = min(aDataDNA1D); % vmin = background
vmax = max(aDataDNA1D);
aZones = zeros(vmax+1 - vmin, sizeC+1);

for c = 1:sizeC
    p = aSpots{c}.GetPositionsXYZ;
    len = size(p,1);
    
    if numel(p) > 1
        for i=1:len
            posx = ceil((p(i,1)-extendMinX)/spacingX);
            posy = ceil((p(i,2)-extendMinY)/spacingY);
            posz = ceil((p(i,3)-extendMinZ)/spacingZ);
            v = aDataDNA(posx, posy, posz);
            aZones(v-vmin+1,c+1) = aZones(v-vmin+1,c+1) + 1;
        end
    end
end
for v=vmin+1:vmax
    aZones(v-vmin+1,1) = v;
    if aZones(v-vmin+1,dapi+2) == 0
        aDataDNA(aDataDNA == v) = 0;
    end
    if aZones(v-vmin+1,gray+2) > 1 && gray > -1
        aZones(v-vmin+1,dapi+2) = aZones(v-vmin+1,gray+2);
    end
    for c=0:sizeC-1
        if c ~= dapi && c ~= gray
            if aZones(v-vmin+1,c+2) > aZones(v-vmin+1,dapi+2)
                aZones(v-vmin+1,c+2) = aZones(v-vmin+1,dapi+2);
            end
        end
    end
end
I = aZones(:,dapi+2) == 0;
aZones(I,:) = [];

aDataSet.SetDataVolumeShorts(uint16(aDataDNA),sizeC,0);

% aSpotsZones = zeros(size(aZones,1), 3);
% p = aSpots{dapi+1}.GetPositionsXYZ;
% len = size(p,1);

vProgressCount = vProgressCount + 1;
waitbar(vProgressCount/vProgressTotalCount,vProgressDisplay,'Saving file')

%% Save file
zonesSize = size(aZones, 1);
aResZones = cell(zonesSize+1, sizeC+1);
aResZones{1,1} = 'Region ID';
for i=1:sizeC
    aResZones{1,i+1} = aNames{i};
    aNumberOfSpots{i+1,2} = int2str(sum(aZones(:,i+1)));
end

for i=1:zonesSize
    for j=1:sizeC+1
        aResZones{i+1,j} = aZones(i,j);
    end
end

xlswrite(fichier, aResZones);

close(vProgressDisplay);

% display(sum(aZones(1:vmax+1,dapi+1)));
% display(sum(aZones(1:vmax+1,gray+1)));
% I = aZones(:,gray+1) == 0;
% display(aZones(I,:));
display(aNumberOfSpots);

aType = Imaris.tType.eTypeUInt8;
vDataSet.SetType(aType);
%vImarisApplication.SetDataSet(aDataSet);

end