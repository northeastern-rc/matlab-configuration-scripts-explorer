function [remoteConnection, mirrorConnection] = getRemoteConnection(cluster)
%GETREMOTECONNECTION Get a connected RemoteClusterAccess
%
% getRemoteConnection will either retrieve a RemoteClusterAccess from the
% cluster's UserData or it will create a new RemoteClusterAccess.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MW: Changes made to support custom remote/nonshared submission. Site uses a separate %
% ClusterHost and MirrorHost. ClusterHost cannot accept SFTP mirroring and MirrorHost  %
% cannot accept scheduler job commands.                                                %
% Assume the username and credentials are identical.                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Copyright 2010-2025 The MathWorks, Inc.

% Store the current filename for the dctSchedulerMessages
currFilename = mfilename;

clusterHost = validatedPropValue(cluster.AdditionalProperties, 'ClusterHost', 'char');
if isempty(clusterHost)
    error('parallelexamples:GenericSLURM:MissingAdditionalProperties', ...
        'Required field %s is missing from AdditionalProperties.', 'ClusterHost');
end

% MW: Separate ClusterHost and MirrorHost
if ~cluster.HasSharedFilesystem
    % Separate mirror host is required for file mirroring
    mirrorHost = validatedPropValue(cluster.AdditionalProperties, 'MirrorHost', 'char');
    if isempty(mirrorHost)
        error('parallelexamples:GenericSLURM:MissingAdditionalProperties', ...
            'Required field %s is missing from AdditionalProperties.', 'MirrorHost');
    end

    remoteJobStorageLocation = validatedPropValue(cluster.AdditionalProperties, ...
        'RemoteJobStorageLocation', 'char');
    if isempty(remoteJobStorageLocation)
        error('parallelexamples:GenericSLURM:MissingAdditionalProperties', ...
            'Required field %s is missing from AdditionalProperties.', 'RemoteJobStorageLocation');
    end
    
    useUniqueSubfolders = validatedPropValue(cluster.AdditionalProperties, ...
        'UseUniqueSubfolders', 'logical', false);
else
    mirrorHost = '';
end

needToCreateNewConnection = false;
if isempty(cluster.UserData)
    needToCreateNewConnection = true;
