function batch_record(CHANNELS,OUTPUT,TIME,SAVE_FREQ,NOTE,SR,BASE_DIR,PREVIEW,RESTARTS)
%
%
% batch_record(CHANNELS,TIME,SAVE_FREQ,NOTE,SR,BASE_DIR,PREVIEW)
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
% OUTPUT.SR
% output sampling rate
%
% OUTPUT.interval
% how often do we want to trigger output?
%
% OUTPUT.repeat
% how often are we repeating the output?
%
% TIME       
% time vector specifying STOP time (default [0 0 1 0])
%
% SAVE_FREQ    
% when to start streaming to a new data file (default [0 0 0 15])
%
% NOTE    
% string that accepts standard escape characters to include in the log (default '')
%
% SR    
% sampling rate (default 40000)
%
% BASE_DIR
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
% TIME AND SAVE_FREQ are vectors of the following format:
% [days hours minutes seconds]
%
% Data files are stored in an automatically maintained directory
% hierarchy.  The variable data_directory in the script is the base
% directory, then data is sorted using the following directory structure:
%
% data_directory/YEAR/MONTH/DAY/TIME
%
% Where TIME is the start time (in HHMMSS format)
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

if nargin<9 | isempty(RESTARTS), RESTARTS=0; end
if nargin<7 | isempty(BASE_DIR), BASE_DIR='E:\chronic_data'; end
if nargin<6 | isempty(SR), SR=40000; end
if nargin<5 | isempty(NOTE), NOTE=''; end
if nargin<4 | isempty(SAVE_FREQ), SAVE_FREQ=[0 0 1 0]; end
if nargin<3 | isempty(TIME), TIME=inf; end
if nargin<2, OUTPUT=[]; end
if nargin==0, CHANNELS=[0]; end

rec_datevec=datevec(addtodate(today,TIME(1),'day'));
rec_datevec(4:6)=TIME(2:4);
disp(['Will record until ' datestr(rec_datevec)]);

% compute the save frequency in seconds

save_fs_secs=sum(SAVE_FREQ.*[86400 3600 60 1]);
disp(['Will save every ' num2str(SAVE_FREQ(1)) ' days ' num2str(SAVE_FREQ(2)) ...
	' hours ' num2str(SAVE_FREQ(3)) ' minutes and ' num2str(SAVE_FREQ(4)) ' seconds ']);

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

if ~exist(fullfile(BASE_DIR,year,month,day,start_time,'mat'),'dir')
	mkdir(fullfile(BASE_DIR,year,month,day,start_time,'mat'))
end

% the final directory is the start time in HHMMSS format

save_directory=fullfile(BASE_DIR,year,month,day,start_time,'mat');

% open the analog input object

AI = analoginput('nidaq','dev2');
set(AI,'InputType','SingleEnded');
ch=addchannel(AI,CHANNELS);
actualrate=setverify(AI,'SampleRate',SR);

% check to see if the actual sampling rate meets our specs, otherwise bail

if actualrate ~= SR
	error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(SR) ')' ]);
end

% start logging

logfile=fopen(fullfile(save_directory,'..','log.txt'),'w');
fprintf(logfile,'Run started at %s\n\n',datestr(now));
fprintf(logfile,[NOTE '\n']);
fprintf(logfile,'User specified end time: %g days %g hours %g minutes %g seconds\n',TIME(1),TIME(2),TIME(3),TIME(4));
fprintf(logfile,'User specified save frequency: %g days %g hours %g minutes %g seconds\n',SAVE_FREQ(1),SAVE_FREQ(2),SAVE_FREQ(3),SAVE_FREQ(4));
fprintf(logfile,'Recording until: %s\n',datestr(rec_datevec));
fprintf(logfile,'Sampling rate:  %g\nChannels=[',actualrate);

for i=1:length(CHANNELS)
	fprintf(logfile,' %g ',CHANNELS(i));
end
fprintf(logfile,']\n\n');

% set the parameters of the analog input object

set(AI,'TriggerType','Immediate')
recording_duration=save_fs_secs*actualrate;
set(AI,'SamplesPerTrigger',inf)

if ~isempty(OUTPUT)

	% add a for loop and make AO a cell array if we want to have multiple outputs?

	AO=analogoutput('nidaq','dev2');
	ch=addchannel(AO,OUTPUT.channels);
	actualrate=setverify(AO,'SampleRate',OUTPUT.SR);

	if actualrate ~= SR
		error(['Actual sampling rate (' num2str(actualrate) ') not equal to target (' num2str(SR) ')' ]);
	end

	%set(AO,'TriggerType','Manual');
	% compute the trigger times 

	current_time=now;
   

	% empty means one-shot

	if isempty(OUTPUT.interval) | all(OUTPUT.interval==0)
		set(AO,'TriggerType','Immediate');
	else
		total_secs=etime(datevec(current_time),rec_datevec);
		output_interval_secs=sum(OUTPUT.interval.*[86400 3600 60 1]);
		output_times_sec=1:output_interval_secs:total_secs;

		set(AO,'TriggerType','Manual');
		set(AO,'TimerPeriod',output_interval_secs);
		set(AO,'TimerFcn',{@output_data,logfile,OUTPUT.data});
	end


	putdata(AO,OUTPUT.data)

end

% uncomment the next two lines to stream directly to disk to avoid memory limitations
% note that you'll need to specify temp_directory for this to work

% start the analog input object

set(AI,'SamplesAcquiredFcnCount',recording_duration);
set(AI,'SamplesAcquiredFcn',{@dump_data,save_directory,logfile,actualrate});

% this may be a kloodge, but keep attempting to record!!!

