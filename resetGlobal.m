function resetGlobal()
    SeqConfig.reset();
    NiDACBackend.clearSession();
    IRCache.get().clear();
    FPGAPoster.dropAll();
    URLPoster.dropAll();
    USRPPoster.dropAll();
end