else
    if ~isstruct(cluster.UserData)
        error('parallelexamples:GenericSLURM:IncorrectUserData', ...
            ['Failed to retrieve remote connection from cluster''s UserData.\n' ...
            'Expected cluster''s UserData to be a structure, but found %s'], ...
            class(cluster.UserData));
    end
    
    % MW: Check RemoteConnection status (for SSH)
    if isfield(cluster.UserData, 'RemoteConnection')
        % Get the remote connection out of the cluster user data
        remoteConnection = cluster.UserData.RemoteConnection;
        
        % And check it is of the type that we expect
        if isempty(remoteConnection) || (isa(remoteConnection, "handle") && ~isvalid(remoteConnection))
            needToCreateNewConnection = true;
        else
            clusterAccessClassname = 'parallel.cluster.RemoteClusterAccess';
            if ~isa(remoteConnection, clusterAccessClassname)
                error('parallelexamples:GenericSLURM:IncorrectArguments', ...
                    ['Failed to retrieve remote connection from cluster''s UserData.\n' ...
                    'Expected the RemoteConnection field of the UserData to contain an object of type %s, but found %s.'], ...
                    clusterAccessClassname, class(remoteConnection));
            end
                
            if ~remoteConnection.IsConnected
                needToCreateNewConnection = true;
            elseif ~strcmpi(remoteConnection.Hostname, clusterHost)
                % The connection stored in the user data does not match the cluster host requested
                warning('parallelexamples:GenericSLURM:DifferentRemoteParameters', ...
                    ['The current cluster is already using cluster host %s.\n', ...
                    'The existing connection to %s will be replaced.'], ...
                    remoteConnection.Hostname, remoteConnection.Hostname);
                cluster.UserData.RemoteConnection = [];
                needToCreateNewConnection = true;
            end
        end
    else
        needToCreateNewConnection = true;
    end

    % MW: Check MirrorConnection status (for file mirroring).  Connection only needs to be made if cluster does not have a shared filesystem.
    % However, mirrorConnection variable still needs to be set in code as it's a function output.
    if ~cluster.HasSharedFilesystem    
        % If RemoteConnection status above requires a new connection, skip this section and just initiate a new connection. 
        if isfield(cluster.UserData, 'MirrorConnection') && ~needToCreateNewConnection
            % Get the mirror connection out of the cluster user data
            mirrorConnection = cluster.UserData.MirrorConnection;
            
            % And check it is of the type that we expect
            if isempty(mirrorConnection) || (isa(mirrorConnection, "handle") && ~isvalid(mirrorConnection))
                needToCreateNewConnection = true;
            else
                clusterAccessClassname = 'parallel.cluster.RemoteClusterAccess';
                if ~isa(mirrorConnection, clusterAccessClassname)
                    error('parallelexamples:GenericSLURM:IncorrectArguments', ...
                        ['Failed to retrieve remote connection from cluster''s UserData.\n' ...
                        'Expected the RemoteConnection field of the UserData to contain an object of type %s, but found %s.'], ...
                        clusterAccessClassname, class(mirrorConnection));
                end
                
                if ~cluster.HasSharedFilesystem
                    if useUniqueSubfolders
                        username = mirrorConnection.Username;
                        expectedRemoteJobStorageLocation = iBuildUniqueSubfolder(remoteJobStorageLocation, ...
                            username, iGetFileSeparator(cluster));
                    else
                        expectedRemoteJobStorageLocation = remoteJobStorageLocation;
                    end
                end
                
                if ~mirrorConnection.IsConnected
                    needToCreateNewConnection = true;
                elseif (~strcmpi(mirrorConnection.Hostname, mirrorHost) || ...
                        ~mirrorConnection.IsFileMirrorSupported || ...
                        ~strcmpi(mirrorConnection.JobStorageLocation, expectedRemoteJobStorageLocation))
                    % The connection stored in the user data does not match the mirror host
                    % and remote location requested
                    warning('parallelexamples:GenericSLURM:DifferentRemoteParameters', ...
                        ['The current cluster is already using mirror host %s and remote job storage location %s.\n', ...
                        'The existing connection to %s will be replaced.'], ...
                        mirrorConnection.Hostname, mirrorConnection.JobStorageLocation, mirrorConnection.Hostname);
                    cluster.UserData.MirrorConnection = [];
                    needToCreateNewConnection = true;
                end
            end
        else
            needToCreateNewConnection = true;
        end
    % MW: Cluster has a shared filesystem. mirrorConnection must be defined, but can be empty as it will not be used. 
    else
        mirrorConnection = '';
    end
end

if ~needToCreateNewConnection
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOMIZATION MAY BE REQUIRED %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get the credential options from the user using simple
% MATLAB dialogs or command line input.  You should change
% this section if you wish for users to provide their credential
% options in a different way.
% The pertinent options are:
% username - The username you use when you run commands on the remote host
% authMode - Authentication mode you use when you connect to the cluster.
%   Supported options are:
%   'Password' - Enter your SSH password when prompted by MATLAB.
%   'IdentityFile' - Use an identity file on disk.
%   'Agent' - Interface with an SSH agent running on the client machine.
%             Supported in R2021b onwards.
%   'Multifactor' - Enable the cluster to prompt you for input one or more
%                   times. If two-factor authentication (2FA) is enabled on
%                   the cluster, the cluster will request your password and
%                   a response for the second authentication factor.
%                   Supported in R2022a onwards.
% identityFile - Full path to the identity file.
% identityFileHasPassphrase - True if the identity file requires a passphrase
%                             (true/false).

% Use the UI for prompts if MATLAB has been started with the desktop enabled
useUI = iShouldUseUI();
username = iGetUsername(cluster, useUI);

% Decide which authentication mode to use
% Default mechanism is to prompt for password
authMode = 'Password';
if isprop(cluster.AdditionalProperties, 'AuthenticationMode')
    % If AdditionalProperties.AuthenticationMode is defined, use that
    authMode = cluster.AdditionalProperties.AuthenticationMode;
elseif isprop(cluster.AdditionalProperties, 'UseIdentityFile')
    % Otherwise use an identity file if UseIdentityFile is defined and true
    useIdentityFile = validatedPropValue(cluster.AdditionalProperties, 'UseIdentityFile', 'logical');
    if useIdentityFile
        authMode = 'IdentityFile';
    end
elseif isprop(cluster.AdditionalProperties, 'IdentityFile')
    % Otherwise use an identity file if IdentityFile is defined
    authMode = 'IdentityFile';
else
    % Otherwise nothing is specified, ask the user what to do
    authMode = iPromptUserForAuthenticationMode(cluster, useUI);
end

