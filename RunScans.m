function varargout = RunScans(scangroup, seq)
% RunScans(scangroup)
% Run a scan over parameters.  This function is designed to be run in one
% MATLAB instance, while MonitorAndSaveAndorScans is running in another
% instance.
% This function sets up and runs runSeq for some set of parameters,
% while MonitorAndSaveAndorScans grabs the data from the camera and saves it.
% Note that this function does not save the data at all;
% MonitorAndSaveAndorScans must be running, but this function will not
% start (or will pause) if MonitorAndSaveAndorScans is not running (or
% crashes.) This function uses a memory map (see MemoryMap) to communicate
% between the MATLAB instances.  See NaCs2015\"Running runSeq/ExpSeq and
% acquiring images on separate MATLAB instances" for details.   Nick
% Hutzler, 2 April 2015.

nargoutchk(0, 2);

if ~EnableScan.check()
    varargout{1} = '';
    varargout{2} = '';
    return;
end

resetGlobal;

p = DynProps(scangroup.getseq(1));
scanp = scangroup.runp();
nseqs = scangroup.nseq();

fprintf('Total scan points: %d\n', nseqs);

Scan = getfields(scanp, 'AndorCenter', 'BoxSize', 'FrameSize', ...
                 'NumImages', 'NumSites', 'SingleAtomSpecies', ...
                 'SingleAtomSites', 'Cutoffs', 'LoadingLogicals', ...
                 'SurvivalLoadingLogicals', 'SurvivalLogicals');

% Name of parameter to scan over
Scan.ParamName = p.ParamName('');
% Units of the parameter
Scan.ParamUnits = p.ParamUnits('');
% x-axis scale for plots.  Enter 1e-6 for micro, 1e3 for kilo, etc.
Scan.PlotScale = p.PlotScale(1);
Scan.ScanGroup = scangroup.dump();
% Parameter values to scan over.  Some helpful custom functions might be
% stack, scramble, QuasirandomList.  Parameter values are in the units used
% in the sequence.
Params = 1:nseqs;

%%
% Number of sequences to run between acquisitions of images from the
% camera.  Must be >1.  Set this to be such that the time delay between
% group is one to a few minutes.
NumPerGroup = scanp.NumPerGroup(200);
StackNum = max(ceil(NumPerGroup / length(Params)), 2);

%% Duplicate and scramble scan parameters
Scan.Params = Params;
Scan.Params = stack(Scan.Params, StackNum);
if scanp.bScramble(1)
    Scan.Params = scramble(Scan.Params);
end
Scan.NumPerGroup = length(Scan.Params);

%% Other Scan Options

% Email somebody when finished?  Options are nobody, nick, lee, yichao,
% jessie, or an email address.  Enter as a string.
Email = scanp.Email('');
if ~isempty(Email)
    Email = {['email:' Email]};
else
    Email = {};
end
% Average number of loaded atoms per parameter.  Sequence will keep running
% until this condition is fulfilled!  Input 0 to just run through one group.
% Loop check if MeanLoads output from plot_data() is > NumPerParamAvg. In
% plot_data(), set MeanLoads to either Cs and Na.
Scan.NumPerParamAvg = scanp.NumPerParamAvg(1e6);

%% Show atoms or fit options
% Show "figure 2" with all the single atom images?  Slow, but useful if you
% are looking for single atoms.
Scan.ShowAtomImages = scanp.ShowAtomImages(0);
Scan.FitType = scanp.FitType('none'); % {'exp1', 'none'};

%% Run the scan.  These things should not need editing.

% Load memory mapped variable m for communication with
% MontiorAndSaveAndorScans
m = MemoryMap;

disp(['If there are not ' int2str(Scan.NumImages) ' images per sequence, and ' int2str(Scan.NumSites) ' sites per image, abort now!'])

if Scan.NumPerGroup < 2
    error('NumPerGroup must be greater than 1.  If you want to run sequences one-at-a-time, use the command line.')
end

if length(Scan.SurvivalLoadingLogicals) ~= length(Scan.SurvivalLogicals)
    error('Number of SurvivalLoadingLogicals must equal number of SurvialLogicals')
end

if Scan.ShowAtomImages
    warning('Will display each atom image.  This is slow, use only when necessary!')
end

if mod(Scan.NumPerGroup, length(Scan.Params))
    Scan.NumPerGroup = length(Scan.Params)*ceil(Scan.NumPerGroup/length(Scan.Params));
end

% AndorConfigured is set to 0 when MontiorAndSaveAndorScans finishes saving
% a scan.  If it is still 1, then something is wrong.
if m.Data(1).AndorConfigured
    error('MonitorAndSaveAndorScans is in the middle of running, or was aborted.  Abort it, and run ResetMemoryMap.')
end

m.Data(1).ScanParamsSet = 0;
m.Data(1).NumImages = Scan.NumImages;
m.Data(1).ScanComplete = 0;
m.Data(1).NumPerParamAvg = Scan.NumPerParamAvg;
m.Data(1).CurrentSeqNum = 0;
m.Data(1).NumPerGroup = Scan.NumPerGroup;

[fname, CurrentDate, CurrentTime] = DateTimeStampFilename();
m.Data(1).TimeStamp = str2num(CurrentTime);
m.Data(1).DateStamp = str2num(CurrentDate);
file_id = [CurrentDate '_' CurrentTime];
if nargout == 2
    varargout{1} = CurrentDate;
    varargout{2} = CurrentTime;
else
    varargout{1} = file_id;
end

if exist(fname, 'file')
    error('Filename already exists!')
end

% Save scan parameters.
save(fname, 'Scan', '-v7.3');

%% Scan

% Indicate to MonitorAndSaveAndorScan that we are ready to scan.
if m.Data(1).AbortRunSeq
    error('AbortRunSeq is set to 1.  Run ResetMemoryMap and try again.')
end
if m.Data(1).PauseRunSeq
    error('PauseRunSeq is set to 1.  Run ResetMemoryMap and try again.')
end
m.Data(1).ScanParamsSet = 1;
% Once MonitorAndSaveAndorScan see that we are ready, it will configure the
% Andor and let us know when the acquisition has started.
tic
disp('Waiting for MonitorAndSaveAndorScans to set AndorConfigured = 1...')
while m.Data(1).AndorConfigured == 0
    pause(0.1)
    if toc > 10
        beep
        m.Data(1).ScanParamsSet = 0;
        warning('StartScan is aborting due to timeout.  Check that MonitorAndSaveAndorScan is running.')
        varargout{1} = '';
        varargout{2} = '';
        return
    end
end
% Set back to 0 in case we have to abort sequence.

m.Data(1).ScanParamsSet = 0;
disp(['Andor is configured and acquiring.  Starting scan ' CurrentDate '_' CurrentTime])

pause(0.1);

% Run the sequences.  This will run forever until the average number of
% loads per point is NumPerParamAvg.
runSeq(seq, 0, scangroup, Scan.Params, Email{:});

% Scan is now finished.
m.Data(1).ScanComplete = 1;
m.Data(1).NumPerGroup = 0;
disp(['Finished scan ' CurrentDate '_' CurrentTime]);
beep

end
