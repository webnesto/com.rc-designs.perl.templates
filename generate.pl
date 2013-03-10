#!/usr/bin/perl -w

#Includes
use strict;
use warnings;

use IO::File;
use Cwd;

# trim function from http://www.somacon.com/p114.php to remove whitespace from the start and end of the string
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# get index of item in array
sub indexArray {
	my ($item, $array) = @_;
	my @array = @{$array};
	my $l = scalar( @array );
	for( my $i = 0; $i < $l; $i++ ){
		if( $item eq $array[$i] ){
			return $i;
		}
	}
	return -1;
}

# return file contents as single string.
sub getContents {
	my ( $file ) = @_;
	my $ret = "";
	if( -e $file ){
		my $fileIO = new IO::File( $file, "r" ) or die "could not open $file";
		while ( my $line = $fileIO->getline() ) {
			$ret.= $line;
		}
		undef $fileIO;
	}
	return $ret;
}

sub buildHash {
	my ( $chunk ) = @_;

	my $returnObj = {};
	my @objects = ();
	my @arrays = ();
	push( @objects, $returnObj );
	$objects[ -1 ]{ "root" } = $returnObj->{ "root" } || $returnObj;

	my $partChunk = $chunk;
	$partChunk =~ s/<%(.+?)%>/BATUNATECH/g;
	my @parts = split( /BATUNATECH/, $partChunk );
	my $part;

	my @tags = ();
	my $tagChunk = $chunk;
	while( $tagChunk =~ /<%(\s*)([^%]*)(\s*)%>/s ){
		$tagChunk = $';
		push( @tags, $2 );
	}
	my $tl = scalar( @tags );
	my $ti;

	my $tag;
	my $type;
	my @tagbits;
	my @types = [
		"list"
	,	"item"
	,	"loaddata"
	,	"loadtpl"
	];
	my $test;
	my $opening;

	for( $ti = 0; $ti < $tl; $ti++ ){
		$tag = trim( $tags[ $ti ] );
		$part = $parts[ $ti + 1 ];
		$type = "";
		$test = "";
		if( $tag =~ /(\s*)\// ){
			$opening = 0;
			$tag =~ s/\///;
		} else {
			$opening = 1;
		}
		@tagbits = split( /([\s]+)/, $tag );
		if( scalar( @tagbits ) == 1 ){
			$test = $tag;
		} else {
			$test = $tagbits[0];
		}
		if( ( indexArray( $test, @types ) != -1 ) || ( $test =~ /^tpl:/ ) ){
			$type = $test;
			if( scalar( @tagbits ) > 2 ){
				$tag = $tagbits[2];
			} else {
				$tag = "";
			}
		} else {
			if( scalar( @tagbits ) > 2 ){
				warn "$test is not a type - check for extra space in tag.\n";
			} else {
				$tag = $tagbits[ 0 ];
			}
		}
		if( $opening ){
			if( $type eq "list"){
				push( @arrays, [] );
				$objects[ -1 ]{ $tag } = $arrays[ -1 ];
			}
			elsif( ( $type eq "item" ) and ( $tag eq "" ) ){
				push( @objects, {} );
				$objects[ -1 ]{ "list" } = $arrays[ -1 ]; #store a reference to the parent list
				$objects[ -1 ]{ "root" } = $objects[ 0 ]{"root"};
				push( @{ $arrays[ -1 ] }, $objects[ -1 ]);
			}
			elsif( $type eq "item" ){
				push( @objects, {} );
				$objects[ -1 ]{ "root" } = $objects[ 0 ]{"root"};
				$objects[ -2 ]{ $tag } = $objects[ -1 ];
			}
			elsif( $type eq "loaddata" ){
				$part =~ s/[\n\r]//g;
				$objects[ -1 ]{ "root" }{ "data:$tag" } = buildHash( getContents( trim( $part ) ) ); #TODO: figure out how to ensure this path is relative to the current data file.
			}
			elsif( $type eq "loadtpl" ){
				$part =~ s/[\n\r]//g;
				$objects[ -1 ]{ "root" }{ "tpl:$tag" } = getContents( trim( $part ) );
			}elsif( $type =~ /^tpl:/ ){
				push( @objects, {} );
				$objects[ -1 ]{ "root" } = $objects[ -1 ];
			}
			else {
				$objects[ -1 ]{ $tag } = trim( $part );
			}
		} else { #closing
			if( $type eq "list" ){
				pop( @arrays );
			}
			elsif( $type eq "item" ){
				pop( @objects );
			}
			elsif( $type =~ /^tpl:/ ){
				my @tplparts = split( /:/, $type );
				my $tpl = $tplparts[1];
				if( defined $objects[ -2 ]{ "tpl:$tpl" } ){
					my $data = pop( @objects );
					$objects[ -1 ]{ $tag } = injectData( $objects[ -1 ]{ "tpl:$tpl" }, $data );
				}
			}
		}
	}

	return $returnObj;
}

