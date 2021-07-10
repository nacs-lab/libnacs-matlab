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

classdef PythonHack
    properties(Constant)
        need_array_convert = ~PythonHack.check_array_convert();
        pyconvert = MutableRef();
    end

    methods(Static)
        function res = check_array_convert()
            % Workaround MATLAB use of the deprecated `array.array.fromstring`
            % which was removed in python 3.9.
            % Note that this workaround doesn't work for MATLAB R2021a since
            % python 3.9 is explicitly rejected by a version check on loading.
            res = false;
            try
                py.dict(pyargs('a', int8([0, 1])));
                res = true;
            catch
            end
        end
        function ary = convert_array(ary)
            if ~PythonHack.need_array_convert
                return;
            end
            pyconvert = PythonHack.pyconvert.get();
            if isempty(pyconvert)
                pyglob = py.dict();
                py.exec(['def convert(e, b):', char(10), ...
                         '  e.frombytes(b.encode("latin_1"))', char(10), ...
                         '  return e', char(10)], pyglob);
                pyconvert = py.eval('convert', pyglob);
                PythonHack.pyconvert.set(pyconvert);
            end
            ary = pyconvert(zeros(0, class(ary)), char(typecast(ary, 'uint8')));
        end
    end
end
