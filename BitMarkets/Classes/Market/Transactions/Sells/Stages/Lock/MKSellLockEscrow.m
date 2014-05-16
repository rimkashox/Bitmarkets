//
//  MKSellLockEscrow.m
//  BitMarkets
//
//  Created by Steve Dekorte on 5/6/14.
//  Copyright (c) 2014 voluntary.net. All rights reserved.
//

#import "MKSellLockEscrow.h"
#import "MKSell.h"
#import "MKRootNode.h"
#import <BitnashKit/BitnashKit.h>

@implementation MKSellLockEscrow

/*
- (id)init
{
    self = [super init];
    return self;
}
*/

- (BOOL)isActive
{
    return self.buyerLockMsg && !self.confirmLockMsg;
}

- (NSString *)nodeNote
{
    if (self.isActive)
    {
        return @"●";
    }
    
    if (self.confirmLockMsg)
    {
        return @"✓";
    }
    
    /*
     // timeout?
     
     if (self.didTimeout)
     {
     return @"✗";
     }
     */
    
    return nil;
}

- (NSString *)nodeSubtitle
{
    if (!self.runningWallet)
    {
        return @"waiting for wallet..";
    }
    
    if (self.sellerLockMsg)
    {
        return @"awaiting confirm";
    }
    
    if (self.buyerLockMsg)
    {
        return @"got buyer lock";
    }
    
    if (self.sell.bids.acceptedBid)
    {
        return @"awaiting buyer lock";
    }
    
    if (self.confirmLockMsg)
    {
        return @"confirmed";
    }
    
    return nil;
}

// --------------------

- (MKSell *)sell
{
    return (MKSell *)self.nodeParent;
}

- (BOOL)handleMsg:(MKMsg *)msg
{
    if ([msg isKindOfClass:MKBuyerLockEscrowMsg.class])
    {
        [self addChild:msg];
        [self update];
        return YES;
    }
        
    return NO;
}

- (void)postLock
{
    BNWallet *wallet = self.runningWallet;
    
    if (!wallet)
    {
        return;
    }
    
    //NSLog(@"remove this return");
    //return YES; // temp
    
    MKSellerPostLockMsg *msg = [[MKSellerPostLockMsg alloc] init];
    [msg copyFrom:self.bidMsg];

    BNTx *buyerEscrowTx = [self.buyerLockMsg.payload asObjectFromJSONObject]; //TODO check errors.  TODO verify tx before signing.
    buyerEscrowTx.wallet = wallet;
    
    [buyerEscrowTx sign];
    [buyerEscrowTx broadcast];

    [msg sendToBuyer];
    [self addChild:msg];
    [self postParentChainChanged];
}

- (void)postLockIfNeeded
{
    if (self.buyerLockMsg && !self.sellerLockMsg)
    {
        @try
        {
            [self postLock];
        }
        @catch (NSException *exception)
        {
            NSLog(@"postLock failed with exception: %@", exception);
        }
    }
}

- (void)update
{
    [self postLockIfNeeded];
    [self lookForConfirmIfNeeded];
}

// confirm methods to extend parent class MKLock

- (MKBidMsg *)bidMsg
{
    return self.sell.bids.acceptedBid.bidMsg;
}

// confirm

- (NSDictionary *)payloadToConfirm
{
    return self.buyerLockMsg.payload;
}

- (BOOL)shouldLookForConfirm; // subclasses should override
{
    return (self.buyerLockMsg && !self.confirmLockMsg);
}

- (BOOL)isComplete
{
    return self.isConfirmed;
}


@end
