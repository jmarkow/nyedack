function output=batch_record_cli(PARAM_FILE,CHANNELS,LENGTH,SAVE_FS,SR,BASEDIR,LABELS,BIRD_NAME,YLIM)
%
% output=batch_record_cli(PARAM_FILE,CHANNELS,LENGTH,SAVE_FS,SR,BASEDIR,LABELS,BIRD_NAME,YLIM)
%
% A simple CLI interface to batch_record
%
% Normally, the settings are created using record_settings.m, and the filename is passed as the only
% parameter.  Otherwise, each setting must be specified manually.
%
% PARAM_FILE (string)
% file that contains the recording parameters
%
% CHANNELS (vector)
% channels to acquire from
%
% LENGTH (vector)
% [DD HH MM SS], specify the stopping time
%
% SAVE_FS (vector)
% [DD HH MM SS], frequency to dump to disk
%
% SR (scalar)
% sampling rate
%
% BASEDIR (string)
% base directory for storing data
%
% LABELS (cell array)
% cell array of string to label each channel
%
% BIRD_NAME (string)
% name for the bird
%
% YLIM (vector)
% ylimits for the preview window
% 

if nargin==1, load([PARAM_FILE]); end

if ~exist('BIRD_NAME','var')
       	BIRD_NAME='Pretty bird'; 
end

if ~exist('LABELS','var')
	for i=1:length(CHANNELS), ch_label{i}=['COLUMN ' num2str(i) '-->NIDAQ ' num2str(CHANNELS(i))]; end
else
	for i=1:length(CHANNELS), ch_label{i}=['COLUMN ' num2str(i) '-->NIDAQ ' num2str(CHANNELS(i)) '--->' LABELS{i}]; end
end
if ~exist('BASEDIR','var')
       	BASEDIR='E:\chronic_data';
end
if ~exist('SR','var')
	SR=40e3; 
end

if exist('YLIM','var')
	preview.ylim=YLIM;
	preview.ylabels=LABELS;
	preview.samples=10e3;
end


divider='==========';

note=[ divider ' Channels ' divider '\n' ];
for i=1:length(ch_label), note=[ note '\n' ch_label{i}]; end
note=[ note '\n\n' divider ' Channels ' divider '\n\n' ];

note=[note 'Bird Name:  ' BIRD_NAME];

if exist('preview','var')
	batch_record(CHANNELS,[],LENGTH,SAVE_FS,note,SR,BASEDIR,preview); % removed preview as a quick fix
else
	batch_record(CHANNELS,[],LENGTH,SAVE_FS,note,SR,BASEDIR);
end


