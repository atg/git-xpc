//static void do_commit(xpc_connection_t conn, xpc_object_t msg, const char* path) {
//  xpc_connection_send_message(conn, msg);
//}

int onGTDiffLine(const git_diff_delta *gitDelta, const git_diff_hunk *gitHunk, const git_diff_line *gitLine, void *payload){
  xpc_object_t modifications = (__bridge xpc_object_t) payload;
  GTDiffLine *line = [[GTDiffLine alloc] initWithGitLine:gitLine];
  if (line.newLineNumber < 0) {
    return 1;
  }
  
  xpc_object_t change = xpc_array_create(NULL, 0);
  xpc_array_set_uint64(change, 0, line.newLineNumber);
  xpc_array_set_uint64(change, 1, line.origin);
  xpc_array_append_value(modifications, change);
  return 0;
}

static void getDiffOfFile(xpc_connection_t conn, xpc_object_t msg, xpc_object_t event, GTRepository *repo){
  NSURL *filepath = [NSURL URLWithString:@(xpc_dictionary_get_string(event, "filepath"))];
  NSData *contents = [@(xpc_dictionary_get_string(event, "buffer")) dataUsingEncoding:NSUTF8StringEncoding];
  xpc_object_t modifications = xpc_array_create(NULL, 0);
  
  GTBlob *newBlob = [GTBlob blobWithData:contents inRepository:repo error:nil];
  GTBlob *oldBlob = [GTBlob blobWithFile:filepath inRepository:repo error:nil];
  
  git_diff_blobs(oldBlob.git_blob, NULL, newBlob.git_blob, NULL, NULL, NULL, NULL, onGTDiffLine, (__bridge void*)modifications);

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

  NSString *name = @(xpc_dictionary_get_string(event, "type"));
  NSURL *repopath = [NSURL fileURLWithPath:@(xpc_dictionary_get_string(event, "repopath")) isDirectory:NO];

  GTRepository *repo = [GTRepository repositoryWithURL:repopath error:nil];

  if (!repo) {
    return xpc_connection_send_message(conn, msg);
  }

  NSLog(@"msg: %@", msg);
  
  NSArray *events = @[@"status", @"diff"];
  switch ([events indexOfObject:name]) {
    case 0: // status
      NSLog(@"status");
      getStatusForDirectory(conn, msg, repo);
      break;
    case 1: // diff
      NSLog(@"diff");
      getDiffOfFile(conn, msg, event, repo);
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