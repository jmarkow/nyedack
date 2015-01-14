function dump_data(obj,event,save_dir,folder_format,out_dir,file_basename,file_format,logfile,actualrate,channel_labels,preview_figure,dump_samples)

% basically, a circular buffer is used!

global preview_voltage_scale;
global preview_refresh_rate;

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

% do we want to preview?

available_samples=obj.SamplesAvailable;

%%% preview code

if ~isempty(preview_figure) & available_samples<dump_samples


	ylimits=[-preview_voltage_scale/1e6 preview_voltage_scale/1e6];
	xlimits=[0 preview_refresh_rate/1e3];

	[data]=peekdata(obj,obj.SamplesAvailable);
    	time=[1:length(data)]/actualrate;
	for i=1:length(channel_axis)
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
		data.labels=channel_labels;

		save_dir=fullfile(save_dir,datestr(now,folder_format),out_dir);
		if ~exist(save_dir,'dir')
			mkdir(save_dir);
		end

		save(fullfile(save_dir,datafile_name),'data');
		fprintf(logfile,'%s saved successfully at %s\n',fullfile(save_dir,datafile_name),datestr(now));
		disp([ fullfile(save_dir,datafile_name) ' saved successfully at ' datestr(now) ]);
	catch
		flushdata(obj);
	end
end
