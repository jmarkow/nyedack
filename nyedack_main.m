function nyedack_main(INCHANNELS,OUTPUT,varargin)
% CLI interface for recording data through the MATLAB legacy interface
%
%	nyedack_main(INCHANNELS,OUTPUT,varargin)
%
%	INCHANNELS
%	vector of NIDAQ channels to record from (start from 0)
%
%	OUTPUT
%	structure specifying how to deliver output (leave empty for no output)
%	
%	the following may be specified as parameter/value pairs:
%
%		fs
%		data acquisition sampling rate (default: 40e3)
%
%		base_dir
%		base directory for data storage (default: 'nyedack')
%
%		note
%		string containing note to include in data storage log (default: empty)
%
%		save_freq
%		frequency for dumping data to disk from memory (in s, default: 60)
%
%		stop_time
%		time to stop recording (vector in [d h m s] format, default: [100 0 0 0], will record for 100 days)
%
%		in_device
%		input device location (default: 'dev2')
%
%		in_device_type (default: 'nidaq')
%
%		out_device
%		output device location (default: 'dev2')
%
%		output_device_type
%		output device type (default: 'nidaq')
%
%		folder_format
%		datestr format for data storage folders (default: 'yyyy-mm-dd')
%
%		file_format
%		datestr format for data storage file timestamp (default: 'yymmdd_HHMMSS')
%
%		file_basename
%		base for data storage filename (default: 'data')
%
%		out_dir
%		data storage sub directory (default: 'mat')
%
%		hannel_labels
%		labels for INCHANNELS (cell array, default: empty)
%
%		preview_enable
%		enable preview of data (default: 0)
%
%		preview_dcoffset
%		remove DC component of data for preview (default: 1)
%
%		polling_rate
%		how often to check for data samples (in s, default: .05)
%
%	Example:
%	
%	Record from 'nidaq' 'dev2' channels [0:5], and preview data
%
%	>>nyedack_main([0:5],[],'in_device_type','nidaq','in_device','dev2','preview_enable',1);
%	
%

% collect the input variables and use defaults if necessary

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETER COLLECTION %%%%%%%%%%%%%%%%%

global preview_voltage_scale;
global preview_refresh_rate;

if nargin<2 | isempty(OUTPUT), OUTPUT=[]; end
if nargin<1 | isempty(INCHANNELS), INCHANNELS=0; end

nparams=length(varargin);

max_recurse=5;

restarts=0;
base_dir='nyedack'; % base directory to save
fs=40e3; % sampling frequency (in Hz)
note=''; % note to save in log file
save_freq=60; % save frequency (in s)
stop_time=[100 0 0 0 ]; % when to stop recording (d h m s)
in_device='dev2'; % location of input device
in_device_type='nidaq'; % input device type
out_device='dev2'; % location of output device
out_device_type='nidaq'; % output device type
folder_format='yyyy-mm-dd'; % date string format for folders
file_format='yymmdd_HHMMSS'; % date string format for files
out_dir='mat'; % save files to this sub directory
channel_labels={}; % labels for INCHANNELS
preview_enable=0; % enable preview?
preview_nrows=5;
preview_pxrow=100;
preview_pxcolumn=300;
preview_dcoffset=1; % remove DC offset for preview?
channel_skew='equisample'; % time between samples
file_basename='data'; % basename for save files
polling_rate=.05; % how often to poll for data (in s)? only used with preview off
		  % otherwise this is tied to the refresh rate of the GUI
recurse=0;

if mod(nparams,2)>0
	error('Parameters must be specified as parameter/value pairs!');
end

