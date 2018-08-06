function res = rabiLine(det, t, Omega)
    Omega2 = Omega.^2;
    OmegaG2 = det.^2 + Omega2;
    res = Omega2 ./ OmegaG2 .* sin(sqrt(OmegaG2) .* t ./ 2).^2;
end
