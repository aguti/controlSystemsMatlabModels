function bb_view(ax, name)
%BB_VIEW  Preset viewpoints for the ball and beam scene drawn by bb_draw.
%   bb_view(ax, 'iso')     3D perspective (default)
%   bb_view(ax, 'front')   seen from the front (-y): beam angle in true size
%   bb_view(ax, 'top')     seen from above
%   bb_view(ax, 'side')    seen along the beam (+x)
switch lower(name)
    case 'front', view(ax, 0, 0);
    case 'top',   view(ax, 0, 90);
    case 'side',  view(ax, 90, 0);
    otherwise,    view(ax, -28, 16);
end
end