for i=1:2:nparams
	switch lower(varargin{i})
		case 'note'
			note=varargin{i+1};
		case 'restarts'
			restarts=varargin{i+1};
		case 'base_dir'
			base_dir=varargin{i+1};
		case 'fs'
			fs=varargin{i+1};
		case 'save_freq'
			save_freq=varargin{i+1};
		case 'in_device_type'
			in_device_type=varargin{i+1};
		case 'in_device'
			in_device=varargin{i+1};
		case 'out_device_type'
			out_device_type=varargin{i+1};
		case 'out_device'
			out_device=varargin{i+1};
		case 'folder_format'
			folder_format=varargin{i+1};
		case 'out_dir'
			out_dir=varargin{i+1};
		case 'channel_labels'
			channel_labels=varargin{i+1};
		case 'preview_enable'
			preview_enable=varargin{i+1};
		case 'preview_nrows'
			preview_nrows=varargin{i+1};
		case 'preview_pxrow'
			preview_pxrow=varargin{i+1};
		case 'preview_pxcolumn'
			preview_pxcolumn=varargin{i+1};
		case 'file_basename'
			file_basename=varargin{i+1};
		case 'file_format'
			file_format=varargin{i+1};
		case 'polling_rate'
			polling_rate=varargin{i+1};
		case 'preview_dcoffset'
			preview_dcoffset=varargin{i+1};
		case 'channel_skew'
			channel_skew=varargin{i+1};
		case 'recurse'
			recurse=varargin{i+1};
		otherwise
	end
end

if recurse>max_recurse
	error('Recursion limit exceeded...');
end

refresh_rates=[ 50 100 200 500 1e3 2e3 5e3 ];
voltage_scales=[ 1 5 1e2 5e2 1e3 5e3 1e4 5e4 1e5 5e5 1e6 5e6 1e7 5e7 1e8 5e8 ];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TODO: finish save_directory creation
% TODO: put preview back in
% TODO: change function names as appropriate
% TODO: simplify as much as possible!

rec_datevec=datevec(addtodate(today,stop_time(1),'day'));
rec_datevec(4:6)=stop_time(2:4);
disp(['Will record until ' datestr(rec_datevec)]);

% compute the save frequency in seconds

sprintf('Will save every %g minutes\n',save_freq/60);

% create the necessary directories for dumping the data

nchannels=length(INCHANNELS);
nlabels=length(channel_labels);

for i=nlabels+1:nchannels
	channel_labels{i}=sprintf('CH %i',INCHANNELS(i));
end

start_time=([datestr(now,'HHMMSS')]);

daqs=daqfind;
if length(daqs)>0
	stop(daqs);
	delete(daqs);
end


% open the analog input object

analog_input = analoginput(in_device_type,in_device);
set(analog_input,'InputType','SingleEnded');

ch=addchannel(analog_input,INCHANNELS);
actualrate=setverify(analog_input,'SampleRate',fs);

for i=1:length(analog_input.Channel)
	analog_input.Channel(i).ChannelName=channel_labels{i};
end

% check to see if the actual sampling rate meets our specs, otherwise bail

if actualrate ~= fs
	error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(fs) ')' ]);
end

% set the parameters of the analog input object

set(analog_input,'TriggerType','Immediate')

recording_duration=round(save_freq*actualrate);
polling_duration=round(polling_rate*actualrate);

set(analog_input,'SamplesPerTrigger',inf)
set(analog_input,'ChannelskewMode',channel_skew);

save_dir=fullfile(base_dir,datestr(now,folder_format),out_dir);
%if ~exist(save_dir,'dir'), mkdir(save_dir); end

logfile_name=sprintf('%s_%s',fullfile(base_dir,'log'),datestr(now,30));
logfile=fopen([ logfile_name '.txt' ],'w');
fprintf(logfile,'Run started at %s\n\n',datestr(now));
fprintf(logfile,[note '\n']);
fprintf(logfile,'User specified save frequency: %g minutes\n',save_freq/60);
fprintf(logfile,'Recording until: %s\n',datestr(rec_datevec));
fprintf(logfile,'Channel skew:  %g\n',analog_input.ChannelSkew);
fprintf(logfile,'Sampling rate:  %g\nChannels=[',actualrate);

for i=1:length(INCHANNELS)
	fprintf(logfile,' %g ',INCHANNELS(i));
end

fprintf(logfile,']\n\n');


