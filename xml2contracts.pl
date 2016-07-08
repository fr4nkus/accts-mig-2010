#!/usr/bin/env perl


package Contract::DBI;
use base 'Class::DBI';
Contract::DBI->connection('dbi:mysql:ronin_development', 'root', $ENV{MYSQL_PASS});
Contract::DBI->table('contracts');
Contract::DBI->columns(All => qw/ id starts ends agent_id client_id / );

package Agent::DBI;
use base 'Class::DBI';
Agent::DBI->connection('dbi:mysql:ronin_development', 'root', $ENV{MYSQL_PASS});
Agent::DBI->table('agents');
Agent::DBI->columns(All => qw/ id name / );

package Invoice::DBI;
use base 'Class::DBI';
Invoice::DBI->connection('dbi:mysql:ronin_development', 'root', $ENV{MYSQL_PASS});
Invoice::DBI->table('invoices');
Invoice::DBI->columns(All => qw/ id paid contract_id invoiced reference / );


use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use Class::DBI;
use Encode; 


opendir DIR, './xml' or die "d'oh!";
my @files = readdir DIR;
my %agent;

for my $file ( @files )
{
  my ( $f ) = split( /\./, $file,2 );
  my ( $inv, $y, $m, $d, $a );

  if( $f =~ /^\d\d\d\d-\d\d\d\d/ )
  {
    ( $inv, $y, $m, $d, $a ) = split( /[-]/, $f, 5 );
  }
  else
  {
    ( $inv, $d, $m, $y, $a ) = split( /[_-]/, $f, 5 );
  }

  unless( defined( $a ) ) {
    print Dumper [ $inv, $y, $m, $d, $a ];
    next;
  }

  my $dt = sprintf( "%04d%02d%02d", $y, $m, $d );

  if( exists( $agent{ $a } ) )
  {
    my $agent = $agent{ $a };

    $agent->{invoices}->{ $inv } = $dt;

    if ( $dt < $agent->{min_date} )
    {
      $agent->{min_date} = $dt;
    }

    if( $dt > $agent->{max_date} )
    {
      $agent->{max_date} = $dt;
    }
  }
  else
  {
    my $name = ucfirst( $a );
    $name =~ s/_(.)/' '. uc($1)/eg;
    my $agent_id = Agent::DBI->find_or_create( { name => $name } );

    $agent{ $a } = {
      agent_id => $agent_id->{id},
      invoices => { $inv => $dt },
      max_date => $dt,
      min_date => $dt,
      name => $name,
    }
  }
}

for my $agent ( values %agent ) {

  my $contract = Contract::DBI->find_or_create( {
      starts => to_date( $agent->{min_date} ),
      ends => to_date( $agent->{max_date} ),
      agent_id => $agent->{agent_id},
      client_id => 1
  } );

  unless( defined( $contract->{id} ) )
  {
    print Dumper $agent;
    next;
  }
  
  print $contract;

  while( my ( $inv_id, $dt ) = each( %{ $agent->{ invoices } } ) )
  {
    my $inv_date = to_date( $dt );
  
    Invoice::DBI->find_or_create( {
      reference => $inv_id,
      paid => $inv_date,
      invoiced => $inv_date,
      contract_id => $contract->{id}
    } );
  }
}

sub to_date
{
  my $s = shift;

  if( $s =~ /(\d\d\d\d)(\d\d)(\d\d)/ ) {
    return sprintf( '%04d-%02d-%02d', $1, $2, $3 );
  }

  return undef;
}

