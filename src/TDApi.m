//
//  TDApi.m
//  ToodledoAPI
//
//  Created by Alex Leutgöb on 08.11.09.
//  Copyright 2009 alexleutgoeb.com. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "TDApi.h"
#import "TDApiConstants.h"
#import "GtdFolder.h"
#import "TDUserIdParser.h"
#import "TDAuthenticationParser.h"
#import "TDFoldersParser.h"


@interface TDApi ()

- (NSString *)getUserIdForUsername:(NSString *)aUsername andPassword:(NSString *)aPassword;
- (NSURLRequest *)requestForURLString:(NSString *)anUrlString additionalParameters:(NSDictionary *)additionalParameters;
- (NSURLRequest *)authenticatedRequestForURLString:(NSString *)anUrlString additionalParameters:(NSDictionary *)additionalParameters;
- (void)setPasswordHashWithPassword:(NSString *)password;

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *passwordHash;
@property (nonatomic, retain) NSDate *keyValidity;

@end


@implementation TDApi

@synthesize userId, key, keyValidity, passwordHash;

#pragma mark -
#pragma mark GtdApi protocol implementation

- (id)initWithUsername:(NSString *)username password:(NSString *)password error:(NSError **)error {
	if (self = [super init]) {
		self.userId = [self getUserIdForUsername:username andPassword:password];
		
		//Check userId
		if (self.userId == nil) {
			// UserId unknown error (connection ? )
			NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
			[errorDetail setValue:@"Unknown error." forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:@"TDAuthErrorDomain" code:100 userInfo:errorDetail];
			[self release];
			return nil;
		}
		else if ([userId isEqualToString:@"0"]) {
			// error: empty arguments
			NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
			[errorDetail setValue:@"Missing input parameters." forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:@"TDAuthErrorDomain" code:200 userInfo:errorDetail];
			[self release];
			return nil;
		}
		else if ([userId isEqualToString:@"1"]) {
			// error: wrong credentials
			NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
			[errorDetail setValue:@"User could not be found, probably wrong credentials" forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:@"TDAuthErrorDomain" code:300 userInfo:errorDetail];
			[self release];
			return nil;
		}
		else {
			[self setPasswordHashWithPassword:password];
			// auth
			[self key];
		}
	}
	return self;
}

- (NSArray *)getFoldersWithError:(NSError **)error {

	if ([self isAuthenticated]) {
		// TODO: parse error handling
		NSError *requestError = nil, *parseError = nil;
		NSURLRequest *request = [self authenticatedRequestForURLString:kGetFoldersURLFormat additionalParameters:nil];
		NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&requestError];
		
		if (requestError == nil) {
			// all ok
			TDFoldersParser *parser = [[TDFoldersParser alloc] initWithData:responseData];
			NSArray *result = [[[parser parseResults:&parseError] retain] autorelease];
			[parser release];
			return result;
		}
		else {
			// error while loading request
			NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
			[errorDetail setValue:[requestError localizedDescription] forKey:NSLocalizedDescriptionKey];
			*error = [NSError errorWithDomain:@"TDFoldersErrorDomain" code:200 userInfo:errorDetail];
			return nil;
		}
	}
	else {
		return nil;
	}
}

- (BOOL)addFolder:(GtdFolder *)aFolder error:(NSError **)error {
	// TODO: implement add folder method
	return NO;
}

- (void) dealloc {
	[passwordHash release];
	[keyValidity release];
	[key release];
	[userId release];
	[super dealloc];
}


- (BOOL)isAuthenticated {
	if (self.key != nil)
		return YES;
	else
		return NO;
}

#pragma mark -
#pragma mark helper methods

