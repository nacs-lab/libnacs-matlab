%% Copyright (c) 2021-2021, Yichao Yu <yyc1992@gmail.com>
%%
%% This library is free software; you can redistribute it and/or
%% modify it under the terms of the GNU Lesser General Public
%% License as published by the Free Software Foundation; either
%% version 3.0 of the License, or (at your option) any later version.
%% This library is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library.

classdef TestScanAccessTracker < matlab.unittest.TestCase
    properties
        warn_format = '';
        backtrace_state;
        verbose_state;
    end
    methods(TestMethodSetup)
        function setup(test)
            test.backtrace_state = warning('off', 'backtrace');
            test.verbose_state = warning('off', 'verbose');
            % MATLAB behaves differently between
            % 1. `warning('')` (no warning) and `warning('%s', '')` warning with empty message
            % 2. `warning('%s')` (`%s` printed) and
            %    `warning('%s', '')` (`%s` interpreted as format)
            % 3. `warning('%%s')` (`%%s` printed) and
            %    `warning('%%s', '')` (`%s` printed)
            % so I'm not really sure what's the most future proof way to get the correct prefix.
            % Given my previous interaction with them,
            % I won't be surprised if they just decide to change that
            % after "carefully studying a large code base"
            % and decide the compatibility of your code with different matlab versions
            % doesn't matter for them.
            f = @() warning('%%s%s', '');
            test.warn_format = evalc('f()');
        end
    end
    methods(TestMethodTeardown)
        function reset(test)
            warning(test.backtrace_state);
            warning(test.verbose_state);
        end
    end
    methods
        function msg = warning_msg(test, msg)
            msg = sprintf(test.warn_format, msg);
        end

        function test_warnings(test, cb, varargin)
            warn_msg = evalc('cb()');
            expected_msg = '';
            for i = 1:length(varargin)
                expected_msg = [expected_msg, test.warning_msg(varargin{i})];
            end
            test.verifyEqual(warn_msg, expected_msg);
        end

        function checked_record_access(test, st, idx, access, varargin)
            test.test_warnings(@() st.record_access(idx, access), varargin{:});
        end

        function checked_force_check(test, st, varargin)
            test.test_warnings(@() st.force_check(), varargin{:});
        end
    end
    %% Test Method Block
    methods(Test)
        function test_reset(test)
            % See if the prefix we got makes sense.
            test.verifyNotEqual(strip(test.warn_format), '');
            test_msg = test.warning_msg('Test');
            test.verifyNotEqual(test_msg, '');
            f = @() warning('Test');
            test.verifyEqual(evalc('f()'), test_msg);
        end

        function test_no_unused(test)
            sg = ScanGroup();
            sg(1).A.B = 1;
            sg(1).A.C.scan(2) = [2, 3, 4];
            sg(2).A.C = 1;
            sg(2).A.D.scan(2) = [2, 3, 4, 5];
            sg(3).B.E = 1;

            st = ScanAccessTracker(sg);
            test.checked_record_access(st, 7, struct('B', struct('C', true)));
            test.checked_record_access(st, 5, struct('A', struct('D', true)));
            test.checked_record_access(st, 6, struct('A', struct('C', true)));
            test.checked_record_access(st, 4, struct('C', struct('D', true)));
            test.checked_record_access(st, 1, struct('C', struct('D', true)));
            test.checked_record_access(st, 8, true);
            test.checked_record_access(st, 3, struct('A', true));
            test.checked_record_access(st, 2, struct());
            test.checked_force_check(st);
        end

        function test_use_subparams(test)
            % This can in principle happen if the user supplied a struct as default value
            % for a parameter with `NaN` value.
            sg = ScanGroup();
            sg(1).A.B = NaN;

            st = ScanAccessTracker(sg);
            test.checked_record_access(st, 1, struct('A', struct('B', struct('C', true))), ...
                                       ['Unused fixed parameters in scan #1:', 10, ...
                                        '  A.B']);
            test.checked_force_check(st);
        end

        function test_rep_access(test)
            sg = ScanGroup();
            sg(1).A.B.scan(1) = [1, 2, 3];

            st = ScanAccessTracker(sg);
            % This should not really happen in principle.
            % I'm testing it just to make sure that it's doing something sane...
            test.checked_record_access(st, 1, struct());
            test.checked_record_access(st, 1, struct('A', struct('C', true)));
            test.checked_record_access(st, 2, struct());
            test.checked_record_access(st, 2, struct('A', struct('B', true)));
            test.checked_record_access(st, 3, struct());
            test.checked_force_check(st);
        end

        function test_force(test)
            sg = ScanGroup();
            sg(1).A.B = 1;
            sg(1).A.C.scan(2) = [2, 3, 4];
            sg(2).A.C = 1;
            sg(2).A.D.scan(2) = [2, 3, 4, 5];
            sg(3).B.E = 1;

            st = ScanAccessTracker(sg);
            test.checked_record_access(st, 4, struct('A', struct('D', true)));
            test.checked_force_check(st, ...
                                     ['Unused fixed parameters in scan #1:', 10, ...
                                      '  A.B'], ...
                                     ['Unused scanning parameters in scan #1:', 10, ...
                                      '  A.C'], ...
                                     ['Unused fixed parameters in scan #2:', 10, ...
                                      '  A.C'], ...
                                     ['Unused fixed parameters in scan #3:', 10, ...
                                      '  B.E']);
        end

        % Printing
        function test_multiline(test)
            sg = ScanGroup();
            sg(1).A.B.A = 1;
            sg(1).A.B.C = 1;
            sg(1).A.B.X = 1;
            sg(1).A.Y.Z.K.scan(2) = [2, 3, 4];
            sg(1).A.Y.A.K.scan(1) = [1, 2, 3, 4];
            sg(1).A.Y.M.K.scan(4) = [3, 2, 3, 4];

            st = ScanAccessTracker(sg);
            test.checked_force_check(st, ...
                                     ['Unused fixed parameters in scan #1:', 10, ...
                                      '  A.B.A', 10, ...
                                      '     .C', 10, ...
                                      '     .X'], ...
                                     ['Unused scanning parameters in scan #1:', 10, ...
                                      '  A.Y.A.K', 10, ...
                                      '     .Z.K', 10, ...
                                      '     .M.K']);
        end
    end
end
