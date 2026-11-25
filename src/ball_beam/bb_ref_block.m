function r = bb_ref_block(t, cmd, ext)
%BB_REF_BLOCK  Ball position reference generator ("Reference/Generator" block).
%   cmd = [type; offset; amplitude; frequency_Hz]   (positions in m)
%   type: 0 constant | 1 sine | 2 square | 3 triangle | 4 external (ref_ext)
%#codegen
typ = round(cmd(1)); off = cmd(2); A = cmd(3); f = cmd(4);
switch typ
    case 1
        r = off + A*sin(2*pi*f*t);
    case 2
        r = off + A*sign(sin(2*pi*f*t));
    case 3
        r = off + A*(2/pi)*asin(sin(2*pi*f*t));
    case 4
        r = off + ext;
    otherwise
        r = off;
end
end
