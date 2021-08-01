function resetGlobal()
    SeqConfig.reset();
    NiDACBackend.clearSession();
    IRCache.get().clear();
    FPGAPoster2.dropAll();
    URLPoster.dropAll();
    USRPPoster.dropAll();
end
