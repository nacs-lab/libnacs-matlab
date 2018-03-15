classdef ScanSeq < handle
    %Class for running scans
    % Example

    properties
        p; %structure for storing scans
        fields; %field names
        fldLengths; %length fields
        scanIdx; %index of which fields are being scanned
        scanLength; %array of scan lengths
        scanLengthTot; %total number of runs
    end

    methods
        function self = ScanSeq(p, idx)
            if nargin < 2
                idx = 1;
            end

            %initiate a scan sequence with a structure array
            self.p = p;
            self = defineEmpty(self, idx); %defines all empty cells.
            self = getDim(self); % get all dimensions
        end

        function self = getDim(self)
            p = self.p;
            pLength = length(p);
            fldLengths = [];
            for m = 1:length(p)
                fields = fieldnames(p(m));
                for i = 1:length(fields)
                    fldLengths(m,i) = length( p(m).(fields{i}) );
                end
                %check all varibles are 1 or same
                scanIdx{m} = find( fldLengths(m,:) > 1 ); %find non-zero length lists
                if isempty(scanIdx{m})
                    %If all variables are length 1, then scan first
                    scanIdx{m} = [1];
                end
                scanLength(m) = max( fldLengths(m,:) ); %find the maximum one
                %make sure all others are same length as max
                if any( fldLengths(m,scanIdx{m})/scanLength(m) - 1)
                    error('All variable lists in ScanSeq need to be same length.');
                end
            end
            self.scanLengthTot = sum(scanLength); %total number of scan points
            %This scanLengthTot will be used in StartScan with Params = 1:scanLengthTot
            self.scanIdx = scanIdx;
            self.scanLength = scanLength;
            self.fldLengths = fldLengths;
            self.fields = fields;
            disp(['Total scan points = ' num2str(self.scanLengthTot) '']);
        end

        function pout = getSingle(self, idx)
            %Output a single structure with all fields of length 1.  Use at
            %beg of NaCsSingleAtom.m
            p = self.p;
            if idx > self.scanLengthTot
                error('idx is larger than total ScanSeq length.');
            end

            %mList is a matrix with [1 1 1 2 2 2 3 3 3], so that mList(idx)
            %gives the m value for the scan.
            mList = [];
            for m = 1:length(p)
                mList = [mList m*ones(1, self.scanLength(m))];
            end
            mscan = mList(idx); %using p(mscan) for scan

            %for scanned variables, find p(mscan).var1(iscan)
            delta = 0;
            if mscan > 1
                for m = 1:(mscan-1)
                    delta = delta + self.scanLength(m);
                end
            end
            iscan = idx - delta; %index for scan of single structure

            %convert to single structure
            pout = p(mscan);

            %convert variable lists to single
            scanIdx = self.scanIdx{mscan}; %indices of all scans for single structure
            for i = scanIdx
                fldlist = pout.(self.fields{i}); %get list of fields being scanned
                pout.(self.fields{i}) = fldlist(iscan);
            end
        end

        function self = defineEmpty(self, idx)
            % If any fields are empty, set to p(idx)
            if nargin < 2
                idx = 1;
            end
            p = self.p;

            fields = fieldnames(p); %self.fields; % same as fields = fieldnames(p);
            for i = 1:length(p)
                for m = 1:length(fields)
                    if isempty( getfield(p(i), fields{m}) )
                        p(i) = setfield( p(i), fields{m}, getfield(p(idx),fields{m}) );
                    end
                end
            end
            self.p = p;
            %self = getDim(self);
        end
    end
end
