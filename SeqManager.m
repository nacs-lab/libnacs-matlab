%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
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

classdef SeqManager < handle
    properties(Constant, Access=private)
        cache = MutableRef();
        % To allow sequence test to run without loading the c++/python library
        test_tick_per_sec = MutableRef(0);
    end
    methods(Static)
        function mgr = get()
            cache = SeqManager.cache;
            mgr = cache.get();
            if isempty(mgr)
                pyglob = py.dict();
                py.exec('from libnacs.expseq_manager import Manager', pyglob);
                mgr = py.eval('Manager()', pyglob);
                cache.set(mgr);
            end
        end
        function override_tick_per_sec(v)
            SeqManager.test_tick_per_sec.set(v);
        end
        function v = tick_per_sec()
            v = SeqManager.test_tick_per_sec.get();
            if v == 0
                v = double(tick_per_sec(SeqManager.get()));
            end
        end
        function res = create_sequence(data)
            res = create_sequence(SeqManager.get(), PythonHack.convert_array(data));
        end
        function load_config_file(fname)
            load_config_file(SeqManager.get(), fname);
        end
        function load_config_string(config)
            load_config_string(SeqManager.get(), config);
        end

        function enable_debug(enable)
            if ~exist('enable', 'var')
                enable = true;
            end
            enable_debug(SeqManager.get(), enable);
        end
        function res = debug_enabled()
            res = debug_enabled(SeqManager.get());
        end

        function enable_dump(enable)
            if ~exist('enable', 'var')
                enable = true;
            end
            enable_dump(SeqManager.get(), enable);
        end
        function res = dump_enabled()
            res = dump_enabled(SeqManager.get());
        end
    end
end
