function nyedack_set_voltage(obj,event,voltage_scales)
%
%

global preview_voltage_scale;
idx=get(obj,'value');
preview_voltage_scale=voltage_scales(idx);

% comment this out to approximate a circular buffer
%flushdata(AI);	% flush residual samples accumulated during data collection
