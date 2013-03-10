#!/usr/bin/perl -w

#Includes
use strict;
use warnings;
use IO::File;

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

# path from here to data folder
my $dataPath = '../dhap/data';
my $tplPath = '../dhap/templates';
my $outPath = '../generated';

my $arg;
my $argValue;
my @argbits;
my @argLocales = ();
my @argPages = ();
my $perl = "perl";
my $generate = "generate.tpl";


print "starting generation map\n";

if (@ARGV) {
	@argLocales = ();
	for my $argStr (@ARGV){
		@argbits = split( "=", $argStr );
		if( scalar( @argbits ) > 1 ){
			$arg = $argbits[ 0 ];
			$argValue = $argbits[ 1 ];
			if( $arg eq "perl" ){
				$perl = $argValue;
			} elsif ( $arg eq "generate" ){
				$generate = $argValue;
			} elsif ( $arg eq "locales" ){
				@argLocales = split( ",", $argValue );
			} elsif ( $arg eq "pages" ){
				@argPages = split( ",", $argValue );
			}
		} #else - shouldn't happen.
	}
}

my @locales = ();
if( scalar( @argLocales ) ){
	print "using argLocales.\n";
	@locales = @argLocales;
} else {
	my @filepaths = glob "$dataPath/*";
	foreach my $path ( @filepaths ){
		$path =~ s/$dataPath\///;
		push( @locales, $path );
	}
}
my @pages = ();
if( scalar( @argPages ) ){
	print "using argPages.\n";
	@pages = @argPages;
} else {
	my @filepaths = glob "$tplPath/pages/*";
	foreach my $path ( @filepaths ){
		$path =~ s/$tplPath\/pages\///;
		$path =~ s/\.html$//;
		push( @pages, $path );
	}
}

if(! -e "$outPath" ){ mkdir $outPath or die "cannot make output dir $outPath"; }


# for list of languages
for my $locale ( @locales ){
	print "generating $locale\n";
	if(! -e "$outPath/$locale" ){ mkdir "$outPath/$locale" or die "cannot make locale output dir $outPath/$locale"; }
	# create main temp output
	# for list of pages
	for my $page ( @pages ) {
		#look for data file & template
		my $tplFile = "$tplPath/main.html";
		my $dataFile = "$dataPath/$locale/$page.data";
		my $outFile = "$outPath/$locale/$page.html";
		print "generating $outFile\n";
		system("$perl $generate $tplFile $dataFile $outFile");
	}
}
print "ending generation map.\n";
# for each content output, inject into copy of temp output