% Build the user arguments to pass to RemoteClusterAccess
userArgs = {username};
if verLessThan('matlab', '9.11') %#ok<*VERLESSMATLAB> We support back to 17a
    if ~ischar(authMode) || ~ismember(authMode, {'IdentityFile', 'Password'})
        % Prior to R2021b, only IdentityFile and Password are supported
        error('parallelexamples:GenericSLURM:IncorrectArguments', ...
            'AuthenticationMode must be either ''IdentityFile'' or ''Password''');
    end
else
    % No need to validate authMode, RemoteClusterAccess will do that for us
    userArgs = [userArgs, 'AuthenticationMode', {authMode}];
end

% If using identity file, also need the filename and whether a passphrase is needed
if any(strcmp(authMode, 'IdentityFile'))
    identityFile = iGetIdentityFile(cluster, useUI);
    identityFileHasPassphrase = iGetIdentityFileHasPassphrase(cluster, useUI);
    userArgs = [userArgs, 'IdentityFilename', {identityFile}, ...
        'IdentityFileHasPassphrase', identityFileHasPassphrase];
    cluster.AdditionalProperties.UseIdentityFile = true;
end

% Changing SSH port supported for R2021b onwards
if ~verLessThan('matlab', '9.11')
    sshPort = validatedPropValue(cluster.AdditionalProperties, 'SSHPort', 'double');
    if ~isempty(sshPort)
        userArgs = [userArgs, 'Port', sshPort];
    end
end

cluster.saveProfile

% Now connect and store the connection
% MW: Changes to support ClusterHost and MirrorHost
if ~isempty(mirrorHost)
    dctSchedulerMessage(1, '%s: Connecting to remote host %s and mirror host %s', ...
        currFilename, clusterHost, mirrorHost);
else
    dctSchedulerMessage(1, '%s: Connecting to remote host %s', ...
        currFilename, clusterHost);
end
if cluster.HasSharedFilesystem
    remoteConnection = parallel.cluster.RemoteClusterAccess.getConnectedAccess(clusterHost, userArgs{:});
    mirrorConnection = '';
else
    if useUniqueSubfolders
        remoteJobStorageLocation = iBuildUniqueSubfolder(remoteJobStorageLocation, ...
            username, iGetFileSeparator(cluster));
    end
    remoteConnection = parallel.cluster.RemoteClusterAccess.getConnectedAccess(clusterHost, userArgs{:});
    mirrorConnection = parallel.cluster.RemoteClusterAccess.getConnectedAccessWithMirror(mirrorHost, remoteJobStorageLocation, userArgs{:});
end
dctSchedulerMessage(5, '%s: Storing remote connection in cluster''s user data.', currFilename);
cluster.UserData.RemoteConnection = remoteConnection;
if ~isempty(mirrorConnection)
    cluster.UserData.MirrorConnection = mirrorConnection;
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function useUI = iShouldUseUI()
if verLessThan('matlab', '9.11')
    % Prior to R2021b, check for Java AWT components
    useUI = isempty(javachk('awt'));
else
    % From R2021b onwards, can use the desktop function
    useUI = desktop('-inuse');
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function username = iGetUsername(cluster, useUI)

username = validatedPropValue(cluster.AdditionalProperties, 'Username', 'char');
if ~isempty(username)
    return
end

if useUI
    dlgMessage = sprintf('Enter the username for %s', cluster.AdditionalProperties.ClusterHost);
    dlgTitle = 'User Credentials';
    numlines = 1;
    usernameResponse = inputdlg(dlgMessage, dlgTitle, numlines);
    % Hitting cancel gives an empty cell array, but a user providing an empty string gives
    % a (non-empty) cell array containing an empty string
    if isempty(usernameResponse)
        % User hit cancel
        error('parallelexamples:GenericSLURM:UserCancelledOperation', ...
            'User cancelled operation.');
    end
    username = char(usernameResponse);
    cluster.AdditionalProperties.Username = username;
    return
end

% useUI == false
msg = sprintf('Enter the username for %s:\n ', cluster.AdditionalProperties.ClusterHost);
username = input(msg, 's');
cluster.AdditionalProperties.Username = username;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function identityFileHasPassphrase = iGetIdentityFileHasPassphrase(cluster, useUI)

identityFileHasPassphrase = validatedPropValue( ...
    cluster.AdditionalProperties, 'IdentityFileHasPassphrase', 'logical');
if ~isempty(identityFileHasPassphrase)
    return
