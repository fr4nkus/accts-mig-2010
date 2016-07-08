#!/usr/bin/env perl

use strict;
use warnings;

use Spreadsheet::ParseExcel;
use XML::Simple;
use Data::Dumper;
use Encode;

die "You must provide a filename to $0 to be parsed as an Excel file"
  unless @ARGV;

my $debug = 0;

sub ignore_cell {
    my $cell = shift;

    return undef unless defined $cell;

    my $v = $cell->Value;

    return undef unless defined $v;
    return undef unless $v;
    return undef if $v =~ /Ronin IT/i;
    return undef if $v =~ /Close$/i;
    return undef if $v =~ /^Chelmsford$/i;
    return undef if $v =~ /^Invoice$/i;
    return undef if $v =~ /^CM1/i;
    return undef if $v =~ /^per unit/i;

    $v;
}

sub normalise_attribute {

	my $key = shift;

	$key = lc($key);
	$key =~ s/:$//;
	$key =~ s/[^a-z0-9]/_/g;
	$key =~ s/^invoice_//;

	$key;
}

sub tidy_items
{
	my $items = shift;

	unless( ref( $items ) eq 'ARRAY' )
	{
		die "\$items not an array! :", Dumper $items;
	}

	unless( ref( $items->[0] ) eq 'ARRAY' )
	{
		die "\$items->[0] not an array! :", Dumper $items->[0];
	}

	my @h = map{ lc( $_ ) }@{shift @{ $items }};
	my $clean = [];

	for my $row ( @{ $items } )
	{
		next unless $row;	

		#push @{$clean}, $row;
		push @{$clean},{ map{ $h[$_] => clean_cell( $row->[$_] ) }(0..$#h) };
	}

	$clean;
}

sub clean_cell
{
	my $currency = shift;
	
	if( $currency )
	{
		$currency = ( split/\n/,$currency )[0];
		$currency =~ s/[^ A-Za-z0-9)(,.\/-]//g;
	}
	$currency;
}


sub print_sheet
{
	my $xml_doc = shift;
	my $invno;

	if( $xml_doc->{invoice}->{'no'} =~ /\d+/) {
		$invno = sprintf( '%04d', $xml_doc->{invoice}->{'no'} );
	}
	else {
		print Dumper $xml_doc;
	}

	my $date = $xml_doc->{invoice}->{'date'};
	my $client = $xml_doc->{invoice}->{'client'};

	my $filename = "$invno-$date-$client.xml";

	$filename =~ s/^-//;
	$filename =~ s/[\/\s]+/_/g;
	$filename = lc( $filename );
	$filename = "output/$filename";

	my $count = 0;

	while( -e $filename )
	{
		print "Error: $filename already exists!\n";
		$filename .= ".$count";
	}

	open( O, ">$filename" ) or die "$filename failed: $!";
    	print O XMLout($xml_doc, RootName => 'xml' );
	close O;
}


{
	my @alpha = ( 'A' ... 'Z' );
	sub col_decode
	{
		$alpha[ shift ];	
	}
}

my $xls = new Spreadsheet::ParseExcel()->Parse( $ARGV[0] );

for my $sheet_no ( 0 ... ( $xls->{SheetCount} - 1 ) ) {

    my $worksheet = $xls->{Worksheet}[$sheet_no];

    my $xml_doc = {
        invoice => {
            origin => $xls->{File},
            sheet  => $sheet_no,
        }
    };

    next unless defined $worksheet->{MaxRow};
    my $key = undef;
    my ($row_offs, $col_offs ) = ( 0, 0 );
    my $items = [];

    # This Parse identifies non-tabular elements.
    for my $row ( $worksheet->{MinRow} ... $worksheet->{MaxRow} ) {

        next unless defined $worksheet->{MaxRow};

        for my $col ( $worksheet->{MinCol} ... $worksheet->{MaxCol} ) {
	
        if( $debug )
	{
		my $c = col_decode( $col );
		my $v = $worksheet->{Cells}[$row][$col];
		if( defined( $v ) )
		{
			my $debug_val = $v->Value;
			print "${c}${row} = $debug_val\n";
		}
        }

            my $v = ignore_cell( $worksheet->{Cells}[$row][$col] );
            next unless $v;

            if ($key) {
                $xml_doc->{invoice}->{ normalise_attribute( $key ) } = clean_cell( $v );
                $key = undef;
		next;
            }

            $key = $v if $v =~ /:$/;
	    next if $key;

	    # We've reached the tabular data.
	    if( $v =~ /unit(:?s)?/i )
            {
		($row_offs, $col_offs ) = ($row, $col);
		print "Unit found at ($row, $col)\n" if $debug;
            }

	    # Add the tabular data to a matrix by subtracting the base coordinates.
	    $items->[ $row - $row_offs ][ $col - $col_offs] = $v;

        }    # end columns

    }    # end rows

    eval{ $xml_doc->{invoice}->{items} = tidy_items( $items ) };
    if( $@ )
    {
	print "Error: File", $xls->{File},       "\n";
	print "Error: Worksheet $sheet_no\n";
	print "Error: $@\n";
    }
    else 
    {
	my $client = $xml_doc->{invoice}->{'client'};

	$client =~ s/\.$//;
	$client =~ s/ltd$//i;
	$client =~ s/limited$//i;
	$client =~ s/itr/IT Recruitment/i;
	$client =~ s/\s$//;

	$xml_doc->{invoice}->{'client'} = $client;

    	print_sheet($xml_doc);
    }
}    # end sheets.
