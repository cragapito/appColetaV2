classdef specClass < handle

    % Author.: Eric Magalhães Delgado
    % Date...: August 08, 2023
    % Version: 1.00

    properties
        ID
        Task        = class.taskClass.empty                                 % See "auxApp.winAddTask.mlapp"
        Observation = struct('Created',    '', ...                          % Datestring data type - Format: '24/02/2023 14:00:00'
                             'BeginTime', NaT, ...                          % Datetime data type
                             'EndTime',   NaT, ...                          % Datetime data type
                             'StartUp',   NaT)                              % Datetime data type
    
        hReceiver                                                           % Handle to Receiver
        hStreaming                                                          % Handle to UDP socket (generated by R&S EB500)
        hGPS                                                                % Handle to GPS

        lastGPS     = struct('Status', 0, 'Latitude', -1, 'Longitude', -1, 'TimeStamp', '')
        GeneralSCPI = struct('resetSET', {}, 'startupSET', {}, 'syncSET', {}, 'attGET', {}, 'dataGET', {})
        Band        = class.bandClass.empty                                 % See "fcn.receiverConfig_SpecificBand.m"

        Error       = table(["Receiver";"GPS"], [NaT;NaT], [NaT;NaT], [0;0], 'VariableNames', {'Family', 'CreatedTime', 'LastTime', 'Count'})
        Status      = ''                                                    % 'Na fila' | 'Em andamento' | 'Concluída' | 'Cancelada' | 'Erro'
        LOG         = struct('type', {}, 'time', {}, 'msg',  {})
    end


    methods
        %-----------------------------------------------------------------%
        function [obj, errorMsg] = AddOrEditTask(obj, infoEdition, newTask, EMSatObj)
            switch infoEdition.type
                case 'new'
                    idx = numel(obj)+1;
                    obj(idx).ID = idx;
                    obj(idx).Observation.Created = datestr(now, 'dd/mm/yyyy HH:MM:SS');

                case 'edit'
                    idx = infoEdition.idx;
            end
            
            obj(idx).Task       = newTask;
            
            obj(idx).hReceiver  = newTask.Receiver.Handle;
            obj(idx).hStreaming = newTask.Streaming.Handle;
            obj(idx).hGPS       = newTask.GPS.Handle;

            obj(idx).Observation.BeginTime = datetime(newTask.Script.Observation.BeginTime, 'InputFormat', 'dd/MM/yyyy HH:mm:ss');
            obj(idx).Observation.EndTime   = datetime(newTask.Script.Observation.EndTime,   'InputFormat', 'dd/MM/yyyy HH:mm:ss');

            obj.startup_lastGPS(idx, newTask.Script.GPS);
            errorMsg = obj.startup_ReceiverTest(idx, EMSatObj);
        end
    end


    methods (Access = protected)
        %-----------------------------------------------------------------%
        function startup_lastGPS(obj, idx, GPS)
            if strcmp(GPS.Type, 'Manual')
                obj(idx).lastGPS.Status    = -1;
                obj(idx).lastGPS.Latitude  = GPS.Latitude;
                obj(idx).lastGPS.Longitude = GPS.Longitude;
            end
            obj(idx).lastGPS.TimeStamp = obj(idx).Observation.Created;
        end


        %-----------------------------------------------------------------%
        function errorMsg = startup_ReceiverTest(obj, idx, EMSatObj)
            errorMsg = '';

            try
                fcn.receiverConfig_General(obj, idx);
                warnMsg = fcn.receiverConfig_SpecificBand(obj, idx, EMSatObj);
                obj(idx).Status = 'Na fila';

                if ~isempty(warnMsg)
                    obj(idx).LOG(end+1) = struct('type', 'warning', 'time', obj(idx).Observation.Created, 'msg', warnMsg);
                end
                obj(idx).LOG(end+1) = struct('type', 'task', 'time', obj(idx).Observation.Created, 'msg', 'Incluída na fila a tarefa.');

            catch ME
                errorMsg = ME.message;

                if isempty(obj.Band)
                    obj(idx) = [];
                else
                    obj(idx).Status = 'Erro';
                    obj(idx).LOG(end+1) = struct('type', 'error', 'time', obj(idx).Observation.Created, 'msg', errorMsg);    
                end
            end          
        end
    end
end