function resetGlobal()
  global nacsTimeSeqDisableRunHack;
  global nacsTimeSeqNameSuffixHack;
  global nacsNiDACBackendSession;
  nacsTimeSeqDisableRunHack = 0;
  nacsTimeSeqNameSuffixHack = [];
  if ~isempty(nacsNiDACBackendSession)
    delete(nacsNiDACBackendSession);
    nacsNiDACBackendSession = [];
  end
  IRCache.get().clear();
  FPGAPoster.dropAll();
  URLPoster.dropAll();
  USRPPoster.dropAll();
  KeySight.dropAll();
end
