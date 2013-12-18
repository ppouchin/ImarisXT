% XT3DCells_distance for Imaris 7.6.4
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
%          <Item name="Regenerate the distance between 3D cells" icon="Matlab" tooltip="Regenerate the distance between 3D cells">
%            <Command>MatlabXT::XT3DCells_distance(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension regenerates the distance between 3D cells.
%
%
function XT3DCells_distance(aImarisApplicationID) % ID corresponds to Imaris instance

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

%DataSet
aDataSet = vImarisApplication.GetDataSet;

% Size variables
sizeZ = aDataSet.GetSizeZ;
extendMinZ = aDataSet.GetExtendMinZ;
extendMaxZ = aDataSet.GetExtendMaxZ;
spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

%% Data access
aSurpassScene = vImarisApplication.GetSurpassScene;
nb_surfaces = aSurpassScene.GetNumberOfChildren;

%% Add statistics (Distance from center)
for i=0:nb_surfaces-1
    % Get object name
    tempname = char(aSurpassScene.GetChild(i).GetName);
    
    % We only process surfaces of interest
    surfacesOfInterest = {'Cells';};
    if ismember(tempname, surfacesOfInterest) == 1
        % Get Surface object
        aSurface = vImarisApplication.GetFactory.ToSurfaces(aSurpassScene.GetChild(i));
        
        % Get stats
        stats = aSurface.GetStatistics;
        aNames = cell(stats.mNames);
        aUnits = cell(stats.mUnits);
        aFactornames = cell(stats.mFactorNames);
        aUnit = char(aUnits(find(ismember(aNames, 'Position X')==1, 1)));
        aName = 'Distance from center';

        % Compute distance
        n = aSurface.GetNumberOfSurfaces;
        ids = zeros(n,1);
        names = cell(n,1);
        units = cell(n,1);
        factors = cell(4,n);
        
        % Get surfaces coordinates
        nsurf = aSurface.GetNumberOfSurfaces;
        pos = zeros(nsurf,3);
        for j=0:nsurf-1
            pos(j+1,:) = aSurface.GetCenterOfMass(j);
            ids(j+1) = j;
            names(j+1) = {aName};
            units(j+1) = {aUnit};
            factors(:,j+1) = {'Surface';'';'';num2str(aSurface.GetTimeIndex(j)+1)};
        end
        meanpos = mean(pos);
        vectors = bsxfun(@minus,pos,meanpos);
        distances = sqrt(sum(vectors .* vectors,2));

        % Add statistics
        aSurface.AddStatistics(names,distances,units,factors,aFactornames,ids);
    end
end

end