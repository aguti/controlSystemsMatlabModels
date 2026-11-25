function bp_view(ax, name)
%BP_VIEW  Preset viewpoints for the ball and plate scene drawn by bp_draw.
%   bp_view(ax, 'iso')     3D perspective (default)
%   bp_view(ax, 'top')     seen from above (camera view)
%   bp_view(ax, 'front')   seen from -y: tilt alpha in true size
%   bp_view(ax, 'side')    seen from +x: tilt beta in true size
switch lower(name)
    case 'top',   view(ax, 0, 90);
    case 'front', view(ax, 0, 0);
    case 'side',  view(ax, 90, 0);
    otherwise,    view(ax, -35, 28);
end
end
