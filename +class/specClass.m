classdef specClass % < handle
% handle methods:
%   addlistener  - Add listener for event and bind to source
%   delete       - Delete a handle object.
%   eq           - Test handle equality.
%   findobj      - Find objects with specified property values.
%   findprop     - Find property of MATLAB handle object.
%   ge           - Greater than or equal relation.
%   gt           - Greater than relation.
%   isvalid      - Test handle validity.
%   le           - Less than or equal relation for handles.
%   listener     - Add listener for event without binding to source
%   lt           - Less than relation for handles.
%   ne           - Not equal relation for handles.
%   notify       - Notify listeners of event.

    properties

        ID
        taskObj     = []
        Observation = struct('Created',    '', ...                          % Datestring data type - Format: '24/02/2023 14:00:00'
                             'BeginTime',  [], ...                          % Datetime data type
                             'EndTime',    [], ...                          % Datetime data type
                             'StartUp',    [])                              % Datetime data type

        hReceiver                                                           % Handle to Receiver
        hStreaming                                                          % Handle to UDP socket (generated by R&S EB500)
        hGPS                                                                % Handle to GPS

        lastGPS     = struct('Status',     0, ...
                             'Latitude',  -1, ...
                             'Longitude', -1, ...
                             'TimeStamp', '')

        SCPI        = struct('scpiSet_Reset',   '', ...
                             'scpiSet_Startup', '', ...
                             'scpiSet_Sync',    '', ...
                             'scpiGet_Att',     '', ...
                             'scpiGet_Data',    '')

        Band        = struct('scpiSet_Config',  '', ...
                             'scpiSet_Att',     '', ...
                             'scpiSet_Answer',  '', ...
                             'Datagrams',       [], ...
                             'DataPoints',      [], ...
                             'SyncModeRef',     -1, ...
                             'FlipArray',        0, ...
                             'Waterfall', struct('idx',      0,   ...
                                                 'Depth',  512,   ...
                                                 'Matrix',   []), ...
                             'Mask', struct('Table',         [],  ...
                                            'Array',         [],  ...
                                            'Validations',   [],  ...
                                            'BrokenArray',   [],  ...
                                            'BrokenCount',   [],  ...
                                            'MainPeaks',     [],  ...
                                            'TimeStamp',     ''), ...
                             'File', struct('Fileversion',   [],  ...
                                            'Basename',      '',  ...
                                            'Filecount',     [],  ...
                                            'WritedSamples', [],  ...
                                            'CurrentFile',   struct('FullPath',        '',   ...
                                                                    'AlocatedSamples', [],   ...
                                                                    'Handle',          [],   ...
                                                                    'MemMap',          [])), ...
                             'Antenna',         '', ...
                             'Status',          [])

        Status      = ''                                                    % 'Na fila' | 'Em andamento' | 'Concluída' | 'Cancelada' | 'Erro'
        LOG         = struct('type', '', ...
                             'time', '', ...
                             'msg',  '')

    end


    methods

        function [specObj, idx] = Fcn_AddTask(specObj, taskObj)

            if isempty([specObj.ID]); idx = 1;
            else;                     idx = numel(specObj)+1;
            end

            specObj(idx).ID          = idx;
            specObj(idx).taskObj     = taskObj;
            specObj(idx).Observation = struct('Created',   datestr(now, 'dd/mm/yyyy HH:MM:SS'),                                                                                         ...
                                              'BeginTime', datetime(taskObj.General.Task.Observation.BeginTime, 'InputFormat', 'dd/MM/yyyy HH:mm:ss', 'Format', 'dd/MM/yyyy HH:mm:ss'), ...
                                              'EndTime',   datetime(taskObj.General.Task.Observation.EndTime,   'InputFormat', 'dd/MM/yyyy HH:mm:ss', 'Format', 'dd/MM/yyyy HH:mm:ss'), ...
                                              'StartUp',   NaT);

            % HANDLES
            specObj(idx).hReceiver   = taskObj.Receiver.Handle;
            specObj(idx).hStreaming  = taskObj.Streaming.Handle;
            specObj(idx).hGPS        = taskObj.GPS.Handle;

            % GPS/SCPI/BAND
            specObj(idx).lastGPS     = struct('Status', 0, 'Latitude', -1, 'Longitude', -1, 'TimeStamp', specObj(idx).Observation.Created);
            if strcmp(taskObj.General.Task.GPS.Type, 'Manual')
                specObj(idx).lastGPS.Status    = -1;
                specObj(idx).lastGPS.Latitude  = taskObj.General.Task.GPS.Latitude;
                specObj(idx).lastGPS.Longitude = taskObj.General.Task.GPS.Longitude;
            end
            
            warnMsg  = {};
            errorMsg = '';
            try
                [specObj(idx).SCPI, specObj(idx).Band, warnMsg] = connect_Receiver_WriteReadTest(taskObj);
            catch ME
                errorMsg = ME.message;
            end
            
            % STATUS/LOG
            specObj(idx).LOG = struct('type', {}, 'time', {}, 'msg',  {});            
            if isempty(errorMsg)
                specObj(idx).Status = 'Na fila';
            else
                specObj(idx).Status = 'Erro';
                specObj(idx).LOG(end+1) = struct('type', 'error', 'time', specObj(idx).Observation.Created, 'msg', errorMsg);
            end
            
            if ~isempty(warnMsg)
                specObj(idx).LOG{end+1} = struct('type', 'warning', 'time', specObj(idx).Observation.Created, 'msg', warnMsg);
            end

        end


        function specObj = Fcn_DelTask(specObj, idx)

            if (idx <= numel(specObj)) & (numel([specObj.ID]) > 1)
                specObj(idx) = [];

                for ii = 1:numel(specObj)
                    specObj(ii).ID = ii;
                end
            end

        end

    end
end