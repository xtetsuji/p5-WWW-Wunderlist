package WWW::Wunderlist::List;

use strict;
use warnings;

use Carp qw(carp croak);

use Class::Accessor::Lite (
    new => 0,
    rw => [
        # Wunderlist properties
    ],
    ro => [
        # Wunderlist properties
        qw(created_at id local_identifier owner_id position title type
           update_at version)],
        # Delegator
        qw(_api),
    wo => [],
);

# my $list = WWW::Wunderlist::List->new( HASHREF, API )
# Internal method for creation object data.
sub new {
    my $class = shift;
    my $arg   = shift;
    my $wl    = shift;
    if ( ref $arg ne 'HASH' ) {
        croak "1st argument required as HASH REFERENCE.";
    }
    if ( !ref $wl || !$wl->isa("WWW::Wunderlist") ) {
        croak "2nd argument requires API object.";
    }
    $arg->{_api} = $wl;
    return bless $arg, $class;
}

# List API is not support PUT (modify) interface.

sub delete {
    my $self = shift;
    my $res = $self->ua->delete(
        $self->_api->endpoint_url . '/me/' . $self->id
    );
    $self->latest_http_response($res);
    return $res->is_success;
}

1;

__END__

=pod

=head1 NAME

WWW::Wunderlist::List - List object for Wunderlist API.

=head1 SYNOPSIS

 # see WWW::Wunderlist document
 my $wl = WWW::Wunderlist->new( email => EMAIL, password => PASSWORD );
 $wl->login()
 my @lists = $wl->get_lists();
 my $task = @lists[0]; # WWW::Wunderlist::List object

=head1 DESCRIPTION

See L<WWW::Wunderlist> document for detail.

=head1 METHODS

=head2 WWW::Wunderlist::List->new( ... )

Internal use.

=head2 $list->delete()

Delete this list.

=head1 PROPERTIES

readonly properties:

        created_at id local_identifier owner_id position title type
        update_at version

This properties are accessible by accessor method. e.g.

 # read only properties:
 my $created_at = $task->created_at;

=head1 CAUTION

B<THIS VERSION IS ALPHA RELEASE.>
B<THIS MODULE IS NOT SUPPORT ALL WUNDERLIST APIs.>
B<UNDER DEVELOPMENT YET.>

=head1 SEE ALSO

L<Wunderlist API|https://wunderpy.readthedocs.org/en/latest/wunderlist_api/index.html>,
L<WWW::Wunderlist>

=head1 LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

OGATA Tetsuji E<lt>tetsuji.ogata {at} gmail.comE<gt>

=cut
