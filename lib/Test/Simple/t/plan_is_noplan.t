# Can't use Test.pm, that's a 5.005 thing.
package My::Test;

# This feature requires a fairly new version of Test::Harness
BEGIN {
    require Test::Harness;
    if( $Test::Harness::VERSION < 1.20 ) {
        print "1..0\n";
        exit(0);
    }
}

print "1..2\n";

my $test_num = 1;
# Utility testing functions.
sub ok ($;$) {
    my($test, $name) = @_;
    print "not " unless $test;
    print "ok $test_num";
    print " - $name" if defined $name;
    print "\n";
    $test_num++;
}


package main;

require Test::Simple;

push @INC, 'lib/Test/Simple/';
require Catch;
my($out, $err) = Catch::caught();


Test::Simple->import('no_plan');

ok(1, 'foo');


END {
    My::Test::ok($$out eq <<OUT);
ok 1 - foo
1..1
OUT

    My::Test::ok($$err eq <<ERR);
ERR

    # Prevent Test::Simple from exiting with non zero
    exit 0;
}
