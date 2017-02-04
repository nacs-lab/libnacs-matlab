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
end
