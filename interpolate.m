%%

function y=interpolate(x, x0, x1, vals)
  dx = x1 - x0;
  x = x - x0;
  y = zeros(size(x));
  nv = length(vals);
  xscaled = x * (nv - 1) / dx;
  for i = 1:length(x)
    xe = xscaled(i);
    if xe <= 0
      y(i) = vals(1);
    elseif xe >= (nv - 1)
      y(i) = vals(end);
    else
      lo = floor(xe);
      xrem = xe - lo;
      vlo = vals(lo + 1);
      if xrem == 0
        y(i) = vlo;
      else
        y(i) = vlo * (1 - xrem) + vals(lo + 2) * xrem;
      end
    end
  end
end
