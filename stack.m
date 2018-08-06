function out = stack(in, num)
% out = duplicate(in,num) returns [in, in, ..., in] (num times) if in is a
% row, and [in; in; ...; in] (num times) if in is a column.

out = [];
if isrow(in)
    for j = 1:num
        out = [out, in];
    end
elseif iscolumn(in)
    for j = 1:num
        out = [out; in];
    end
end

end
