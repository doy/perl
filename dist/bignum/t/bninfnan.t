#!/usr/bin/perl -w

###############################################################################

use Test;
use strict;

BEGIN
  {
  $| = 1;
  my $location = $0; $location =~ s/bninfnan.t//i;
  unshift @INC, '../lib';     # for testing manually
  if (-d 't')
    {
    chdir 't';
    require File::Spec;
    unshift @INC, File::Spec->catdir(File::Spec->updir, $location);
    }
  else
    {
    unshift @INC, $location;
    }
  print "# INC = @INC\n";
  plan tests => 26;
  }

use bignum;

my ($x);

require "infnan.inc";
