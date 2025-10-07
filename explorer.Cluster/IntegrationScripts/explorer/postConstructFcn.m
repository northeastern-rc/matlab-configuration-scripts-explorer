function postConstructFcn(cluster) %#ok<INUSD>
%POSTCONSTRUCTFCN Perform custom configuration after call to PARCLUSTER
%
% POSTCONSTRUCTFCN(CLUSTER) execute code on cluster object CLUSTER.
%
% See also parcluster.

% Copyright 2023-2025 The MathWorks, Inc.


%%%%%%%%%%%%%%%%%%%%%
% Functions to call %
%%%%%%%%%%%%%%%%%%%%%

% Checks for a complete RJSL, as often the local hostname is missing on macOS and Linux. 
iRJSLHostnameCheck(cluster);

% Uncomment the following line if the cluster has a non-standard RJSL that requires user input rather 
% than relying on the same pattern for all users. See function for full instructions.
%iNonstandardRJSL(cluster);

% Uncomment the following line if you'd like to display a banner informing the user that
% an AdditionalProperties value is required to submit a job.  See function for more info.
%iRequiredPropertiesBanner(cluster);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Required Properties Banner %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function iRequiredPropertiesBanner(cluster)
     
    persistent DONE
    mlock
    
    if DONE
        % We've already warned to correctly set the AdditionalProperties
        return
    else
        % Only want to check once per MATLAB session
        DONE = true;
    end

    ap = cluster.AdditionalProperties;
    profile = split(cluster.Profile);

    if isempty(validatedPropValue(ap, 'WallTime', 'char', ''))
        fprintf(['\n\tMust set WallTime before submitting jobs to %s.  E.g.\n\n', ...
                 '\t>> c = parcluster;\n', ...
                 '\t>> %% 5 hour, 30 minute walltime\n', ...
                 '\t>> c.AdditionalProperties.WallTime = ''05:30:00'';\n', ...
                 '\t>> c.saveProfile\n'], profile{1})
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%
% RJSL Hostname Check %
%%%%%%%%%%%%%%%%%%%%%%%%

function iRJSLHostnameCheck(cluster)

    % Only perform this section if an RJSL is set.
    if isprop(cluster.AdditionalProperties, 'RemoteJobStorageLocation')

        % First, get the cluster profile name so we can look at it in the string.  We only want to perform these steps if the RJSL is set to a 
        % standard version **AND** it's missing the HOST variable.  
        profileName = strsplit(cluster.Profile, ' ');
        clusterName = lower(profileName{1});
        defaultRJSLString = strcat('/.matlab/generic_cluster_jobs/', clusterName);
        
        % Check to see if the RJSL has the default string 
        if contains(cluster.AdditionalProperties.RemoteJobStorageLocation, defaultRJSLString) 
            % If RJSL has default string, then we next want to get the hostname variable.
            if ispc
                hostVariable = getenv('COMPUTERNAME');
            else
                hostVariable = getenv('HOST');
            end
        
            % We then need to update the RJSL with a new value if the hostVariable
            % is empty AND the RJSL ends with '/' indicating the hostname was never
            % set AND the RJSL hasn't been updated yet
            if isempty(hostVariable) && endsWith(cluster.AdditionalProperties.RemoteJobStorageLocation, '/') && ~contains(cluster.AdditionalProperties.RemoteJobStorageLocation, 'remoteClient-')
                % First get an appropriate placeholder for the hostname
                fixedPart = 'remoteClient-';
                % Generate a temporary name and split it into parts
                pathParts = strsplit(tempname, filesep);
                % Extract the first 7 characters of the last section
                randomPart = pathParts{end}(1:7);
                % Assemble the new hostname
                newHostname = [fixedPart, randomPart];
        
                % Now that we have a new hostname, we can append it at the end
                % (since if it's empty, there's just an empty space there after the /)
                cluster.AdditionalProperties.RemoteJobStorageLocation = strcat(cluster.AdditionalProperties.RemoteJobStorageLocation, newHostname);
                cluster.saveProfile
            end
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Non-Standard RemoteJobStorageLocation %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function iNonstandardRJSL(cluster)

    % The following code block is used if the cluster has a non-standard RJSL that requires user input rather 
    % than relying on the same pattern for all users.
    % You MUST also make corresponding changes to the cluster.conf file(s).

    % Step One -- Modify .conf file(s) with "default_proj_name" where the custom value should go.
    % Example hpcDesktop.conf file:

    % # Remote Job Storage Location
    % # Directory on the cluster's file system to be used as the remote job storage location.   
    % RemoteJobStorageLocation (Windows) = /proj/default_proj_name/"$USERNAME"/.matlab/generic_cluster_jobs/HPC/"$COMPUTERNAME"
    % RemoteJobStorageLocation (Unix) = /proj/default_proj_name/"$USER"/.matlab/generic_cluster_jobs/HPC/"$HOST"

    % Step Two - Modify the following code as necessary


    if contains(cluster.AdditionalProperties.RemoteJobStorageLocation, 'default_proj_name')
        projectname = iGetProjectName;
        cluster.AdditionalProperties.RemoteJobStorageLocation = replace(cluster.AdditionalProperties.RemoteJobStorageLocation, 'default_proj_name', projectname);
        if ~contains(cluster.AdditionalProperties.RemoteJobStorageLocation, projectname)
            error(['Failed to configure RemoteJobStorageLocation with project name "%s".' ...
                '\nManually verify that a correct RemoteJobStorageLocation value is configured.'], projectname)
        end
        cluster.saveProfile
    end
end

function pn = iGetProjectName

    pn = input('Project name (e.g. fs#####): ','s');
    if isempty(pn)
        error('Failed to configure cluster.')
    end
end
