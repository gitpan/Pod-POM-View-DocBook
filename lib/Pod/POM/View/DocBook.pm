#============================================================= -*-Perl-*-
#
# Pod::POM::View::DocBook
#
# DESCRIPTION
#   DocBook XML view of a Pod Object Model.
#
# AUTHOR
#   Andrew Ford    <A.Ford@ford-mason.co.uk>
#
#   Based heavily on Pod::POM::View::HTML by Andy Wardley <abw@kfs.org>
#
# COPYRIGHT
#   Copyright (C) 2009 Andrew Ford and Ford & Mason Ltd.  All Rights Reserved.
#   Copyright (C) 2000 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# REVISION
#   $Id: DocBook.pm 4116 2009-03-05 23:21:30Z andrew $
#
# TODO
#   * get all the view_* methods outputting valid DocBook XML
#   * check all list items for common item formats
#========================================================================

package Pod::POM::View::DocBook;

require 5.004;

use strict;

use Pod::POM::View;
use Pod::POM::Constants qw( :all );
use base qw( Pod::POM::View );

use Text::Wrap;
use List::MoreUtils qw(firstidx);
#use Clone; # cloning doesn't seem to work at the moment
#use Data::Dumper; # for debugging

use constant DEFAULT_ROOT_ELEMENT    => 'article';
use constant DEFAULT_TOPSECT_ELEMENT => 'sect1';


#########################################################################
# Don't forget to update the VERSION section in the POD!!!
our $VERSION = '0.07';
#########################################################################

our $DEBUG   = 0 unless defined $DEBUG;

my $XML_PROTECT = 0;
my @OVER;
my %topsect = ( book    => 'chapter',
                article => 'sect1',
                chapter => 'sect1',
                sect1   => 'sect2' );
my @section = qw( part chapter sect1 sect2 sect3 sect4 sect5 );
my $head1off = (firstidx { $_ eq 'sect1' } @section) - 1;

my %dont_ucfirst = map { $_ =>1 } qw {
	a an at as and are
	but by 
	ere
	for from
	in into is
	of on onto or over
	per
	the to that than
	until unto upon
	via
	with while whilst within without
        de von
};



#------------------------------------------------------------------------
# new(%options)
#
# Constructor for the view.  Called implicitly by Pod::POM 
# Options:
#  * root    - the root element (defaults to 'article')
#  * topsect - top sectional element
#  * pubid
#  * title
#  * author
#  * extracttoptitle
#  * titlecasing
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_)
        || return;

    # initalise stack for maintaining info for nested lists
    $self->{ OVER } = [];

    # Determine the index of the topmost level section

    if (!exists $self->{topsect}) {
        if (exists $self->{root}) {
            my $root = $self->{root};
            if (exists $topsect{$root}) {
                $self->{topsect} = $topsect{$root};
            }
        }
    }
    
    $self->{root}      ||= DEFAULT_ROOT_ELEMENT;
    $self->{topsect}   ||= DEFAULT_TOPSECT_ELEMENT;
    $self->{_head1off} = (firstidx { $_ eq $self->{topsect} } @section) - 1;
    return $self;
}

#------------------------------------------------------------------------
# view($self, $type, $item)
#------------------------------------------------------------------------

sub view {
    my ($self, $type, $item) = @_;

    DEBUG("view $type");

    if ($type =~ s/^seq_//) {
        return $item;
    }
    elsif (UNIVERSAL::isa($item, 'HASH')) {
        if (defined $item->{ content }) {
            return $item->{ content }->present($self);
        }
        elsif (defined $item->{ text }) {
            my $text = $item->{ text };
            return ref $text ? $text->present($self) : $text;
        }
        else {
            return '';
        }
    }
    elsif (! ref $item) {
        return $item;
    }
    else {
        return '';
    }
}

#------------------------------------------------------------------------
# view_pod($self, $pod)
#
# View method for top-level node.  Outputs the doctype and root element 
# and its content.
#------------------------------------------------------------------------

