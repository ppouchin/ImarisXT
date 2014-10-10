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
%        	<Item name="Mouse : intensity stats (Sylvain)" icon="Matlab" tooltip="Export the intensities to an excel file.">
%          		<Command>MatlabXT::XT_Mouse_Cells_Stats(%i)</Command>
%        	</Item>
%        </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%        <Item name="Mouse : intensity stats (Sylvain)" icon="Matlab" tooltip="Export the intensities to an excel file.">
%          <Command>MatlabXT::XT_Mouse_Cells_Stats(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Computes the volumes corresponding to the cells..
% 

function XT_Mouse_Cells_Stats(aImarisApplicationID)

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

%% Get Surpass Surfaces Object
vImarisObject = vImarisApplication.GetSurpassSelection;            
% Check if there is a selection
if isempty(vImarisObject)
    msgbox('A surfaces object must be selected');
    return;
end

% Check if the selection is a surfaces object
if vImarisApplication.GetFactory.IsSpots(vImarisObject)
    vImarisObject = vImarisApplication.GetFactory.ToSpots(vImarisObject);
else
    if vImarisApplication.GetFactory.IsSurfaces(vImarisObject)
        vImarisObject = vImarisApplication.GetFactory.ToSurfaces(vImarisObject);
    else
        msgbox('Your selection is not a valid "surfaces" object');
        return;
    end
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
prompt{1}='Results file name ? (in C:\Users\Public\Documents\Mouse)';
defaultanswer{1}=char(aDataName);

answer = inputdlg(prompt,name,numlines,defaultanswer);
if isempty(answer)
    return;
end
file = ['C:\Users\Public\Documents\Mouse', answer{1}, '.xls'];

%% Export stats
vStatisticValues = vImarisObject.GetStatistics;
aNames = cell(vStatisticValues.mNames);
aFactorNames = cell(vStatisticValues.mFactorNames);
aFactors = cell(vStatisticValues.mFactors);
aValues = vStatisticValues.mValues;
aIds = uint32(vStatisticValues.mIds);

chFactorIndex = find(ismember(aFactorNames,'Channel') == 1);
valueChannel = ones(size(aValues));

for i=1:size(aFactors,2)
    valueChannel(i) = str2double(aFactors(chFactorIndex,i));
end

nstats = 5;
stat = cell(1,nstats);
stat{1} = 'Intensity Mean';
stat{2} = 'Intensity StdDev';
stat{3} = 'Intensity Min';
stat{4} = 'Intensity Median';
stat{5} = 'Intensity Max';

alphabet = {'A' 'B' 'C' 'D' 'E' 'F' 'G' 'H' 'I' 'J' 'K' 'L' 'M' 'N' 'O' 'P' 'Q' 'R' 'S' 'T' 'U' 'V' 'W' 'X' 'Y' 'Z'};

name = cell(1,sizeC+1);
name{sizeC+1} = 'Ids';

for i=1:nstats
    crit1 = ismember(aNames, stat{i});
    for j=1:sizeC
        crit2 = valueChannel == j;
        name{j} = ['Channel ' num2str(j)];
        xlswrite(file, aValues(crit1 & crit2), stat{i}, [alphabet{j} num2str(2)]);
    end
    
    xlswrite(file, name, stat{i});
    
    % Lazy way to put Ids : might give wrong results.
    xlswrite(file, aIds(crit1 & crit2), stat{i}, [alphabet{sizeC+1} num2str(2)]);
end

end