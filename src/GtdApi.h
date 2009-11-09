//
//  GtdApi.h
//  ToodledoAPI
//
//  Created by Alex Leutgöb on 05.11.09.
//  Copyright 2009 alexleutgoeb.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GtdFolder;

@protocol GtdApi

@property (readonly) BOOL isAuthenticated;

// Main initializer, performs authentication.
- (id)initWithUsername:(NSString *)username password:(NSString *)password error:(NSError **)error;

// Loads and returns an array with GtdFolder objects.
- (NSArray *)getFoldersWithError:(NSError **)error;

// Adds a remote folder
- (BOOL)addFolder:(GtdFolder *)aFolder error:(NSError **)error;



//
@optional

// Inits an api implementation with username and password, possible auth tokens have to be saved by the implementation
- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password;

// Adds a remote task to the gtd service
- (NSInteger)addTask:(id)aTask;

// Gets a list of remote tasks matching the given prototype; if prototype is nil, all tasks are returned
- (NSArray *)getTasksLikePrototype:(id)aPrototype;

// Modifies a given remote task, returns YES if successful, otherwise NO
- (BOOL)updateTask:(id)aTask;

// Deletes a remote task permamently
- (BOOL)deleteTask:(id)aTask;


// Adds a folder to the gtd service
- (NSInteger)addFolder:(id)aFolder;

// Adds a context to the gtd service
- (NSInteger)addContext:(id)aContext;




@end
