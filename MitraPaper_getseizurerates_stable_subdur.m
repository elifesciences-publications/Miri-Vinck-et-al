function [R] = MitraPaper_getperiodrates()
%%
MitraPaper_info;
global info
global datadir_manuscript

for dur = [60 80 100 120]
    for nIctalPeriods = 4
        clear R

        nFiles = length(info);
        celltype = {};
        for iFile = 1:nFiles
            info(iFile)
            celltype{iFile} = info(iFile).neuron_type;
            if info(iFile).has_rc==0

                % read in the opto files 
                fieldSelection = ones(1,5);    
                extractHeader  = 1;
                try
                    [TimeStamp,B,C,D,data,F] = Nlx2MatSpike(fullfile(info(iFile).directory, 'optopulses.ntt'), fieldSelection,extractHeader, 1);
                catch
                    TimeStamp = [];
                end

                % if there are no pulses, compute the rat in the regular way
                if length(TimeStamp)<2
                   [rate_base(iFile)] = Mitra01_rate(fullfile(info(iFile).directory, info(iFile).name), info(iFile).base_start, info(iFile).base_end);
                else % if there are opto pulses, use a different script
                    rate_base(iFile) = MitraPaper_rate_opto_spontaneous(fullfile(info(iFile).directory, info(iFile).name), TimeStamp, info(iFile).base_start, info(iFile).base_end);
                end

                % ictal periods
                ts1 = info(iFile).seizure_onset+info(iFile).ictalspike*10^6;
                ts2 = info(iFile).stable_until; %info(iFile).seizure_onset+info(iFile).seizure_autodetect_absolute*10^6;
                if isnan(ts2), continue,end

                if (ts2-ts1)<(dur*10^6), continue; end
                ts1 = info(iFile).seizure_onset+info(iFile).ictalspike*10^6;
                ts2 = ts1 + dur*(10^6);%info(iFile).stable_until; %info(iFile).seizure_onset+info(iFile).seizure_autodetect_absolute*10^6;
                
                ts  = linspace(ts1, ts2, nIctalPeriods+1);   
                for iIctalPeriod = 1:nIctalPeriods

                     if length(TimeStamp)<2
                         [rate_ictal(iFile,iIctalPeriod)] = ...
                         Mitra01_rate(fullfile(info(iFile).directory, info(iFile).name), ts(iIctalPeriod), ts(iIctalPeriod+1));
                     else
                        [rate_ictal(iFile,iIctalPeriod)] = ...
                         MitraPaper_rate_opto_spontaneous(fullfile(info(iFile).directory, info(iFile).name),  TimeStamp,ts(iIctalPeriod), ts(iIctalPeriod+1));                
                     end
                end
            else % write something new that produces the same stuff for RC
                % read in the data and the timestamps
                fieldSelection = ones(1,5);    
                extractHeader  = 1;
                [TimeStamp,B,C,D,data,F] = Nlx2MatSpike(fullfile(info(iFile).directory, 'optopulses.ntt'), fieldSelection,extractHeader, 1);

                 if sum(diff(TimeStamp)>1.5*10^6)<10, continue,end      

                 % compute the baseline rate
                 rate_base(iFile) = MitraPaper_rate_opto(fullfile(info(iFile).directory, info(iFile).name), TimeStamp, info(iFile).nlevels,info(iFile).base_start_pulse, info(iFile).base_end_pulse);

                 %ictal for RC files
                 ts1 = info(iFile).injection_start_pulse;
                 ts2 = info(iFile).seizure_onset_pulse;  
                 ts1 = TimeStamp(ts2) + info(iFile).ictalspike*10^6;                  
                ts2 = info(iFile).stable_until; %info(iFile).seizure_onset+info(iFile).seizure_autodetect_absolute*10^6;
                
                if isempty(ts2) | isnan(ts2), continue,end
                if (ts2-ts1)<(dur*10^6), continue; end
                ts2 = ts1 + dur*(10^6);%info(iFile).stable_until; %info(iFile).seizure_onset+info(iFile).seizure_autodetect_absolute*10^6;
                              

            %     ts2 = TimeStamp(ts2) + info(iFile).seizure_autodetect_absolute*10^6; 
                 %if (ts2-ts1)<50, continue,end        
                % dur(iFile) = (ts2-ts1) / (10^6); 

                 if (ts2-ts1)<(20*10^6), continue; end          
                 ts1 = nearest(TimeStamp,ts1);             
                 ts2 = nearest(TimeStamp,ts2);
                 iFile 
                 ts  = round(linspace(ts1, ts2, nIctalPeriods+1)); 
                 try
                     for iIctalPeriod = 1:nIctalPeriods
                          [rate_ictal(iFile,iIctalPeriod)] = ...
                          MitraPaper_rate_opto(fullfile(info(iFile).directory, info(iFile).name), TimeStamp, info(iFile).nlevels,ts(iIctalPeriod), ts(iIctalPeriod+1));                
                     end
                 catch
                 end
            end        
        end

        % concatenate all the data and give it back as a result structure
         for k = 1:length(info)
             if isempty(rate_base(k).avg)                   
                rate_base(k).avg = NaN;
             end
        end

        R.rate_base = cat(1,rate_base(:).avg);

        for k = 1:length(info)
           for ii = 1:nIctalPeriods
                if size(rate_ictal,1)<k || isempty(rate_ictal(k,ii).avg)                   
                    rate_ictal(k,ii).avg = NaN;
                end
           end
        end

        for ii = 1:nIctalPeriods
            R.rate_ictal(:,ii)  = cat(1,rate_ictal(:,ii).avg);
        end

        R.neurontype   = celltype;
        for k = 1:length(R.neurontype)
            if isempty(R.neurontype{k}) | isnan(R.neurontype{k})
                R.neurontype{k} = 'Z';
            end
        end

        [a,b,c] = unique(R.neurontype);
        R.neurontype_label = a;
        R.neurontype_indx  = c;
        R.dur              = dur;
        R.dur(end+1:length(R.neurontype)) = NaN;

        outputdir = fullfile(datadir_manuscript, 'averagerateseizure_stable');
        mkdir(outputdir)
        str = ['averagerateseizure_stable_' num2str(nIctalPeriods) '_' num2str(dur)];
        filename = fullfile(outputdir, str);
        save(filename, 'R');
    end
end

    



