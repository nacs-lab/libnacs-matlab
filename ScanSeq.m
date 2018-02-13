classdef ScanSeq < handle
    %Class for running scans
    % Example
    
    properties
        p; %structure for storing scans
        flds; %field names
        fldLengths; %length fields
        scanIdx; %index of which fields are being scanned
        scanLength; %array of scan lengths
        scanLengthTot; %total number of runs
    end
    
    methods
        function self = ScanSeq(p)
            %initiate a scan sequence with a structure array
            self.p = p;
            self = getDim(self); % get all dimensions
        end
        
        function self = getDim(self)
            p = self.p;
            pLength = length(p);
            
            fldLengths = [];
            for m = 1:length(p)
                flds = fieldnames(p(m));
                for i = 1:length(flds)
                    fldLengths(m,i) = length( p(m).(flds{i}) );
                end
                
                %check all varibles are 1 or same
                scanIdx(m) = find( fldLengths(m,:) > 1); %find non-zero length lists
                scanLength(m) = max( fldLengths(m,:) );
                if ~all( fldLengths(scanIdx(m))/scanLength(m) )
                    error('All lists need to be same length in scan structure.');
                end
            end
            
            p.scanLengthTot = sum(scanLength); %total number of scan points
            %This scanLengthTot will be used in StartScan with Params = 1:scanLengthTot
            p.ScanIdx = scanIdx;
            p.scanLength = scanLength;
            p.fldLengths = fldLengths;
            p.flds = flds;
        end
        
        function po = getSingle(self)
            %Output a single structure with all fields of length 1.  Use at
            %beg of NaCsSingleAtom.m
            p = self.p;
            
            tmp = [];
            for m = 1:length(p)
                tmp = [tmp m*ones(1, self.scanLength(m))];
            end
            mscan = tmp(idx);
            
            sb = 0;
            if mscan > 1
                for m = 1:(mscan-1)
                    sb = sb + self.scanLength(m);
                end
            end
            iscan = idx - sb;
            
            po = p(mscan); %convert to single structure
            scanIdx2 = self.scanIdx(m); %indices of all scans for single structure
            for i = scanIdx2
                fldlist = po.(self.flds{i});
                po.(self.flds{i}) = fldlist(iscan);
            end
        end
        
        function self = defineEmpty(self)
            % If any fields are empty, set to first one
            p = self.p;
            fields = fieldnames(p);
            for i = 1:length(p)
                for m = 1:length(fields)
                    if isempty( getfield(p(i), fields{m}) )
                        p(i) = setfield( p(i), fields{m}, getfield(p(1), fields{m}) );
                    end
                end
            end
            self.p = p;
        end
    end
end