sub view_pod {
    my ($self, $pod) = @_;

    DEBUG("view_pod\n");
    my ($root, $author, $pubid, $sysid, $intsubset);
    my $title = "";
    my @content = $pod->content;
    my $version_msg = sprintf("<!-- Generated by %s %s using Pod:::POM %s -->\n",
                              __PACKAGE__, $VERSION, $Pod::POM::VERSION);

    if (ref $self) {
        $root    = $self->{root};
        if ($self->{suppressversion}) {
            $version_msg = "";
        }
    }

    if (ref $content[0] eq 'Pod::POM::Node::Head1'
        and $content[0]->title eq 'NAME'
        and int(@{$content[0]->content}) == 1)
    {
        my ($titlecontent) = (shift @content)->content;

        $title = $titlecontent->text->present($self);

    }

    $root  ||= DEFAULT_ROOT_ELEMENT;
    $pubid ||= "-//OASIS//DTD DocBook XML V4.5//EN";
    $sysid ||= "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd";
    $intsubset ||= "";

    return "<?xml version='1.0'?>\n"
        . "<!DOCTYPE $root PUBLIC\n"
        . "    \"$pubid\"\n"
        . "    \"$sysid\">\n"
        . $version_msg
        . "<$root>\n"
        . "<title>$title</title>\n\n"
        . join('', ( map { $_->present($self) } @content ))
        . "\n</$root>\n";
}


#------------------------------------------------------------------------
# _title_case_text($self, $text, $casepreserve, $is_subsequent)
#
# Convert the case of words in a text string to "title case".  There are
# a couple of implementations of this (Text::Autoformat and 
# Text::Capitalize).  This is a fairly simple implementation.
#
# 
#------------------------------------------------------------------------


sub _title_case_text {
    my ($self, $text, $casepreserve, $is_subsequent) = @_;

    my @words = grep { $_ } split(/\s+/, $text);
    foreach my $word (@words) {
        next if $casepreserve->{lc $word};
        $word = lc $word;
        $word = ucfirst $word unless $dont_ucfirst{$word};
    }
    $words[0] = ucfirst $words[0] unless $is_subsequent or $casepreserve->{$words[0]};
    my $newtext = join(" ", @words);
    $text =~ s/(\S.*\S)/$newtext/s;
    return $text;
}


sub _title_case_seq {
    my ($self, $node, $casepreserve, $is_subsequent) = @_;

    return unless ref $node;

    $casepreserve ||= {};
    if (!ref $casepreserve) {
        $casepreserve = { map { lc($_) => 1 } split(/[\,\|\s]+/, $casepreserve) };
    }
    elsif (ref $casepreserve eq  'ARRAY') {
        $casepreserve = { map { lc($_) => 1 } @$casepreserve };
    }


    $node = $$node;
    if ($node->[CMD] =~ /^[BI]?$/) {
        foreach ( @{$node->[CONTENT]} ) {
            if (ref $_) {
                $self->_title_case_seq($_, $casepreserve, $is_subsequent);
            }
            else {
                $_ = $self->_title_case_text($_, $casepreserve, $is_subsequent);
            }
            $is_subsequent = 1;
        }
    }
}

sub _view_headn {
    my ($self, $head, $level) = @_;

    DEBUG("view_head$level\n");

    my $sect  = $section[$level + (ref $self ? $self->{_head1off} : $head1off)];
    my $title = $head->title;
    if (ref $self and $self->{titlecasing}) {
#        $title = clone($title);
        $self->_title_case_seq($title, $self->{preservecase});
    }

    $title = $title->present($self, "head$level");
    return "<$sect>\n" 
        . "<title>$title</title>\n\n"
        . $head->content->present($self)
        . "\n</$sect>\n";
}

sub view_head1 {
    my ($self, $head1) = @_;
    return $self->_view_headn($head1, 1);
}


sub view_head2 {
    my ($self, $head2) = @_;
    return $self->_view_headn($head2, 2);
}


