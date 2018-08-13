%% Copyright (c) 2018-2018, Yichao Yu <yyc1992@gmail.com>
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

classdef TTLMgr < handle
    % This output manager handles TTL pre-trigger and skipping (useful for shutters).
    % The user is expected to specify when the channel needs to be on (or off) as usual
    % in the sequence. The manager will alter the output timing so that.
    % 1. The channel is turned on before it needs to be on to acount for turning on delay.
    % 2. The channel is turned off before it needs to be off to acount for turning off delay.
    % 3. If the channel is turned on again very soon after it is turned off, the turn off
    %    will be skipped. (This avoid turning off the shutter unnecessarilyxf)
    % 4. If the channel is turned off again very soon after it is turned on, the turn off
    %    is delayed to be at least a minimum time after the turn on.

    % The role of on-off can be reversed by passing `off_val = 1`.
    properties
        s;
        chn;
        % The time it takes to react to channel turning off (`~off_val` -> `off_val`)
        % This is the time the channel needs to be turned off before when it needed to be off.
        off_delay;
        % The time it takes to react to channel turning on (0 -> 1)
        % This is the time the channel needs to be turned on before when it needed to be on.
        on_delay;
        % Minimum off time. Off interval shorter than this will be skipped.
        skip_time;
        % Minimum on time. On time shorter than this will be extended
        % (the off pulse will be delayed so that it's at least this time after the on one).
        min_time;

        off_val = 0;
    end
    methods
        function self = TTLMgr(s, chn, off_delay, on_delay, skip_time, min_time, off_val)
            self.s = s;
            self.chn = chn;
            self.off_delay = off_delay;
            self.on_delay = on_delay;
            self.skip_time = skip_time;
            self.min_time = min_time;
            if exist('off_val', 'var')
                self.off_val = off_val;
            end
        end
        function res = processPulses(self, pulses)
            off_delay = self.off_delay;
            on_delay = self.on_delay;
            skip_time = self.skip_time;
            min_time = self.min_time;
            off_val = self.off_val;

            % The current pulse (time and value).
            % If `cur_v == output_v`, this pulse has already been outputted.
            % If `cur_v ~= output_v`, the pulse is not outputted yet
            % (can be merged with the next one). In this case, the code that
            % modifies the current pulse should make sure the previous value is
            % outputted when needed.
            cur_t = 0;
            cur_v = getDefault(self.s, self.chn) ~= 0;
            % The last pulse actually outputted.
            output_t = -inf;
            output_v = cur_v;

            res = {};
            for j = 1:size(pulses, 1)
                pulse_obj = pulses{j, 3};
                if ~isnumeric(pulse_obj)
                    error('Ramp not allowed on TTL channel.');
                end
                val = pulse_obj ~= 0;
                if val == cur_v
                    continue;
                end
                t = pulses{j, 1};
                if val == off_val
                    if t == 0
                        % If a turn off needs to be started at t < 0,
                        % only do it if the original time is t = 0.
                        % This makes sure the channel is at the beginning
                        % of the sequence as programmed by the user.
                        assert(cur_t == 0 && output_t < 0);
                        setDefault(self.s, self.chn, val);
                        cur_v = val;
                        output_v = val;
                        continue;
                    end
                    t = t - off_delay;
                    % If we are turning off, we might need to extend the turn off time.
                    t = max(t, cur_t + min_time);
                else
                    t = t - on_delay;
                    % If we are turning on, we might want to skip the previous one
                    if t - cur_t <= skip_time
                        % The only reason `cur_v == output_v` is when a `cur_v == off_val`
                        % was skipped so `output_v` must be `~off_val`.
                        % Since `cur_v == ~val == off_val`, `cur_v == ~output_v`
                        % meaning that the `cur_v` is not outputted yet.
                        assert(cur_v ~= output_v);
                        if cur_t == 0
                            setDefault(self.s, self.chn, val);
                            cur_v = val;
                            output_v = val;
                            continue;
                        elseif output_t < 0
                            % This means that we have one pulse pending,
                            % i.e. `cur_t > 0`, but we don't have anything
                            % actually outputed yet.
                            % The way to skip the pending pulse is to
                            % basically revert to the state we started
                            % with.
                            cur_t = 0;
                        else
                            cur_t = output_t;
                        end
                        cur_v = output_v;
                        continue;
                    end
                end
                assert(t > 0 && t > cur_t);
                if cur_v ~= output_v
                    if cur_t == 0
                        setDefault(self.s, self.chn, cur_v);
                    else
                        res(1:3, end + 1) = {cur_t, 0, cur_v};
                        output_t = cur_t;
                    end
                    output_v = cur_v;
                end
                cur_t = t;
                cur_v = val;
            end
            if cur_t > 0 && cur_v ~= output_v
                res(1:3, end + 1) = {cur_t, 0, cur_v};
            end
            if cur_t == 0
                assert(size(res, 1) == 0);
                % Make sure the TLL channel is used.
                res(1:3, end + 1) = {0, 0, cur_v};
            end
            res = res';
        end
    end
end
