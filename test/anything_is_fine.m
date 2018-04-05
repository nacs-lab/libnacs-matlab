% define simulation structure
clear p
p.PAswitch = 1;
p.AmpPAAOM = 0.1;
p.bRotateBField = 1;
p.angleMergeBfield = 45;
p.Bzmerge = 0.13;
p.bMergeOP = 0;
p.DoDetection = 1;
p.TCsMergeBlast = 20e-6;
p.TMergeWait = [0, 0.2, 0.5, 1, 2, 5, 10, 20, 50]*1e-3;
p.ParamName = "TMergeWait";
p.ParamUnits = "ms";
p.PlotScale = 1e-3; %used for plotting

% run simulation
StartScan(ScanSeq(p, struct()));