sub injectData{
	my ( $tpl, $data ) = @_;
	$tpl =~ s/([\|+])/GRRRRRRRRRR\\$1/g;
	my $replaced = $tpl;
	my $type;
	my $tag;
	my $value;
	my $tmpStr = "";
	my $match;

	while( $tpl =~ m/<%([\s]*)([^%\s]+)([\s]+)([^%\s]+)([\s]*)%>(.*?)<%([\s]*)\/([\s]*)\2([\s]*)\4([\s]*)%>/s ){
		$tmpStr = "";
#		print "\nFOUND ONE: 1-$1- 2-$2- 3-$3- 4-$4- 5-$5 6:\n$6\n";
		$match = $&;
		$tpl = $';
		$type = $2;
		$tag = ( ( $4 eq "" ) and ( $2 ne "" ) ) ? $2 : $4; # 4 or 2 can be the tag depending on whether any spaces were used in the definition
		$value = $6;

		if( $type eq "list" ){
			$tmpStr = "";
			#check to make sure $data ref is an array
			if( ref( $data->{ $tag } ) eq "ARRAY" ){
				my @a = @{ $data->{ $tag } };
				my $l = scalar( @a );
				for( my $i = 0; $i < $l; $i++ ){
					$a[ $i ]->{ "i" } = $i + 1; #add the current index (+1) to the return object
					$tmpStr.= injectData( $value, $a[ $i ] );
				}
				$replaced =~ s/$match/$tmpStr/s;
			} else {
				$replaced =~ s/$match//;
			}
		} elsif( ( $type eq "item" ) and ( $tag and ( $tag ne "item" ) ) ){
			$tmpStr = injectData( $value, $data->{ $tag } );
			$replaced =~ s/$match/$tmpStr/s;
		} elsif( $type eq "if" ){
			if( defined $data->{ $tag } ){
				$tmpStr = injectData( $value, $data );
			} else {
				$tmpStr = "";
			}
			$replaced =~ s/$match/$tmpStr/s;
		} elsif( $type eq "data" ){
			if( $tag eq "root" ){
				$tmpStr = injectData( $value, $data->{ "root" } );
			} elsif( defined $data->{ "root" }->{ "data:$tag" } ){
				$tmpStr = injectData( $value, $data->{ "root" }->{ "data:$tag" } );
			} else {
				$tmpStr = "";
			}
			$replaced =~ s/$match/$tmpStr/s;
		} else {
#			print "type: $type\n";
			#nothing
		}
	}

	$replaced = tagReplace( $replaced, $data );


	$replaced =~ s/GRRRRRRRRRR\\([\|+])/$1/g;
	return $replaced;
}

sub tagReplace {
	my ( $tpl, $data ) = @_;
	my $replaced = $tpl;
	my $match;
	my $tag;
	my $e = "";

	while( $tpl =~ /<%([\s]*)(.+?)([\s]*)%>/ ){
		$match = $&;
		$tag = $2;

		if( defined $data->{ $tag } ){
			$replaced =~ s/$match/$data->{ $tag }/s;
		} # else replace with nothing
		else{
			$replaced =~ s/$match/$e/s;
		}

		$tpl = $';
	}
	return $replaced;
}


if (@ARGV) {
	my( $tplFile, $dataFile, $outputFile ) = @ARGV;
	my $tpl = getContents( $tplFile );
	my $hash = buildHash( getContents( $dataFile ) );
	open FILE, ">$outputFile" or die "Could not open $outputFile\n";
	print FILE injectData( $tpl, $hash );
	close FILE;
}