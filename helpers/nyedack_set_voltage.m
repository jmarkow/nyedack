function nyedack_set_voltage(obj,event,voltage_scales,axis_number)
%
%

global preview_voltage_scale;
idx=get(obj,'value');
preview_voltage_scale(axis_number)=voltage_scales(idx);