// Used for userid lookup. Warning: the pwd is sent unencrypted.
- (NSString *)getUserIdForUsername:(NSString *)aUsername andPassword:(NSString *)aPassword {

	// TODO: parse error handling
	NSError *parseError = nil;
	NSDictionary *params = [[NSDictionary alloc] initWithObjectsAndKeys:aUsername, @"email", aPassword, @"pass", nil];
	NSURLRequest *request = [self requestForURLString:kUserIdURLFormat additionalParameters:params];
	[params release];
	NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	
	TDUserIdParser *parser = [[TDUserIdParser alloc] initWithData:responseData];
	NSArray *result = [[[parser parseResults:&parseError] retain] autorelease];
	[parser release];
	
	if ([result count] == 1) {
		DLog(@"Got user id: %@", [result objectAtIndex:0]);
		return [result objectAtIndex:0];
	}
	else {
		DLog(@"Could not fetch user id.");
		return nil;
	}
	
}

// Custom getter for key; if key is not set or invalid, the getter loads a new one.
- (NSString *)key {
	if (key == nil || keyValidity == nil | [keyValidity compare:[NSDate date]] == NSOrderedDescending) {
		// TODO: parse error handling
		NSError *parseError = nil;
		
		// If no key exists or key is invalid
		NSDictionary *params = [[NSDictionary alloc] initWithObjectsAndKeys:userId, @"userid", @"welldone", @"appid", nil];
		NSURLRequest *request = [self requestForURLString:kAuthenticationURLFormat additionalParameters:params];
		[params release];
		
		NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
		
		TDAuthenticationParser *parser = [[TDAuthenticationParser alloc] initWithData:responseData];
		NSArray *result = [[[parser parseResults:&parseError] retain] autorelease];
		[parser release];
		
		if ([result count] == 1) {
			NSString *token = [result objectAtIndex:0];
			DLog(@"New token: %@", token);
			
			const char *cStr = [[NSString stringWithFormat:@"%@%@%@", passwordHash, token, userId] UTF8String];
			unsigned char result[CC_MD5_DIGEST_LENGTH];
			
			CC_MD5(cStr, strlen(cStr), result);
			
			self.key = [[NSString stringWithFormat: @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
								  result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7], result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]] lowercaseString];
			self.keyValidity = [NSDate date];
			DLog(@"Loaded new key: %@", key);
		}
		else {
			self.key = nil;
		}
	}
	return key;
}

// Custom setter, sets the password hash for a given password.
- (void)setPasswordHashWithPassword:(NSString *)password {
	const char *cStr = [password UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	
	CC_MD5(cStr, strlen(cStr), result);
	
	self.passwordHash = [[NSString stringWithFormat: @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7], result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]] lowercaseString];
}

// Create a request and append the api key
- (NSURLRequest *)authenticatedRequestForURLString:(NSString *)anUrlString additionalParameters:(NSDictionary *)additionalParameters {
	
	// Create parameter string
	NSMutableString *params = [[NSMutableString alloc] initWithFormat:@"%@key=%@;", anUrlString, self.key];
	for (NSString *paramKey in additionalParameters)
		[params appendFormat:@"%@=%@;", paramKey, [additionalParameters objectForKey:paramKey]];
	
	
	// Create rest url
	NSURL *url = [[NSURL alloc] initWithString:params];
	[params release];
	
	NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:url] autorelease];
	[url release];
	
	DLog(@"Created request with url: %@", [[request URL] absoluteString]);
	
    return request;
}

// Create a request without the api key.
- (NSURLRequest *)requestForURLString:(NSString *)anUrlString additionalParameters:(NSDictionary *)additionalParameters {

	// Create parameter string
	NSMutableString *params = [[NSMutableString alloc] initWithString:anUrlString];
	for (NSString *paramKey in additionalParameters)
		[params appendFormat:@"%@=%@;", paramKey, [additionalParameters valueForKey:paramKey]];
	
	
	// Create rest url
	NSURL *url = [[NSURL alloc] initWithString:params];
	[params release];
	NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:url] autorelease];
	[url release];
	
	DLog(@"Created request with url: %@", [[request URL] absoluteString]);
	
    return request;
}

@end
