%
%
%  Mouse Cells Volumes Function for Imaris 7.3.1 (and Sylvain)
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
%        	<Item name="Mouse : Cell volumes (Sylvain)" icon="Matlab" tooltip="Computes the volumes corresponding to the cells.">
%          		<Command>MatlabXT::XT_Mouse_Cells_Volumes(%i)</Command>
%        	</Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
% 
%
%  Description:
%   
%   Computes the volumes corresponding to the cells..
% 

function XT_Mouse_Cells_Volumes(aImarisApplicationID)

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

%% User interface
aDataSet = vImarisApplication.GetDataSet();
aSurpassScene = vImarisApplication.GetSurpassScene();
sizeC = aDataSet.GetSizeC;

% Spacing
sizeX = aDataSet.GetSizeX;
sizeY = aDataSet.GetSizeY;
extendMinX = aDataSet.GetExtendMinX;
extendMinY = aDataSet.GetExtendMinY;
extendMaxX = aDataSet.GetExtendMaxX;
extendMaxY = aDataSet.GetExtendMaxY;
spacingX = (extendMaxX - extendMinX) / sizeX;
spacingY = (extendMaxY - extendMinY) / sizeY;
% sizeZ = aDataSet.GetSizeZ;
% extendMinZ = aDataSet.GetExtendMinZ;
% extendMaxZ = aDataSet.GetExtendMaxZ;
% spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

% Filter size
aSize = [5 5 5];

% We have the user input information
name='Parameters';
numlines=1;
prompt{1}='DAPI channel number ?';
prompt{2}='Z shift DAPI ?';
prompt{3}='Objects size ? (µm)';
defaultanswer{1}=num2str(sizeC);
defaultanswer{2}=num2str(0);
defaultanswer{3}=num2str(6.5);

answer = inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
dapi=floor(str2double(answer{1})-1);
shift=floor(str2double(answer{2}));
objectsSize=floor(str2double(answer{3})-1);

%% Processing
% Shift
vImarisApplication.GetImageProcessing.Shift3DChannel(aDataSet,dapi,0,0,shift);
% Median filter
vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,dapi,aSize);
% Segmentation
%aSurfaces = vImarisApplication.GetImageProcessing.DetectSurfacesRegionGrowing(aDataSet,[],dapi,spacingX+spacingY,0,1,0.0,objectsSize,1,'"Quality" above 0','"Volume" above 20.000 um^3');
aSurfaces = vImarisApplication.GetImageProcessing.DetectSpots2(aDataSet,[],dapi,objectsSize,0,'"Quality" above automatic threshold');
aSurpassScene.AddChild(aSurfaces,-1);

end