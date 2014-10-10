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
%          <Item name="Export the stats of the FISH model" icon="Matlab" tooltip="Export the stats of the FISH model">
%            <Command>MatlabXT::XTFISH_Export_Stats(%i)</Command>
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
function XTFISH_Export_Stats(aImarisApplicationID) % ID corresponds to Imaris instance

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

    
%% User interface
aDataSet = vImarisApplication.GetDataSet();
sizeC = aDataSet.GetSizeC;

% Image Name
aParameterSection='Image';
aParameterName='Name';
aDataName = aDataSet.GetParameter(aParameterSection,aParameterName);
if isempty(aDataName)
    aDataName = 'res';
end

% We have the user choose a name for the results file
name='Filename';
numlines=1;
prompt{1}='Results file name ? (in C:\Users\Public\Documents\FISH)';
defaultanswer{1}=char(aDataName);

answer = inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
file = ['C:\Users\Public\Documents\FISH\', answer{1}, '.csv'];

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

        fid = fopen(file,'w');
  
        for j=1:nspots
            % Get the stats
            stats = aSpots(j).GetStatistics;
            aNames = cell(stats.mNames);
            aUnits = cell(stats.mUnits);
            aUnit = char(aUnits(find(ismember(aNames, 'Position X')==1, 1)));
%             aUnit = char(aUnits(find(ismember(aNames, 'Distance from nucleus center to border')==1, 1)));
            aFactornames = cell(stats.mFactorNames);
            aFactors = transpose(cell(stats.mFactors));
            values = stats.mValues;
            ids = stats.mIds;
            ch = strcmp(aFactornames,'Channel');
            I = strcmp(aNames,'Intensity Center') & strcmp(aFactors(:,ch),num2str(sizeC));
            intensities = values(I);
            corrids = ids(I);
            
            % Store the values
            results = cell(size(corrids,1)+1,6);
            results{1,1} = 'IDs';
            results{1,2} = 'Nucleus ID';
            results{1,3} = 'Distance from nucleus centroid to border';
            results{1,4} = 'Distance from spot to nucleus centroid';
            results{1,5} = 'Ratio';
            results{1,6} = 'Unit';
            ns = 2;
            
            for i=1:n
                SpotsInNucleus = ismember(ids,corrids(intensities == i));
                DNB = ismember(aNames,'Distance from nucleus centroid to border');
                DSN = ismember(aNames,'Distance from spot to nucleus centroid');
                SpotsIDs = ids(SpotsInNucleus & DNB);
                dn = values(SpotsInNucleus & DNB);
                ds = values(SpotsInNucleus & DSN);
                nbs = size(SpotsIDs,1);
                
                if(nbs > 0)
                    results(ns:ns+nbs-1,1) = num2cell(SpotsIDs);
                    results(ns:ns+nbs-1,2) = num2cell(repmat(i,nbs,1));
                    results(ns:ns+nbs-1,3) = num2cell(dn);
                    results(ns:ns+nbs-1,4) = num2cell(ds);
                    results(ns:ns+nbs-1,5) = num2cell(ds ./ dn);
                    results(ns:ns+nbs-1,6) = {aUnit};
                    ns = ns+nbs;
                end
            end
            
            fprintf(fid,char(aSpots(j).GetName));
            fprintf(fid,'\n');
            fprintf(fid,'%s;%s;%s;%s;%s;%s\n',results{1,:});
            for row=2:size(results,1)
                fprintf(fid,'%d;%d;%f;%f;%f;%s\n',results{row,:});
            end
            fprintf(fid,'\n');
            
            %xlswrite('C:\Users\Public\Documents\FISH\tata.xls',results,char(aSpots(j).GetName));
            %xlswrite(file,results,char(aSpots(j).GetName));
        end
            
        fclose(fid);
        
    end
end

end