sub view_head3 {
    my ($self, $head3) = @_;
    return $self->_view_headn($head3, 3);
}


sub view_head4 {
    my ($self, $head4) = @_;
    return $self->_view_headn($head4, 4);
}


#------------------------------------------------------------------------
# view_over($self, $over)
#
# View method for =over.  Maps to some sort of list - except if the content
# contains no "=item"s in which case it is a blockquote.
#------------------------------------------------------------------------

sub view_over {
    my ($self, $over) = @_;
    my ($start, $end, $strip);

    DEBUG("view_over");

    my $items   = $over->item();

    return '' unless @$items || @{$over->content};

    if (@$items) {
        my $first_title = $items->[0]->title();

        if ($first_title =~ /^\s*\*\s*/) {
            # '=item *' => <ul>
            $start = "<itemizedlist>\n";
            $end   = "</itemizedlist>\n";
            $strip = qr/^\s*\*\s*/;
        }
        elsif ($first_title =~ /^\s*\d+\.?\s*/) {
            # '=item 1.' or '=item 1 ' => <ol>
            $start = "<orderedlist>\n";
            $end   = "</orderedlist>\n";
            $strip = qr/^\s*\d+\.?\s*/;
        }
        else {
            $start = "<itemizedlist>\n";
            $end   = "</itemizedlist>\n";
            $strip = '';
        }
    }
    else {
        $start = "<blockquote>\n";
        $end   = "</blockquote>\n";
        $strip = '';
    }

    my $overstack = ref $self ? $self->{ OVER } : \@OVER;
    push(@$overstack, $strip);
    my $content = $over->content->present($self);
    pop(@$overstack);

    return "\n"
        . $start
        . $content
        . $end;
}


sub view_item {
    my ($self, $item) = @_;

    DEBUG("view_item");

    my $over  = ref $self ? $self->{ OVER } : \@OVER;
    my $title = $item->title();
    my $strip = $over->[-1];

    if (defined $title) {
        $title = $title->present($self) if ref $title;
        $title =~ s/$strip// if $strip;
        if (length $title) {
            my $anchor = $title;
            $anchor =~ s/^\s*|\s*$//g; # strip leading and closing spaces
            $anchor =~ s/\W/_/g;
            $title = qq{<a name="item_$anchor"></a><b>$title</b>};
        }
    }

    return '<listitem>'
        . "$title\n"
        . $item->content->present($self)
        . "</listitem>\n";
}


sub view_for {
    my ($self, $for) = @_;
    return '' unless $for->format() =~ /\bdocbook\b/;
    return $for->text()
        . "\n\n";
}
    

sub view_begin {
    my ($self, $begin) = @_;
    return '' unless $begin->format() =~ /\bdocbook\b/;
    $XML_PROTECT++;
    my $output = $begin->content->present($self);
    $XML_PROTECT--;
    return $output;
}
    

sub view_textblock {
    my ($self, $text) = @_;
    return "<para>$text</para>\n";
}


sub view_verbatim {
    my ($self, $text) = @_;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
    }
    return "\n<verbatim><![CDATA[$text]]></verbatim>\n\n";
}


sub view_seq_bold {
    my ($self, $text) = @_;
    return "<emphasis role='strong'>$text</emphasis>";
}


sub view_seq_italic {
    my ($self, $text) = @_;
    return "<emphasis>$text</emphasis>";
}


sub view_seq_code {
    my ($self, $text) = @_;
    return "<literal>$text</literal>";
}

sub view_seq_file {
    my ($self, $text) = @_;
    return "<filename>$text</filename>";
}



sub view_seq_space {
    my ($self, $text) = @_;
    $text =~ s/\s/&nbsp;/g;
    return $text;
}


sub view_seq_entity {
    my ($self, $entity) = @_;
    return "&$entity;"
}

