#!/usr/bin/perl

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
    else {
        unshift @INC, 't/lib';
    }
}
chdir 't';

use strict;
use Test::More;

BEGIN {
	if ($^O =~ /MSWin32/i) {
		plan tests => 42;
	} else {
		plan skip_all => 'This is not Win32';
	}
}

use Config;
use File::Spec;
use File::Basename;
use ExtUtils::MM;

require_ok( 'ExtUtils::MM_Win32' );

# Dummy MM object until we have a real MM init method.
my $MM = bless {
                DIR     => [],
                NOECHO  => '@',
                XS      => {},
                MAKEFILE => 'Makefile',
                RM_RF   => 'rm -rf',
                MV      => 'mv',
               }, 'MM';


# replace_manpage_separator() => tr|/|.|s ?
{
    my $man = 'a/path/to//something';
    ( my $replaced = $man ) =~ tr|/|.|s;
    is( $MM->replace_manpage_separator( $man ),
        $replaced, 'replace_manpage_separator()' );
}

# maybe_command()
SKIP: {
    skip( '$ENV{COMSPEC} not set', 2 )
        unless $ENV{COMSPEC} =~ m!((?:[a-z]:)?[^|<>]+)!i;
    my $comspec = $1;
    is( $MM->maybe_command( $comspec ), 
        $comspec, 'COMSPEC is a maybe_command()' );
    ( my $comspec2 = $comspec ) =~ s|\..{3}$||;
    like( $MM->maybe_command( $comspec2 ), 
          qr/\Q$comspec/i, 
          'maybe_command() without extension' );
}

my $had_pathext = exists $ENV{PATHEXT};
{
    local $ENV{PATHEXT} = '.exe';
    ok( ! $MM->maybe_command( 'not_a_command.com' ), 
        'not a maybe_command()' );
}
# Bug in Perl.  local $ENV{FOO} won't delete the key afterward.
delete $ENV{PATHEXT} unless $had_pathext;

# file_name_is_absolute() [Does not support UNC-paths]
{
    ok( $MM->file_name_is_absolute( 'C:/' ), 
        'file_name_is_absolute()' );
    ok( ! $MM->file_name_is_absolute( 'some/path/' ),
        'not file_name_is_absolute()' );

}

# find_perl() 
# Should be able to find running perl... $^X is OK on Win32
{
    my $my_perl = $1 if $^X  =~ /(.*)/; # are we in -T or -t?
    my( $perl, $path ) = fileparse( $my_perl );
    like( $MM->find_perl( $], [ $perl ], [ $path ], 0 ), 
          qr/^\Q$my_perl\E$/i, 'find_perl() finds this perl' );
}

# catdir() (calls MM_Win32->canonpath)
{
    my @path_eg = qw( c: trick dir/now_OK );

    is( $MM->catdir( @path_eg ), 
         'C:\\trick\\dir\\now_OK', 'catdir()' );
    is( $MM->catdir( @path_eg ), 
        File::Spec->catdir( @path_eg ), 
        'catdir() eq File::Spec->catdir()' );

# catfile() (calls MM_Win32->catdir)
    push @path_eg, 'file.ext';

    is( $MM->catfile( @path_eg ),
        'C:\\trick\\dir\\now_OK\\file.ext', 'catfile()' );

    is( $MM->catfile( @path_eg ), 
        File::Spec->catfile( @path_eg ), 
        'catfile() eq File::Spec->catfile()' );
}

# init_others(): check if all keys are created and set?
# qw( TOUCH CHMOD CP RM_F RM_RF MV NOOP TEST_F LD AR LDLOADLIBS DEV_NUL )
{
    my $mm_w32 = bless( {}, 'MM' );
    $mm_w32->init_others();
    my @keys = qw( TOUCH CHMOD CP RM_F RM_RF MV NOOP 
                   TEST_F LD AR LDLOADLIBS DEV_NULL );
    for my $key ( @keys ) {
        ok( $mm_w32->{ $key }, "init_others: $key" );
    }
}

# constants()
# XXX this test is probably useless now that we can call individual
# init_* methods and check the keys in $mm_w32 directly
{
    my $mm_w32 = bless {
        NAME         => 'TestMM_Win32', 
        VERSION      => '1.00',
        PM           => { 'MM_Win32.pm' => 1 },
    }, 'MM';

    # XXX Hack until we have a proper init method.
    # Flesh out some necessary keys in the MM object.
    @{$mm_w32}{qw(XS MAN1PODS MAN3PODS)} = ({}) x 3;
    @{$mm_w32}{qw(C O_FILES H)}          = ([]) x 3;
    @{$mm_w32}{qw(PARENT_NAME)}          = ('') x 3;
    $mm_w32->{FULLEXT} = 'TestMM_Win32';
    $mm_w32->{BASEEXT} = 'TestMM_Win32';

    $mm_w32->init_VERSION;
    $mm_w32->init_linker;
    $mm_w32->init_INST;
    $mm_w32->init_xs;

    my $s_PM = join( " \\\n\t", sort keys %{$mm_w32->{PM}} );
    my $k_PM = join( " \\\n\t", %{$mm_w32->{PM}} );

    my $constants = $mm_w32->constants;

    foreach my $regex (
         qr|^NAME       \s* = \s* TestMM_Win32 \s* $|xms,
         qr|^VERSION    \s* = \s* 1\.00 \s* $|xms,
         qr|^MAKEMAKER  \s* = \s* \Q$INC{'ExtUtils/MakeMaker.pm'}\E \s* $|xms,
         qr|^MM_VERSION \s* = \s* \Q$ExtUtils::MakeMaker::VERSION\E \s* $|xms,
         qr|^TO_INST_PM \s* = \s* \Q$s_PM\E \s* $|xms,
         qr|^PM_TO_BLIB \s* = \s* \Q$k_PM\E \s* $|xms,
        )
    {
        like( $constants, $regex, 'constants() check' );
    }
}

