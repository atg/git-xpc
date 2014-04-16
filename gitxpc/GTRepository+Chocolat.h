//
//  GTRepository+Chocolat.h
//  gitxpc
//
//  Created by Nicholas Penree on 4/15/14.
//  Copyright (c) 2014 Chocolat. All rights reserved.
//

@interface GTRepository (Chocolat)

- (BOOL)choc_enumerateFileStatusUsingBlock:(void (^)(NSString *path, GTRepositoryStatusFlags status, BOOL *stop))block;

@end
