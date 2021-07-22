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

classdef TestYAML < matlab.unittest.TestCase
    %% Test Method Block
    methods(Test)
        function empty(test)
            test.verifyEqual(YAML.sprint([]), '[]');
            test.verifyEqual(YAML.sprint([], 4), '[]');
            test.verifyEqual(YAML.sprint({}), '[]');
            test.verifyEqual(YAML.sprint({}, 4), '[]');
            test.verifyEqual(YAML.sprint(struct()), '{}');
            test.verifyEqual(YAML.sprint(struct(), 4), '{}');
        end
        function primitive(test)
            test.verifyEqual(YAML.sprint(false), 'false');
            test.verifyEqual(YAML.sprint(123), '123');
            test.verifyEqual(YAML.sprint('abcdef'), 'abcdef');
        end
        function array(test)
            test.verifyEqual(YAML.sprint([1, 2, 3, 4, 5]), '[1, 2, 3, 4, 5]');
            test.verifyEqual(YAML.sprint({1, 2, 3, 4, 'abcdef'}), ...
                             ['- 1' char(10), ...
                              '- 2' char(10), ...
                              '- 3' char(10), ...
                              '- 4' char(10), ...
                              '- abcdef', ...
                             ]);
            test.verifyEqual(YAML.sprint({1, 2, 3, 4, 'abcdef'}, 2), ...
                             ['- 1' char(10), ...
                              '  - 2' char(10), ...
                              '  - 3' char(10), ...
                              '  - 4' char(10), ...
                              '  - abcdef', ...
                             ]);
            test.verifyEqual(YAML.sprint({1, 2, [1, 2, 3], 4, 'abcdef'}), ...
                             ['- 1' char(10), ...
                              '- 2' char(10), ...
                              '- [1, 2, 3]' char(10), ...
                              '- 4' char(10), ...
                              '- abcdef', ...
                             ]);
        end
        function object(test)
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, 'c', [])), ...
                             ['a: xyz' char(10), ...
                              'b: 234' char(10), ...
                              'c: []', ...
                             ]);
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, 'c', []), 3), ...
                             ['a: xyz' char(10), ...
                              '   b: 234' char(10), ...
                              '   c: []', ...
                             ]);
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, ...
                                                'ccc', struct('x', 'zzz', 'wer', true))), ...
                             ['a: xyz' char(10), ...
                              'b: 234' char(10), ...
                              'ccc: x: zzz' char(10), ...
                              '     wer: true', ...
                             ]);
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, ...
                                                'ccc', struct('x', struct('zzz', struct('wer', true))))), ...
                             ['a: xyz' char(10), ...
                              'b: 234' char(10), ...
                              'ccc: x: zzz: wer: true', ...
                             ]);
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, ...
                                                'ccc', struct('x', struct('zzz', struct('wer', true)))), 2), ...
                             ['a: xyz' char(10), ...
                              '  b: 234' char(10), ...
                              '  ccc: x: zzz: wer: true', ...
                             ]);
            test.verifyEqual(YAML.sprint(struct('a', 'xyz', 'b', 234, ...
                                                'ccc', struct('x', struct('zzz', struct('wer', true)))), 2, true), ...
                             ['a: xyz' char(10), ...
                              '  b: 234' char(10), ...
                              '  ccc: x.zzz.wer: true', ...
                             ]);
        end
    end
end