# path()
my $had_path = exists $ENV{PATH};
{
    my @path_eg = ( qw( . .. ), 'C:\\Program Files' );
    local $ENV{PATH} = join ';', @path_eg;
    ok( eq_array( [ $MM->path() ], [ @path_eg ] ),
        'path() [preset]' );
}
# Bug in Perl.  local $ENV{FOO} will not delete key afterwards.
delete $ENV{PATH} unless $had_path;

# static_lib() should look into that
# dynamic_bs() should look into that
# dynamic_lib() should look into that

# clean()
{
    my $clean = $Config{cc} =~ /^gcc/i ? 'dll.base dll.exp' : '*.pdb';
    like( $MM->clean(), qr/^clean ::\s+\Q-$(RM_F) $clean\E\s+$/m,
          'clean() Makefile target' );
}

# init_linker
{
    my $libperl = File::Spec->catfile('$(PERL_INC)', 
                                      $Config{libperl} || 'libperl.a');
    my $export  = '$(BASEEXT).def';
    my $after   = '';
    $MM->init_linker;

    is( $MM->{PERL_ARCHIVE},        $libperl,   'PERL_ARCHIVE' );
    is( $MM->{PERL_ARCHIVE_AFTER},  $after,     'PERL_ARCHIVE_AFTER' );
    is( $MM->{EXPORT_LIST},         $export,    'EXPORT_LIST' );
}

# canonpath()
{
    my $path = 'c:\\Program Files/SomeApp\\Progje.exe';
    is( $MM->canonpath( $path ), File::Spec->canonpath( $path ),
	    'canonpath() eq File::Spec->canonpath' );
}

# perl_script()
my $script_ext  = '';
my $script_name = 'mm_w32tmp';
SKIP: {
    local *SCRIPT;
    skip( "Can't create temp file: $!", 4 )
        unless open SCRIPT, "> $script_name";
    print SCRIPT <<'EOSCRIPT';
#! perl
__END__
EOSCRIPT
    skip( "Can't write to temp file: $!", 4 )
        unless close SCRIPT;
    # now start tests:
    is( $MM->perl_script( $script_name ), 
        "${script_name}$script_ext", "perl_script ($script_ext)" );

    skip( "Can't rename temp file: $!", 3 )
        unless rename $script_name, "${script_name}.pl";
    $script_ext = '.pl';
    is( $MM->perl_script( $script_name ), 
        "${script_name}$script_ext", "perl_script ($script_ext)" );

    skip( "Can't rename temp file: $!", 2 )
        unless rename "${script_name}$script_ext", "${script_name}.bat";
    $script_ext = '.bat';
    is( $MM->perl_script( $script_name ), 
        "${script_name}$script_ext", "perl_script ($script_ext)" );

    skip( "Can't rename temp file: $!", 1 )
        unless rename "${script_name}$script_ext", "${script_name}.noscript";
    $script_ext = '.noscript';

    isnt( $MM->perl_script( $script_name ),
          "${script_name}$script_ext", 
          "not a perl_script anymore ($script_ext)" );
    is( $MM->perl_script( $script_name ), undef,
        "perl_script ($script_ext) returns empty" );
}
unlink "${script_name}$script_ext" if -f "${script_name}$script_ext";


# xs_o() should look into that
# top_targets() should look into that

# dist_ci() should look into that
# dist_core() should look into that

# pasthru()
{
    my $pastru = "PASTHRU = " . ($Config{make} =~ /^nmake/i ? "-nologo" : "");
    is( $MM->pasthru(), $pastru, 'pasthru()' );
}

package FakeOut;

sub TIEHANDLE {
	bless(\(my $scalar), $_[0]);
}

sub PRINT {
	my $self = shift;
	$$self .= shift;
}

__END__

=head1 NAME

MM_Win32.t - Tests for ExtUtils::MM_Win32

=head1 TODO

 - Methods to still be checked:
 # static_lib() should look into that
 # dynamic_bs() should look into that
 # dynamic_lib() should look into that
 # xs_o() should look into that
 # top_targets() should look into that
 # dist_ci() should look into that
 # dist_core() should look into that

=head1 AUTHOR

20011228 Abe Timmerman <abe@ztreet.demon.nl>

=cut