#------------------------------------------------------------------------
# view_seq_link($self, $link)
#
# View sequence method for links
#  L<name>               link to Perl manual page
#  L<name(n)             link to Unix man page
#  L<name/"sec">         link to section in man page
#  L<text|name>          link with display text
#  L<text|/sec>          link to section in this doc
#  L<scheme:address>     link to absolute URL (text is not allowed)
#------------------------------------------------------------------------

sub view_seq_link {
    my ($self, $link) = @_;

    # view_seq_text has already taken care of L<http://example.com/>
    if ($link =~ /^<ulink url=/ ) {
        return $link;
    }

    # full-blown URL's are emitted as-is
    if ($link =~ m{^\w+://}s ) {
        return make_ulink($link);
    }

    $link =~ s/\n/ /g;   # undo line-wrapped tags

    my $orig_link = $link;
    my $linktext;
    # strip the sub-title and the following '|' char
    if ( $link =~ s/^ ([^|]+) \| //x ) {
        $linktext = $1;
    }

    # make sure sections start with a /
    $link =~ s|^"|/"|;

    my $page;
    my $section;
    if ($link =~ m|^ (.*?) / "? (.*?) "? $|x) { # [name]/"section"
        ($page, $section) = ($1, $2);
    }
    elsif ($link =~ /\s/) {  # this must be a section with missing quotes
        ($page, $section) = ('', $link);
    }
    else {
        ($page, $section) = ($link, '');
    }

    # warning; show some text.
    $linktext = $orig_link unless defined $linktext;

    my $url = '';
    if (defined $page && length $page) {
        $url = $self->view_seq_link_transform_path($page);
    }

    # append the #section if exists
    $url .= "#$section" if defined $url and
        defined $section and length $section;

    return make_ulink($url, $linktext);
}


# should be sub-classed if extra transformations are needed
#
# for example a sub-class may search for the given page and return a
# relative path to it.
#
# META: where this functionality should be documented? This module
# doesn't have docs section
#
sub view_seq_link_transform_path {
    my($self, $page) = @_;

    # right now the default transform doesn't check whether the link
    # is not dead (i.e. whether there is a corresponding file.
    # therefore we don't link L<>'s other than L<http://>
    # subclass to change the default (and of course add validation)

    # this is the minimal transformation that will be required if enabled
    # $page = "$page.html";
    # $page =~ s|::|/|g;
    #print "page $page\n";
    return;
}


sub make_ulink {
    my($url, $title) = @_;

    if (!defined $url) {
        return defined $title ? "<emphasis>$title</emphasis>"  : '';
    }

    $title = $url unless defined $title;
    #print "$url, $title\n";
    return qq{<ulink url="$url">$title</ulink>};
}




# this code has been borrowed from Pod::Html
my $urls = '(' . join ('|',
     qw{
       http
       telnet
       mailto
       news
       gopher
       file
       wais
       ftp
     } ) . ')'; 
my $ltrs = '\w';
my $gunk = '/#~:.?+=&%@!\-';
my $punc = '.:!?\-;';
my $any  = "${ltrs}${gunk}${punc}";

sub view_seq_text {
     my ($self, $text) = @_;

     unless ($XML_PROTECT) {
        for ($text) {
            s/&/&amp;/g;
            s/</&lt;/g;
            s/>/&gt;/g;
        }
     }

     $text =~ s{
        \b                           # start at word boundary
         (                           # begin $1  {
           $urls     :               # need resource and a colon
           (?!:)                     # Ignore File::, among others.
           [$any] +?                 # followed by one or more of any valid
                                     #   character, but be conservative and
                                     #   take only what you need to....
         )                           # end   $1  }
         (?=                         # look-ahead non-consumptive assertion
                 [$punc]*            # either 0 or more punctuation followed
                 (?:                 #   followed
                     [^$any]         #   by a non-url char
                     |               #   or
                     $               #   end of the string
                 )                   #
             |                       # or else
                 $                   #   then end of the string
         )
       }{<ulink url="$1">$1</ulink>}igox;

     return $text;
}


#------------------------------------------------------------------------
# DEBUG(@msg)
#------------------------------------------------------------------------

sub DEBUG {
    print STDERR "DEBUG: ", @_ if $DEBUG;
}


1;


=pod

=head1 NAME

Pod::POM::View::DocBook - DocBook XML view of a Pod Object Model

=head1 SYNOPSIS

    use Pod::POM;
    use Pod::POM::View::DocBook;

    $parser = Pod::POM->new;
    $pom    = $parser->parse($file);

    $parser->default_view('Pod::POM::View::DocBook')
    $pom->present;

    # or

    $view   = Pod::Pom::View::DocBook->new(%options);
    $parser->default_view($view)
    $pom->present;

    # or even

    $pom->present(Pod::Pom::View::DocBook->new(%options));


=head1 DESCRIPTION

I<DocBook> is a

See L<http://www.docbook.org/> for details.

This module provides a view for C<Pod::POM> that outputs the
content as a DocBook XML document.

Use it like any other C<Pod::POM::View> subclass.

If C<< Pod::POM-E<gt>default_view >> is passed this modules class name then
when the C<present> method is called on the Pod object, this constructor
will be called without any options.  If you want to override the default
options then you have to create a view object and pass it to
C<default_view> or on the C<present> method.

For example to convert a Pod document to a DocBook chapter document (for
inclusion in another document), you might use the following code:

    $pom  = $parser->parse($file);
    $view = Pod::Pom::View::DocBook( root => 'chapter' );
    print $pom->present($view);


=head1 SUBROUTINES/METHODS

Apart from the C<view_*> methods (see L<Pod::POM> for details), this
module supports the two following methods:

=over 4

=item new()

Constructor for the view object.  

Options:

=over 4

=item C<root>

name of the root element (default: C<article>)

=item C<topsect>

name of the topmost sectional element (defaults to C<sect1> if C<root>
is C<article> or C<chapter> if C<root> is C<book>

=item C<extractname>

if true then if the first C<=head1> is C<NAME> then its content is
extracted as the title of the root element (default is true)

=item C<titlecasing>

if true then title text is converted to initial caps format, i.e. all
words are initial capped except for stopwords such as "a", "the", "and",
"of", "on", etc (default is enabled)

=item C<preservecase>

list of words for which case should be preserved in titles.  The list may be an array ref or a
string of words separated by spaces, commas or vertical bar characters.

=back



=item view( $type, $node )

Return the given Pod::POM node as formatted by the View.

=back

The following methods are specializations of the methods in L<Pod::POM::View>:

=over 4

=item make_ulink

=item view_begin

=item view_for

=item view_head1

=item view_head2

=item view_head3

=item view_head4

=item view_item

=item view_over

=item view_pod

=item view_seq_bold

=item view_seq_code

=item view_seq_entity

=item view_seq_file

=item view_seq_italic

=item view_seq_link

=item view_seq_link_transform_path

=item view_seq_space

=item view_seq_text

=item view_textblock

=item view_verbatim

=item DEBUG

=back

=head1 AUTHOR

Andrew Ford, C<< E<lt>A.Ford@ford-mason.co.ukE<gt> >>

=head1 VERSION

This is version 0.07 of C<Pod::POM::View::DocBook>.  


=head1 BUGS AND LIMITATIONS

This is still alpha-level code, many features are not fully implemented.

Please report any bugs or feature requests to C<bug-pod-pom-view-docbook
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Pod-POM-View-Docbook>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 DEPENDENCIES

This module depends on L<Pod::POM>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Pod::POM::View::DocBook

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Pod-POM-View-DocBook>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Pod-POM-View-DocBook>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Pod-POM-View-DocBook>

=item * Search CPAN

L<http://search.cpan.org/dist/Pod-POM-View-DocBook>

=back

=head1 SEE ALSO

=over 4

=item * L<perlpodspec>

=item * L<perlpod>

=item * L<Pod::DocBook>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2009 Andrew Ford and Ford & Mason Ltd, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
