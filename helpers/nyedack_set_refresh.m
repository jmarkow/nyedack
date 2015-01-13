function nyedack_set_refresh(obj,event,analog_input,refresh_rates)
%
%

global preview_refresh_rate;
idx=get(obj,'value');
preview_refresh_rate=refresh_rates(idx);
set(analog_input,'TimerPeriod',preview_refresh_rate/1e3);
