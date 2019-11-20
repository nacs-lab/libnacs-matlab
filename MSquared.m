%% Copyright (c) 2019-2019, Yichao Yu <yyc1992@gmail.com>
%
% This library is free software; you can redistribute it and/or
% modify it under the terms of the GNU Lesser General Public
% License as published by the Free Software Foundation; either
% version 3.0 of the License, or (at your option) any later version.
% This library is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
% Lesser General Public License for more details.
% You should have received a copy of the GNU Lesser General Public
% License along with this library.

classdef MSquared < handle
    properties
        ms;
    end

    methods(Static)
        function res = py2matlab(pyobj)
            if isa(pyobj, 'py.str')
                res = char(pyobj);
            elseif isa(pyobj, 'py.tuple')
                nele = length(pyobj);
                res = cell(1, nele);
                for i = 1:nele
                    res{i} = MSquared.py2matlab(pyobj{i});
                end
            elseif isa(pyobj, 'py.dict')
                res = struct(pyobj);
                fields = fieldnames(res);
                for i = 1:length(fields)
                    fn = fields{i};
                    res.(fn) = MSquared.py2matlab(res.(fn));
                end
            elseif isa(pyobj, 'py.list')
                nele = length(pyobj);
                res = cell(1, nele);
                for i = 1:nele
                    res{i} = MSquared.py2matlab(pyobj{i});
                end
                if nele == 1
                    res = res{1};
                end
            elseif isa(pyobj, 'py.int')
                res = int64(pyobj);
            else
                res = pyobj;
            end
        end
    end

    methods(Access=private)
        function self = MSquared(remote, port, local)
            pyglob = py.dict();
            py.exec('from libnacs.msquared import MSquared', pyglob);
            MS = py.eval('MSquared', pyglob);
            self.ms = MS(py.tuple({remote, int32(port)}), local);
        end
    end

    methods
        function res = wait_res(self, future)
            try
                for i = 1:60
                    % Wait with timeout to give matlab time to response to user input.
                    % Wait up to 60 seconds in total.
                    res = self.ms.wait(future, 1);
                    if isa(res, 'py.dict')
                        res = MSquared.py2matlab(res);
                        return;
                    end
                end
            catch
                res = false;
            end
        end

        function res = move_wave(self, varargin)
            res = self.wait_res(self.ms.move_wave(varargin{:}));
        end
        function res = poll_move_wave(self, varargin)
            res = self.wait_res(self.ms.poll_move_wave(varargin{:}));
        end
        function res = tune_etalon(self, varargin)
            res = self.wait_res(self.ms.tune_etalon(varargin{:}));
        end
        function res = tune_resonator(self, varargin)
            res = self.wait_res(self.ms.tune_resonator(varargin{:}));
        end
        function res = fine_tune_resonator(self, varargin)
            res = self.wait_res(self.ms.fine_tune_resonator(varargin{:}));
        end
        function res = etalon_lock(self, varargin)
            res = self.wait_res(self.ms.etalon_lock(varargin{:}));
        end
        function res = etalon_lock_status(self, varargin)
            res = self.wait_res(self.ms.etalon_lock_status(varargin{:}));
        end
        function res = select_etalon_profile(self, varargin)
            res = self.wait_res(self.ms.select_etalon_profile(varargin{:}));
        end
        function res = system_status(self, varargin)
            res = self.wait_res(self.ms.system_status(varargin{:}));
        end
        function res = alignment_status(self, varargin)
            res = self.wait_res(self.ms.alignment_status(varargin{:}));
        end
        function res = set_alignment_mode(self, varargin)
            res = self.wait_res(self.ms.set_alignment_mode(varargin{:}));
        end
        function res = alignment_adjust_x(self, varargin)
            res = self.wait_res(self.ms.alignment_adjust_x(varargin{:}));
        end
        function res = alignment_adjust_y(self, varargin)
            res = self.wait_res(self.ms.alignment_adjust_y(varargin{:}));
        end
        function res = wavelength_range(self, varargin)
            res = self.wait_res(self.ms.wavelength_range(varargin{:}));
        end

        % Frequency in GHz
        function res = move_freq(self, freq)
            % Wavelength in nm
            res = move_wave(self, 299792458 / freq);
        end

        function self = start(self)
            self.ms.start();
        end
        function self = stop(self)
            self.ms.stop();
        end

        function delete(self)
            self.ms.stop();
        end
    end

    properties(Constant, Access=private)
        cache = containers.Map();
    end

    methods(Static)
        function dropAll()
            remove(MSquared.cache, keys(MSquared.cache));
        end
        function res = get(remote, port, local)
            cache = MSquared.cache;
            key = sprintf('%s/%d/%s', remote, port, local);
            if isKey(cache, key)
                res = cache(key);
                if ~isempty(res) && isvalid(res)
                    res.start();
                    return;
                end
            end
            res = MSquared(remote, port, local);
            cache(key) = res;
        end
    end
end
