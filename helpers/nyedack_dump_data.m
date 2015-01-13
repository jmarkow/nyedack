function dump_data(obj,event,save_dir,folder_format,out_dir,logfile,actualrate)

% basically, a circular buffer is used!

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

try
	[data.voltage,data.time,data.start_time]=getdata(obj,obj.SamplesAvailable);
	datafile_name=[ 'data_' datestr(now,30) '.mat' ];
	data.sampling_rate=actualrate;

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

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection
