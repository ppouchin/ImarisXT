% ImarisXT2DSurfaces for Imaris 7.6.4
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
%          <Item name="Compute surface of ovary cells" icon="Matlab" tooltip="Compute the surface of 2D ovary cells">
%            <Command>MatlabXT::XT2DSurfaces_cells(%i)</Command>
%          </Item>
%        </Submenu>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension computes the surface of 2D ovary cells.
%
%
function XT2DSurfaces_cells(aImarisApplicationID) % ID corresponds to Imaris instance

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
prompt={'Enter the membranes (red) channel number:'};
prompt{2} = 'Enter the mutant marker (green) channel number (0 if no green):';
prompt{3} = 'Enter the DAPI (blue) channel number (0 if no blue):';
prompt{4} = 'Enter the magenta channel number (0 if no magenta):';
prompt{5} = 'Enter start slice:';
prompt{6} = 'Enter end slice:';
prompt{7} = 'Enter the approximate cell size: (diameter / µm)';
if sizeT > 1
    prompt{8} = 'Enter the maximum search distance (tracking)';
end
defaultanswer={num2str(rgbm(1))};
defaultanswer{2}=num2str(rgbm(2));
defaultanswer{3}=num2str(rgbm(3));
defaultanswer{4}=num2str(rgbm(4));
defaultanswer{5}='1';
defaultanswer{6}=num2str(sizeZ);
defaultanswer{7}='3';
defaultanswer{8}='3';

% We retrieve the answers
answer=inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
rgbm(1)=floor(str2double(answer{1})-1); % Red Channel
rgbm(2)=floor(str2double(answer{2})-1); % Green Channel
rgbm(3)=floor(str2double(answer{3})-1); % Blue Channel
rgbm(4)=floor(str2double(answer{4})-1); % Magenta Channel
zstart = max(0,floor(str2double(answer{5})-1));
zend = min(floor(str2double(answer{6})-1),sizeZ-1);
cellsSize = str2double(answer{7});

% We rectify incorrect answers
rgbm(rgbm < 0) = -1;
rgbm(rgbm >= sizeC) = -1;

% We prepare an "undo"
% vImarisApplication.DataSetPushUndo('XT: Cells Surfaces');

%% Objects filtering
% roi = vImarisApplication.GetImageProcessing.DetectSurfaces(vDataSet,[],rgbm(1),cellsSize/8,0,1,0,'"Number of Voxels" above automatic threshold');
% for t=0:sizeT-1
%     maskSurfaces = roi.GetMask(extendMinX,extendMinY,extendMinZ,extendMaxX,extendMaxX,extendMaxY,extendMaxZ,sizeX,sizeY,sizeZ,t);
%     mask = maskSurfaces.GetVolumeDataBytes(0,t);
% 
%     if vDataSet.GetType == Imaris.tType.eTypeUInt8
%         redCh = typecast(vDataSet.GetDataVolumeAs1DArrayBytes(rgbm(1),t), 'uint8');
%         redCh = reshape(redCh, [sizeX sizeY sizeZ]);
%         redCh = uint8(redCh .* mask);
%         vDataSet.GetDataVolumeAs1DArrayBytes(redCh, rgbm(1),t);
%     elseif vDataSet.GetType == Imaris.tType.eTypeUInt16
%         redCh = typecast(vDataSet.GetDataVolumeAs1DArrayShorts(rgbm(1),t), 'uint16');
%         redCh = reshape(redCh, [sizeX sizeY sizeZ]);
%         redCh = uint16(redCh .* mask);
%         vDataSet.GetDataVolumeAs1DArrayShorts(redCh, rgbm(1),t);
%     elseif vDataSet.GetType == Imaris.tType.eTypeFloat
%         redCh = vDataSet.GetDataVolumeAs1DArrayFloats(rgbm(1),t);
%         redCh = reshape(redCh, [sizeX sizeY sizeZ]);
%         redCh = redCh .* mask;
%         vDataSet.SetDataVolumeAs1DArrayFloats(redCh, rgbm(1),t);
%     end
%     clear mask;
%     clear redCh;
% end

