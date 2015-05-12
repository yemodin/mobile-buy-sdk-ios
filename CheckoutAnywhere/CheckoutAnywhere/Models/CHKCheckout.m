//
//  CHKCheckout.m
//  Checkout
//
//  Created by Shopify on 2014-09-10.
//  Copyright (c) 2014 Shopify Inc. All rights reserved.
//

#import "CHKAddress.h"
#import "CHKCart.h"
#import "CHKCheckout.h"
#import "CHKDiscount.h"
#import "CHKLineItem.h"
#import "CHKProductVariant.h"
#import "CHKShippingRate.h"
#import "CHKTaxLine.h"
#import "NSDecimalNumber+CHKAdditions.h"
#import "NSString+Trim.h"

static NSDictionary *kCHKPropertyMap = nil;

@implementation CHKCheckout

+ (void)initialize
{
	if (self == [CHKCheckout class]) {
		[self trackDirtyProperties];
	}
}

- (instancetype)initWithCart:(CHKCart *)cart
{
	self = [super initWithDictionary:@{}];
	if (self) {
		_lineItems = [cart.lineItems copy];
		[self markPropertyAsDirty:@"lineItems"];
	}
	return self;
}

- (void)setShippingRateId:(NSString *)shippingRateIdentifier
{
	[self willChangeValueForKey:@"shippingRateId"];
	_shippingRateId = shippingRateIdentifier;
	[self didChangeValueForKey:@"shippingRateId"];
}

- (void)setShippingRate:(CHKShippingRate *)shippingRate
{
	[self willChangeValueForKey:@"shippingRate"];
	_shippingRate = shippingRate;
	[self didChangeValueForKey:@"shippingRate"];
	
	[self setShippingRateId:shippingRate.shippingRateIdentifier];
}

+ (NSString *)jsonKeyForProperty:(NSString *)property
{
	NSString *key = nil;
	if ([property isEqual:@"identifier"]) {
		key = @"id";
	}
	else {
		static NSCharacterSet *kUppercaseCharacters = nil;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			kUppercaseCharacters = [NSCharacterSet uppercaseLetterCharacterSet];
		});
		
		NSMutableString *output = [NSMutableString string];
		for (NSInteger i = 0; i < [property length]; ++i) {
			unichar c = [property characterAtIndex:i];
			if ([kUppercaseCharacters characterIsMember:c]) {
				[output appendFormat:@"_%@", [[NSString stringWithCharacters:&c length:1] lowercaseString]];
			}
			else {
				[output appendFormat:@"%C", c];
			}
		}
		key = output;
	}
	return key;
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
	self.email = dictionary[@"email"];
	self.orderId = dictionary[@"order_id"];
	self.token = dictionary[@"token"];
	self.requiresShipping = [dictionary[@"requires_shipping"] boolValue];
	self.taxesIncluded = [dictionary[@"taxes_included"] boolValue];
	self.currency = dictionary[@"currency"];
	self.subtotalPrice = [NSDecimalNumber chk_decimalNumberFromJSON:dictionary[@"subtotal_price"]];
	self.totalTax = [NSDecimalNumber chk_decimalNumberFromJSON:dictionary[@"total_tax"]];
	self.totalPrice = [NSDecimalNumber chk_decimalNumberFromJSON:dictionary[@"total_price"]];
	
	self.paymentSessionId = dictionary[@"payment_session_id"];
	NSString *paymentURLString = dictionary[@"payment_url"];
	self.paymentURL = paymentURLString ? [NSURL URLWithString:paymentURLString] : nil;
	self.reservationTime = dictionary[@"reservation_time"];
	self.reservationTimeLeft = dictionary[@"reservation_time_left"];
	self.paymentDue = dictionary[@"payment_due"];
					   
	_lineItems = [CHKLineItem convertJSONArray:dictionary[@"line_items"]];
	_taxLines = [CHKTaxLine convertJSONArray:dictionary[@"tax_lines"]];
	
	self.billingAddress = [CHKAddress convertObject:dictionary[@"billing_address"]];
	self.shippingAddress = [CHKAddress convertObject:dictionary[@"shipping_address"]];
	self.shippingRate = [CHKShippingRate convertObject:dictionary[@"shipping_rate"]];
	self.discount = [CHKDiscount convertObject:dictionary[@"discount"]];

	NSString *orderStatusURL = dictionary[@"order_status_url"];
	self.orderStatusURL = orderStatusURL && [orderStatusURL isKindOfClass:[NSString class]] ? [NSURL URLWithString:orderStatusURL] : nil;
}

- (id)jsonValueForValue:(id)value
{
	id newValue = value;
	if ([value conformsToProtocol:@protocol(CHKSerializable)]) {
		newValue = [(id <CHKSerializable>)value jsonDictionaryForCheckout];
	}
	else if ([value isKindOfClass:[NSArray class]]) {
		NSMutableArray *newArray = [[NSMutableArray alloc] init];
		for (id arrayValue in value) {
			[newArray addObject:[self jsonValueForValue:arrayValue]];
		}
		newValue = newArray;
	}
	else if ([value isKindOfClass:[NSString class]]) {
		newValue = [value chk_trim];
	}
	return newValue;
}

- (NSDictionary *)jsonDictionaryForCheckout
{
	//We only need the dirty properties
	NSSet *dirtyProperties = [self dirtyProperties];
	NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
	for (NSString *dirtyProperty in dirtyProperties) {
		id value = [self jsonValueForValue:[self valueForKey:dirtyProperty]];
		json[[CHKCheckout jsonKeyForProperty:dirtyProperty]] = value ?: [NSNull null];
	}
	json[@"partial_addresses"] = @YES;
	return @{ @"checkout" : json };
}

- (BOOL)hasToken
{
	return (_token && [_token length] > 0);
}

@end
