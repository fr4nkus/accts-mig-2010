#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

open( S, 'ls xml/*|' ) or die "nnnhhn...yeah that didnt work: $!";
my %consec_nos = map{$_=>1}( 1...252 );
my %dupes = ();

while(<S>)
{
	my $invno = ( split/-/,$_,2 )[0];
	$invno = int( ( split'/',$invno,2 )[1] );

	if( exists( $consec_nos{ $invno } ) )
	{
		delete( $consec_nos{ $invno } );
	}
	else
	{
		$dupes{ $invno }++;
	}
}

print Dumper { gaps => join( ',', sort { $a <=> $b } keys %consec_nos ), duplicates => join( ',', sort { $a <=> $b } keys %dupes ) };
