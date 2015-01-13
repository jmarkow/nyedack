function batch_record(INCHANNELS,OUTPUT,varargin)
%
%
% batch_record(INCHANNELS,stop_time,save_freq,note,fs,base_dir,PREVIEW)
%
% INCHANNELS
% vector of the channel(s) to record from (default [0])
%
%
% OUTPUT
% structure of output parameters
%
% OUTPUT.channel
% DACOUT channel(s) to use
%
% OUTPUT.data
% data to be fed out (must equal n of channels)
%
% OUTPUT.fs
% output sampling rate
%
% OUTPUT.interval
% how often do we want to trigger output?
%
% OUTPUT.repeat
% how often are we repeating the output?
%
% stop_time       
% time vector specifying STOP time (default [0 0 1 0])
%
% save_freq    
% how often to save to disk (in s, default: 60)
%
% note    
% string that accepts standard escape characters to include in the log (default '')
%
% fs    
% sampling rate (default 40000)
%
% base_dir
% base data directory for storing data
%
% PREVIEW
% a structure that contains the fields 'samples' and 'ylim' that
% allows you to display the logged data as it is being recorded.
% Ommission of this argument will prevent the preview from being
% displayed, and ommitting the field ylim yields a dynamically
% scaled ordinate in the preview window
%
%
% stop_time AND save_freq are vectors of the following format:
% [days hours minutes seconds]
%
% Data files are stored in an automatically maintained directory
% hierarchy.  The variable data_directory in the script is the base
% directory, then data is sorted using the following directory structure:
%
% data_directory/YEAR/MONTH/DAY/stop_time
%
% Where stop_time is the start time (in HHMMSS format)
%
% Examples:
%
% batch_record([6 7],[0 0 0 30],[0 0 0 15],'test',40e3,10e3)
%
% Records until 0 0 0 30 (12:00:30 AM) in 15 second "chunks" from channels 6
% and 7.  The output is 2 files containing 15 seconds of data,
% each in the daq format.  Shows a preview of 10e3 samples as
% they're collected.
%
% It is recommended that the user excludes "preview" as the feature
% is still VERY EXPERIMENTAL

% collect the input variables and use defaults if necessary

% preview is deprecated ATM

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETER COLLECTION %%%%%%%%%%%%%%%%%

global preview_voltage_scale;
global preview_refresh_rate;

if nargin<2 | isempty(OUTPUT), OUTPUT=[]; end
if nargin<1 | isempty(INCHANNELS), INCHANNELS=0; end

nparams=length(varargin);

restarts=0;
base_dir=fullfile(pwd,'nidaq');
fs=40e3; % sampling frequency (in Hz)
note='';
save_freq=60; % save frequency (in s)
stop_time=[100 0 0 0 ]; % when to stop recording
in_device='dev2';
out_device='dev2';
folder_format='yyyy-mm-dd';
out_dir='mat';
channel_labels={};
preview_enable=0;
preview_nrows=5;
preview_pxrow=150;
preview_pxcolumn=300;

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
		case 'in_device'
			in_device=varargin{i+1};
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
		otherwise
	end
end

refresh_rates=[ 10 20 50 100 200 500 1e3 2e3 5e3 ];
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
start_time=([datestr(now,'HHMMSS')]);

daqs=daqfind;
if length(daqs)>0
	stop(daqs);
	delete(daqs);
end


% open the analog input object

analog_input = analoginput('nidaq',in_device);
set(analog_input,'InputType','SingleEnded');
ch=addchannel(analog_input,INCHANNELS);
actualrate=setverify(analog_input,'SampleRate',fs);

% check to see if the actual sampling rate meets our specs, otherwise bail

if actualrate ~= fs
	error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(fs) ')' ]);
end

% set the parameters of the analog input object

set(analog_input,'TriggerType','Immediate')
recording_duration=save_freq*actualrate;
set(analog_input,'SamplesPerTrigger',inf)

save_dir=fullfile(base_dir,datestr(now,folder_format),out_dir);
if ~exist(save_dir,'dir'), mkdir(save_dir); end

logfile_name=fullfile(save_dir,'..','log.txt');

if exist(logfile_name,'file')
	nameflag=1;
else
	nameflag=0;
end

counter=1;
basename=logfile_name;

while nameflag
	logfile_name=sprintf('%s_%i',basename,counter);
	if exist(logfile_name,'file')
		nameflag=1;
		counter=counter+1;
	else
		nameflag=0;
	end
end

logfile=fopen(fullfile(save_dir,'..','log.txt'),'w');
fprintf(logfile,'Run started at %s\n\n',datestr(now));
fprintf(logfile,[note '\n']);
fprintf(logfile,'User specified save frequency: %g minutes\n',save_freq/60);
fprintf(logfile,'Recording until: %s\n',datestr(rec_datevec));
fprintf(logfile,'Sampling rate:  %g\nChannels=[',actualrate);

