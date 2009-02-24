# $Id: TestUtils.pm 4092 2009-02-24 17:46:48Z andrew $

package TestUtils;

use strict;
use vars qw(@EXPORT);

use base 'Exporter';

@EXPORT = qw(get_tests);


sub get_tests {
    my ($src, $tproc, $params) = @_;
    my ($input, @tests);

    # read input text
    eval {
        local $/ = undef;
        $input = ref $src ? <$src> : $src;
    };
    if ($@) {
        warn "Cannot read input text from $src\n";
        return undef;
    }


    # remove any comment lines
    $input =~ s/^#.*?\n//gm;

    # remove anything before '-- start --' and/or after '-- stop --'
    $input = $' if $input =~ /\s*--\s*start\s*--\s*/;
    $input = $` if $input =~ /\s*--\s*stop\s*--\s*/;   # help out emacs: ';

    my @rawtests = split(/^\s*==\s*TEST\s*==\s*\n/im, $input);

    # if the first line of the file was '--test--' (optional) then the 
    # first test will be empty and can be discarded
    shift(@rawtests) if $rawtests[0] =~ /^\s*$/;

    my $testno;

    foreach my $input (@rawtests) {
        my ($expect, $params, %params, $desc);
        $testno++;

        # split input by a line like "-- expect --"
        ($input, $expect) = 
            split(/^\s*--\s*expect\s*--\s*\n/im, $input);
        $expect = '' 
            unless defined $expect;

        ($input, $params) = 
            split(/^\s*--\s*params\s*--\s*\n/im, $input);

        if (!defined $params) {
            ($expect, $params) = 
            split(/^\s*--\s*params\s*--\s*\n/im, $expect);
            $params = '' 
                unless defined $params;
        }

        $expect .= "\n" unless substr($expect, -1, 1) eq "\n";

        if ($input =~ s/^\s*desc: (.*?)\n\s*//si) {
            $desc = $1;
        }
                       
        if ($params) {
            foreach (split(/\n/, $params)) {
                chomp;
                next if /^\s*$/;
                if (my($key, $value) = split(/\s*=\s*/, $_, 2)) {
                    $params{$key} = $value;
                }
            }
        }
                       
        push @tests, PkgTest->new( { input       => $input,
                                     params      => \%params,
                                     expect      => $expect,
                                     description => $desc || "Test $testno" } );
    }
    return @tests;
}

1;

package PkgTest;
use strict;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors( qw(input params expect description) );

1;