%% Cropping
if sizeZ ~= zend - zstart + 1
    sizeZ = zend - zstart + 1;
    vDataSet.Crop(0,sizeX,0,sizeY,zstart,sizeZ,0,sizeC,0,sizeT);
end

%% 2D projection
if sizeZ ~= 1
    XT3Dto2DProjection(vImarisApplication, 1, 'MIP');
end

%% Working Dataset and Z size
aDataSet = vDataSet.Clone;
sizeZ = aDataSet.GetSizeZ;
extendMinZ = aDataSet.GetExtendMinZ;
extendMaxZ = aDataSet.GetExtendMaxZ;
spacingZ = (extendMaxZ - extendMinZ) / sizeZ;

extendMin = [extendMinX extendMinY extendMinZ];
spacing = [spacingX spacingY spacingZ];

%% Smoothing
aSize = [5 5 1];
vImarisApplication.GetImageProcessing.GaussFilterChannel(aDataSet,rgbm(1),0.3);
vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,rgbm(1),aSize);
if rgbm(2) >= 0
    vImarisApplication.GetImageProcessing.MedianFilterChannel(aDataSet,rgbm(2),aSize);
end

%% Thresholding (green)
if rgbm(2) >= 0
    aData1D = aDataSet.GetDataVolumeAs1DArrayShorts(rgbm(2),0);
    histo = histc(single(aData1D), 0:255);
    P = histo / sum(histo);
    P2 = P .* (1:256)';
    muT = ones(256,256) * sum(P2(1:256));
    omega0 = zeros(256, 256);
    omega1 = omega0;
    omega2 = omega0;
    mu0 = omega0;
    mu1 = omega0;
    mu2 = omega0;
    for i=1:255
        for j=i+1:256
            omega0(i,j) = sum(P(1:i));
            omega1(i,j) = sum(P(i+1:j));
            omega2(i,j) = sum(P(j+1:256));
            mu0(i,j) = sum(P2(1:i)) ./ omega0(i,j);
            mu1(i,j) = sum(P2(i+1:j)) ./ omega1(i,j);
            mu2(i,j) = sum(P2(j+1:256)) ./ omega2(i,j);
        end
    end
    sigma = omega0 .* (mu0 - muT).^2 + omega1 .* (mu1 - muT).^2 + omega2 .* (mu2 - muT).^2;
    %[~, thresh] = max(max(sigma));
    [Y, I] = max(sigma);
    [~, J] = max(Y);
%     thresh = I(J);
    thresh = max(I(J),40);
    vImarisApplication.GetImageProcessing.ThresholdChannel(aDataSet, rgbm(2), thresh, 0);
    vImarisApplication.GetImageProcessing.ThresholdUpperChannel(aDataSet, rgbm(2), thresh, 255);
end

%% Inverting
vImarisApplication.GetImageProcessing.InvertChannel(aDataSet,rgbm(1));


%% Segmentation
unit = aDataSet.GetUnit;
nb_surfaces = 1;
if rgbm(2) >= 0
    nb_surfaces = 2;
    if rgbm(4) >= 0
        nb_surfaces = nb_surfaces * 2;
    end
end

% Surfaces array
aSurface = javaArray('Imaris.ISurfacesPrxHelper', nb_surfaces);

% Surfaces names
surName = cell(nb_surfaces, 1);
surName{1} = 'Surfaces';

% Channel used to compute corresponding surface (red by default)
channelUsed = rgbm(1)*ones(nb_surfaces,1);

% Green Filter
greenFilter = cell(nb_surfaces,1);
if rgbm(2) >= 0 && rgbm(2) < sizeC
    greenFilter{1} = [' "Intensity Mean Ch=',num2str(rgbm(2)+1),'" below 128'];
    greenFilter{2} = [' "Intensity Mean Ch=',num2str(rgbm(2)+1),'" above 128'];
    greenFilter{nb_surfaces-1} = [' "Intensity Mean Ch=',num2str(rgbm(2)+1),'" below 128'];
    greenFilter{nb_surfaces}   = [' "Intensity Mean Ch=',num2str(rgbm(2)+1),'" above 128'];
    channelUsed(2) = rgbm(2);
    surName{1} = 'NotGreen';
    surName{2} = 'Green';
