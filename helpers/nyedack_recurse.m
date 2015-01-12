function recurse(obj,event,save_directory,logfile,channels,output,stop_time,save_freq,note,fs,base_dir,PREVIEW,button_figure,restarts)

done_signal=fopen(fullfile(save_directory,'..','.done_recording'),'w');
fclose(done_signal);
fclose(logfile);
daqreset;
disp('Hit a data missed event or run-time error, restarting!');	

if nargin==13
	close(button_figure);
end

restarts=restarts+1;
if restarts<5
	batch_record(channels,output,stop_time,save_freq,note,fs,base_dir,PREVIEW);
end