end

if useUI
    dlgMessage = 'Does the identity file require a password?';
    dlgTitle = 'User Credentials';
    passphraseResponse = questdlg(dlgMessage, dlgTitle);
    if strcmp(passphraseResponse, 'Cancel')
        % User hit cancel
        error('parallelexamples:GenericSLURM:UserCancelledOperation', 'User cancelled operation.');
    end
    identityFileHasPassphrase = strcmp(passphraseResponse, 'Yes');
    cluster.AdditionalProperties.IdentityFileHasPassphrase = identityFileHasPassphrase;
    return
end

% useUI == false
validYesNoResponse = {'y', 'n'};
passphraseMessage = sprintf('Does the identity file require a password? (y or n)\n ');
passphraseResponse = iLoopUntilValidStringInput(passphraseMessage, validYesNoResponse);
identityFileHasPassphrase = strcmpi(passphraseResponse, 'y');
cluster.AdditionalProperties.IdentityFileHasPassphrase = identityFileHasPassphrase;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function identityFile = iGetIdentityFile(cluster, useUI)

if isprop(cluster.AdditionalProperties, 'IdentityFile')
    identityFile = cluster.AdditionalProperties.IdentityFile;
    if ~(ischar(identityFile) || isstring(identityFile) || iscellstr(identityFile)) || any(strlength(identityFile) == 0)
        error('parallelexamples:GenericSLURM:IncorrectArguments', ...
            'Each IdentityFile must be a nonempty character vector');
    end
else
    if useUI
        dlgMessage = 'Select Identity File to use';
        [filename, pathname] = uigetfile({'*.*', 'All Files (*.*)'},  dlgMessage);
        % If the user hit cancel, then filename and pathname will both be 0.
        if isequal(filename, 0) && isequal(pathname,0)
            error('parallelexamples:GenericSLURM:UserCancelledOperation', 'User cancelled operation.');
        end
        identityFile = fullfile(pathname, filename);
        cluster.AdditionalProperties.IdentityFile = identityFile;
    else
        msg = sprintf('Please enter the full path to the Identity File to use:\n ');
        identityFile = input(msg, 's');
        cluster.AdditionalProperties.IdentityFile = identityFile;
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function authMode = iPromptUserForAuthenticationMode(cluster, useUI)

promptMessage = sprintf('Select an authentication method to log in to %s', cluster.AdditionalProperties.ClusterHost);
options = {'Password', 'Identity File', 'Cancel'};

if useUI
    dlgTitle = 'User Credentials';
    defaultOption = 'Password';
    authMode = questdlg(promptMessage, dlgTitle, options{:}, defaultOption);
    authMode = strrep(authMode, ' ', '');
    if strcmp(authMode, 'Cancel') || isempty(authMode)
        % User hit cancel or closed the window
        error('parallelexamples:GenericSLURM:UserCancelledOperation', 'User cancelled operation.');
    end
    useIdentityFile = strcmp(authMode, 'IdentityFile');
    cluster.AdditionalProperties.UseIdentityFile = useIdentityFile;
else
    validResponses = {'1', '2', '3'};
    displayItems = [validResponses; options];
    identityFileMessage = [promptMessage, newline, sprintf('%s) %s\n', displayItems{:}), ' '];
    response = iLoopUntilValidStringInput(identityFileMessage, validResponses);
    switch response
        case '1'
            authMode = 'Password';
        case '2'
            authMode = 'IdentityFile';
        otherwise
            error('parallelexamples:GenericSLURM:UserCancelledOperation', 'User cancelled operation.');
    end
    useIdentityFile = strcmpi(response, 'IdentityFile');
    cluster.AdditionalProperties.UseIdentityFile = useIdentityFile;
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function returnValue = iLoopUntilValidStringInput(message, validValues)
% Function to loop until a valid response is obtained user input
returnValue = '';

while isempty(returnValue) || ~any(strcmpi(returnValue, validValues))
    returnValue = input(message, 's');
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function subfolder = iBuildUniqueSubfolder(remoteJobStorageLocation, username, fileSeparator)
% Function to build unique location using username and MATLAB release version
release = ['R' version('-release')];
subfolder = [remoteJobStorageLocation fileSeparator username fileSeparator release];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fileSeparator = iGetFileSeparator(cluster)
% Function to return file separator for cluster operating system
if strcmpi(cluster.OperatingSystem, 'unix')
    fileSeparator = '/';
else
    fileSeparator = '\';
end
end
