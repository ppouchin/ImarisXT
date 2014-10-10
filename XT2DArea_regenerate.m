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
%        <Submenu name="Drosophila">
%          <Item name="Regenerate the area of 2D surfaces" icon="Matlab" tooltip="Regenerate the 2D area of ovary cells">
%            <Command>MatlabXT::XT2DArea_regenerate(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension regenerates the area of 2D ovary cells.
%
%
function XT2DArea_regenerate(aImarisApplicationID) % ID corresponds to Imaris instance

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

%% Add statistics (2D Area)
precision = 10e3;
for i=0:nb_surfaces-1
    % Get object name
    tempname = char(aSurpassScene.GetChild(i).GetName);
    
    % We only process surfaces of interest
    surfacesOfInterest = {'Surfaces'; 'Green'; 'NotGreen'; 'MagentaNotGreen'; 'MagentaGreen'; };
    if ismember(tempname, surfacesOfInterest) == 1
        % Get Surface object
        aSurface = vImarisApplication.GetFactory.ToSurfaces(aSurpassScene.GetChild(i));
        
        % Get stats
        stats = aSurface.GetStatistics;
        aNames = cell(stats.mNames);
        aUnits = cell(stats.mUnits);
        aFactornames = cell(stats.mFactorNames);
        aUnit = char(aUnits(find(ismember(aNames, 'Area')==1, 1)));
        aName = '2D Area';
        adName = '2D Growth';
        ad2Name = '2D Growth Speed';

        % Compute 2D area
        n = aSurface.GetNumberOfSurfaces;
        areas = zeros(n,1);
        dareas = zeros(n,1);
        d2areas = zeros(n,1);
        ids = zeros(n,1);
        names = cell(n,1);
        dnames = cell(n,1);
        d2names = cell(n,1);
        units = cell(n,1);
        factors = cell(4,n);
        
        % For each object
        for j=0:n-1
            % Find vertices in Z=0 plane (or close enough)
            vertices = aSurface.GetVertices(j);
            I = find(round(precision*vertices(:,3))==round(precision*(extendMinZ+spacingZ/2)));
            
            % Find edges between vertices in Z=0 plane
            triangles = aSurface.GetTriangles(j) + 1;
            J = sum(ismember(triangles,I)~=0,2) == 2;
            edges = triangles(J,:);
            edges = unique(sort(edges .* int32(ismember(edges,I)),2),'rows');
            edges = edges(:,2:3);
            
            % Sort 2D vertices
            V = zeros(size(edges,1),1);
            row = 1;
            count = 1;
            elt = 1;
            
            while count <= size(V,1)
                V(count) = elt;
                [rows, cols] = find(edges == elt);
                if rows(2) == row
                    row = rows(1);
                    col = cols(1);
                else
                    row = rows(2);
                    col = cols(2);
                end
                elt = edges(row,3-col);
                count = count + 1;
            end;
            x=vertices(V,1);
            y=vertices(V,2);

%             % Sort 2D vertices
%             x=vertices(I,1);
%             y=vertices(I,2);
%             cx = mean(x);
%             cy = mean(y);
%             a = atan2(y - cy, x - cx);
%             [~, order] = sort(a);
%             x = x(order);
%             y = y(order);

            % Compute 2D area
            areas(j+1) = polyarea(x,y);
            ids(j+1) = j;
            names(j+1) = {aName};
            dnames(j+1) = {adName};
            d2names(j+1) = {ad2Name};
            units(j+1) = {aUnit};
            factors(:,j+1) = {'Surface';'';'';num2str(aSurface.GetTimeIndex(j)+1)};
        end
        
        trackids = int32(aSurface.GetTrackIds);
        trackedges = aSurface.GetTrackEdges;
        tracks = [trackids trackedges+1];
        tids = unique(tracks(:,1));
        ntracks = size(tids,1);
        
        for t=1:ntracks
            tid = tids(t,1);
            track = tracks(tracks(:,1) == tid,:);
            nt = size(track,1);
            
            dareas(track(1,2)) = areas(track(1,3)) - areas(track(1,2));
            for tp=1:nt-1
                %if(track(tp,3) == track(tp+1,2))
                    dareas(track(tp,3)) = (areas(track(tp,3)) - areas(track(tp,2)));% / 2;
                %else
                %    dareas(track(tp,3)) = NaN;
                %end
            end
            dareas(track(nt,3)) = areas(track(nt,3)) - areas(track(nt,2));
        end
        
        for t=1:ntracks
            tid = tids(t,1);
            track = tracks(tracks(:,1) == tid,:);
            nt = size(track,1);
            
            d2areas(track(1,2)) = dareas(track(1,3)) - dareas(track(1,2));
            for tp=1:nt-1
                if(track(tp,3) == track(tp+1,2))
                    d2areas(track(tp,3)) = (dareas(track(tp+1,3)) - dareas(track(tp,2))) / 2;
                else
                    d2areas(track(tp,3)) = NaN;
                end
            end
            d2areas(track(nt,3)) = dareas(track(nt,3)) - dareas(track(nt,2));
        end
        

        % Add statistics
        aSurface.AddStatistics(names,areas,units,factors,aFactornames,ids);
        aSurface.AddStatistics(dnames,dareas,units,factors,aFactornames,ids);
        aSurface.AddStatistics(d2names,d2areas,units,factors,aFactornames,ids);
    end
end

end