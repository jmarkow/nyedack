function batch_record(CHANNELS,OUTPUT,stop_time,save_freq,note,fs,base_dir,PREVIEW,restarts)
%
%
% batch_record(CHANNELS,stop_time,save_freq,note,fs,base_dir,PREVIEW)
%
% CHANNELS
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

if nargin<2 | isempty(OUTPUT), OUTPUT=[]; end
if nargin<1 | isempty(CHANNELS), CHANNELS=0; end

nparams=length(varargin);

restarts=0;
base_dir=fullfile(pwd,'nidaq');
fs=40e3; % sampling frequency (in Hz)
note='';
save_freq=60; % save frequency (in s)
stop_time=[inf 0 0 0 ]; % when to stop recording
in_device='dev2';
out_device='dev2';
folder_format='yyyy-mm-dd';
out_dir='mat';

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
		otherwise
	end
end

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

day=datestr(now,'dd');
month=datestr(now,'mm');
year=datestr(now,'yyyy');

start_time=([datestr(now,'HHMMSS')]);

daqs=daqfind;
if length(daqs)>0
	stop(daqs);
	delete(daqs);
end

logfile=fopen(fullfile(save_dir,'..','log.txt'),'w');
fprintf(logfile,'Run started at %s\n\n',datestr(now));
fprintf(logfile,[note '\n']);
fprintf(logfile,'User specified save frequency: %g minutes\n',save_fs/60);
fprintf(logfile,'Recording until: %s\n',datestr(rec_datevec));
fprintf(logfile,'Sampling rate:  %g\nChannels=[',actualrate);

for i=1:length(CHANNELS)
	fprintf(logfile,' %g ',CHANNELS(i));
end
fprintf(logfile,']\n\n');

% current save_dir can store logfile

save_dir=fullfile(base_dir,datestr(now,folder_format),'mat');

if ~exist(save_dir,'dir'), mkdir(save_dir); end


% open the analog input object

analog_input = analoginput('nidaq',in_device);
set(analog_input,'InputType','SingleEnded');
ch=addchannel(analog_input,CHANNELS);
actualrate=setverify(analog_input,'SampleRate',fs);

% check to see if the actual sampling rate meets our specs, otherwise bail

if actualrate ~= fs
	error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(fs) ')' ]);
end

% set the parameters of the analog input object

set(analog_input,'TriggerType','Immediate')
recording_duration=save_freq*actualrate;
set(analog_input,'SamplesPerTrigger',inf)

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
		set(analog_output,'TimerFcn',{@output_data,logfile,OUTPUT.data});
	end

	putdata(analog_output,OUTPUT.data)

end

% start the analog input object

set(analog_input,'SamplesAcquiredFcnCount',recording_duration);
set(analog_input,'SamplesAcquiredFcn',{@dump_data,save_dir,logfile,actualrate});

% this may be a kloodge, but keep attempting to record!!!

objects{1}=analog_input;

if ~isempty(OUTPUT)
	object{2}=analog_output;
end

button_figure=figure('Visible','on','Name',['Push button v.001a'],...
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

set(stop_button,'call',{@stop_routine,logfile,objects,status_text,start_button,stop_button});
set(start_button,'call',{@start_routine,logfile,objects,status_text,start_button,stop_button});
quit_button=uicontrol(button_figure,'style','pushbutton',...
		'String','Quit Acquisition',...
		'units','normalized',...
		'FontSize',15,...
		'Value',0,'Position',[.1 .05 .7 .4],...
		'call',{@early_quit,button_figure});

set(analog_input,'DataMissedFcn',{@restart_routine,logfile,objects,status_text,start_button,stop_button});
set(analog_input,'RuntimeErrorFcn',{@restart_routine,logfile,objects,status_text,start_button,stop_button});
cleanup_object=onCleanup(@()cleanup_routine([],[],save_dir,logfile,objects,button_figure));

start(analog_input)

if ~isempty(OUTPUT)
	start(analog_output);
end


set(status_text,'string','Status:  running','ForegroundColor','g');


% record until we reach the stopping time or the quit button is pressed

% rudimentary set of buttons to pause, resume or quit

% perhaps add a button for manual triggering of the output for testing


% pause for a millisecond

while now<datenum(rec_datevec)
	if ~ishandle(button_figure), break; end
    	pause(1e-3);
end

% if everything worked, copy the finish time and wrap up

if exist('PREVIEW','var') && PREVIEW.enable
	close(preview_window)
end

end



