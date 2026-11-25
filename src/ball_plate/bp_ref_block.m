function r = bp_ref_block(t, cmd, ext)
%BP_REF_BLOCK  Ball position reference generator ("Reference/Generator" block).
%   cmd = [type; cx; cy; amplitude; frequency_Hz]   (positions in m)
%   ext = [rx; ry] from the workspace variable ref_ext
%   type: 0 point (cx, cy)
%         1 circle of radius A around (cx, cy), counter-clockwise
%         2 square: jumps between the four corners (cx +- A, cy +- A)
%         3 figure of eight (Lissajous 1:2) of half width A
%         4 external (ref_ext) + (cx, cy)
%#codegen
typ = round(cmd(1)); c = [cmd(2); cmd(3)]; A = cmd(4); w = 2*pi*cmd(5);
switch typ
    case 1
        r = c + A*[cos(w*t); sin(w*t)];
    case 2
        r = c + A*[sign(sin(w*t + pi/4)); sign(cos(w*t + pi/4))];
    case 3
        r = c + A*[sin(w*t); 0.5*sin(2*w*t)];
    case 4
        r = c + ext(:);
    otherwise
        r = c;
end
end