end

% DAPI Filter
blueFilter = '';
if rgbm(3) >= 0 && rgbm(3) < sizeC
    blueFilter = [' "Intensity Mean Ch=',num2str(rgbm(3)+1),'" above automatic threshold'];
end

% Magenta Filter
magentaFilter = cell(nb_surfaces,1);
if rgbm(4) >= 0 && rgbm(4) < sizeC
    magentaFilter{nb_surfaces/2+1} = [' "Intensity Mean Ch=',num2str(rgbm(4)+1),'" above 40'];
    magentaFilter{nb_surfaces}     = [' "Intensity Mean Ch=',num2str(rgbm(4)+1),'" above 40'];
    channelUsed(nb_surfaces/2+1) = rgbm(4);
    channelUsed(nb_surfaces)     = rgbm(4);
    surName{nb_surfaces}     = 'MagentaGreen';
    surName{nb_surfaces/2+1} = 'MagentaNotGreen';
end


for i=1:nb_surfaces
    % Compute Imaris Surfaces
    aSurface(i) = vImarisApplication.GetImageProcessing.DetectSurfacesRegionGrowing(aDataSet,[],rgbm(1),0.2,0,0,0,cellsSize,1,...
                                                                                    '"Quality" above 0', ...
                                                                                   ['"Number of Voxels" above 100'...
                                                                                    blueFilter, ...
                                                                                    greenFilter{i}, ...
                                                                                    magentaFilter{i}, ...
                                                                                    ' "Distance to Image Border XY" above ' num2str(cellsSize) ' ' char(unit)]);
    % Put object in the scene
    aRGBA=aDataSet.GetChannelColorRGBA(channelUsed(i));
    aSurface(i).SetColorRGBA(aRGBA);
    aSurface(i).SetName(surName{i});
    aSurpassScene.AddChild(aSurface(i),-1);
end

%% Re-Inverting
vImarisApplication.GetImageProcessing.InvertChannel(aDataSet,rgbm(1));

%% Tracking
if sizeT > 1
    max_distance = str2double(answer{8});
    %%%% Test %%%%
%     windowSize = [49 49 0];
%     hann = hannWindow(2*windowSize(1)+1,2*windowSize(2)+1,2*windowSize(3)+1);
    %%%% /Test %%%%
%     weight_contrast = 3;
    for i=1:nb_surfaces
        % Get the statistics
        stats = aSurface(i).GetStatistics;
        ids = stats.mIds;
        values = stats.mValues;
        names = cell(stats.mNames);
        
        % Prepare the results
        res = int32([]);
        
        % Store it more efficiently
        nIds = max(ids)+1;
        positions = zeros(nIds,3);
        timeindices = zeros(nIds,1);
        volumes = zeros(nIds,1);
%         contrast = zeros(nIds,1);
        
        tids = find(ismember(names, 'Time Index')==1);
        posx = find(ismember(names, 'Position X')==1);
        posy = find(ismember(names, 'Position Y')==1);
        posz = find(ismember(names, 'Position Z')==1);
        vol = find(ismember(names, 'Volume')==1);
%         std = find(ismember(names, ['Intensity StdDev Ch=' rgbm(1)])==1);
        
        timeindices(ids(tids)+1) = values(tids);
        positions(ids(posx)+1,1) = values(posx);
        positions(ids(posy)+1,2) = values(posy);
        positions(ids(posz)+1,3) = values(posz);
        volumes(ids(vol)+1) = values(vol);
