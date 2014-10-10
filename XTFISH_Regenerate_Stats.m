% XT2DArea_regenerate for Imaris 7.6.4
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
%          <Item name="Regenerate the stats of the FISH model" icon="Matlab" tooltip="Regenerate the stats of the FISH model">
%            <Command>MatlabXT::XTFISH_Regenerate_Stats(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension regenerates the area of 2D ovary cells.
%   It requires intersect_line.m and normals.m from FieldTrip project
%   https://code.google.com/p/fieldtrip/
%
function XTFISH_Regenerate_Stats(aImarisApplicationID) % ID corresponds to Imaris instance

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
sizeC = aDataSet.GetSizeC;

%% Data access
aSurpassScene = vImarisApplication.GetSurpassScene;
nb_objects = aSurpassScene.GetNumberOfChildren;
surfaces = zeros(nb_objects,1);
spots = zeros(nb_objects,1);
nucleus = -1;

for i=0:nb_objects-1
    if(vImarisApplication.GetFactory.IsSurfaces(aSurpassScene.GetChild(i)))
        surfaces(i+1) = 1;
    else
        if(vImarisApplication.GetFactory.IsSpots(aSurpassScene.GetChild(i)))
            spots(i+1) = 1;
        end
    end
end

surfidx = find(surfaces==1)-1;
spotsidx = find(spots==1)-1;

for i=1:size(surfidx)
    if(strcmp(char(aSurpassScene.GetChild(surfidx(i)).GetName),'Nucleus')==1)
        nucleus = surfidx(i);
    end
end

%% Generate stats if nucleus was detected
if nucleus >= 0
    aNucleus = vImarisApplication.GetFactory.ToSurfaces(aSurpassScene.GetChild(nucleus));
    n = aNucleus.GetNumberOfSurfaces;
    nspots = size(spotsidx,1);
    
    if nspots > 0
        aSpots = javaArray('Imaris.ISpotsPrxHelper', nspots);
        for i=1:size(spotsidx)
            aSpots(i) = vImarisApplication.GetFactory.ToSpots(aSurpassScene.GetChild(spotsidx(i)));
        end
        
        for i=1:n
            CMN = aNucleus.GetCenterOfMass(i-1);
            vertices = aNucleus.GetVertices(i-1);
            triangles = aNucleus.GetTriangles(i-1);
            faces = triangles + 1; % Index correction for Matlab

            for j=1:nspots
                positions = aSpots(j).GetPositionsXYZ;
                stats = aSpots(j).GetStatistics;
                aNames = cell(stats.mNames);
                aUnits = cell(stats.mUnits);
                aUnit = char(aUnits(find(ismember(aNames, 'Position')==1, 1)));
                aFactornames = cell(stats.mFactorNames);
                aFactors = transpose(cell(stats.mFactors));
                values = stats.mValues;
                ids = stats.mIds;
                ch = strcmp(aFactornames,'Channel');
                I = strcmp(aNames,'Intensity Center') & strcmp(aFactors(:,ch),num2str(sizeC));
                intensities = values(I);
                corrids = ids(I);
                spotcenters = positions(corrids(intensities == i)+1,:);

                % Compute border distance from nucleus center (in spot direction)
                ns = size(spotcenters,1);
                
                if ns > 0
                    ids = corrids(intensities == i);
                    dn = zeros(ns,1);
                    ds = zeros(ns,1);
                    names_dn = cell(1,ns);
                    names_ds = cell(1,ns);
                    units = cell(1,ns);
                    factors = cell(4,ns);
                    [names_dn{1:ns}] = deal('Distance from nucleus centroid to border');
                    [names_ds{1:ns}] = deal('Distance from spot to nucleus centroid');
                    [units{1:ns}] = deal(aUnit);
                    [factors{1,1:ns}] = deal('Spot');
                    [factors{2,1:ns}] = deal('');
                    [factors{3,1:ns}] = deal('');
                    [factors{4,1:ns}] = deal('');

                    % For each spot in the selected nucleus
                    for k=1:ns;
                        % Intersections computation
                        CMS = spotcenters(k,:);
                        [inters pos] = intersect_line(vertices, faces, CMS, CMN);

                        % Closest intersection on the outer layer of the nucleus
                        [~, idx] = min(abs(pos(pos<0)));
                        points = inters(pos<0,:);
                        point = points(idx,:);

                        % Distances computation
                        dn(k) = norm(point - CMN);
                        ds(k) = norm(CMS - CMN);
                    end

                    % Save statistics
                    aSpots(j).AddStatistics(names_dn,dn,units,factors,aFactornames,ids);
                    aSpots(j).AddStatistics(names_ds,ds,units,factors,aFactornames,ids);
                end
            end
        end
        
    end
end

end