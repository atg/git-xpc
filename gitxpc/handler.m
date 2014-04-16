#import "status.m"
#import "diff.m"

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