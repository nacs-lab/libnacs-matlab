classdef OpContext < handle
    % this is where the global SeqVals live that represent each atom
   properties
        sites = {};
        L;
   end
   methods
       function self = OpContext(L)
            self.L = L;
            sites = cell(1,L);
            for i = 1:L
                sites{i} = SeqVal(SeqVal.HGlobal, {i - 1}, self);
            end
            self.sites = sites;
       end
       function res = Z(self,i)
            res = self.sites{i};
       end
   end
end