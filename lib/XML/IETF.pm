package XML::IETF;
# ABSTRACT: an interface to the IETF XML Registry.
use Carp;
use Data::Mirror qw(mirror_xml mirror_file);
use URI;
use URI::Namespace;
use constant REGISTRY_URL => 'https://www.iana.org/assignments/xml-registry/xml-registry.xml';
use feature qw(state);
use vars qw($REGISTRY);
use strict;
use warnings;

state $REGISTRY;

=pod

=head1 SYNOPSIS

    $xmlns = XML::IETF->xmlns('netconf'); # returns a URI::Namespace object

    $url = XML::IETF->schemaLocation($xmlns); # returns a URI object

    $xsd = XML::IETF->xsd($xmlns); # returns an XML::LibXML::Schema object

=head1 DESCRIPTION

C<XML::IETF> provides a simple interface to the IETF XML Registry, specified in
L<RFC 3688|https://www.rfc-editor.org/rfc/rfc3688.html>.

This permits for example, dynamically retrieve and load XML schema files using
only their target namespace or mnemonic name. This is quite useful for schema-
heavy protocols such as L<EPP|Net::EPP>.

This module uses L<Data::Mirror> to retrieve remote resources from the IANA.

=head1 PACKAGE METHODS

=head2 xmlns($value)

This method returns a L<URI::Namespace> object for the XML namespace URI that is
associated with C<$value>, or C<undef> if the record cannot be found.

=cut

sub xmlns {
    my ($class, $value) = @_;

    foreach my $record ($class->get_registry('ns')->getElementsByTagName('record')) {
        if ($value eq $record->getElementsByTagName('value')->shift->textContent) {
            return URI::Namespace->new($record->getElementsByTagName('name')->shift->textContent);
        }
    }

    return undef;
}

=pod

=head2 name($xmlns)

This method is the reverse of C<xmlns()>: given an XML namespace, it returns the
name that the namespace is registered with. C<$xmlns> may be a string or a
L<URI::Namespace> object.

=cut

sub name {
    my ($class, $xmlns) = @_;
    $xmlns = $xmlns->as_string if ($xmlns->isa('URI::Namespace'));

    foreach my $record ($class->get_registry('ns')->getElementsByTagName('record')) {
        if ($xmlns eq $record->getElementsByTagName('name')->shift->textContent) {
            return $record->getElementsByTagName('value')->shift->textContent;
        }
    }
}

=pod

=head2 schemaLocation($xmlns)

This method returns a L<URI> object which locates the XSD file that is
associated with the XML namespace URI in C<$xmlns>, which may be a string or a
L<URI::Namespace> object, or C<undef> if the record cannot be found.

=cut

sub schemaLocation {
    my ($class, $xmlns) = @_;

    my $name = $class->name($xmlns);

    foreach my $record ($class->get_registry('schema')->getElementsByTagName('record')) {
        if ($name eq $record->getElementsByTagName('value')->shift->textContent) {
            return URI->new_abs(
                $record->getElementsByTagName('file')->shift->textContent,
                REGISTRY_URL,
            )
        }
    }

    return undef;
}

=pod

=head2 xsd($xmlns)

This method returns a L<XML::LibXML::Schema> object containg the XML schema that
is associated with the XML namespace URI in C<$xmlns>, which may be a string or
a L<URI::Namespace> object, or C<undef> if the record cannot be found.

=cut

sub xsd {
    my ($class, $xmlns) = @_;

    my $url = $class->schemaLocation($xmlns);

    return undef if (!$url);

    return XML::LibXML::Schema->new('location' => mirror_file($url));
}

sub get_registry {
    my ($class, $sub) = @_;

    $REGISTRY ||= mirror_xml(REGISTRY_URL);

    foreach my $el ($REGISTRY->getElementsByTagName('registry')) {
        if ($el->hasAttribute('id') && $sub eq $el->getAttribute('id')) {
            return $el;
        }
    }

    return undef;
}

1;
