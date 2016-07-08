#!/usr/bin/env perl

package Quarters::DBI;

use strict;
use warnings;

use Class::DBI;
use Data::Dumper;
use DateTime;


use base 'Class::DBI';
Quarters::DBI->connection('dbi:mysql:ronin_development', 'root', $ENV{MYSQL_PASS});
Quarters::DBI->table('quarters');
Quarters::DBI->columns(All => qw/ yq starts ends quarter year / );

for my $fin_year ( 2002...2038 )
{
  my $year = $fin_year;

  # Quarter 1.
  Quarters::DBI->insert( {
      yq => "${fin_year}01",
      starts => "${year}-05-01",
      ends => "${year}-07-31",
      quarter => 1,
      year => $fin_year
    }
  );

  # Quarter 2.
  Quarters::DBI->insert( {
      yq => "${fin_year}02",
      starts => "${year}-08-01",
      ends => "${year}-10-31",
      quarter => 2,
      year => $fin_year
    }
  );

  $year++;

  # Quarter 3.
  Quarters::DBI->insert( {
      yq => "${fin_year}03",
      starts => "${year}-11-01",
      ends => "${year}-01-31",
      quarter => 3,
      year => $fin_year
    }
  );

  # Quarter 4.
  Quarters::DBI->insert( {
      yq => "${fin_year}04",
      starts => "${year}-02-01",
      ends => "${year}-04-30",
      quarter => 4,
      year => $fin_year
    }
  );
}
