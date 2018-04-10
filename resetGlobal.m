function resetGlobal()
  global nacsTimeSeqDisableRunHack;
  global nacsTimeSeqNameSuffixHack;
  nacsTimeSeqDisableRunHack = 0;
  nacsTimeSeqNameSuffixHack = [];
  NiDACBackend.clearSession();
  IRCache.get().clear();
  FPGAPoster.dropAll();
  URLPoster.dropAll();
  USRPPoster.dropAll();
  KeySight.dropAll();
  WavemeterClient.dropAll();
  Wavemeter.dropAll();
end
