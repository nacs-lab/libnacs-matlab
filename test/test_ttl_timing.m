function s=test_ttl_timing(chn, init, times, mgrarg)
s = ExpSeq();
if exist('mgrarg', 'var')
    s.addOutputMgr(mgrarg{:});
end
v = init;
for t = times
    s.addStep(t).add(chn, v);
    v = ~v;
end
s.run();
end
