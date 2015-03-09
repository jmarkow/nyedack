function dump_data(obj,event,dump_samples,save_dir,folder_format,out_dir,file_basename,file_format,logfile,...
		preview_figure,channel_axis,channel_plot,dcoffset,note)

% basically, a circular buffer is used!

global preview_voltage_scale;
global preview_refresh_rate;

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

% do we want to preview?

actualrate=obj.SampleRate;
available_samples=obj.SamplesAvailable;
refresh_samples=round((preview_refresh_rate/1e3)*actualrate);
nchannels=length(obj.Channel);

%%% preview code

if ~isempty(preview_figure) & available_samples<dump_samples & available_samples>refresh_samples

	ylimits=[-preview_voltage_scale/1e6 preview_voltage_scale/1e6];
	xlimits=[0 preview_refresh_rate/1e3];

	data=peekdata(obj,refresh_samples);

	if dcoffset
		data=detrend(data,'constant');
	end

	% grab latest segment

	time=[1:refresh_samples]/actualrate;

	for i=1:length(channel_axis)

		% bail if the figure has been deleted...
		
		if ~ishandle(channel_plot(i))
		    return;
		end
		
		set(channel_plot(i),'XData',time,'YData',data(:,i));
		old_xlimits=get(channel_axis(i),'xlim');
		old_ylimits=get(channel_axis(i),'ylim');

		if ~all(xlimits==old_xlimits)
			set(channel_axis(i),'xlim',xlimits);
		end

		if ~all(ylimits==old_ylimits)
			set(channel_axis(i),'ylim',ylimits);
		end

		drawnow;
	end
end

%%% acquisition code

if available_samples>dump_samples
	try
		[data.voltage,data.time,data.start_time]=getdata(obj,obj.SamplesAvailable);
		datafile_name=[ file_basename '_' datestr(now,file_format) '.mat' ];

		data.fs=actualrate;
		data.labels=[];
		data.names={};
		data.parameters.units={};
		data.parameters.sensor_range={};
		data.parameters.input_range={};
		data.parameters.units_range={};
        data.note=note;

		for i=1:nchannels
			data.labels(i)=obj.Channel(i).HwChannel;
			data.names{i}=obj.Channel(i).ChannelName;
			data.parameters.units{i}=obj.Channel(i).Units;
			data.parameters.sensor_range=obj.Channel(i).SensorRange;
			data.parameters.input_range=obj.Channel(i).InputRange;
			data.parameters.units_range=obj.Channel(i).UnitsRange;
		end

		if ~isempty(folder_format)	
			save_dir=fullfile(save_dir,datestr(now,folder_format),out_dir);
		end

		if ~exist(save_dir,'dir')
			mkdir(save_dir);
		end

		save(fullfile(save_dir,datafile_name),'data');
		fprintf(logfile,'%s saved successfully at %s\n',fullfile(save_dir,datafile_name),datestr(now));
		disp([ fullfile(save_dir,datafile_name) ' saved successfully at ' datestr(now) ]);
	catch
		warning('Could not get data, flushing...');
		flushdata(obj);
	end
end
