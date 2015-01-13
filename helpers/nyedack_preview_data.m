function preview_data(obj,event,channel_axis)

% basically, a circular buffer is used!

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

global preview_voltage_scale;

ylimits=[-preview_voltage_scale/1e6 preview_voltage_scale/1e6];

try
	[data.voltage,data.time,data.start_time]=getdata(obj,obj.SamplesAvailable);
	data.fs=actualrate;
	[nsamples,nchannels]=size(data.voltage);
	for i=1:length(channel_axis)
		plot(data.time-data.time(1),data.voltage(:,i),'parent',channel_axis(i));
		ylim(ylimits);
		drawnow;
	end
catch
	flushdata(obj);
end

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection

