//
//  GITAppDelegate.m
//  GitXPCTester
//
//  Created by Alex Gordon on 13/03/2014.
//  Copyright (c) 2014 Chocolat. All rights reserved.
//

#import "GITAppDelegate.h"

static void handle_event(xpc_object_t event) {
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
        
        // Handle the message.
    }
}

@implementation GITAppDelegate {
    xpc_connection_t _conn;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    
    // Initialize XPC connection
    _conn = xpc_connection_create("com.chocolatapp.gitxpc", dispatch_get_main_queue());
    
    xpc_connection_set_event_handler(_conn, ^(xpc_object_t event) {
        handle_event(event);
    });
    
    xpc_connection_resume(_conn);
    
    [self performSelector:@selector(getStatusForDirectory) withObject:nil afterDelay:0.3];
}

- (void)getStatusForDirectory {
    NSString* directory = @"/Users/alexgordon/chocolat";//NSHomeDirectory();
    NSString* filepath = @"CHActionPanelLineNumberView.m";
    
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "type", "diff");
    xpc_dictionary_set_string(msg, "repopath", directory.UTF8String);
    xpc_dictionary_set_string(msg, "filepath", filepath.UTF8String);
    
    xpc_connection_send_message_with_reply(_conn, msg, dispatch_get_main_queue(), ^(xpc_object_t event) {
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
            
            //        xpc_object_t statuses = xpc_dictionary_get_value(event, "statuses");
            //        assert(xpc_get_type(statuses) == XPC_TYPE_ARRAY);
            
            //        xpc_array_apply(statuses, ^bool(size_t index, xpc_object_t status) {
            char* description = xpc_copy_description(event);
            NSLog(@"Got status: %s", description);
            free(description);
            //            return true;
            //        });
        }
    });
}

@end
