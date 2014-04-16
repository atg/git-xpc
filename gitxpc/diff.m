static void getDiffOfFile(xpc_connection_t conn, xpc_object_t msg, GTRepository *repo, NSString* filepath){
  xpc_object_t modifications = xpc_array_create(NULL, 0);
  
  GTDiff *diff = [GTDiff diffIndexToWorkingDirectoryInRepository:repo options:@{
    @"GTDiffOptionsPathSpecArrayKey": @[filepath]
  } error:nil];
  
  void(^onGTDiffLine)() = ^(GTDiffLine *line, BOOL *stop){
    if (line.newLineNumber < 0) {
      return;
    }
    
    xpc_object_t change = xpc_array_create(NULL, 0);
    xpc_array_set_uint64(change, 0, line.newLineNumber);
    xpc_array_set_uint64(change, 1, line.origin);
    xpc_array_append_value(modifications, change);
  };
  
  void(^onGTDiffHunk)() = ^(GTDiffHunk *hunk, BOOL *stop){
    [hunk enumerateLinesInHunk:nil usingBlock:onGTDiffLine];
  };
  
  void(^onGTDiffDelta)() = ^(GTDiffDelta *delta, BOOL *stop){
    GTDiffPatch *patch = [delta generatePatch:nil];
    [patch enumerateHunksUsingBlock:onGTDiffHunk];
  };
  
  [diff enumerateDeltasUsingBlock:onGTDiffDelta];
  
  xpc_dictionary_set_value(msg, "diff", modifications);
  xpc_connection_send_message(conn, msg);
};