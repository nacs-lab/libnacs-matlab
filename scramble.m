function out = scramble(in)
% out = scramble(in)
% Returns the elements of "in" but in a random order.  "in" is a vector.

out = in(randperm(length(in)));

end
