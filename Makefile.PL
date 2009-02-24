# $Id: Makefile.PL 4092 2009-02-24 17:46:48Z andrew $

use ExtUtils::MakeMaker;

my %opts = (
    'NAME'	   => 'Pod::POM::View::DocBook',
    'VERSION_FROM' => 'lib/Pod/POM/View/DocBook.pm',
#    'EXE_FILES'    => [ 'bin/pom2', 'bin/podlint' ],
    'PREREQ_PM'    => { 
        'List::MoreUtils' => 0,
        'Pod::POM::View'  => 0,
        'Text::Wrap'      => 0,
    },
    'dist'         => {
	'COMPRESS' => 'gzip',
	'SUFFIX'   => 'gz',
    },

);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{ AUTHOR }   = 'Andrew Ford <A.Ford@ford-mason.co.uk>';
    $opts{ ABSTRACT } = 'DocBook View for POD Object Model',
}

WriteMakefile( %opts );

