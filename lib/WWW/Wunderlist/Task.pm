package WWW::Wunderlist::Task;

use strict;
use warnings;

use Carp qw(carp croak);

use Class::Accessor::Lite (
    new => 0,
    rw => [
        # Wunderlist properties
        qw(note due_date recurrence_count),
    ],
    ro => [
        # Wunderlist properties
        qw(assignee_id completed_at completed_by_id created_at
           created_by_id deleted_at id list_id local_identifier
           owner_id parent_id position recurrence_type recurring_parent_id
           starred title type updated_at updated_by_id user_id version)],
        # Delegator
        qw(_api),
    wo => [],
);

# my $task = WWW::Wunderlist::Task->new( HASHREF )
# Internal method for creation object data.
sub new {
    my $class = shift;
    my $arg   = shift;
    my $wl    = shift;
    if ( ref $arg ne 'HASH' ) {
        croak "1st argument required as HASH REFERENCE.";
    }
    $arg->{_api} = $wl;
    return bless $arg, $class;
}

sub put {
    my $self = shift;
    my %arg = @_;
    my %post_data;
    for my $key (qw/note due_date recurrence_count/) {
        if ( exists $arg{$key} && defined $arg{$key} ) {
            $self->$key( $arg{$key} );
            $post_data{$key} = $arg{$key};
        }
    }
    my $res = $self->ua->put(
        $self->_api->endpoint_url . '/me/' . $self->id,
        \%post_data,
    );
    $self->latest_http_response($res);
    # rewrite by newest data.
    my $data = $self->json->utf8->decode($res->content);
    for my $key (keys %$data) {
        if( $self->can($key) ) {
            $self->$key($data->{$key});
        }
        else {
            carp qq{method "$key" is not defined.};
        }
    }
    return $res->is_success;
}

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

WWW::Wunderlist::Task - Task object for Wunderlist API.

=head1 SYNOPSIS

 # see WWW::Wunderlist document
 my $wl = WWW::Wunderlist->new( email => EMAIL, password => PASSWORD );
 $wl->login()
 my @tasks = $wl->get_tasks();
 my $task = @tasks[0]; # WWW::Wunderlist::Task object


=head1 DESCRIPTION

(stub)

=head1 METHODS

(stub)

=head1 CAUTION

THIS VERSION IS ALPHA RELEASE.
THIS MODULE IS NOT SUPPORT ALL WUNDERLIST APIs.
UNDER DEVELOPMENT YET.

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
