function nyedack_preview_data(obj,event,channel_axis,channel_plot,actualrate)
% preview data still not quite working correctly, need some more time with
% this...
% basically, a circular buffer is used!

%disp('Dumping data...');

% if getdata trips up clear the buffer and keep going!

global preview_voltage_scale;
global preview_refresh_rate;

ylimits=[-preview_voltage_scale/1e6 preview_voltage_scale/1e6];
xlimits=[0 preview_refresh_rate/1e3];

try
	[data]=peekdata(obj,obj.SamplesAvailable);
    	time=[1:length(data)]/actualrate;
	for i=1:length(channel_axis)
		set(channel_plot(i),'XData',time,'YData',data(:,i));
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
catch err
    warning('No samples found, consider decreasing refresh rate');
    %flushdata(obj);	
end

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection

