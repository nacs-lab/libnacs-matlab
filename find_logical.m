function cond_atom_logical = find_logical(logical_spec, single_atom_logical, num_sites, num_seq)

%% finds logical given images to condition on


N = length(logical_spec);
cond_atom_logical(N, num_sites, num_seq) = 0;
for i = 1:length(logical_spec)
    logical_temp = ones(num_sites, num_seq);
    logical_arr = logical_spec{i};
    for n = 1:length(logical_arr)
        ind = logical_arr(n);
        if ind > 0
            if num_sites > 1
                logical_temp = logical_temp .* squeeze(single_atom_logical(ind,:,:));
            else
                logical_temp = logical_temp .* squeeze(single_atom_logical(ind,:,:))';
            end
        else
            if num_sites > 1
                logical_temp = logical_temp .* not(squeeze(single_atom_logical(-ind,:,:)));
            else
                logical_temp = logical_temp .* not(squeeze(single_atom_logical(-ind,:,:))');
            end
        end
    end
    cond_atom_logical(i,:,:) = logical_temp;
end

end