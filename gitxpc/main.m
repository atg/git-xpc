static void do_commit(xpc_connection_t conn, xpc_object_t msg, const char* path) {
  xpc_connection_send_message(conn, msg);
}

static void getDiffOfFile(xpc_connection_t conn, xpc_object_t msg, GTRepository *repo, NSString* filepath){
  xpc_object_t modifications = xpc_array_create(NULL, 0);

  GTDiff *diff = [GTDiff diffIndexToWorkingDirectoryInRepository:repo options:@{
    @"GTDiffOptionsPathSpecArrayKey": @[filepath]
  } error:nil];

  void(^onGTDiffLine)() = ^(GTDiffLine *line, BOOL *stop){
    if (!line) {
      return;
    }

    if (line.newLineNumber < 0) {
      return;
    }

    xpc_object_t change = xpc_array_create(NULL, 0);
    xpc_array_set_uint64(change, 0, line.newLineNumber);
    xpc_array_set_uint64(change, 1, line.origin);
    xpc_array_append_value(modifications, change);
  };

  void(^onGTDiffHunk)() = ^(GTDiffHunk *hunk, BOOL *stop){
    if (!hunk) {
      return;
    }

    [hunk enumerateLinesInHunk:nil usingBlock:onGTDiffLine];
  };

  void(^onGTDiffDelta)() = ^(GTDiffDelta *delta, BOOL *stop){
    if (!delta) {
      return;
    }

    GTDiffPatch *patch = [delta generatePatch:nil];

    if (!patch) {
      return;
    }

    [patch enumerateHunksUsingBlock:onGTDiffHunk];
  };

  if (diff) {
    [diff enumerateDeltasUsingBlock:onGTDiffDelta];
  }

  xpc_dictionary_set_value(msg, "diff", modifications);
  xpc_connection_send_message(conn, msg);
};

static void getStatusForDirectory(xpc_connection_t conn, xpc_object_t msg, GTRepository *repo){
  [repo choc_enumerateFileStatusUsingBlock:^(NSString *fileName, GTRepositoryStatusFlags status, BOOL *stop) {
    xpc_dictionary_set_uint64(msg, [fileName UTF8String], status);
  }];

  xpc_connection_send_message(conn, msg);
}

static void handleXPCMessage(xpc_connection_t peer, xpc_object_t event){
  xpc_connection_t conn = xpc_dictionary_get_remote_connection(event);
  xpc_object_t msg = xpc_dictionary_create_reply(event);

  NSString *name = [NSString stringWithUTF8String:xpc_dictionary_get_string(event, "type")];
  NSURL *repopath = [NSURL fileURLWithPath:[NSString stringWithUTF8String:xpc_dictionary_get_string(event, "repopath")]];

  GTRepository *repo = [GTRepository repositoryWithURL:repopath error:nil];

  if (!repo) {
    return xpc_connection_send_message(conn, msg);
  }

  NSLog(@"%@", msg);

  NSArray *events = @[@"status", @"diff"];
  switch ([events indexOfObject:name]) {
    case 0: // status
      getStatusForDirectory(conn, msg, repo);
      break;
    case 1: // diff
      getDiffOfFile(conn, msg, repo, [NSString stringWithUTF8String:xpc_dictionary_get_string(event, "filepath")]);
      break;
    default:
      assert(0 && "Unknown command");
      break;
  }
}




// TO IGNORE
static void gitxpc_peer_event_handler(xpc_connection_t peer, xpc_object_t event){
  xpc_type_t type = xpc_get_type(event);
  if (type == XPC_TYPE_ERROR) {
    if (event == XPC_ERROR_CONNECTION_INVALID) {
      // The client process on the other end of the connection has either
      // crashed or cancelled the connection. After receiving this error,
      // the connection is in an invalid state, and you do not need to
      // call xpc_connection_cancel(). Just tear down any associated state
      // here.
    } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
      // Handle per-connection termination cleanup.
    }
  } else {
    assert(type == XPC_TYPE_DICTIONARY);
    handleXPCMessage(peer, event);
  }
}

static void gitxpc_event_handler(xpc_connection_t peer){
  xpc_connection_set_target_queue(peer, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

  xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
    gitxpc_peer_event_handler(peer, event);
  });

  xpc_connection_resume(peer);
}

int main(int argc, const char *argv[]){
  xpc_main(gitxpc_event_handler);
  return 0;
}