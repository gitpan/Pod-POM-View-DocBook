# $Id: Makefile.PL 4114 2009-03-04 22:28:43Z andrew $

use ExtUtils::MakeMaker;

my %opts = (
    'NAME'         => 'Pod::POM::View::DocBook',
    'VERSION_FROM' => 'lib/Pod/POM/View/DocBook.pm',
    'PREREQ_PM'    => { 
        'List::MoreUtils' => 0,
        'Pod::POM::View'  => 0,
        'Test::XML'       => 0,
        'Text::Wrap'      => 0,
        'XML::LibXML'     => 0,
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

