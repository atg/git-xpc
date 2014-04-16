//  Created by Alex Gordon on 13/03/2014.
#import "handler.m"

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