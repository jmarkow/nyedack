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