objects{1}=AI;

if ~isempty(OUTPUT)
	object{2}=AO;
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

set(AI,'DataMissedFcn',{@restart_routine,logfile,objects,status_text,start_button,stop_button});
set(AI,'RuntimeErrorFcn',{@restart_routine,logfile,objects,status_text,start_button,stop_button});
cleanup_object=onCleanup(@()cleanup_routine([],[],save_directory,logfile,objects,button_figure));

start(AI)

if ~isempty(OUTPUT)
	start(AO);
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

function stop_routine(obj,event,logfile,objects,status_text,start_button,stop_button)
	
	disp('Pausing acquisition...');

	for i=1:length(objects)
		stop(objects{i});
	end

	counter=0;
	for i=1:length(objects)
		if strcmpi(get(objects{i},'Running'),'Off')
			counter=counter+1;
		end
	end


	set(start_button,'enable','on');
	set(stop_button,'enable','off');
	set(status_text,'string','Status:  stopped','ForegroundColor','r');
	disp(['Stopped ' num2str(counter) ' out of ' num2str(length(objects)) ' objects']);
	fprintf(logfile,'\nRun stopped at %s',datestr(now));
end

function start_routine(obj,event,logfile,objects,status_text,start_button,stop_button)

	disp('Resuming acquisition...');

	for i=1:length(objects)
		start(objects{i});
	end
	
	counter=0;
	for i=1:length(objects)
		if strcmpi(get(objects{i},'Running'),'On')
			counter=counter+1;
		end
	end

	set(start_button,'enable','off');
	set(stop_button,'enable','on');
	set(status_text,'string','Status:  running','ForegroundColor','g');
	disp(['Resumed ' num2str(counter) ' out of ' num2str(length(objects)) ' objects']);
	fprintf(logfile,'\nRun restarted at %s\n',datestr(now));
end

function restart_routine(obj,event,logfile,objects,status_text,start_button,stop_button)

	disp('Error occurred, restarting the acquisition...')
	
	fprintf(logfile,'\nError encountered at%s\n',datestr(now));
	disp('Stopping all objects and flushing data');

	for i=1:length(objects)
		stop(objects{i});
		flushdata(objects{i});
	end

	counter=0;
	for i=1:length(objects)
		if strcmpi(get(objects{i},'Running'),'Off')
			counter=counter+1;
		end
	end

	disp(['Stopped ' num2str(counter) ' out of ' num2str(length(objects)) ' objects']);

	disp('Pausing for ten seconds...');

	set(start_button,'enable','off');
	set(stop_button,'enable','off');
	pause(10);
	set(status_text,'string','Status:  error (pausing and restarting)','ForegroundColor','g');

	for i=1:length(objects)
		start(objects{i});
	end
	
	counter=0;
	for i=1:length(objects)
		if strcmpi(get(objects{i},'Running'),'On')
			counter=counter+1;
		end
	end

	disp(['Resumed ' num2str(counter) ' out of ' num2str(length(objects)) ' objects']);

	set(start_button,'enable','off');
	set(stop_button,'enable','on');

	set(status_text,'string','Status:  running','ForegroundColor','g');
	fprintf(logfile,'\nRun restarted at %s\n',datestr(now));

end

function cleanup_routine(obj,event,save_directory,logfile,objects,figure)

	disp('Cleaning up and quitting...');

	fprintf(logfile,'\nRun complete at %s',datestr(now));
	done_signal=fopen(fullfile(save_directory,'..','.done_recording'),'w');
	fclose(done_signal);
	fclose(logfile);
	for i=1:length(objects)
		stop(objects{i});delete(objects{i});
	end
	daqreset;
	disp('Run complete!');

	if nargin==6
		if ishandle(figure)
			close(figure);
		end
	end

end

function dump_data(obj,event,save_directory,logfile,actualrate)

	% basically, a circular buffer is used!

    	%disp('Dumping data...');
	
	% if getdata trips up clear the buffer and keep going!

	try
		[data.voltage,data.time,data.start_time]=getdata(obj,obj.SamplesAvailable);
		datafile_name=[ 'data_' datestr(now,30) '.mat' ];
		data.sampling_rate=actualrate;
		save(fullfile(save_directory,datafile_name),'data');
		fprintf(logfile,'%s saved successfully at %s\n',fullfile(save_directory,datafile_name),datestr(now));
		disp([ fullfile(save_directory,datafile_name) ' saved successfully at ' datestr(now) ]);    
	catch
		flushdata(obj);
	end

	% comment this out to approximate a circular buffer
	%flushdata(AI);	% flush residual samples accumulated during data collection
end

function output_data(obj,event,logfile,output_data)
	trigger(obj);
	fprintf(logfile,'Triggered at %s\n', datestr(now));
	disp(['Trigger event occurred at ' datestr(now)]);
	putdata(obj,output_data);
end

function recurse(obj,event,save_directory,logfile,CHANNELS,OUTPUT,TIME,SAVE_FREQ,NOTE,SR,BASE_DIR,PREVIEW,button_figure,RESTARTS)

	done_signal=fopen(fullfile(save_directory,'..','.done_recording'),'w');
	fclose(done_signal);
	fclose(logfile);
	daqreset;
	disp('Hit a data missed event or run-time error, restarting!');	

	if nargin==13
		close(button_figure);
	end

	RESTARTS=RESTARTS+1;
	if RESTARTS<5
		batch_record(CHANNELS,OUTPUT,TIME,SAVE_FREQ,NOTE,SR,BASE_DIR,PREVIEW);
	end
end

function early_quit(obj,event,button_figure)
	delete(button_figure)
end
