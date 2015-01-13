function nyedack_set_voltage(obj,event,voltage_scales)
%
%

global preview_refresh_rate;
idx=get(obj,'value');
preview_refresh_rate=voltage_scale(idx);

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection
