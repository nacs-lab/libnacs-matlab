function resetGlobal()
    ExpSeq.reset();
    SeqConfig.reset();
    NiDACBackend.clearSession();
    IRCache.get().clear();
    FPGAPoster.dropAll();
    URLPoster.dropAll();
    USRPPoster.dropAll();
    KeySight.dropAll();
    WavemeterClient.dropAll();
    Wavemeter.dropAll();
    DisableScan.set(0);
end
