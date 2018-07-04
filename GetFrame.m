function F = GetFrame(n)
    if ~exist('n', 'var')
        n = 2;
    elseif n < 1
        error('Invalid frame index');
    else
        n = n + 1;
    end
    SI = dbstack();
    if n > length(SI)
        F = struct('file', '', 'name', '', 'line', 0);
    else
        F = SI(n);
    end
end
