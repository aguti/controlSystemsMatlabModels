function rp_view(ax, name)
%RP_VIEW  Preset viewpoints for the rotary pendulum scene drawn by rp_draw.
%   rp_view(ax, 'iso')     3D perspective (default)
%   rp_view(ax, 'top')     seen from above: arm angle theta
%   rp_view(ax, 'front')   seen along -y
%   rp_view(ax, 'side')    seen along +x
switch lower(name)
    case 'top',   view(ax, 0, 90);
    case 'front', view(ax, 0, 0);
    case 'side',  view(ax, 90, 0);
    otherwise,    view(ax, 62, 20);
end
end
