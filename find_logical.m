function cond_atom_logical = find_logical(logical_spec, single_atom_logical, num_sites, num_seq)

%% finds logical given images to condition on


N = length(logical_spec);
cond_atom_logical = zeros(N, num_sites, num_seq);
for i = 1:N
    logical_temp = ones(num_sites, num_seq);
    logical_arr = logical_spec{i};
    for n = 1:length(logical_arr)
        ind = logical_arr(n);
        slice = reshape(single_atom_logical(abs(ind),:,:), num_sites, num_seq);
        if ind > 0
            logical_temp = logical_temp .* slice;
        else
            logical_temp = logical_temp .* ~slice;
        end
    end
    cond_atom_logical(i,:,:) = logical_temp;
end

end