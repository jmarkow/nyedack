function nyedack_preview_data(obj,event,channel_axis)

% basically, a circular buffer is used!

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

global preview_voltage_scale;
global preview_refresh_rate;

ylimits=[-preview_voltage_scale/1e6 preview_voltage_scale/1e6];
xlimits=[0 preview_refresh_rate/1e3];

try
	[data.voltage,data.time,data.start_time]=getdata(obj,obj.SamplesAvailable);
    	data.time=data.time-data.time(1);
	for i=1:length(channel_axis)
		plot(data.time-data.time(1),data.voltage(:,i),'parent',channel_axis(i));

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
catch 
    flushdata(obj);	
end

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection

