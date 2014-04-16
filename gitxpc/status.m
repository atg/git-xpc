#include <xpc/xpc.h>
#include <Foundation/Foundation.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "GTRepository+Chocolat.h"

static void getStatusForDirectory(xpc_connection_t conn, xpc_object_t msg, GTRepository *repo){
  [repo choc_enumerateFileStatusUsingBlock:^(NSString *fileName, GTRepositoryStatusFlags status, BOOL *stop) {
    xpc_dictionary_set_uint64(msg, [fileName UTF8String], status);
  }];
  
  xpc_connection_send_message(conn, msg);
}