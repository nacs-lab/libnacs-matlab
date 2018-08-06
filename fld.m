function r = fld(x, y)
    %% This is the best way I can find to do this.
    % The first line is the julia implementation but it doesn't seem to
    % work....
    % Test case:
    %   x = -0.097076000000000023
    %   y = 0.0000020000000000000003
    % Expected answer:
    %   -48539
    r0 = round((x - rem(x, y)) / y);
    for r1 = (r0 - 1):(r0 + 1)
        if r1 * y > x
            r = r1 - 1;
            return;
        end
    end
    r = r0 + 1;
end
