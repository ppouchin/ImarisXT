% XTExport_stats for Imaris 7.6.4
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%        <Item name="Export statistics" icon="Matlab" tooltip="Export statistics to file">
%          <Command>MatlabXT::XTExport_stats(%i)</Command>
%        </Item>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension exports selected stats to a text file.
%
%
function XTExport_stats(aImarisApplicationID) % ID corresponds to Imaris instance

%% Working variables
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

% DataSet
aDataSet = vImarisApplication.GetDataSet;

% Name
aParameterSection='Image';
aParameterName='Name';
aDataName = cell(aDataSet.GetParameter(aParameterSection,aParameterName));
if isempty(aDataName)
    aDataName = 'res';
end

% Data access
aSurpassScene = vImarisApplication.GetSurpassScene;
nb_objects = aSurpassScene.GetNumberOfChildren;
surfaces = zeros(nb_objects,1);
spots = zeros(nb_objects,1);

for i=0:nb_objects-1
    if(vImarisApplication.GetFactory.IsSurfaces(aSurpassScene.GetChild(i)))
        surfaces(i+1) = 1;
    else
        if(vImarisApplication.GetFactory.IsSpots(aSurpassScene.GetChild(i)))
            spots(i+1) = 1;
        end
    end
end


%% UI: type of object
qstring = 'For which type of object do you need stats?';
choice = questdlg(qstring,'Object type','Spot','Surface','Track','Surface');

if strcmpi('track',choice)==1
    spotsorsurfaces = spots | surfaces;
    objidx = find(spotsorsurfaces==1)-1;
    nobj = size(objidx,1);
else
    if strcmpi('spot',choice)==1
        objidx = find(spots==1)-1;
        nobj = size(objidx,1);
    else
        objidx = find(surfaces==1)-1;
        nobj = size(objidx,1);
    end
end