for i=1:length(INCHANNELS)
	fprintf(logfile,' %g ',INCHANNELS(i));
end

fprintf(logfile,']\n\n');


% set up output

if ~isempty(OUTPUT)

	% add a for loop and make analog_output a cell array if we want to have multiple outputs?

	analog_output=analogoutput('nidaq',out_device);
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

% start the analog input object

set(analog_input,'SamplesAcquiredFcnCount',recording_duration);
set(analog_input,'SamplesAcquiredFcn',{@nyedack_dump_data,base_dir,folder_format,out_dir,logfile,actualrate});

% this may be a kloodge, but keep attempting to record!!!

objects{1}=analog_input;

if ~isempty(OUTPUT)
	object{2}=analog_output;
end

% record until we reach the stopping time or the quit button is pressed
% rudimentary set of buttons to pause, resume or quit
% perhaps add a button for manual triggering of the output for testing

button_figure=figure('Visible','off','Name',['Push button v.001a'],...
		'Position',[200,200,600,500],'NumberTitle','off',...
		'menubar','none','resize','off');
status_text=uicontrol(button_figure,'style','text',...
		'String','Status:  ',...
		'FontSize',25,...
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
quit_button=uicontrol(button_figure,'style','pushbutton',...
		'String','Quit Acquisition',...
		'units','normalized',...
		'FontSize',15,...
		'Value',0,'Position',[.1 .05 .7 .4],...
		'call',{@nyedack_early_quit,button_figure});

set(analog_input,'DataMissedFcn',{@nyedack_restart_routine,logfile,objects,status_text,start_button,stop_button});
set(analog_input,'RuntimeErrorFcn',{@nyedack_restart_routine,logfile,objects,status_text,start_button,stop_button});
cleanup_object=onCleanup(@()nyedack_cleanup_routine([],[],save_dir,logfile,objects,button_figure));
set(button_figure,'Visible','on');
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
		voltage_string{i}=sprintf('+/- %.0e uV',voltage_scales(i));
	end

	ncolumns=ceil(nchannels/preview_nrows);
	preview_figure=figure('Visible','off','Name','Preview v.001a',...
		'Position',[400,200,...
		preview_nrows*preview_pxrow,...
		ncolumns*preview_pxcolumn],...
		'NumberTitle','off',...
		'menubar','none','resize','off');

	refresh_setting=uicontrol(preview_figure,'Style','popupmenu',...
		'String',refresh_string,...
		'Units','Normalized',...
        'Value',2,...
		'FontSize',11,...
		'Position',[.15 .05 .35 .1],...
		'Call',{@nyedack_set_refresh,analog_input,refresh_rates});

	voltage_setting=uicontrol(preview_figure,'Style','popupmenu',...
		'String',voltage_string,...
		'Units','Normalized',...
		'FontSize',11,...
		'Position',[.6 .05 .35 .1],...
		'Call',{@nyedack_set_voltage,voltage_scales});

	voltage_val=get(voltage_setting,'value');
	preview_voltage_scale=voltage_scales(voltage_val);

	refresh_val=get(refresh_setting,'value');
	cur_rate=refresh_rates(refresh_val); % rates are in ms
	preview_refresh_rate=cur_rate;

	% plot axes

	channel_axis=[];

	height=.65/preview_nrows;
	width=.8/ncolumns;

	for i=1:nchannels
		cur_column=floor(i/(preview_nrows+1))+1
		idx=mod(i,preview_nrows);
		idx(idx==0)=preview_nrows;

		left_edge=.2+(cur_column-1)*width;
		bot_edge=.25+(idx-1)*height;

		channel_axis(i)=axes('Units','Normalized','Position',...
			[left_edge,bot_edge,width*.8,height*.8],'parent',preview_figure,...
			'nextplot','add');
        channel_plot(i)=plot(NaN,NaN,'parent',channel_axis(i));
        
        if i>1
            set(channel_axis(i),'xtick',[],'ytick',[]);
        end
        
	end

	set(analog_input,'TimerPeriod',cur_rate/1e3);
	set(analog_input,'TimerFcn',{@nyedack_preview_data,channel_axis,channel_plot})
	set(preview_figure,'Visible','on');

end

start(analog_input)

if ~isempty(OUTPUT)
	start(analog_output);
end

set(status_text,'string','Status:  running','ForegroundColor','g');

% pause for a millisecond

while now<datenum(rec_datevec)
	if ~ishandle(button_figure), break; end
	pause(1e-3);
end

% if everything worked, copy the finish time and wrap up

if exist('PREVIEW','var') && PREVIEW.enable
	close(preview_figure)
end