%         contrast(ids(std)+1) = values(std);
        
        % We create a "cost" matrix for each timepoint
        nt = max(timeindices)-1;
        for j=1:nt
            % We create the matrix
            curt_ind = find(timeindices==j);
            next_ind = find(timeindices==j+1);
            ncurt = size(curt_ind,1);
            nnext = size(next_ind,1);
            cost = zeros(ncurt,nnext);
            
            % We compute the cost
            for curt=1:ncurt
                for next=1:nnext
                    % Distance between the objects
                    distance = norm(positions(curt_ind(curt),:) - positions(next_ind(next),:));
                    
                    % Cost (if distance > threshold : cost = infinite)
                    if distance > max_distance;
                        cost(curt,next) = inf;
                    else
                        % Statistical differences
                        diff_volume = norm(volumes(curt_ind(curt)) - volumes(next_ind(next)));
%                         diff_contrast = norm(contrast(curt_ind(curt)) - contrast(next_ind(next)));
                        cost(curt,next) = distance^2 + (diff_volume/2*spacingZ)^2; % + weight_contrast*diff_contrast;
                    end
                    
                    %%%% Correlation test %%%%
%                     if distance > max_distance;
%                         cost(curt,next) = inf;
%                     else
%                         % Get points coordinates
%                         curt_coord = aSurface(i).GetCenterOfMass(curt_ind(curt)-1);
%                         next_coord = aSurface(i).GetCenterOfMass(next_ind(next)-1);
% 
%                         % Convert it to image coordinates
%                         curt_coord = int32((curt_coord - extendMin - spacing/2) ./ spacing);
%                         next_coord = int32((next_coord - extendMin - spacing/2) ./ spacing);
% 
%                         % Create window
%                         patch_curt = double(aDataSet.GetDataSubVolumeShorts(curt_coord(1)-windowSize(1),curt_coord(2)-windowSize(2),curt_coord(3)-windowSize(3),rgbm(1),j-1,2*windowSize(1)+1,2*windowSize(2)+1,2*windowSize(3)+1));
%                         patch_next = double(aDataSet.GetDataSubVolumeShorts(next_coord(1)-windowSize(1),next_coord(2)-windowSize(2),next_coord(3)-windowSize(3),rgbm(1),j,2*windowSize(1)+1,2*windowSize(2)+1,2*windowSize(3)+1));
% 
%                         patch_curt = patch_curt .* hann;
%                         patch_next = patch_next .* hann;
% %                         correlation = mean(mean(ifftn(fftn(double(patch_next)) .* conj(fftn(double(patch_curt))))));
%                         covariance = cov(patch_curt,patch_next);
%                         correlation = covariance(1,2)/(covariance(1,1)*covariance(2,2));
%                         cost(curt,next) = 1/correlation;
%                     end
                    %%%% End of test %%%%
                end
            end
            
            % We find the minima
            minima = zeros(ncurt,nnext);
            newmin = ones(ncurt,nnext);
            minsize = min(ncurt,nnext);
            v = 0;
            while nnz(newmin) >= 1 && nnz(minima) <= minsize
                for curt=1:ncurt
                    for next=1:nnext
                        if(isfinite(min(cost(curt,:))))
                            newmin(curt,next) = min(cost(curt,:)) == min(cost(:,next));
                        else
                            newmin(curt,next) = 0;
                        end
                    end
                end
                minima = minima + newmin;
                [I, J] = ind2sub(size(minima),find(minima == 1));
                cost(:,J) = inf;
                cost(I,:) = inf;
                v = v+1;
            end
            
            % We store the results
            res = [res; curt_ind(I)-1 next_ind(J)-1]; %#ok
%             [~, intcat_msgid] = lastwarn;
%             warning('off', intcat_msgid);
        end
        aSurface(i).SetTrackEdges(res);
    end
end

%% Add statistics (2D Area)
XT2DArea_regenerate(aImarisApplicationID);

%% Save modifications (*.ims files only)
%filename = vImarisApplication.GetCurrentFileName;
%[~, ~, extension] = fileparts(filename);
%if strcmpi(extension,'ims')
%    vImarisApplication.Save(filename, '');
%end

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