% set up output

if ~isempty(OUTPUT)

	% add a for loop and make analog_output a cell array if we want to have multiple outputs?

	analog_output=analogoutput(out_device_type,out_device);
	ch=addchannel(analog_output,OUTPUT.channels);
	actualrate=setverify(analog_output,'SampleRate',OUTPUT.fs);

	if actualrate ~= fs
		error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(fs) ')' ]);
	end

	%set(analog_output,'TriggerType','Manual');
	% compute the trigger times 

	current_time=now;

	% empty means one-shot

	if isempty(OUTPUT.interval) | all(OUTPUT.interval==0)
		set(analog_output,'TriggerType','Immediate');
	else
		total_secs=etime(datevec(current_time),rec_datevec);
		output_times_sec=1:OUTPUT.interval:total_secs;

		set(analog_output,'TriggerType','Manual');
		set(analog_output,'TimerPeriod',OUTPUT.interval);
		set(analog_output,'TimerFcn',{@nyedack_output_data,logfile,OUTPUT.data});
	end

	putdata(analog_output,OUTPUT.data)

end

%set(analog_input,'SamplesAcquiredFcnCount',recording_duration);

objects{1}=analog_input;

if ~isempty(OUTPUT)
	object{2}=analog_output;
end

% record until we reach the stopping time or the quit button is pressed
% rudimentary set of buttons to pause, resume or quit
% perhaps add a button for manual triggering of the output for testing

button_figure=figure('Visible','off','Name',['Push button v.001a'],...
	'Position',[200,200,300,250],'NumberTitle','off',...
	'menubar','none','resize','off');
status_text=uicontrol(button_figure,'style','text',...
	'String','Status:  ',...
	'FontSize',15,...
	'ForegroundColor','k',...
	'units','normalized',...
	'FontWeight','bold',...
	'Position',[.1 .875 .7 .1]);
stop_button=uicontrol(button_figure,'style','pushbutton',...
	'String','Pause Acquisition',...
	'units','normalized',...
	'FontSize',15,...
	'Value',0,'Position',[.1 .5 .3 .3]);
start_button=uicontrol(button_figure,'style','pushbutton',...
	'String','Resume Acquisition',...
	'units','normalized',...
	'FontSize',15,...
	'Value',0,'Position',[.5 .5 .3 .3],...
	'Enable','off');

set(stop_button,'call',{@nyedack_stop_routine,logfile,objects,status_text,start_button,stop_button});
set(start_button,'call',{@nyedack_start_routine,logfile,objects,status_text,start_button,stop_button});
set(analog_input,'DataMissedFcn',{@nyedack_restart_routine,logfile,objects,status_text,start_button,stop_button});
set(analog_input,'RuntimeErrorFcn',{@nyedack_restart_routine,logfile,objects,status_text,start_button,stop_button});
set(analog_input,'TimerPeriod',polling_duration);

% refresh rate of scope determined by TimerPeriod

