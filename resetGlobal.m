function resetGlobal()
    ExpSeq.reset();
    NiDACBackend.clearSession();
    IRCache.get().clear();
    FPGAPoster.dropAll();
    URLPoster.dropAll();
    USRPPoster.dropAll();
    KeySight.dropAll();
    WavemeterClient.dropAll();
    Wavemeter.dropAll();
end