%% Continue if requested objects exist
if nobj > 0
    %% Populate objects and get stats names
    aObjects = javaArray('Imaris.IDataItemPrxHelper', nobj);
    aNames = cell(0);
    for i=1:nobj
        aObjects(i) = aSurpassScene.GetChild(objidx(i));
    
        % Get the stats
        stats = aObjects(i).GetStatistics;
        tempNames = cell(stats.mNames);
        aFactornames = cell(stats.mFactorNames);
        aFactors = transpose(cell(stats.mFactors));
        objtype = strcmp(aFactornames,'Category');
        ch = strcmp(aFactornames,'Channel');
        I = ~cellfun('isempty',aFactors(:,ch));
        tempNames(I) = strcat(tempNames(I), {' Ch='}, aFactors(I,ch));
        filter = strcmp(aFactors(:,objtype),choice);
        tempNames = tempNames(filter);
        aNames = [aNames; tempNames];
    end
    uniqueNames = unique(aNames);
    
    namesAndChannels = cell(numel(uniqueNames),2);
    substrindices = zeros(numel(uniqueNames),4);
    getsubstr = @(x,s,e) x(s:e);
    indices = strfind(uniqueNames,' Ch=');
    I = ~cellfun(@isempty,indices);
    J = ~I;
    namesAndChannels(J,1) = uniqueNames(J);
    namesAndChannels(J,2) = {''};
    substrindices(I,1) = 1;
    substrindices(I,2) = transpose([indices{I}] - 1);
    substrindices(I,3) = transpose([indices{I}] + 4);
    substrindices(I,4) = cellfun(@(x) size(x,2),uniqueNames(I));
    substrindices = num2cell(substrindices);
    namesAndChannels(I,1) =  cellfun(getsubstr,uniqueNames(I),substrindices(I,1),substrindices(I,2),'UniformOutput',false);
    namesAndChannels(I,2) =  cellfun(getsubstr,uniqueNames(I),substrindices(I,3),substrindices(I,4),'UniformOutput',false);
    
    %% UI: stats selection
    [selection,ok] = listdlg('PromptString','Select the stats to export:',...
                             'SelectionMode','multiple',...
                             'ListString',uniqueNames);
	
    nselection = numel(selection);
    if nselection == 0
        return;
    end
    selectedNames = namesAndChannels(selection,1);
    selectedChannels = namesAndChannels(selection,2);
    
    % Cell to store results
    results = cell(nobj+1,2*nselection+3);
    results{1,1} = 'Object';
    results{1,2} = 'Id';
    results{1,3} = 'Track Id';
    results(1,4:2:2*nselection+2) = transpose(uniqueNames(selection));
    results(1,5:2:2*nselection+3) = {'Unit'};

	if(ok == 1)
        %% UI: file name
        % Get the images folder
        startpath = getenv('USERPROFILE');
        startpath = [startpath '\Documents'];
        folder = uigetdir(startpath);

        % We have the user choose a name for the results file
        name='Filename';
        numlines=1;
        prompt='Results file name ?';
        defaultanswer=aDataName;

        answer = inputdlg(prompt,name,numlines,defaultanswer);
        if isempty(answer)
            return;
        end
        file = [folder, '\', answer{1}, '.txt'];
        
        %% Get the stats
        for i=1:nobj
            
            % Convert to appropriate type
            if vImarisApplication.GetFactory.IsSpots(aObjects(i))
                obj = vImarisApplication.GetFactory.ToSpots(aObjects(i));
            else
                if vImarisApplication.GetFactory.IsSurfaces(aObjects(i))
                    obj = vImarisApplication.GetFactory.ToSurfaces(aObjects(i));
                end
            end
            
            % Get the stats
            stats = obj.GetStatistics;
            aNames = cell(stats.mNames);
            aUnits = cell(stats.mUnits);
            aFactornames = cell(stats.mFactorNames);
            aFactors = transpose(cell(stats.mFactors));
            values = stats.mValues;
            ids = stats.mIds;
            ch = strcmp(aFactornames,'Channel');
            objtype = strcmp(aFactornames,'Category');
            results{i+1,1} = char(obj.GetName);
    
            % Time dependent stats
            if strcmp(class(ids),'int64')
                myint = @int64;
            else
                myint = @int32;
            end
            trackids = myint(obj.GetTrackIds);
            trackedges = obj.GetTrackEdges;
            tracks = [trackids trackedges];
            tracks_ids = [tracks(:,2:-1:1); tracks(:,3:-2:1)];
            parents = unique(tracks_ids,'rows');
            
            for j=1:nselection;
                if isempty(selectedChannels{j})
                    I = strcmp(aNames,selectedNames{j}) & strcmp(aFactors(:,objtype),choice);
                else
                    I = strcmp(aNames,selectedNames{j}) ...
                    & strcmp(aFactors(:,objtype),choice) ...
                    & strcmp(aFactors(:,ch),selectedChannels{j});
                end
                
                if strcmp(choice,'Track') ~= 1
                    ids_without_parents = setdiff(ids(I),parents(:,1));
                    missing_ids = [ids_without_parents zeros(length(ids_without_parents),1)];
                    all_parents = vertcat(missing_ids, parents);
                    A = all_parents(:,1);
                    B = ids(I);
                    [sortedA,indA] = sort(A,1);
                    [sortedB,indB] = sort(B,1);
                    [sortedindA,indindA] = sort(indA,1);
                    sorted_parents = all_parents(indB(indindA),2);
                else
                    sorted_parents = ids(I);
                end
                
                if isempty(results{i+1,2})
                    results{i+1,2} = ids(I);
                end
                
                if isempty(results{i+1,3})
                    results{i+1,3} = sorted_parents;
                end
                
                if ids(I) ~= results{i+1,2}
                    A = results{i+1,2};
                    B = ids(I);
                    val = values(I);
                    units = aUnits(I);
                    [sortedA,indA] = sort(A,1);
                    [sortedB,indB] = sort(B,1);
                    [sortedindA,indindA] = sort(indA,1);
                    
                    results{i+1,2*j+2} = val(indB(indindA));
                    results{i+1,2*j+3} = units(indB(indindA));
                else
                    results{i+1,2*j+2} = values(I);
                    results{i+1,2*j+3} = aUnits(I);
                end
            end
        end
        
        %% Convert to pure cell array
        nbrows = 1;
        for i=1:nobj
            ids = results{i+1,2};
            nbrows = nbrows + size(ids,1);
        end
        endresults = cell(nbrows,2*nselection+3);
        
        endresults(1,:) = results(1,:);
        row = 1;
        for i=1:nobj
            name = results{i+1,1};
            ids = results{i+1,2};
            parents = results{i+1,3};
            increment = size(ids,1);
            for k=1:increment
                endresults{row+k,1} = name;
                endresults{row+k,2} = ids(k);
                endresults{row+k,3} = parents(k);
            end
            for j=1:nselection
                val = results{i+1,2*j+2};
                units = results{i+1,2*j+3};
                for k=1:increment
                    endresults{row+k,2*j+2} = double(val(k));
                    endresults{row+k,2*j+3} = units{k};
                end
            end
            row = row + increment;
        end
        clear results;
        
        %% Write file
        fid = fopen(file,'w');
        
        if fid ~= -1
            fprintf(fid,'"%s"\t"%s"\t"%s"',endresults{1,1:3});
            for j=1:nselection
                fprintf(fid,'\t"%s"\t"%s"',endresults{1,2*j+2:2*j+3});
            end
            fprintf(fid,'\n');

            for i=2:nbrows
                fprintf(fid,'"%s"\t%d\t%d',endresults{i,1:3});
                for j=1:nselection
                    fprintf(fid,'\t%f\t"%s"',endresults{i,2*j+2:2*j+3});
                end
                fprintf(fid,'\n');
            end
            fclose(fid);
        end
	end
end

end