if preview_enable

	if nchannels<preview_nrows
		preview_nrows=nchannels;
	end

	refresh_string={};
	voltage_string={};

	for i=1:length(refresh_rates)
		refresh_string{i}=sprintf('</> %i ms',refresh_rates(i));
	end

	for i=1:length(voltage_scales)
		voltage_string{i}=sprintf('%.0e V',voltage_scales(i)/1e6);
	end

	ncolumns=ceil(nchannels/preview_nrows);
	preview_figure=figure('Visible','off','Name','Preview v.001a',...
		'Position',[10,10,...
		preview_nrows*preview_pxrow,...
		ncolumns*preview_pxcolumn],...
		'NumberTitle','off',...
		'menubar','none','resize','on');

	refresh_setting=uicontrol(preview_figure,'Style','popupmenu',...
		'String',refresh_string,...
		'Units','Normalized',...
		'Value',1,...
		'FontSize',11,...
		'Position',[.25 .05 .35 .1],...
		'Call',{@nyedack_set_refresh,analog_input,refresh_rates});

	refresh_val=get(refresh_setting,'value');
	cur_rate=refresh_rates(refresh_val); % rates are in ms
	preview_refresh_rate=cur_rate;

	% plot axes

	channel_axis=[];

	height=.6/preview_nrows;
	width=.8/ncolumns;
	w_spacing=.05;
	h_spacing=.02;

	for i=1:nchannels
		cur_column=ceil(i/(preview_nrows));
		idx=mod(i,preview_nrows);
		idx(idx==0)=preview_nrows;

		left_edge=(.15-.02*ncolumns)+(cur_column-1)*width+(cur_column-1)*w_spacing;
		bot_edge=(.3-.005*preview_nrows)+(idx-1)*height+(idx-1)*h_spacing;

		channel_axis(i)=axes('Units','Normalized','Position',...
			[left_edge,bot_edge,width,height],'parent',preview_figure,...
			'nextplot','add');
		channel_plot(i)=plot(NaN,NaN,'parent',channel_axis(i));
		ylabel(channel_labels{i},'FontSize',9,'parent',channel_axis(i));	

		if i>1
			set(channel_axis(i),'xtick',[],'ytick',[]);
		end

		if i==1
			xlabel('Time (s)','FontSize',11,'parent',channel_axis(i));
			set(channel_axis(i),'ytick',[]);
		end

		pos=get(channel_axis(i),'pos');
        set(channel_axis(i),'pos',[pos(1) pos(2) pos(3)-.2 pos(4)]);
        pos=get(channel_axis(i),'pos');
		voltage_setting_axis(i)=uicontrol(preview_figure,'Style','popupmenu',...
			'String',voltage_string,...
			'Units','Normalized',...
			'Value',min(6,length(voltage_scales)),...
			'FontSize',8,...
			'Position',[pos(1)+pos(3)+.05 pos(2) w_spacing*2 .1],...
			'Call',{@nyedack_set_voltage,voltage_scales,i});

		preview_voltage_scale(i)=voltage_scales(get(voltage_setting_axis(i),'value'));

	end


	disp('Note that the card polling rate is set to the refresh rate...');

	set(analog_input,'TimerPeriod',cur_rate/1e3);
	set(preview_figure,'Visible','on');

else
	preview_figure=[];
	channel_plot=[];
	channel_axis=[];
end

cleanup_object=onCleanup(@()nyedack_cleanup_routine([],[],save_dir,logfile,objects,button_figure,preview_figure));

quit_button=uicontrol(button_figure,'style','pushbutton',...
	'String','Quit Acquisition',...
	'units','normalized',...
	'FontSize',15,...
	'Value',0,'Position',[.1 .05 .7 .4],...
	'call',{@nyedack_early_quit,button_figure,preview_figure});

set(button_figure,'Visible','on');
set(analog_input,'TimerFcn',{@nyedack_dump_data,...
	recording_duration,base_dir,folder_format,out_dir,file_basename,file_format,...
	logfile,preview_figure,channel_axis,channel_plot,preview_dcoffset,status_text,note});

start(analog_input)

if ~isempty(OUTPUT)
	start(analog_output);
end

set(status_text,'string','Status:  running','ForegroundColor','g');

% pause for a millisecond, consider storing status in userdata

while now<datenum(rec_datevec)
	if ~ishandle(button_figure), break; end
	pause(1e-3);

	% get status
	
	tmp=get(status_text,'string');
	iserr=findstr(tmp,'error');

	if iserr
		warning('Error detected, attempting to reset acquisition system...');
		% TODO:  attempt !matlab -r functionname to restart everything, daqreset not enough
		%nyedack_cleanup_routine([],[],save_dir,logfile,objects,...
		%	button_figure,preview_figure);
		%nyedack_main(INCHANNELS,OUTPUT,varargin{:},'recurse',recurse+1);
	end

end

% if everything worked, copy the finish time and wrap up

if exist('PREVIEW','var') && PREVIEW.enable
	close(preview_figure)
end
