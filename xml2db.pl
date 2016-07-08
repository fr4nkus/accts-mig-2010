#!/usr/bin/env perl

package Invoice::DBI;

use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use Class::DBI;
use Encode;


use base 'Class::DBI';
Invoice::DBI->connection('dbi:mysql:ronin_development', 'root', $ENV{MYSQL_PASS});
Invoice::DBI->table('temp_invoice_items');
Invoice::DBI->columns(All => qw/ id inv_date invoice_id cost vat net gross description units name /);

die "You must provide a filename to $0 to be parsed." unless @ARGV;
my $debug = 0;
my $xml_inv = XMLin( $ARGV[0], ForceArray =>qw/ items /  );

if( $xml_inv->{invoice}->[0]->{items}->[-1]->{cost} eq '' )
{
  pop( @{ $xml_inv->{invoice}->[0]->{items} } );
}

print Dumper $xml_inv;

for my $item ( @{ $xml_inv->{invoice}->[0]->{items} } )
{
  $item->{'net'} =~ s/[^0-9.]//g;
  $item->{'gross'} =~ s/[^0-9.]//g;
  Invoice::DBI->insert( {
      invoice_id => $xml_inv->{invoice}->[0]->{'no'},
      inv_date => $xml_inv->{invoice}->[0]->{'date'},
      %{$item}
    }
  );
}
