function early_quit(obj,event,button_figure,preview_figure)
%
%
%

delete(button_figure)

if nargin==4
	if ishandle(preview_figure)
		delete(preview_figure);
	end
end
