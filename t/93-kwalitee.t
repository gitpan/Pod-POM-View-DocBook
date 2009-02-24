#!/usr/bin/perl
# $Id: 93-kwalitee.t 4092 2009-02-24 17:46:48Z andrew $

use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import() };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
