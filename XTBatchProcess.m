%
%
%  Batch Process Function for Imaris 7.3.0
%
%  Copyright Bitplane AG 2011
%
%
%  Installation:
%
%  - Copy this file into the folder containing the XTensions you want to use
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%        <Item name="Batch Process" icon="Matlab" tooltip="Automatically process images with a custom script">
%          <Command>MatlabXT::XTBatchProcess(%i)</Command>
%        </Item>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%
%   This XTension batch processes images.
%
%

function XTBatchProcess(aImarisApplicationID)

%Get script directory
scriptname = mfilename;
scriptfullname = mfilename('fullpath');
idx = strfind(scriptfullname, scriptname);
scriptpath = scriptfullname(1:idx(size(idx,2))-1);

%Get .m files (provided functions names equal filenames)
matlabfiles = what(scriptpath);
[junk,mfiles] = cellfun(@fileparts,matlabfiles.m,'UniformOutput',0); %#ok
clear junk;

%Get the current function name
[junk,curfun] = fileparts(scriptname); %#ok
clear junk;

%Remove it from the functions list
curfunidx = ismember(mfiles,curfun);
mfiles(curfunidx) = [];

%Get the images folder
folder = uigetdir;
files = [folder '\*.ims'];
listing = dir(files);
nfiles = size(listing,1);

%Choose the image processing
[selection,ok] = listdlg('PromptString','Select a function:',...
                         'SelectionMode','single',...
                         'ListString',mfiles);

if(ok == 1)
    %Define function name
    funcname = mfiles{selection};
    funstr = funcname;
    fun = str2func(funstr);
    
    %Get the Imaris application
    if isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
        vImarisApplication = aImarisApplicationID;
    else
        % Connect to Imaris interface
        javaaddpath ImarisLib.jar
        vImarisLib = ImarisLib;
        if ischar(aImarisApplicationID)
            aImarisApplicationID = round(str2double(aImarisApplicationID));
        end
        vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
    end

    %Process the files
    for i=1:nfiles
        filename = [folder '\' listing(i).name];
        vImarisApplication.FileOpen(filename, '');
        vImarisApplication.GetSurpassCamera().SetOrientationAxisAngle([0,0,1],0);
        vImarisApplication.GetSurpassCamera().Fit();

        %Process one image
        try
%             fun(aImarisApplicationID);
            fun(vImarisApplication);
        catch err
            fprintf('Function: %s\n', err.name);
            fprintf('Line: %s\n', err.line);
            fprintf('Message: %s\n', err.message);
        end
    end
end

end