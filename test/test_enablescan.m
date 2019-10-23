%%

function test_enablescan()

assert(EnableScan.check());
EnableScan.set(false);
assert(~EnableScan.check());
EnableScan.set(true);
assert(EnableScan.check());

a0 = EnableScan(false);
assert(~EnableScan.check());
delete(a0);
assert(EnableScan.check());

disabled = false;
    function disable()
        a = EnableScan(false);
        disabled = ~EnableScan.check();
        error();
    end

try
    disable();
catch
end
assert(disabled);
assert(EnableScan.check());

end
